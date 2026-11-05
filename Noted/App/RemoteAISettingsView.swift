import SwiftUI

struct RemoteAISettingsView: View {
    let store: LibraryStore
    @State private var generator = RemoteTextGenerator.shared
    @State private var key = ""
    @State private var endpoint = ""
    @State private var model = ""
    @State private var message: String?
    @State private var confirmEnable = false

    var body: some View {
        Form {
            Section {
                Toggle("Tóm tắt link bằng AI", isOn: Binding(get: { generator.linksEnabled }, set: { value in
                    if value { confirmEnable = true } else { generator.setLinksEnabled(false) }
                }))
                .accessibilityIdentifier("remoteLinkToggle")
                Text("Mặc định tắt. Khi bật, link mới và link được đọc lại sẽ gửi text đã trích để viết tóm tắt tiếng Việt. Lỗi sẽ dùng bản trích xuất. Không gửi ảnh hoặc URL đầy đủ; URL xuất hiện trong text cũng được loại bỏ.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Đã dùng \(generator.usedToday)/\(RemoteTextGenerator.dailyLimit) lượt hôm nay. Mỗi lần thử lại cũng tính một lượt.")
                    .font(.footnote)
            }
            Section("Khóa API") {
                SecureField("Nhập khóa Groq mới", text: $key)
                    .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Lưu khóa") {
                    do {
                        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { message = "Hãy nhập khóa API."; return }
                        generator.invalidateRequests()
                        try APIKeyStore().save(key)
                        key = ""; message = "Đã lưu khóa vào Keychain trên iPhone này."
                    } catch { message = "Không lưu được khóa. Hãy mở khóa iPhone và thử lại." }
                }
                Button("Xóa khóa", role: .destructive) {
                    generator.setLinksEnabled(false)
                    do { try APIKeyStore().delete(); key = ""; message = "Đã xóa khóa và tắt AI." }
                    catch { message = "Không xóa được khóa trong Keychain." }
                }
                Text("Khóa không nằm trong backup của Noted, không đồng bộ Keychain và không hiển thị lại ở đây.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Nhà cung cấp") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Endpoint HTTPS").font(.caption).foregroundStyle(.secondary)
                    TextField("Endpoint HTTPS", text: $endpoint, axis: .vertical)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model").font(.caption).foregroundStyle(.secondary)
                    TextField("Model", text: $model).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Button("Lưu endpoint và model") {
                    do { try generator.configure(endpoint: endpoint, model: model); message = "Đã lưu. Hãy bật lại AI để xác nhận nơi gửi mới." }
                    catch { message = "Cần endpoint HTTPS không có thông tin đăng nhập, query hoặc fragment và tên model hợp lệ." }
                }
                Text("Mặc định Groq. Chính sách kiểm tra ngày 05/11/2026: inference không lưu nội dung theo mặc định, có ngoại lệ lưu đến 30 ngày cho sự cố/lạm dụng. Bạn có thể bật Zero Data Retention trong Groq Console. Đổi nhà cung cấp có thể thay đổi chính sách và chi phí.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Chính sách dữ liệu Groq", destination: URL(string: "https://console.groq.com/docs/your-data")!)
            }
            Section("Xem trước dữ liệu sẽ gửi") {
                let links = store.items.filter { $0.kind == "link" && $0.trashedAt == nil }
                if links.isEmpty { Text("Chưa có link để xem trước.").foregroundStyle(.secondary) }
                ForEach(links) { item in
                    NavigationLink(item.title.isEmpty ? "Link đã lưu" : item.title) { RemoteLinkPayloadView(item: item) }
                }
                Text("Xem trước chỉ tải trang, chưa gọi AI. Trong Chi tiết, chọn “Thử đọc lại” để tạo lại theo cài đặt hiện tại. Tắt AI sẽ hủy request đang chạy; các bản AI đã lưu vẫn giữ đến khi tạo lại.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let message { Section("Kết quả") { Text(message).accessibilityIdentifier("remoteSettingsResult") } }
        }
        .scrollContentBackground(.hidden).paperBackground().tint(NotedDesign.Palette.brand)
        .navigationTitle("AI tùy chọn").navigationBarTitleDisplayMode(.inline)
        .onAppear { endpoint = generator.endpoint; model = generator.model; generator.refreshUsage() }
        .onDisappear { key = "" }
        .alert("Cho phép gửi text link đến API?", isPresented: $confirmEnable) {
            Button("Bật tóm tắt link bằng AI") { generator.setLinksEnabled(true) }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Nơi gửi: \(generator.endpoint)\nModel: \(generator.model)\nGửi domain, tiêu đề, mô tả và nội dung đã làm sạch (tối đa 2.000 ký tự). Text có thể chứa thông tin riêng tư. Bạn có thể xem trước bên dưới trước khi bật.")
        }
    }
}

private struct RemoteLinkPayloadView: View {
    let item: Item
    @State private var payload: String?
    @State private var loading = true
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Chỉ dữ liệu dưới đây được đặt trong phần dữ liệu của lời nhắc AI; không kèm ID mục hoặc URL gốc. Nội dung trang có thể thay đổi ở lần đọc sau.")
                    .font(.footnote).foregroundStyle(.secondary)
                if loading { ProgressView("Đang đọc trang…") }
                else if let payload {
                    Text("\(payload.count)/2.000 ký tự").font(.caption)
                    Text(payload).textSelection(.enabled).accessibilityIdentifier("remoteLinkPayload")
                } else { Text(message) }
            }.padding()
        }
        .paperBackground().navigationTitle("Dữ liệu sẽ gửi")
        .task(id: item.originalURL) {
            loading = true; payload = nil
            do {
                guard let url = URL(string: item.originalURL) else { throw URLError(.badURL) }
                let result = try await LinkDigestRunner.fetch(url)
                guard !Task.isCancelled else { return }
                payload = result.remotePayload
                message = result.content.status == .loginWall ? "Trang yêu cầu đăng nhập. Không gửi dữ liệu đến AI." : "Không đủ nội dung thật để gửi đến AI."
            } catch { message = "Không đọc được trang để xem trước. Chưa gửi dữ liệu đến AI." }
            loading = false
        }
    }
}
