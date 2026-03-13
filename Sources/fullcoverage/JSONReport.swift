import Foundation

private struct CoverageReport: Encodable {
    struct Metric: Encodable {
        let covered: Int
        let total: Int
        let pct: Double
    }
    struct Totals: Encodable {
        let lines: Metric
        let branches: Metric
        let functions: Metric
    }
    struct FileCoverage: Encodable {
        let path: String
        let target: String
        let lines: Metric
        let branches: Metric
        let functions: Metric
    }
    let generatedAt: String
    let totals: Totals
    let files: [FileCoverage]
}

func buildJSON(reports: [FileReport]) throws -> Data {
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
    func metric(_ c: Int, _ t: Int) -> CoverageReport.Metric { .init(covered: c, total: t, pct: pct(c, t)) }

    let files = reports
        .filter { $0.summary.executableLines > 0 }
        .map { r in
            CoverageReport.FileCoverage(
                path: r.filename,
                target: r.targetName,
                lines: metric(r.summary.coveredLines, r.summary.executableLines),
                branches: metric(r.coveredBranches, r.branchCount),
                functions: metric(r.summary.coveredFunctions, r.summary.functions.count)
            )
        }

    let report = CoverageReport(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        totals: .init(
            lines: metric(tLinesCov, tLines),
            branches: metric(tBranchesCov, tBranches),
            functions: metric(tFuncsCov, tFuncs)
        ),
        files: files
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(report)
}
