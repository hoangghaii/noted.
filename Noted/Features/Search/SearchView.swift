import SwiftUI

struct SearchView: View {
    let store: LibraryStore
    @State private var query = ""
    @State private var settledQuery = ""
    @State private var kind = "all"
    @State private var period = "all"
    @State private var collection: UUID?
    @State private var limit = 50

    private var results: [Item] {
        let cutoff: Date? = period == "today" ? Calendar.current.startOfDay(for: Date()) : period == "week" ? Calendar.current.date(byAdding: .day, value: -7, to: Date()) : nil
        return store.items.filter { item in
            item.trashedAt == nil && (kind == "all" || item.kind == kind) &&
            (collection == nil || item.collectionID == collection) &&
            (cutoff == nil || item.createdAt >= cutoff!) &&
            SearchService.matches(item: item, query: settledQuery)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NotedDesign.Spacing.base) {
                VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                    Text("Tìm lại")
                        .font(NotedDesign.TypeStyle.display)
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                    Text("Gõ điều bạn còn nhớ.")
                        .font(.subheadline)
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                }
                PaperField(label: "Tìm kiếm") {
                    HStack(spacing: NotedDesign.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(NotedDesign.Palette.secondaryText)
                        TextField("Tìm ghi chú, link, ảnh…", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .accessibilityIdentifier("searchQuery")
                        if !query.isEmpty {
                            Button("Xóa tìm kiếm", systemImage: "xmark.circle.fill") { query = "" }
                                .labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                                .foregroundStyle(NotedDesign.Palette.secondaryText)
                        }
                    }
                }
                filters

                HStack(alignment: .firstTextBaseline) {
                    Text(settledQuery.isEmpty ? "Mới lưu" : "\(results.count) kết quả")
                        .font(NotedDesign.TypeStyle.heading)
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                    Spacer()
                    Text("\(results.count) mục")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                }
                if results.isEmpty {
                    ContentUnavailableView(
                        settledQuery.isEmpty ? "Chưa có mục phù hợp" : "Chưa tìm thấy",
                        systemImage: "magnifyingglass",
                        description: Text("Thử một từ khác hoặc bỏ bộ lọc."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, NotedDesign.Spacing.xl)
                } else {
                    ItemCardGrid(items: Array(results.prefix(limit)), store: store)
                    if results.count > limit {
                        Button("Xem thêm") { limit += 50 }
                            .buttonStyle(NotedButtonStyle(role: .secondary))
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("searchLoadMore")
                    }
                }
                Text("Có thể tìm tiếng Việt có hoặc không dấu.")
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
        .task(id: query) {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard !Task.isCancelled else { return }
            settledQuery = query
            limit = 50
        }
        .onChange(of: kind) { _, _ in limit = 50 }
        .onChange(of: period) { _, _ in limit = 50 }
        .onChange(of: collection) { _, _ in limit = 50 }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: NotedDesign.Spacing.sm) {
            EqualWidthPillGroup(count: 4, accessibilityID: "searchKindFilters") { index in
                let values = ["all", "text", "image", "link"]
                NotedPill(title: ["Tất cả", "Ghi chú", "Ảnh", "Link"][index], selected: kind == values[index]) {
                    kind = values[index]
                }
                .accessibilityIdentifier("searchKind_" + values[index])
            }
            EqualWidthPillGroup(count: 3, accessibilityID: "searchPeriodFilters") { index in
                let values = ["all", "today", "week"]
                NotedPill(title: ["Mọi lúc", "Hôm nay", "7 ngày qua"][index], selected: period == values[index]) {
                    period = values[index]
                }
                .accessibilityIdentifier("searchPeriod_" + values[index])
            }
            EqualWidthPillGroup(count: store.collections.count + 1, visibleCount: 2, accessibilityID: "searchCollectionFilters") { index in
                if index == 0 {
                    NotedPill(title: "Mọi bộ sưu tập", selected: collection == nil) { collection = nil }
                        .accessibilityIdentifier("searchCollection_all")
                } else {
                    let value = store.collections[index - 1]
                    NotedPill(title: value.name, selected: collection == value.id) { collection = value.id }
                        .accessibilityIdentifier("searchCollection_" + value.id.uuidString)
                }
            }
            if kind != "all" || period != "all" || collection != nil {
                Button("Xóa bộ lọc") { kind = "all"; period = "all"; collection = nil }
                    .buttonStyle(NotedButtonStyle(role: .quiet))
                    .accessibilityIdentifier("searchClearFilters")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("searchFilters")
    }
}
