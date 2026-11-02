import SwiftUI

enum LibraryFilter: String, CaseIterable {
    case all = "Tất cả", inbox = "Inbox", images = "Ảnh", links = "Link", notes = "Ghi chú", pinned = "Đã ghim"
    func includes(_ item: Item) -> Bool {
        switch self {
        case .all: true
        case .inbox: item.collectionID == nil
        case .images: item.kind == "image"
        case .links: item.kind == "link"
        case .notes: item.kind == "text"
        case .pinned: item.pinned
        }
    }
}

struct LibraryView: View {
    let store: LibraryStore
    var collectionID: UUID? = nil
    var collectionTitle: String? = nil
    var onManageData: (() -> Void)? = nil
    var onShowTrash: (() -> Void)? = nil
    var onCapture: (() -> Void)? = nil
    @State private var filter = LibraryFilter.all
    @State private var limit = 50
    @State private var error: String?
    @State private var pendingDiscard: CaptureIssue?

    private var items: [Item] {
        store.items.filter { $0.trashedAt == nil && (collectionID == nil || $0.collectionID == collectionID) && filter.includes($0) }
            .sorted { $0.pinned == $1.pinned ? $0.createdAt > $1.createdAt : $0.pinned }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NotedDesign.Spacing.base) {
                if collectionID == nil {
                    HStack(alignment: .center, spacing: NotedDesign.Spacing.base) {
                        VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                            Text("Thư viện")
                                .font(NotedDesign.TypeStyle.display)
                                .foregroundStyle(NotedDesign.Palette.primaryText)
                            Text("Những điều bạn muốn giữ.")
                                .font(.subheadline)
                                .foregroundStyle(NotedDesign.Palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        if let onManageData, let onShowTrash {
                            Menu {
                                Button("Dữ liệu & Backup", systemImage: "externaldrive", action: onManageData)
                                Button("Thùng rác", systemImage: "trash", action: onShowTrash)
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.headline)
                                    .foregroundStyle(NotedDesign.Palette.primaryText)
                                    .frame(width: 44, height: 44)
                                    .background(NotedDesign.Palette.chip, in: Circle())
                            }
                            .accessibilityLabel("Tùy chọn thư viện")
                            .accessibilityIdentifier("libraryOptions")
                        }
                    }
                    if let onCapture {
                        // v3 hero: ~111 pt, one-line 19 pt title; the bulb sits on the right
                        // without taking width from the text (overlay, not an HStack column).
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Một ý hay vừa xuất hiện?")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(NotedDesign.Palette.heroText)
                            Button(action: onCapture) {
                                Label("Lưu nhanh", systemImage: "plus")
                            }
                            .buttonStyle(NotedButtonStyle(role: .primary))
                            .accessibilityIdentifier("captureAdd")
                        }
                        .padding(.leading, 18).padding(.trailing, 88).padding(.top, 18).padding(.bottom, 16)
                        .frame(maxWidth: .infinity, minHeight: 111, alignment: .leading)
                        .overlay(alignment: .trailing) {
                            NotedDesign.Sketch.lightbulb.image.resizable().scaledToFit()
                                .frame(width: 76, height: 76)
                                .foregroundStyle(NotedDesign.Palette.heroText)
                                .padding(.trailing, 14)
                                .accessibilityHidden(true)
                        }
                        .paperBackground(NotedDesign.Palette.hero, isHero: true)
                        .clipShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
                    }
                } else {
                    Text("Nội dung trong bộ sưu tập này.")
                        .font(.subheadline)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                }
                if !store.pendingMessages.isEmpty {
                    DisclosureGroup {
                        ForEach(store.pendingIssues) { issue in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(issue.message).font(.footnote).foregroundStyle(.secondary)
                                Button("Bỏ lượt lưu này", role: .destructive) { pendingDiscard = issue }
                                    .buttonStyle(NotedButtonStyle(role: .destructive))
                                    .disabled(store.isImporting)
                            }
                        }
                        Button("Thử nhập lại") { Task { await retryImport() } }
                            .buttonStyle(NotedButtonStyle(role: .secondary))
                            .disabled(store.isImporting)
                    } label: { NotedStatusBanner(message: "Có nội dung đang chờ xử lý") }
                    .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
                }
                // v3 rhythm: 12.5 pt from "Vừa lưu" to the pills, 14 pt from pills to cards
                // (the 44 pt touch row already adds 4 pt around the 36 pt visual pill).
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Vừa lưu")
                            .font(NotedDesign.TypeStyle.heading)
                            .foregroundStyle(NotedDesign.Palette.primaryText)
                        Spacer()
                        Text("\(items.count) mục")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(NotedDesign.Palette.secondaryText)
                    }
                    EqualWidthPillGroup(count: 6, visibleCount: 4, accessibilityID: "libraryFilters") { index in
                        let choice = [LibraryFilter.all, .inbox, .images, .links, .notes, .pinned][index]
                        NotedPill(title: choice.rawValue, selected: filter == choice) { filter = choice }
                            .accessibilityIdentifier("libraryFilter_" + ["all", "inbox", "images", "links", "notes", "pinned"][index])
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 4)
                if items.isEmpty {
                    ContentUnavailableView(
                        filter == .all ? "Chỗ cho những điều muốn giữ" : "Chưa có mục phù hợp",
                        systemImage: filter == .all ? "tray" : "line.3.horizontal.decrease.circle",
                        description: Text(filter != .all
                            ? "Thử bộ lọc khác hoặc lưu thêm nội dung."
                            : collectionID == nil
                                ? "Chọn Lưu nhanh để ghi chú, thêm ảnh hoặc dán link. Bạn cũng có thể chia sẻ từ app khác."
                                : "Chọn Thêm để lưu nội dung, rồi chọn bộ sưu tập này."))
                        .padding(.top, NotedDesign.Spacing.lg)
                } else {
                    ItemCardGrid(items: Array(items.prefix(limit)), store: store)
                        .padding(.top, -6)
                    if items.count > limit {
                        Button("Xem thêm") { limit += 50 }
                            .buttonStyle(NotedButtonStyle(role: .secondary))
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("libraryLoadMore")
                    }
                }
            }
            .padding(.horizontal, NotedDesign.Spacing.base)
            .padding(.top, 8)
            .padding(.bottom, NotedDesign.Spacing.base + 88)
        }
        .background(NotedDesign.Palette.paper)
        .accessibilityIdentifier("libraryScroll")
        .navigationTitle(collectionTitle ?? "")
        .toolbar(collectionID == nil ? .hidden : .visible, for: .navigationBar)
        .onChange(of: filter) { _, _ in limit = 50 }
        .refreshable { await retryImport() }
        .confirmationDialog("Bỏ lượt lưu đang chờ?", isPresented: Binding(get: { pendingDiscard != nil }, set: { if !$0 { pendingDiscard = nil } }), titleVisibility: .visible) {
            Button("Bỏ lượt lưu", role: .destructive) {
                if let issue = pendingDiscard {
                    do { try store.discardPending(id: issue.id) } catch { self.error = error.localizedDescription }
                }
                pendingDiscard = nil
            }
        } message: { Text("Nội dung chưa nhập của lượt này sẽ bị xóa khỏi Noted. Bản gốc trong app nguồn không thay đổi.") }
        .alert("Chưa hoàn tất", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func retryImport() async {
        do { try await store.importPending() } catch { self.error = error.localizedDescription }
    }
}
