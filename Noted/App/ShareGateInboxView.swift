#if DEBUG
import SwiftUI
import ImageIO

struct ShareGateInboxView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var payloads: [ShareGatePayload] = []
    @State private var error: String?
    @State private var groupAvailable = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Lưu nhanh. Giữ trên iPhone.", systemImage: "tray.full")
                        .font(.headline).padding(.vertical, 8)
                    Text("Bước kiểm chứng Share Extension. Thư viện đầy đủ sẽ được xây sau khi xác minh lưu trên máy thật.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let error {
                    Section("Chưa đọc được dữ liệu") { Text(error).foregroundStyle(NotedDesign.Palette.error) }
                }
                if payloads.isEmpty && error == nil {
                    ContentUnavailableView("Chưa có nội dung", systemImage: "square.and.arrow.down",
                                           description: Text("Trong Safari hoặc Photos, chọn Share → Noted. → Lưu. Sau đó quay lại đây."))
                }
                ForEach(payloads) { payload in
                    Section {
                        if !payload.caption.isEmpty { Text(payload.caption) }
                        ForEach(payload.entries) { entry in
                            switch entry.kind {
                            case .text: Text(entry.value).textSelection(.enabled)
                            case .link:
                                if let url = URL(string: entry.value) {
                                    Link(destination: url) { Label(entry.value, systemImage: "link") }
                                }
                            case .image:
                                if let url = try? ShareGateStore.configured().imageURL(payload: payload.id, name: entry.value) {
                                    LocalGateImage(url: url).frame(maxHeight: 240)
                                }
                            }
                        }
                    } header: { Text(payload.createdAt, style: .date) }
                }
                Section("Trạng thái") {
                    Label(groupAvailable ? "Đọc được vùng lưu chung" : "Chưa xác minh vùng lưu chung",
                          systemImage: groupAvailable ? "checkmark.shield" : "exclamationmark.shield")
                    Text("Nội dung chưa được tự động đồng bộ hoặc backup. Không gỡ app nếu cần giữ dữ liệu.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NotedDesign.Palette.paper)
            .navigationTitle("Noted.")
            .toolbar { Button("Làm mới", systemImage: "arrow.clockwise") { refresh() } }
            .refreshable { refresh() }
            .task { refresh() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        }
        .tint(NotedDesign.Palette.brand)
    }

    private func refresh() {
        do {
            let store = try ShareGateStore.configured()
            payloads = try store.readAll()
            groupAvailable = true
            error = nil
        } catch {
            groupAvailable = false
            self.error = error.localizedDescription
        }
    }
}

private struct LocalGateImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        // A concrete container keeps the task identity stable when loading becomes an image.
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Ảnh đã lưu") }
            else if failed { Label("Không đọc được ảnh gốc. File vẫn được giữ.", systemImage: "exclamationmark.triangle") }
            else { ProgressView("Đang đọc ảnh…") }
        }
        .task(id: url) {
            image = nil
            failed = false
            let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 1000
                      ] as CFDictionary) else { return nil }
                return UIImage(cgImage: cgImage)
            }.value
            guard !Task.isCancelled else { return }
            image = loaded
            failed = loaded == nil
        }
    }
}

#endif
