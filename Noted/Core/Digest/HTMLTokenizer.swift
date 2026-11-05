import Foundation

/// Minimal, fault-tolerant HTML tokenizer: start/end tags with attributes, text, and raw-text elements.
/// Single forward pass over UTF-8 bytes, no recursion; a truncated document simply ends early.
enum HTMLTokenizer {
    enum Token {
        case start(name: String, attributes: [String: String])
        case end(name: String)
        case text(String)
        /// Content of <script>/<style>/<title>/<textarea>, not tokenized further. Carries the opening tag's attributes.
        case raw(name: String, attributes: [String: String], content: String)
    }

    static let rawTextElements: Set<String> = ["script", "style", "title", "textarea"]

    static func tokenize(_ html: String, _ visit: (Token) -> Void) {
        let bytes = Array(html.utf8)
        let count = bytes.count
        var index = 0
        var textStart = 0

        func flushText(upTo end: Int) {
            if end > textStart { visit(.text(String(decoding: bytes[textStart..<end], as: UTF8.self))) }
        }

        while index < count {
            guard bytes[index] == UInt8(ascii: "<"), index + 1 < count else { index += 1; continue }
            let next = bytes[index + 1]
            if next == UInt8(ascii: "!") || next == UInt8(ascii: "?") {
                flushText(upTo: index)
                let isComment = index + 3 < count && bytes[index + 2] == UInt8(ascii: "-") && bytes[index + 3] == UInt8(ascii: "-")
                let close = isComment ? find(Array("-->".utf8), in: bytes, from: index + 4) : find([UInt8(ascii: ">")], in: bytes, from: index + 2)
                index = close.map { $0 + (isComment ? 3 : 1) } ?? count
                textStart = index
            } else if next == UInt8(ascii: "/"), index + 2 < count, isNameStart(bytes[index + 2]) {
                flushText(upTo: index)
                let (name, nameEnd) = readName(bytes, from: index + 2)
                index = (find([UInt8(ascii: ">")], in: bytes, from: nameEnd) ?? count - 1) + 1
                textStart = index
                visit(.end(name: name))
            } else if isNameStart(next) {
                guard let tag = readTag(bytes, from: index + 1) else {
                    // Unterminated tag at the end of a truncated document.
                    flushText(upTo: index)
                    textStart = count
                    break
                }
                flushText(upTo: index)
                visit(.start(name: tag.name, attributes: tag.attributes))
                index = tag.end
                if rawTextElements.contains(tag.name), !tag.selfClosing {
                    let closing = findClosingTag(tag.name, in: bytes, from: index)
                    let contentEnd = closing ?? count
                    visit(.raw(name: tag.name, attributes: tag.attributes, content: String(decoding: bytes[index..<contentEnd], as: UTF8.self)))
                    visit(.end(name: tag.name))
                    index = closing.map { (find([UInt8(ascii: ">")], in: bytes, from: $0) ?? count - 1) + 1 } ?? count
                }
                textStart = index
            } else {
                index += 1 // A literal "<" in text.
            }
        }
        flushText(upTo: count)
    }

    private static func isNameStart(_ byte: UInt8) -> Bool {
        (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }

    private static func isNameByte(_ byte: UInt8) -> Bool {
        isNameStart(byte) || (byte >= 0x30 && byte <= 0x39) || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ":") || byte == UInt8(ascii: "_")
    }

    private static func isSpace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0C || byte == 0x0D
    }

    private static func readName(_ bytes: [UInt8], from start: Int) -> (String, Int) {
        var end = start
        while end < bytes.count, isNameByte(bytes[end]) { end += 1 }
        return (String(decoding: bytes[start..<end], as: UTF8.self).lowercased(), end)
    }

    /// Returns nil when the document ends before the tag's closing ">".
    private static func readTag(_ bytes: [UInt8], from start: Int) -> (name: String, attributes: [String: String], selfClosing: Bool, end: Int)? {
        let (name, nameEnd) = readName(bytes, from: start)
        var index = nameEnd
        var attributes: [String: String] = [:]
        var selfClosing = false
        let count = bytes.count
        while index < count {
            let byte = bytes[index]
            if byte == UInt8(ascii: ">") { return (name, attributes, selfClosing, index + 1) }
            if isSpace(byte) { index += 1; continue }
            if byte == UInt8(ascii: "/") { selfClosing = true; index += 1; continue }
            selfClosing = false
            let keyStart = index
            while index < count, !isSpace(bytes[index]), bytes[index] != UInt8(ascii: "="),
                  bytes[index] != UInt8(ascii: ">"), bytes[index] != UInt8(ascii: "/") { index += 1 }
            let key = String(decoding: bytes[keyStart..<index], as: UTF8.self).lowercased()
            while index < count, isSpace(bytes[index]) { index += 1 }
            var value = ""
            if index < count, bytes[index] == UInt8(ascii: "=") {
                index += 1
                while index < count, isSpace(bytes[index]) { index += 1 }
                guard index < count else { return nil }
                let quote = bytes[index]
                if quote == UInt8(ascii: "\"") || quote == UInt8(ascii: "'") {
                    guard let close = find([quote], in: bytes, from: index + 1) else { return nil }
                    value = String(decoding: bytes[(index + 1)..<close], as: UTF8.self)
                    index = close + 1
                } else {
                    let valueStart = index
                    while index < count, !isSpace(bytes[index]), bytes[index] != UInt8(ascii: ">") { index += 1 }
                    value = String(decoding: bytes[valueStart..<index], as: UTF8.self)
                }
            }
            if !key.isEmpty, attributes[key] == nil { attributes[key] = value }
        }
        return nil
    }

    private static func find(_ needle: [UInt8], in bytes: [UInt8], from start: Int) -> Int? {
        guard !needle.isEmpty, start <= bytes.count - needle.count else { return nil }
        var index = start
        let last = bytes.count - needle.count
        while index <= last {
            if bytes[index] == needle[0] {
                var matched = true
                for offset in 1..<needle.count where bytes[index + offset] != needle[offset] { matched = false; break }
                if matched { return index }
            }
            index += 1
        }
        return nil
    }

    /// Case-insensitive search for "</name".
    private static func findClosingTag(_ name: String, in bytes: [UInt8], from start: Int) -> Int? {
        let needle = Array(("</" + name).utf8)
        var index = start
        while let candidate = find([UInt8(ascii: "<")], in: bytes, from: index) {
            guard candidate + needle.count <= bytes.count else { return nil }
            var matched = bytes[candidate + 1] == UInt8(ascii: "/")
            var offset = 2
            while matched, offset < needle.count {
                matched = bytes[candidate + offset] | 0x20 == needle[offset] | 0x20
                offset += 1
            }
            if matched { return candidate }
            index = candidate + 1
        }
        return nil
    }
}
