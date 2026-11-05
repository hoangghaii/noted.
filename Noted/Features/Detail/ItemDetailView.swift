import SwiftUI

struct ItemDetailView: View {
    let item: Item
    let store: LibraryStore
    @Environment(\.linkDigestRunner) private var digestRunner
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var confirmTrash = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NotedDesign.Spacing.lg) {
                HStack {
                    Text(item.kind == "image" ? "ẢNH" : item.kind == "link" ? "LIÊN KẾT" : "GHI CHÚ")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NotedDesign.Palette.brand)
                    Text("·")
                    Text(item.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                    Spacer()
                    if item.pinned { Label("Đã ghim", systemImage: "pin.fill").font(.caption).foregroundStyle(NotedDesign.Palette.brand) }
                }
                if item.kind == "image" {
                    ForEach(item.attachments) { attachment in
                        StoredImageView(url: store.attachmentURL(attachment), maximumPixels: 1800)
                            .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
                        ShareLink(item: store.attachmentURL(attachment)) { Label("Chia sẻ ảnh gốc", systemImage: "square.and.arrow.up") }
                            .buttonStyle(NotedButtonStyle(role: .soft))
                            .accessibilityIdentifier("detailShareOriginal")
                    }
                }
                if !item.title.isEmpty { Text(item.title).font(NotedDesign.TypeStyle.title).foregroundStyle(NotedDesign.Palette.primaryText).textSelection(.enabled) }
                if item.kind == "link", let url = URL(string: item.originalURL) {
                    Link(destination: url) {
                        Label(item.originalURL, systemImage: "arrow.up.right.square").font(.body)
                            .multilineTextAlignment(.leading)
                    }
                    .accessibilityIdentifier("detailOpenURL")
                    ShareLink(item: url) { Label("Chia sẻ link", systemImage: "square.and.arrow.up") }.buttonStyle(NotedButtonStyle(role: .soft))
                }
                if item.kind == "link", item.previewStatus == "pending" || item.previewStatus == "running" {
                    ProgressView("Đang tải preview liên kết…").font(.footnote)
                }
                if item.kind == "link" { linkSummary }
                if !item.body.isEmpty { Text(item.body).font(.body).foregroundStyle(NotedDesign.Palette.primaryText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                if item.kind == "text" { ShareLink(item: item.body) { Label("Chia sẻ ghi chú", systemImage: "square.and.arrow.up") }.buttonStyle(NotedButtonStyle(role: .soft)) }
                if !item.tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(Array(item.tags.enumerated()), id: \.offset) { _, tag in
                            TagChip(title: "#" + tag).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if let collection = store.collections.first(where: { $0.id == item.collectionID }) {
                    Label(collection.name, systemImage: "folder").font(.subheadline).foregroundStyle(.secondary)
                }
                if !item.ocrText.isEmpty {
                    DisclosureGroup("Chữ nhận diện trong ảnh") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Chữ được nhận diện tự động và có thể sai. Ảnh gốc vẫn được giữ nguyên; bạn có thể thêm từ khóa vào ghi chú ảnh để dễ tìm.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Text(item.ocrText).font(.footnote).textSelection(.enabled)
                        }
                    }
                } else if item.kind == "image", item.ocrStatus == "failed" {
                    Text("Chưa nhận diện được chữ trong ảnh. Bạn vẫn có thể thêm ghi chú để tìm lại.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if item.kind == "image" {
                    Button("Đọc chữ lại", systemImage: "text.viewfinder") {
                        perform { item.ocrStatus = "pending"; try store.saveChanges() }
                    }.buttonStyle(NotedButtonStyle(role: .soft)).disabled(item.ocrStatus == "pending" || item.ocrStatus == "running")
                    if item.ocrStatus == "pending" || item.ocrStatus == "running" {
                        ProgressView(item.ocrStatus == "running" ? "Đang nhận diện chữ…" : "Đang chờ nhận diện chữ…").font(.footnote)
                    }
                }
            }
            .padding(NotedDesign.Spacing.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperBackground(NotedDesign.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
            .padding(NotedDesign.Spacing.base)
        }
        .paperBackground()
        .navigationTitle(item.kind == "image" ? "Ảnh" : item.kind == "link" ? "Liên kết" : "Ghi chú")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("itemDetail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Sửa", systemImage: "pencil") { showEditor = true }.accessibilityIdentifier("itemEdit")
                    Button(item.pinned ? "Bỏ ghim" : "Ghim", systemImage: "pin") { perform { try store.togglePin(item) } }
                    Button("Chuyển vào thùng rác", systemImage: "trash", role: .destructive) { confirmTrash = true }
                        .accessibilityIdentifier("itemTrash")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                        .frame(width: 44, height: 44)
                        .background(NotedDesign.Palette.chip, in: Circle())
                }.accessibilityLabel("Tùy chọn nội dung")
            }.notedOwnBackground()
        }
        .sheet(isPresented: $showEditor) { ItemEditor(item: item, store: store) }
        .confirmationDialog("Chuyển vào Thùng rác?", isPresented: $confirmTrash) {
            Button("Chuyển vào Thùng rác", role: .destructive) {
                perform { try store.trash(item); dismiss() }
            }
        } message: {
            Text("Bạn có thể khôi phục mục này sau.")
        }
        .alert("Chưa hoàn tất", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    @ViewBuilder private var linkSummary: some View {
        if let runner = digestRunner {
            let digest = runner.digest(for: item)
            VStack(alignment: .leading, spacing: 8) {
                Text("Tóm tắt").font(.headline)
                if let digest, let summary = digest.visibleSummary {
                    if let title = digest.title { Text(title).font(.subheadline.weight(.semibold)) }
                    if !digest.byline.isEmpty { Text(digest.byline).font(.subheadline) }
                    Text(summary).textSelection(.enabled).accessibilityIdentifier("detailLinkSummary")
                    Text(digest.source == LinkDigestSource.api.rawValue ? "Viết lại bằng AI" : "Trích từ trang")
                        .font(.caption).foregroundStyle(.secondary)
                    if let date = digest.fetchedAt {
                        Text("Đọc ngày \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if digest?.state == .loginWall {
                    Text("Không đọc được nội dung (cần đăng nhập)")
                    Text("Bạn có thể thêm ghi chú để nhớ nội dung link.").font(.footnote)
                    Button("Thêm ghi chú", systemImage: "pencil") { showEditor = true }
                } else if digest?.state == .pending || digest?.state == .running {
                    Text("Đang chờ đọc nội dung link…").font(.footnote)
                } else {
                    Text("Chưa đọc được nội dung link.").font(.footnote)
                }
                Button("Thử đọc lại", systemImage: "arrow.clockwise") {
                    do {
                        try runner.retry(itemID: item.id)
                        Task { await runner.run(in: store) }
                    } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(NotedButtonStyle(role: .soft))
                .disabled(runner.running || store.isDataOperationInProgress)
                .accessibilityIdentifier("detailRetryLink")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }
}

struct ItemEditDraft: Codable, Equatable {
    var title: String
    var body: String
    var tags: String
    var collectionID: UUID?
}

enum DetailDraftStore {
    static func path(_ id: UUID) -> URL {
        #if DEBUG
        if let directory = PhaseFourFixtures.draftDirectory { return directory.appendingPathComponent("item-" + id.uuidString + ".json") }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NotedDraft", isDirectory: true).appendingPathComponent("item-" + id.uuidString + ".json")
    }
    static func read(_ id: UUID) -> ItemEditDraft? {
        guard let data = try? Data(contentsOf: path(id)) else { return nil }
        return try? JSONDecoder().decode(ItemEditDraft.self, from: data)
    }
    static func save(_ draft: ItemEditDraft, id: UUID) throws {
        try FileManager.default.createDirectory(at: path(id).deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: path(id), options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}

private struct ItemEditor: View {
    let item: Item
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ItemEditDraft
    @State private var error: String?
    @State private var draftWarning = false
    @State private var saved = false

    init(item: Item, store: LibraryStore) {
        self.item = item
        self.store = store
        _draft = State(initialValue: DetailDraftStore.read(item.id) ?? ItemEditDraft(title: item.title, body: item.body, tags: item.tags.joined(separator: ", "), collectionID: item.collectionID))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PaperField(label: "Tiêu đề") {
                        TextField("Không bắt buộc", text: $draft.title).accessibilityIdentifier("editTitle")
                    }
                    PaperField(label: "Nội dung") {
                        TextEditor(text: $draft.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 180)
                            .accessibilityIdentifier("editBody")
                    }
                    PaperField(label: "Thẻ") {
                        TextField("Tag, phân cách bằng dấu phẩy", text: $draft.tags)
                            .textInputAutocapitalization(.never).accessibilityIdentifier("editTags")
                    }
                    PaperField(label: "Bộ sưu tập") {
                        Picker("Bộ sưu tập", selection: $draft.collectionID) {
                            Text("Inbox").tag(UUID?.none)
                            ForEach(store.collections) { collection in Text(collection.name).tag(Optional(collection.id)) }
                        }.accessibilityIdentifier("editCollection")
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                #if DEBUG
                if PhaseFourFixtures.isVerificationStore(store) {
                    Section("Kiểm chứng dữ liệu thử") {
                        Button("Thử lỗi lưu một lần") { PhaseFourFixtures.failNextSave(in: store) }
                            .accessibilityIdentifier("fixtureFailSave")
                        Button("Chuẩn bị lượt nhập mới") {
                            do { try PhaseFourFixtures.stageIncoming(in: store) }
                            catch { self.error = error.localizedDescription }
                        }.accessibilityIdentifier("fixtureStageIncoming")
                        Text("\(store.items.count)").accessibilityIdentifier("fixtureImportCount")
                    }
                }
                #endif
                if draftWarning {
                    Text("Chưa ghi được bản nháp. Hãy giữ cửa sổ này và thử lưu lại.")
                        .font(.footnote)
                        .foregroundStyle(NotedDesign.Palette.error)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .tint(NotedDesign.Palette.brand)
            .accessibilityIdentifier("itemEditorForm")
            .navigationTitle("Chỉnh sửa").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CircleIconButton(symbol: "xmark", label: "Đóng") { dismiss() } }.notedOwnBackground()
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        do {
                            try store.update(item, title: draft.title, body: draft.body,
                                tags: draft.tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                                collectionID: draft.collectionID)
                            saved = true
                            try? FileManager.default.removeItem(at: DetailDraftStore.path(item.id))
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }.buttonStyle(NotedButtonStyle(role: .primary)).fixedSize().accessibilityIdentifier("editSave")
                }.notedOwnBackground()
            }
            .onChange(of: draft.title) { _, _ in persist() }
            .onChange(of: draft.body) { _, _ in persist() }
            .onChange(of: draft.tags) { _, _ in persist() }
            .onChange(of: draft.collectionID) { _, _ in persist() }
            .onDisappear { if !saved { persist() } }
            .alert("Chưa lưu được", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Đóng", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private func persist() {
        do { try DetailDraftStore.save(draft, id: item.id); draftWarning = false }
        catch { draftWarning = true }
    }
}
