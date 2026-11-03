import UIKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let content = ShareGateView(context: extensionContext)
        let hosting = UIHostingController(rootView: content)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        preferredContentSize = CGSize(width: 360, height: 480)
    }
}

private struct ShareGateView: View {
    let context: NSExtensionContext?
    @State private var busy = false
    @State private var message: String?
    @State private var saved = false
    @State private var previewReady = false
    @State private var previewTextValues: [String]?
    @State private var previewLoadError: String?

    private var inputs: [NSExtensionItem] { context?.inputItems as? [NSExtensionItem] ?? [] }
    private var providers: [NSItemProvider] { inputs.flatMap { $0.attachments ?? [] } }
    private var textProviders: [NSItemProvider] {
        providers.filter { provider in
            !provider.registeredTypeIdentifiers.contains(where: { UTType($0)?.conforms(to: .image) == true }) &&
                !provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) &&
                provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }
    }

    private var preflightError: ShareGateError? {
        guard providers.count <= ShareGateStore.maximumEntries + 1 else { return .tooLarge }
        var mediaCount = 0
        var textCount = 0
        for provider in providers {
            if provider.registeredTypeIdentifiers.contains(where: { UTType($0)?.conforms(to: .image) == true }) ||
                provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                mediaCount += 1
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                textCount += 1
            } else { return .unsupported }
        }
        let entryCount = mediaCount > 0 ? mediaCount : textCount
        if entryCount > ShareGateStore.maximumEntries { return .tooLarge }
        if entryCount == 0 && inputs.allSatisfy({
            ($0.attributedContentText?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { return .unsupported }
        return nil
    }

    private var preview: (summary: String, detail: String, symbol: String) {
        let images = providers.filter { provider in
            provider.registeredTypeIdentifiers.contains { UTType($0)?.conforms(to: .image) == true }
        }.count
        let links = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }.count
        let hostText = inputs.compactMap { $0.attributedContentText?.string }.joined(separator: "\n")
        let detail: String
        if !previewReady && previewLoadError == nil {
            detail = "Đang kiểm tra nội dung…"
        } else if previewLoadError != nil {
            detail = "Không thể kiểm tra nội dung."
        } else if images > 0 || links > 0 {
            let captions = ([hostText] + (previewTextValues ?? []))
                .filter { !$0.isEmpty }
            let uniqueCaptions = captions.reduce(into: [String]()) { result, text in
                if !result.contains(text) { result.append(text) }
            }
            detail = uniqueCaptions.isEmpty ? "Sẽ lưu vào Inbox" : uniqueCaptions.joined(separator: "\n")
        } else {
            detail = previewTextValues?.first ?? (hostText.isEmpty ? "Sẽ lưu vào Inbox" : hostText)
        }
        if images > 0 && links > 0 { return ("\(images) ảnh, \(links) link", detail, "photo.on.rectangle") }
        if images > 0 { return ("\(images) ảnh", detail, "photo.on.rectangle") }
        if links > 0 { return ("Liên kết", detail, "link") }
        if !textProviders.isEmpty || !hostText.isEmpty {
            return ("Văn bản", detail, "text.alignleft")
        }
        return ("Nội dung chưa hỗ trợ", "Hãy chọn ảnh, link hoặc văn bản.", "questionmark.square")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NotedDesign.Spacing.base) {
                    HStack(alignment: .top, spacing: NotedDesign.Spacing.md) {
                        VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                            Text(saved ? "Đã lưu trên iPhone" : "Lưu vào Noted.")
                                .scaledFont(28, weight: .bold, relativeTo: .title)
                                .foregroundStyle(NotedDesign.Palette.primaryText)
                            Text(saved ? "Mở Noted. để xem nội dung." : "Lưu trên máy, không cần chọn thư mục.")
                                .font(NotedDesign.TypeStyle.caption)
                                .foregroundStyle(NotedDesign.Palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        CircleIconButton(symbol: "xmark", label: "Hủy") {
                            context?.cancelRequest(withError: CocoaError(.userCancelled))
                        }
                        .disabled(busy || saved)
                        .accessibilityIdentifier("shareCancel")
                    }

                    if !saved {
                        PaperCard(tone: .cream) {
                            HStack(alignment: .top, spacing: NotedDesign.Spacing.md) {
                                Image(systemName: preview.symbol)
                                    .font(.headline)
                                    .foregroundStyle(NotedDesign.Palette.brand)
                                    .frame(width: 32, height: 32)
                                    .background(NotedDesign.Palette.brandSoft, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.thumbnail))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                                    Text(preview.summary)
                                        .font(NotedDesign.TypeStyle.heading)
                                        .foregroundStyle(NotedDesign.Palette.primaryText)
                                    Text(preview.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                                        .lineLimit(3)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(NotedDesign.Spacing.base)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("sharePreview")
                    }
                    if let preflightError, !saved {
                        status(preflightError.localizedDescription)
                            .accessibilityIdentifier("sharePreflightError")
                    } else if let previewLoadError, !saved {
                        status(previewLoadError)
                            .accessibilityIdentifier("sharePreflightError")
                    }
                    if let message { status(message).accessibilityLabel("Lỗi: " + message) }
                    if !previewReady && previewLoadError == nil && preflightError == nil {
                        ProgressView("Đang kiểm tra nội dung…")
                            .tint(NotedDesign.Palette.brand)
                    }
                    if busy {
                        HStack(spacing: NotedDesign.Spacing.sm) {
                            ProgressView().tint(NotedDesign.Palette.brand)
                            Text("Đang lưu…")
                                .font(.subheadline)
                                .foregroundStyle(NotedDesign.Palette.primaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NotedDesign.Spacing.lg)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    if saved { context?.completeRequest(returningItems: nil) }
                    else {
                        guard !busy, preflightError == nil, previewReady, previewLoadError == nil else { return }
                        busy = true
                        Task { await save() }
                    }
                } label: {
                    Text(saved ? "Xong" : "Lưu")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NotedButtonStyle(role: .primary, prominent: true))
                .disabled(busy || (!saved && (preflightError != nil || !previewReady || previewLoadError != nil)))
                .accessibilityIdentifier("shareSave")
                .padding(.horizontal, NotedDesign.Spacing.lg)
                .padding(.vertical, NotedDesign.Spacing.md)
                .paperBackground()
            }
            .paperBackground()
            .tint(NotedDesign.Palette.brand)
            .toolbar(.hidden, for: .navigationBar)
            .task { await preparePreview() }
        }
    }

    private func preparePreview() async {
        guard preflightError == nil else { return }
        do {
            var values: [String] = []
            for provider in providers {
                if let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) {
                    try await validateImageSize(provider, type: type)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let value = try await loadValue(provider, type: UTType.url.identifier)
                    guard let url = value as? URL,
                          ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                    else { throw ShareGateError.unsupported }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    let value = try await loadValue(provider, type: UTType.plainText.identifier)
                    let text: String?
                    if let string = value as? String { text = string }
                    else if let data = value as? Data { text = String(data: data, encoding: .utf8) }
                    else { text = nil }
                    guard let text, !text.isEmpty else { throw ShareGateError.invalidPayload }
                    values.append(text)
                } else { throw ShareGateError.unsupported }
            }
            previewTextValues = values
            previewReady = true
        } catch {
            previewLoadError = error.localizedDescription
        }
    }

    private func validateImageSize(_ provider: NSItemProvider, type: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                do {
                    if let error { throw error }
                    guard let url else { throw ShareGateError.invalidPayload }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= ShareGateStore.maximumFileBytes else { throw ShareGateError.tooLarge }
                    continuation.resume(returning: ())
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func status(_ text: String) -> some View {
        HStack(alignment: .top, spacing: NotedDesign.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(NotedDesign.Palette.error)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(NotedDesign.Palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(NotedDesign.Spacing.md)
        .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
        .accessibilityElement(children: .combine)
    }

    private func save() async {
        message = nil
        defer { busy = false }
        var staging: URL?
        do {
            if let preflightError { throw preflightError }
            // One supplementary text provider may accompany three media entries.
            let store = try ShareGateStore.configured()
            var payload = ShareGatePayload()
            payload.caption = inputs.compactMap { $0.attributedContentText?.string }.joined(separator: "\n")
            if providers.isEmpty {
                payload = try ShareGateStore.textOnlyPayload(payload.caption)
            }
            let directory = try store.begin(id: payload.id)
            staging = directory
            for provider in providers {
                if let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) {
                    let suffix = UTType(type)?.preferredFilenameExtension ?? "image"
                    let name: String = try await withCheckedThrowingContinuation { continuation in
                        provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                            do {
                                if let error { throw error }
                                guard let url else { throw ShareGateError.invalidPayload }
                                let name = try ShareGateStore.copyImage(from: url, to: directory, extension: suffix)
                                continuation.resume(returning: name)
                            } catch { continuation.resume(throwing: error) }
                        }
                    }
                    payload.entries.append(.init(kind: .image, value: name))
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    let value = try await loadValue(provider, type: UTType.url.identifier)
                    guard let url = value as? URL, ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                    else { throw ShareGateError.unsupported }
                    payload.entries.append(.init(kind: .link, value: url.absoluteString))
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    let value = try await loadValue(provider, type: UTType.plainText.identifier)
                    let text: String?
                    if let string = value as? String { text = string }
                    else if let data = value as? Data { text = String(data: data, encoding: .utf8) }
                    else { text = nil }
                    guard let text, !text.isEmpty else { throw ShareGateError.invalidPayload }
                    payload.entries.append(.init(kind: .text, value: text))
                } else { throw ShareGateError.unsupported }
            }
            let grouped = IncomingContentDecoder.groupingSupplementaryText(in: payload)
            guard grouped.entries.count <= ShareGateStore.maximumEntries else { throw ShareGateError.tooLarge }
            try store.publish(grouped, directory: directory)
            staging = nil
            saved = true
        } catch {
            // Unpublished probe data is disposable. Ready batches are never removed here.
            if let staging { try? FileManager.default.removeItem(at: staging) }
            message = error.localizedDescription
        }
    }

    private func loadValue(_ provider: NSItemProvider, type: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { value, error in
                if let error { continuation.resume(throwing: error) }
                else if let value { continuation.resume(returning: value) }
                else { continuation.resume(throwing: ShareGateError.invalidPayload) }
            }
        }
    }
}
