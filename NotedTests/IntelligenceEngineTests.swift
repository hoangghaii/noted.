import XCTest
import UIKit
@testable import Noted

final class IntelligenceEngineTests: XCTestCase {
    func testVectorNormalizationAndCosine() throws {
        let vector = try EmbeddingMath.normalized([3, 4])
        XCTAssertEqual(vector[0], 0.6, accuracy: 0.0001)
        XCTAssertEqual(vector[1], 0.8, accuracy: 0.0001)
        XCTAssertEqual(EmbeddingMath.cosine(vector, vector) ?? -1, 1, accuracy: 0.0001)
        XCTAssertNil(EmbeddingMath.cosine([1], [1, 0]))
        XCTAssertThrowsError(try EmbeddingMath.normalized([0, 0]))
    }

    func testBaselineNormalizesVietnameseAndRejectsAmbiguity() {
        let topics = [
            KeywordBaseline.Topic(name: "Cà phê", aliases: ["cà phê", "coffee"]),
            KeywordBaseline.Topic(name: "Tìm việc", aliases: ["tìm việc", "job"])
        ]
        XCTAssertEqual(KeywordBaseline.predict("Quan ca phe yen tinh", topics: topics), "Cà phê")
        XCTAssertEqual(KeywordBaseline.predict("Tim viec remote", topics: topics), "Tìm việc")
        XCTAssertNil(KeywordBaseline.predict("Java lập trình", topics: topics))
        XCTAssertNil(KeywordBaseline.predict("coffee job", topics: topics))
        XCTAssertNil(KeywordBaseline.predict("café", topics: topics))
    }

    func testLongOcrIsChunkedWithoutDroppingCharacters() {
        let input = String(repeating: "a", count: 65) + " lỗi OCR"
        let chunks = ContextualEmbeddingEngine.chunks(input, maximumCharacters: 20)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 20 })
        XCTAssertEqual(chunks.joined().filter { !$0.isWhitespace }, input.filter { !$0.isWhitespace })
    }

    func testVietnameseContextualCandidateCanBeDiscovered() {
        let candidate = ContextualEmbeddingEngine()
        XCTAssertNotNil(candidate)
        XCTAssertTrue(candidate?.supportedLanguages.contains("vi") == true)
        XCTAssertFalse(candidate?.engineVersion.isEmpty ?? true)
        // Availability is environment-dependent; the app does not request a download here.
    }

    func testVisionFeaturePrintForSyntheticImage() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.brown.setFill()
            context.fill(CGRect(x: 25, y: 25, width: 50, height: 50))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try XCTUnwrap(image.pngData()).write(to: url)
        let signals: ImageSignalResult
        do {
            signals = try ImageSignals.analyze(url: url)
        } catch {
            #if targetEnvironment(simulator)
            let failure = error as NSError
            if failure.domain == NSOSStatusErrorDomain && failure.code == -1 {
                throw XCTSkip("Vision cannot create an Espresso context in this simulator runtime")
            }
            #endif
            throw error
        }
        XCTAssertGreaterThan(signals.classifyRevision, 0)
        XCTAssertGreaterThan(signals.featurePrintRevision, 0)
        XCTAssertEqual(try ImageSignals.distance(signals.featurePrint, signals.featurePrint), 0, accuracy: 0.001)
    }

    #if DEBUG
    func testSpikeReportUsesHoldoutAndDoesNotExportItemText() throws {
        let marker = "PRIVATE-EVALUATION-CONTENT-DO-NOT-EXPORT"
        let samples = [
            IntelligenceSpikeSample(id: UUID(), kind: "text", text: "cà phê", hasOriginalText: true, imageURL: nil,
                                    hasOCR: false, gold: "Cà phê", desiredTags: ["coffee"], split: "calibration"),
            IntelligenceSpikeSample(id: UUID(), kind: "text", text: "\(marker) cà phê", hasOriginalText: true, imageURL: nil,
                                    hasOCR: false, gold: "Cà phê", desiredTags: ["private-tag"], split: "holdout")
        ]
        let report = IntelligenceSpikeEvaluator.evaluate(samples)
        XCTAssertEqual(report.counts.total, 2)
        XCTAssertEqual(report.counts.holdout, 1)
        XCTAssertFalse(report.sufficientLabelsForGate)
        XCTAssertEqual(report.candidates.first?.holdoutCorrect, 1)
        XCTAssertEqual(report.candidates.first?.holdoutEvaluated, 1)
        let json = String(decoding: try JSONEncoder().encode(report), as: UTF8.self)
        XCTAssertFalse(json.contains(marker))
        XCTAssertFalse(json.contains("private-tag"))
    }

    func testEvaluationSplitIsStableAndLabelStoreRoundTripsWithoutLibraryMutation() throws {
        let id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let split = IntelligenceLabelStorage.split(for: id)
        XCTAssertEqual(split, IntelligenceLabelStorage.split(for: id))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("labels.json")
        let label = IntelligenceLabel(itemID: id, topic: "Carepath", secondaryTopics: ["Tìm việc"], desiredTags: ["example"],
                                      split: split, labeledAt: Date(timeIntervalSince1970: 1_700_000_000))
        try IntelligenceLabelStorage.save([id: label], to: url)
        XCTAssertEqual(try IntelligenceLabelStorage.load(from: url)[id], label)
    }
    #endif
}
