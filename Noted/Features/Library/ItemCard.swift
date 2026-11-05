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

/// Shared rows keep both paper cards at the height of the tallest card.
struct ItemCardGrid: View {
    let items: [Item]
    let store: LibraryStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var error: String?

    private var columns: Int { typeSize.isAccessibilitySize ? 1 : 2 }

    var body: some View {
        LazyVStack(spacing: 14) { // v3 row gap 13.3 pt; column gap stays 12 (L30)
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(items[start..<min(start + columns, items.count)])) { item in
                        NavigationLink { ItemDetailView(item: item, store: store) } label: {
                            ItemCard(item: item, store: store)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("item_" + item.id.uuidString)
                        .overlay(alignment: .topTrailing) {
                            Menu {
                                Button(item.pinned ? "Bỏ ghim" : "Ghim", systemImage: "pin") {
                                    do { try store.togglePin(item) } catch { self.error = error.localizedDescription }
                                }
                                Button("Chuyển vào Thùng rác", systemImage: "trash", role: .destructive) {
                                    do { try store.trash(item) } catch { self.error = error.localizedDescription }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline) // v3 glyph ≈13.7 pt wide
                                    .foregroundStyle(item.kind == "image" ? .white : NotedDesign.tone(for: item.id, kind: item.kind).foreground)
                                    .shadow(color: item.kind == "image" ? .black.opacity(0.7) : .clear, radius: 2)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Tùy chọn nội dung")
                            .accessibilityIdentifier("itemMenu_" + item.id.uuidString)
                        }
                    }
                    if columns == 2 && start + 1 == items.count {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alert("Chưa hoàn tất", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Đóng", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct ItemCard: View {
    @Environment(\.linkDigestRunner) private var digestRunner
    @Environment(\.dynamicTypeSize) private var typeSize
    private var digest: LinkDigest? { digestRunner?.digest(for: item) }
    let item: Item
    let store: LibraryStore

    private var tone: NotedDesign.PaperTone { NotedDesign.tone(for: item.id, kind: item.kind) }
    private var sketch: NotedDesign.Sketch {
        item.kind == "image" ? .photo : item.kind == "link" ? .link : .note
    }
    private var excerpt: String {
        String(item.body.prefix(400)).components(separatedBy: .newlines).map { line in
            line.hasPrefix("- ") ? "• " + line.dropFirst(2) : line
        }.joined(separator: "\n")
    }
    private var dateLabel: String {
        let parts = Calendar(identifier: .gregorian).dateComponents([.day, .month, .year], from: item.createdAt)
        return "\(parts.day ?? 1) thg \(parts.month ?? 1), \(parts.year ?? 2024)"
    }

    var body: some View {
        PaperCard(tone: tone, curl: NotedDesign.curls(for: item.id, kind: item.kind)) {
            VStack(alignment: .leading, spacing: 0) {
                if item.kind == "image" {
                    ZStack(alignment: .topLeading) {
                        Group {
                            if let attachment = item.attachments.first {
                                StoredImageView(url: store.attachmentURL(attachment), contentMode: .fill)
                            } else {
                                NotedDesign.Palette.brandSoft
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 120).clipped()
                        sketch.image.resizable().scaledToFit().frame(width: 22, height: 22)
                            .foregroundStyle(.white).shadow(color: .black.opacity(0.7), radius: 2).padding(12)
                    }
                } else {
                    // v3: icon 14 pt from the top, title starts ~46 pt down.
                    sketch.image.resizable().scaledToFit().frame(width: 24, height: 24)
                        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 9) // v3 link card icon at +14.7 pt
                }
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.displayTitle)
                            .scaledFont(item.kind == "image" ? 11.5 : 15.5, weight: .semibold, relativeTo: item.kind == "image" ? .caption2 : .subheadline) // v3 photo title ≈11.5 pt (measured)
                            .lineLimit(2)
                        if item.kind != "image", !excerpt.isEmpty {
                            // v3 fits ~26 characters per line in a half-width card.
                            Text(excerpt).scaledFont(12.5, relativeTo: .footnote).lineSpacing(1.8) // v3 line pitch ≈16.8 pt
                                .foregroundStyle(tone.secondaryForeground)
                                .lineLimit(item.kind == "link" ? 3 : 5)
                        }
                        if item.kind == "link", let digest {
                            if let summary = digest.visibleSummary {
                                if !digest.byline.isEmpty {
                                    Text(digest.byline).font(.caption).foregroundStyle(tone.secondaryForeground)
                                }
                                Text(summary).scaledFont(12.5, relativeTo: .footnote)
                                    .foregroundStyle(tone.secondaryForeground)
                                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                    .accessibilityIdentifier("cardLinkSummary_" + item.id.uuidString)
                            } else if digest.state == .loginWall {
                                Text("Không đọc được nội dung (cần đăng nhập)")
                                    .font(.footnote).foregroundStyle(tone.secondaryForeground)
                            }
                        }
                        if item.kind == "link" {
                            // v3 puts the external-link mark after the domain.
                            HStack(spacing: 6) {
                                Text(URL(string: item.originalURL)?.host ?? item.originalURL).lineLimit(1)
                                Image(systemName: "arrow.up.right.square").accessibilityHidden(true)
                            }
                            .font(.caption).foregroundStyle(tone.secondaryForeground)
                        }
                    }
                    Spacer(minLength: 0)
                    // v3: ~10 pt from the last text line to the date, ~8 pt below it (measured).
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateLabel)
                        if item.pinned { Label("Đã ghim", systemImage: "pin.fill") }
                    }
                    .font(.caption2).foregroundStyle(tone.secondaryForeground) // v3 date ≈11 pt (ink 70.3 pt wide)
                    .padding(.top, item.kind == "image" ? 4 : 10) // v3 photo card: date 9 pt under the title
                }
                .padding(.leading, 12).padding(.trailing, 8).padding(.bottom, 8)
                .padding(.top, item.kind == "image" ? 7 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, minHeight: 174, maxHeight: .infinity, alignment: .topLeading) // v3 row 2: 174 pt
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: NotedDesign.Radius.card))
    }
}
