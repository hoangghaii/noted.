import Foundation
import SwiftData

extension LibraryStore {
    /// Read-only preflight for the complete batch; no model insertion happens until it passes.
    func preflightCaptures(_ captures: [PreparedCapture]) throws -> [PreparedCapture] {
        let existingItems = try context.fetch(FetchDescriptor<Item>())
        let byCapture = Dictionary(uniqueKeysWithValues: existingItems.map { ($0.captureID, $0) })
        var itemIDs = Set(existingItems.map(\.id))
        var attachmentIDs = Set(try context.fetch(FetchDescriptor<Attachment>()).map(\.id))
        var newCaptureIDs = Set<String>()
        var pending: [PreparedCapture] = []
        let files = AttachmentStore(root: root)

        for capture in captures {
            if let existing = byCapture[capture.captureID] {
                // Retry must preserve user edits, but cannot discard the source if its
                // committed image is absent or refers to another immutable original.
                guard existing.kind == capture.kind else { throw LibraryError.identityCollision }
                if let prepared = capture.attachment {
                    guard existing.attachments.contains(where: { $0.checksum == prepared.checksum && $0.size == prepared.size })
                    else { throw LibraryError.identityCollision }
                }
                for attachment in existing.attachments { try files.validate(attachment) }
                continue
            }
            guard newCaptureIDs.insert(capture.captureID).inserted,
                  itemIDs.insert(capture.id).inserted else { throw LibraryError.identityCollision }
            if let attachment = capture.attachment {
                guard attachmentIDs.insert(attachment.id).inserted else { throw LibraryError.identityCollision }
            }
            pending.append(capture)
        }
        return pending
    }

    func validateCommittedOriginals(batchID: UUID) throws {
        let prefix = batchID.uuidString + "."
        let committed = try context.fetch(FetchDescriptor<Item>()).filter { $0.captureID.hasPrefix(prefix) }
        let files = AttachmentStore(root: root)
        for item in committed {
            if item.kind == "image", item.attachments.isEmpty { throw LibraryError.invalidAttachment }
            for attachment in item.attachments { try files.validate(attachment) }
        }
        // A receipt with no remaining item means that batch's items were deliberately
        // deleted. Do not re-import or resurrect them merely because cleanup was retried.
    }
}
