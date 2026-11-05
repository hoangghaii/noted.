import Foundation

/// The exact string shown in preview is also the only page data sent to the API.
enum RemoteLinkDigester {
    struct Payload: Codable, Equatable {
        var domain: String
        var title: String
        var description: String
        var mainText: String
    }

    static func payload(fields: LinkPageFields, url: URL, content: LinkDigestContent) -> String? {
        guard content.status == .complete else { return nil }
        func clean(_ text: String?) -> String {
            let text = LinkPageParser.collapse(text ?? "")
            return text.replacingOccurrences(of: #"(?i)(?:https?://|www\.)[^\s<>\"']+"#, with: "", options: .regularExpression)
        }
        var value = Payload(domain: String((url.host?.lowercased() ?? "").prefix(253)),
                            title: String(clean(content.title).prefix(300)),
                            description: String(clean(fields.description?.text ?? fields.jsonLD.description).prefix(800)),
                            mainText: String(clean(fields.mainText.isEmpty ? fields.jsonLD.articleBody : fields.mainText).prefix(2_000)))
        guard !value.description.isEmpty || !value.mainText.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Bound the complete serialized payload, including keys, delimiters and escaped characters.
        while let data = try? encoder.encode(value), let encoded = String(data: data, encoding: .utf8) {
            if encoded.count <= 2_000 { return encoded }
            if !value.mainText.isEmpty { value.mainText.removeLast() }
            else if !value.description.isEmpty { value.description.removeLast() }
            else if !value.title.isEmpty { value.title.removeLast() }
            else { return nil }
        }
        return nil
    }

    static func validate(_ text: String, extractive: LinkDigestContent) -> LinkDigestContent? {
        guard extractive.status == .complete, let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["title", "summary"]),
              let title = object["title"] as? String, let summary = object["summary"] as? String,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 80,
              !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, summary.count <= 300,
              !title.contains("\n"), !title.contains("<"), !summary.contains("<"),
              !title.contains("://"), !summary.contains("://") else { return nil }
        var result = extractive
        result.title = title
        result.summary = summary
        // Keep extracted evidence for embeddings; generated text is never treated as evidence.
        return result
    }

    @MainActor static func rewrite(_ fetch: LinkDigestFetch, using generator: RemoteTextGenerator) async -> LinkDigestContent? {
        guard let payload = fetch.remotePayload, fetch.content.status == .complete else { return nil }
        do { return validate(try await generator.generateLink(payload: payload), extractive: fetch.content) }
        catch { return nil }
    }
}
