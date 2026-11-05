# Phase 06 — Nghiệm thu & đánh giá lại Phase 01

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 04 (và 05 nếu làm). Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Chứng minh trên iPhone 12 Pro rằng link đã đọc hiểu được, rồi quay lại gán nhãn link để Phase 01 của plan Lớp AI có dữ liệu link dùng được.

## Bước

- [ ] Trên iPhone (bản Debug, dữ liệu thật): chạy runner cho 21 link, ghi số `complete` / `loginWall` / `unreachable` theo domain vào `docs/intelligence-evaluation.md` (chỉ số đếm).
- [ ] Đo thời gian đọc mỗi link (p50/p95) và đảm bảo lưu link mới không bị chậm khi runner đang chạy.
- [ ] Offline: lưu link khi tắt mạng → mục vẫn lưu, digest chạy khi có mạng lại.
- [ ] Backup/restore: digest không nằm trong backup; sau restore runner tạo lại.
- [ ] Người dùng gán nhãn lại các link đang là “Không rõ” trong màn DEBUG, dựa trên tóm tắt.
- [ ] Chạy lại “Chạy đánh giá local”, so precision/coverage của link trước và sau khi có digest. Cập nhật Phase 01 của plan Lớp AI.
- [ ] Nếu bật Phase 05: so bản API với bản trích xuất trên link đọc được.

## Acceptance

- Tỷ lệ link có tóm tắt dùng được đạt mục tiêu chốt ở Phase 01 của plan này (theo domain), với Facebook/Instagram/Threads báo riêng.
- Số link nhãn “Không rõ” giảm so với lần gán 2026-11-04, và evaluation doc có kết quả đánh giá lại.
- Test unit/UI liên quan pass trên máy; build Release thành công.

## Rủi ro

- Phần lớn link Meta là `loginWall` → báo người dùng rõ con số; khi đó gợi ý thêm ghi chú khi share, hoặc cân nhắc WKWebView ẩn như một quyết định riêng.
