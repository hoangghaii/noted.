import Foundation
import UniformTypeIdentifiers

struct PreparedAttachment: Sendable {
    let id: UUID
    let relativePath: String
    let size: Int64
    let checksum: String
    let typeIdentifier: String
}

struct PreparedCapture: Sendable {
    let id: UUID
    let captureID: String
    let kind: String
    let title: String
    let body: String
    let originalURL: String
    let createdAt: Date
    let attachment: PreparedAttachment?
}

enum CaptureImporter {
    /// Filesystem work only. SwiftData instances are created by the single main-actor writer.
    static func prepare(directory: URL, queue: ShareGateStore, libraryRoot: URL) throws -> [PreparedCapture] {
        let payload = try queue.readPayload(at: directory)
        return try payload.entries.map { entry in
            var attachment: PreparedAttachment?
            var title = ""
            var body = payload.caption
            var originalURL = ""
            switch entry.kind {
            case .text:
                body = entry.value
                if !payload.caption.isEmpty && payload.caption != entry.value { body += "\n" + payload.caption }
                title = String(entry.value.split(separator: "\n", maxSplits: 1).first ?? "").prefix(100).description
            case .link:
                guard let url = URL(string: entry.value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                      url.host != nil else { throw LibraryError.invalidLink }
                originalURL = entry.value
                title = url.host ?? entry.value
            case .image:
                guard let source = queue.imageURL(payload: payload.id, name: entry.value) else { throw LibraryError.invalidAttachment }
                attachment = try AttachmentStore(root: libraryRoot).prepareImage(source: source, batchID: payload.id, entryID: entry.id)
                title = "Ảnh"
            }
            return PreparedCapture(id: entry.id, captureID: payload.id.uuidString + "." + entry.id.uuidString,
                                   kind: entry.kind.rawValue, title: title, body: body, originalURL: originalURL,
                                   createdAt: payload.createdAt, attachment: attachment)
        }
    }
}

enum CaptureFaultPoint: Equatable { case afterFilesPrepared, beforeMetadataSave, afterMetadataSave, beforeSourceCleanup }

struct CaptureIssue: Identifiable {
    let id: UUID
    let message: String
    let isPartial: Bool
}
