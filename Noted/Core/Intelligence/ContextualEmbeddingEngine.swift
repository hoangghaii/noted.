import Foundation
import NaturalLanguage

/// Apple's downloadable contextual model, evaluated without requesting assets silently.
final class ContextualEmbeddingEngine: TextEmbeddingEngine {
    private let model: NLContextualEmbedding
    let engineVersion: String

    init?(language: NLLanguage = .vietnamese) {
        guard let model = NLContextualEmbedding(language: language),
              model.languages.contains(language) else { return nil }
        self.model = model
        engineVersion = "nl-contextual-\(model.modelIdentifier)-r\(model.revision)-mean-v1"
    }

    var supportedLanguages: [String] { model.languages.map(\.rawValue) }
    var hasAvailableAssets: Bool { model.hasAvailableAssets }
    var maximumSequenceLength: Int { model.maximumSequenceLength }

    func embed(_ text: String, role: EmbeddingRole) throws -> [Float] {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw EmbeddingError.emptyInput }
        guard model.hasAvailableAssets else { throw EmbeddingError.unavailable("Contextual assets absent") }
        try model.load()

        // Character chunks are a conservative proxy, not a tokenizer guarantee.
        // Token coverage must be checked on real OCR data before accepting this engine.
        let chunks = Self.chunks(cleaned, maximumCharacters: min(180, max(48, model.maximumSequenceLength / 3)))
        var sum = [Double](repeating: 0, count: model.dimension)
        var count = 0
        for chunk in chunks {
            let result = try model.embeddingResult(for: chunk, language: nil)
            result.enumerateTokenVectors(in: result.string.startIndex..<result.string.endIndex) { vector, _ in
                guard vector.count == sum.count else { return true }
                for index in sum.indices { sum[index] += vector[index] }
                count += 1
                return true
            }
        }
        guard count > 0 else { throw EmbeddingError.emptyResult }
        return try EmbeddingMath.normalized(sum.map { Float($0 / Double(count)) })
    }

    static func chunks(_ text: String, maximumCharacters: Int) -> [String] {
        let limit = max(1, maximumCharacters)
        var output: [String] = []
        var current = ""
        for word in text.split(whereSeparator: \.isWhitespace) {
            let candidate = String(word)
            if current.count + candidate.count + 1 > limit && !current.isEmpty {
                output.append(current)
                current = ""
            }
            // Very long OCR words also need a hard boundary.
            var remainder = candidate[...]
            while remainder.count > limit {
                output.append(String(remainder.prefix(limit)))
                remainder = remainder.dropFirst(limit)
            }
            if !remainder.isEmpty { current += (current.isEmpty ? "" : " ") + remainder }
        }
        if !current.isEmpty { output.append(current) }
        return output
    }
}
