import SwiftUI

struct CollectionsView: View {
    let store: LibraryStore
    @State private var showCreate = false
    @State private var name = ""
    @State private var renaming: ItemCollection?
    @State private var deleting: ItemCollection?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NotedDesign.Spacing.base) {
                VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                    Text("Bộ sưu tập")
                        .font(NotedDesign.TypeStyle.display)
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                    Text("Sắp xếp theo cách của bạn.")
                        .font(NotedDesign.TypeStyle.body)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                }
                Button { name = ""; showCreate = true } label: {
                    Label("Tạo bộ sưu tập", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NotedButtonStyle(role: .secondary))
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
                    ForEach(store.collections) { collection in
                        NavigationLink {
                            LibraryView(store: store, collectionID: collection.id, collectionTitle: collection.name)
                        } label: {
                            HStack(spacing: NotedDesign.Spacing.md) {
                                Image(systemName: "folder.fill")
                                    .font(.title3)
                                    .foregroundStyle(NotedDesign.Palette.brand)
                                    .frame(width: 44, height: 44)
                                    .background(NotedDesign.Palette.brandSoft, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.thumbnail))
                                VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                                    Text(collection.name)
                                        .font(NotedDesign.TypeStyle.heading)
                                        .foregroundStyle(NotedDesign.Palette.primaryText)
                                        .lineLimit(2)
                                    Text(collectionSubtitle(collection))
                                        .font(.caption)
                                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 4)
                                Text("\(collectionItems(collection).count)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(NotedDesign.Palette.secondaryText)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(NotedDesign.Palette.secondaryText)
                            }
                            .padding(NotedDesign.Spacing.base)
                            .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
                            .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.card).strokeBorder(NotedDesign.Palette.border) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("collection_" + collection.id.uuidString)
                        .contextMenu {
                            Button("Đổi tên", systemImage: "pencil") { name = collection.name; renaming = collection }
                            Button("Xóa bộ sưu tập", systemImage: "folder.badge.minus", role: .destructive) { deleting = collection }
                        }
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
        .background(NotedDesign.Palette.paper)
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
    private func collectionSubtitle(_ collection: ItemCollection) -> String {
        let titles = collectionItems(collection).prefix(2).map(\.displayTitle)
        return titles.isEmpty ? "Chưa có nội dung" : titles.joined(separator: ", ")
    }
    private func perform(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}
