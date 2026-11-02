import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

private struct ImportedPhoto: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let size = try received.file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 20 * 1024 * 1024 else { throw ShareGateError.tooLarge }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NotedPhotoImports", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let suffix = received.file.pathExtension.isEmpty ? "image" : received.file.pathExtension
            let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImportedPhoto(url: destination)
        }
    }
}

struct CaptureSheet: View {
    let store: LibraryStore
    private enum EditorFocus: Hashable { case body, url }
    @FocusState private var editorFocus: EditorFocus?
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NoteDraftStore.read()
    @State private var photos: [PhotosPickerItem] = []
    @State private var busy = false
    @State private var saved = false
    @State private var error: String?
    @State private var draftWarning: String?
    @State private var pinAfterSave = false
    @State private var confirmReset = false

    private var canSave: Bool {
        if saved { return false }
        if draft.mode == "photo" { return !photos.isEmpty && photos.count <= 3 }
        if draft.mode == "link" { return validLink != nil }
        return !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var validLink: URL? {
        guard let url = URL(string: draft.url.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    private var photoPickerTitle: String {
        photos.isEmpty ? "Chọn ảnh" : "Đã chọn \(photos.count) ảnh"
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photos, maxSelectionCount: 3, matching: .images) {
            VStack(spacing: NotedDesign.Spacing.xs) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                Text(photoPickerTitle).font(NotedDesign.TypeStyle.heading)
                Text("Tối đa 3 ảnh, mỗi ảnh 20 MB")
                    .font(NotedDesign.TypeStyle.caption)
                    .foregroundStyle(NotedDesign.Palette.secondaryText)
            }
            .foregroundStyle(NotedDesign.Palette.brand)
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(NotedDesign.Palette.brandSoft, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
            .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.input).strokeBorder(NotedDesign.Palette.border, style: StrokeStyle(lineWidth: 1, dash: [6])) }
        }
        .accessibilityIdentifier("capturePhotos")
    }

    private var modeSection: some View {
        EqualWidthPillGroup(count: 3, visualHeight: 44, accessibilityID: "captureMode") { index in
            let mode = ["note", "link", "photo"][index]
            NotedPill(title: ["Ghi chú", "Link", "Ảnh"][index], selected: draft.mode == mode, visualHeight: 44) {
                editorFocus = nil
                draft.mode = mode
            }
            .accessibilityIdentifier("captureMode_" + mode)
        }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: NotedDesign.Spacing.sm) {
            Text("Liên kết *")
                .font(NotedDesign.TypeStyle.heading)
                .foregroundStyle(NotedDesign.Palette.primaryText)
            TextField("Địa chỉ http hoặc https", text: $draft.url)
                .focused($editorFocus, equals: .url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("captureURL")
                .padding(NotedDesign.Spacing.base)
                .frame(minHeight: 52)
                .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
                .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.input).strokeBorder(NotedDesign.Palette.border) }
            Text("Chỉ hỗ trợ liên kết http và https.")
                .font(NotedDesign.TypeStyle.caption)
                .foregroundStyle(NotedDesign.Palette.secondaryText)
            if !draft.url.isEmpty && validLink == nil {
                Text("Nhập liên kết http hoặc https hợp lệ.")
                    .font(.footnote)
                    .foregroundStyle(NotedDesign.Palette.error)
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: NotedDesign.Spacing.sm) {
            Text("Ảnh *")
                .font(NotedDesign.TypeStyle.heading)
                .foregroundStyle(NotedDesign.Palette.primaryText)
            photoPicker
            Text("Lưu bản ảnh riêng trong Noted.")
                .font(NotedDesign.TypeStyle.caption)
                .foregroundStyle(NotedDesign.Palette.secondaryText)
        }
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: NotedDesign.Spacing.sm) {
            Text(draft.mode == "note" ? "Điều bạn muốn giữ *" : "Ghi chú đi kèm · không bắt buộc")
                .font(NotedDesign.TypeStyle.heading)
                .foregroundStyle(NotedDesign.Palette.primaryText)
            ZStack(alignment: .topLeading) {
                if draft.body.isEmpty {
                    Text("Một ý tưởng nhỏ hôm nay…")
                        .font(NotedDesign.TypeStyle.body)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                        .padding(.horizontal, NotedDesign.Spacing.base + 4)
                        .padding(.top, NotedDesign.Spacing.base + 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft.body)
                    .focused($editorFocus, equals: .body)
                .scrollContentBackground(.hidden)
                .padding(NotedDesign.Spacing.md)
                .frame(minHeight: 180)
                .accessibilityLabel(draft.mode == "note" ? "Nội dung ghi chú" : "Ghi chú đi kèm, không bắt buộc")
                .accessibilityIdentifier("captureBody")
            }
            .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
            .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.input).strokeBorder(NotedDesign.Palette.border) }
            Text("\(draft.body.count) ký tự")
                .font(NotedDesign.TypeStyle.caption)
                .foregroundStyle(NotedDesign.Palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: NotedDesign.Spacing.md) {
            Toggle(isOn: $pinAfterSave) {
                VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                    Text("Ghim sau khi lưu").font(NotedDesign.TypeStyle.heading)
                    Text("Đưa mục lên đầu thư viện").font(NotedDesign.TypeStyle.caption)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                }
            }
            .tint(NotedDesign.Palette.brand)
            .accessibilityIdentifier("capturePinAfterSave")
            Button("Dán nội dung", systemImage: "doc.on.clipboard") { paste() }
                .accessibilityIdentifier("capturePaste")
                .foregroundStyle(NotedDesign.Palette.brand)
            Label("Lưu trên iPhone, dùng được khi offline", systemImage: "iphone.and.arrow.forward")
                .font(NotedDesign.TypeStyle.caption)
                .foregroundStyle(NotedDesign.Palette.secondaryText)
        }
        .padding(NotedDesign.Spacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
        .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.card).strokeBorder(NotedDesign.Palette.border) }
    }

    private var saveButton: some View {
        Button { Task { await save() } } label: {
            HStack(spacing: NotedDesign.Spacing.sm) {
                if busy { ProgressView().tint(NotedDesign.Palette.accentText) }
                Text(saved ? "Đã lưu" : busy ? "Đang lưu…" : draft.mode == "note" ? "Lưu ghi chú" : draft.mode == "link" ? "Lưu liên kết" : "Lưu ảnh")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(NotedButtonStyle(role: .primary))
        .disabled(!canSave || busy)
        .accessibilityIdentifier("captureSave")
        .padding(.horizontal, NotedDesign.Spacing.base)
        .padding(.vertical, NotedDesign.Spacing.sm)
        .background(NotedDesign.Palette.paper)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NotedDesign.Spacing.lg) {
                    Text("Bản nháp được giữ trên iPhone")
                        .font(NotedDesign.TypeStyle.caption)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                    modeSection
                    if draft.mode == "link" { linkSection }
                    if draft.mode == "photo" { photoSection }
                    bodySection
                    supportSection
                    if let draftWarning { NotedStatusBanner(message: draftWarning) }
                    Button("Xóa bản nháp") { confirmReset = true }
                        .font(NotedDesign.TypeStyle.caption)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                        .disabled(busy || saved)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(NotedDesign.Spacing.base)
            }
            .background(NotedDesign.Palette.paper)
            .tint(NotedDesign.Palette.brand)
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .operationLoading(busy, message: draft.mode == "photo" ? "Đang xử lý và lưu ảnh…" : "Đang lưu nội dung…")
            .navigationTitle("Lưu nhanh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() }.disabled(busy) }
            }
            .presentationDetents([.height(600), .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(busy)
            .onChange(of: draft.body) { _, _ in persistDraft() }
            .onChange(of: draft.url) { _, _ in persistDraft() }
            .onChange(of: draft.mode) { _, _ in persistDraft() }
            .onDisappear { if !saved { persistDraft() } }
            .confirmationDialog("Xóa bản nháp đang lưu?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Xóa bản nháp", role: .destructive) { clearDraft() }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Nội dung chưa lưu sẽ bị xóa khỏi bản nháp trên iPhone.")
            }
            .alert(saved ? "Đã lưu, chưa ghim" : "Chưa lưu được", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(saved ? "Về Thư viện" : "Đóng", role: .cancel) {
                    error = nil
                    if saved { dismiss() }
                }
            } message: { Text(error ?? "") }
        }
    }

    private func clearDraft() {
        draft = NoteDraft()
        photos = []
        pinAfterSave = false
        do { try NoteDraftStore.clear(); draftWarning = nil }
        catch { draftWarning = "Chưa xóa được bản nháp trên máy. Hãy thử lại." }
    }

    private func paste() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            draft.mode = "link"
            draft.url = url.absoluteString
        } else { draft.mode = "note"; draft.body = text }
    }

    private func persistDraft() {
        do { try NoteDraftStore.save(draft); draftWarning = nil }
        catch { draftWarning = "Chưa ghi được bản nháp trên máy. Hãy giữ cửa sổ này và thử Lưu lại." }
    }

    private func save() async {
        guard !busy, !saved, canSave else { return }
        busy = true
        defer { busy = false }
        await Task.yield()
        let existingIDs = Set(store.items.map(\.id))
        var temporaryFiles: [URL] = []
        defer { for file in temporaryFiles { try? FileManager.default.removeItem(at: file) } }
        do {
            if draft.mode == "photo" {
                for photo in photos {
                    guard let file = try await photo.loadTransferable(type: ImportedPhoto.self) else { throw ShareGateError.invalidPayload }
                    temporaryFiles.append(file.url)
                }
                try await store.captureImageFiles(temporaryFiles, caption: draft.body)
            } else if draft.mode == "link" {
                guard let url = validLink else { throw ShareGateError.unsupported }
                try await store.captureLink(url, caption: draft.body)
            } else { try await store.captureText(draft.body) }
            saved = true
            try? NoteDraftStore.clear()
            if pinAfterSave {
                let added = store.items.filter { !existingIDs.contains($0.id) }
                let expectedCount = draft.mode == "photo" ? photos.count : 1
                let matchesCapture = added.count == expectedCount && added.allSatisfy { item in
                    switch draft.mode {
                    case "note": item.kind == "text" && item.body == draft.body
                    case "link": item.kind == "link" && item.originalURL == validLink?.absoluteString
                    default: item.kind == "image" && item.body == draft.body
                    }
                }
                guard matchesCapture else {
                    self.error = "Nội dung đã được nhận vào hàng đợi. Khi xuất hiện trong Thư viện, bạn có thể ghim từ tùy chọn nội dung."
                    return
                }
                do { for item in added { try store.togglePin(item) } }
                catch {
                    self.error = "Nội dung đã lưu, nhưng chưa ghim được. Hãy mở mục trong Thư viện để thử lại."
                    return
                }
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
