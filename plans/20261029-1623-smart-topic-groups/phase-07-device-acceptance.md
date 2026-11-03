# Phase 07 — Nghiệm thu iPhone

Ngày 2026-11-03. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 03, 04, 05 (và 06 nếu có làm). Ưu tiên cao. Overview: [plan.md](plan.md).

## File ảnh hưởng

- Create (đề xuất) `Noted./docs/intelligence-verification.md` — evidence runtime, chất lượng, giới hạn.
- Modify `Noted./README.md` — tính năng AI, offline/riêng tư, kích thước model, backup.
- Modify `Noted./docs/verification.md` — liên kết evidence mới, không sửa kết quả cũ.

## Bước

- [ ] Unit + UI tests trên iPhone thật `00008101-001A2519266B001E`. Xác minh scheme có NotedUITests trước khi chạy.
- [ ] Chất lượng trên holdout chưa dùng để chỉnh ngưỡng: confusion theo nhóm, coverage tách ảnh/link/ghi chú, độ chính xác tag, recall tìm theo nghĩa, tỷ lệ tiêu đề tự động người dùng giữ lại.
- [ ] Tài nguyên trên iPhone 12 Pro:
  - cold load, p95 mỗi mục, thời gian phân tích toàn thư viện;
  - peak memory, nhiệt độ máy;
  - kích thước app tăng thêm;
  - bộ nhớ Share Extension.
  Capture trong lúc batch đang chạy vẫn mượt.
- [ ] Offline thật (chế độ máy bay): xác nhận bằng một request mạng thất bại. Kiểm tra mở nhóm, phân nhóm mục mới, tìm theo nghĩa, tiêu đề trích xuất, Share gợi ý. Phase 06: mục mới vẫn dùng bản trích xuất.
- [ ] Fault matrix:
  - `intelligence.store`/cache hỏng, thiếu model;
  - sửa/trash/xóa mục đang inference;
  - backup đang chạy;
  - bảng tra cứu Share hỏng;
  - (06) 429, timeout, sai schema.
  Kết quả mong đợi: retry có giới hạn, manual override còn nguyên.
- [ ] Backup v1 → app mới, v2 → v2 (topic/merge/override/tag đã bỏ qua). Cài đè cùng bundle ID giữ originals/checksum. Không gỡ app.
- [ ] Người dùng tự nghiệm thu trên thư viện thật. Ghi rõ đâu là build, đâu là unit, UI, và đánh giá chất lượng thực.

Lệnh dự kiến (sau khi thêm file test):

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=00008101-001A2519266B001E' \
  -only-testing:NotedTests/IntelligenceEngineTests -only-testing:NotedTests/IntelligencePipelineTests \
  -only-testing:NotedTests/TopicClassifierTests -only-testing:NotedTests/TitleAndTagTests \
  -only-testing:NotedTests/SemanticSearchTests test
```

## Acceptance

Report có số đạt/trượt, thời gian, engine version và artifact thật. Mục nào còn thiếu ghi pending. Gate Phase 01 không đạt → không bật AI mặc định, không claim hoàn tất.

Quay lui: tắt AI trong cài đặt (danh sách phẳng, tìm từ khóa). Giữ user corrections và dữ liệu gốc.
