import XCTest
import SwiftData
import UIKit
@testable import Noted

@MainActor
final class CaptureRecoveryTests: XCTestCase {
    private enum Injected: Error { case stopped }

    private func environment() throws -> (URL, ShareGateStore) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = ShareGateStore(root: root.appendingPathComponent("queue", isDirectory: true))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (root, queue)
    }

    private func pngData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    private func imageBatch(_ queue: ShareGateStore, count: Int = 3) throws -> ShareGatePayload {
        var payload = ShareGatePayload()
        let directory = try queue.begin(id: payload.id)
        let image = pngData()
        for index in 0..<count {
            let name = "image-\(index).png"
            try image.write(to: directory.appendingPathComponent(name))
            payload.entries.append(.init(kind: .image, value: name))
        }
        try queue.publish(payload, directory: directory)
        return payload
    }

    func testAfterFileCopyBeforeSaveRetryIsAllOrNothing() async throws {
        let (root, queue) = try environment()
        _ = try imageBatch(queue)
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        store.faultInjector = { if $0 == .beforeMetadataSave { throw Injected.stopped } }
        try await store.importPending()
        XCTAssertEqual(store.items.count, 0)
        XCTAssertEqual(try queue.readAll().count, 1)
        XCTAssertEqual(store.pendingIssues.count, 1)
        store.faultInjector = nil
        try await store.importPending()
        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(try queue.readAll().isEmpty)
        for attachment in store.items.flatMap(\.attachments) {
            XCTAssertEqual(try ShareGateStore.checksum(store.attachmentURL(attachment)), attachment.checksum)
        }
    }

    func testAfterMetadataCommitRetryDoesNotDuplicateOrResurrectDeletedItem() async throws {
        let (root, queue) = try environment()
        _ = try imageBatch(queue, count: 1)
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        store.faultInjector = { if $0 == .afterMetadataSave { throw Injected.stopped } }
        try await store.importPending()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(try queue.readAll().count, 1)
        let item = try XCTUnwrap(store.items.first)
        let imageURL = store.attachmentURL(try XCTUnwrap(item.attachments.first))
        try store.trash(item)
        try store.permanentlyDelete(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
        store.faultInjector = nil
        try await store.importPending()
        XCTAssertEqual(store.items.count, 0)
        XCTAssertTrue(try queue.readAll().isEmpty)
    }

    func testCorruptBatchDoesNotBlockHealthyBatchOrModifyExistingItems() async throws {
        let (root, queue) = try environment()
        let bad = try imageBatch(queue, count: 1)
        let image = try XCTUnwrap(queue.imageURL(payload: bad.id, name: "image-0.png"))
        try Data([7, 7, 7, 7]).write(to: image)
        var healthy = try ShareGateStore.textOnlyPayload("Không dấu / Đà Nẵng")
        healthy.caption = "ghi chú"
        let directory = try queue.begin(id: healthy.id)
        try queue.publish(healthy, directory: directory)
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        try await store.importPending()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.body, "Không dấu / Đà Nẵng\nghi chú")
        XCTAssertEqual(store.pendingIssues.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: image.path))
    }

    func testMalformedImageIsNotCommittedAndReadySourceIsRetained() async throws {
        let (root, queue) = try environment()
        var payload = ShareGatePayload()
        payload.entries = [.init(kind: .image, value: "broken.png")]
        let directory = try queue.begin(id: payload.id)
        try Data([1, 2, 3, 4]).write(to: directory.appendingPathComponent("broken.png"))
        try queue.publish(payload, directory: directory)

        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        try await store.importPending()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.pendingIssues.map(\.id), [payload.id])
        XCTAssertEqual(try queue.readAll().count, 1)
    }

    func testAfterFilesPreparedRetryImportsBatchOnce() async throws {
        let (root, queue) = try environment()
        _ = try imageBatch(queue)
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        store.faultInjector = { if $0 == .afterFilesPrepared { throw Injected.stopped } }
        try await store.importPending()
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(try queue.readAll().count, 1)
        store.faultInjector = nil
        try await store.importPending()
        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(try queue.readAll().isEmpty)
    }

    func testBeforeSourceCleanupRetryKeepsOneCommittedBatch() async throws {
        let (root, queue) = try environment()
        _ = try imageBatch(queue)
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        store.faultInjector = { if $0 == .beforeSourceCleanup { throw Injected.stopped } }
        try await store.importPending()
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(try queue.readAll().count, 1)
        store.faultInjector = nil
        try await store.importPending()
        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(try queue.readAll().isEmpty)
    }

    func testNewContextReopensSavedTextAndLinkOffline() async throws {
        let (root, queue) = try environment()
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        try await store.captureText("Cà phê\nĐà Nẵng")
        try await store.captureLink(URL(string: "https://example.com/?q=đà-nẵng")!, caption: "Để đọc")
        let context = ModelContext(store.container)
        let reloaded = try context.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(reloaded.count, 2)
        XCTAssertTrue(reloaded.contains { $0.body == "Cà phê\nĐà Nẵng" })
        XCTAssertTrue(reloaded.contains { $0.originalURL.contains("example.com") && $0.body == "Để đọc" })
    }

    func testPartialRemainsVisibleAndExplicitDiscardRemovesOnlyThatBatch() async throws {
        let (root, queue) = try environment()
        let partialID = UUID()
        _ = try queue.begin(id: partialID)
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        try await store.captureText("Giữ mục này")
        XCTAssertTrue(store.pendingIssues.contains { $0.id == partialID && $0.isPartial })
        try store.discardPending(id: partialID)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(try queue.partialDirectories().isEmpty)
    }

    func testDifferentCaptureWithSameItemIDCannotOverwriteEditedItemOrPartiallyImportBatch() async throws {
        let (root, queue) = try environment()
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        let collisionID = UUID()
        let original = Item(id: collisionID, captureID: "restored-other-source", kind: "text", title: "Đã sửa", body: "Giữ bản biên tập")
        store.context.insert(original)
        try store.saveChanges()

        var payload = ShareGatePayload()
        payload.entries = [.init(kind: .text, value: "Mục hợp lệ trước collision"),
                           .init(id: collisionID, kind: .text, value: "Không được ghi đè")]
        let directory = try queue.begin(id: payload.id)
        try queue.publish(payload, directory: directory)
        try await store.importPending()

        XCTAssertEqual(store.items.count, 1)
        let kept = try XCTUnwrap(store.items.first)
        XCTAssertEqual(kept.id, collisionID)
        XCTAssertEqual(kept.captureID, "restored-other-source")
        XCTAssertEqual(kept.title, "Đã sửa")
        XCTAssertEqual(kept.body, "Giữ bản biên tập")
        XCTAssertEqual(store.pendingIssues.map(\.id), [payload.id])
        XCTAssertEqual(try queue.readAll().count, 1)
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<ProcessedBatch>()).isEmpty)
    }

    func testDifferentCaptureAttachmentIDCollisionRetainsSourceAndExistingOriginal() async throws {
        let (root, queue) = try environment()
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        var payload = ShareGatePayload()
        let imageID = UUID()
        payload.entries = [.init(id: imageID, kind: .image, value: "image.png")]
        let directory = try queue.begin(id: payload.id)
        try pngData().write(to: directory.appendingPathComponent("image.png"))
        try queue.publish(payload, directory: directory)

        let original = Item(captureID: "restored-image", kind: "image", body: "Giữ ảnh")
        let keptURL = store.root.appendingPathComponent("originals/kept.png")
        try FileManager.default.createDirectory(at: keptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([9, 8, 7]).write(to: keptURL)
        let keptChecksum = try ShareGateStore.checksum(keptURL)
        let attachment = Attachment(id: imageID, relativePath: "originals/kept.png", size: 3, checksum: keptChecksum, typeIdentifier: "public.png")
        original.attachments = [attachment]
        store.context.insert(original)
        try store.saveChanges()
        try await store.importPending()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.body, "Giữ ảnh")
        XCTAssertEqual(store.items.first?.attachments.first?.checksum, keptChecksum)
        XCTAssertEqual(try Data(contentsOf: keptURL), Data([9, 8, 7]))
        XCTAssertEqual(store.pendingIssues.map(\.id), [payload.id])
        XCTAssertEqual(try queue.readAll().count, 1)
    }

    func testReceiptRetryRetainsSourceWhenCommittedOriginalDisappears() async throws {
        let (root, queue) = try environment()
        _ = try imageBatch(queue, count: 1)
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: queue)
        store.faultInjector = { if $0 == .afterMetadataSave { throw Injected.stopped } }
        try await store.importPending()
        let item = try XCTUnwrap(store.items.first)
        let original = store.attachmentURL(try XCTUnwrap(item.attachments.first))
        try FileManager.default.removeItem(at: original)
        store.faultInjector = nil
        try await store.importPending()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.pendingIssues.count, 1)
        XCTAssertEqual(try queue.readAll().count, 1)
    }
}
