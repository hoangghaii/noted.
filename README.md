# Noted

App cá nhân chỉ dành cho iPhone, build trực tiếp bằng Xcode. Không dùng Simulator hoặc TestFlight.

## Chức năng

- Lưu ảnh, link và ghi chú qua Share Extension hoặc nút ＋ trong app.
- Thư viện trên máy, Inbox, ghim, tag, bộ sưu tập một cấp và thùng rác.
- Tìm kiếm tiếng Việt có/không dấu; nhận diện chữ trong ảnh bằng Apple Vision trên iPhone.
- Xuất/nhập package `.notedbackup` qua Files; giữ cả hai bản khi nội dung xung đột.
- Không cần tài khoản hoặc backend. AI tóm tắt link qua Groq là tùy chọn, mặc định tắt; cần khóa API riêng. Preview link có thể cần mạng; nội dung gốc được lưu trước.
- Dữ liệu & backup → AI tùy chọn: xem trước domain, tiêu đề, mô tả và nội dung text sẽ gửi (tổng tối đa 2.000 ký tự, loại URL trong text; không gửi ảnh, ID mục hoặc URL đầy đủ). Khóa lưu trong Keychain trên thiết bị, ngoài backup Noted. Giới hạn 50 request/ngày; lỗi/hết hạn mức dùng bản trích xuất. Bật áp dụng cho link mới hoặc “Thử đọc lại” trong Chi tiết; tắt hủy request và bỏ kết quả đang chạy, bản AI đã lưu giữ đến khi tạo lại. Endpoint/model đổi được và cần bật lại để xác nhận nơi gửi mới.

Đã build/cài và kiểm thử trên iPhone 12 Pro, iOS 27.0.1. Các hạng mục kiểm chứng và giới hạn còn lại được ghi riêng trong báo cáo, không đồng nhất build thành công với nghiệm thu toàn bộ.

- [Kế hoạch](plans/20261028-0948-noted-iphone/plan.md)
- [Cài và kiểm chứng trên iPhone](docs/device-setup.md)
- [Kết quả kiểm tra](docs/verification.md)

## Mở project

Mở `Noted.xcodeproj`, chọn scheme **Noted** và iPhone vật lý.
Copy `.env.example` thành `.env`, điền team ID từ tài khoản Xcode, bundle ID, App Group và metadata tài khoản/thiết bị. Chạy `python3 scripts/configure-env.py` sau mỗi lần sửa `.env` để sinh `Config/Local.xcconfig` cho Xcode. Cả hai file cá nhân đều bị Git ignore; không lưu mật khẩu, token hoặc khóa ký vào `.env`. Apple ID và UDID chỉ là metadata local, không được đưa vào app và không thay thế đăng nhập Xcode.
Không thay bundle ID/App Group hoặc gỡ app nếu đang cần giữ dữ liệu.

`scripts/generate-project.rb` chỉ phục vụ tạo project lần đầu, dùng gem `xcodeproj`; script từ chối ghi đè project có sẵn. Không cần chạy script để build project đã lưu.

## Sử dụng

Trong Safari/Photos/app khác: Share → Noted → Lưu → Xong. Mở Noted để nhập lượt lưu vào thư viện.
Trong Ghi chú trên iOS 27, chọn **Gửi bản sao (Send a Copy)** trong menu dưới tiêu đề ghi chú nếu bảng Share đang ở chế độ chia sẻ link cộng tác ([hướng dẫn Apple](https://support.apple.com/en-sg/guide/iphone/iphe4d04f674/27/ios/27)).
Trên iPhone đang kiểm chứng, **Gửi bản sao** từ Ghi chú chỉ cung cấp URL cho Noted nên tạo link mở lại Notes, không tạo bản sao nội dung offline. Muốn giữ text trong Noted, chọn Sao chép văn bản rồi vào Noted → ＋ → Dán nội dung → Lưu.
Trong app: ＋ → ghi chú, link hoặc chọn ảnh; tag và bộ sưu tập có thể thêm sau.
Tối đa 3 mục mỗi lượt, mỗi ảnh 20 MB; ảnh gốc được copy độc lập, không tự nén thay thế.

Menu trên cùng bên trái → Dữ liệu & Backup → Xuất backup. Backup chưa mã hóa, gồm cả thùng rác; chọn nơi lưu phù hợp và giữ một bản ngoài vùng dữ liệu của app.
Không gỡ app khi chưa có backup đã kiểm chứng. App không tự đồng bộ hoặc tự xuất backup.

## Kiểm thử

Scheme **Noted** chạy unit/integration tests dữ liệu trên iPhone. Scheme **Noted-DeviceGate** chứa các UI tests; chạy đúng test được mô tả trong báo cáo vì các locator Safari/Photos phụ thuộc giao diện iOS.
`NotedGateHost` là app nguồn nội dung tổng hợp dùng riêng cho kiểm chứng Share giữa hai app, không phải thành phần của Noted khi sử dụng thông thường.
