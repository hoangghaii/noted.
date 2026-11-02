import XCTest
@testable import Noted

final class NotedDesignTests: XCTestCase {
    private func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }

    func testFolderSketchMatchesVietnameseNamesAndStableFallback() {
        for (name, sketch) in [("Cảm hứng", NotedDesign.Sketch.folderLeaf), ("Đọc sau", .folderBook), ("Góc riêng", .folderHeart), ("Chuyến đi", .folderMountain), ("Ý TƯỞNG", .folderLeaf), ("Du lịch", .folderMountain)] {
            XCTAssertEqual(NotedDesign.folderSketch(for: name, id: id(1)), sketch)
        }
        let choices: [NotedDesign.Sketch] = [.folderLeaf, .folderBook, .folderHeart, .folderMountain]
        for index in 1...20 {
            XCTAssertEqual(NotedDesign.folderSketch(for: "Khác", id: id(index)), choices[Int(NotedDesign.stableHash(id(index)) % 4)])
        }
    }

    func testHashHasFixedCrossLaunchVectors() {
        XCTAssertEqual(NotedDesign.stableHash(id(1)), 8950987144096290878)
        XCTAssertEqual(NotedDesign.stableHash(id(2)), 8950986044584662667)
    }

    func testMockCardTones() {
        XCTAssertEqual(NotedDesign.tone(for: id(1), kind: "text"), .cream)
        XCTAssertEqual(NotedDesign.tone(for: id(37), kind: "text"), .honey)
        XCTAssertEqual(NotedDesign.tone(for: id(3), kind: "image"), .cream)
        XCTAssertEqual(NotedDesign.tone(for: id(4), kind: "link"), .sage)
        // v3 shows exactly one curl among the first four cards: the honey idea note.
        XCTAssertTrue(NotedDesign.curls(for: id(37), kind: "text"))
        for plain in [(1, "text"), (3, "image"), (4, "link")] {
            XCTAssertFalse(NotedDesign.curls(for: id(plain.0), kind: plain.1))
        }
    }

    func testThousandNotesHaveSparseCurlsAndHoney() {
        let ids = (0..<1000).map(id)
        let honey = ids.filter { NotedDesign.tone(for: $0, kind: "text") == .honey }.count
        let curls = ids.filter { NotedDesign.curls(for: $0, kind: "text") }.count
        XCTAssertTrue((280...380).contains(honey), "Honey: \(honey)/1000")
        XCTAssertTrue((90...160).contains(curls), "Curls: \(curls)/1000")
        for value in ids {
            XCTAssertEqual(NotedDesign.tone(for: value, kind: "image"), .cream)
            XCTAssertFalse(NotedDesign.curls(for: value, kind: "image"))
            XCTAssertEqual(NotedDesign.tone(for: value, kind: "link"), .sage)
        }
        XCTAssertEqual(NotedDesign.folderTone(at: 0), .cream)
        XCTAssertEqual(NotedDesign.folderTone(at: 1), .sage)
    }
}
