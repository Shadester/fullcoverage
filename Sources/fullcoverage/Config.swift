import Foundation
import Yams

struct Config {
    var ignore: [String] = []

    static func load(from url: URL) throws -> Config {
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let dict = try Yams.load(yaml: text) as? [String: Any] else { return Config() }
        var config = Config()
        config.ignore = dict["ignore"] as? [String] ?? []
        return config
    }
}
