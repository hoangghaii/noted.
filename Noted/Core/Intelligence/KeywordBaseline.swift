import Foundation

/// Explicitly a lexical comparison point, never an AI prediction.
struct KeywordBaseline {
    struct Topic {
        let name: String
        let aliases: [String]
    }

    static func predict(_ text: String, topics: [Topic]) -> String? {
        let normalized = " " + normalize(text) + " "
        let scored: [(String, Int)] = topics.map { topic in
            let hits = topic.aliases.reduce(into: 0) { count, alias in
                let term = normalize(alias)
                if !term.isEmpty && normalized.contains(" \(term) ") { count += 1 }
            }
            return (topic.name, hits)
        }.sorted { left, right in
            left.1 == right.1 ? left.0 < right.0 : left.1 > right.1
        }
        guard let top = scored.first, top.1 > 0,
              scored.dropFirst().first?.1 != top.1 else { return nil }
        return top.0
    }

    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased().replacingOccurrences(of: "đ", with: "d")
        return folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }
}
