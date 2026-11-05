import Foundation
import Observation

/// What the runner needs from one fetch: the digest and the page's raw `<title>`,
/// so a title written earlier by `EnrichmentRunner` can be recognized and replaced.
struct LinkDigestFetch: Sendable {
    var content: LinkDigestContent
    var rawTitle: String
}

/// Reads saved links one at a time into `LinkDigest` records (link-understanding Phase 03).
/// Snapshot on the main actor → download and extraction off it → commit after re-checking the item.
@MainActor @Observable
final class LinkDigestRunner {
    static let maximumAttempts = 3

    @ObservationIgnored let intelligence: IntelligenceStore
    @ObservationIgnored private let loader: @Sendable (URL) async throws -> LinkDigestFetch
    @ObservationIgnored private let now: () -> Date
    private(set) var running = false
    /// Set when the last run stopped for lack of a usable network; cleared by the next run.
    private(set) var isOffline = false
    var lastError: String?

    init(intelligence: IntelligenceStore,
         loader: @escaping @Sendable (URL) async throws -> LinkDigestFetch = { try await LinkDigestRunner.fetch($0) },
         now: @escaping () -> Date = Date.init) {
        self.intelligence = intelligence
        self.loader = loader
        self.now = now
    }

    nonisolated static func fetch(_ url: URL) async throws -> LinkDigestFetch {
        let page = try await LinkMetadataService.fetchPage(for: url)
        return LinkDigestFetch(content: ExtractiveLinkDigester.digest(page),
                               rawTitle: LinkMetadataService.title(fromHTML: page.html, url: url))
    }

    /// 1 min, then 4 min before the second and third attempts.
    static func retryDelay(afterAttempt attempt: Int) -> TimeInterval {
        60 * pow(4, Double(max(attempt, 1) - 1))
    }

    /// A digest left `running` by a crash or termination goes back to `pending`.
    func recoverInterrupted() throws {
        for digest in try intelligence.linkDigests() where digest.state == .running { digest.state = .pending }
        try intelligence.saveChanges()
    }

    /// Clears the backoff and attempt count, e.g. for “Thử đọc lại” on a login wall.
    func retry(itemID: UUID) throws {
        guard let digest = try intelligence.linkDigest(for: itemID) else { return }
        digest.state = .pending
        digest.attempts = 0
        digest.nextRetryAt = nil
        digest.updatedAt = now()
        try intelligence.saveChanges()
    }

    func run(in library: LibraryStore) async {
        guard !running, !library.isDataOperationInProgress else { return }
        running = true
        isOffline = false
        defer { running = false }
        do { try pruneDeletedItems(in: library) } catch { lastError = error.localizedDescription; return }
        // Each item is attempted at most once per run; a retry waits for its backoff and a later run.
        var visited = Set<UUID>()
        while !Task.isCancelled, !library.isDataOperationInProgress {
            let job: Job?
            do { job = try nextJob(in: library, excluding: visited) } catch { lastError = error.localizedDescription; return }
            guard let job else { return }
            visited.insert(job.itemID)
            do {
                guard try await process(job, in: library) else { return }
            } catch {
                lastError = error.localizedDescription
                return
            }
            await Task.yield()
        }
    }

    private struct Job {
        let itemID: UUID
        let url: URL?
        let fingerprint: String
    }

    /// Newest saved link first, once `EnrichmentRunner` is done with its preview so it cannot overwrite the digest title.
    private func nextJob(in library: LibraryStore, excluding visited: Set<UUID>) throws -> Job? {
        let digests = Dictionary(try intelligence.linkDigests().map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        let current = now()
        for item in library.items where item.kind == "link" && item.trashedAt == nil && !visited.contains(item.id)
            && item.previewStatus != "pending" && item.previewStatus != "running" {
            let fingerprint = LinkDigest.fingerprint(originalURL: item.originalURL, engineVersion: ExtractiveLinkDigester.engineVersion)
            let needsWork: Bool
            if let digest = digests[item.id], digest.fingerprint == fingerprint {
                needsWork = digest.state == .pending && (digest.nextRetryAt ?? .distantPast) <= current
            } else {
                needsWork = true
            }
            if needsWork { return Job(itemID: item.id, url: Self.fetchableURL(item.originalURL), fingerprint: fingerprint) }
        }
        return nil
    }

    /// Returns false when the run must stop (offline, cancelled or a data operation started).
    private func process(_ job: Job, in library: LibraryStore) async throws -> Bool {
        let digest: LinkDigest
        if let existing = try intelligence.linkDigest(for: job.itemID) { digest = existing }
        else {
            digest = LinkDigest(itemID: job.itemID, fingerprint: job.fingerprint,
                                engineVersion: ExtractiveLinkDigester.engineVersion, now: now())
            intelligence.context.insert(digest)
        }
        // A title this runner wrote before may be replaced again after the URL or engine changes.
        let previousTitle = digest.title
        if digest.fingerprint != job.fingerprint {
            digest.reset(fingerprint: job.fingerprint, engineVersion: ExtractiveLinkDigester.engineVersion, now: now())
        }
        guard let url = job.url else {
            digest.state = .failed
            digest.updatedAt = now()
            try intelligence.saveChanges()
            return true
        }
        digest.state = .running
        digest.updatedAt = now()
        try intelligence.saveChanges()

        let loader = self.loader
        let result: Result<LinkDigestFetch, Error>
        do { result = .success(try await Task.detached(priority: .utility) { try await loader(url) }.value) }
        catch { result = .failure(error) }

        // The digest may have been pruned while the request was in flight.
        guard let digest = try intelligence.linkDigest(for: job.itemID) else { return true }
        if library.isDataOperationInProgress || Task.isCancelled {
            digest.state = .pending
            try intelligence.saveChanges()
            return false
        }
        guard let item = library.items.first(where: { $0.id == job.itemID }), item.trashedAt == nil,
              LinkDigest.fingerprint(originalURL: item.originalURL, engineVersion: ExtractiveLinkDigester.engineVersion) == job.fingerprint else {
            // Trashed or changed meanwhile: the stale result is dropped; a later run starts over.
            digest.state = .pending
            try intelligence.saveChanges()
            return true
        }
        switch result {
        case .success(let fetch):
            digest.attempts += 1
            digest.apply(fetch.content, now: now())
            try intelligence.saveChanges()
            if fetch.content.status != .loginWall, let title = fetch.content.title,
               Self.canReplaceTitle(of: item, rawTitle: fetch.rawTitle, previousDigestTitle: previousTitle, with: title) {
                try library.applyGeneratedTitle(title, to: item)
            }
            return true
        case .failure(let error):
            if Self.isOffline(error) {
                // Not the link's fault: the attempt is not counted and the run waits for the network.
                digest.state = .pending
                try intelligence.saveChanges()
                isOffline = true
                return false
            }
            digest.attempts += 1
            if Self.isPermanent(error) {
                digest.state = .failed
            } else if digest.attempts >= Self.maximumAttempts {
                digest.state = .unreachable
                digest.nextRetryAt = nil
            } else {
                digest.state = .pending
                digest.nextRetryAt = now().addingTimeInterval(Self.retryDelay(afterAttempt: digest.attempts))
            }
            digest.updatedAt = now()
            try intelligence.saveChanges()
            return true
        }
    }

    /// Only a title nobody edited: empty, the host, the page's raw `<title>` or this runner's previous title.
    static func canReplaceTitle(of item: Item, rawTitle: String, previousDigestTitle: String?, with title: String) -> Bool {
        guard !item.userEditedTitle else { return false }
        let current = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty, current != replacement else { return false }
        if current.isEmpty || current == rawTitle || current == previousDigestTitle { return true }
        return current == URL(string: item.originalURL)?.host
    }

    /// Digests are derived data: those whose item no longer exists (permanent delete, backup import) are removed.
    /// Trashed items keep theirs so a restore does not refetch.
    private func pruneDeletedItems(in library: LibraryStore) throws {
        let live = Set(library.items.map(\.id))
        var removed = false
        for digest in try intelligence.linkDigests() where !live.contains(digest.itemID) {
            intelligence.context.delete(digest)
            removed = true
        }
        if removed { try intelligence.saveChanges() }
    }

    private static func fetchableURL(_ value: String) -> URL? {
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    /// No usable network (offline, or Low Data Mode, which the digest request does not use).
    static func isOffline(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        if error.networkUnavailableReason != nil { return true }
        return [.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .callIsActive].contains(error.code)
    }

    static func isPermanent(_ error: Error) -> Bool {
        if case LinkPreviewError.unsafeURL = error { return true }
        if let error = error as? URLError { return [.unsupportedURL, .badURL].contains(error.code) }
        return false
    }
}
