import XCTest
@testable import Noted

/// Link-understanding Phase 03: `intelligence.store` + `LinkDigestRunner`. Loaders are fakes; nothing touches the network.
@MainActor
final class LinkDigestPipelineTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { [root] in try? FileManager.default.removeItem(at: root!) }
    }

    private var intelligenceRoot: URL { root.appendingPathComponent("library/Intelligence") }

    private func library() throws -> LibraryStore {
        try LibraryStore(root: root.appendingPathComponent("library"), queue: ShareGateStore(root: root.appendingPathComponent("queue")))
    }

    /// A captured link whose preview `EnrichmentRunner` has already finished.
    @discardableResult
    private func addLink(_ value: String, title: String? = nil, to store: LibraryStore) async throws -> Item {
        try await store.captureLink(URL(string: value)!)
        let item = try XCTUnwrap(store.items.first { $0.originalURL == value })
        item.previewStatus = "complete"
        item.title = title ?? (URL(string: value)?.host ?? "")
        item.rebuildSearchDocument()
        try store.saveChanges()
        return item
    }

    private func runner(_ loader: @escaping @Sendable (URL) async throws -> LinkDigestFetch,
                        clock: TestClock = TestClock()) throws -> LinkDigestRunner {
        LinkDigestRunner(intelligence: try IntelligenceStore(root: intelligenceRoot), loader: loader, now: { clock.now })
    }

    nonisolated private static func fetch(title: String = "Tiêu đề đọc được", summary: String? = "Tóm tắt một câu đủ dài để hiển thị trên thẻ.",
                              status: LinkDigestStatus = .complete, rawTitle: String = "Raw | Site") -> LinkDigestFetch {
        LinkDigestFetch(content: LinkDigestContent(title: title, siteName: "Site", author: "Tác giả", summary: summary,
                                                   textForEmbedding: "\(title) Site \(summary ?? "")", status: status),
                        rawTitle: rawTitle)
    }

    // MARK: - Fingerprint

    func testFingerprintIgnoresFragmentAndTracksEngineVersion() {
        let base = LinkDigest.fingerprint(originalURL: "https://example.com/a?x=1", engineVersion: "v1")
        XCTAssertEqual(base, LinkDigest.fingerprint(originalURL: "https://example.com/a?x=1#section", engineVersion: "v1"))
        XCTAssertNotEqual(base, LinkDigest.fingerprint(originalURL: "https://example.com/a?x=2", engineVersion: "v1"))
        XCTAssertNotEqual(base, LinkDigest.fingerprint(originalURL: "https://example.com/a?x=1", engineVersion: "v2"))
        XCTAssertEqual(base.count, 64)
    }

    // MARK: - Runner

    func testCompleteDigestIsStoredAndReplacesHostTitleWithoutTouchingLibraryFields() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        try store.update(item, title: item.title, body: "Ghi chú", tags: ["đọc"], collectionID: nil, markTitleEdited: false)
        let before = Snapshot(item)
        let runner = try runner { _ in Self.fetch() }
        await runner.run(in: store)

        let digest = try XCTUnwrap(try runner.intelligence.linkDigest(for: item.id))
        XCTAssertEqual(digest.state, .complete)
        XCTAssertEqual(digest.title, "Tiêu đề đọc được")
        XCTAssertEqual(digest.author, "Tác giả")
        XCTAssertEqual(digest.source, LinkDigestSource.extractive.rawValue)
        XCTAssertEqual(digest.engineVersion, ExtractiveLinkDigester.engineVersion)
        XCTAssertEqual(digest.attempts, 1)
        XCTAssertNotNil(digest.fetchedAt)
        XCTAssertEqual(item.title, "Tiêu đề đọc được")
        XCTAssertFalse(item.userEditedTitle)
        XCTAssertTrue(SearchService.matches(item: item, query: "tieu de doc duoc"))
        // library.store: only the allowed title (and its search document) changed.
        var expected = before
        expected.title = "Tiêu đề đọc được"
        XCTAssertEqual(Snapshot(item), expected)
        // Reopened from disk the item is identical.
        let reopened = try XCTUnwrap(try library().items.first { $0.id == item.id })
        XCTAssertEqual(Snapshot(reopened), expected)
    }

    func testRawTitleIsReplacedButUserAndSharedTitlesAreNot() async throws {
        let store = try library()
        let raw = try await addLink("https://a.example/1", title: "Raw | Site", to: store)
        let edited = try await addLink("https://b.example/2", to: store)
        try store.update(edited, title: "Tên tôi đặt", body: "", tags: [], collectionID: nil)
        let other = try await addLink("https://c.example/3", title: "Tiêu đề từ app chia sẻ", to: store)
        try await runner { _ in Self.fetch() }.run(in: store)
        XCTAssertEqual(raw.title, "Tiêu đề đọc được")
        XCTAssertEqual(edited.title, "Tên tôi đặt")
        XCTAssertTrue(edited.userEditedTitle)
        XCTAssertEqual(other.title, "Tiêu đề từ app chia sẻ")
    }

    func testLinkWithPendingPreviewWaitsForEnrichment() async throws {
        let store = try library()
        try await store.captureLink(URL(string: "https://example.com/new")!)
        let item = try XCTUnwrap(store.items.first)
        XCTAssertEqual(item.previewStatus, "pending")
        let calls = Counter()
        let runner = try runner { _ in calls.increment(); return Self.fetch() }
        await runner.run(in: store)
        XCTAssertEqual(calls.value, 0)
        XCTAssertNil(try runner.intelligence.linkDigest(for: item.id))
    }

    func testNewestLinkIsReadFirst() async throws {
        let store = try library()
        try await addLink("https://example.com/old", to: store)
        try await Task.sleep(for: .milliseconds(20))
        try await addLink("https://example.com/new", to: store)
        let order = Recorder()
        try await runner { url in order.append(url.path); return Self.fetch() }.run(in: store)
        XCTAssertEqual(order.values, ["/new", "/old"])
    }

    func testTrashDuringFetchDropsResultAndRestoreReadsAgain() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let gate = FetchGate()
        let started = expectation(description: "Fetch started")
        let runner = try runner { _ in started.fulfill(); return await gate.value() }
        let task = Task { await runner.run(in: store) }
        await fulfillment(of: [started], timeout: 5)
        try store.trash(item)
        await gate.complete(Self.fetch())
        await task.value
        let digest = try XCTUnwrap(try runner.intelligence.linkDigest(for: item.id))
        XCTAssertEqual(digest.state, .pending)
        XCTAssertNil(digest.title)
        XCTAssertEqual(item.title, "example.com")

        await runner.run(in: store) // trashed items are skipped
        XCTAssertEqual(digest.state, .pending)
        try store.restore(item)
        let resumed = LinkDigestRunner(intelligence: runner.intelligence, loader: { _ in Self.fetch() })
        await resumed.run(in: store)
        XCTAssertEqual(digest.state, .complete)
        XCTAssertEqual(item.title, "Tiêu đề đọc được")
    }

    func testURLChangeDuringFetchDropsStaleResultAndRefetchesNewURL() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/old", to: store)
        let gate = FetchGate()
        let started = expectation(description: "Fetch started")
        let runner = try runner { _ in started.fulfill(); return await gate.value() }
        let task = Task { await runner.run(in: store) }
        await fulfillment(of: [started], timeout: 5)
        item.originalURL = "https://example.com/new"
        try store.saveChanges()
        await gate.complete(Self.fetch(title: "Bài cũ"))
        await task.value
        let digest = try XCTUnwrap(try runner.intelligence.linkDigest(for: item.id))
        XCTAssertNil(digest.title)

        let fetched = Recorder()
        await LinkDigestRunner(intelligence: runner.intelligence, loader: { url in fetched.append(url.path); return Self.fetch(title: "Bài mới") }).run(in: store)
        XCTAssertEqual(fetched.values, ["/new"])
        XCTAssertEqual(digest.title, "Bài mới")
        XCTAssertEqual(digest.fingerprint, LinkDigest.fingerprint(originalURL: "https://example.com/new", engineVersion: ExtractiveLinkDigester.engineVersion))
    }

    func testPinTagAndTitleEditDoNotRerunDigest() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let calls = Counter()
        let runner = try runner { _ in calls.increment(); return Self.fetch() }
        await runner.run(in: store)
        try store.togglePin(item)
        try store.update(item, title: "Đổi tên", body: "x", tags: ["a"], collectionID: nil)
        try store.trash(item)
        try store.restore(item)
        await runner.run(in: store)
        XCTAssertEqual(calls.value, 1)
    }

    func testChangedEngineVersionFingerprintRebuildsAndMayReplaceItsOwnTitle() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let runner = try runner { _ in Self.fetch(title: "Bản v1") }
        await runner.run(in: store)
        XCTAssertEqual(item.title, "Bản v1")
        // Simulate a digest written by an older engine.
        let digest = try XCTUnwrap(try runner.intelligence.linkDigest(for: item.id))
        digest.fingerprint = LinkDigest.fingerprint(originalURL: item.originalURL, engineVersion: "link-extractive-v0")
        try runner.intelligence.saveChanges()
        await LinkDigestRunner(intelligence: runner.intelligence, loader: { _ in Self.fetch(title: "Bản v2") }).run(in: store)
        XCTAssertEqual(digest.title, "Bản v2")
        XCTAssertEqual(item.title, "Bản v2")
    }

    func testRunningAfterCrashIsRecoveredAndCompleted() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let intelligence = try IntelligenceStore(root: intelligenceRoot)
        let crashed = LinkDigest(itemID: item.id, fingerprint: LinkDigest.fingerprint(originalURL: item.originalURL, engineVersion: ExtractiveLinkDigester.engineVersion),
                                 engineVersion: ExtractiveLinkDigester.engineVersion)
        crashed.state = .running
        intelligence.context.insert(crashed)
        try intelligence.saveChanges()

        // Reopen as after a relaunch.
        let runner = try runner { _ in Self.fetch() }
        let reopened = try XCTUnwrap(try runner.intelligence.linkDigest(for: item.id))
        XCTAssertEqual(reopened.state, .running)
        await runner.run(in: store)
        XCTAssertEqual(reopened.state, .running, "a running digest is not picked without recovery")
        try runner.recoverInterrupted()
        XCTAssertEqual(reopened.state, .pending)
        await runner.run(in: store)
        XCTAssertEqual(reopened.state, .complete)
    }

    func testNetworkErrorsRetryWithBackoffThenBecomeUnreachable() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let clock = TestClock()
        let calls = Counter()
        let runner = try runner({ _ in calls.increment(); throw URLError(.timedOut) }, clock: clock)
        await runner.run(in: store)
        let digest = try XCTUnwrap(try runner.intelligence.linkDigest(for: item.id))
        XCTAssertEqual(digest.state, .pending)
        XCTAssertEqual(digest.attempts, 1)
        XCTAssertEqual(digest.nextRetryAt, clock.now.addingTimeInterval(60))

        await runner.run(in: store) // still backing off
        XCTAssertEqual(calls.value, 1)
        clock.advance(61)
        await runner.run(in: store)
        XCTAssertEqual(digest.attempts, 2)
        XCTAssertEqual(digest.nextRetryAt, clock.now.addingTimeInterval(240))
        clock.advance(241)
        await runner.run(in: store)
        XCTAssertEqual(digest.attempts, 3)
        XCTAssertEqual(digest.state, .unreachable)
        XCTAssertNil(digest.nextRetryAt)
        clock.advance(3_600)
        await runner.run(in: store)
        XCTAssertEqual(calls.value, 3)
        XCTAssertEqual(item.title, "example.com")
    }

    func testUnsafeURLFailsWithoutRetry() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let calls = Counter()
        let runner = try runner { _ in calls.increment(); throw LinkPreviewError.unsafeURL }
        await runner.run(in: store)
        await runner.run(in: store)
        XCTAssertEqual(calls.value, 1)
        XCTAssertEqual(try runner.intelligence.linkDigest(for: item.id)?.state, .failed)
    }

    func testLoginWallIsNotRetriedAutomaticallyUntilUserAsks() async throws {
        let store = try library()
        let item = try await addLink("https://www.facebook.com/share/p/abc", to: store)
        let calls = Counter()
        let runner = try runner { _ in
            calls.increment()
            return Self.fetch(title: "Log in", summary: nil, status: .loginWall)
        }
        await runner.run(in: store)
        let digest = try XCTUnwrap(try runner.intelligence.linkDigest(for: item.id))
        XCTAssertEqual(digest.state, .loginWall)
        XCTAssertNil(digest.summary)
        XCTAssertEqual(item.title, "www.facebook.com", "a login wall title is not written")
        await runner.run(in: store)
        XCTAssertEqual(calls.value, 1)
        try runner.retry(itemID: item.id)
        XCTAssertEqual(digest.state, .pending)
        XCTAssertEqual(digest.attempts, 0)
        await runner.run(in: store)
        XCTAssertEqual(calls.value, 2)
    }

    func testOfflineStopsRunWithoutCountingAttempt() async throws {
        let store = try library()
        try await addLink("https://example.com/a", to: store)
        try await Task.sleep(for: .milliseconds(20))
        let newest = try await addLink("https://example.com/b", to: store)
        let calls = Counter()
        let runner = try runner { _ in calls.increment(); throw URLError(.notConnectedToInternet) }
        await runner.run(in: store)
        XCTAssertTrue(runner.isOffline)
        XCTAssertEqual(calls.value, 1, "the run stops at the first offline error")
        let digest = try XCTUnwrap(try runner.intelligence.linkDigest(for: newest.id))
        XCTAssertEqual(digest.state, .pending)
        XCTAssertEqual(digest.attempts, 0)
        XCTAssertNil(digest.nextRetryAt)

        let online = LinkDigestRunner(intelligence: runner.intelligence, loader: { _ in Self.fetch() })
        await online.run(in: store)
        XCTAssertFalse(online.isOffline)
        XCTAssertEqual(try online.intelligence.linkDigests().map(\.state), [.complete, .complete])
    }

    func testLowDataModeCountsAsOffline() {
        XCTAssertTrue(LinkDigestRunner.isOffline(URLError(.dataNotAllowed)))
        XCTAssertTrue(LinkDigestRunner.isOffline(URLError(.notConnectedToInternet)))
        XCTAssertFalse(LinkDigestRunner.isOffline(URLError(.timedOut)))
        XCTAssertFalse(LinkDigestRunner.isOffline(LinkPreviewError.invalidResponse))
    }

    func testDataOperationInProgressBlocksCommit() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let gate = FetchGate()
        let started = expectation(description: "Fetch started")
        let runner = try runner { _ in started.fulfill(); return await gate.value() }
        let task = Task { await runner.run(in: store) }
        await fulfillment(of: [started], timeout: 5)
        store.isDataOperationInProgress = true
        await gate.complete(Self.fetch())
        await task.value
        XCTAssertEqual(try runner.intelligence.linkDigest(for: item.id)?.state, .pending)
        XCTAssertEqual(item.title, "example.com")
        store.isDataOperationInProgress = false
    }

    func testPermanentDeleteRemovesDigestButTrashKeepsIt() async throws {
        let store = try library()
        let kept = try await addLink("https://example.com/kept", to: store)
        let deleted = try await addLink("https://example.com/deleted", to: store)
        let runner = try runner { _ in Self.fetch() }
        await runner.run(in: store)
        XCTAssertEqual(try runner.intelligence.linkDigests().count, 2)
        try store.trash(kept)
        try store.trash(deleted)
        try store.permanentlyDelete(deleted)
        await runner.run(in: store)
        XCTAssertEqual(try runner.intelligence.linkDigests().map(\.itemID), [kept.id])
    }

    func testNonLinkItemsAreIgnored() async throws {
        let store = try library()
        try await store.captureText("Ghi chú không phải link")
        let calls = Counter()
        let runner = try runner { _ in calls.increment(); return Self.fetch() }
        await runner.run(in: store)
        XCTAssertEqual(calls.value, 0)
        XCTAssertTrue(try runner.intelligence.linkDigests().isEmpty)
    }

    // MARK: - Store

    func testDeletedIntelligenceStoreIsRebuiltForEveryLink() async throws {
        let store = try library()
        for index in 0..<3 { try await addLink("https://example.com/\(index)", to: store) }
        try await runner { _ in Self.fetch() }.run(in: store)
        try FileManager.default.removeItem(at: intelligenceRoot)
        let rebuilt = try runner { _ in Self.fetch() }
        XCTAssertTrue(try rebuilt.intelligence.linkDigests().isEmpty)
        await rebuilt.run(in: store)
        XCTAssertEqual(Set(try rebuilt.intelligence.linkDigests().map(\.itemID)), Set(store.items.map(\.id)))
        XCTAssertTrue(try rebuilt.intelligence.linkDigests().allSatisfy { $0.state == .complete })
    }

    func testCorruptStoreIsSetAsideAndRecreated() async throws {
        try FileManager.default.createDirectory(at: intelligenceRoot, withIntermediateDirectories: true)
        let file = intelligenceRoot.appendingPathComponent(IntelligenceStore.fileName)
        try Data(repeating: 0x5A, count: 8_192).write(to: file)
        let intelligence = try IntelligenceStore(root: intelligenceRoot)
        XCTAssertTrue(intelligence.recoveredFromCorruption)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path + ".corrupt"))
        intelligence.context.insert(LinkDigest(itemID: UUID(), fingerprint: "f", engineVersion: "v"))
        try intelligence.saveChanges()
        XCTAssertEqual(try IntelligenceStore(root: intelligenceRoot).linkDigests().count, 1)
    }

    func testUnknownSchemaVersionIsResetWithoutTouchingLibrary() async throws {
        let store = try library()
        let item = try await addLink("https://example.com/post", to: store)
        let first = try IntelligenceStore(root: intelligenceRoot)
        first.context.insert(LinkDigest(itemID: item.id, fingerprint: "f", engineVersion: "v"))
        try first.saveChanges()
        try "99".write(to: intelligenceRoot.appendingPathComponent("schema-version.txt"), atomically: true, encoding: .utf8)
        let reset = try IntelligenceStore(root: intelligenceRoot)
        XCTAssertTrue(reset.recoveredFromCorruption)
        XCTAssertTrue(try reset.linkDigests().isEmpty)
        XCTAssertEqual(try String(contentsOf: intelligenceRoot.appendingPathComponent("schema-version.txt"), encoding: .utf8), "1")
        XCTAssertEqual(try library().items.map(\.id), [item.id])
    }
}

/// Library fields the runner must leave alone (except `title`/`searchDocument`).
private struct Snapshot: Equatable {
    var title, body, originalURL, kind, ocrStatus, previewStatus: String
    var tags: [String]
    var pinned, userEditedTitle: Bool
    var updatedAt, createdAt: Date
    var trashedAt: Date?
    var collectionID: UUID?

    @MainActor init(_ item: Item) {
        title = item.title; body = item.body; originalURL = item.originalURL; kind = item.kind
        ocrStatus = item.ocrStatus; previewStatus = item.previewStatus; tags = item.tags
        pinned = item.pinned; userEditedTitle = item.userEditedTitle
        updatedAt = item.updatedAt; createdAt = item.createdAt; trashedAt = item.trashedAt; collectionID = item.collectionID
    }
}

private final class TestClock: @unchecked Sendable {
    private(set) var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    var values: [String] { lock.withLock { items } }
    func append(_ value: String) { lock.withLock { items.append(value) } }
}

private actor FetchGate {
    private var continuation: CheckedContinuation<LinkDigestFetch, Never>?
    private var result: LinkDigestFetch?
    func value() async -> LinkDigestFetch {
        if let result { return result }
        return await withCheckedContinuation { continuation = $0 }
    }
    func complete(_ fetch: LinkDigestFetch) {
        result = fetch
        continuation?.resume(returning: fetch)
        continuation = nil
    }
}
