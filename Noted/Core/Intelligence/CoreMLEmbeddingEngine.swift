import CoreML
import Foundation

/// multilingual-e5-small converted by `scripts/topic-model-evaluation/export.py`.
/// Spike only: model files are copied into Application Support for evaluation, not bundled.
final class CoreMLEmbeddingEngine: TextEmbeddingEngine {
    static let revision = "fd1525a9fd15316a2d503bf26ab031a61d056e98"
    static let maxTokens = 128
    /// Bounds long OCR: at most this many 126-token windows are embedded and averaged.
    static let maxChunks = 8

    let variant: String
    let engineVersion: String
    private let modelURL: URL
    private let tokenizerURL: URL
    private var model: MLModel?
    private var tokenizer: XLMRobertaTokenizer?
    private var prefixIDs: [EmbeddingRole: [Int32]] = [:]
    private let computeUnits: MLComputeUnits

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IntelligenceEvaluation/e5", isDirectory: true)
    }

    /// Returns nil when the compiled model for `variant` has not been copied to the device.
    /// `.all`/`.cpuAndGPU` hit `LLVM ERROR: out of memory` for int8 on iPhone 12 Pro and
    /// `.cpuOnly` returned NaN; the Neural Engine path matched the Python reference.
    init?(variant: String, computeUnits: MLComputeUnits = .cpuAndNeuralEngine,
          directory: URL = CoreMLEmbeddingEngine.defaultDirectory) {
        let modelURL = directory.appendingPathComponent("e5-\(variant).mlmodelc", isDirectory: true)
        let tokenizerURL = directory.appendingPathComponent("tokenizer.json")
        guard FileManager.default.fileExists(atPath: modelURL.path),
              FileManager.default.fileExists(atPath: tokenizerURL.path) else { return nil }
        self.variant = variant
        self.modelURL = modelURL
        self.tokenizerURL = tokenizerURL
        self.computeUnits = computeUnits
        engineVersion = "e5-small-\(Self.revision.prefix(7))-\(variant)-t\(Self.maxTokens)-mean-v1"
    }

    /// Parses the tokenizer and loads the model; timed separately as cold load.
    func load() throws {
        guard model == nil else { return }
        let tokenizer = try XLMRobertaTokenizer(tokenizerJSON: tokenizerURL)
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        model = try MLModel(contentsOf: modelURL, configuration: configuration)
        // Metaspace splits per word, so the prefix tokenizes independently of the text.
        prefixIDs = [.query: tokenizer.tokenize("query:"), .passage: tokenizer.tokenize("passage:")]
        self.tokenizer = tokenizer
    }

    func tokenizerForTesting() throws -> XLMRobertaTokenizer {
        try load()
        return tokenizer!
    }

    func embed(_ text: String, role: EmbeddingRole) throws -> [Float] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw EmbeddingError.emptyInput }
        try load()
        guard let tokenizer, let prefix = prefixIDs[role] else { throw EmbeddingError.unavailable("E5 not loaded") }
        let content = tokenizer.tokenize(cleaned)
        let room = Self.maxTokens - 2 - prefix.count
        var sum = [Double]()
        var weight = 0.0
        for chunkStart in stride(from: 0, to: max(content.count, 1), by: room).prefix(Self.maxChunks) {
            let chunk = Array(content[chunkStart..<min(content.count, chunkStart + room)])
            let vector = try embed(encoding: tokenizer.window(prefix + chunk, maxLength: Self.maxTokens))
            if sum.isEmpty { sum = [Double](repeating: 0, count: vector.count) }
            // Weight by tokens so a short tail chunk does not dominate the average.
            let tokens = Double(max(1, chunk.count))
            for index in sum.indices { sum[index] += Double(vector[index]) * tokens }
            weight += tokens
        }
        guard weight > 0 else { throw EmbeddingError.emptyResult }
        return try EmbeddingMath.normalized(sum.map { Float($0 / weight) })
    }

    /// One fixed-length window through the Core ML model; output is already L2-normalized.
    func embed(encoding: XLMRobertaTokenizer.Encoding) throws -> [Float] {
        try load()
        guard let model else { throw EmbeddingError.unavailable("E5 not loaded") }
        let shape = [1, NSNumber(value: Self.maxTokens)]
        let ids = try MLMultiArray(shape: shape, dataType: .int32)
        let mask = try MLMultiArray(shape: shape, dataType: .int32)
        for index in 0..<Self.maxTokens {
            ids[index] = NSNumber(value: encoding.inputIDs[index])
            mask[index] = NSNumber(value: encoding.attentionMask[index])
        }
        let input = try MLDictionaryFeatureProvider(dictionary: ["input_ids": ids, "attention_mask": mask])
        guard let output = try model.prediction(from: input).featureValue(for: "embedding")?.multiArrayValue else {
            throw EmbeddingError.emptyResult
        }
        return (0..<output.count).map { output[$0].floatValue }
    }
}
