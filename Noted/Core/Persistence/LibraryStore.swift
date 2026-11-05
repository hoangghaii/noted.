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
            applyPendingPostCaptureOptions()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Returns the payload id; `options` are stored before publishing and applied when the batch imports.
    @discardableResult
    func captureText(_ text: String, options: PostCaptureOptions? = nil) async throws -> UUID {
        guard !isDataOperationInProgress else { throw LibraryError.operationInProgress }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LibraryError.emptyContent }
        let payload = try ShareGateStore.textOnlyPayload(text)
        try registerPostCaptureOptions(options, for: payload.id) { try publish(payload) }
        await capturePublished()
        return payload.id
    }

    @discardableResult
    func captureLink(_ url: URL, caption: String = "", options: PostCaptureOptions? = nil) async throws -> UUID {
        guard !isDataOperationInProgress else { throw LibraryError.operationInProgress }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { throw LibraryError.invalidLink }
        var payload = ShareGatePayload()
        payload.caption = caption
        payload.entries = [.init(kind: .link, value: url.absoluteString)]
        try registerPostCaptureOptions(options, for: payload.id) { try publish(payload) }
        await capturePublished()
        return payload.id
    }

    @discardableResult
    func captureImageFiles(_ urls: [URL], caption: String = "", options: PostCaptureOptions? = nil) async throws -> UUID {
        guard !isDataOperationInProgress else { throw LibraryError.operationInProgress }
        guard !urls.isEmpty, urls.count <= ShareGateStore.maximumEntries else { throw ShareGateError.tooLarge }
        let queue = self.queue
        let payloadID = UUID()
        // Registered before any file exists in the queue; a failed copy leaves a partial batch and
        // the sweep drops the options once that batch is discarded.
        if let options, !options.isEmpty { try postCaptureOptions.save(options, for: payloadID) }
        try await Task.detached(priority: .userInitiated) {
            var payload = ShareGatePayload()
            payload.id = payloadID
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
        return payloadID
    }

    /// True once every entry of this capture is in the library and its options (if any) are applied.
    func isCaptureSettled(_ payloadID: UUID) -> Bool {
        items.contains { $0.captureID.hasPrefix(payloadID.uuidString + ".") } && postCaptureOptions.all()[payloadID] == nil
    }

    private var postCaptureOptions: PostCaptureOptionsStore {
        PostCaptureOptionsStore(url: root.appendingPathComponent("pending-capture-options.json"))
    }

    private func registerPostCaptureOptions(_ options: PostCaptureOptions?, for id: UUID, publish: () throws -> Void) throws {
        guard let options, !options.isEmpty else { return try publish() }
        try postCaptureOptions.save(options, for: id)
        do { try publish() } catch { try? postCaptureOptions.remove(id); throw error }
    }

    /// Applies stored options to items whose captureID belongs to the payload. Runs after every import,
    /// so options survive an import that was skipped (another one running) or an app relaunch.
    private func applyPendingPostCaptureOptions() {
        let pending = postCaptureOptions.all()
        guard !pending.isEmpty else { return }
        let directories = ((try? queue.readyDirectories()) ?? []) + ((try? queue.partialDirectories()) ?? [])
        let queued = Set(directories.map { $0.deletingPathExtension().lastPathComponent })
        for (id, options) in pending {
            let prefix = id.uuidString + "."
            let matched = items.filter { $0.captureID.hasPrefix(prefix) }
            if matched.isEmpty {
                // Still queued: wait. Otherwise the batch was discarded and the options have no target.
                if !queued.contains(id.uuidString) { try? postCaptureOptions.remove(id) }
                continue
            }
            do {
                try options.apply(to: matched, store: self)
                try postCaptureOptions.remove(id)
            } catch {
                lastError = "Nội dung đã lưu, nhưng chưa áp dụng được tiêu đề, thẻ, bộ sưu tập hoặc ghim: " + error.localizedDescription
            }
        }
    }

    private func publish(_ payload: ShareGatePayload) throws {
        let directory = try queue.begin(id: payload.id)
        try queue.publish(payload, directory: directory)
    }

    private func capturePublished() async {
        // Capture is already durable. An import failure must not invite a duplicate re-save.
        do { try await importPending() } catch { lastError = error.localizedDescription }
    }

    func update(_ item: Item, title: String, body: String, tags: [String], collectionID: UUID?, markTitleEdited: Bool = true) throws {
        try guardMutation()
        item.title = title
        item.body = body
        item.tags = Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        item.collectionID = collections.contains { $0.id == collectionID } ? collectionID : nil
        item.updatedAt = Date()
        if markTitleEdited { item.userEditedTitle = true }
        item.rebuildSearchDocument()
        try saveChanges()
    }

    /// Writes a derived title (e.g. from a link digest). Never marks it user-edited and leaves `updatedAt`
    /// alone, so it neither looks like an edit to `EnrichmentRunner` nor blocks later generated titles.
    func applyGeneratedTitle(_ title: String, to item: Item) throws {
        try guardMutation()
        guard !item.userEditedTitle else { return }
        item.title = title
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
