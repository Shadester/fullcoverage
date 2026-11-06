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

/// One xccov call dumps line data for every file; far cheaper than one process per file.
private func getAllFileLines(xcresult: URL) throws -> [String: [LineInfo]] {
    let data = try xcrun(["xccov", "view", "--archive", "--json", xcresult.path])
    let all = try JSONDecoder().decode([String: [XccovLine]].self, from: data)
    return all.mapValues { $0.map(parseLineInfo) }
}

func buildReports(
    xcresult: URL,
    targetFilter: String? = nil,
    keep: (String) -> Bool = { _ in true }
) throws -> [FileReport] {
    var targets = try getReport(xcresult: xcresult)
    if targets.isEmpty { throw FullcoverageError.noTargetsFound }

    // Optional target filter
    if let filter = targetFilter, !filter.isEmpty {
        targets = targets.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    let linesByPath = try getAllFileLines(xcresult: xcresult)

    // First target wins for de-duplication
    var seen = Set<String>()
    var reports: [FileReport] = []
    for target in targets {
        for file in target.files where keep(file.path) && seen.insert(file.path).inserted {
            reports.append(FileReport(
                filename: file.path,
                targetName: target.name,
                summary: parseFileSummary(file),
                lines: linesByPath[file.path] ?? []
            ))
        }
    }
    return reports
}
