#if DEBUG
import SwiftUI
import UIKit
import Photos

/// Debug-only fixtures. Never reads or deletes the person's photo library or saved payloads.
struct DeviceGateFixturesView: View {
    let onInbox: () -> Void
    @State private var activity: GateActivity?
    @State private var photoStatus = ""

    private var runID: String { ProcessInfo.processInfo.environment["NOTED_GATE_RUN_ID"] ?? "manual" }
    private var text: String { "NOTED DEVICE GATE TEXT " + runID + " — Cà phê Đà Nẵng" }
    private var imageCaption: String { "NOTED DEVICE GATE IMAGE " + runID }
    private var fixtureURL: URL {
        var components = URLComponents(string: "https://example.com/")!
        components.queryItems = [URLQueryItem(name: "noted-gate", value: runID)]
        return components.url!
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Fixture kiểm chứng máy thật") {
                    Text("Chỉ tạo nội dung thử. Không đọc hoặc xóa ảnh cá nhân.")
                    Button("Share văn bản") { activity = GateActivity(items: [text]) }
                        .accessibilityIdentifier("gateShareText")
                    Button("Share URL") { activity = GateActivity(items: [fixtureURL]) }
                        .accessibilityIdentifier("gateShareURL")
                    Button("Share ảnh PNG") {
                        do {
                            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NotedGateFixtures", isDirectory: true)
                            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                            let url = directory.appendingPathComponent("noted-gate.png")
                            guard let data = Self.fixtureImage().pngData() else { return }
                            try data.write(to: url, options: .atomic)
                            activity = GateActivity(items: [url, imageCaption])
                        } catch { photoStatus = error.localizedDescription }
                    }
                    .accessibilityIdentifier("gateShareImage")
                    Button("Tạo ảnh thử trong Noted.") {
                        do {
                            let store = try ShareGateStore.configured()
                            var payload = ShareGatePayload()
                            let directory = try store.begin(id: payload.id)
                            let name = "fixture.png"
                            guard let data = Self.fixtureImage().pngData() else { return }
                            try data.write(to: directory.appendingPathComponent(name))
                            payload.caption = imageCaption
                            payload.entries = [.init(kind: .image, value: name)]
                            try store.publish(payload, directory: directory)
                            photoStatus = "Đã tạo ảnh thử trong vùng chung."
                        } catch { photoStatus = error.localizedDescription }
                    }.accessibilityIdentifier("gateSeedImage")
                    Button("Mở URL mẫu trong trình duyệt mặc định") { UIApplication.shared.open(fixtureURL) }
                        .accessibilityIdentifier("gateOpenBrowser")
                    Button("Thêm ảnh mẫu vào Photos") { Task { await addFixtureToPhotos() } }
                        .accessibilityIdentifier("gateAddPhoto")
                    if !photoStatus.isEmpty { Text(photoStatus).accessibilityIdentifier("gatePhotoStatus") }
                }
                Section {
                    Button("Xem nội dung đã nhận", action: onInbox)
                        .accessibilityIdentifier("gateShowInbox")
                }
            }
            .navigationTitle("Device Gate")
            .sheet(item: $activity) { activity in GateActivityController(items: activity.items) }
        }
    }

    private func addFixtureToPhotos() async {
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil else {
            photoStatus = "Chưa cấu hình quyền thêm ảnh; không truy cập Photos."
            return
        }
        let permission = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard permission == .authorized || permission == .limited else {
            photoStatus = "Chưa được cho phép thêm ảnh mẫu."
            return
        }
        do {
            let image = Self.fixtureImage()
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            photoStatus = "Đã thêm ảnh mẫu NOTED DEVICE GATE vào Photos."
        } catch { photoStatus = error.localizedDescription }
    }

    private static func fixtureImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            ("NOTED DEVICE GATE\nSynthetic test image\nCà phê Đà Nẵng" as NSString).draw(
                in: CGRect(x: 40, y: 160, width: 560, height: 200),
                withAttributes: [.font: UIFont.systemFont(ofSize: 32, weight: .bold), .foregroundColor: UIColor.white]
            )
        }
    }
}

private struct GateActivity: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct GateActivityController: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
