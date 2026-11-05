#if DEBUG
import Foundation
import UIKit
import SwiftData

/// Explicit UI-test opt-in. Both metadata and queue are outside the personal library/App Group.
@MainActor
enum PhaseFourFixtures {
    private static var openedStoreID: ObjectIdentifier?
    private enum FixtureError: LocalizedError {
        case save
        var errorDescription: String? { "Lỗi lưu chủ động trong thư viện kiểm chứng." }
    }

    private nonisolated static func requestedRoot() throws -> URL? {
        guard let run = ProcessInfo.processInfo.environment["NOTED_PHASE4_RUN"] else { return nil }
        guard let id = UUID(uuidString: run) else { throw CocoaError(.fileReadInvalidFileName) }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotedPhaseFour", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    nonisolated static var draftDirectory: URL? {
        (try? requestedRoot())?.appendingPathComponent("drafts", isDirectory: true)
    }

    static func isVerificationStore(_ store: LibraryStore) -> Bool {
        openedStoreID == ObjectIdentifier(store)
    }

    static func openIfRequested() throws -> LibraryStore? {
        guard let root = try requestedRoot() else { return nil }
        let store = try LibraryStore(root: root.appendingPathComponent("library"),
                                     queue: ShareGateStore(root: root.appendingPathComponent("queue")))
        openedStoreID = ObjectIdentifier(store)
        let marker = root.appendingPathComponent("seeded")
        guard !FileManager.default.fileExists(atPath: marker.path) else { return store }
        if ProcessInfo.processInfo.environment["NOTED_PHASE4_EMPTY"] != "1" {
            try seed(store)
        }
        if ProcessInfo.processInfo.environment["NOTED_PHASE4_PENDING"] == "1" {
            _ = try store.queue.begin(id: UUID())
        }
        try Data().write(to: marker, options: .atomic)
        return store
    }

    private static func seed(_ store: LibraryStore) throws {
        let date = Date()
        let collection = ItemCollection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, name: "P4 collection")
        store.context.insert(collection)
        for index in 0..<54 {
            let item = Item(id: index == 0 ? UUID(uuidString: "00000000-0000-0000-0000-000000000001")! : UUID(),
                            captureID: "fixture-note-\(index)", kind: "text", title: String(format: "P4 note %02d", index),
                            body: "Nội dung kiểm chứng \(index)", createdAt: date.addingTimeInterval(Double(-index)))
            store.context.insert(item)
        }
        let link = Item(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, captureID: "fixture-link",
                        kind: "link", title: "P4 link", originalURL: "https://example.com/", createdAt: date.addingTimeInterval(1))
        link.previewStatus = "complete"
        store.context.insert(link)
        let png = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800)).pngData { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
            ("P4 ORIGINAL" as NSString).draw(at: CGPoint(x: 80, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 60), .foregroundColor: UIColor.white])
        }
        for (suffix, title, data) in [("2", "P4 image", png), ("3", "P4 broken", Data([0, 1, 2]))] {
            let id = UUID(uuidString: "00000000-0000-0000-0000-00000000000" + suffix)!
            let relative = "originals/" + id.uuidString + ".png"
            let url = store.root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            let attachment = Attachment(relativePath: relative, size: Int64(data.count), checksum: try ShareGateStore.checksum(url), typeIdentifier: "public.png")
            let item = Item(id: id, captureID: "fixture-image-" + suffix, kind: "image", title: title,
                            body: "Ghi chú ảnh", createdAt: date.addingTimeInterval(Double(Int(suffix)!)), attachments: [attachment])
            item.ocrStatus = "complete"
            store.context.insert(item)
        }
        try store.saveChanges()
    }

    static func linkDigestRunner(in store: LibraryStore) throws -> LinkDigestRunner {
        let intelligence = try IntelligenceStore(root: store.root.appendingPathComponent("Intelligence"))
        let blockedID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        if !store.items.contains(where: { $0.id == blockedID }) {
            let item = Item(id: blockedID, captureID: "fixture-login-wall", kind: "link",
                            title: "P4 login wall", originalURL: "https://example.com/login",
                            createdAt: Date().addingTimeInterval(10))
            item.previewStatus = "complete"
            store.context.insert(item)
            try store.saveChanges()
        }
        for item in store.items where item.kind == "link" {
            if try intelligence.linkDigest(for: item.id) != nil { continue }
            let digest = LinkDigest(itemID: item.id,
                fingerprint: LinkDigest.fingerprint(originalURL: item.originalURL, engineVersion: ExtractiveLinkDigester.engineVersion),
                engineVersion: ExtractiveLinkDigester.engineVersion)
            digest.apply(LinkDigestContent(title: "Chăm sóc cây trong nhà", siteName: "Vườn mẫu", author: "An",
                summary: "Tưới cây vừa đủ và đặt cây gần cửa sổ có ánh sáng dịu.",
                textForEmbedding: "Chăm sóc cây trong nhà", status: .complete), now: Date())
            if item.id == blockedID { digest.apply(LinkDigestContent(status: .loginWall), now: Date()) }
            intelligence.context.insert(digest)
        }
        try intelligence.saveChanges()
        if ProcessInfo.processInfo.arguments.contains("--link-digest-labeling-fixture") {
            let labels = Dictionary(uniqueKeysWithValues: store.items.sorted { $0.id.uuidString < $1.id.uuidString }.prefix(3).map { item in
                (item.id, IntelligenceLabel(itemID: item.id, topic: "Không rõ", desiredTags: [],
                    split: IntelligenceLabelStorage.split(for: item.id), labeledAt: Date()))
            })
            try IntelligenceLabelStorage.save(labels, to: IntelligenceLabelStorage.fileURL(for: store.root))
        }
        return LinkDigestRunner(intelligence: intelligence, loader: { _ in
            LinkDigestFetch(content: LinkDigestContent(status: .loginWall), rawTitle: "")
        })
    }

    static func failNextSave(in store: LibraryStore) {
        guard isVerificationStore(store) else { return }
        store.libraryFaultInjector = { [weak store] point in
            guard point == .beforeSave else { return }
            store?.libraryFaultInjector = nil
            throw FixtureError.save
        }
    }

    static func stageIncoming(in store: LibraryStore) throws {
        guard isVerificationStore(store) else { return }
        let payload = try ShareGateStore.textOnlyPayload("P4 incoming")
        let directory = try store.queue.begin(id: payload.id)
        try store.queue.publish(payload, directory: directory)
    }
}
#endif
