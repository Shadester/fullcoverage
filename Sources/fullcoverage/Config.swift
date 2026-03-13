import Foundation
import Yams

struct Config {
    var ignore: [String] = []
    var include: [String] = []
    var output: String? = nil
    var jobs: Int? = nil
    var title: String? = nil
    var minLines: Double? = nil
    var minBranches: Double? = nil
    var minFunctions: Double? = nil
    var target: String? = nil
    var sort: String? = nil

    static func load(from url: URL) throws -> Config {
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let dict = try Yams.load(yaml: text) as? [String: Any] else { return Config() }
        var config = Config()
        config.ignore = dict["ignore"] as? [String] ?? []
        config.include = dict["include"] as? [String] ?? []
        config.output = dict["output"] as? String
        config.title = dict["title"] as? String
        config.target = dict["target"] as? String
        config.sort = dict["sort"] as? String
        if let j = dict["jobs"] as? Int { config.jobs = j }
        if let v = dict["min_lines"] { config.minLines = asDouble(v) }
        if let v = dict["min_branches"] { config.minBranches = asDouble(v) }
        if let v = dict["min_functions"] { config.minFunctions = asDouble(v) }
        return config
    }
}

private func asDouble(_ value: Any) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    return nil
}
