import Foundation

enum LinkDigestStatus: String, Codable, Equatable {
    /// A summary was extracted.
    case complete
    /// Only a title is available (e.g. iCloud Notes, JavaScript-only pages); the UI suggests adding a note.
    case titleOnly
    /// The page asks to log in; nothing is invented.
    case loginWall
}

/// Extractive digest of one link. Every string is taken from the page, never generated.
struct LinkDigestContent: Equatable {
    var title: String?
    var siteName: String?
    var author: String?
    var summary: String?
    /// Input for the topic engine: title, author/site, summary and up to ~1,000 characters of main text.
    var textForEmbedding: String?
    var status: LinkDigestStatus
}

enum ExtractiveLinkDigester {
    /// Bump when extraction rules change so stored digests are rebuilt.
    static let engineVersion = "link-extractive-v1"
    static let summaryLimit = 240
    static let titleLimit = 80
    static let minimumDescriptionLength = 40
    /// Social post text is the content itself, so short posts still count.
    static let minimumSocialDescriptionLength = 15
    static let embeddingMainTextLimit = 1_000

    static func digest(_ page: LinkPage) -> LinkDigestContent {
        digest(fields: LinkPageParser.parse(page.html), url: page.url, redirectedToLogin: page.redirectedToLogin)
    }

    static func digest(fields: LinkPageFields, url: URL, redirectedToLogin: Bool = false) -> LinkDigestContent {
        let platform = domain(for: url)
        let social = socialPlatforms.contains(platform)
        let siteName = fields.siteName ?? platformNames[platform]
        let rawTitle = fields.ogTitle ?? fields.jsonLD.headline ?? fields.htmlTitle.map { stripSiteSuffix($0, siteName: siteName) }
            ?? fields.twitterTitle
        var description = fields.description?.text ?? fields.jsonLD.description

        if redirectedToLogin || loginWallPattern(description: description, title: rawTitle) != nil {
            return LinkDigestContent(siteName: siteName, status: .loginWall)
        }

        var title = rawTitle
        var author = fields.jsonLD.authorName ?? fields.articleAuthor.flatMap { $0.hasPrefix("http") ? nil : $0 }
        if social {
            if let post = socialPostDescription(description) {
                author = author ?? post.author
                description = post.content
            }
            if let current = title, let parsed = socialTitle(current, platform: platform) {
                // og:title of a post names its author, not its content.
                author = author ?? parsed.author
                if let content = parsed.content, description == nil { description = content }
                title = nil
            }
        }
        if let current = title, isGenericTitle(current, siteName: siteName) { title = nil }

        var summary: String?
        let minimum = social ? minimumSocialDescriptionLength : minimumDescriptionLength
        if let description, description.count >= minimum,
           !sameText(description, title), !sameText(description, siteName) {
            summary = clip(description, limit: summaryLimit)
        }
        let body = fields.mainText.isEmpty ? (fields.jsonLD.articleBody ?? "") : fields.mainText
        if summary == nil {
            let sentences = splitSentences(body).filter { !isBoilerplate($0) }
            if !sentences.isEmpty { summary = clip(sentences.prefix(3).joined(separator: " "), limit: summaryLimit) }
        }
        if title == nil, social, let summary { title = clip(summary, limit: titleLimit) }
        let finalTitle = title ?? url.host ?? url.absoluteString

        var parts: [String] = []
        for part in [finalTitle, author, siteName, summary, String(body.prefix(embeddingMainTextLimit))] {
            guard let part, !part.isEmpty else { continue }
            let joined = parts.joined(separator: "\n")
            if !joined.contains(part) { parts.append(part) }
        }
        return LinkDigestContent(title: finalTitle, siteName: siteName, author: author, summary: summary,
                                 textForEmbedding: parts.joined(separator: "\n"),
                                 status: summary == nil ? .titleOnly : .complete)
    }

    // MARK: Platforms

    static let socialPlatforms: Set<String> = ["facebook", "instagram", "threads", "x", "tiktok"]
    static let platformNames = [
        "facebook": "Facebook", "instagram": "Instagram", "threads": "Threads", "x": "X",
        "tiktok": "TikTok", "youtube": "YouTube"
    ]

    /// Normalized domain: platform families collapse (`m.facebook.com`, `fb.watch` → `facebook`),
    /// other hosts reduce to their registrable domain.
    static func domain(for url: URL) -> String {
        var host = url.host?.lowercased() ?? "unknown"
        for prefix in ["www.", "m.", "mobile.", "web.", "l.", "lm.", "vt.", "vm.", "music."] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        let families: [(String, [String])] = [
            ("facebook", ["facebook.com", "fb.com", "fb.watch", "fb.me", "fb.gg"]),
            ("instagram", ["instagram.com", "instagr.am", "ig.me"]),
            ("threads", ["threads.net", "threads.com"]),
            ("youtube", ["youtube.com", "youtu.be"]),
            ("tiktok", ["tiktok.com"]),
            ("x", ["x.com", "twitter.com", "t.co"])
        ]
        for (family, hosts) in families where hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            return family
        }
        let labels = host.split(separator: ".")
        guard labels.count > 2 else { return host }
        // Keep three labels for country second-level domains such as bbc.co.uk.
        let secondLevel = ["com", "co", "net", "org", "gov", "edu", "ac"]
        let take = labels.last!.count == 2 && secondLevel.contains(String(labels[labels.count - 2])) ? 3 : 2
        return labels.suffix(take).joined(separator: ".")
    }

    // MARK: Login walls

    /// Normalized, diacritic-folded boilerplate seen on login walls. Threads' wording was observed on 2026-11-04;
    /// Facebook/Instagram wording is not yet verified on real links.
    static let loginWallPatterns = [
        "log in or sign up", "log into facebook", "log in to facebook", "see posts, photos and more on facebook",
        "create an account or log in", "sign up to see photos and videos", "welcome back to instagram",
        "log in to instagram", "join threads", "log in with your instagram", "log in to see",
        "dang nhap facebook", "dang nhap hoac dang ky", "dang nhap de xem", "dang ky de xem",
        "xem bai viet, anh va noi dung khac tren facebook", "tao tai khoan hoac dang nhap"
    ]
    static let genericLoginTitles: Set<String> = [
        "facebook", "instagram", "threads", "log in", "login", "dang nhap", "log into facebook",
        "facebook - log in or sign up", "facebook – log in or sign up", "instagram - log in",
        "threads • log in", "error", "x"
    ]

    static func isLoginURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        let host = url.host?.lowercased() ?? ""
        return ["/login", "/accounts/login", "/checkpoint", "login.php", "/signin", "/auth"].contains { path.contains($0) }
            || host.hasPrefix("login.") || host.hasPrefix("accounts.")
    }

    /// The matched pattern (boilerplate wording, never post content), or nil.
    static func loginWallPattern(description: String?, title: String?) -> String? {
        let text = Item.normalize(description ?? "")
        if let pattern = loginWallPatterns.first(where: { text.contains($0) }) { return pattern }
        if text.isEmpty, let title, genericLoginTitles.contains(Item.normalize(title)) {
            return "title:" + Item.normalize(title)
        }
        return nil
    }

    // MARK: Social formats

    /// `12 likes, 3 comments - Name on March 1, 2026: "content"` (Facebook/Instagram og:description).
    static func socialPostDescription(_ text: String?) -> (author: String, content: String)? {
        guard let text,
              let match = firstMatch(#"^[\d.,\s]+[KkMm]?\s+(?:likes?|lượt thích)[^:]*?[-–]\s*(.+?)\s+(?:on|vào|ngày)\s+[^:]+:\s*["“](.+)["”]\.?$"#, in: text),
              match.count == 2 else { return nil }
        return (match[0], match[1])
    }

    /// `Name (@handle) on Threads`, `Name on Instagram: "content"`.
    static func socialTitle(_ title: String, platform: String) -> (author: String, content: String?)? {
        if platform == "instagram" || platform == "facebook",
           let match = firstMatch(#"^(.+?)\s+(?:on|trên)\s+(?:Instagram|Facebook):\s*["“](.+)["”]$"#, in: title), match.count == 2 {
            return (match[0], match[1])
        }
        guard let name = platformNames[platform],
              let match = firstMatch("^(.+?)\\s+(?:on|trên|•)\\s+\(name)$", in: title), match.count == 1 else { return nil }
        return (match[0], nil)
    }

    // MARK: Text

    /// Drops a trailing "| Facebook", "• Instagram photos and videos", "- YouTube" style suffix.
    static func stripSiteSuffix(_ title: String, siteName: String?) -> String {
        let names = Set(([siteName].compactMap { $0 } + Array(platformNames.values)).map(Item.normalize))
        for separator in [" | ", " • ", " - ", " – ", " — "] {
            guard let range = title.range(of: separator, options: .backwards) else { continue }
            let suffix = Item.normalize(String(title[range.upperBound...]))
            if names.contains(where: { suffix == $0 || suffix.hasPrefix($0 + " ") }) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return title
    }

    static let boilerplatePhrases = [
        "cookie", "quang cao", "advertisement", "subscribe", "dang ky nhan tin", "accept all", "chap nhan tat ca",
        "enable javascript", "bat javascript", "trinh duyet cua ban khong ho tro", "your browser"
    ]

    static func isBoilerplate(_ sentence: String) -> Bool {
        let normalized = Item.normalize(sentence)
        return boilerplatePhrases.contains { normalized.contains($0) }
    }

    static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if character.isNewline {
                append(&current, to: &sentences)
                continue
            }
            current.append(character)
            let terminal = ".!?…".contains(character)
            let nextIsBreak = index + 1 == characters.count || characters[index + 1].isWhitespace
            if terminal, nextIsBreak { append(&current, to: &sentences) }
        }
        append(&current, to: &sentences)
        return sentences
    }

    /// Whole sentences up to `limit`; a single longer sentence is cut at a word boundary with "…".
    static func clip(_ text: String, limit: Int) -> String {
        let collapsed = LinkPageParser.collapse(text)
        guard collapsed.count > limit else { return collapsed }
        var result = ""
        for sentence in splitSentences(collapsed) {
            let candidate = result.isEmpty ? sentence : result + " " + sentence
            guard candidate.count <= limit else { break }
            result = candidate
        }
        if !result.isEmpty { return result }
        let prefix = String(collapsed.prefix(limit - 1))
        let cut = prefix.lastIndex(where: \.isWhitespace).map { String(prefix[..<$0]) } ?? prefix
        return cut.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)) + "…"
    }

    private static func append(_ current: inout String, to sentences: inout [String]) {
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { sentences.append(trimmed) }
        current = ""
    }

    private static func isGenericTitle(_ title: String, siteName: String?) -> Bool {
        sameText(title, siteName) || genericLoginTitles.contains(Item.normalize(title))
    }

    private static func sameText(_ lhs: String, _ rhs: String?) -> Bool {
        guard let rhs else { return false }
        return Item.normalize(lhs).trimmingCharacters(in: .whitespacesAndNewlines) ==
            Item.normalize(rhs).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
    }
}
