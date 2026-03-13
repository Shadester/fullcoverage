struct LineInfo {
    let line: Int
    let isExecutable: Bool
    let count: Int
    let isPartial: Bool
    let branchCount: Int
    let coveredBranches: Int
}

struct FunctionInfo {
    let name: String
    let lineNumber: Int
    let executionCount: Int
    let lineCoverage: Double
    let coveredLines: Int
    let executableLines: Int
}

struct FileSummary {
    let coveredLines: Int
    let executableLines: Int
    let lineCoverage: Double
    let functions: [FunctionInfo]

    var coveredFunctions: Int { functions.filter { $0.executionCount > 0 }.count }
    var functionCoverage: Double {
        functions.isEmpty ? 0 : Double(coveredFunctions) / Double(functions.count)
    }
}

struct FileReport {
    let filename: String
    let targetName: String
    let summary: FileSummary
    var lines: [LineInfo]

    var branchCount: Int { lines.reduce(0) { $0 + $1.branchCount } }
    var coveredBranches: Int { lines.reduce(0) { $0 + $1.coveredBranches } }
    var branchCoverage: Double {
        branchCount == 0 ? 0 : Double(coveredBranches) / Double(branchCount)
    }
}
