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
                HStack(spacing: NotedDesign.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(NotedDesign.Palette.brand)
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
                .padding(.horizontal, NotedDesign.Spacing.base)
                .frame(minHeight: 52)
                .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
                .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.input).strokeBorder(NotedDesign.Palette.border) }
                .padding(.top, NotedDesign.Spacing.sm)

                HStack(alignment: .firstTextBaseline) {
                    Text(settledQuery.isEmpty ? "Mới lưu" : "\(results.count) kết quả")
                        .font(NotedDesign.TypeStyle.heading)
                        .foregroundStyle(NotedDesign.Palette.primaryText)
                    Spacer()
                    Text("\(results.count) mục")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(NotedDesign.Palette.secondaryText)
                    Menu {
                        Picker("Loại nội dung", selection: $kind) {
                            Text("Tất cả").tag("all")
                            Text("Ghi chú").tag("text")
                            Text("Link").tag("link")
                            Text("Ảnh").tag("image")
                        }
                        Picker("Thời gian", selection: $period) {
                            Text("Mọi lúc").tag("all")
                            Text("Hôm nay").tag("today")
                            Text("7 ngày qua").tag("week")
                        }
                        Picker("Bộ sưu tập", selection: $collection) {
                            Text("Tất cả bộ sưu tập").tag(UUID?.none)
                            ForEach(store.collections) { value in Text(value.name).tag(Optional(value.id)) }
                        }
                        Button("Xóa bộ lọc") { kind = "all"; period = "all"; collection = nil }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.subheadline)
                            .foregroundStyle(NotedDesign.Palette.brand)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Lọc")
                    .accessibilityIdentifier("searchFilters")
                }
                if kind != "all" || period != "all" || collection != nil {
                    Text("Đang lọc: \(kindTitle(kind))")
                        .font(.footnote)
                        .foregroundStyle(NotedDesign.Palette.brand)
                }
                if results.isEmpty {
                    ContentUnavailableView(
                        settledQuery.isEmpty ? "Chưa có mục phù hợp" : "Chưa tìm thấy",
                        systemImage: "magnifyingglass",
                        description: Text("Thử một từ khác hoặc bỏ bộ lọc."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, NotedDesign.Spacing.xl)
                } else {
                    LazyVStack(spacing: NotedDesign.Spacing.sm) {
                        ForEach(Array(results.prefix(limit))) { item in
                            NavigationLink { ItemDetailView(item: item, store: store) } label: {
                                HStack(spacing: NotedDesign.Spacing.md) {
                                    Image(systemName: kindSymbol(item.kind))
                                        .font(.headline)
                                        .foregroundStyle(NotedDesign.Palette.brand)
                                        .frame(width: 44, height: 44)
                                        .background(NotedDesign.Palette.brandSoft,
                                                    in: RoundedRectangle(cornerRadius: NotedDesign.Radius.thumbnail))
                                    VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                                        Text(item.displayTitle)
                                            .font(NotedDesign.TypeStyle.heading)
                                            .foregroundStyle(NotedDesign.Palette.primaryText)
                                            .lineLimit(2)
                                        Text("\(kindTitle(item.kind)) · \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(NotedDesign.Palette.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(NotedDesign.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(NotedDesign.Palette.surface,
                                            in: RoundedRectangle(cornerRadius: NotedDesign.Radius.input))
                                .overlay { RoundedRectangle(cornerRadius: NotedDesign.Radius.input).strokeBorder(NotedDesign.Palette.border) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if results.count > limit {
                        Button("Xem thêm") { limit += 50 }
                            .buttonStyle(NotedButtonStyle(role: .secondary))
                            .frame(maxWidth: .infinity)
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

    private func kindTitle(_ value: String) -> String {
        switch value {
        case "text": "Ghi chú"
        case "link": "Liên kết"
        case "image": "Ảnh"
        default: "Tất cả"
        }
    }

    private func kindSymbol(_ value: String) -> String {
        switch value {
        case "text": "note.text"
        case "link": "link"
        case "image": "photo"
        default: "square.grid.2x2"
        }
    }
}
