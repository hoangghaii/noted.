import Foundation
import SwiftData

@Model
final class Item {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var captureID: String
    var kind: String
    var title: String
    var body: String
    var originalURL: String
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool
    var trashedAt: Date?
    var collectionID: UUID?
    var tags: [String]
    var ocrText: String
    var ocrStatus: String
    var previewStatus: String
    var searchDocument: String
    var userEditedTitle: Bool
    @Relationship(deleteRule: .cascade) var attachments: [Attachment]

    init(id: UUID = UUID(), captureID: String, kind: String, title: String = "", body: String = "",
         originalURL: String = "", createdAt: Date = Date(), attachments: [Attachment] = []) {
        self.id = id
        self.captureID = captureID
        self.kind = kind
        self.title = title
        self.body = body
        self.originalURL = originalURL
        self.createdAt = createdAt
        updatedAt = createdAt
        pinned = false
        tags = []
        ocrText = ""
        ocrStatus = kind == "image" ? "pending" : "complete"
        previewStatus = kind == "link" ? "pending" : "complete"
        searchDocument = ""
        userEditedTitle = false
        self.attachments = attachments
        rebuildSearchDocument()
    }

    func rebuildSearchDocument() {
        searchDocument = Self.normalize(([title, body, originalURL, ocrText] + tags).joined(separator: " "))
    }

    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        if kind == "image" { return "Ảnh đã lưu" }
        if kind == "link" { return URL(string: originalURL)?.host ?? (originalURL.isEmpty ? "Liên kết" : originalURL) }
        return body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ghi chú" : String(body.prefix(160))
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased().replacingOccurrences(of: "đ", with: "d")
    }
}

@Model
final class Attachment {
    @Attribute(.unique) var id: UUID
    var relativePath: String
    var size: Int64
    var checksum: String
    var typeIdentifier: String

    init(id: UUID = UUID(), relativePath: String, size: Int64, checksum: String, typeIdentifier: String) {
        self.id = id
        self.relativePath = relativePath
        self.size = size
        self.checksum = checksum
        self.typeIdentifier = typeIdentifier
    }
}

@Model
final class ItemCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}

/// Remains after item deletion: a retry of an already-committed batch must not resurrect it.
@Model
final class ProcessedBatch {
    @Attribute(.unique) var id: UUID
    var processedAt: Date
    init(id: UUID) { self.id = id; processedAt = Date() }
}
