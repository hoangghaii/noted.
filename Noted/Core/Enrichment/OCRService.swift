import Foundation
import Vision
import ImageIO

struct OCRResult: Sendable {
    let text: String
    let supportedLanguages: [String]
}

enum OCRService {
    static func recognize(url: URL) async throws -> OCRResult {
        try await Task.detached(priority: .utility) {
            try Task.checkCancellation()
            // Bound the image decoded for OCR. The original file is never changed.
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400
                  ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let languages = try request.supportedRecognitionLanguages()
            // Use the language identifiers returned by this Vision runtime, including
            // regional variants; do not assume its Vietnamese tag is always vi-VN.
            let preferred = ["vi", "en", "ja"].compactMap { prefix in
                languages.first(where: { $0 == prefix || $0.hasPrefix(prefix + "-") })
            }
            if !preferred.isEmpty { request.recognitionLanguages = preferred }
            request.automaticallyDetectsLanguage = true
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            try Task.checkCancellation()
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            return OCRResult(text: text, supportedLanguages: languages)
        }.value
    }
}
