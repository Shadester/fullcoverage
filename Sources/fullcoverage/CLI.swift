import ArgumentParser
import Foundation

// MARK: - Argument types

enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    case html, json, all
}

enum SortOrder: String, CaseIterable, ExpressibleByArgument {
    /// Alphabetical by file name (default).
    case name
    /// Worst line coverage first.
    case coverage
    /// Worst line coverage first (alias for coverage).
    case lines
    /// Worst branch coverage first.
    case branches
    /// Worst function coverage first.
    case functions
}

enum GroupBy: String, CaseIterable, ExpressibleByArgument {
    case none
    case target
    case codeowners
}

// MARK: - Command

@main
struct Fullcoverage: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fullcoverage",
        abstract: "Generate an HTML coverage report from an Xcode .xcresult bundle."
    )

    @Argument(help: "Path to the .xcresult bundle.")
    var xcresult: String

    @Option(name: .shortAndLong, help: "Output directory (default: coverage).")
    var output: String?

    @Option(name: .shortAndLong, help: "Parallel workers (default: CPU count).")
    var jobs: Int?

    @Option(name: .long, help: "Glob patterns for files to exclude (repeatable).")
    var ignore: [String] = []

    @Option(name: .long, help: "Glob patterns for files to include (repeatable; all files if omitted).")
    var include: [String] = []

    @Option(name: .long, help: "Path to config file (default: .fullcoverage.yml).")
    var config: String = ".fullcoverage.yml"

    @Option(name: .long, help: "Report title (default: fullcoverage).")
    var title: String?

    @Option(name: .long, help: "Output format: html (default), json, all.")
    var format: OutputFormat = .html

    @Option(name: .long, help: "Sort order: name (default), coverage, lines, branches, functions.")
    var sort: SortOrder?

    @Option(name: .long, help: "Group rows by: none (default), target, codeowners.")
    var groupBy: GroupBy?

    @Option(name: .long, help: "Path to CODEOWNERS file (auto-discovered if omitted).")
    var codeowners: String?

    @Option(name: .long, help: "Only include files from this Xcode target.")
    var target: String?

    @Option(name: .long, help: "Minimum line coverage % (e.g. 80). Exits non-zero if not met.")
    var minLines: Double?

    @Option(name: .long, help: "Minimum branch coverage % (e.g. 60). Exits non-zero if not met.")
    var minBranches: Double?

    @Option(name: .long, help: "Minimum function coverage % (e.g. 80). Exits non-zero if not met.")
    var minFunctions: Double?

    @Option(name: .long, help: "Write an SVG badge to this path.")
    var badge: String?

    @Flag(name: .long, help: "Open index.html in the browser after generation.")
    var open: Bool = false

    mutating func run() throws {
        let xcresultURL = URL(fileURLWithPath: xcresult).standardizedFileURL
        guard FileManager.default.fileExists(atPath: xcresultURL.path) else {
            throw ValidationError("xcresult not found: \(xcresultURL.path)")
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // Load config
        let configURL = URL(fileURLWithPath: config, relativeTo: cwd).standardizedFileURL
        var cfg = Config()
        if FileManager.default.fileExists(atPath: configURL.path) {
            cfg = try Config.load(from: configURL)
        }

        // Resolve options: CLI > config > hardcoded default
        let resolvedOutput   = output  ?? cfg.output  ?? "coverage"
        let resolvedJobs     = jobs    ?? cfg.jobs     ?? ProcessInfo.processInfo.activeProcessorCount
        let resolvedTitle    = title   ?? cfg.title    ?? "fullcoverage"
        let resolvedTarget   = target  ?? cfg.target
        let resolvedSort     = sort    ?? sortOrderFromString(cfg.sort) ?? .name
        let resolvedGroupBy  = groupBy ?? .none
        let resolvedMinLines     = minLines     ?? cfg.minLines
        let resolvedMinBranches  = minBranches  ?? cfg.minBranches
        let resolvedMinFunctions = minFunctions ?? cfg.minFunctions

        let ignorePatterns = cfg.ignore + ignore
        let includePatterns = cfg.include + include

        let outputURL = URL(fileURLWithPath: resolvedOutput, relativeTo: cwd).standardizedFileURL

        // Parse coverage
        print("Reading coverage from \(xcresultURL.lastPathComponent)…")
        var reports = try buildReports(
            xcresult: xcresultURL,
            maxWorkers: resolvedJobs,
            targetFilter: resolvedTarget
        ) { done, total in
            FileHandle.standardOutput.write(
                Data("\r  Fetching line data… \(done)/\(total)  ".utf8)
            )
        }
        print() // end progress line
        print("  \(reports.count) file(s) parsed.")

        // Apply include/ignore filters
        if !includePatterns.isEmpty {
            reports = reports.filter { shouldInclude(path: $0.filename, patterns: includePatterns) }
        }
        if !ignorePatterns.isEmpty {
            reports = reports.filter { !shouldIgnore(path: $0.filename, patterns: ignorePatterns) }
        }
        if !includePatterns.isEmpty || !ignorePatterns.isEmpty {
            print("  \(reports.count) file(s) after filters.")
        }

        // Compute totals
        var tLines = 0, tLinesCov = 0
        var tBranches = 0, tBranchesCov = 0
        var tFuncs = 0, tFuncsCov = 0
        for r in reports {
            tLines += r.summary.executableLines
            tLinesCov += r.summary.coveredLines
            tBranches += r.branchCount
            tBranchesCov += r.coveredBranches
            tFuncs += r.summary.functions.count
            tFuncsCov += r.summary.coveredFunctions
        }
        func pct(_ c: Int, _ t: Int) -> Double { t == 0 ? 0 : Double(c) / Double(t) * 100 }
        let linesPct     = pct(tLinesCov, tLines)
        let branchesPct  = pct(tBranchesCov, tBranches)
        let funcsPct     = pct(tFuncsCov, tFuncs)

        // Determine output modes
        let generateHTML = format == .html || format == .all
        let generateJSON = format == .json || format == .all

        // Load CODEOWNERS if grouping by it
        var co: Codeowners? = nil
        if resolvedGroupBy == .codeowners {
            if let coPath = codeowners {
                co = try Codeowners.load(from: URL(fileURLWithPath: coPath, relativeTo: cwd))
            } else if let found = Codeowners.find(startingAt: cwd) {
                co = try Codeowners.load(from: found)
            }
        }

        // Generate report
        print("Generating report in \(outputURL.path)…")
        let opts = GenerateOptions(
            title: resolvedTitle,
            sort: resolvedSort,
            groupBy: resolvedGroupBy,
            codeowners: co,
            generateHTML: generateHTML,
            generateJSON: generateJSON
        )
        try generate(reports: reports, outputDir: outputURL, options: opts)

        if generateHTML {
            try writeGitHubSummary(reports: reports, title: resolvedTitle)
            print("Done. Open \(outputURL.appendingPathComponent("index.html").path)")
        }
        if generateJSON {
            print("  JSON: \(outputURL.appendingPathComponent("coverage.json").path)")
        }

        // SVG badge
        if let badgePath = badge {
            let badgeURL = URL(fileURLWithPath: badgePath, relativeTo: cwd).standardizedFileURL
            let svg = generateSVGBadge(pct: linesPct / 100)
            try svg.write(to: badgeURL, atomically: true, encoding: .utf8)
            print("Badge: \(badgeURL.path)")
        }

        // Open in browser
        if open, generateHTML {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = [outputURL.appendingPathComponent("index.html").path]
            try proc.run()
        }

        // CI threshold gate — runs after outputs are written so the report is
        // still available even when the build fails.
        var failures: [String] = []
        if let min = resolvedMinLines, linesPct < min {
            failures.append("Line coverage \(pctStr(linesPct))% < \(pctStr(min))% required")
        }
        if let min = resolvedMinBranches, branchesPct < min {
            failures.append("Branch coverage \(pctStr(branchesPct))% < \(pctStr(min))% required")
        }
        if let min = resolvedMinFunctions, funcsPct < min {
            failures.append("Function coverage \(pctStr(funcsPct))% < \(pctStr(min))% required")
        }

        if !failures.isEmpty {
            fputs("\nCoverage threshold failure(s):\n", stderr)
            for f in failures { fputs("  • \(f)\n", stderr) }
            Foundation.exit(1)
        }
    }
}

// MARK: - Helpers

private func pctStr(_ d: Double) -> String { String(format: "%.1f", d) }

private func sortOrderFromString(_ s: String?) -> SortOrder? {
    guard let s else { return nil }
    return SortOrder(rawValue: s)
}
