import Foundation
import Observation

@MainActor @Observable
final class EnrichmentRunner {
    @ObservationIgnored private let previewLoader: @Sendable (URL) async throws -> String
    private(set) var running = false
    private(set) var supportedOCRLanguages: [String] = []
    var lastError: String?

    init(previewLoader: @escaping @Sendable (URL) async throws -> String = { try await LinkMetadataService.title(for: $0) }) {
        self.previewLoader = previewLoader
    }

    func recoverInterrupted(in store: LibraryStore) throws {
        for item in store.items {
            if item.ocrStatus == "running" { item.ocrStatus = "pending" }
            if item.previewStatus == "running" { item.previewStatus = "pending" }
        }
        try store.saveChanges()
    }

    func run(in store: LibraryStore) async {
        guard !running, !store.isDataOperationInProgress else { return }
        running = true
        defer { running = false }
        while !Task.isCancelled, !store.isDataOperationInProgress,
              let item = store.items.first(where: { $0.trashedAt == nil && ($0.ocrStatus == "pending" || $0.previewStatus == "pending") }) {
            let id = item.id
            let revision = item.updatedAt
            do {
                if item.kind == "image", item.ocrStatus == "pending" {
                    guard let attachment = item.attachments.first else {
                        item.ocrStatus = "failed"
                        try store.saveChanges()
                        continue
                    }
                    item.ocrStatus = "running"
                    try store.saveChanges()
                    let result = try await OCRService.recognize(url: store.attachmentURL(attachment))
                    supportedOCRLanguages = result.supportedLanguages
                    if store.isDataOperationInProgress { return }
                    guard let current = store.items.first(where: { $0.id == id }) else { continue }
                    if current.trashedAt != nil {
                        current.ocrStatus = "pending"
                        try store.saveChanges()
                        continue
                    }
                    guard current.updatedAt == revision else {
                        current.ocrStatus = "pending"
                        try store.saveChanges()
                        continue
                    }
                    current.ocrText = result.text
                    current.ocrStatus = result.text.isEmpty ? "empty" : "complete"
                    current.rebuildSearchDocument()
                } else if item.kind == "link", item.previewStatus == "pending" {
                    guard let url = URL(string: item.originalURL) else {
                        item.previewStatus = "failed"
                        try store.saveChanges()
                        continue
                    }
                    item.previewStatus = "running"
                    try store.saveChanges()
                    let title = try await previewLoader(url)
                    if store.isDataOperationInProgress { return }
                    guard let current = store.items.first(where: { $0.id == id }) else { continue }
                    if current.trashedAt != nil {
                        current.previewStatus = "pending"
                        try store.saveChanges()
                        continue
                    }
                    // Metadata does not overwrite a title edited while the request was in flight.
                    if current.updatedAt == revision && !current.userEditedTitle { current.title = title }
                    current.previewStatus = "complete"
                    current.rebuildSearchDocument()
                } else {
                    if item.kind != "image" { item.ocrStatus = "complete" }
                    if item.kind != "link" { item.previewStatus = "complete" }
                }
                try store.saveChanges()
            } catch {
                if let current = store.items.first(where: { $0.id == id }) {
                    if current.ocrStatus == "running" { current.ocrStatus = "failed" }
                    if current.previewStatus == "running" { current.previewStatus = "failed" }
                    do { try store.saveChanges() } catch { lastError = error.localizedDescription; break }
                }
                lastError = error.localizedDescription
            }
            await Task.yield()
        }
    }
}
