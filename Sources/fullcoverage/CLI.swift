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

    mutating func run() throws {
        let xcresultURL = URL(fileURLWithPath: xcresult).standardizedFileURL
        guard FileManager.default.fileExists(atPath: xcresultURL.path) else {
            throw ValidationError("xcresult not found: \(xcresultURL.path)")
        }

        let outputURL = URL(fileURLWithPath: output).standardizedFileURL

        print("Reading coverage from \(xcresultURL.lastPathComponent)…")
        let reports = try buildReports(xcresult: xcresultURL, maxWorkers: jobs)
        print("  \(reports.count) file(s) parsed.")

        print("Generating HTML report in \(outputURL.path)…")
        try generate(reports: reports, outputDir: outputURL)
        print("Done. Open \(outputURL.appendingPathComponent("index.html").path)")
    }
}
