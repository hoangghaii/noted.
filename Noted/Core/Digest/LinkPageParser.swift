import Foundation

/// Fields read from one HTML page. Values are entity-decoded with whitespace collapsed; nil when absent or empty.
struct LinkPageFields: Equatable {
    var htmlTitle: String?
    var ogTitle: String?
    var twitterTitle: String?
    var ogDescription: String?
    var twitterDescription: String?
    var metaDescription: String?
    var siteName: String?
    var articleAuthor: String?
    var jsonLD = JSONLDFields()
    var hasJSONLD = false
    /// Reader-mode text: paragraphs of <article>, else <main>, else the container with the most paragraph text.
    var mainText = ""

    struct JSONLDFields: Equatable {
        var headline: String?
        var description: String?
        var articleBody: String?
        var authorName: String?
    }

    /// First description in priority order og → twitter → meta, with its source.
    var description: (text: String, source: String)? {
        if let ogDescription { return (ogDescription, "og") }
        if let twitterDescription { return (twitterDescription, "twitter") }
        if let metaDescription { return (metaDescription, "meta") }
        return nil
    }
}

enum LinkPageParser {
    /// Elements whose text is never part of the main content.
    static let skippedElements: Set<String> = [
        "script", "style", "noscript", "svg", "template", "nav", "header", "footer", "aside", "form", "button", "select"
    ]
    static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"
    ]
    static let minimumParagraphLength = 20

    static func parse(_ html: String) -> LinkPageFields {
        var fields = LinkPageFields()
        var meta: [String: String] = [:]
        var stack: [(name: String, id: Int)] = []
        var nextID = 0
        var skipDepth = 0, articleDepth = 0, mainDepth = 0
        var paragraph: (text: String, container: Int, inArticle: Bool, inMain: Bool)?
        var paragraphs: [(text: String, container: Int, inArticle: Bool, inMain: Bool)] = []

        func closeParagraph() {
            guard let current = paragraph else { return }
            paragraph = nil
            let text = collapse(decodeEntities(current.text))
            if text.count >= minimumParagraphLength {
                paragraphs.append((text, current.container, current.inArticle, current.inMain))
            }
        }
        func pop(through index: Int) {
            while stack.count > index {
                let element = stack.removeLast()
                if skippedElements.contains(element.name) { skipDepth -= 1 }
                if element.name == "article" { articleDepth -= 1 }
                if element.name == "main" { mainDepth -= 1 }
                if element.name == "p" { closeParagraph() }
            }
        }

        HTMLTokenizer.tokenize(html) { token in
            switch token {
            case let .start(name, attributes):
                if name == "meta" {
                    if let key = attributes["property"] ?? attributes["name"] ?? attributes["itemprop"],
                       let content = attributes["content"], meta[key.lowercased()] == nil {
                        meta[key.lowercased()] = content
                    }
                    return
                }
                if name == "br" { paragraph?.text += " " }
                if voidElements.contains(name) { return }
                if name == "p", let open = stack.lastIndex(where: { $0.name == "p" }) { pop(through: open) }
                nextID += 1
                if name == "p", skipDepth == 0 {
                    paragraph = ("", stack.last?.id ?? 0, articleDepth > 0, mainDepth > 0)
                }
                stack.append((name, nextID))
                if skippedElements.contains(name) { skipDepth += 1 }
                if name == "article" { articleDepth += 1 }
                if name == "main" { mainDepth += 1 }
            case let .end(name):
                if let open = stack.lastIndex(where: { $0.name == name }) { pop(through: open) }
            case let .text(text):
                if skipDepth == 0, paragraph != nil { paragraph?.text += text }
            case let .raw(name, attributes, content):
                if name == "title", fields.htmlTitle == nil, !stack.contains(where: { $0.name == "svg" }) {
                    fields.htmlTitle = nonEmpty(collapse(decodeEntities(content)))
                } else if name == "script", attributes["type"]?.lowercased().contains("ld+json") == true {
                    fields.hasJSONLD = true
                    readJSONLD(content, into: &fields.jsonLD)
                }
            }
        }
        pop(through: 0)

        func value(_ key: String) -> String? { meta[key].flatMap { nonEmpty(collapse(decodeEntities($0))) } }
        fields.ogTitle = value("og:title")
        fields.twitterTitle = value("twitter:title")
        fields.ogDescription = value("og:description")
        fields.twitterDescription = value("twitter:description")
        fields.metaDescription = value("description")
        fields.siteName = value("og:site_name")
        fields.articleAuthor = value("article:author") ?? value("author")
        fields.mainText = selectMainText(paragraphs)
        return fields
    }

    /// All text of an HTML fragment (e.g. an oEmbed `html` value), scripts and styles excluded.
    static func plainText(_ html: String) -> String {
        var parts: [String] = []
        HTMLTokenizer.tokenize(html) { token in
            if case let .text(text) = token { parts.append(text) }
        }
        return collapse(decodeEntities(parts.joined(separator: " ")))
    }

    private static func selectMainText(_ paragraphs: [(text: String, container: Int, inArticle: Bool, inMain: Bool)]) -> String {
        let article = paragraphs.filter(\.inArticle)
        if !article.isEmpty { return article.map(\.text).joined(separator: "\n") }
        let main = paragraphs.filter(\.inMain)
        if !main.isEmpty { return main.map(\.text).joined(separator: "\n") }
        // The container whose paragraphs hold the most text.
        let totals = Dictionary(grouping: paragraphs, by: \.container).mapValues { $0.reduce(0) { $0 + $1.text.count } }
        guard let best = totals.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) })?.key else { return "" }
        return paragraphs.filter { $0.container == best }.map(\.text).joined(separator: "\n")
    }

    /// Reads the first Article-like object. Iterative walk with a node budget, no recursion.
    private static func readJSONLD(_ content: String, into fields: inout LinkPageFields.JSONLDFields) {
        guard let data = content.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else { return }
        var queue: [Any] = [root]
        var visited = 0
        while !queue.isEmpty, visited < 200 {
            visited += 1
            let node = queue.removeFirst()
            if let array = node as? [Any] { queue.append(contentsOf: array); continue }
            guard let object = node as? [String: Any] else { continue }
            if let graph = object["@graph"] as? [Any] { queue.append(contentsOf: graph) }
            let types = (object["@type"] as? String).map { [$0] } ?? (object["@type"] as? [String] ?? [])
            let articleLike = object["headline"] != nil || object["articleBody"] != nil ||
                types.contains { $0.hasSuffix("Article") || $0.hasSuffix("Posting") }
            guard articleLike else { continue }
            func text(_ key: String) -> String? { (object[key] as? String).flatMap { nonEmpty(collapse(decodeEntities($0))) } }
            fields.headline = fields.headline ?? text("headline") ?? text("name")
            fields.description = fields.description ?? text("description")
            fields.articleBody = fields.articleBody ?? text("articleBody")
            fields.authorName = fields.authorName ?? authorName(object["author"])
        }
    }

    private static func authorName(_ value: Any?) -> String? {
        if let name = value as? String { return nonEmpty(collapse(name)) }
        if let object = value as? [String: Any] { return (object["name"] as? String).flatMap { nonEmpty(collapse($0)) } }
        if let array = value as? [Any] { return array.lazy.compactMap(authorName).first }
        return nil
    }

    // MARK: Text helpers

    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func nonEmpty(_ text: String) -> String? { text.isEmpty ? nil : text }

    static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "hellip": "…", "ndash": "–", "mdash": "—", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "laquo": "«", "raquo": "»", "bull": "•", "middot": "·", "copy": "©", "reg": "®", "trade": "™", "deg": "°",
        "agrave": "à", "aacute": "á", "acirc": "â", "atilde": "ã", "egrave": "è", "eacute": "é", "ecirc": "ê",
        "igrave": "ì", "iacute": "í", "ograve": "ò", "oacute": "ó", "ocirc": "ô", "otilde": "õ",
        "ugrave": "ù", "uacute": "ú", "yacute": "ý",
        "Agrave": "À", "Aacute": "Á", "Acirc": "Â", "Atilde": "Ã", "Egrave": "È", "Eacute": "É", "Ecirc": "Ê",
        "Igrave": "Ì", "Iacute": "Í", "Ograve": "Ò", "Oacute": "Ó", "Ocirc": "Ô", "Otilde": "Õ",
        "Ugrave": "Ù", "Uacute": "Ú", "Yacute": "Ý"
    ]

    /// Decodes numeric (`&#7871;`, `&#x1EBF;`) and common named entities; unknown entities are kept verbatim.
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character == "&", let semicolon = text[index...].prefix(12).firstIndex(of: ";") else {
                result.append(character)
                index = text.index(after: index)
                continue
            }
            let body = text[text.index(after: index)..<semicolon]
            var decoded: String?
            if body.hasPrefix("#x") || body.hasPrefix("#X") {
                decoded = UInt32(body.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
            } else if body.hasPrefix("#") {
                decoded = UInt32(body.dropFirst(), radix: 10).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
            } else {
                decoded = namedEntities[String(body)]
            }
            if let decoded {
                result += decoded
                index = text.index(after: semicolon)
            } else {
                result.append(character)
                index = text.index(after: index)
            }
        }
        return result
    }
}
