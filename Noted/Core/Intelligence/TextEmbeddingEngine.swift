import Foundation

enum EmbeddingRole {
    case query
    case passage
}

enum EmbeddingError: Error {
    case unavailable(String)
    case emptyInput
    case emptyResult
}

/// A candidate is only an evaluation engine until the holdout and device gates pass.
protocol TextEmbeddingEngine {
    var engineVersion: String { get }
    func embed(_ text: String, role: EmbeddingRole) throws -> [Float]
}

enum EmbeddingMath {
    static func normalized(_ vector: [Float]) throws -> [Float] {
        let squared = vector.reduce(0.0) { $0 + Double($1) * Double($1) }
        guard squared.isFinite, squared > 0 else { throw EmbeddingError.emptyResult }
        let length = Float(sqrt(squared))
        return vector.map { $0 / length }
    }

    static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Float? {
        guard !lhs.isEmpty, lhs.count == rhs.count else { return nil }
        return zip(lhs, rhs).reduce(0) { $0 + $1.0 * $1.1 }
    }
}
