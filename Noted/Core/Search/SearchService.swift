import Foundation

enum SearchService {
    static func document(for item: Item) -> String {
        Item.normalize(([item.title, item.body, item.originalURL, item.ocrText] + item.tags).joined(separator: " "))
    }

    static func matches(item: Item, query: String) -> Bool {
        guard item.trashedAt == nil else { return false }
        let tokens = Item.normalize(query).split(whereSeparator: \.isWhitespace)
        let document = document(for: item)
        return tokens.allSatisfy { document.contains($0) }
    }
}
