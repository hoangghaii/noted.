import Foundation
import Vision
import ImageIO

struct ImageSignalResult {
    let labels: [(name: String, confidence: Float)]
    let featurePrint: VNFeaturePrintObservation
    let classifyRevision: Int
    let featurePrintRevision: Int
}

enum ImageSignals {
    static func analyze(url: URL, minimumConfidence: Float = 0.15) throws -> ImageSignalResult {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let classifier = VNClassifyImageRequest()
        let printRequest = VNGenerateImageFeaturePrintRequest()
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([classifier, printRequest])
        guard let featurePrint = printRequest.results?.first else { throw EmbeddingError.emptyResult }
        let labels = (classifier.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
            .map { (name: $0.identifier, confidence: $0.confidence) }
        return ImageSignalResult(labels: labels, featurePrint: featurePrint,
                                 classifyRevision: classifier.revision,
                                 featurePrintRevision: printRequest.revision)
    }

    static func distance(_ lhs: VNFeaturePrintObservation, _ rhs: VNFeaturePrintObservation) throws -> Float {
        var distance: Float = 0
        try lhs.computeDistance(&distance, to: rhs)
        return distance
    }
}
