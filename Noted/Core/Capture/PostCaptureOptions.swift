import Foundation

/// Title, tags, collection and pin chosen in Lưu nhanh. They are stored durably, keyed by the
/// capture payload id, before the payload is published, and applied when that batch is imported.
/// Matching by payload id (item.captureID == "<payload>.<entry>") replaces guessing the new
/// items from a before/after diff, which failed when another import ran or added other batches.
struct PostCaptureOptions: Codable, Equatable {
    var title = ""
    var tags: [String] = []
    var collectionID: UUID?
    var pin = false

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && tags.isEmpty && collectionID == nil && !pin
    }

    /// Photo captures have no title field, so a title left over from note mode is ignored.
    init(title: String = "", tags: [String] = [], collectionID: UUID? = nil, pin: Bool = false, mode: String = "note") {
        self.title = mode == "photo" ? "" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = tags
        self.collectionID = collectionID
        self.pin = pin
    }

    @MainActor
    func apply(to items: [Item], store: LibraryStore) throws {
        for item in items {
            if !title.isEmpty || !tags.isEmpty || collectionID != nil {
                // An empty title keeps the captured/derived title so link metadata may still fill it.
                try store.update(item, title: title.isEmpty ? item.title : title, body: item.body, tags: tags,
                                 collectionID: collectionID, markTitleEdited: !title.isEmpty)
            }
            if pin && !item.pinned { try store.togglePin(item) }
        }
    }
}

/// Durable payload-id → options map in the library root (a small JSON file, written atomically).
struct PostCaptureOptionsStore {
    let url: URL

    func all() -> [UUID: PostCaptureOptions] {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([String: PostCaptureOptions].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
    }

    func save(_ options: PostCaptureOptions, for id: UUID) throws {
        var current = all()
        current[id] = options
        try write(current)
    }

    func remove(_ id: UUID) throws {
        var current = all()
        guard current.removeValue(forKey: id) != nil else { return }
        try write(current)
    }

    private func write(_ values: [UUID: PostCaptureOptions]) throws {
        let encoded = Dictionary(uniqueKeysWithValues: values.map { ($0.key.uuidString, $0.value) })
        try JSONEncoder().encode(encoded).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
