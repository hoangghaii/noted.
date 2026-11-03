import XCTest
import UIKit
import CoreML
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

    func testMeanCenteringSeparatesVectorsInANarrowCone() throws {
        let a = UUID(), b = UUID()
        let raw = [a: try EmbeddingMath.normalized([1, 0.1]), b: try EmbeddingMath.normalized([1, -0.1])]
        XCTAssertGreaterThan(EmbeddingMath.cosine(raw[a]!, raw[b]!)!, 0.97)
        let centered = EmbeddingMath.meanCentered(raw)
        XCTAssertEqual(EmbeddingMath.cosine(centered[a]!, centered[b]!)!, -1, accuracy: 0.0001)
        XCTAssertEqual(EmbeddingMath.meanCentered([a: [1, 0]])[a]!, [1, 0])
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

    func testResourceProbeReadsFootprintAndCyclesSmallLibraries() {
        XCTAssertGreaterThan(IntelligenceResourceProbe.physicalFootprintBytes() ?? 0, 0)
        XCTAssertEqual(IntelligenceResourceProbe.megabytes(from: 1_048_576, to: 3_145_728), 2)
        XCTAssertNil(IntelligenceResourceProbe.megabytes(from: nil, to: 1))
        let cycled = IntelligenceResourceProbe.cycled([1, 2, 3])
        XCTAssertEqual(cycled.count, IntelligenceResourceProbe.batchSize)
        XCTAssertEqual(Array(cycled.prefix(4)), [1, 2, 3, 1])
        XCTAssertTrue(IntelligenceResourceProbe.cycled([Int]()).isEmpty)
    }

    func testReportSchemaV3CarriesResourceFieldsWithoutLabels() throws {
        let samples = [IntelligenceSpikeSample(id: UUID(), kind: "text", text: "cà phê sáng", hasOriginalText: true,
                                               imageURL: nil, hasOCR: false, gold: nil, desiredTags: [], split: nil)]
        let report = IntelligenceSpikeEvaluator.evaluate(samples)
        XCTAssertEqual(report.schemaVersion, 3)
        XCTAssertEqual(report.dataSource, "library")
        XCTAssertNil(report.visionColdMilliseconds)
        let contextual = try XCTUnwrap(report.candidates.first { $0.name == "Apple NL contextual" })
        // Resource numbers require downloaded assets; without them nothing may be reported as measured.
        if contextual.status.hasPrefix("resources measured") {
            XCTAssertNotNil(contextual.coldStartMilliseconds)
            XCTAssertNotNil(contextual.batch50Milliseconds)
        } else {
            XCTAssertNil(contextual.batch50Milliseconds)
        }
    }

    func testSyntheticCorpusIsBalancedAndNeverPassesGate() {
        let samples = IntelligenceSyntheticCorpus.samples()
        XCTAssertGreaterThanOrEqual(samples.count, 150)
        XCTAssertEqual(Set(samples.map(\.id)).count, samples.count)
        XCTAssertTrue(samples.allSatisfy { ["text", "link"].contains($0.kind) && $0.imageURL == nil })
        let topics = Dictionary(grouping: samples, by: { $0.gold ?? "" })
        XCTAssertEqual(Set(topics.keys), ["Cà phê", "Tìm việc", "Carepath", "Kiếm thêm thu nhập", "Hài hước", "Không rõ"])
        for (topic, rows) in topics {
            XCTAssertGreaterThanOrEqual(rows.filter { $0.split == "holdout" }.count, 1, topic)
            XCTAssertGreaterThanOrEqual(rows.filter { $0.split == "calibration" }.count, 10, topic)
        }
        let report = IntelligenceSpikeEvaluator.evaluate(samples, dataSource: IntelligenceSyntheticCorpus.version)
        XCTAssertEqual(report.dataSource, IntelligenceSyntheticCorpus.version)
        XCTAssertFalse(report.sufficientLabelsForGate)
        XCTAssertTrue(report.notes.contains { $0.contains("cannot satisfy the Phase 01 gate") })
        XCTAssertEqual(report.visionFailures, 0)
    }

    /// Opt-in device measurement: `TEST_RUNNER_NOTED_SPIKE_REPORT=1 xcodebuild test ...`.
    /// Downloads Apple's NL asset if missing, then prints the synthetic-corpus report.
    func testSyntheticSpikeReportOnDevice() async throws {
        guard ProcessInfo.processInfo.environment["NOTED_SPIKE_REPORT"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_NOTED_SPIKE_REPORT=1 to run the device spike report")
        }
        if let engine = ContextualEmbeddingEngine(), !engine.hasAvailableAssets {
            _ = try await engine.requestAssets()
        }
        let samples = IntelligenceSyntheticCorpus.samples()
        let report = IntelligenceSpikeEvaluator.evaluate(samples, dataSource: IntelligenceSyntheticCorpus.version)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        print("NOTED_SPIKE_REPORT_JSON " + String(decoding: try encoder.encode(report), as: UTF8.self))
    }

    // MARK: E5 parity (files copied by devicectl; skipped when absent)

    private func e5File(_ name: String) throws -> URL {
        let url = CoreMLEmbeddingEngine.defaultDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("E5 spike file absent: \(name)") }
        return url
    }

    func testE5NativeTokenizerMatchesPythonTokenIDs() throws {
        let fixture = try e5File("token-fixture.json")
        let tokenizer = try XLMRobertaTokenizer(tokenizerJSON: try e5File("tokenizer.json"))
        struct Record: Decodable { let id: Int; let text: String; let ids: [Int32] }
        struct File: Decodable { let records: [Record] }
        let records = try JSONDecoder().decode(File.self, from: Data(contentsOf: fixture)).records
        XCTAssertGreaterThan(records.count, 150)
        var mismatches = [String]()
        for record in records where tokenizer.tokenize(record.text) != record.ids {
            mismatches.append("#\(record.id) native=\(tokenizer.tokenize(record.text).prefix(16)) python=\(record.ids.prefix(16))")
        }
        XCTAssertTrue(mismatches.isEmpty, "\(mismatches.count)/\(records.count) mismatches:\n" + mismatches.prefix(10).joined(separator: "\n"))
    }

    func testE5DeviceVectorsMatchPythonReference() throws {
        let reference = try e5File("reference-vectors.json")
        struct Vector: Decodable { let id: String; let text: String; let input_ids: [Int32]; let attention_mask: [Int32]; let vector: [Float] }
        struct File: Decodable { let vectors: [Vector] }
        let vectors = try JSONDecoder().decode(File.self, from: Data(contentsOf: reference)).vectors
        let environment = ProcessInfo.processInfo.environment
        let variants = environment["NOTED_E5_VARIANTS"]?.split(separator: ",").map(String.init) ?? ["fp16", "int8"]
        let units = Self.computeUnits(environment["NOTED_E5_UNITS"])
        for variant in variants {
            guard let engine = CoreMLEmbeddingEngine(variant: variant, computeUnits: units) else {
                throw XCTSkip("E5 \(variant) model absent")
            }
            print("NOTED_E5_PARITY \(variant) units=\(environment["NOTED_E5_UNITS"] ?? "cpuAndNeuralEngine")")
            let tokenizer = try engine.tokenizerForTesting()
            for record in vectors {
                let encoding = tokenizer.encode(record.text, maxLength: CoreMLEmbeddingEngine.maxTokens)
                XCTAssertEqual(encoding.inputIDs, record.input_ids, "\(variant) \(record.id) token IDs")
                XCTAssertEqual(encoding.attentionMask, record.attention_mask, "\(variant) \(record.id) mask")
                let native = try engine.embed(encoding: encoding)
                let cosine = try XCTUnwrap(EmbeddingMath.cosine(native, record.vector))
                print("NOTED_E5_PARITY \(variant) \(record.id) cosine=\(cosine)")
                XCTAssertGreaterThanOrEqual(cosine, 0.99, "\(variant) \(record.id)")
            }
        }
    }

    static func computeUnits(_ name: String?) -> MLComputeUnits {
        switch name {
        case "cpuOnly": .cpuOnly
        case "cpuAndGPU": .cpuAndGPU
        case "all": .all
        default: .cpuAndNeuralEngine
        }
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
