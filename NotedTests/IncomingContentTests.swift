import XCTest
@testable import Noted

final class IncomingContentTests: XCTestCase {
    func testTextProviderBecomesMediaCaptionWithoutChangingIdentity() {
        var payload = ShareGatePayload()
        let image = ShareGatePayload.Entry(kind: .image, value: "original.heic")
        payload.caption = "Tiêu đề từ host"
        payload.entries = [image, .init(kind: .text, value: "Cà phê Đà Nẵng")]
        let result = IncomingContentDecoder.groupingSupplementaryText(in: payload)
        XCTAssertEqual(result.id, payload.id)
        XCTAssertEqual(result.entries.map(\.id), [image.id])
        XCTAssertEqual(result.caption, "Tiêu đề từ host\nCà phê Đà Nẵng")
    }

    func testDuplicateHostCaptionIsNotRepeated() {
        var payload = ShareGatePayload()
        payload.caption = "Example"
        payload.entries = [.init(kind: .link, value: "https://example.com"), .init(kind: .text, value: "Example")]
        let result = IncomingContentDecoder.groupingSupplementaryText(in: payload)
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.caption, "Example")
    }

    func testThreeImagesAndTextCaptionRemainThreeEntries() {
        var payload = ShareGatePayload()
        payload.entries = (0..<3).map { .init(kind: .image, value: "image\($0).heic") }
        payload.entries.append(.init(kind: .text, value: "Ba ảnh ở Đà Nẵng"))
        let result = IncomingContentDecoder.groupingSupplementaryText(in: payload)
        XCTAssertEqual(result.entries.count, ShareGateStore.maximumEntries)
        XCTAssertTrue(result.entries.allSatisfy { $0.kind == .image })
        XCTAssertEqual(result.caption, "Ba ảnh ở Đà Nẵng")
    }

    func testStandaloneTextIsPreservedAsText() {
        let payload = try! ShareGateStore.textOnlyPayload("Ý tưởng\nDòng thứ hai")
        let result = IncomingContentDecoder.groupingSupplementaryText(in: payload)
        XCTAssertEqual(result.entries.first?.kind, .text)
        XCTAssertEqual(result.entries.first?.value, "Ý tưởng\nDòng thứ hai")
    }
}
