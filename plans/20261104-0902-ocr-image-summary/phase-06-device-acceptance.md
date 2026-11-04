# Phase 06 — Nghiệm thu iPhone

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 04 và 05. Ưu tiên cao. Overview: [plan.md](plan.md).

## File ảnh hưởng

- Modify `Noted./docs/intelligence-evaluation.md`: kết quả chất lượng và tài nguyên của digest ảnh.
- Modify `Noted./docs/verification.md`: liên kết evidence mới, không sửa kết quả cũ.

## Bước

- [ ] Unit test scheme **Noted** và `DigestUITests` trên iPhone 12 Pro thật (iOS 27). Xác minh scheme chứa đúng test trước khi chạy.
- [ ] Chất lượng trên 27 ảnh thật: tỷ lệ đúng ý / tạm / sai theo loại, cho cả bản trích xuất và bản API (nếu bật). Độ chính xác của bộ phân loại và của dữ kiện tin tuyển dụng.
- [ ] Tài nguyên:
  - p95 OCR có cấu trúc + generate mỗi ảnh;
  - thời gian rebuild toàn bộ 27 ảnh;
  - peak memory;
  - capture trong lúc runner chạy vẫn mượt.
- [ ] Offline thật (chế độ máy bay), có một request mạng thất bại để xác nhận: ảnh mới vẫn có digest trích xuất; API bật nhưng offline thì fallback.
- [ ] Fault matrix:
  - `intelligence.store` hỏng hoặc bị xóa;
  - trash/xóa ảnh đang được xử lý;
  - backup đang chạy;
  - (05) 429, timeout, sai schema.
- [ ] Backup → import trên cùng máy: item và checksum giữ nguyên, digest được rebuild. Cài đè cùng bundle ID, không gỡ app.
- [ ] Người dùng tự nghiệm thu trên thư viện thật. Báo cáo ghi rõ đâu là build, đâu là unit test, UI test và đánh giá chất lượng thực.

## Acceptance

- Các gate của Phase 01, 03 và 05 có số đo thật hoặc được ghi là không đạt kèm lý do.
- Evidence không chứa nội dung ảnh, text OCR hay key.

Tiếp theo: cập nhật trạng thái trong [plan.md](plan.md) và ghi chú liên kết trong [plan Lớp AI](../20261029-1623-smart-topic-groups/plan.md).
