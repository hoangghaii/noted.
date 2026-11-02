import Foundation
import SwiftData

enum NotedSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Item.self, Attachment.self, ItemCollection.self, ProcessedBatch.self] }
}

enum ModelStore {
    static let schemaVersion = 1

    static func open(root: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let versionFile = root.appendingPathComponent("schema-version.txt")
        if FileManager.default.fileExists(atPath: versionFile.path) {
            let version = try String(contentsOf: versionFile, encoding: .utf8)
            guard version.trimmingCharacters(in: .whitespacesAndNewlines) == String(schemaVersion) else {
                throw LibraryError.unsupportedSchema
            }
        }
        let schema = Schema(versionedSchema: NotedSchemaV1.self)
        let config = ModelConfiguration("Noted", schema: schema, url: root.appendingPathComponent("library.store"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        // Never destroy/recreate a failed store. Future schema changes require an explicit
        // migration plan and a closed-store snapshot; v1 rejects unknown version markers.
        if !FileManager.default.fileExists(atPath: versionFile.path) {
            try String(schemaVersion).write(to: versionFile, atomically: true, encoding: .utf8)
        }
        return container
    }
}

enum LibraryError: LocalizedError {
    case unsupportedSchema, emptyContent, invalidLink, invalidName, invalidAttachment, identityCollision, operationInProgress
    var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "Phiên bản dữ liệu chưa được hỗ trợ. Không xóa hoặc gỡ app; hãy giữ bản backup."
        case .emptyContent: "Hãy nhập nội dung trước khi lưu."
        case .invalidLink: "Link phải dùng http hoặc https."
        case .invalidName: "Tên bộ sưu tập không được để trống."
        case .invalidAttachment: "File ảnh thiếu hoặc không khớp dữ liệu. File nguồn vẫn được giữ để thử lại."
        case .identityCollision: "Mã nội dung trùng với một mục đã có. Lượt lưu nguồn được giữ để xử lý, thư viện hiện tại không bị thay thế."
        case .operationInProgress: "Đang xử lý dữ liệu. Hãy thử lại sau."
        }
    }
}
