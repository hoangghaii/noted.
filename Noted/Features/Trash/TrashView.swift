import SwiftUI

struct TrashView: View {
    let store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var deleting: Item?
    @State private var error: String?
    private var items: [Item] { store.items.filter { $0.trashedAt != nil }.sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) } }

    var body: some View {
        List {
            Section {
                Text("Khôi phục để đưa nội dung trở lại Thư viện. Xóa vĩnh viễn sẽ xóa cả ảnh gốc đã lưu cùng mục này.")
                    .font(.footnote)
                    .foregroundStyle(NotedDesign.Palette.secondaryText)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: NotedDesign.Spacing.md) {
                    Text(item.displayTitle)
                        .lineLimit(2)
                        .font(NotedDesign.TypeStyle.heading)
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                        .accessibilityIdentifier("trashItem_" + item.id.uuidString)
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: NotedDesign.Spacing.sm)) : AnyLayout(HStackLayout(spacing: NotedDesign.Spacing.sm))
                    layout {
                        Button("Khôi phục", systemImage: "arrow.uturn.backward") { perform { try store.restore(item) } }
                            .buttonStyle(NotedButtonStyle(role: .secondary))
                            .accessibilityIdentifier("trashRestore")
                        Button("Xóa vĩnh viễn", systemImage: "trash", role: .destructive) { deleting = item }
                            .buttonStyle(NotedButtonStyle(role: .destructive))
                            .accessibilityIdentifier("trashDelete")
                    }
                }
                .padding(.vertical, NotedDesign.Spacing.sm)
                .listRowBackground(NotedDesign.Palette.toneCream)
            }
        }
        .scrollContentBackground(.hidden)
        .paperBackground()
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    "Thùng rác trống",
                    systemImage: "trash",
                    description: Text("Các mục đã xóa sẽ xuất hiện ở đây.")
                )
                .allowsHitTesting(false)
            }
        }
        .navigationTitle("Thùng rác").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() }.buttonStyle(NotedButtonStyle(role: .soft)) } }
        .overlay { confirmationOverlay }
        .alert("Chưa hoàn tất", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    @ViewBuilder
    private var confirmationOverlay: some View {
        if let item = deleting {
            ZStack {
                Color.black.opacity(0.42).ignoresSafeArea()
                VStack(alignment: .leading, spacing: NotedDesign.Spacing.md) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(NotedDesign.Palette.error)
                        .frame(width: 44, height: 44)
                        .background(NotedDesign.Palette.errorSoft, in: Circle())
                    Text("Xóa vĩnh viễn mục này?")
                        .font(NotedDesign.TypeStyle.title)
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                    Text("Nội dung và ảnh gốc sẽ bị xóa khỏi iPhone. Bạn không thể khôi phục mục này từ Thùng rác.")
                        .font(NotedDesign.TypeStyle.body)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: NotedDesign.Spacing.sm) {
                        Button("Hủy") { deleting = nil }
                            .buttonStyle(NotedButtonStyle(role: .secondary))
                            .accessibilityIdentifier("trashConfirmCancel")
                        Button("Xóa vĩnh viễn", role: .destructive) {
                            perform { try store.permanentlyDelete(item) }
                            deleting = nil
                        }
                        .buttonStyle(NotedButtonStyle(role: .destructive))
                        .accessibilityIdentifier("trashConfirmDelete")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(NotedDesign.Spacing.lg)
                .frame(maxWidth: 350)
                .paperBackground(NotedDesign.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
                .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.card).strokeBorder(NotedDesign.Palette.border) }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("trashConfirmDialog")
            }
            .contentShape(Rectangle())
        }
    }

    private func perform(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}
