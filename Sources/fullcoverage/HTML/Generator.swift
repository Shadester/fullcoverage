import Foundation

struct GenerateOptions {
    var title: String = "fullcoverage"
    var sort: SortOrder = .name
    var groupBy: GroupBy = .none
    var codeowners: Codeowners? = nil
    var generateHTML: Bool = true
    var generateJSON: Bool = false
}

func generate(reports: [FileReport], outputDir: URL, options: GenerateOptions = GenerateOptions()) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

    if options.generateHTML {
        let filesDir = outputDir.appendingPathComponent("files")
        try fm.createDirectory(at: filesDir, withIntermediateDirectories: true)

        // Copy stylesheet
        guard let cssSource = Bundle.module.url(forResource: "style", withExtension: "css") else {
            throw NSError(domain: "fullcoverage", code: 1, userInfo: [NSLocalizedDescriptionKey: "style.css not found in bundle"])
        }
        let cssDest = outputDir.appendingPathComponent("style.css")
        if fm.fileExists(atPath: cssDest.path) { try fm.removeItem(at: cssDest) }
        try fm.copyItem(at: cssSource, to: cssDest)

        // Write index
        let indexHTML = renderIndex(
            reports: reports,
            title: options.title,
            sort: options.sort,
            groupBy: options.groupBy,
            codeowners: options.codeowners
        )
        try indexHTML.write(to: outputDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        // Write per-file pages
        for report in reports where report.summary.executableLines > 0 {
            let href = fileHref(filename: report.filename)
            let dest = outputDir.appendingPathComponent(href)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            let pageHTML = renderFilePage(report: report)
            try pageHTML.write(to: dest, atomically: true, encoding: .utf8)
        }
    }

    if options.generateJSON {
        let jsonData = try buildJSON(reports: reports)
        try jsonData.write(to: outputDir.appendingPathComponent("coverage.json"))
    }
}

func fileHref(filename: String) -> String {
    let url = URL(fileURLWithPath: filename)
    let parts = url.pathComponents
    let name = parts.count >= 2
        ? "\(parts[parts.count - 2])__\(parts[parts.count - 1])"
        : url.lastPathComponent
    let safe = name.replacingOccurrences(of: " ", with: "_")
    return "files/\(safe).html"
}
