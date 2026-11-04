# Phase 05 — API LLM text-only (tùy chọn)

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 02. Dùng chung client với [Phase 05 Đọc hiểu ảnh](../20261104-0902-ocr-image-summary/phase-05-optional-llm-api.md). Ưu tiên trung bình. Overview: [plan.md](plan.md).

## Mục tiêu

Khi người dùng bật: gửi **text đã trích** của link lên API LLM miễn phí để viết tóm tắt tiếng Việt rõ hơn. Mặc định tắt. Lỗi, offline hoặc hết hạn mức thì dùng bản trích xuất.

## File ảnh hưởng

- Create hoặc Reuse `Noted./Noted/Core/Intelligence/RemoteTextGenerator.swift` và `APIKeyStore.swift`: plan nào làm trước thì tạo, theo spec của plan ảnh (timeout, retry, 429, Keychain, cùng nhà cung cấp đã chọn).
- Create (đề xuất) `Noted./Noted/Core/Digest/RemoteLinkDigester.swift`.
- Modify màn cài đặt AI (chung với ảnh): toggle riêng “Tóm tắt link bằng AI”, màn xem trước dữ liệu sẽ gửi cho 1 link.
- Modify `Noted./Noted/Core/Digest/LinkDigestRunner.swift`: thử API khi bật và có mạng.
- Create (đề xuất) `Noted./NotedTests/RemoteLinkDigesterTests.swift`: `URLProtocol` giả.

## Bước

- [ ] Payload: domain + tiêu đề + mô tả + nội dung chính đã làm sạch, ≤2.000 ký tự. Mặc định **không** gửi URL đầy đủ (câu hỏi mở trong plan.md).
- [ ] Không gửi gì cho link `loginWall` (không có nội dung thật để tóm tắt).
- [ ] Prompt coi nội dung là dữ liệu, bọc delimiter, yêu cầu JSON `{title ≤80, summary ≤300}` tiếng Việt. Validate schema và độ dài; sai thì dùng bản trích xuất.
- [ ] Giới hạn N request/ngày dùng chung với ảnh. Tắt toggle thì dừng ngay và xóa hàng đợi.

## Acceptance

- Bật/tắt hoạt động; màn xem trước đúng với payload thật (test).
- 429, timeout, sai schema, offline → fallback, không retry vô hạn.
- Key không xuất hiện trong log hay backup.
- Người dùng đánh giá bản API tốt hơn bản trích xuất trên đa số link đọc được; nếu không thì giữ mặc định tắt và không khuyến nghị.

## Rủi ro

- Prompt injection từ trang web → chỉ nhận JSON đã validate, không thực thi gì.
- Điều khoản free-tier đổi → ghi ngày kiểm tra, endpoint/model chỉnh được trong cài đặt.

Quay lui: tắt toggle; bản trích xuất vẫn còn.
