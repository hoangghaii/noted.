import SwiftUI

struct CollectionsView: View {
    let store: LibraryStore
    var onManageData: (() -> Void)? = nil
    var onShowTrash: (() -> Void)? = nil
    @State private var showCreate = false
    @State private var name = ""
    @State private var renaming: ItemCollection?
    @State private var deleting: ItemCollection?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NotedDesign.Spacing.base) {
                HStack {
                    VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                        Text("Bộ sưu tập")
                            .font(NotedDesign.TypeStyle.display)
                            .foregroundStyle(NotedDesign.Palette.primaryText)
                        Text("Mỗi ý tưởng, một góc riêng.")
                            .font(.body)
                            .foregroundStyle(NotedDesign.Palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                    if let onManageData, let onShowTrash {
                        Menu {
                            Button("Dữ liệu & Backup", systemImage: "externaldrive", action: onManageData)
                            Button("Thùng rác", systemImage: "trash", action: onShowTrash)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(NotedDesign.Palette.primaryText)
                                .frame(width: 44, height: 44)
                                .background(NotedDesign.Palette.chip, in: Circle())
                        }
                        .accessibilityLabel("Tùy chọn bộ sưu tập")
                        .accessibilityIdentifier("collectionsOptions")
                    }
                }
                Button { name = ""; showCreate = true } label: {
                    Label("Tạo bộ sưu tập", systemImage: "plus")
                        .font(.system(size: 17))
                        .frame(minHeight: 48)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NotedButtonStyle(role: .soft))
                .accessibilityIdentifier("collectionCreate")
                .padding(.top, NotedDesign.Spacing.sm)
                if store.collections.isEmpty {
                    ContentUnavailableView(
                        "Nhóm những điều liên quan",
                        systemImage: "folder",
                        description: Text("Tạo một bộ sưu tập cho ý tưởng, công việc hoặc chuyến đi của bạn.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NotedDesign.Spacing.xl)
                } else {
                    ForEach(Array(store.collections.enumerated()), id: \.element.id) { index, collection in
                        NavigationLink {
                            LibraryView(store: store, collectionID: collection.id, collectionTitle: collection.name)
                        } label: {
                            FolderCard(name: collection.name, count: collectionItems(collection).count,
                                       sketch: NotedDesign.folderSketch(for: collection.name, id: collection.id),
                                       tone: NotedDesign.folderTone(at: index))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("collection_" + collection.id.uuidString)
                        .contextMenu {
                            Button("Đổi tên", systemImage: "pencil") { name = collection.name; renaming = collection }
                            Button("Xóa bộ sưu tập", systemImage: "folder.badge.minus", role: .destructive) { deleting = collection }
                        }
                        .padding(.top, index == 0 ? 22 : 11.5)
                    }
                }
                Text("Nội dung chưa phân loại vẫn nằm trong Inbox.")
                    .font(.footnote)
                    .foregroundStyle(NotedDesign.Palette.brand)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(NotedDesign.Spacing.md)
                    .background(NotedDesign.Palette.brandSoft,
                                in: RoundedRectangle(cornerRadius: NotedDesign.Radius.thumbnail))
            }
            .padding(NotedDesign.Spacing.base)
            .padding(.bottom, 88)
        }
        .paperBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .alert("Bộ sưu tập mới", isPresented: $showCreate) {
            TextField("Tên", text: $name)
            Button("Tạo") { perform { try store.createCollection(name) } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Hủy", role: .cancel) {}
        }
        .alert("Đổi tên", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Tên", text: $name)
            Button("Lưu") { if let collection = renaming { perform { try store.renameCollection(collection, name: name) } }; renaming = nil }
            Button("Hủy", role: .cancel) { renaming = nil }
        }
        .confirmationDialog("Xóa bộ sưu tập?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Xóa bộ sưu tập", role: .destructive) { if let collection = deleting { perform { try store.deleteCollection(collection) } }; deleting = nil }
        } message: { Text("Nội dung vẫn được giữ và trở về Inbox.") }
        .alert("Chưa hoàn tất", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
    private func collectionItems(_ collection: ItemCollection) -> [Item] {
        store.items.filter { $0.collectionID == collection.id && $0.trashedAt == nil }
    }
    private func perform(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

/// App-only folder row: the tab sits behind the paper and has its own layout space.
private struct FolderCard: View {
    let name: String
    let count: Int
    let sketch: NotedDesign.Sketch
    let tone: NotedDesign.PaperTone

    var body: some View {
        PaperCard(tone: tone) {
            // v3: ~99 pt rows, ~54 pt folder drawing inset ~30 pt, name starting ~124 pt in.
            HStack(spacing: 28) {
                // The SVG artwork fills ~81% of its box.
                sketch.image.resizable().scaledToFit()
                    .frame(width: 66, height: 66)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.system(size: 19, weight: .semibold)).lineLimit(2)
                    Text("\(count) mục").font(.system(size: 14))
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .medium))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(NotedDesign.Palette.primaryText)
            .padding(.leading, 26).padding(.trailing, 20).padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                .fill(NotedDesign.Palette.folderTab)
                .frame(width: 72, height: 20)
                .offset(x: 22, y: -15)
        }
    }
}
