import UIKit
import ImageIO

actor ThumbnailService {
    static let shared = ThumbnailService()
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 32
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func image(at url: URL, maxPixelSize: Int = 800) throws -> UIImage {
        let key = (url.path + ":" + String(maxPixelSize)) as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let result = UIImage(cgImage: image)
        cache.setObject(result, forKey: key, cost: image.bytesPerRow * image.height)
        return result
    }
}
