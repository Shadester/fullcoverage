import Foundation
import Yams

enum SlatherConfig {
    static func loadIgnorePatterns(from url: URL) throws -> [String] {
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let dict = try Yams.load(yaml: text) as? [String: Any] else { return [] }
        return dict["ignore"] as? [String] ?? []
    }
}
