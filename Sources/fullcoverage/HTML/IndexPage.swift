import Foundation

func renderIndex(
    reports: [FileReport],
    title: String = "fullcoverage",
    sort: SortOrder = .name,
    groupBy: GroupBy = .none,
    codeowners: Codeowners? = nil
) -> String {
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

    let visible = reports.filter { $0.summary.executableLines > 0 }
    let sorted = applySortOrder(sort, to: visible)

    let tbody: String
    switch groupBy {
    case .none:
        tbody = sorted.map(fileRow).joined(separator: "\n")
    case .target:
        tbody = renderGroups(sorted, label: { $0.targetName })
    case .codeowners:
        let co = codeowners
        tbody = renderGroups(sorted, label: { co?.groupLabel(for: $0.filename) ?? "Unowned" })
    }

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
      <div class="filter-row">
        <input class="filter-input" id="filter" type="text" placeholder="Filter files…" autocomplete="off">
      </div>
      <table class="coverage-table">
        <thead>
          <tr>
            <th class="sortable" data-col="0">File</th>
            <th class="sortable" data-col="1">Target</th>
            <th class="sortable" data-col="2">Lines</th><th></th>
            <th class="sortable" data-col="4">Branches</th><th></th>
            <th class="sortable" data-col="6">Functions</th><th></th>
          </tr>
        </thead>
        <tbody>
    \(tbody)
        </tbody>
      </table>
      <script>
    (function(){
      // ── Search/filter ──────────────────────────────────────────────────
      var input=document.getElementById('filter');
      input.addEventListener('input',function(){
        var q=this.value.toLowerCase();
        document.querySelectorAll('.coverage-table tbody tr:not(.group-header):not(.group-subtotal)').forEach(function(row){
          row.style.display=row.textContent.toLowerCase().includes(q)?'':'none';
        });
      });

      // ── Sortable columns ───────────────────────────────────────────────
      var table=document.querySelector('.coverage-table');
      var headers=table.querySelectorAll('th[data-col]');
      var state={col:-1,asc:true};
      headers.forEach(function(th){
        th.addEventListener('click',function(){
          var col=parseInt(th.dataset.col);
          state.asc=(state.col===col)?!state.asc:(col===0||col===1);
          state.col=col;
          headers.forEach(function(h){h.removeAttribute('data-sort-dir');});
          th.dataset.sortDir=state.asc?'asc':'desc';
          var tbody=table.querySelector('tbody');
          var rows=Array.from(tbody.querySelectorAll('tr:not(.group-header):not(.group-subtotal)'));
          rows.sort(function(a,b){
            var av=cellVal(a,col),bv=cellVal(b,col);
            if(av<bv)return state.asc?-1:1;
            if(av>bv)return state.asc?1:-1;
            return 0;
          });
          rows.forEach(function(r){tbody.appendChild(r);});
        });
      });
      function cellVal(row,col){
        var cell=row.cells[col];if(!cell)return'';
        var pct=cell.querySelector('.pct');
        if(pct)return parseFloat(pct.textContent)||0;
        return cell.textContent.trim().toLowerCase();
      }
    })();
      </script>
    </body>
    </html>
    """
}

// MARK: - Sorting

func applySortOrder(_ sort: SortOrder, to reports: [FileReport]) -> [FileReport] {
    switch sort {
    case .name:
        return reports.sorted { $0.filename < $1.filename }
    case .coverage, .lines:
        return reports.sorted { $0.summary.lineCoverage < $1.summary.lineCoverage }
    case .branches:
        return reports.sorted { $0.branchCoverage < $1.branchCoverage }
    case .functions:
        return reports.sorted { $0.summary.functionCoverage < $1.summary.functionCoverage }
    }
}

// MARK: - Grouping

private func renderGroups(_ reports: [FileReport], label: (FileReport) -> String) -> String {
    // Preserve group order based on first appearance
    var groupOrder: [String] = []
    var groups: [String: [FileReport]] = [:]
    for r in reports {
        let key = label(r)
        if groups[key] == nil { groupOrder.append(key) }
        groups[key, default: []].append(r)
    }

    return groupOrder.flatMap { key -> [String] in
        let members = groups[key]!
        var rows: [String] = []
        rows.append("""
            <tr class="group-header">
              <td colspan="8">\(htmlEscape(key))</td>
            </tr>
            """)
        rows.append(contentsOf: members.map(fileRow))
        rows.append(subtotalRow(for: members))
        return rows
    }.joined(separator: "\n")
}

private func subtotalRow(for reports: [FileReport]) -> String {
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
    func pct(_ c: Int, _ t: Int) -> Double { t == 0 ? 0 : Double(c) / Double(t) }
    let lp = pct(tLinesCov, tLines)
    let bp = pct(tBranchesCov, tBranches)
    let fp = pct(tFuncsCov, tFuncs)
    let branchCell = tBranches > 0
        ? "<span class=\"pct \(cls(bp))\">\(fmt(bp))</span>"
        : "<span class=\"muted\">—</span>"
    let branchBar = tBranches > 0 ? bar(bp) : ""
    return """
        <tr class="group-subtotal">
          <td colspan="2">Subtotal (\(reports.count) files)</td>
          <td><span class="pct \(cls(lp))">\(fmt(lp))</span></td>
          <td class="bar-cell">\(bar(lp))</td>
          <td>\(branchCell)</td>
          <td class="bar-cell">\(branchBar)</td>
          <td><span class="pct \(cls(fp))">\(fmt(fp))</span></td>
          <td class="bar-cell">\(bar(fp))</td>
        </tr>
        """
}

// MARK: - Row rendering

private func fileRow(_ r: FileReport) -> String {
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
          <td><a href="\(href)">\(htmlEscape(name))</a></td>
          <td class="muted">\(htmlEscape(r.targetName))</td>
          <td><span class="pct \(cls(lp))">\(fmt(lp))</span></td>
          <td class="bar-cell">\(bar(lp))</td>
          <td>\(branchCell)</td>
          <td class="bar-cell">\(branchBar)</td>
          <td><span class="pct \(cls(fp))">\(fmt(fp))</span></td>
          <td class="bar-cell">\(bar(fp))</td>
        </tr>
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

private func htmlEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
}
