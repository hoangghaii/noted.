import CryptoKit
import Foundation
import SwiftData

/// Lifecycle of a stored link digest. The last three cases mirror `LinkDigestStatus` from the digester.
enum LinkDigestState: String, Codable, CaseIterable {
    case pending, running
    case complete, titleOnly, loginWall
    /// Network errors exhausted `LinkDigestRunner.maximumAttempts`.
    case unreachable
    /// Not fetchable at all (invalid or non-public URL); never retried automatically.
    case failed
}

enum LinkDigestSource: String, Codable {
    case extractive, api
}

/// Derived reading of one link item, stored in `intelligence.store` (never in `library.store` or backups).
@Model
final class LinkDigest {
    @Attribute(.unique) var itemID: UUID
    var fingerprint: String
    var engineVersion: String
    var title: String?
    var siteName: String?
    var author: String?
    var summary: String?
    var textForEmbedding: String?
    var source: String
    var status: String
    var attempts: Int
    var nextRetryAt: Date?
    var fetchedAt: Date?
    var updatedAt: Date

    init(itemID: UUID, fingerprint: String, engineVersion: String, now: Date = Date()) {
        self.itemID = itemID
        self.fingerprint = fingerprint
        self.engineVersion = engineVersion
        source = LinkDigestSource.extractive.rawValue
        status = LinkDigestState.pending.rawValue
        attempts = 0
        updatedAt = now
    }

    var state: LinkDigestState {
        get { LinkDigestState(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    func isCurrent(for item: Item) -> Bool {
        item.kind == "link" && fingerprint == Self.fingerprint(originalURL: item.originalURL,
                                                               engineVersion: ExtractiveLinkDigester.engineVersion)
    }

    var byline: String {
        [siteName, author].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var visibleSummary: String? {
        guard state == .complete, let summary,
              !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return summary
    }

    /// Clears every derived field for a new fingerprint (URL or engine changed).
    func reset(fingerprint: String, engineVersion: String, now: Date) {
        self.fingerprint = fingerprint
        self.engineVersion = engineVersion
        title = nil; siteName = nil; author = nil; summary = nil; textForEmbedding = nil
        source = LinkDigestSource.extractive.rawValue
        state = .pending
        attempts = 0
        nextRetryAt = nil
        fetchedAt = nil
        updatedAt = now
    }

    func apply(_ content: LinkDigestContent, now: Date, source: LinkDigestSource = .extractive) {
        title = content.title
        siteName = content.siteName
        author = content.author
        summary = content.summary
        textForEmbedding = content.textForEmbedding
        self.source = source.rawValue
        state = LinkDigestState(rawValue: content.status.rawValue) ?? .complete
        nextRetryAt = nil
        fetchedAt = now
        updatedAt = now
    }

    /// SHA-256 of the original URL without its fragment, plus the engine version.
    /// Pin, trash, tags and title edits do not change it, so they never re-run the digest.
    static func fingerprint(originalURL: String, engineVersion: String) -> String {
        var normalized = originalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if var components = URLComponents(string: normalized) {
            components.fragment = nil
            normalized = components.string ?? normalized
        }
        let digest = SHA256.hash(data: Data((normalized + "\n" + engineVersion).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
