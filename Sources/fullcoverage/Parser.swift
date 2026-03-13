import Foundation

// MARK: - Codable types for xccov JSON

private struct XccovReport: Decodable {
    let targets: [XccovTarget]
}

private struct XccovTarget: Decodable {
    let name: String
    let files: [XccovFile]
}

private struct XccovFile: Decodable {
    let path: String
    let coveredLines: Int
    let executableLines: Int
    let lineCoverage: Double
    let functions: [XccovFunction]
}

private struct XccovFunction: Decodable {
    let name: String
    let lineNumber: Int
    let executionCount: Int
    let lineCoverage: Double
    let coveredLines: Int
    let executableLines: Int
}

private struct XccovLine: Decodable {
    let line: Int
    let isExecutable: Bool
    let executionCount: Int?
    let subranges: [XccovSubrange]?
}

private struct XccovSubrange: Decodable {
    let executionCount: Int
}

// MARK: - Subprocess

enum FullcoverageError: LocalizedError {
    case xccovFailed(args: [String], stderr: String)
    case noTargetsFound

    var errorDescription: String? {
        switch self {
        case .xccovFailed(let args, let stderr):
            return "xccov failed (\(args.joined(separator: " "))):\n\(stderr)"
        case .noTargetsFound:
            return "No targets found in xcresult."
        }
    }
}

private func xcrun(_ args: [String]) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = args

    let stdout = Pipe()
    process.standardOutput = stdout
    // Pass stderr through to the terminal — avoids pipe-buffer deadlocks
    // when many processes run concurrently and also surfaces xccov warnings.
    process.standardError = FileHandle.standardError

    try process.run()

    // Read stdout before waitUntilExit to avoid blocking if the output is large.
    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw FullcoverageError.xccovFailed(args: args, stderr: "")
    }
    return data
}

// MARK: - Parsing

private func parseLineInfo(_ raw: XccovLine) -> LineInfo {
    let isExec = raw.isExecutable
    let count = isExec ? (raw.executionCount ?? 0) : 0
    let subranges = raw.subranges ?? []
    let branchCount = subranges.count
    let coveredBranches = subranges.filter { $0.executionCount > 0 }.count
    let isPartial = isExec && count > 0 && coveredBranches < branchCount

    return LineInfo(
        line: raw.line,
        isExecutable: isExec,
        count: count,
        isPartial: isPartial,
        branchCount: branchCount,
        coveredBranches: coveredBranches
    )
}

private func parseFileSummary(_ file: XccovFile) -> FileSummary {
    FileSummary(
        coveredLines: file.coveredLines,
        executableLines: file.executableLines,
        lineCoverage: file.lineCoverage,
        functions: file.functions.map {
            FunctionInfo(
                name: $0.name,
                lineNumber: $0.lineNumber,
                executionCount: $0.executionCount,
                lineCoverage: $0.lineCoverage,
                coveredLines: $0.coveredLines,
                executableLines: $0.executableLines
            )
        }
    )
}

// MARK: - Public API

private func getReport(xcresult: URL) throws -> [XccovTarget] {
    let data = try xcrun(["xccov", "view", "--report", "--json", xcresult.path])
    return try JSONDecoder().decode(XccovReport.self, from: data).targets
}

func getFileLines(xcresult: URL, filepath: String) throws -> [LineInfo] {
    let data = try xcrun(["xccov", "view", "--archive", "--file", filepath, "--json", xcresult.path])
    // Top level is {"<path>": [...lines...]}
    guard
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let rawLines = dict[filepath] as? [[String: Any]]
    else { return [] }

    let jsonLines = try JSONDecoder().decode(
        [XccovLine].self,
        from: JSONSerialization.data(withJSONObject: rawLines)
    )
    return jsonLines.map(parseLineInfo)
}

func buildReports(xcresult: URL, maxWorkers: Int = 8) throws -> [FileReport] {
    let targets = try getReport(xcresult: xcresult)
    if targets.isEmpty { throw FullcoverageError.noTargetsFound }

    // Collect unique file entries (first target wins for de-duplication)
    var seen = Set<String>()
    var fileEntries: [(path: String, target: String, file: XccovFile)] = []
    for target in targets {
        for file in target.files where !seen.contains(file.path) {
            seen.insert(file.path)
            fileEntries.append((file.path, target.name, file))
        }
    }

    // Fetch per-line data in parallel, bounded to maxWorkers concurrent subprocesses.
    var linesByPath = [String: [LineInfo]]()
    let lock = NSLock()
    var fetchError: Error?
    let semaphore = DispatchSemaphore(value: maxWorkers)
    let group = DispatchGroup()

    for entry in fileEntries {
        semaphore.wait()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { semaphore.signal(); group.leave() }
            guard fetchError == nil else { return }
            do {
                let lines = try getFileLines(xcresult: xcresult, filepath: entry.path)
                lock.withLock { linesByPath[entry.path] = lines }
            } catch {
                lock.withLock { if fetchError == nil { fetchError = error } }
            }
        }
    }
    group.wait()

    if let error = fetchError { throw error }

    return fileEntries.map { entry in
        FileReport(
            filename: entry.path,
            targetName: entry.target,
            summary: parseFileSummary(entry.file),
            lines: linesByPath[entry.path] ?? []
        )
    }
}
