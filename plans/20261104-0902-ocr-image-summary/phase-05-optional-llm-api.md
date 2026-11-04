# Phase 05 — API LLM text-only (tùy chọn)

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 03; màn cài đặt dùng UI của Phase 04. Ưu tiên trung bình. Overview: [plan.md](plan.md).

## Mục tiêu

Khi người dùng bật: gửi **text OCR đã làm sạch** lên LLM API miễn phí để viết lại tiêu đề và tóm tắt bằng tiếng Việt. Đặc biệt hữu ích cho ảnh chat. Không bao giờ gửi ảnh. Hết hạn mức, offline hoặc lỗi thì dùng bản trích xuất.

## Điều kiện trước khi làm

- [ ] Chọn nhà cung cấp theo điều khoản **hiện hành**:
  - có gói free không cần thẻ thanh toán;
  - dữ liệu free-tier **không** dùng để huấn luyện (nếu có dùng thì loại, hoặc báo người dùng quyết định);
  - hỗ trợ tiếng Việt;
  - trả JSON có cấu trúc.
  Ghi nguồn và ngày kiểm tra vào `docs/intelligence-evaluation.md`.
- [ ] Người dùng xác nhận nhà cung cấp.

## File ảnh hưởng

- Create (đề xuất) `Noted./Noted/Core/Intelligence/RemoteTextGenerator.swift`: client chung, không gắn với ảnh, để Phase 06 của [plan Lớp AI](../20261029-1623-smart-topic-groups/phase-06-optional-free-api.md) dùng lại. Timeout 15 s, retry ≤2, xử lý 429 và hết hạn mức.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/APIKeyStore.swift`: lưu key trong Keychain, nhập trong màn cài đặt. Không hardcode, không log, không đưa vào backup.
- Create (đề xuất) `Noted./Noted/Core/Digest/RemoteDigester.swift`: triển khai `DigestGenerator` bằng `RemoteTextGenerator`.
- Modify `Noted./Noted/App/DataManagementView.swift` (hoặc màn cài đặt AI): toggle mặc định tắt, ô nhập key, màn xem trước dữ liệu sẽ gửi cho 1 ảnh, bộ đếm lượt dùng/ngày.
- Modify `Noted./Noted/Core/Digest/DigestRunner.swift`: khi toggle bật và có mạng thì thử `RemoteDigester` trước, lỗi thì dùng `ExtractiveDigester`.
- Modify `Noted./README.md`: thay câu "không cần dịch vụ AI bên ngoài" bằng mô tả tính năng tùy chọn và dữ liệu được gửi.
- Create (đề xuất) `Noted./NotedTests/RemoteDigesterTests.swift`: dùng `URLProtocol` giả, không gọi mạng thật.

## Bước

- [ ] Payload chỉ gồm `kind` và text đã làm sạch, cắt ≤2.000 ký tự. Không gửi tên file, URL, ID, metadata ảnh.
- [ ] Prompt coi nội dung là dữ liệu: bọc trong delimiter, yêu cầu JSON `{title ≤80, summary ≤300, facts[]}` bằng tiếng Việt. Riêng chat yêu cầu tóm tắt "ai nói gì, chốt gì".
- [ ] Validate schema và độ dài. Sai schema thì bỏ, dùng bản trích xuất, ghi `source = extractive`.
- [ ] Facts từ API chỉ được giữ nếu chuỗi giá trị có trong text OCR, để tránh dữ kiện bịa.
- [ ] Giới hạn ở client: N request/ngày (mặc định 50), hàng đợi chạy khi có mạng, không chặn capture.
- [ ] Không tự chuyển từ local sang cloud. Tắt toggle thì dừng ngay, xóa hàng đợi; digest API đã có vẫn giữ, "Tạo lại" sẽ quay về bản trích xuất.
- [ ] Người dùng so sánh bản API với bản trích xuất trên 27 ảnh.

## Acceptance

- Bật/tắt hoạt động; màn xem trước hiện đúng text sẽ gửi.
- 429, timeout, sai schema, offline → fallback, không retry vô hạn (unit test với `URLProtocol` giả).
- Key không xuất hiện trong log hay file backup (grep bản export).
- Người dùng đánh giá bản API tốt hơn bản trích xuất trên đa số ảnh chat và bài viết. Nếu không tốt hơn thì giữ tính năng nhưng không khuyến nghị bật, hoặc bỏ phase.

## Rủi ro

- Riêng tư: chat có thể chứa thông tin của người khác → màn xem trước và cảnh báo khi bật lần đầu. Mặc định tắt.
- Điều khoản free-tier đổi → ghi ngày kiểm tra, cho đổi endpoint/model trong cài đặt mà không cần build lại.
- Prompt injection từ nội dung ảnh → chỉ nhận JSON đã validate, không thực thi gì từ kết quả trả về.

Quay lui: tắt toggle, xóa key khỏi Keychain. Bản trích xuất vẫn còn.
