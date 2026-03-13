import Foundation

func renderFilePage(report: FileReport, backHref: String = "../index.html") -> String {
    let sourceLines: [String]
    do {
        let text = try String(contentsOfFile: report.filename, encoding: .utf8)
        sourceLines = text.components(separatedBy: "\n")
    } catch {
        sourceLines = ["(source not available: \(report.filename))"]
    }

    let lineMap = Dictionary(uniqueKeysWithValues: report.lines.map { ($0.line, $0) })

    let rows = sourceLines.enumerated().map { (i, sourceLine) -> String in
        let lineNum = i + 1
        let escaped = sourceLine
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let rowClass: String
        let hitStr: String

        if let li = lineMap[lineNum], li.isExecutable {
            if li.count == 0 {
                rowClass = "cov-red"; hitStr = "0"
            } else if li.isPartial {
                rowClass = "cov-yellow"; hitStr = "\(li.count)"
            } else {
                rowClass = "cov-green"; hitStr = "\(li.count)"
            }
        } else {
            rowClass = ""; hitStr = ""
        }

        return """
        <tr class="\(rowClass)">
          <td class="line-num">\(lineNum)</td>
          <td class="hit-count">\(hitStr)</td>
          <td class="source-code">\(escaped)</td>
        </tr>
        """
    }.joined(separator: "\n")

    let s = report.summary
    let lp = s.lineCoverage
    let bp = report.branchCoverage
    let fp = s.functionCoverage
    let filename = URL(fileURLWithPath: report.filename).lastPathComponent

    let branchStat = report.branchCount > 0
        ? "<span class=\"stat \(cls(bp))\"><span class=\"value\">\(fmt(bp))</span> branches <span class=\"stat-detail\">(\(report.coveredBranches)/\(report.branchCount))</span></span>"
        : ""

    let stats = """
    <div class="file-stats">
      <span class="stat \(cls(lp))"><span class="value">\(fmt(lp))</span> lines <span class="stat-detail">(\(s.coveredLines)/\(s.executableLines))</span></span>
      \(branchStat)
      <span class="stat \(cls(fp))"><span class="value">\(fmt(fp))</span> functions <span class="stat-detail">(\(s.coveredFunctions)/\(s.functions.count))</span></span>
    </div>
    """

    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(filename)</title>
      <link rel="stylesheet" href="../style.css">
    </head>
    <body>
      <div class="back-link"><a href="\(backHref)">← Back to index</a></div>
      <div class="file-header">
        <h2>\(filename)</h2>
        \(stats)
      </div>
      <div class="legend">
        <span class="legend-item"><span class="legend-dot green"></span> Covered</span>
        <span class="legend-item"><span class="legend-dot yellow"></span> Partial</span>
        <span class="legend-item"><span class="legend-dot red"></span> Uncovered</span>
      </div>
      <table class="source-table">
        <tbody>
    \(rows)
        </tbody>
      </table>
    </body>
    </html>
    """
}
