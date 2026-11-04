# Phase 03 — Tóm tắt trích xuất theo loại ảnh

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 02. Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

`ExtractiveDigester`: offline, không dùng model ngoài, tạo `title`, `summary` và `facts` theo từng loại ảnh. Chỉ dùng câu và chuỗi có sẵn trong ảnh, không bịa nội dung.

## File ảnh hưởng

- Create (đề xuất) `Noted./Noted/Core/Digest/DigestGenerator.swift`: protocol `generate(blocks:kind:) async throws -> DigestContent`.
- Create (đề xuất) `Noted./Noted/Core/Digest/ExtractiveDigester.swift`.
- Create (đề xuất) `Noted./Noted/Core/Digest/FactExtractor.swift`: dùng `NSDataDetector` (ngày, link, số điện thoại, địa chỉ) và regex cho số tiền/lương (`15–20 triệu`, `$1,500`, `15tr`) và email.
- Modify `Noted./Noted/Core/Digest/DigestRunner.swift`: thay generator tạm bằng bản thật, tăng `engineVersion`.
- Create (đề xuất) `Noted./NotedTests/ExtractiveDigestTests.swift`: fixture text tổng hợp cho từng loại.

## Luật theo loại

- **article**:
  - title = khối tiêu đề, nếu không có thì câu đầu ≤80 ký tự;
  - summary = 2–3 câu có điểm cao nhất, ≤240 ký tự, giữ thứ tự xuất hiện;
  - điểm câu = tần suất từ (đã bỏ stopword vi/en) + thưởng vị trí cho đoạn đầu;
  - facts = link, ngày.
- **jobPosting**:
  - title = vị trí, kèm "· công ty" nếu tìm được;
  - summary là 1 dòng ghép từ các trường đã tìm được, ví dụ `Lương 15–20 tr · Hà Nội · 2 năm kinh nghiệm · Hạn 30/11`;
  - facts = lương, địa điểm, kinh nghiệm, hạn nộp, email/điện thoại/link apply;
  - trường nào không tìm được thì bỏ, không đoán.
- **chat**:
  - title = "Đoạn chat" + tên người nếu có khối tên ở đầu màn;
  - summary = số tin nhắn + 2 tin nhắn dài nhất hoặc cuối cùng, cắt ≤240 ký tự;
  - facts = ngày giờ hẹn, địa điểm, số điện thoại, link, số tiền;
  - ghi rõ trong code: chat dùng bản trích xuất thì chỉ ở mức "xem nhanh", còn tóm tắt thật cần Phase 05.
- **other**: như article nhưng chỉ 1–2 câu.

## Bước

- [ ] Viết `FactExtractor` và test các mẫu tiếng Việt: ngày `30/11`, `30-11-2026`, `thứ 6`; lương `15-20 triệu`, `upto 2000$`; số điện thoại `09xx xxx xxx`.
- [ ] Viết các luật trên. Mọi chuỗi đầu ra phải là chuỗi con của text đã làm sạch (test bất biến này), riêng dòng ghép của jobPosting chỉ thêm nhãn trường.
- [ ] Danh sách stopword vi/en nhỏ, đặt trong code. Không thêm dependency.
- [ ] Chạy lại digest cho 27 ảnh. Người dùng chấm từng ảnh trên màn DEBUG của Phase 01: **đúng ý / tạm / sai**, tách theo loại.

## Acceptance

- Unit test xanh, kể cả bất biến "không bịa chuỗi".
- Trên 27 ảnh thật (mục tiêu đề xuất):
  - bài viết + tin tuyển dụng: ≥70% đúng ý hoặc tạm;
  - tin tuyển dụng: lương và hạn nộp, nếu có trong ảnh, được trích đúng ≥80%.
  Chat được ghi nhận riêng, không tính vào gate.
- Thời gian generate ≤50 ms mỗi ảnh, chưa tính OCR.

## Rủi ro

- OCR mất dấu làm hỏng từ khóa → so khớp trên chuỗi đã bỏ dấu (`Item.normalize`).
- Chat trích xuất kém → chấp nhận, đó là lý do có Phase 05.

Quay lui: hạ `engineVersion` về generator tạm. Digest được rebuild.
