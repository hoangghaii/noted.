# Phase 05 — API LLM text-only (tùy chọn)

Ngày 2026-11-04. Trạng thái: Implemented — kiểm chứng kỹ thuật đạt trên iPhone; chờ người dùng đánh giá chất lượng Groq thật. Review: đã tự rà diff/call path ngày 2026-11-05. Phụ thuộc Phase 02. Dùng chung client với [Phase 05 Đọc hiểu ảnh](../20261104-0902-ocr-image-summary/phase-05-optional-llm-api.md). Ưu tiên trung bình. Overview: [plan.md](plan.md).

## Mục tiêu

Khi người dùng bật: gửi **text đã trích** của link lên API LLM miễn phí để viết tóm tắt tiếng Việt rõ hơn. Mặc định tắt. Lỗi, offline hoặc hết hạn mức thì dùng bản trích xuất.

## File ảnh hưởng

- Create hoặc Reuse `Noted./Noted/Core/Intelligence/RemoteTextGenerator.swift` và `APIKeyStore.swift`: plan nào làm trước thì tạo, theo spec của plan ảnh (timeout, retry, 429, Keychain, cùng nhà cung cấp đã chọn).
- Create (đề xuất) `Noted./Noted/Core/Digest/RemoteLinkDigester.swift`.
- Modify màn cài đặt AI (chung với ảnh): toggle riêng “Tóm tắt link bằng AI”, màn xem trước dữ liệu sẽ gửi cho 1 link.
- Modify `Noted./Noted/Core/Digest/LinkDigestRunner.swift`: thử API khi bật và có mạng.
- Create (đề xuất) `Noted./NotedTests/RemoteLinkDigesterTests.swift`: `URLProtocol` giả.

## Bước

- [x] Payload: domain + tiêu đề + mô tả + nội dung chính đã làm sạch, ≤2.000 ký tự. Mặc định **không** gửi URL đầy đủ (câu hỏi mở trong plan.md).
- [x] Không gửi gì cho link `loginWall` (không có nội dung thật để tóm tắt).
- [x] Prompt coi nội dung là dữ liệu, bọc delimiter, yêu cầu JSON `{title ≤80, summary ≤300}` tiếng Việt. Validate schema và độ dài; sai thì dùng bản trích xuất.
- [x] Giới hạn N request/ngày dùng chung với ảnh. Tắt toggle thì dừng ngay và xóa hàng đợi.

## Acceptance

- [x] Bật/tắt hoạt động; màn xem trước đúng với payload thật (test).
- [x] 429, timeout, sai schema, offline → fallback, không retry vô hạn.
- [x] Key không xuất hiện trong log hay backup (kiểm chứng với khóa tổng hợp; Keychain service test riêng).
- [ ] Người dùng đánh giá bản API tốt hơn bản trích xuất trên đa số link đọc được; nếu không thì giữ mặc định tắt và không khuyến nghị.

## Rủi ro

- Prompt injection từ trang web → chỉ nhận JSON đã validate, không thực thi gì.
- Điều khoản free-tier đổi → ghi ngày kiểm tra, endpoint/model chỉnh được trong cài đặt.

Quay lui: tắt toggle; bản trích xuất vẫn còn.


## Triển khai và kiểm chứng 2026-11-05

Người dùng chọn **Groq** trong phiên. Điều khoản/model và nguồn hiện hành ghi ở [intelligence-evaluation.md](../../docs/intelligence-evaluation.md#link-phase-05--nhà-cung-cấp-api-tùy-chọn-2026-11-05). Mặc định `openai/gpt-oss-20b`; endpoint/model chỉnh được và đổi nơi gửi phải bật lại để xác nhận. Không gửi URL đầy đủ; URL HTTP(S)/www xuất hiện trong text bị loại. Bỏ qua cả loginWall lẫn titleOnly. Budget 50 request/ngày (tính retry), dùng client chung cho API ảnh ở phase sau; chưa triển khai phần API ảnh. Không cần protocol DigestGenerator khi chưa có implementation API thứ hai.

Tắt hủy ngay task và bỏ kết quả muộn; không lưu cloud queue. Khi lỗi, dùng trích xuất cùng lần đọc. Giữ text trích xuất cho embedding. Bản API đã lưu không xóa khi tắt; Chi tiết → Thử đọc lại tạo lại theo cài đặt hiện tại. Không tự gửi lại toàn bộ link cũ khi bật.

Build/type-check generic iOS đạt; 61/61 unit/integration và 1/1 UI test trên iPhone đạt. File mới vào target bằng `ruby scripts/update-project.rb`; không đổi schema. [Báo cáo, lệnh và evidence](../../docs/evidence/20261105-link-phase5/summary.md).

**Chưa đóng phase về nghiệm thu:** không có khóa Groq thật trong phiên, chưa gọi mạng thật hoặc so sánh chất lượng bản API trên đa số link. Tính năng vẫn mặc định tắt, chưa khuyến nghị bật. Các gate thủ công này được giữ mở.
