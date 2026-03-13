import Foundation

func writeGitHubSummary(reports: [FileReport], title: String) throws {
    guard let summaryPath = ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"],
          !summaryPath.isEmpty else { return }

    var totalLines = 0, totalLinesCov = 0
    var totalBranches = 0, totalBranchesCov = 0
    var totalFuncs = 0, totalFuncsCov = 0
    for r in reports {
        totalLines += r.summary.executableLines
        totalLinesCov += r.summary.coveredLines
        totalBranches += r.branchCount
        totalBranchesCov += r.coveredBranches
        totalFuncs += r.summary.functions.count
        totalFuncsCov += r.summary.coveredFunctions
    }

    func pct(_ c: Int, _ t: Int) -> Double { t == 0 ? 0 : Double(c) / Double(t) }
    func fmtPct(_ d: Double) -> String { String(format: "%.1f%%", d * 100) }
    func icon(_ d: Double) -> String { d >= 0.8 ? "🟢" : d >= 0.5 ? "🟡" : "🔴" }

    let lp = pct(totalLinesCov, totalLines)
    let bp = pct(totalBranchesCov, totalBranches)
    let fp = pct(totalFuncsCov, totalFuncs)

    var md = "## \(title) — Coverage Report\n\n"
    md += "| Metric | Coverage |\n|---|---|\n"
    md += "| Lines | \(icon(lp)) **\(fmtPct(lp))** (\(totalLinesCov)/\(totalLines)) |\n"
    md += "| Branches | \(icon(bp)) **\(fmtPct(bp))** (\(totalBranchesCov)/\(totalBranches)) |\n"
    md += "| Functions | \(icon(fp)) **\(fmtPct(fp))** (\(totalFuncsCov)/\(totalFuncs)) |\n\n"

    let worst = reports
        .filter { $0.summary.executableLines > 0 }
        .sorted { $0.summary.lineCoverage < $1.summary.lineCoverage }
        .prefix(10)

    if !worst.isEmpty {
        md += "<details><summary>10 files with lowest line coverage</summary>\n\n"
        md += "| File | Lines | Branches | Functions |\n|---|---|---|---|\n"
        for r in worst {
            let name = URL(fileURLWithPath: r.filename).lastPathComponent
            let lp2 = r.summary.lineCoverage
            let bp2 = r.branchCoverage
            let fp2 = r.summary.functionCoverage
            let bCell = r.branchCount > 0 ? "\(icon(bp2)) \(fmtPct(bp2))" : "—"
            md += "| `\(name)` | \(icon(lp2)) \(fmtPct(lp2)) | \(bCell) | \(icon(fp2)) \(fmtPct(fp2)) |\n"
        }
        md += "\n</details>\n"
    }

    let url = URL(fileURLWithPath: summaryPath)
    if var existing = try? Data(contentsOf: url) {
        existing.append(contentsOf: md.utf8)
        try existing.write(to: url)
    } else {
        try Data(md.utf8).write(to: url)
    }
}
