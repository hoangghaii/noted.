import SwiftUI
import UIKit

/// A separate, disposable source app for physical-device Share checks.
/// It has no App Group, library access or dependency on Noted's implementation.
@main
struct GateHostApp: App {
    var body: some Scene { WindowGroup { GateHostView() } }
}

private struct GateHostView: View {
    @State private var activity: GateHostActivity?
    @State private var error: String?
    private var runID: String { ProcessInfo.processInfo.environment["NOTED_GATE_RUN_ID"] ?? "manual" }

    var body: some View {
        NavigationStack {
            List {
                Text("Nguồn Share độc lập. Chỉ dùng nội dung mẫu, không đọc dữ liệu cá nhân.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Share văn bản mẫu") {
                    activity = .init(items: ["NOTED EXTERNAL TEXT " + runID + " — Cà phê Đà Nẵng"])
                }.accessibilityIdentifier("externalShareText")
                Button("Share URL mẫu") {
                    var components = URLComponents(string: "https://example.com/")!
                    components.queryItems = [.init(name: "noted-external", value: runID)]
                    activity = .init(items: [components.url!])
                }.accessibilityIdentifier("externalShareURL")
                Button("Share PNG mẫu") {
                    do {
                        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NotedExternalFixtures", isDirectory: true)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let url = directory.appendingPathComponent("noted-external.png")
                        let image = UIGraphicsImageRenderer(size: .init(width: 640, height: 480)).image { context in
                            UIColor.systemIndigo.setFill()
                            context.fill(.init(x: 0, y: 0, width: 640, height: 480))
                            ("NOTED EXTERNAL IMAGE\n" + runID + "\nCà phê Đà Nẵng" as NSString).draw(
                                in: .init(x: 32, y: 130, width: 576, height: 240),
                                withAttributes: [.font: UIFont.systemFont(ofSize: 32, weight: .bold), .foregroundColor: UIColor.white])
                        }
                        guard let png = image.pngData() else { return }
                        try png.write(to: url, options: .atomic)
                        activity = .init(items: [url, "NOTED EXTERNAL IMAGE " + runID])
                    } catch { self.error = error.localizedDescription }
                }.accessibilityIdentifier("externalShareImage")
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Noted Share Check")
            .sheet(item: $activity) { GateHostActivityController(items: $0.items) }
        }
    }
}

private struct GateHostActivity: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct GateHostActivityController: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
