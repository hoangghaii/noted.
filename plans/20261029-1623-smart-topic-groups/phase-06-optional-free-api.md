# Phase 06 — (Tùy chọn) API miễn phí cho câu văn

Ngày 2026-11-03. Trạng thái: Pending, **có thể bỏ** nếu tiêu đề/tóm tắt trích xuất ở Phase 04 đã đủ. Phụ thuộc Phase 04. Ưu tiên thấp. Overview: [plan.md](plan.md).

## Mục tiêu

Khi người dùng bật: dùng LLM API miễn phí để viết lại tiêu đề/tóm tắt (đặc biệt cho ghi chú dài, ảnh có OCR lộn xộn) và đặt tên cho nhóm mới phát hiện. Ngân sách 0 đồng: hết hạn mức thì quay về trích xuất.

## Điều kiện trước khi làm

- [ ] Chọn nhà cung cấp tại thời điểm triển khai, theo điều khoản **hiện hành**: có gói free không cần thẻ thanh toán; ghi rõ dữ liệu free-tier **không** dùng để huấn luyện (nếu điều khoản cho phép dùng dữ liệu để huấn luyện → loại hoặc báo người dùng quyết định); hỗ trợ tiếng Việt; trả về JSON có cấu trúc. Ghi nguồn + ngày kiểm tra vào doc.
- [ ] Người dùng xác nhận nhà cung cấp và loại dữ liệu được gửi.

## File ảnh hưởng (đề xuất)

- Create `Noted./Noted/Core/Intelligence/RemoteTextGenerator.swift` — client, timeout 15 s, retry ≤2, xử lý lỗi 429/hết hạn mức.
- Create `Noted./Noted/Core/Intelligence/APIKeyStore.swift` — Keychain. Key nạp từ `.env`/`Config/Local.xcconfig` lúc dev hoặc nhập trong Settings. Không hardcode trong binary, không log, không đưa vào backup.
- Modify `Noted./Noted/App/DataManagementView.swift` (hoặc màn cài đặt AI) — toggle mặc định tắt, xem trước dữ liệu sẽ gửi, bộ đếm lượt dùng.

## Bước

- [ ] Chỉ gửi text tối thiểu: title/body/OCR cắt ≤1.500 ký tự, domain (không gửi URL đầy đủ). **Không gửi ảnh.**
- [ ] Prompt coi nội dung là dữ liệu: bọc trong delimiter, yêu cầu JSON `{title, summary}`. Validate schema + độ dài; sai → bỏ, dùng bản trích xuất.
- [ ] Giới hạn ở phía client: N request/ngày (cấu hình được), xếp hàng chạy khi online, không chặn capture. Offline → giữ bản trích xuất.
- [ ] Kết quả ghi `GeneratedText` với `source = api`. Tuân thủ quy tắc tiêu đề trống/`userEditedTitle` như Phase 04.
- [ ] Không bao giờ tự chuyển từ local sang cloud. Tắt toggle → dừng ngay, xóa hàng đợi.

## Acceptance

- Bật/tắt hoạt động; màn xem trước cho thấy đúng dữ liệu sẽ gửi.
- 429/timeout/sai schema → fallback, không retry vô hạn.
- Key không xuất hiện trong log/backup (grep bản export).
- Chất lượng tiêu đề được người dùng đánh giá tốt hơn bản trích xuất trên ≥20 mục mẫu. Nếu không tốt hơn → bỏ phase.

Quay lui: tắt toggle, xóa key khỏi Keychain. Bản trích xuất vẫn còn.
