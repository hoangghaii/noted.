import Foundation
import SwiftData

enum IntelligenceSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [LinkDigest.self] }
}

/// Derived AI data (`intelligence.store`), separate from `library.store`.
/// Everything here can be rebuilt, so an unreadable or unknown-version store is set aside
/// (`intelligence.store.corrupt*`) and replaced by an empty one; `library.store` is never touched.
/// Later plans add entities here and bump `schemaVersion` with a tested migration.
@MainActor
final class IntelligenceStore {
    static let schemaVersion = 1
    static let fileName = "intelligence.store"

    let root: URL
    let container: ModelContainer
    let context: ModelContext
    /// True when the previous store was unreadable and has been replaced.
    private(set) var recoveredFromCorruption = false

    init(root: URL) throws {
        self.root = root
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let versionFile = root.appendingPathComponent("schema-version.txt")
        if fm.fileExists(atPath: versionFile.path) {
            let version = (try? String(contentsOf: versionFile, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if version != String(Self.schemaVersion) {
                try Self.setAside(root: root)
                recoveredFromCorruption = true
            }
        }
        do {
            container = try Self.makeContainer(root: root)
        } catch {
            try Self.setAside(root: root)
            recoveredFromCorruption = true
            container = try Self.makeContainer(root: root)
        }
        if !fm.fileExists(atPath: versionFile.path) {
            try String(Self.schemaVersion).write(to: versionFile, atomically: true, encoding: .utf8)
        }
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func saveChanges() throws {
        do { try context.save() } catch {
            context.rollback()
            throw error
        }
    }

    func linkDigests() throws -> [LinkDigest] {
        try context.fetch(FetchDescriptor<LinkDigest>())
    }

    func linkDigest(for itemID: UUID) throws -> LinkDigest? {
        var descriptor = FetchDescriptor<LinkDigest>(predicate: #Predicate { $0.itemID == itemID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func makeContainer(root: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: IntelligenceSchemaV1.self)
        let config = ModelConfiguration("NotedIntelligence", schema: schema,
                                        url: root.appendingPathComponent(fileName), cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Keeps only the most recent unreadable copy for diagnosis; the data is derived.
    private static func setAside(root: URL) throws {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let file = root.appendingPathComponent(fileName + suffix)
            let aside = root.appendingPathComponent(fileName + ".corrupt" + suffix)
            if fm.fileExists(atPath: aside.path) { try fm.removeItem(at: aside) }
            if fm.fileExists(atPath: file.path) { try fm.moveItem(at: file, to: aside) }
        }
        let versionFile = root.appendingPathComponent("schema-version.txt")
        if fm.fileExists(atPath: versionFile.path) { try fm.removeItem(at: versionFile) }
    }
}
