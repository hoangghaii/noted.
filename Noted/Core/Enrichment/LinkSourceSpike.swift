#if DEBUG
import Foundation
import LinkPresentation
import UIKit

/// DEBUG spike (link-understanding Phase 01): measures what each fetch strategy returns for the user's links.
/// Writes nothing to library.store or intelligence.store. The persisted report holds only domains, flags,
/// lengths and hashes; page text is kept in memory for on-device review and never written.
enum LinkSourceStrategy: String, Codable, CaseIterable {
    /// Production pipeline (Phase 02): `LinkMetadataService.fetchPage` + `ExtractiveLinkDigester`. First, so the
    /// review list previews the digest.
    case extractiveDigest
    case urlSessionDefault, safariUserAgent, linkPresentation, oEmbed
}

struct LinkSourceAttempt: Codable, Equatable {
    var strategy: LinkSourceStrategy
    /// oEmbed endpoint family (e.g. "threads-graph"); nil for the page strategies.
    var endpoint: String?
    var httpStatus: Int?
    var error: String?
    var redirectCount = 0
    /// Page exceeded the byte limit; only its prefix (which holds <head>) was parsed.
    var truncated: Bool? = nil
    var loginRedirect = false
    var hasOGTitle = false
    var hasOGDescription = false
    /// "og", "twitter", "meta", "oembed" or nil.
    var descriptionSource: String?
    var descriptionLength = 0
    /// FNV-1a of the normalized description: detects boilerplate shared by several links without storing text.
    var descriptionHash: String?
    /// The known login-wall pattern that matched (boilerplate wording, never post content).
    var genericPattern: String?
    var hasJSONLD = false
    var mainTextLength = 0
    var titleLength = 0
    /// `LinkDigestStatus` raw value, extractiveDigest only.
    var digestStatus: String?
    var durationMs = 0
    var usable = false

    var loginWall: Bool { loginRedirect || genericPattern != nil }
}

struct LinkSourceResult: Codable, Equatable {
    let itemID: UUID
    let domain: String
    var attempts: [LinkSourceAttempt]
}

struct LinkSourceSummaryRow: Codable, Hashable {
    let domain: String
    let strategy: LinkSourceStrategy
    var attempted = 0
    var usable = 0
    var loginWall = 0
    var withStatus2xx = 0
}

struct LinkSourceRun: Codable {
    let measuredAt: Date
    let appVersion: String
    let build: String
    let systemVersion: String
    let deviceModel: String
    let safariUserAgent: String
    let domainCounts: [String: Int]
    var results: [LinkSourceResult]
    var summary: [LinkSourceSummaryRow]
    /// `ExtractiveLinkDigester.engineVersion`; nil for runs made before Phase 02.
    var engineVersion: String?
}

struct LinkSourceReport: Codable {
    var schemaVersion = 1
    var runs: [LinkSourceRun] = []
    /// itemID → whether the fetched information was enough for the user to assign a topic.
    var judgments: [String: Bool] = [:]
}

/// In-memory only; shown in the DEBUG review list so the user can judge sufficiency.
struct LinkSourcePreview: Equatable {
    var title: String
    var description: String
    var strategy: LinkSourceStrategy?
}

enum LinkSourceSpike {
    static let minimumDescriptionLength = 40
    static let minimumMainTextLength = 200
    /// Pause between requests so 21 links × 4 strategies do not trip rate limits.
    static let requestSpacing: Duration = .milliseconds(1200)

    static func reportURL(for libraryRoot: URL) -> URL {
        IntelligenceLabelStorage.fileURL(for: libraryRoot).deletingLastPathComponent()
            .appendingPathComponent("link-sources.json")
    }

    static func domain(for url: URL) -> String { ExtractiveLinkDigester.domain(for: url) }

    static func safariUserAgent(systemVersion: String = UIDevice.current.systemVersion) -> String {
        let parts = systemVersion.split(separator: ".").map(String.init)
        let os = parts.joined(separator: "_")
        let version = parts.prefix(2).joined(separator: ".")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) AppleWebKit/605.1.15 " +
            "(KHTML, like Gecko) Version/\(version) Mobile/15E148 Safari/604.1"
    }

    static func genericPattern(description: String?, title: String?) -> String? {
        ExtractiveLinkDigester.loginWallPattern(description: description, title: title)
    }

    static func hash(_ text: String) -> String {
        let value = Array(Item.normalize(text).utf8).reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        return String(value, radix: 16)
    }

    /// oEmbed endpoint per family. Graph endpoints are called without a token on purpose,
    /// to measure whether they answer at all (Instagram/Facebook are documented to require one).
    static func oEmbedEndpoint(domain: String, url: URL) -> (name: String, url: URL)? {
        let endpoints = [
            "youtube": ("youtube", "https://www.youtube.com/oembed?format=json&url="),
            "tiktok": ("tiktok", "https://www.tiktok.com/oembed?url="),
            "threads": ("threads-graph", "https://graph.threads.net/v1.0/oembed?url="),
            "instagram": ("instagram-graph", "https://graph.facebook.com/v22.0/instagram_oembed?url="),
            "facebook": ("facebook-graph", "https://graph.facebook.com/v22.0/oembed_post?url="),
            "x": ("x-publish", "https://publish.twitter.com/oembed?url="),
            "vimeo.com": ("vimeo", "https://vimeo.com/api/oembed.json?url=")
        ]
        guard let (name, base) = endpoints[domain],
              let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let endpoint = URL(string: base + encoded) else { return nil }
        return (name, endpoint)
    }

    // MARK: Run

    static func run(links: [(id: UUID, url: URL)],
                    progress: @escaping @MainActor (Int, Int) -> Void) async -> (LinkSourceRun, [UUID: LinkSourcePreview]) {
        let agent = await MainActor.run { safariUserAgent() }
        var results: [LinkSourceResult] = []
        var previews: [UUID: LinkSourcePreview] = [:]
        var texts: [UUID: [LinkSourceStrategy: (title: String, description: String)]] = [:]
        let total = links.count * LinkSourceStrategy.allCases.count
        var done = 0
        for link in links {
            let domain = domain(for: link.url)
            var attempts: [LinkSourceAttempt] = []
            for strategy in LinkSourceStrategy.allCases {
                if Task.isCancelled { break }
                let (attempt, text) = await measure(strategy, url: link.url, domain: domain, userAgent: agent)
                if let attempt { attempts.append(attempt) }
                if let text { texts[link.id, default: [:]][strategy] = text }
                done += 1
                await progress(done, total)
                if attempt != nil { try? await Task.sleep(for: requestSpacing) }
            }
            results.append(LinkSourceResult(itemID: link.id, domain: domain, attempts: attempts))
        }
        results = markBoilerplate(results)
        for result in results {
            let best = result.attempts.first(where: \.usable) ?? result.attempts.first(where: { $0.titleLength > 0 })
            let text = best.flatMap { texts[result.itemID]?[$0.strategy] }
            previews[result.itemID] = LinkSourcePreview(title: text?.title ?? "", description: text?.description ?? "",
                                                        strategy: best?.strategy)
        }
        let info = Bundle.main.infoDictionary ?? [:]
        let device = await MainActor.run { UIDevice.current.systemVersion }
        let run = LinkSourceRun(
            measuredAt: Date(), appVersion: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "?", systemVersion: device, deviceModel: machine(),
            safariUserAgent: agent,
            domainCounts: Dictionary(grouping: links, by: { domain(for: $0.url) }).mapValues(\.count),
            results: results, summary: summarize(results), engineVersion: ExtractiveLinkDigester.engineVersion)
        return (run, previews)
    }

    /// Descriptions repeated verbatim across different links are boilerplate, not post content.
    static func markBoilerplate(_ results: [LinkSourceResult]) -> [LinkSourceResult] {
        var owners: [String: Set<UUID>] = [:]
        for result in results {
            for attempt in result.attempts {
                if let hash = attempt.descriptionHash { owners[hash, default: []].insert(result.itemID) }
            }
        }
        return results.map { result in
            var copy = result
            copy.attempts = result.attempts.map { attempt in
                var updated = attempt
                if let hash = attempt.descriptionHash, (owners[hash]?.count ?? 0) > 1, updated.genericPattern == nil {
                    updated.genericPattern = "repeated-description"
                    updated.usable = updated.mainTextLength >= minimumMainTextLength && !updated.loginRedirect
                }
                return updated
            }
            return copy
        }
    }

    static func summarize(_ results: [LinkSourceResult]) -> [LinkSourceSummaryRow] {
        var rows: [String: LinkSourceSummaryRow] = [:]
        for result in results {
            for attempt in result.attempts {
                let key = result.domain + "|" + attempt.strategy.rawValue
                var row = rows[key] ?? LinkSourceSummaryRow(domain: result.domain, strategy: attempt.strategy)
                row.attempted += 1
                if attempt.usable { row.usable += 1 }
                if attempt.loginWall { row.loginWall += 1 }
                if let status = attempt.httpStatus, (200..<300).contains(status) { row.withStatus2xx += 1 }
                rows[key] = row
            }
        }
        return rows.values.sorted {
            ($0.domain, $0.strategy.rawValue) < ($1.domain, $1.strategy.rawValue)
        }
    }

    /// Returns nil when the strategy does not apply (no oEmbed endpoint for this domain).
    private static func measure(_ strategy: LinkSourceStrategy, url: URL, domain: String,
                                userAgent: String) async -> (LinkSourceAttempt?, (title: String, description: String)?) {
        let clock = ContinuousClock()
        let start = clock.now
        var attempt = LinkSourceAttempt(strategy: strategy)
        var text: (title: String, description: String)?
        func elapsed() -> Int {
            let duration = clock.now - start
            return Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
        }
        do {
            try await Task.detached(priority: .utility) { try PublicURLPolicy.validate(url) }.value
            switch strategy {
            case .extractiveDigest:
                let page = try await LinkMetadataService.fetchPage(for: url)
                let digest = ExtractiveLinkDigester.digest(page)
                attempt.httpStatus = page.statusCode
                attempt.redirectCount = page.redirectCount
                attempt.loginRedirect = page.redirectedToLogin
                if page.truncated { attempt.truncated = true }
                attempt.digestStatus = digest.status.rawValue
                attempt.titleLength = digest.title?.count ?? 0
                attempt.descriptionSource = digest.summary == nil ? nil : "digest"
                attempt.descriptionLength = digest.summary?.count ?? 0
                if digest.status == .loginWall { attempt.genericPattern = "digest:loginWall" }
                let heading = [digest.title, digest.author].compactMap { $0 }.joined(separator: " · ")
                text = (heading, digest.summary ?? "")
            case .urlSessionDefault, .safariUserAgent:
                let download = BoundedMetadataDownload(userAgent: strategy == .safariUserAgent ? userAgent : nil,
                                                       keepPrefixWhenOversized: true)
                defer { record(download, into: &attempt) }
                let data = try await download.load(url)
                // Lossy UTF-8: a truncated prefix may end mid-character, which would make strict decoding fail.
                let html = String(decoding: data, as: UTF8.self)
                let fields = LinkPageParser.parse(html)
                let description = fields.description
                attempt.hasOGTitle = fields.ogTitle != nil
                attempt.hasOGDescription = fields.ogDescription != nil
                attempt.descriptionSource = description?.source
                attempt.descriptionLength = description?.text.count ?? 0
                attempt.descriptionHash = description.map { hash($0.text) }
                attempt.hasJSONLD = fields.hasJSONLD
                attempt.mainTextLength = fields.mainText.count
                let title = fields.ogTitle ?? fields.htmlTitle ?? ""
                attempt.titleLength = title.count
                attempt.genericPattern = genericPattern(description: description?.text, title: title)
                text = (title, description?.text ?? String(fields.mainText.prefix(400)))
            case .linkPresentation:
                let title = try await linkPresentationTitle(url)
                attempt.titleLength = title?.count ?? 0
                attempt.genericPattern = genericPattern(description: nil, title: title)
                text = title.map { ($0, "") }
            case .oEmbed:
                guard let endpoint = oEmbedEndpoint(domain: domain, url: url) else { return (nil, nil) }
                attempt.endpoint = endpoint.name
                let download = BoundedMetadataDownload(acceptedMIMETypes: ["application/json", "text/javascript", "text/json"])
                defer { record(download, into: &attempt) }
                let data = try await download.load(endpoint.url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let title = json["title"] as? String ?? ""
                let author = json["author_name"] as? String ?? ""
                let embedText = LinkPageParser.plainText(json["html"] as? String ?? "")
                attempt.titleLength = title.count
                attempt.descriptionSource = embedText.isEmpty ? nil : "oembed"
                attempt.descriptionLength = embedText.count
                attempt.descriptionHash = embedText.isEmpty ? nil : hash(embedText)
                text = (title.isEmpty ? author : title, embedText)
            }
        } catch {
            attempt.error = errorKind(error)
        }
        attempt.durationMs = elapsed()
        attempt.usable = isUsable(attempt)
        return (attempt, text)
    }

    static func isUsable(_ attempt: LinkSourceAttempt) -> Bool {
        guard attempt.error == nil, !attempt.loginWall else { return false }
        switch attempt.strategy {
        case .linkPresentation: return false // title-only by design; compared separately.
        case .extractiveDigest: return attempt.digestStatus == LinkDigestStatus.complete.rawValue
        case .oEmbed: return attempt.descriptionLength >= minimumDescriptionLength || attempt.titleLength >= 10
        case .urlSessionDefault, .safariUserAgent:
            return attempt.descriptionLength >= minimumDescriptionLength || attempt.mainTextLength >= minimumMainTextLength
        }
    }

    private static func record(_ download: BoundedMetadataDownload, into attempt: inout LinkSourceAttempt) {
        attempt.httpStatus = download.httpStatus
        attempt.redirectCount = download.redirectURLs.count
        if download.truncated { attempt.truncated = true }
        attempt.loginRedirect = download.redirectURLs.contains(where: ExtractiveLinkDigester.isLoginURL)
    }

    @MainActor
    private static func linkPresentationTitle(_ url: URL) async throws -> String? {
        let provider = LPMetadataProvider()
        provider.timeout = 12
        provider.shouldFetchSubresources = false
        return try await provider.startFetchingMetadata(for: url).title
    }

    private static func errorKind(_ error: Error) -> String {
        if let preview = error as? LinkPreviewError { return "\(preview)" }
        let ns = error as NSError
        return "\(ns.domain)#\(ns.code)"
    }

    private static func machine() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    // MARK: Persistence

    static func load(from url: URL) throws -> LinkSourceReport {
        guard FileManager.default.fileExists(atPath: url.path) else { return LinkSourceReport() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LinkSourceReport.self, from: Data(contentsOf: url))
    }

    static func save(_ report: LinkSourceReport, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: url, options: .atomic)
    }
}
#endif
