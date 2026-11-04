import XCTest
import UIKit
@testable import Noted

@MainActor
final class SearchAndEnrichmentTests: XCTestCase {
    func testTrashingDuringPreviewCanResumeAfterRestore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root.appendingPathComponent("library"), queue: ShareGateStore(root: root.appendingPathComponent("queue")))
        try await store.captureLink(URL(string: "https://example.com")!)
        let item = try XCTUnwrap(store.items.first)
        let started = expectation(description: "Preview started")
        let gate = PreviewGate()
        let runner = EnrichmentRunner(previewLoader: { _ in
            started.fulfill()
            return await gate.value()
        })
        let task = Task { await runner.run(in: store) }
        await fulfillment(of: [started], timeout: 5)
        try store.trash(item)
        await gate.complete("Metadata title")
        await task.value
        XCTAssertEqual(item.previewStatus, "pending")
        try store.restore(item)
        let resumed = EnrichmentRunner(previewLoader: { _ in "Restored title" })
        await resumed.run(in: store)
        XCTAssertEqual(item.previewStatus, "complete")
        XCTAssertEqual(item.title, "Restored title")
    }

    func testVietnameseSearchMatchesEditsAndExcludesTrash() {
        let item = Item(captureID: UUID().uuidString, kind: "text", title: "Cà phê ĐÀ NẴNG", body: "Gặp bạn chiều thứ bảy")
        XCTAssertTrue(SearchService.matches(item: item, query: "ca phe da nang"))
        XCTAssertTrue(SearchService.matches(item: item, query: "Đà Nẵng"))
        item.tags = ["Du lịch"]
        item.ocrText = "Reservation number 42"
        XCTAssertTrue(SearchService.matches(item: item, query: "du lich reservation"))
        item.trashedAt = Date()
        XCTAssertFalse(SearchService.matches(item: item, query: "cà phê"))
    }

    func testPreviewRejectsLocalAddressesBeforeAnyDownload() {
        for value in ["file:///private/test", "https://localhost/", "http://127.0.0.1/", "http://10.0.0.1/", "http://192.168.1.1/", "http://[::1]/"] {
            XCTAssertThrowsError(try PublicURLPolicy.validate(URL(string: value)!))
        }
        XCTAssertFalse(PublicURLPolicy.isPublicIPv4(0xA9FE0001))
        XCTAssertTrue(PublicURLPolicy.isPublicIPv4(0x08080808))
    }

    func testLinkSourceSpikeMarksRepeatedBoilerplate() {
        var attempt = LinkSourceAttempt(strategy: .safariUserAgent)
        attempt.descriptionLength = 80
        attempt.descriptionHash = LinkSourceSpike.hash("Same boilerplate")
        attempt.usable = LinkSourceSpike.isUsable(attempt)
        XCTAssertTrue(attempt.usable)
        let marked = LinkSourceSpike.markBoilerplate([
            LinkSourceResult(itemID: UUID(), domain: "facebook", attempts: [attempt]),
            LinkSourceResult(itemID: UUID(), domain: "facebook", attempts: [attempt])
        ])
        XCTAssertTrue(marked.allSatisfy { $0.attempts[0].genericPattern == "repeated-description" && !$0.attempts[0].usable })
        let summary = LinkSourceSpike.summarize(marked)
        XCTAssertEqual(summary, [LinkSourceSummaryRow(domain: "facebook", strategy: .safariUserAgent,
                                                      attempted: 2, usable: 0, loginWall: 2, withStatus2xx: 0)])
    }

    func testOCRReadsSyntheticImageAndReportsActualLanguages() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("ocr.png")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 300)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 300))
            ("NOTED DEVICE GATE 42" as NSString).draw(at: CGPoint(x: 40, y: 100), withAttributes: [
                .font: UIFont.systemFont(ofSize: 58), .foregroundColor: UIColor.black
            ])
        }
        try XCTUnwrap(image.pngData()).write(to: url)
        let result = try await OCRService.recognize(url: url)
        XCTAssertTrue(result.text.contains("NOTED"), result.text)
        XCTAssertFalse(result.supportedLanguages.isEmpty)
        print("Vision supported recognition languages: \(result.supportedLanguages.joined(separator: ","))")
    }

    func testVietnameseOCRUsesRuntimeLanguageIdentifier() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("vietnamese.png")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1500, height: 400)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1500, height: 400))
            ("CÀ PHÊ ĐÀ NẴNG" as NSString).draw(at: CGPoint(x: 60, y: 130), withAttributes: [
                .font: UIFont.systemFont(ofSize: 92, weight: .semibold), .foregroundColor: UIColor.black
            ])
        }
        try XCTUnwrap(image.pngData()).write(to: url)
        let result = try await OCRService.recognize(url: url)
        guard result.supportedLanguages.contains(where: { $0.hasPrefix("vi") }) else {
            throw XCTSkip("Vision runtime does not advertise Vietnamese recognition.")
        }
        XCTAssertTrue(Item.normalize(result.text).contains("ca phe da nang"), result.text)
    }
}

private actor PreviewGate {
    private var continuation: CheckedContinuation<String, Never>?
    private var result: String?
    func value() async -> String {
        if let result { return result }
        return await withCheckedContinuation { continuation = $0 }
    }
    func complete(_ text: String) {
        result = text
        continuation?.resume(returning: text)
        continuation = nil
    }
}
