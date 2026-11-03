import Foundation

struct NoteDraft: Codable {
    var mode = "note"
    var body = ""
    var url = ""
    var title = ""
    var collectionID: UUID?
    var tags: [String] = []

    init(mode: String = "note", body: String = "", url: String = "", title: String = "",
         collectionID: UUID? = nil, tags: [String] = []) {
        self.mode = mode; self.body = body; self.url = url; self.title = title
        self.collectionID = collectionID; self.tags = tags
    }

    private enum CodingKeys: String, CodingKey { case mode, body, url, title, collectionID, tags }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decodeIfPresent(String.self, forKey: .mode) ?? "note"
        body = try values.decodeIfPresent(String.self, forKey: .body) ?? ""
        url = try values.decodeIfPresent(String.self, forKey: .url) ?? ""
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        collectionID = try values.decodeIfPresent(UUID.self, forKey: .collectionID)
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

enum NoteDraftStore {
    private static var path: URL {
        #if DEBUG
        if let directory = MockFixtures.draftDirectory { return directory.appendingPathComponent("capture.json") }
        if let directory = PhaseFourFixtures.draftDirectory { return directory.appendingPathComponent("capture.json") }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotedDraft", isDirectory: true).appendingPathComponent("capture.json")
    }

    static func read() -> NoteDraft {
        guard let data = try? Data(contentsOf: path), let draft = try? JSONDecoder().decode(NoteDraft.self, from: data) else { return NoteDraft() }
        return draft
    }

    static func save(_ draft: NoteDraft) throws {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: path, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func clear() throws {
        if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
    }
}
