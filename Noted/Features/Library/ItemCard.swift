import SwiftUI

struct StoredImageView: View {
    let url: URL
    var maximumPixels = 800
    var contentMode: ContentMode = .fit
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                    .accessibilityLabel("Ảnh đã lưu")
            } else if failed {
                Label("Không đọc được ảnh. Bản gốc vẫn được giữ.", systemImage: "photo.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary).padding()
            } else {
                ProgressView("Đang đọc ảnh…").font(.caption).padding()
            }
        }
        .task(id: url) {
            image = nil
            failed = false
            do {
                let loaded = try await ThumbnailService.shared.image(at: url, maxPixelSize: maximumPixels)
                guard !Task.isCancelled else { return }
                image = loaded
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
            }
        }
    }
}

struct ItemCard: View {
    let item: Item
    let store: LibraryStore

    private var title: String {
        item.displayTitle
    }

    private var kindLabel: String {
        switch item.kind {
        case "image": "ẢNH"
        case "link": "LIÊN KẾT"
        default: "GHI CHÚ"
        }
    }

    private var kindSymbol: String {
        switch item.kind {
        case "image": "photo"
        case "link": "link"
        default: "note.text"
        }
    }

    private var collectionLabel: String {
        store.collections.first(where: { $0.id == item.collectionID })?.name ?? "Inbox"
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(item.createdAt) { return "Hôm nay" }
        if Calendar.current.isDateInYesterday(item.createdAt) { return "Hôm qua" }
        return item.createdAt.formatted(.dateTime.day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
            if let attachment = item.attachments.first, item.kind == "image" {
                StoredImageView(url: store.attachmentURL(attachment), contentMode: .fill)
                    .frame(maxWidth: .infinity).frame(height: 72)
                    .background(NotedDesign.Palette.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.thumbnail))
            }
            HStack(spacing: NotedDesign.Spacing.xs) {
                Image(systemName: kindSymbol)
                Text(kindLabel)
                    .tracking(0.4)
                Spacer()
                if item.pinned {
                    Label("Đã ghim", systemImage: "pin.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(NotedDesign.Palette.brand)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NotedDesign.Palette.primaryText)
                .lineLimit(2)
            if item.kind == "text", !item.body.isEmpty {
                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(NotedDesign.Palette.secondaryText)
                    .lineLimit(1)
            } else if item.kind == "link" {
                Text(URL(string: item.originalURL)?.host ?? item.originalURL)
                    .font(.caption)
                    .foregroundStyle(NotedDesign.Palette.secondaryText)
                    .lineLimit(1)
            }
            if item.kind != "image", !item.tags.isEmpty {
                Text(item.tags.prefix(3).map { "#" + $0 }.joined(separator: " "))
                    .font(.caption2)
                    .foregroundStyle(NotedDesign.Palette.brand)
                    .lineLimit(1)
            }
            if item.kind != "image" {
                Spacer(minLength: 0)
                HStack(spacing: NotedDesign.Spacing.xs) {
                    Text(dateLabel)
                    Text("·")
                    Text(collectionLabel).lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(NotedDesign.Palette.secondaryText)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(NotedDesign.Palette.surface, in: RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: NotedDesign.Radius.card)
                .strokeBorder(NotedDesign.Palette.border)
        }
        .contentShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
    }
}
