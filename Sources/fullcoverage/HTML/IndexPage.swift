import Foundation

func renderIndex(reports: [FileReport], title: String = "fullcoverage") -> String {
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

    func pct(_ cov: Int, _ tot: Int) -> Double { tot == 0 ? 0 : Double(cov) / Double(tot) }

    let badges = badge("Lines", cov: totalLinesCov, tot: totalLines, pct: pct(totalLinesCov, totalLines))
        + badge("Branches", cov: totalBranchesCov, tot: totalBranches, pct: pct(totalBranchesCov, totalBranches))
        + badge("Functions", cov: totalFuncsCov, tot: totalFuncs, pct: pct(totalFuncsCov, totalFuncs))

    let rows = reports
        .filter { $0.summary.executableLines > 0 }
        .sorted { $0.filename < $1.filename }
        .map { r -> String in
            let lp = r.summary.lineCoverage
            let bp = r.branchCoverage
            let fp = r.summary.functionCoverage
            let name = URL(fileURLWithPath: r.filename).lastPathComponent
            let href = fileHref(filename: r.filename)
            let branchCell = r.branchCount > 0
                ? "<span class=\"pct \(cls(bp))\">\(fmt(bp))</span>"
                : "<span class=\"muted\">—</span>"
            let branchBar = r.branchCount > 0 ? bar(bp) : ""
            return """
            <tr>
              <td><a href="\(href)">\(name)</a></td>
              <td class="muted">\(r.targetName)</td>
              <td><span class="pct \(cls(lp))">\(fmt(lp))</span></td>
              <td class="bar-cell">\(bar(lp))</td>
              <td>\(branchCell)</td>
              <td class="bar-cell">\(branchBar)</td>
              <td><span class="pct \(cls(fp))">\(fmt(fp))</span></td>
              <td class="bar-cell">\(bar(fp))</td>
            </tr>
            """
        }
        .joined(separator: "\n")

    let today = ISO8601DateFormatter().string(from: Date()).prefix(10)

    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(title)</title>
      <link rel="stylesheet" href="style.css">
    </head>
    <body>
      <div class="header">
        <h1>\(title)</h1>
        <div class="meta">Generated \(today)</div>
      </div>
      <div class="summary-badges">
        \(badges)
      </div>
      <table class="coverage-table">
        <thead>
          <tr>
            <th>File</th><th>Target</th>
            <th>Lines</th><th></th>
            <th>Branches</th><th></th>
            <th>Functions</th><th></th>
          </tr>
        </thead>
        <tbody>
    \(rows)
        </tbody>
      </table>
    </body>
    </html>
    """
}

// MARK: - Helpers

func cls(_ pct: Double) -> String {
    pct >= 0.8 ? "green" : pct >= 0.5 ? "yellow" : "red"
}

func fmt(_ pct: Double) -> String {
    String(format: "%.1f%%", pct * 100)
}

func bar(_ pct: Double) -> String {
    let w = min(100, max(0, pct * 100))
    return """
    <div class="bar-wrap"><div class="bar-fill \(cls(pct))" style="width:\(String(format: "%.1f", w))%"></div></div>
    """
}

func badge(_ label: String, cov: Int, tot: Int, pct: Double) -> String {
    """
    <div class="badge \(cls(pct))">
      <span class="label">\(label)</span>
      <span class="value">\(fmt(pct))</span>
      <span class="label">(\(cov)/\(tot))</span>
    </div>
    """
}
