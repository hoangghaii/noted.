import XCTest
import SwiftData
@testable import Noted

@MainActor
final class BackupRoundTripTests: XCTestCase {
    private func library() throws -> LibraryStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try LibraryStore(root: root, queue: ShareGateStore(root: root.appendingPathComponent("queue")))
    }

    func testRoundTripPreservesMetadataAndRepeatedImportIsIdempotent() async throws {
        let source = try library()
        try await source.captureText("Cà phê Đà Nẵng")
        try source.createCollection("Ideas")
        let item = try XCTUnwrap(source.items.first)
        try source.update(item, title: "Ý tưởng", body: item.body, tags: ["café"], collectionID: source.collections.first?.id)
        try source.togglePin(item)
        try source.trash(item)
        let backup = try await BackupService().export(store: source)
        let target = try library()
        let result = try await BackupService().importPackage(at: backup.url, into: target)
        XCTAssertEqual(result.inserted, 1)
        let restored = try XCTUnwrap(target.items.first)
        XCTAssertEqual(restored.id, item.id)
        XCTAssertEqual(restored.body, item.body)
        XCTAssertEqual(restored.tags, ["café"])
        XCTAssertEqual(restored.collectionID, item.collectionID)
        XCTAssertTrue(restored.pinned)
        XCTAssertNotNil(restored.trashedAt)
        let repeated = try await BackupService().importPackage(at: backup.url, into: target)
        XCTAssertEqual(repeated.inserted, 0)
        XCTAssertEqual(target.items.count, 1)
    }

    func testConflictKeepsBothAndDoesNotRepeatConflictCopy() async throws {
        let source = try library()
        try await source.captureText("Original")
        let backup = try await BackupService().export(store: source)
        let item = try XCTUnwrap(source.items.first)
        try source.update(item, title: "Edited", body: "New text", tags: [], collectionID: nil)
        let first = try await BackupService().importPackage(at: backup.url, into: source)
        XCTAssertEqual(first.conflicts, 1)
        XCTAssertEqual(source.items.count, 2)
        let second = try await BackupService().importPackage(at: backup.url, into: source)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(source.items.count, 2)
        XCTAssertTrue(source.items.contains { $0.body == "New text" })
        XCTAssertTrue(source.items.contains { $0.body == "Original" })
    }

    func testImageRoundTripAndCorruptChecksumRejectedBeforeMutation() async throws {
        let source = try library()
        let file = source.root.appendingPathComponent("fixture.png")
        // Transport preserves bytes independently of decode. This is a valid 1x1 PNG.
        let bytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=")!
        try bytes.write(to: file)
        try await source.captureImageFiles([file])
        let backup = try await BackupService().export(store: source)
        let target = try library()
        _ = try await BackupService().importPackage(at: backup.url, into: target)
        let attachment = try XCTUnwrap(target.items.first?.attachments.first)
        XCTAssertEqual(try Data(contentsOf: target.attachmentURL(attachment)), bytes)
        let manifest = try BackupService.readValidatedPackage(backup.url)
        let path = try XCTUnwrap(manifest.items.first?.attachments.first?.path)
        try Data("corrupt".utf8).write(to: backup.url.appendingPathComponent(path))
        let empty = try library()
        do {
            _ = try await BackupService().importPackage(at: backup.url, into: empty)
            XCTFail("Corrupt backup must fail")
        } catch { XCTAssertTrue(empty.items.isEmpty) }
    }

    func testEditedImportedCopyIsPreservedWhenSourceIsRestoredAgain() async throws {
        let source = try library()
        try await source.captureText("Source text")
        let backup = try await BackupService().export(store: source)
        let target = try library()
        _ = try await BackupService().importPackage(at: backup.url, into: target)
        let restored = try XCTUnwrap(target.items.first)
        try target.update(restored, title: "My edit", body: "Edited after restore", tags: [], collectionID: nil)
        let result = try await BackupService().importPackage(at: backup.url, into: target)
        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(target.items.count, 2)
        XCTAssertTrue(target.items.contains { $0.body == "Edited after restore" })
        XCTAssertTrue(target.items.contains { $0.body == "Source text" })
        _ = try await BackupService().importPackage(at: backup.url, into: target)
        XCTAssertEqual(target.items.count, 2)
    }

    func testInterruptedImportCanRetryWithoutLostOrDuplicateItems() async throws {
        struct Interrupted: Error {}
        let source = try library()
        try await source.captureText("Keep original")
        let backup = try await BackupService().export(store: source)
        for point in [BackupFaultPoint.beforeMetadataSave, .afterMetadataSave] {
            let target = try library()
            let service = BackupService()
            service.faultInjector = { current in if current == point { throw Interrupted() } }
            do { _ = try await service.importPackage(at: backup.url, into: target); XCTFail("Expected interruption") }
            catch {}
            service.faultInjector = nil
            _ = try await service.importPackage(at: backup.url, into: target)
            XCTAssertEqual(target.items.count, 1)
            XCTAssertEqual(target.items.first?.body, "Keep original")
        }
    }

    func testTraversalAndUnsupportedSchemaRejected() async throws {
        let source = try library()
        try await source.captureText("Keep me")
        let backup = try await BackupService().export(store: source)
        let manifestURL = backup.url.appendingPathComponent("manifest.json")
        var manifest = try BackupService.readValidatedPackage(backup.url)
        manifest.version = 99
        try JSONEncoder().encode(manifest).write(to: manifestURL)
        XCTAssertThrowsError(try BackupService.readValidatedPackage(backup.url))
        manifest.version = 1
        manifest.items[0].kind = "image"
        manifest.items[0].attachments = [BackupAttachment(id: UUID(), path: "originals/../../outside", size: 4,
                                                         checksum: String(repeating: "a", count: 64), typeIdentifier: "public.png")]
        try JSONEncoder().encode(manifest).write(to: manifestURL)
        XCTAssertThrowsError(try BackupService.readValidatedPackage(backup.url))
        XCTAssertEqual(source.items.first?.body, "Keep me")
    }
}
