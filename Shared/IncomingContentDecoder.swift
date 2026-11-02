import Foundation

enum IncomingContentDecoder {
    /// Hosts may deliver a caption as its own text provider alongside a URL/image.
    /// Keep that text with the media instead of creating an unrelated note.
    static func groupingSupplementaryText(in input: ShareGatePayload) -> ShareGatePayload {
        guard input.entries.contains(where: { $0.kind != .text }) else { return input }
        var result = input
        var captions: [String] = []
        for text in [input.caption] + input.entries.filter({ $0.kind == .text }).map(\.value) {
            if !text.isEmpty && !captions.contains(text) { captions.append(text) }
        }
        result.caption = captions.joined(separator: "\n")
        result.entries.removeAll { $0.kind == .text }
        return result
    }
}
