import Foundation
import CryptoKit
import UniformTypeIdentifiers

extension UTType {
    static let notedBackup = UTType(exportedAs: "dev.nguyenhoanghai861.Noted.backup", conformingTo: .package)
}

struct BackupManifest: Codable, Sendable {
    var version = 1
    var exportedAt: Date
    var collections: [BackupCollection]
    var items: [BackupItem]
}

struct BackupCollection: Codable, Sendable { var id: UUID; var name: String }

struct BackupAttachment: Codable, Sendable {
    var id: UUID
    var path: String
    var size: Int64
    var checksum: String
    var typeIdentifier: String
}

struct BackupItem: Codable, Sendable {
    var id: UUID
    var captureID: String
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
    var userEditedTitle: Bool
    var attachments: [BackupAttachment]

    @MainActor init(_ item: Item) {
        id = item.id; captureID = item.captureID; kind = item.kind
        title = item.title; body = item.body; originalURL = item.originalURL
        createdAt = item.createdAt; updatedAt = item.updatedAt; pinned = item.pinned
        trashedAt = item.trashedAt; collectionID = item.collectionID; tags = item.tags
        ocrText = item.ocrText; ocrStatus = item.ocrStatus; previewStatus = item.previewStatus
        userEditedTitle = item.userEditedTitle
        attachments = item.attachments.map {
            BackupAttachment(id: $0.id, path: $0.relativePath, size: $0.size,
                             checksum: $0.checksum, typeIdentifier: $0.typeIdentifier)
        }
    }

    func fingerprint() throws -> String {
        var value = self
        let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        value.id = zero
        value.captureID = ""
        value.ocrStatus = ""; value.previewStatus = ""
        value.tags.sort()
        value.attachments.sort { ($0.checksum, $0.typeIdentifier, $0.size) < ($1.checksum, $1.typeIdentifier, $1.size) }
        for index in value.attachments.indices { value.attachments[index].path = ""; value.attachments[index].id = zero }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }
}

struct BackupExport: Identifiable {
    var id: URL { url }
    let url: URL
    let itemCount: Int
    let cutoff: Date
    let pendingCount: Int
}
struct BackupImportSummary { var inserted = 0; var skipped = 0; var conflicts = 0 }
enum BackupFaultPoint: Equatable { case beforeMetadataSave, afterMetadataSave }

enum BackupError: LocalizedError {
    case invalid(String), busy
    var errorDescription: String? {
        switch self {
        case .invalid(let message): "Backup không hợp lệ: " + message
        case .busy: "Một tác vụ dữ liệu đang chạy. Hãy thử lại sau."
        }
    }
}
