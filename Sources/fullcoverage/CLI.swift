import ArgumentParser
import Foundation

@main
struct Fullcoverage: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fullcoverage",
        abstract: "Generate an HTML coverage report from an Xcode .xcresult bundle."
    )

    @Argument(help: "Path to the .xcresult bundle.")
    var xcresult: String

    @Option(name: .shortAndLong, help: "Output directory.")
    var output: String = "coverage"

    @Option(name: .shortAndLong, help: "Parallel workers for xccov calls.")
    var jobs: Int = 8

    @Option(name: .long, help: "Glob patterns for files to exclude (repeatable).")
    var ignore: [String] = []

    @Option(name: .long, help: "Path to config file (default: .fullcoverage.yml).")
    var config: String = ".fullcoverage.yml"

    mutating func run() throws {
        let xcresultURL = URL(fileURLWithPath: xcresult).standardizedFileURL
        guard FileManager.default.fileExists(atPath: xcresultURL.path) else {
            throw ValidationError("xcresult not found: \(xcresultURL.path)")
        }

        let outputURL = URL(fileURLWithPath: output).standardizedFileURL

        // Load config file, merge ignore patterns (CLI flags take precedence / extend)
        let configURL = URL(fileURLWithPath: config, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
        var ignorePatterns: [String] = []
        if FileManager.default.fileExists(atPath: configURL.path) {
            let cfg = try Config.load(from: configURL)
            ignorePatterns = cfg.ignore
        }
        ignorePatterns += ignore

        print("Reading coverage from \(xcresultURL.lastPathComponent)…")
        var reports = try buildReports(xcresult: xcresultURL, maxWorkers: jobs)
        print("  \(reports.count) file(s) parsed.")

        if !ignorePatterns.isEmpty {
            reports = reports.filter { !shouldIgnore(path: $0.filename, patterns: ignorePatterns) }
            print("  \(reports.count) file(s) after ignore filters.")
        }

        print("Generating HTML report in \(outputURL.path)…")
        try generate(reports: reports, outputDir: outputURL)
        print("Done. Open \(outputURL.appendingPathComponent("index.html").path)")
    }
}
