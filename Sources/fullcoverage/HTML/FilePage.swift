import Foundation
import Plot

func renderFilePage(report: FileReport, backHref: String = "../index.html") -> String {
    let sourceLines: [String]
    do {
        let text = try String(contentsOfFile: report.filename, encoding: .utf8)
        // Normalize CRLF before splitting so Windows-formatted files don't
        // leave a trailing \r on every line.
        sourceLines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    } catch {
        sourceLines = ["(source not available: \(report.filename))"]
    }

    let lineMap = Dictionary(uniqueKeysWithValues: report.lines.map { ($0.line, $0) })

    let rows = Node<HTML.TableContext>.group(sourceLines.enumerated().map { (i, sourceLine) -> Node<HTML.TableContext> in
        let lineNum = i + 1
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

        return .tr(
            .class(rowClass),
            .td(.class("line-num"), .text("\(lineNum)")),
            .td(.class("hit-count"), .text(hitStr)),
            .td(.class("source-code"), .text(sourceLine))
        )
    })

    let s = report.summary
    let lp = s.lineCoverage
    let bp = report.branchCoverage
    let fp = s.functionCoverage
    let filename = URL(fileURLWithPath: report.filename).lastPathComponent

    let branchStat: Node<HTML.BodyContext> = report.branchCount > 0
        ? .span(.class("stat \(cls(bp))"),
            .span(.class("value"), .text(fmt(bp))),
            .text(" branches "),
            .span(.class("stat-detail"), .text("(\(report.coveredBranches)/\(report.branchCount))"))
          )
        : .empty

    return HTML(
        .head(
            .encoding(.utf8),
            .raw("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"),
            .title(filename),
            .stylesheet("../style.css")
        ),
        .body(
            .div(.class("back-link"), .a(.href(backHref), .text("← Back to index"))),
            .div(.class("file-header"),
                .h2(.text(filename)),
                .div(.class("file-stats"),
                    .span(.class("stat \(cls(lp))"),
                        .span(.class("value"), .text(fmt(lp))),
                        .text(" lines "),
                        .span(.class("stat-detail"), .text("(\(s.coveredLines)/\(s.executableLines))"))
                    ),
                    branchStat,
                    .span(.class("stat \(cls(fp))"),
                        .span(.class("value"), .text(fmt(fp))),
                        .text(" functions "),
                        .span(.class("stat-detail"), .text("(\(s.coveredFunctions)/\(s.functions.count))"))
                    )
                )
            ),
            .div(.class("legend"),
                .span(.class("legend-item"), .span(.class("legend-dot green")), .text(" Covered")),
                .span(.class("legend-item"), .span(.class("legend-dot yellow")), .text(" Partial")),
                .span(.class("legend-item"), .span(.class("legend-dot red")), .text(" Uncovered")),
                .span(.class("legend-item legend-hint"),
                    .text("Press "),
                    .raw("<kbd>n</kbd>"),
                    .text(" / "),
                    .raw("<kbd>p</kbd>"),
                    .text(" to jump between uncovered lines")
                )
            ),
            .table(.class("source-table"),
                .tbody(rows)
            ),
            .script(.raw("""
(function(){
  var red=Array.from(document.querySelectorAll('tr.cov-red'));
  if(!red.length)return;
  var cur=-1;
  document.addEventListener('keydown',function(e){
    if(e.target.tagName==='INPUT'||e.target.tagName==='TEXTAREA')return;
    if(e.key==='n'){cur=(cur+1)%red.length;red[cur].scrollIntoView({block:'center'});}
    if(e.key==='p'){cur=(cur-1+red.length)%red.length;red[cur].scrollIntoView({block:'center'});}
  });
})();
"""))
        )
    ).render()
}
