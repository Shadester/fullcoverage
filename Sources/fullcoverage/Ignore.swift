import Foundation

func shouldIgnore(path: String, patterns: [String]) -> Bool {
    patterns.contains { pattern in
        NSPredicate(format: "SELF LIKE %@", pattern).evaluate(with: path)
    }
}
