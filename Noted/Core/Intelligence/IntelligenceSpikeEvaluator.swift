#if DEBUG
import Foundation
import Vision

/// Immutable inputs copied from SwiftData on the main actor before running a spike.
struct IntelligenceSpikeSample: Sendable {
    let id: UUID
    let kind: String
    let text: String
    let hasOriginalText: Bool
    let imageURL: URL?
    let hasOCR: Bool
    let gold: String?
    let desiredTags: [String]
    let split: String?
}

struct IntelligenceSpikeReport: Codable, Sendable {
    struct Counts: Codable, Sendable {
        let total: Int
        let image: Int
        let link: Int
        let note: Int
        let imageWithOCR: Int
        let imageWithoutOCR: Int
        let labeled: Int
        let calibration: Int
        let holdout: Int
    }

    struct Confusion: Codable, Sendable {
        let gold: String
        let predicted: String
        let kind: String
        let count: Int
    }

    struct Candidate: Codable, Sendable {
        let name: String
        let engineVersion: String
        let status: String
        let threshold: Float?
        let margin: Float?
        let holdoutCorrect: Int
        let holdoutPredicted: Int
        let holdoutEvaluated: Int
        let precision: Double?
        let coverage: Double?
        let coverageForTextItems: Double?
        /// First embedding includes load plus inference, not isolated model load time.
        let coldStartMilliseconds: Double?
        let warmP95Milliseconds: Double?
        let unknownReductionForTextlessImages: Double?
        let confusion: [Confusion]
    }

    let schemaVersion: Int
    let generatedAt: Date
    let platform: String
    let buildVersion: String
    let counts: Counts
    let sufficientLabelsForGate: Bool
    let candidates: [Candidate]
    let visionProcessed: Int
    let visionFailures: Int
    let visionP95Milliseconds: Double?
    let notes: [String]
}

enum IntelligenceSpikeEvaluator {
    static let unknown = "Không rõ"
    private struct ConfusionKey: Hashable {
        let gold: String
        let predicted: String
        let kind: String
    }

    @MainActor
    static func snapshots(store: LibraryStore, labels: [UUID: IntelligenceLabel]) -> [IntelligenceSpikeSample] {
        store.items.filter { $0.trashedAt == nil }.map { item in
            var fields = [String]()
            if item.userEditedTitle { fields.append(item.title) }
            fields.append(item.body)
            fields.append(item.ocrText)
            fields.append(contentsOf: item.tags)
            if let url = URL(string: item.originalURL), let host = url.host { fields.append(host) }
            let label = labels[item.id]
            let text = fields.filter { !$0.isEmpty }.joined(separator: "\n")
            return IntelligenceSpikeSample(
                id: item.id, kind: item.kind,
                text: text, hasOriginalText: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                imageURL: item.kind == "image" ? item.attachments.first.map(store.attachmentURL) : nil,
                hasOCR: !item.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                gold: label?.topic, desiredTags: label?.desiredTags ?? [], split: label?.split
            )
        }
    }

    /// Evaluates locally. Call from a detached task with snapshots, never with SwiftData models.
    static func evaluate(_ samples: [IntelligenceSpikeSample]) -> IntelligenceSpikeReport {
        let labeled = samples.filter { $0.gold != nil }
        let calibration = labeled.filter { $0.split == "calibration" }
        let holdout = labeled.filter { $0.split == "holdout" }
        let topicCounts = Dictionary(grouping: labeled.filter { $0.gold != unknown }, by: { $0.gold! }).mapValues(\.count)
        let holdoutCounts = Dictionary(grouping: holdout.filter { $0.gold != unknown }, by: { $0.gold! }).mapValues(\.count)
        let calibrationCounts = Dictionary(grouping: calibration.filter { $0.gold != unknown }, by: { $0.gold! }).mapValues(\.count)
        let sufficient = labeled.count >= 150 && topicCounts.values.allSatisfy { $0 >= 10 }
            && !topicCounts.isEmpty && topicCounts.keys.allSatisfy {
                (holdoutCounts[$0] ?? 0) >= 1 && (calibrationCounts[$0] ?? 0) >= 2
            }
        let image = samples.filter { $0.kind == "image" }
        let counts = IntelligenceSpikeReport.Counts(
            total: samples.count, image: image.count,
            link: samples.filter { $0.kind == "link" }.count,
            note: samples.filter { $0.kind == "text" }.count,
            imageWithOCR: image.filter(\.hasOCR).count,
            imageWithoutOCR: image.filter { !$0.hasOCR }.count,
            labeled: labeled.count, calibration: calibration.count, holdout: holdout.count
        )

        // Topic names alone make an intentionally weak, reproducible lexical baseline.
        let topics = Array(Set(calibration.compactMap(\.gold).filter { $0 != unknown })).sorted().map {
            KeywordBaseline.Topic(name: $0, aliases: [$0])
        }
        let baselinePredictions = holdout.map { (sample: $0, predicted: KeywordBaseline.predict($0.text, topics: topics)) }
        let baseline = candidate(name: "Topic-name keyword baseline", engineVersion: "keyword-topic-name-v1",
                                 status: topics.isEmpty ? "insufficient calibration labels" : "measured; not AI",
                                 threshold: nil, margin: nil, predictions: baselinePredictions, timings: [])

        var notes = [String]()
        if !sufficient { notes.append("Label gate unmet: need at least 150 labels, 10 per topic, and a nonempty holdout; metrics are exploratory.") }
        var visionTimings = [Double]()
        var visionFailures = 0
        var visionProcessed = 0
        var visionWords: [UUID: String] = [:]
        var featurePrints: [UUID: VNFeaturePrintObservation] = [:]
        var visionVersion = "vision-unavailable"
        for sample in image {
            guard let url = sample.imageURL else { visionFailures += 1; continue }
            let start = ProcessInfo.processInfo.systemUptime
            do {
                let signal = try ImageSignals.analyze(url: url)
                visionTimings.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
                visionProcessed += 1
                visionWords[sample.id] = signal.labels.prefix(5).map(\.name).joined(separator: " ")
                featurePrints[sample.id] = signal.featurePrint
                visionVersion = "vision-classify-r\(signal.classifyRevision)-feature-r\(signal.featurePrintRevision)-v1"
            } catch {
                visionFailures += 1
            }
        }
        if visionFailures > 0 { notes.append("Vision failures: \(visionFailures); no image-quality claim can use those samples.") }
        // Vision labels enrich text only after signals are available. Original text
        // presence is retained separately for the text-only coverage calculation.
        let enriched = samples.map { sample in
            IntelligenceSpikeSample(id: sample.id, kind: sample.kind,
                                    text: [sample.text, visionWords[sample.id] ?? ""].filter { !$0.isEmpty }.joined(separator: "\n"),
                                    hasOriginalText: sample.hasOriginalText, imageURL: sample.imageURL,
                                    hasOCR: sample.hasOCR, gold: sample.gold,
                                    desiredTags: sample.desiredTags, split: sample.split)
        }

        let contextual = evaluateContextual(enriched)
        let nearestImage = evaluateImageNearestNeighbor(samples, featurePrints: featurePrints,
                                                        baselinePredictions: baselinePredictions,
                                                        engineVersion: visionVersion)
        notes.append("No E5 native tokenizer/vector parity, tag precision, or semantic recall@10 is measured here.")
        return IntelligenceSpikeReport(
            schemaVersion: 1, generatedAt: Date(),
            platform: "\(ProcessInfo.processInfo.operatingSystemVersionString)\(isSimulator ? " simulator" : " device")",
            buildVersion: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"))",
            counts: counts, sufficientLabelsForGate: sufficient,
            candidates: [baseline, contextual, nearestImage], visionProcessed: visionProcessed,
            visionFailures: visionFailures, visionP95Milliseconds: p95(visionTimings), notes: notes
        )
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private static func evaluateContextual(_ samples: [IntelligenceSpikeSample]) -> IntelligenceSpikeReport.Candidate {
        guard let engine = ContextualEmbeddingEngine() else {
            return candidate(name: "Apple NL contextual", engineVersion: "unavailable", status: "Vietnamese model unavailable",
                             threshold: nil, margin: nil, predictions: [], timings: [])
        }
        guard engine.hasAvailableAssets else {
            return candidate(name: "Apple NL contextual", engineVersion: engine.engineVersion, status: "assets unavailable; no automatic download",
                             threshold: nil, margin: nil, predictions: [], timings: [])
        }
        var vectors: [UUID: [Float]] = [:]
        var timings = [Double]()
        var errors = 0
        for sample in samples where !sample.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let start = ProcessInfo.processInfo.systemUptime
            do {
                vectors[sample.id] = try engine.embed(sample.text, role: .passage)
                timings.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
            } catch { errors += 1 }
        }
        let calibration = samples.filter { $0.split == "calibration" && $0.gold != nil && vectors[$0.id] != nil }
        let knownCalibration = calibration.filter { $0.gold != unknown }
        let holdout = samples.filter { $0.split == "holdout" && $0.gold != nil }
        guard !knownCalibration.isEmpty else {
            return candidate(name: "Apple NL contextual", engineVersion: engine.engineVersion,
                             status: "no usable calibration vectors; \(errors) embedding errors",
                             threshold: nil, margin: nil, predictions: [], timings: timings)
        }
        let rankings = calibration.map { sample in
            (sample: sample, ranked: rank(vectors[sample.id]!, prototypes: prototypes(
                knownCalibration.filter { $0.id != sample.id }, vectors)))
        }
        let grid: [(Float, Float)] = (0...18).flatMap { a in (0...10).map { b in (Float(a) * 0.05, Float(b) * 0.02) } }
        var best: (threshold: Float, margin: Float, correct: Int, predicted: Int)?
        for (threshold, margin) in grid {
            let predictions = rankings.map { row -> (IntelligenceSpikeSample, String?) in
                return (row.sample, predict(row.ranked, threshold: threshold, margin: margin))
            }
            let predicted = predictions.filter { $0.1 != nil }.count
            let correct = predictions.filter { $0.1 == $0.0.gold }.count
            guard predicted > 0, Double(correct) / Double(predicted) >= 0.85 else { continue }
            if best == nil || correct > best!.correct || (correct == best!.correct && predicted > best!.predicted) {
                best = (threshold, margin, correct, predicted)
            }
        }
        guard let selected = best else {
            return candidate(name: "Apple NL contextual", engineVersion: engine.engineVersion,
                             status: "no calibration threshold reached 85% precision; \(errors) embedding errors",
                             threshold: nil, margin: nil, predictions: [], timings: timings)
        }
        let centers = prototypes(knownCalibration, vectors)
        let predictions = holdout.map { sample in
            (sample: sample, predicted: vectors[sample.id].flatMap {
                predict(rank($0, prototypes: centers), threshold: selected.threshold, margin: selected.margin)
            })
        }
        return candidate(name: "Apple NL contextual", engineVersion: engine.engineVersion,
                         status: "exploratory holdout; \(errors) embedding errors", threshold: selected.threshold,
                         margin: selected.margin, predictions: predictions,
                         timings: Array(timings.dropFirst()), coldLoad: timings.first)
    }

    /// One nearest labeled image, with its distance cutoff chosen by calibration leave-one-out.
    private static func evaluateImageNearestNeighbor(
        _ samples: [IntelligenceSpikeSample], featurePrints: [UUID: VNFeaturePrintObservation],
        baselinePredictions: [(sample: IntelligenceSpikeSample, predicted: String?)],
        engineVersion: String
    ) -> IntelligenceSpikeReport.Candidate {
        let calibration = samples.filter {
            $0.kind == "image" && $0.split == "calibration" && $0.gold != nil && featurePrints[$0.id] != nil
        }
        let knownCalibration = calibration.filter { $0.gold != unknown }
        let holdout = samples.filter { $0.kind == "image" && $0.split == "holdout" && $0.gold != nil }
        guard knownCalibration.count >= 2, !holdout.isEmpty else {
            return candidate(name: "Vision feature-print 1-NN", engineVersion: engineVersion,
                             status: "insufficient labeled calibration/holdout images", threshold: nil,
                             margin: nil, predictions: [], timings: [])
        }
        let calibrationRankings = calibration.map { sample in
            (sample: sample, ranked: nearest(sample, among: knownCalibration.filter { $0.id != sample.id }, featurePrints: featurePrints))
        }
        let candidateDistances = Array(Set(calibrationRankings.compactMap { $0.ranked.first?.1 })).sorted()
        var best: (threshold: Float, correct: Int, predicted: Int)?
        for threshold in candidateDistances {
            let rows = calibrationRankings.map { ($0.sample, imagePrediction($0.ranked, threshold: threshold)) }
            let predicted = rows.filter { $0.1 != nil }.count
            let correct = rows.filter { $0.1 == $0.0.gold }.count
            guard predicted > 0, Double(correct) / Double(predicted) >= 0.85 else { continue }
            if best == nil || correct > best!.correct || (correct == best!.correct && predicted > best!.predicted) {
                best = (threshold, correct, predicted)
            }
        }
        guard let selected = best else {
            return candidate(name: "Vision feature-print 1-NN", engineVersion: engineVersion,
                             status: "no calibration distance reached 85% precision", threshold: nil,
                             margin: nil, predictions: [], timings: [])
        }
        let predictions = holdout.map { sample in
            (sample: sample, predicted: imagePrediction(nearest(sample, among: knownCalibration,
                                                                  featurePrints: featurePrints), threshold: selected.threshold))
        }
        let baselineUnknownIDs = Set(baselinePredictions.filter { $0.predicted == nil }.map { $0.sample.id })
        let textless = predictions.filter {
            !$0.sample.hasOCR && featurePrints[$0.sample.id] != nil && baselineUnknownIDs.contains($0.sample.id)
        }
        let baselineUnknown = textless.count
        let featureUnknown = textless.filter { $0.predicted == nil }.count
        let reduction = baselineUnknown > 0 ? Double(baselineUnknown - featureUnknown) / Double(baselineUnknown) : nil
        return candidate(name: "Vision feature-print 1-NN", engineVersion: engineVersion,
                         status: "exploratory holdout; image only", threshold: selected.threshold,
                         margin: nil, predictions: predictions, timings: [], unknownReduction: reduction)
    }

    private static func nearest(_ sample: IntelligenceSpikeSample, among peers: [IntelligenceSpikeSample],
                                featurePrints: [UUID: VNFeaturePrintObservation]) -> [(String, Float)] {
        guard let image = featurePrints[sample.id] else { return [] }
        return peers.compactMap { peer -> (String, Float)? in
            guard let other = featurePrints[peer.id], let gold = peer.gold,
                  let distance = try? ImageSignals.distance(image, other) else { return nil }
            return (gold, distance)
        }.sorted { $0.1 < $1.1 }
    }

    private static func imagePrediction(_ ranked: [(String, Float)], threshold: Float) -> String? {
        guard let first = ranked.first, first.1 <= threshold else { return nil }
        if let second = ranked.dropFirst().first, first.1 >= second.1 { return nil }
        return first.0
    }

    private static func prototypes(_ samples: [IntelligenceSpikeSample], _ vectors: [UUID: [Float]]) -> [String: [Float]] {
        Dictionary(grouping: samples, by: { $0.gold! }).compactMapValues { group in
            guard let first = group.first.flatMap({ vectors[$0.id] }) else { return nil }
            var sum = [Float](repeating: 0, count: first.count)
            for sample in group {
                guard let vector = vectors[sample.id], vector.count == sum.count else { continue }
                for index in sum.indices { sum[index] += vector[index] }
            }
            return try? EmbeddingMath.normalized(sum)
        }
    }

    private static func rank(_ vector: [Float], prototypes: [String: [Float]]) -> [(String, Float)] {
        prototypes.compactMap { key, center in EmbeddingMath.cosine(vector, center).map { (key, $0) } }
            .sorted { $0.1 > $1.1 }
    }

    private static func predict(_ ranked: [(String, Float)], threshold: Float, margin: Float) -> String? {
        guard let first = ranked.first, first.1 >= threshold else { return nil }
        if let second = ranked.dropFirst().first,
           first.1 <= second.1 || first.1 - second.1 < margin { return nil }
        return first.0
    }

    private static func candidate(name: String, engineVersion: String, status: String, threshold: Float?, margin: Float?,
                                  predictions: [(sample: IntelligenceSpikeSample, predicted: String?)],
                                  timings: [Double], coldLoad: Double? = nil,
                                  unknownReduction: Double? = nil) -> IntelligenceSpikeReport.Candidate {
        let evaluated = predictions.count
        let predicted = predictions.filter { $0.predicted != nil }.count
        let correct = predictions.filter { $0.predicted == $0.sample.gold }.count
        let textRows = predictions.filter(\.sample.hasOriginalText)
        let textPredicted = textRows.filter { $0.predicted != nil }.count
        let grouped = Dictionary(grouping: predictions) { row in
            ConfusionKey(gold: row.sample.gold ?? unknown, predicted: row.predicted ?? unknown,
                         kind: row.sample.kind)
        }
        let confusion = grouped.map { key, rows -> IntelligenceSpikeReport.Confusion in
            .init(gold: key.gold, predicted: key.predicted, kind: key.kind, count: rows.count)
        }.sorted { a, b in
            if a.kind != b.kind { return a.kind < b.kind }
            if a.gold != b.gold { return a.gold < b.gold }
            return a.predicted < b.predicted
        }
        return .init(name: name, engineVersion: engineVersion, status: status,
                     threshold: threshold, margin: margin, holdoutCorrect: correct,
                     holdoutPredicted: predicted, holdoutEvaluated: evaluated,
                     precision: predicted > 0 ? Double(correct) / Double(predicted) : nil,
                     coverage: evaluated > 0 ? Double(predicted) / Double(evaluated) : nil,
                     coverageForTextItems: textRows.isEmpty ? nil : Double(textPredicted) / Double(textRows.count),
                     coldStartMilliseconds: coldLoad,
                     warmP95Milliseconds: p95(timings),
                     unknownReductionForTextlessImages: unknownReduction,
                     confusion: confusion)
    }

    private static func p95(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
    }
}
#endif
