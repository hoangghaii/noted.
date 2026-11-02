import Foundation
import UniformTypeIdentifiers
import ImageIO

struct AttachmentStore {
    let root: URL

    func originalURL(relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    func prepareImage(source: URL, batchID: UUID, entryID: UUID) throws -> PreparedAttachment {
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= ShareGateStore.maximumFileBytes else { throw LibraryError.invalidAttachment }
        guard let image = CGImageSourceCreateWithURL(source as CFURL, nil),
              CGImageSourceCreateThumbnailAtIndex(image, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 64
              ] as CFDictionary) != nil else { throw LibraryError.invalidAttachment }
        let checksum = try ShareGateStore.checksum(source)
        let suffix = source.pathExtension.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(10)
        let name = entryID.uuidString + (suffix.isEmpty ? "" : "." + suffix)
        let relative = "originals/" + batchID.uuidString + "/" + name
        let destination = originalURL(relativePath: relative)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            guard try ShareGateStore.checksum(destination) == checksum else { throw LibraryError.invalidAttachment }
        } else {
            let temporary = destination.appendingPathExtension("partial")
            // A previous interrupted copy is unpublished and safe to replace from intact source.
            if FileManager.default.fileExists(atPath: temporary.path) { try FileManager.default.removeItem(at: temporary) }
            try FileManager.default.copyItem(at: source, to: temporary)
            guard try ShareGateStore.checksum(temporary) == checksum else { throw LibraryError.invalidAttachment }
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: temporary.path)
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
        return PreparedAttachment(id: entryID, relativePath: relative, size: Int64(size), checksum: checksum,
                          typeIdentifier: UTType(filenameExtension: String(suffix))?.identifier ?? UTType.image.identifier)
    }

    func validate(_ attachment: Attachment) throws {
        guard isSafe(relativePath: attachment.relativePath) else { throw LibraryError.invalidAttachment }
        let url = originalURL(relativePath: attachment.relativePath)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              Int64(values.fileSize ?? -1) == attachment.size,
              try ShareGateStore.checksum(url) == attachment.checksum else { throw LibraryError.invalidAttachment }
    }

    static func isSafe(relativePath: String) -> Bool {
        !relativePath.isEmpty && !relativePath.hasPrefix("/") && !relativePath.contains("\\") &&
        !relativePath.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
    }

    private func isSafe(relativePath: String) -> Bool { Self.isSafe(relativePath: relativePath) }
}
