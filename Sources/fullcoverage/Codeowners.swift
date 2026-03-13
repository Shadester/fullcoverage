import Foundation

struct Codeowners {
    struct Entry {
        let pattern: String
        let owners: [String]
    }

    let entries: [Entry]

    static func find(startingAt directory: URL) -> URL? {
        for path in ["CODEOWNERS", ".github/CODEOWNERS", "docs/CODEOWNERS"] {
            let url = directory.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    static func load(from url: URL) throws -> Codeowners {
        let text = try String(contentsOf: url, encoding: .utf8)
        let entries: [Entry] = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap { line in
                let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
                guard !parts.isEmpty else { return nil }
                return Entry(pattern: parts[0], owners: Array(parts.dropFirst()))
            }
        return Codeowners(entries: entries)
    }

    /// Returns the display label for a path. Last matching rule wins (gitignore semantics).
    func groupLabel(for path: String) -> String {
        let normalPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var result: String? = nil
        for entry in entries where !entry.owners.isEmpty {
            if patternMatches(entry.pattern, path: normalPath) {
                result = entry.owners.first
            }
        }
        return result ?? "Unowned"
    }

    private func patternMatches(_ pattern: String, path: String) -> Bool {
        var pat = pattern
        let anchored = pat.hasPrefix("/")
        if anchored { pat = String(pat.dropFirst()) }

        // Directory pattern: ends with /
        if pat.hasSuffix("/") {
            return path.hasPrefix(pat) || (!anchored && path.contains("/" + pat))
        }

        // No slash in pattern: match against filename only
        if !pat.contains("/") {
            let filename = URL(fileURLWithPath: path).lastPathComponent
            return NSPredicate(format: "SELF LIKE %@", pat).evaluate(with: filename)
        }

        // Pattern with slash: replace ** with *, match full or relative path
        let glob = pat.replacingOccurrences(of: "**", with: "*")
        if anchored {
            return NSPredicate(format: "SELF LIKE %@", glob).evaluate(with: path)
        }
        return NSPredicate(format: "SELF LIKE %@", glob).evaluate(with: path)
            || NSPredicate(format: "SELF LIKE %@", "*/" + glob).evaluate(with: path)
    }
}
