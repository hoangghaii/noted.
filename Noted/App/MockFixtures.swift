#if DEBUG
import Foundation
import SwiftData

/// Explicit visual-test opt-in. Library, incoming queue and drafts never use personal paths.
@MainActor
enum MockFixtures {
    enum Variant: String { case library, collections, capture }

    nonisolated static var requestedVariant: Variant? {
        ProcessInfo.processInfo.environment["NOTED_MOCK_FIXTURE"].flatMap(Variant.init(rawValue:))
    }

    private nonisolated static func requestedRoot() throws -> URL? {
        let environment = ProcessInfo.processInfo.environment
        guard let value = environment["NOTED_MOCK_FIXTURE"] else { return nil }
        guard let variant = Variant(rawValue: value) else { throw CocoaError(.fileReadInvalidFileName) }
        let run = environment["NOTED_MOCK_RUN"] ?? "00000000-0000-0000-0000-000000000001"
        guard let id = UUID(uuidString: run) else { throw CocoaError(.fileReadInvalidFileName) }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotedMockFixtures", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
            .appendingPathComponent(variant.rawValue, isDirectory: true)
    }

    nonisolated static var draftDirectory: URL? {
        (try? requestedRoot())?.appendingPathComponent("drafts", isDirectory: true)
    }

    // Phase 07 uses these values when the corresponding capture fields are introduced.
    nonisolated static let captureTitle = "Ý tưởng cuối tuần"
    nonisolated static let captureBody = "• Đi Đà Lạt\n• Chụp ảnh phim\n• Tìm quán cà phê mới"
    nonisolated static let captureCollectionID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    nonisolated static let captureTags = ["cảm hứng"]

    static func openIfRequested() throws -> LibraryStore? {
        guard let root = try requestedRoot(), let variant = requestedVariant else { return nil }
        let store = try LibraryStore(root: root.appendingPathComponent("library"),
                                     queue: ShareGateStore(root: root.appendingPathComponent("queue")))
        let marker = root.appendingPathComponent("seeded-v1")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return store }
        if variant == .collections { try seedCollections(store) }
        else { try seedLibrary(store) }
        if variant == .capture {
            try NoteDraftStore.save(NoteDraft(mode: "note", body: captureBody, url: "", title: captureTitle, collectionID: captureCollectionID, tags: captureTags))
        }
        try Data().write(to: marker, options: .atomic)
        return store
    }

    private static func date(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2024, month: 4, day: day, hour: 12))!
    }

    private static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
    }

    private static func seedLibrary(_ store: LibraryStore) throws {
        store.context.insert(ItemCollection(id: captureCollectionID, name: "Góc riêng"))
        let note = Item(id: id(1), captureID: "mock-note", kind: "text", title: "Một góc yên tĩnh",
                        body: "Những buổi sáng chậm rãi, một tách cà phê nóng và vài dòng suy nghĩ. Đôi khi, chỉ vậy là đủ để lòng nhẹ hơn.", createdAt: date(12))
        let idea = Item(id: id(37), captureID: "mock-idea", kind: "text", title: captureTitle,
                        body: captureBody, createdAt: date(10))
        idea.tags = captureTags
        idea.collectionID = captureCollectionID
        idea.rebuildSearchDocument()
        let link = Item(id: id(4), captureID: "mock-link", kind: "link", title: "Sống chậm một chút",
                        body: "Một bài viết hay về cách tận hưởng những điều nhỏ bé trong cuộc sống.", originalURL: "https://vietcetera.com/", createdAt: date(5))
        link.previewStatus = "complete"
        guard let coffee = Bundle.main.url(forResource: "mock-coffee", withExtension: "jpg") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let relative = "originals/mock-coffee.jpg"
        let destination = store.root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.copyItem(at: coffee, to: destination)
        let data = try Data(contentsOf: destination)
        let attachment = Attachment(id: id(201), relativePath: relative, size: Int64(data.count),
                                    checksum: try ShareGateStore.checksum(destination), typeIdentifier: "public.jpeg")
        let photo = Item(id: id(3), captureID: "mock-photo", kind: "image", title: "Buổi sáng ở Đà Lạt",
                         createdAt: date(8), attachments: [attachment])
        photo.ocrStatus = "complete"
        for item in [note, idea, photo, link] { store.context.insert(item) }
        for index in 5...12 {
            store.context.insert(Item(id: id(index), captureID: "mock-extra-\(index)", kind: "text",
                                      title: "Điều muốn giữ \(index)", createdAt: date(1).addingTimeInterval(Double(-index))))
        }
        try store.saveChanges()
    }

    private static func seedCollections(_ store: LibraryStore) throws {
        for (index, entry) in [("Cảm hứng", 24), ("Đọc sau", 18), ("Góc riêng", 12), ("Chuyến đi", 15)].enumerated() {
            let collection = ItemCollection(id: id(101 + index), name: entry.0)
            store.context.insert(collection)
            for offset in 0..<entry.1 {
                let number = 1000 + index * 100 + offset
                let item = Item(id: id(number), captureID: "mock-collection-\(number)", kind: "text",
                                title: "\(entry.0) \(offset + 1)", createdAt: date(1).addingTimeInterval(Double(-number)))
                item.collectionID = collection.id
                store.context.insert(item)
            }
        }
        try store.saveChanges()
    }
}
#endif
