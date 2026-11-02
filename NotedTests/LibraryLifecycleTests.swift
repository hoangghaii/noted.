import XCTest
import SwiftData
import UIKit
@testable import Noted

@MainActor
final class LibraryLifecycleTests: XCTestCase {
    private enum Injected: Error { case stopped }
    private func store() throws -> LibraryStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try LibraryStore(root: root.appendingPathComponent("library"), queue: ShareGateStore(root: root.appendingPathComponent("queue")))
    }

    func testDeletingCollectionPreservesItemAndRestoreReturnsToInbox() async throws {
        let store = try store()
        try await store.captureText("Bản ghi vẫn còn")
        try store.createCollection("Ý tưởng")
        let collection = try XCTUnwrap(store.collections.first)
        let item = try XCTUnwrap(store.items.first)
        try store.update(item, title: "Tiêu đề", body: item.body, tags: [" test ", "test"], collectionID: collection.id)
        try store.togglePin(item)
        try store.trash(item)
        try store.deleteCollection(collection)
        try store.restore(item)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNil(item.collectionID)
        XCTAssertNil(item.trashedAt)
        XCTAssertTrue(item.pinned)
        XCTAssertEqual(item.tags, ["test"])
        XCTAssertEqual(item.body, "Bản ghi vẫn còn")
    }

    func testTrashRetainsOriginalUntilExplicitPermanentDeletion() async throws {
        let store = try store()
        let source = store.root.appendingPathComponent("source.png")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        try image.write(to: source)
        try await store.captureImageFiles([source])
        let item = try XCTUnwrap(store.items.first)
        let url = store.attachmentURL(try XCTUnwrap(item.attachments.first))
        try store.createCollection("Ảnh thử")
        let collection = try XCTUnwrap(store.collections.first)
        try store.update(item, title: "", body: item.body, tags: [], collectionID: collection.id)
        try store.trash(item)
        try store.deleteCollection(collection)
        XCTAssertNil(item.collectionID)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try store.restore(item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try store.trash(item)
        try store.permanentlyDelete(item)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testBackupMutationLockPreservesExistingValues() async throws {
        let store = try store()
        try await store.captureText("Bản gốc")
        let item = try XCTUnwrap(store.items.first)
        store.isDataOperationInProgress = true
        XCTAssertThrowsError(try store.update(item, title: "Mới", body: "Bị thay", tags: [], collectionID: nil))
        XCTAssertEqual(item.body, "Bản gốc")
        store.isDataOperationInProgress = false
        try store.update(item, title: "Đà Nẵng", body: "Cà phê", tags: ["Việt"], collectionID: nil)
        XCTAssertTrue(item.searchDocument.contains("da nang"))
        XCTAssertTrue(item.searchDocument.contains("ca phe"))
    }

    func testOrganizationPersistsAfterReopeningStore() async throws {
        let store = try store()
        try await store.captureText("Nội dung")
        try store.createCollection("Công việc")
        let item = try XCTUnwrap(store.items.first)
        let collection = try XCTUnwrap(store.collections.first)
        try store.update(item, title: "Tiêu đề", body: item.body, tags: ["tag"], collectionID: collection.id)
        try store.togglePin(item)
        try store.trash(item)
        let reopened = try LibraryStore(root: store.root, queue: store.queue)
        let restored = try XCTUnwrap(reopened.items.first)
        XCTAssertEqual(restored.collectionID, collection.id)
        XCTAssertEqual(restored.tags, ["tag"])
        XCTAssertTrue(restored.pinned)
        XCTAssertNotNil(restored.trashedAt)
        try reopened.restore(restored)
        XCTAssertEqual(restored.collectionID, collection.id)
        XCTAssertNil(restored.trashedAt)
    }

    func testSaveFailureAndIncomingImportPreserveEditDraft() async throws {
        let store = try store()
        try await store.captureText("Bản gốc")
        let item = try XCTUnwrap(store.items.first)
        let draft = ItemEditDraft(title: "Đang sửa", body: "Chưa lưu", tags: "test", collectionID: nil)
        let itemID = item.id
        addTeardownBlock { try? FileManager.default.removeItem(at: DetailDraftStore.path(itemID)) }
        try DetailDraftStore.save(draft, id: item.id)
        store.libraryFaultInjector = { if $0 == .beforeSave { throw Injected.stopped } }
        XCTAssertThrowsError(try store.update(item, title: draft.title, body: draft.body, tags: [draft.tags], collectionID: nil))
        XCTAssertEqual(item.body, "Bản gốc")
        XCTAssertEqual(DetailDraftStore.read(item.id), draft)
        store.libraryFaultInjector = nil
        try await store.captureText("Nội dung mới từ queue")
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(DetailDraftStore.read(item.id), draft)
        try store.update(item, title: draft.title, body: draft.body, tags: [draft.tags], collectionID: nil)
        XCTAssertEqual(item.body, draft.body)
    }

    func testInterruptedDeletionRecoversOnReopen() async throws {
        for point in [LibraryFaultPoint.afterDeletionCommit, .beforeOriginalCleanup] {
            let store = try store()
            let source = store.root.appendingPathComponent("source.png")
            let data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
                UIColor.blue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            }
            try data.write(to: source)
            try await store.captureImageFiles([source])
            let item = try XCTUnwrap(store.items.first)
            let original = store.attachmentURL(try XCTUnwrap(item.attachments.first))
            try store.trash(item)
            store.libraryFaultInjector = { if $0 == point { throw Injected.stopped } }
            XCTAssertThrowsError(try store.permanentlyDelete(item))
            XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
            let reopened = try LibraryStore(root: store.root, queue: store.queue)
            XCTAssertTrue(reopened.items.isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        }
    }

    func testFailedDeletionPreservesReferencedOriginalOnReopen() async throws {
        let store = try store()
        let source = store.root.appendingPathComponent("source.png")
        let data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        try data.write(to: source)
        try await store.captureImageFiles([source])
        let item = try XCTUnwrap(store.items.first)
        let attachment = try XCTUnwrap(item.attachments.first)
        let original = store.attachmentURL(attachment)
        let checksum = attachment.checksum
        try store.trash(item)
        store.libraryFaultInjector = { if $0 == .beforeSave { throw Injected.stopped } }
        XCTAssertThrowsError(try store.permanentlyDelete(item))
        let reopened = try LibraryStore(root: store.root, queue: store.queue)
        XCTAssertEqual(reopened.items.count, 1)
        XCTAssertNotNil(reopened.items.first?.trashedAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertEqual(try ShareGateStore.checksum(original), checksum)
    }

    func testUntitledOfflineLinkHasReadableTitle() {
        let link = Item(captureID: UUID().uuidString, kind: "link", originalURL: "https://example.com/article")
        XCTAssertEqual(link.displayTitle, "example.com")
        link.title = "   "
        XCTAssertEqual(link.displayTitle, "example.com")
    }

    func testLibraryFiltersDistinguishKindsInboxAndPinned() {
        let note = Item(captureID: UUID().uuidString, kind: "text", body: "Ghi chú")
        let link = Item(captureID: UUID().uuidString, kind: "link", originalURL: "https://example.com")
        let image = Item(captureID: UUID().uuidString, kind: "image")
        link.collectionID = UUID()
        image.pinned = true
        let items = [note, link, image]
        XCTAssertEqual(items.filter(LibraryFilter.all.includes).map(\.id), items.map(\.id))
        XCTAssertEqual(items.filter(LibraryFilter.notes.includes).map(\.id), [note.id])
        XCTAssertEqual(items.filter(LibraryFilter.links.includes).map(\.id), [link.id])
        XCTAssertEqual(items.filter(LibraryFilter.images.includes).map(\.id), [image.id])
        XCTAssertEqual(items.filter(LibraryFilter.inbox.includes).map(\.id), [note.id, image.id])
        XCTAssertEqual(items.filter(LibraryFilter.pinned.includes).map(\.id), [image.id])
        image.pinned = false
        XCTAssertTrue(items.filter(LibraryFilter.pinned.includes).isEmpty)
    }

    func testThumbnailDownsamplesAndSeparatesGridAndDetailSizes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("large.png")
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1200), format: format).pngData { context in
            UIColor.purple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
        }
        try data.write(to: source)
        let service = ThumbnailService()
        let grid = try await service.image(at: source, maxPixelSize: 400)
        let detail = try await service.image(at: source, maxPixelSize: 900)
        let gridPixels = try XCTUnwrap(grid.cgImage)
        let detailPixels = try XCTUnwrap(detail.cgImage)
        XCTAssertEqual(gridPixels.width, 400)
        XCTAssertEqual(gridPixels.height, 200)
        XCTAssertEqual(detailPixels.width, 900)
        XCTAssertEqual(detailPixels.height, 450)
        XCTAssertEqual(try Data(contentsOf: source), data, "Thumbnail decoding must preserve the original bytes.")
    }

    func testThumbnailRejectsMalformedImageAndCanRetryRepairedFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("broken.png")
        let invalid = Data("not an image".utf8)
        try invalid.write(to: source)
        let service = ThumbnailService()
        do {
            _ = try await service.image(at: source, maxPixelSize: 100)
            XCTFail("Malformed image must throw so the UI can show its fallback.")
        } catch {
            XCTAssertEqual((error as NSError).code, CocoaError.fileReadCorruptFile.rawValue)
        }
        XCTAssertEqual(try Data(contentsOf: source), invalid)
        let valid = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        try valid.write(to: source)
        let retry = try await service.image(at: source, maxPixelSize: 100)
        XCTAssertNotNil(retry.cgImage, "A failed decode must not poison later attempts.")
    }
}
