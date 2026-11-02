import Foundation

struct NoteDraft: Codable {
    var mode = "note"
    var body = ""
    var url = ""
}

enum NoteDraftStore {
    private static var path: URL {
        #if DEBUG
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
