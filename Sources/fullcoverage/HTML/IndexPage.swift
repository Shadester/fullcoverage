import Foundation
import Plot

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

    let lp = pct(totalLinesCov, totalLines)
    let bp = pct(totalBranchesCov, totalBranches)
    let fp = pct(totalFuncsCov, totalFuncs)

    let visible = reports.filter { $0.summary.executableLines > 0 }
    let sorted = applySortOrder(sort, to: visible)

    let tbodyContent: Node<HTML.TableContext>
    switch groupBy {
    case .none:
        tbodyContent = .group(sorted.map(fileRow))
    case .target:
        tbodyContent = renderGroups(sorted, label: { $0.targetName })
    case .codeowners:
        let co = codeowners
        tbodyContent = renderGroups(sorted, label: { co?.groupLabel(for: $0.filename) ?? "Unowned" })
    }

    let today = ISO8601DateFormatter().string(from: Date()).prefix(10)

    return HTML(
        .head(
            .encoding(.utf8),
            .raw("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"),
            .title(title),
            .stylesheet("style.css")
        ),
        .body(
            .div(.class("header"),
                .h1(.text(title)),
                .div(.class("meta"), .text("Generated \(today)"))
            ),
            .div(.class("summary-badges"),
                badge("Lines", cov: totalLinesCov, tot: totalLines, pct: lp),
                badge("Branches", cov: totalBranchesCov, tot: totalBranches, pct: bp),
                badge("Functions", cov: totalFuncsCov, tot: totalFuncs, pct: fp)
            ),
            .div(.class("filter-row"),
                .input(
                    .class("filter-input"),
                    .id("filter"),
                    .type(.text),
                    .placeholder("Filter files…"),
                    .attribute(named: "autocomplete", value: "off")
                )
            ),
            .table(.class("coverage-table"),
                .thead(
                    .tr(
                        .th(.class("sortable"), .attribute(named: "data-col", value: "0"), .text("File")),
                        .th(.class("sortable"), .attribute(named: "data-col", value: "1"), .text("Target")),
                        .th(.class("sortable"), .attribute(named: "data-col", value: "2"), .text("Lines")),
                        .th(),
                        .th(.class("sortable"), .attribute(named: "data-col", value: "4"), .text("Branches")),
                        .th(),
                        .th(.class("sortable"), .attribute(named: "data-col", value: "6"), .text("Functions")),
                        .th()
                    )
                ),
                .tbody(tbodyContent)
            ),
            .script(.raw("""
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
"""))
        )
    ).render()
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

private func renderGroups(_ reports: [FileReport], label: (FileReport) -> String) -> Node<HTML.TableContext> {
    // Preserve group order based on first appearance
    var groupOrder: [String] = []
    var groups: [String: [FileReport]] = [:]
    for r in reports {
        let key = label(r)
        if groups[key] == nil { groupOrder.append(key) }
        groups[key, default: []].append(r)
    }

    return .group(groupOrder.flatMap { key -> [Node<HTML.TableContext>] in
        let members = groups[key]!
        let header = Node<HTML.TableContext>.tr(
            .class("group-header"),
            .td(.attribute(named: "colspan", value: "8"), .text(key))
        )
        return [header] + members.map(fileRow) + [subtotalRow(for: members)]
    })
}

private func subtotalRow(for reports: [FileReport]) -> Node<HTML.TableContext> {
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

    let branchCell: Node<HTML.BodyContext> = tBranches > 0
        ? .span(.class("pct \(cls(bp))"), .text(fmt(bp)))
        : .span(.class("muted"), .text("—"))
    let branchBar: Node<HTML.BodyContext> = tBranches > 0 ? bar(bp) : .empty

    return .tr(.class("group-subtotal"),
        .td(.attribute(named: "colspan", value: "2"), .text("Subtotal (\(reports.count) files)")),
        .td(.span(.class("pct \(cls(lp))"), .text(fmt(lp)))),
        .td(.class("bar-cell"), bar(lp)),
        .td(branchCell),
        .td(.class("bar-cell"), branchBar),
        .td(.span(.class("pct \(cls(fp))"), .text(fmt(fp)))),
        .td(.class("bar-cell"), bar(fp))
    )
}

// MARK: - Row rendering

private func fileRow(_ r: FileReport) -> Node<HTML.TableContext> {
    let lp = r.summary.lineCoverage
    let bp = r.branchCoverage
    let fp = r.summary.functionCoverage
    let name = URL(fileURLWithPath: r.filename).lastPathComponent
    let href = fileHref(filename: r.filename)

    let branchCell: Node<HTML.BodyContext> = r.branchCount > 0
        ? .span(.class("pct \(cls(bp))"), .text(fmt(bp)))
        : .span(.class("muted"), .text("—"))
    let branchBar: Node<HTML.BodyContext> = r.branchCount > 0 ? bar(bp) : .empty

    return .tr(
        .td(.a(.href(href), .text(name))),
        .td(.class("muted"), .text(r.targetName)),
        .td(.span(.class("pct \(cls(lp))"), .text(fmt(lp)))),
        .td(.class("bar-cell"), bar(lp)),
        .td(branchCell),
        .td(.class("bar-cell"), branchBar),
        .td(.span(.class("pct \(cls(fp))"), .text(fmt(fp)))),
        .td(.class("bar-cell"), bar(fp))
    )
}

// MARK: - Helpers

func cls(_ pct: Double) -> String {
    pct >= 0.8 ? "green" : pct >= 0.5 ? "yellow" : "red"
}

func fmt(_ pct: Double) -> String {
    String(format: "%.1f%%", pct * 100)
}

func bar(_ pct: Double) -> Node<HTML.BodyContext> {
    let w = min(100, max(0, pct * 100))
    return .div(.class("bar-wrap"),
        .div(
            .class("bar-fill \(cls(pct))"),
            .attribute(named: "style", value: "width:\(String(format: "%.1f", w))%")
        )
    )
}

func badge(_ label: String, cov: Int, tot: Int, pct: Double) -> Node<HTML.BodyContext> {
    .div(.class("badge \(cls(pct))"),
        .span(.class("label"), .text(label)),
        .span(.class("value"), .text(fmt(pct))),
        .span(.class("label"), .text("(\(cov)/\(tot))"))
    )
}
