import Foundation
import SwiftData
import CryptoKit
import UniformTypeIdentifiers

@MainActor
final class BackupService {
    nonisolated static let maximumItems = 10_000
    nonisolated static let maximumBytes: Int64 = 5 * 1024 * 1024 * 1024
    var faultInjector: ((BackupFaultPoint) throws -> Void)?

    func export(store: LibraryStore) async throws -> BackupExport {
        guard !store.isDataOperationInProgress else { throw BackupError.busy }
        try await store.importPending()
        guard !store.isImporting else { throw BackupError.busy }
        store.isDataOperationInProgress = true
        defer { store.isDataOperationInProgress = false }
        let cutoff = Date()
        let records = store.items.map(BackupItem.init)
        let manifest = BackupManifest(exportedAt: cutoff,
            collections: store.collections.map { BackupCollection(id: $0.id, name: $0.name) }, items: records)
        let originals = Dictionary(uniqueKeysWithValues: store.items.flatMap(\.attachments).map { ($0.id, store.attachmentURL($0)) })
        let output = try await Task.detached(priority: .userInitiated) {
            try Self.writePackage(manifest: manifest, originals: originals)
        }.value
        return BackupExport(url: output, itemCount: records.count, cutoff: cutoff, pendingCount: store.pendingMessages.count)
    }

    func importPackage(at package: URL, into store: LibraryStore) async throws -> BackupImportSummary {
        guard !store.isDataOperationInProgress, !store.isImporting else { throw BackupError.busy }
        store.isDataOperationInProgress = true
        defer { store.isDataOperationInProgress = false }
        let access = package.startAccessingSecurityScopedResource()
        defer { if access { package.stopAccessingSecurityScopedResource() } }
        let manifest = try await Task.detached(priority: .userInitiated) {
            try Self.readValidatedPackage(package)
        }.value
        let root = store.root
        // Keep the validated manifest as a recovery journal until the metadata save succeeds.
        let journal = root.appendingPathComponent("backup-import-journal.json")
        try JSONEncoder().encode(manifest).write(to: journal, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let destinations = try await Task.detached(priority: .userInitiated) {
            try Self.prepareOriginals(manifest, package: package, libraryRoot: root)
        }.value
        var summary = BackupImportSummary()
        do {
            var collectionMap: [UUID: UUID] = [:]
            var knownCollections = Dictionary(uniqueKeysWithValues: store.collections.map { ($0.id, $0) })
            for record in manifest.collections {
                var targetID = record.id
                if let prior = knownCollections[targetID], prior.name != record.name {
                    targetID = Self.stableID("collection/" + record.id.uuidString + "/" + record.name)
                }
                if knownCollections[targetID] == nil {
                    let collection = ItemCollection(id: targetID, name: record.name)
                    store.context.insert(collection); knownCollections[targetID] = collection
                }
                collectionMap[record.id] = targetID
            }
            var existing = Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) })
            var captureIDs = Set(store.items.map(\.captureID))
            var attachmentIDs = Set(store.items.flatMap(\.attachments).map(\.id))
            for record in manifest.items {
                let fingerprint = try record.fingerprint()
                let baseKey = "backup-" + record.id.uuidString + "-" + fingerprint
                let mappedCollection = record.collectionID.flatMap { collectionMap[$0] }
                let candidates = existing.values.filter {
                    $0.id == record.id || $0.captureID == baseKey || $0.captureID.hasPrefix(baseKey + "/")
                }
                if try candidates.contains(where: { current in
                    guard current.collectionID == mappedCollection else { return false }
                    var canonical = BackupItem(current)
                    canonical.collectionID = record.collectionID
                    return try canonical.fingerprint() == fingerprint
                }) {
                    summary.skipped += 1; continue
                }
                let conflict = existing[record.id] != nil
                var restoreKey = baseKey
                var version = 1
                while captureIDs.contains(restoreKey) {
                    restoreKey = baseKey + "/" + String(version)
                    version += 1
                }
                let id = conflict ? Self.stableID(restoreKey) : record.id
                guard existing[id] == nil else { throw BackupError.invalid("ID xung đột không thể hợp nhất an toàn.") }
                let item = Item(id: id, captureID: restoreKey, kind: record.kind, title: record.title,
                                body: record.body, originalURL: record.originalURL, createdAt: record.createdAt)
                item.updatedAt = record.updatedAt; item.pinned = record.pinned; item.trashedAt = record.trashedAt
                item.collectionID = mappedCollection; item.tags = record.tags
                item.ocrText = record.ocrText; item.ocrStatus = record.ocrStatus == "running" ? "pending" : record.ocrStatus
                item.previewStatus = record.previewStatus == "running" ? "pending" : record.previewStatus
                item.userEditedTitle = record.userEditedTitle
                item.attachments = try record.attachments.map { attachment in
                    guard let relative = destinations[attachment.id] else { throw BackupError.invalid("Thiếu file đã xác minh.") }
                    // Attachment IDs must remain unique even when two versions of an item are preserved.
                    let attachmentID = conflict || attachmentIDs.contains(attachment.id)
                        ? Self.stableID(restoreKey + attachment.id.uuidString) : attachment.id
                    guard attachmentIDs.insert(attachmentID).inserted else { throw BackupError.invalid("ID ảnh xung đột; không ghi đè.") }
                    return Attachment(id: attachmentID, relativePath: relative, size: attachment.size,
                                      checksum: attachment.checksum, typeIdentifier: attachment.typeIdentifier)
                }
                item.rebuildSearchDocument(); store.context.insert(item)
                existing[id] = item; captureIDs.insert(restoreKey); summary.inserted += 1
                if conflict { summary.conflicts += 1 }
            }
            #if DEBUG
            try faultInjector?(.beforeMetadataSave)
            #endif
            try store.saveChanges()
            #if DEBUG
            try faultInjector?(.afterMetadataSave)
            #endif
            try? FileManager.default.removeItem(at: journal)
            return summary
        } catch {
            store.context.rollback(); try? store.refresh()
            // Originals copied before commit are immutable; retain journal for retry, never delete live files.
            throw error
        }
    }

    nonisolated static func stableID(_ string: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(string.utf8)).prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }

    nonisolated private static func writePackage(manifest: BackupManifest, originals: [UUID: URL]) throws -> URL {
        let fm = FileManager.default
        let parent = fm.temporaryDirectory.appendingPathComponent("NotedBackup-" + UUID().uuidString, isDirectory: true)
        let temporary = parent.appendingPathComponent("Backup.partial", isDirectory: true)
        let ready = parent.appendingPathComponent("Noted-" + ISO8601DateFormatter().string(from: manifest.exportedAt).replacingOccurrences(of: ":", with: "-") + ".notedbackup", isDirectory: true)
        try fm.createDirectory(at: temporary.appendingPathComponent("originals"), withIntermediateDirectories: true)
        var output = manifest
        var total: Int64 = 0
        do {
            guard manifest.items.count <= maximumItems else { throw BackupError.invalid("Kho quá nhiều mục cho backup v1.") }
            try checkCapacity(at: parent, needed: manifest.items.flatMap(\.attachments).reduce(0) { $0 + $1.size })
            for i in output.items.indices {
                for j in output.items[i].attachments.indices {
                    let attachment = output.items[i].attachments[j]
                    guard let source = originals[attachment.id] else { throw BackupError.invalid("Thiếu ảnh gốc khi export.") }
                    let properties = try source.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey, .isRegularFileKey])
                    guard properties.isSymbolicLink != true, properties.isRegularFile == true,
                          Int64(properties.fileSize ?? -1) == attachment.size else { throw BackupError.invalid("Ảnh gốc đã thay đổi.") }
                    total += attachment.size
                    guard total <= maximumBytes, try ShareGateStore.checksum(source) == attachment.checksum else { throw BackupError.invalid("Checksum ảnh gốc không khớp hoặc kho quá lớn.") }
                    let path = "originals/" + attachment.id.uuidString + ".data"
                    try fm.copyItem(at: source, to: temporary.appendingPathComponent(path))
                    output.items[i].attachments[j].path = path
                }
            }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(output).write(to: temporary.appendingPathComponent("manifest.json"), options: .atomic)
            _ = try readValidatedPackage(temporary)
            try fm.moveItem(at: temporary, to: ready)
            return ready
        } catch { try? fm.removeItem(at: temporary); throw error }
    }

    nonisolated static func readValidatedPackage(_ package: URL) throws -> BackupManifest {
        let fm = FileManager.default
        let values = try package.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw BackupError.invalid("Hãy chọn package .notedbackup.") }
        let manifestURL = try checkedFile("manifest.json", in: package)
        guard (try manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 16 * 1024 * 1024 else { throw BackupError.invalid("Manifest quá lớn.") }
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.version == 1, manifest.items.count <= maximumItems, manifest.collections.count <= maximumItems else { throw BackupError.invalid("Phiên bản hoặc số mục không được hỗ trợ.") }
        guard Set(manifest.items.map(\.id)).count == manifest.items.count,
              Set(manifest.items.map(\.captureID)).count == manifest.items.count,
              Set(manifest.collections.map(\.id)).count == manifest.collections.count else { throw BackupError.invalid("ID bị trùng.") }
        let collectionIDs = Set(manifest.collections.map(\.id))
        var attachmentIDs = Set<UUID>(); var paths = Set<String>(); var total: Int64 = 0
        for collection in manifest.collections { guard !collection.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BackupError.invalid("Collection không có tên.") } }
        for item in manifest.items {
            guard ["text", "link", "image"].contains(item.kind), !item.captureID.isEmpty,
                  item.collectionID == nil || collectionIDs.contains(item.collectionID!),
                  item.kind != "image" || !item.attachments.isEmpty,
                  item.kind == "image" || item.attachments.isEmpty,
                  item.createdAt.timeIntervalSince1970.isFinite, item.updatedAt.timeIntervalSince1970.isFinite else { throw BackupError.invalid("Metadata mục không hợp lệ.") }
            if item.kind == "link" {
                guard let url = URL(string: item.originalURL), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw BackupError.invalid("URL không hợp lệ.") }
            }
            for attachment in item.attachments {
                guard attachmentIDs.insert(attachment.id).inserted, paths.insert(attachment.path).inserted,
                      attachment.path.hasPrefix("originals/"), attachment.size > 0,
                      attachment.size <= Int64(ShareGateStore.maximumFileBytes),
                      UTType(attachment.typeIdentifier)?.conforms(to: .image) == true,
                      attachment.checksum.count == 64 else { throw BackupError.invalid("Attachment không hợp lệ.") }
                let file = try checkedFile(attachment.path, in: package)
                guard Int64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1) == attachment.size,
                      try ShareGateStore.checksum(file) == attachment.checksum else { throw BackupError.invalid("Ảnh thiếu hoặc checksum sai.") }
                total += attachment.size
                guard total <= maximumBytes, attachmentIDs.count <= maximumItems * 3 else { throw BackupError.invalid("Backup quá lớn.") }
            }
        }
        if let enumerator = fm.enumerator(at: package, includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) {
            var count = 0
            for case let url as URL in enumerator {
                count += 1
                guard count <= maximumItems * 5, try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw BackupError.invalid("Package có symlink hoặc quá nhiều file.") }
            }
        }
        return manifest
    }

    nonisolated private static func checkedFile(_ relative: String, in root: URL) throws -> URL {
        guard AttachmentStore.isSafe(relativePath: relative) else { throw BackupError.invalid("Đường dẫn file không an toàn.") }
        var file = root
        for component in relative.split(separator: "/") {
            file.appendPathComponent(String(component))
            guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw BackupError.invalid("Không chấp nhận symlink.") }
        }
        guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { throw BackupError.invalid("File không tồn tại.") }
        return file
    }

    nonisolated private static func prepareOriginals(_ manifest: BackupManifest, package: URL, libraryRoot: URL) throws -> [UUID: String] {
        let fm = FileManager.default
        var result: [UUID: String] = [:]
        let directory = libraryRoot.appendingPathComponent("originals/backup", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var required: Int64 = 0
        var neededHashes = Set<String>()
        for attachment in manifest.items.flatMap(\.attachments) {
            let destination = directory.appendingPathComponent(attachment.checksum + ".data")
            if !fm.fileExists(atPath: destination.path), neededHashes.insert(attachment.checksum).inserted {
                required += attachment.size
            }
        }
        try checkCapacity(at: libraryRoot, needed: required)
        for attachment in manifest.items.flatMap(\.attachments) {
            let relative = "originals/backup/" + attachment.checksum + ".data"
            let destination = libraryRoot.appendingPathComponent(relative)
            if fm.fileExists(atPath: destination.path) {
                let values = try destination.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
                guard values.isSymbolicLink != true, values.isRegularFile == true,
                      try ShareGateStore.checksum(destination) == attachment.checksum else { throw BackupError.invalid("File đích xung đột; không ghi đè.") }
            } else {
                let partial = directory.appendingPathComponent(UUID().uuidString + ".partial")
                try fm.copyItem(at: checkedFile(attachment.path, in: package), to: partial)
                guard try ShareGateStore.checksum(partial) == attachment.checksum else { throw BackupError.invalid("File nguồn thay đổi trong lúc nhập.") }
                try fm.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: partial.path)
                try fm.moveItem(at: partial, to: destination)
            }
            result[attachment.id] = relative
        }
        return result
    }

    nonisolated private static func checkCapacity(at url: URL, needed: Int64) throws {
        guard needed >= 0, needed <= maximumBytes else { throw BackupError.invalid("Dung lượng backup vượt giới hạn.") }
        if let capacity = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
           capacity < needed + 16 * 1024 * 1024 {
            throw BackupError.invalid("Không đủ dung lượng trống để tạo bản sao an toàn.")
        }
    }
}
