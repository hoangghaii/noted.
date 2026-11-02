import Foundation
import CryptoKit

/// Shared capture transport. The name and directory retain compatibility with phase-01 data.
/// A ready directory is immutable and only published after every attachment is copied.
struct ShareGatePayload: Codable, Identifiable {
    struct Entry: Codable, Identifiable {
        enum Kind: String, Codable { case text, link, image }
        var id = UUID()
        let kind: Kind
        let value: String
        var byteCount: Int64? = nil
        var sha256: String? = nil
    }

    var id = UUID()
    var createdAt = Date()
    var caption = ""
    var entries: [Entry] = []
    // Optional so phase-01 manifests remain readable without rewriting originals.
    var schemaVersion: Int? = 1
}

enum ShareGateError: LocalizedError {
    case unavailableGroup, unsupported, tooLarge, invalidPayload

    var errorDescription: String? {
        switch self {
        case .unavailableGroup: "Không truy cập được vùng lưu chung. Kiểm tra signing và App Group."
        case .unsupported: "Nội dung này chưa được hỗ trợ. Hãy chia sẻ ảnh, link hoặc văn bản."
        case .tooLarge: "Mỗi lần lưu hỗ trợ tối đa 3 mục, mỗi ảnh 20 MB. Nội dung chưa được lưu."
        case .invalidPayload: "Dữ liệu chia sẻ chưa đầy đủ. Nội dung gốc vẫn được giữ."
        }
    }
}

struct ShareGateStore {
    static let maximumEntries = 3
    static let maximumFileBytes = 20 * 1024 * 1024
    let root: URL

    static func textOnlyPayload(_ text: String) throws -> ShareGatePayload {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ShareGateError.unsupported }
        var payload = ShareGatePayload()
        payload.entries = [.init(kind: .text, value: text)]
        return payload
    }

    static func configured(bundle: Bundle = .main) throws -> ShareGateStore {
        guard let group = bundle.object(forInfoDictionaryKey: "NotedAppGroupIdentifier") as? String,
              !group.isEmpty, !group.contains("$("),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw ShareGateError.unavailableGroup }
        return ShareGateStore(root: container.appendingPathComponent("ShareGate", isDirectory: true))
    }

    func begin(id: UUID) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let directory = root.appendingPathComponent(id.uuidString + ".partial", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    /// Must be called while NSItemProvider's temporary file is still valid.
    static func copyImage(from source: URL, to directory: URL, extension suffix: String) throws -> String {
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumFileBytes else { throw ShareGateError.tooLarge }
        let safeExtension = suffix.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(10)
        let name = UUID().uuidString + "." + (safeExtension.isEmpty ? "image" : String(safeExtension))
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(name))
        return name
    }

    func publish(_ input: ShareGatePayload, directory: URL) throws {
        var payload = input
        guard directory == root.appendingPathComponent(payload.id.uuidString + ".partial", isDirectory: true)
        else { throw ShareGateError.invalidPayload }
        try validate(payload, directory: directory)
        payload.schemaVersion = 1
        for index in payload.entries.indices where payload.entries[index].kind == .image {
            let url = directory.appendingPathComponent(payload.entries[index].value)
            payload.entries[index].byteCount = Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            payload.entries[index].sha256 = try Self.checksum(url)
        }
        let data = try JSONEncoder().encode(payload)
        try data.write(to: directory.appendingPathComponent("manifest.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        // Same-volume rename is the commit point; app ignores .partial directories.
        try FileManager.default.moveItem(at: directory, to: readyDirectory(payload.id))
    }

    func readAll() throws -> [ShareGatePayload] {
        try readyDirectories().map { try readPayload(at: $0) }.sorted { $0.createdAt > $1.createdAt }
    }

    func readyDirectories() throws -> [URL] {
        try directories().filter { $0.pathExtension == "ready" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func partialDirectories() throws -> [URL] {
        try directories().filter { $0.pathExtension == "partial" }
    }

    func readPayload(at directory: URL) throws -> ShareGatePayload {
        let manifest = directory.appendingPathComponent("manifest.json")
        let values = try manifest.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let bytes = values.fileSize, bytes <= Self.maximumFileBytes else { throw ShareGateError.invalidPayload }
        let payload = try JSONDecoder().decode(ShareGatePayload.self, from: Data(contentsOf: manifest))
        guard directory.standardizedFileURL == readyDirectory(payload.id).standardizedFileURL,
              payload.schemaVersion == nil || payload.schemaVersion == 1 else { throw ShareGateError.invalidPayload }
        try validate(payload, directory: directory)
        return payload
    }

    func removeCommittedBatch(_ id: UUID) throws {
        let directory = readyDirectory(id)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func discard(id: UUID) throws {
        for suffix in ["ready", "partial"] {
            let url = root.appendingPathComponent(id.uuidString + "." + suffix, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    static func checksum(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func directories() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
    }

    func imageURL(payload: UUID, name: String) -> URL? {
        guard isSafeName(name) else { return nil }
        return readyDirectory(payload).appendingPathComponent(name)
    }

    private func readyDirectory(_ id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString + ".ready", isDirectory: true)
    }

    private func validate(_ payload: ShareGatePayload, directory: URL) throws {
        guard !payload.entries.isEmpty, payload.entries.count <= Self.maximumEntries,
              Set(payload.entries.map(\.id)).count == payload.entries.count,
              payload.caption.utf8.count <= Self.maximumFileBytes else { throw ShareGateError.invalidPayload }
        for entry in payload.entries {
            guard !entry.value.isEmpty, entry.value.utf8.count <= Self.maximumFileBytes else { throw ShareGateError.invalidPayload }
            if entry.kind == .image {
                guard isSafeName(entry.value) else { throw ShareGateError.invalidPayload }
                let values = try directory.appendingPathComponent(entry.value)
                    .resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true,
                      let size = values.fileSize, size > 0, size <= Self.maximumFileBytes
                else { throw ShareGateError.invalidPayload }
                if let expected = entry.byteCount, expected != Int64(size) { throw ShareGateError.invalidPayload }
                if let expected = entry.sha256,
                   try Self.checksum(directory.appendingPathComponent(entry.value)) != expected { throw ShareGateError.invalidPayload }
            }
        }
    }

    private func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\")
    }
}
