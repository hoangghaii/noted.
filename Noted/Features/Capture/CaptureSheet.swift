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
    private enum EditorFocus: Hashable { case title, body, url, tags }
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
    @State private var tagInput = ""
    @State private var moreOptions = false
    @State private var viewportHeight: CGFloat = 0
    // Icon columns measured on v3 at the default text size; they grow with the scaled glyphs.
    @ScaledMetric(relativeTo: .title3) private var folderIconWidth: CGFloat = 26
    @ScaledMetric(relativeTo: .title3) private var tagIconWidth: CGFloat = 24

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
            .background(NotedDesign.Palette.toneSage, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
            .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.input).strokeBorder(NotedDesign.Palette.border, style: StrokeStyle(lineWidth: 1, dash: [6])) }
        }
        .accessibilityIdentifier("capturePhotos")
    }

    private var modeSection: some View {
        EqualWidthPillGroup(count: 3, visualHeight: 44, accessibilityID: "captureMode") { index in
            let mode = ["note", "link", "photo"][index]
            NotedPill(title: ["Ghi chú", "Link", "Ảnh"][index], selected: draft.mode == mode,
                       symbol: ["doc.text", "link", "photo"][index], symbolSize: 17.5, visualHeight: 44) {
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
        // Mock v3: plain field label, cream paper sheet with rounded corners (no border, no curl).
        VStack(alignment: .leading, spacing: 9) {
            PaperFieldLabel(text: draft.mode == "note" ? "Nội dung" : "Ghi chú đi kèm")
            PaperCard(tone: .cream) {
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
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                        .scrollContentBackground(.hidden)
                        .padding(NotedDesign.Spacing.md)
                        // Fixed like before; a min height would absorb the first-screen spacer below.
                        .frame(height: 182)
                        .accessibilityLabel(draft.mode == "note" ? "Nội dung ghi chú" : "Ghi chú đi kèm, không bắt buộc")
                        .accessibilityHint(draft.mode == "note" ? "Bắt buộc" : "")
                        .accessibilityIdentifier("captureBody")
                }
            }
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
            Text("\(draft.body.count) ký tự")
                .font(NotedDesign.TypeStyle.caption)
                .foregroundStyle(NotedDesign.Palette.secondaryText)
            Label("Lưu trên iPhone, dùng được khi offline", systemImage: "iphone.and.arrow.forward")
                .font(NotedDesign.TypeStyle.caption)
                .foregroundStyle(NotedDesign.Palette.secondaryText)
        }
        .padding(NotedDesign.Spacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
        .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.card).strokeBorder(NotedDesign.Palette.border) }
    }

    /// Mock v3 header: handle at 17 pt, 40 pt close circle at 337,23 (13 pt from the edge), title below at 51 pt.
    private var header: some View {
        ZStack(alignment: .top) {
            Capsule().fill(NotedDesign.Palette.handle).frame(width: 48, height: 5)
                .padding(.top, 17)
                .accessibilityHidden(true)
            HStack(alignment: .top) {
                Text("Lưu nhanh").scaledFont(28, weight: .bold, relativeTo: .title)
                    .foregroundStyle(NotedDesign.Palette.primaryText)
                    // Glyph ink measured at 24.7,55.3 in v3.
                    .padding(.top, 48) // whole points keep the pill row on the pixel grid
                    .padding(.leading, 3)
                Spacer()
                CircleIconButton(symbol: "xmark", label: "Đóng", diameter: 40) { dismiss() }
                    .disabled(busy).accessibilityIdentifier("captureClose")
                    .padding(.top, 21)
                    .padding(.trailing, -9)
            }
        }
    }

    private var saveButton: some View {
        Button { Task { await save() } } label: {
            HStack(spacing: NotedDesign.Spacing.sm) {
                if busy { ProgressView().tint(NotedDesign.Palette.accentText) }
                Text(saved ? "Đã lưu" : busy ? "Đang lưu…" : draft.mode == "note" ? "Lưu ghi chú" : draft.mode == "link" ? "Lưu liên kết" : "Lưu ảnh")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(NotedButtonStyle(role: .primary, prominent: true))
        .disabled(!canSave || busy)
        .accessibilityIdentifier("captureSave")
        .padding(.horizontal, 20)
        .padding(.vertical, NotedDesign.Spacing.sm)
        .background(NotedDesign.Palette.paper)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
            ScrollView {
                // Vertical rhythm follows paper-ui-spec Q18–Q39 (pt from the sheet top).
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        modeSection.padding(.top, 21)
                        if draft.mode != "photo" { titleSection.padding(.top, 23) }
                        if draft.mode == "link" { linkSection.padding(.top, 16) }
                        if draft.mode == "photo" { photoSection.padding(.top, 23) }
                        bodySection.padding(.top, 16)
                        collectionSection.padding(.top, 19)
                        tagsSection.id("captureTagsRow").padding(.top, 21)
                    }
                    // Plan decision: "Tùy chọn khác" stays below the first screenful on any device height.
                    .frame(minHeight: viewportHeight, alignment: .top)
                    // Identify only the header: an identifier on the whole group overrides its children's ids.
                    DisclosureGroup(isExpanded: $moreOptions) {
                        supportSection
                        Button("Xóa bản nháp") { confirmReset = true }
                            .font(NotedDesign.TypeStyle.caption)
                            .foregroundStyle(NotedDesign.Palette.secondaryText)
                            .disabled(busy || saved)
                            .id("captureMoreOptionsEnd")
                    } label: {
                        Text("Tùy chọn khác").accessibilityIdentifier("captureMoreOptions")
                    }
                    .padding(.top, 24)
                }
                // v3 capture sheet uses ~20 pt side margins (fields measured at 20.7–370.7 pt).
                .padding(.horizontal, 20)
                .padding(.bottom, NotedDesign.Spacing.base)
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { viewportHeight = $0 }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: editorFocus) { _, focus in
                if focus == .tags {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollProxy.scrollTo("captureTagsRow", anchor: .center)
                    }
                }
            }
            // The header sits at the fold; reveal the options it opens instead of expanding off-screen.
            .onChange(of: moreOptions) { _, expanded in
                guard expanded else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    scrollProxy.scrollTo("captureMoreOptionsEnd", anchor: .bottom)
                }
            }
            .paperBackground()
            .tint(NotedDesign.Palette.brand)
            // spacing 0: the default 8 pt gap is uncovered and shows the white sheet base.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // The draft warning must stay visible: the first-screen block always fills the viewport.
                VStack(spacing: 0) {
                    if let draftWarning {
                        NotedStatusBanner(message: draftWarning)
                            .padding(.horizontal, 20).padding(.top, NotedDesign.Spacing.sm)
                            .background(NotedDesign.Palette.paper)
                    }
                    saveButton
                }
            }
            .operationLoading(busy, message: draft.mode == "photo" ? "Đang xử lý và lưu ảnh…" : "Đang lưu nội dung…")
            .toolbar(.hidden, for: .navigationBar)
            .presentationDetents([.large])
            .presentationCornerRadius(28)
            // Drawn in `header` at the mock's position; the system handle sits ~10 pt higher.
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(busy)
            .onChange(of: draft.body) { _, _ in persistDraft() }
            .onChange(of: draft.url) { _, _ in persistDraft() }
            .onChange(of: draft.mode) { _, _ in persistDraft() }
            .onChange(of: draft.title) { _, _ in persistDraft() }
            .onChange(of: draft.collectionID) { _, _ in persistDraft() }
            .onChange(of: draft.tags) { _, _ in persistDraft() }
            .onDisappear { if !saved { commitTag(); persistDraft() } }
            .confirmationDialog("Xóa bản nháp đang lưu?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Xóa bản nháp", role: .destructive) { clearDraft() }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Nội dung chưa lưu sẽ bị xóa khỏi bản nháp trên iPhone.")
            }
            .alert(saved ? "Đã lưu" : "Chưa lưu được", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(saved ? "Về Thư viện" : "Đóng", role: .cancel) {
                    error = nil
                    if saved { dismiss() }
                }
            } message: { Text(error ?? "") }
            }
        }
    }

    private func clearDraft() {
        draft = NoteDraft()
        photos = []
        pinAfterSave = false
        tagInput = ""
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

    private var titleSection: some View {
        PaperField(label: "Tiêu đề", minHeight: 42) {
            TextField("Thêm tiêu đề", text: $draft.title)
                .focused($editorFocus, equals: .title)
                .accessibilityIdentifier("captureTitle")
        }
    }

    private var collectionSection: some View {
        PaperField(label: "Bộ sưu tập", spacing: 6, minHeight: 47) {
            Menu {
                Button("Inbox") { draft.collectionID = nil }
                ForEach(store.collections) { collection in
                    Button(collection.name) { draft.collectionID = collection.id }
                }
            } label: {
                HStack(spacing: 22) {
                    Image(systemName: "folder").scaledFont(22, relativeTo: .title3).frame(width: folderIconWidth)
                    Text(store.collections.first(where: { $0.id == draft.collectionID })?.name ?? "Inbox")
                    Spacer()
                    Image(systemName: "chevron.right").scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                }
                .frame(minHeight: 47)
                .contentShape(Rectangle())
            }.accessibilityIdentifier("captureCollection")
        }
    }

    /// One row like the mock: tag icon, chips, then the input inline (placeholder only while empty).
    private var tagsSection: some View {
        PaperField(label: "Thẻ", spacing: 4, minHeight: 51) {
            HStack(spacing: 20) {
                Image(systemName: "tag").scaledFont(20, relativeTo: .title3).frame(width: tagIconWidth)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(draft.tags, id: \.self) { tag in
                            Button { draft.tags.removeAll { $0 == tag } } label: {
                                // v3 chip is ~99 pt for “cảm hứng”; a small xmark keeps removal visible.
                                HStack(spacing: 4) {
                                    Text(tag).scaledFont(15, relativeTo: .subheadline)
                                    Image(systemName: "xmark").scaledFont(9, weight: .semibold, relativeTo: .caption2)
                                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                                }
                                .foregroundStyle(NotedDesign.Palette.primaryText)
                                .padding(.horizontal, 9).padding(.vertical, 7.5)
                                .background(NotedDesign.Palette.toneSage, in: Capsule())
                            }.buttonStyle(.plain).accessibilityLabel("Xóa thẻ " + tag)
                        }
                        TextField(draft.tags.isEmpty ? "Thêm thẻ" : "", text: $tagInput)
                            .focused($editorFocus, equals: .tags)
                            .submitLabel(.done)
                            .onSubmit { commitTag() }
                            .onChange(of: tagInput) { _, value in
                                if value.contains(",") { commitTag() }
                            }
                            .frame(minWidth: 96)
                            .accessibilityLabel("Thêm thẻ")
                            .accessibilityIdentifier("captureTags")
                    }
                    .frame(minHeight: 51)
                }
            }
        }
    }

    private func commitTag() {
        let entries = tagInput.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for entry in entries where !draft.tags.contains(entry) { draft.tags.append(entry) }
        tagInput = ""
    }


    private func save() async {
        guard !busy, !saved, canSave else { return }
        busy = true
        commitTag()
        defer { busy = false }
        await Task.yield()
        let options = PostCaptureOptions(title: draft.title, tags: draft.tags, collectionID: draft.collectionID,
                                         pin: pinAfterSave, mode: draft.mode)
        var temporaryFiles: [URL] = []
        defer { for file in temporaryFiles { try? FileManager.default.removeItem(at: file) } }
        do {
            let payloadID: UUID
            if draft.mode == "photo" {
                for photo in photos {
                    guard let file = try await photo.loadTransferable(type: ImportedPhoto.self) else { throw ShareGateError.invalidPayload }
                    temporaryFiles.append(file.url)
                }
                payloadID = try await store.captureImageFiles(temporaryFiles, caption: draft.body, options: options)
            } else if draft.mode == "link" {
                guard let url = validLink else { throw ShareGateError.unsupported }
                payloadID = try await store.captureLink(url, caption: draft.body, options: options)
            } else { payloadID = try await store.captureText(draft.body, options: options) }
            saved = true
            // Options are stored with the payload, so clearing the draft cannot lose them.
            try? NoteDraftStore.clear()
            if !options.isEmpty && !store.isCaptureSettled(payloadID) {
                self.error = "Nội dung đã được lưu trên iPhone. Tiêu đề, thẻ, bộ sưu tập hoặc ghim sẽ tự áp dụng khi mục xuất hiện trong Thư viện."
                return
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
