import Foundation
import SwiftData
import Observation

enum LibraryFaultPoint { case beforeSave, afterDeletionCommit, beforeOriginalCleanup }

@MainActor @Observable
final class LibraryStore {
    let container: ModelContainer
    let context: ModelContext
    let root: URL
    let queue: ShareGateStore
    private(set) var items: [Item] = []
    private(set) var collections: [ItemCollection] = []
    var lastError: String?
    private(set) var pendingIssues: [CaptureIssue] = []
    var pendingMessages: [String] { pendingIssues.map(\.message) }
    private(set) var isImporting = false
    /// UI/backup can use this single writer's lock for a consistent synchronous snapshot.
    var isDataOperationInProgress = false
    @ObservationIgnored var faultInjector: ((CaptureFaultPoint) throws -> Void)?
    @ObservationIgnored var libraryFaultInjector: ((LibraryFaultPoint) throws -> Void)?

    init(root: URL? = nil, queue: ShareGateStore? = nil) throws {
        let selectedRoot: URL
        if let root { selectedRoot = root }
        else {
            selectedRoot = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
                .appendingPathComponent("NotedLibrary", isDirectory: true)
        }
        self.root = selectedRoot
        self.queue = try queue ?? ShareGateStore.configured()
        container = try ModelStore.open(root: selectedRoot)
        context = ModelContext(container)
        context.autosaveEnabled = false
        try refresh()
        try finishDeletionJournal()
    }

    func refresh() throws {
        items = try context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        collections = try context.fetch(FetchDescriptor<ItemCollection>(sortBy: [SortDescriptor(\.name)]))
    }

    func saveChanges() throws {
        do {
            try injectLibrary(.beforeSave)
            try context.save()
            try refresh()
            lastError = nil
        } catch {
            context.rollback()
            try? refresh()
            lastError = error.localizedDescription
            throw error
        }
    }

    func importPending() async throws {
        guard !isImporting, !isDataOperationInProgress else { return }
        isImporting = true
        defer { isImporting = false }
        pendingIssues = []
        let queue = self.queue
        let root = self.root
        do {
            let directories = try queue.readyDirectories()
            for directory in directories {
                guard let batchID = UUID(uuidString: directory.deletingPathExtension().lastPathComponent) else { continue }
                do {
                    let prior = try context.fetch(FetchDescriptor<ProcessedBatch>()).contains { $0.id == batchID }
                    if !prior {
                        let captures = try await Task.detached(priority: .userInitiated) {
                            try CaptureImporter.prepare(directory: directory, queue: queue, libraryRoot: root)
                        }.value
                        try inject(.afterFilesPrepared)
                        // Complete collision validation before inserting any model: SwiftData
                        // unique attributes otherwise upsert and overwrite restored/edited items.
                        let newCaptures = try preflightCaptures(captures)
                        for capture in newCaptures {
                            let attachments: [Attachment] = capture.attachment.map { prepared in
                                [Attachment(id: prepared.id, relativePath: prepared.relativePath, size: prepared.size,
                                            checksum: prepared.checksum, typeIdentifier: prepared.typeIdentifier)]
                            } ?? []
                            let item = Item(id: capture.id, captureID: capture.captureID, kind: capture.kind,
                                            title: capture.title, body: capture.body, originalURL: capture.originalURL,
                                            createdAt: capture.createdAt, attachments: attachments)
                            context.insert(item)
                        }
                        context.insert(ProcessedBatch(id: batchID))
                        try inject(.beforeMetadataSave)
                        try context.save()
                        try inject(.afterMetadataSave)
                    }
                    try validateCommittedOriginals(batchID: batchID)
                    try inject(.beforeSourceCleanup)
                    // Copies are verified before the metadata commit. Receipt makes cleanup retry safe.
                    try queue.removeCommittedBatch(batchID)
                } catch {
                    context.rollback()
                    pendingIssues.append(CaptureIssue(id: batchID,
                        message: "Một lượt lưu cần thử lại: " + error.localizedDescription, isPartial: false))
                }
            }
            for directory in try queue.partialDirectories() {
                guard let id = UUID(uuidString: directory.deletingPathExtension().lastPathComponent) else { continue }
                pendingIssues.append(CaptureIssue(id: id, message: "Lượt lưu bị gián đoạn, chưa có đủ nội dung. Hãy chia sẻ lại từ nguồn hoặc bỏ lượt này.", isPartial: true))
            }
            try refresh()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func captureText(_ text: String) async throws {
        guard !isDataOperationInProgress else { throw LibraryError.operationInProgress }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LibraryError.emptyContent }
        let payload = try ShareGateStore.textOnlyPayload(text)
        try publish(payload)
        await capturePublished()
    }

    func captureLink(_ url: URL, caption: String = "") async throws {
        guard !isDataOperationInProgress else { throw LibraryError.operationInProgress }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw LibraryError.invalidLink }
        var payload = ShareGatePayload()
        payload.caption = caption
        payload.entries = [.init(kind: .link, value: url.absoluteString)]
        try publish(payload)
        await capturePublished()
    }

    func captureImageFiles(_ urls: [URL], caption: String = "") async throws {
        guard !isDataOperationInProgress else { throw LibraryError.operationInProgress }
        guard !urls.isEmpty, urls.count <= ShareGateStore.maximumEntries else { throw ShareGateError.tooLarge }
        let queue = self.queue
        try await Task.detached(priority: .userInitiated) {
            var payload = ShareGatePayload()
            payload.caption = caption
            let directory = try queue.begin(id: payload.id)
            do {
                for url in urls {
                    let name = try ShareGateStore.copyImage(from: url, to: directory, extension: url.pathExtension)
                    payload.entries.append(.init(kind: .image, value: name))
                }
                try queue.publish(payload, directory: directory)
            } catch {
                // Keep incomplete captures visible for explicit recovery/discard.
                throw error
            }
        }.value
        await capturePublished()
    }

    private func publish(_ payload: ShareGatePayload) throws {
        let directory = try queue.begin(id: payload.id)
        try queue.publish(payload, directory: directory)
    }

    private func capturePublished() async {
        // Capture is already durable. An import failure must not invite a duplicate re-save.
        do { try await importPending() } catch { lastError = error.localizedDescription }
    }

    func update(_ item: Item, title: String, body: String, tags: [String], collectionID: UUID?) throws {
        try guardMutation()
        item.title = title
        item.body = body
        item.tags = Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        item.collectionID = collections.contains { $0.id == collectionID } ? collectionID : nil
        item.updatedAt = Date()
        item.userEditedTitle = true
        item.rebuildSearchDocument()
        try saveChanges()
    }

    func togglePin(_ item: Item) throws { try guardMutation(); item.pinned.toggle(); item.updatedAt = Date(); try saveChanges() }
    func trash(_ item: Item) throws { try guardMutation(); item.trashedAt = Date(); item.updatedAt = Date(); try saveChanges() }
    func restore(_ item: Item) throws {
        try guardMutation()
        item.trashedAt = nil
        if !collections.contains(where: { $0.id == item.collectionID }) { item.collectionID = nil }
        item.updatedAt = Date()
        try saveChanges()
    }

    func createCollection(_ name: String) throws {
        try guardMutation()
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LibraryError.invalidName }
        context.insert(ItemCollection(name: clean))
        try saveChanges()
    }

    func renameCollection(_ collection: ItemCollection, name: String) throws {
        try guardMutation()
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LibraryError.invalidName }
        collection.name = clean
        try saveChanges()
    }

    func deleteCollection(_ collection: ItemCollection) throws {
        try guardMutation()
        for item in items where item.collectionID == collection.id { item.collectionID = nil }
        context.delete(collection)
        try saveChanges()
    }

    func permanentlyDelete(_ item: Item) throws {
        try guardMutation()
        guard item.trashedAt != nil else { return }
        try finishDeletionJournal()
        let paths = item.attachments.map(\.relativePath)
        try JSONEncoder().encode(paths).write(to: deletionJournalURL, options: .atomic)
        context.delete(item)
        // Keep the journal even if refresh fails after a successful commit.
        // Replay checks live references, so a rolled-back deletion is safe too.
        try saveChanges()
        try injectLibrary(.afterDeletionCommit)
        try finishDeletionJournal()
    }

    func attachmentURL(_ attachment: Attachment) -> URL {
        AttachmentStore(root: root).originalURL(relativePath: attachment.relativePath)
    }

    func discardPending(id: UUID) throws {
        try guardMutation()
        try queue.discard(id: id)
        pendingIssues.removeAll { $0.id == id }
    }

    private func guardMutation() throws {
        if isDataOperationInProgress { throw LibraryError.operationInProgress }
    }

    private var deletionJournalURL: URL { root.appendingPathComponent("deletion-journal.json") }

    private func finishDeletionJournal() throws {
        guard FileManager.default.fileExists(atPath: deletionJournalURL.path) else { return }
        let paths = try JSONDecoder().decode([String].self, from: Data(contentsOf: deletionJournalURL))
        let livePaths = Set(items.flatMap(\.attachments).map(\.relativePath))
        for path in paths where !livePaths.contains(path) {
            guard AttachmentStore.isSafe(relativePath: path) else { throw LibraryError.invalidAttachment }
            try injectLibrary(.beforeOriginalCleanup)
            let url = root.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
        try FileManager.default.removeItem(at: deletionJournalURL)
    }

    private func inject(_ point: CaptureFaultPoint) throws {
        #if DEBUG
        try faultInjector?(point)
        #endif
    }

    private func injectLibrary(_ point: LibraryFaultPoint) throws {
        #if DEBUG
        try libraryFaultInjector?(point)
        #endif
    }
}
