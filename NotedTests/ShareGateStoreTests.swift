import XCTest
@testable import Noted

final class ShareGateStoreTests: XCTestCase {
    func testTextOnlyHostPayloadPreservesUnicodeAndRejectsEmpty() throws {
        let payload = try ShareGateStore.textOnlyPayload("Ý tưởng\nCà phê")
        XCTAssertEqual(payload.entries.first?.kind, .text)
        XCTAssertEqual(payload.entries.first?.value, "Ý tưởng\nCà phê")
        XCTAssertTrue(payload.caption.isEmpty)
        XCTAssertThrowsError(try ShareGateStore.textOnlyPayload("  \n"))
    }

    private func temporaryStore() throws -> ShareGateStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return ShareGateStore(root: root)
    }

    func testPartialIsInvisibleAndPublishedTextSurvivesReopen() throws {
        let store = try temporaryStore()
        var payload = ShareGatePayload()
        payload.entries = [.init(kind: .text, value: "Cà phê\nĐà Nẵng"), .init(kind: .link, value: "https://example.com")]
        let directory = try store.begin(id: payload.id)
        XCTAssertTrue(try store.readAll().isEmpty)
        try store.publish(payload, directory: directory)
        let reopened = ShareGateStore(root: store.root)
        XCTAssertEqual(try reopened.readAll().first?.entries.first?.value, "Cà phê\nĐà Nẵng")
        XCTAssertEqual(try reopened.readAll().count, 1)
    }

    func testCopyDoesNotDependOnTemporaryHostFile() throws {
        let store = try temporaryStore()
        var payload = ShareGatePayload()
        let directory = try store.begin(id: payload.id)
        let source = store.root.appendingPathComponent("source.png")
        let bytes = Data([1, 2, 3, 4])
        try bytes.write(to: source)
        let name = try ShareGateStore.copyImage(from: source, to: directory, extension: "png")
        payload.entries = [.init(kind: .image, value: name)]
        try FileManager.default.removeItem(at: source)
        try store.publish(payload, directory: directory)
        let url = try XCTUnwrap(store.imageURL(payload: payload.id, name: name))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testMissingAttachmentCannotPublish() throws {
        let store = try temporaryStore()
        var payload = ShareGatePayload()
        let directory = try store.begin(id: payload.id)
        payload.entries = [.init(kind: .image, value: "missing.png")]
        XCTAssertThrowsError(try store.publish(payload, directory: directory))
        XCTAssertTrue(try store.readAll().isEmpty)
    }

    func testTraversalCannotPublish() throws {
        let store = try temporaryStore()
        var payload = ShareGatePayload()
        let directory = try store.begin(id: payload.id)
        payload.entries = [.init(kind: .image, value: "../source.png")]
        XCTAssertThrowsError(try store.publish(payload, directory: directory))
        XCTAssertNil(store.imageURL(payload: payload.id, name: "../source.png"))
    }
}
