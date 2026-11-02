# Phase 04 — Lưu và luồng phụ

Ngày 2026-11-02. Ưu tiên cao. Phụ thuộc: phase 02–03. Triển khai: code, ảnh iPhone thật và ca thiết bị cho Capture, Safari/Photos Share preview, Trash và backup Files đã có trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md). Review: đã sửa preview caption Share, trạng thái hủy backup và đường thoát khi lưu thành công nhưng ghim lỗi.

## Phạm vi và file

- Modify `/Users/nhhai7/LocalData/Noted./Noted/Features/Capture/CaptureSheet.swift` — segmented note/link/ảnh, form, CTA, paste, loading, lỗi.
- Modify `/Users/nhhai7/LocalData/Noted./NotedShare/ShareViewController.swift` — áp dụng nhận diện/theme cho Share preview và save state, giữ logic preflight/payload.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/Features/Trash/TrashView.swift` — empty, restore/delete, confirm.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/App/DataManagementView.swift` — thống nhất form/action/progress/result mà không đổi backup service.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/App/ShareGateInboxView.swift` **nếu cần** — chỉ màn DEBUG fixture để màu/trạng thái không lệch.
- Reuse `/Users/nhhai7/LocalData/Noted./Shared/NotedDesign.swift` từ phase 01; không thêm dependency mạng.

## Bước triển khai

- [ ] CaptureSheet: nhãn field luôn rõ; note bắt buộc, URL http/https hợp lệ, ảnh tối đa ba ảnh như hiện tại; caption tùy chọn được gọi đúng. Nút Lưu có disabled/busy và vị trí dễ thấy khi keyboard mở; draft được giữ qua đóng/lỗi.
- [ ] Paste chọn đúng note hoặc link như hiện tại. PhotosPicker, import file tạm, giới hạn dung lượng, thông điệp offline và nội dung gốc không đổi.
- [ ] Share Extension: áp dụng icon màu/type/button/card cho preview; lỗi preflight hiện trước save, nút Lưu khóa khi unsupported/too large/busy. Không đổi provider decoding, `.partial`/`.ready`, App Group hay lời hứa về Notes payload.
- [ ] Trash: phân biệt restore với xóa vĩnh viễn; confirm có mô tả hậu quả, cancel giữ item, không đưa nút destructive vào vị trí dễ chạm nhầm. Backup: loading không biến mất giữa chừng, import/export result đọc rõ; không đổi manifest/merge.
- [ ] Thống nhất error, loading, empty của startup/import/Share/Trash/backup. Giữ tất cả `accessibilityIdentifier` dùng cho UI tests (`captureSave`, `sharePreview`, `shareSave`, `trashRestore`, `backupExport`...).

## Nghiệm thu

- Note, link, ảnh và dán nội dung lưu đúng; không lưu trùng khi chạm nhanh; lỗi giữ draft. Share Safari/Photos vẫn lưu đúng payload và preview loại/số ảnh/caption trước save trên iPhone.
- Trash restore/cancel/xóa xác nhận và backup Files roundtrip giữ hành vi cũ. Không tuyên bố pass với flow chưa chạy; không thực hiện xóa vĩnh viễn trên dữ liệu cá nhân để thử UI.
- Build app + Share Extension trên iPhoneOS; các test đang có về decoder/Share/lifecycle và UI fixture liên quan được chạy lại khi phase này hoàn tất.

Rủi ro: style mới trong extension khác kích thước sheet và che nút lưu, hoặc thay trạng thái busy. Kiểm tra Share picker thật; nếu bố cục không vừa, ưu tiên preview + nút Lưu nhìn thấy. Rollback view, không thay hàng đợi hay model.

## Bằng chứng trước nghiệm thu thiết bị

Các ghi chú thiết bị `unavailable` dưới đây là trạng thái của lượt triển khai trước Phase 05; kết quả iPhone thật mới nằm trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md).

- Đã cập nhật CaptureSheet, Share Extension, Trash, Data & backup và màu của màn DEBUG Share fixture. Build app + Share Extension bằng `xcodebuild ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` đạt `BUILD SUCCEEDED`; build lại cùng scheme bằng `build-for-testing` sau thay đổi cuối đạt `TEST BUILD SUCCEEDED`. Các target test được biên dịch, chưa thực thi.
- Review phát hiện và đã sửa preview Share thiếu caption từ text provider, và thông báo hủy xuất backup bị hiển thị như thành công. Share hiện kiểm tra sớm dung lượng ảnh, URL và text trước khi bật Lưu. Không đổi model, backup service, App Group hay hàng đợi.
- `xcrun devicectl list devices` báo iPhone 12 Pro vật lý `unavailable`; lần kiểm tra sau bị CoreDeviceService timeout. Chưa chạy lưu note/link/ảnh, Share Safari/Photos, Trash hoặc backup Files trên iPhone sau thay đổi; chưa xác nhận bố cục Share sheet, nút Lưu khi keyboard mở, chống lưu trùng, draft sau lỗi, hoặc dữ liệu cũ sau cài đè. Không tính build/test compilation là nghiệm thu những hành vi này. Các checkbox nghiệm thu ở trên giữ mở đến khi có bằng chứng thiết bị.
