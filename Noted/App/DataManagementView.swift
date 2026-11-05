import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DataManagementView: View {
    let store: LibraryStore
    var initialImportURL: URL? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var busyMessage = "Đang xử lý dữ liệu…"
    @State private var message: String?
    @State private var export: BackupExport?
    @State private var showImport = false
    @State private var handledImportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: NotedDesign.Spacing.xs) {
                        Text("Giữ một bản dữ liệu của bạn")
                            .font(NotedDesign.TypeStyle.title)
                            .foregroundStyle(NotedDesign.Palette.primaryText)
                        Text("Xuất ra Files và chọn nơi lưu bạn tin cậy. Bạn có thể nhập bản backup này khi cần.")
                            .font(.subheadline)
                            .foregroundStyle(NotedDesign.Palette.secondaryText)
                    }
                    .padding(.vertical, NotedDesign.Spacing.sm)
                }
                Section("Dữ liệu trên iPhone") {
                    LabeledContent("Mục đã lưu", value: "\(store.items.count)")
                    LabeledContent("Bộ sưu tập", value: "\(store.collections.count)")
                    LabeledContent("Ảnh gốc", value: ByteCountFormatter.string(fromByteCount: store.items.flatMap(\.attachments).reduce(0) { $0 + $1.size }, countStyle: .file))
                }
                Section {
                    NavigationLink("AI tùy chọn") { RemoteAISettingsView(store: store) }
                }
                #if DEBUG
                Section {
                    NavigationLink("Gán nhãn chủ đề") { IntelligenceLabelingView(store: store) }
                        .accessibilityIdentifier("intelligenceLabeling")
                } header: {
                    Text("Đánh giá AI · DEBUG")
                } footer: {
                    Text("Nhãn đánh giá lưu riêng trên máy, không thay đổi Thư viện.")
                }
                #endif
                Section {
                    Button { Task { await makeExport() } } label: {
                        Label("Xuất backup", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(NotedButtonStyle(role: .primary))
                        .accessibilityIdentifier("backupExport")
                    Button { showImport = true } label: {
                        Label("Nhập backup", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(NotedButtonStyle(role: .soft))
                        .accessibilityIdentifier("backupImport")
                } footer: {
                    Text("Backup gồm ghi chú, link, ảnh gốc, collections, tag và thùng rác. File chưa mã hóa; hãy chọn nơi lưu phù hợp. Nhập sẽ hợp nhất và giữ cả hai bản khi nội dung xung đột.")
                }
                if FileManager.default.fileExists(atPath: store.root.appendingPathComponent("backup-import-journal.json").path) {
                    Section {
                        Label("Lần nhập trước chưa hoàn tất. Chọn lại cùng backup để tiếp tục; nội dung hiện có được giữ nguyên.", systemImage: "exclamationmark.circle")
                            .foregroundStyle(NotedDesign.Palette.error)
                    }
                }
                if let message {
                    Section("Kết quả") {
                        HStack(alignment: .top, spacing: NotedDesign.Spacing.sm) {
                            Image(systemName: resultSymbol(for: message))
                                .foregroundStyle(resultColor(for: message))
                            Text(message)
                                .foregroundStyle(NotedDesign.Palette.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("backupResult")
                        }
                        .padding(.vertical, NotedDesign.Spacing.xs)
                        .accessibilityElement(children: .contain)
                    }
                }
                Section {
                    Text("Nội dung đến sau thời điểm snapshot vẫn ở hàng đợi và sẽ có trong lần backup tiếp theo. Không gỡ app khi chưa có backup đã kiểm chứng.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("Dữ liệu & backup")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: initialImportURL) {
                guard let url = initialImportURL, handledImportURL != url else { return }
                handledImportURL = url
                await importBackup(url)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() }.buttonStyle(NotedButtonStyle(role: .soft)).fixedSize().disabled(busy) }.notedOwnBackground() }
            .operationLoading(busy, message: busyMessage)
            .interactiveDismissDisabled(busy)
            .sheet(item: $export) { output in
                BackupExportPicker(url: output.url) { saved in
                    message = saved ? "Đã xuất \(output.itemCount) mục • \(output.url.lastPathComponent)\nSnapshot: \(output.cutoff.formatted()). \(output.pendingCount) lượt lưu cần kiểm tra riêng."
                                    : "Đã hủy chọn nơi lưu. Chưa xác nhận backup được lưu ra Files."
                    export = nil
                    try? FileManager.default.removeItem(at: output.url.deletingLastPathComponent())
                }
            }
            .sheet(isPresented: $showImport) {
                BackupImportPicker { url in
                    showImport = false
                    if let url { Task { await importBackup(url) } }
                }
            }
        }
    }

    private func makeExport() async {
        guard !busy else { return }
        busyMessage = "Đang tạo backup…"
        busy = true; message = nil
        defer { busy = false }
        await Task.yield()
        do { export = try await BackupService().export(store: store) }
        catch { message = userMessage(for: error) }
    }

    private func importBackup(_ url: URL) async {
        guard !busy else { return }
        busyMessage = "Đang kiểm tra và nhập backup…"
        busy = true; message = nil
        defer { busy = false }
        await Task.yield()
        do {
            let result = try await BackupService().importPackage(at: url, into: store)
            message = "Đã nhập \(result.inserted) mục; bỏ qua \(result.skipped) mục đã có; giữ \(result.conflicts) bản xung đột."
        } catch { message = userMessage(for: error) }
    }

    private func userMessage(for error: Error) -> String {
        if let error = error as? BackupError { return error.localizedDescription }
        return "Không thể hoàn tất tác vụ. Dữ liệu hiện có được giữ nguyên. Hãy kiểm tra dung lượng trống và quyền truy cập backup, rồi thử lại."
    }

    private func resultSymbol(for message: String) -> String {
        if message.hasPrefix("Đã xuất ") || message.hasPrefix("Đã nhập ") { return "checkmark.circle.fill" }
        if message.hasPrefix("Đã hủy ") { return "info.circle.fill" }
        return "exclamationmark.circle.fill"
    }

    private func resultColor(for message: String) -> Color {
        if message.hasPrefix("Đã xuất ") || message.hasPrefix("Đã nhập ") { return NotedDesign.Palette.brand }
        if message.hasPrefix("Đã hủy ") { return NotedDesign.Palette.secondaryText }
        return NotedDesign.Palette.error
    }
}

private struct BackupExportPicker: UIViewControllerRepresentable {
    let url: URL
    let completed: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completed: (Bool) -> Void
        init(_ completed: @escaping (Bool) -> Void) { self.completed = completed }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completed(!urls.isEmpty) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completed(false) }
    }
}

private struct BackupImportPicker: UIViewControllerRepresentable {
    let completed: (URL?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.notedBackup, .folder], asCopy: false)
        controller.allowsMultipleSelection = false
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completed: (URL?) -> Void
        init(_ completed: @escaping (URL?) -> Void) { self.completed = completed }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completed(urls.first) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completed(nil) }
    }
}
