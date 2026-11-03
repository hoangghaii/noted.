# Phase 04 — Tiêu đề, tóm tắt, tag & Share Extension

Ngày 2026-11-03. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 02. Gợi ý topic trong Share cần topic từ Phase 03 (tag thì không cần). Ưu tiên trung bình-cao. Overview: [plan.md](plan.md).

## Mục tiêu

Tự điền tiêu đề trống, tóm tắt link, gợi ý tag, gợi ý topic/tag ngay trong Share Extension. Tất cả offline, theo kiểu trích xuất.

## File ảnh hưởng

- Modify `Noted./Noted/Core/Enrichment/LinkMetadataService.swift` — trả struct `{title, description, siteName}` từ `<title>`, `og:title`, `og:description`, `meta name=description`, `og:site_name`. **Cùng request**, vẫn giới hạn 512 KB và `PublicURLPolicy`. Giải mã HTML entity đầy đủ hơn (`&#NNN;`).
- Modify `Noted./Noted/Core/Enrichment/EnrichmentRunner.swift` — dùng struct mới. Title giữ logic `!userEditedTitle`. Description lưu vào `GeneratedText.summary`.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/ExtractiveTitler.swift` — tiêu đề cho ảnh/ghi chú trống.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/TagSuggester.swift`.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/ShareSuggestionIndex.swift` — xuất bảng tra cứu vào App Group.
- Modify `Noted./Shared/ShareGateStore.swift` — `ShareGatePayload` thêm field optional `topicID: UUID?`, `tags: [String]?`. Payload cũ vẫn decode được.
- Modify `Noted./NotedShare/ShareViewController.swift` — chip gợi ý topic/tag, người dùng bấm chọn.
- Modify `Noted./Noted/Core/Persistence/LibraryStore.swift` — import payload: áp tags; topicID hợp lệ → manual assignment; topicID không tồn tại → bỏ qua, không lỗi.
- Modify `Noted./Noted/Features/Detail/ItemDetailView.swift`, `Noted./Noted/Features/Capture/CaptureSheet.swift`, `Noted./Noted/Features/Library/ItemCard.swift` — tóm tắt, chip tag gợi ý.
- Create (đề xuất) `Noted./NotedTests/TitleAndTagTests.swift`.

## Bước

- [ ] **Link**: title theo thứ tự `og:title` → `<title>` → host. Tóm tắt = `og:description`/`meta description`, cắt ≤240 ký tự theo ranh giới câu. Không tải thêm trang.
- [ ] **Ảnh có tiêu đề trống**: dòng OCR nổi bật (dòng đầu đủ dài, không phải số/giờ/thanh trạng thái), ≤60 ký tự. Ảnh không có OCR → để `displayTitle` hiện có (“Ảnh đã lưu”), **không** bịa tiêu đề từ nhãn Vision.
- [ ] **Ghi chú có tiêu đề trống**: câu đầu, ≤60 ký tự. Chỉ ghi khi body dài hơn câu đó (tránh lặp nguyên body).
- [ ] Ghi qua `applyGeneratedTitle` (Phase 02). Tiêu đề người dùng sửa → `userEditedTitle` → không bao giờ ghi đè. Có nút “Đặt lại tiêu đề tự động” trong Detail.
- [ ] **Tag**:
  - ứng viên = tag của k mục gần nhất (k=8, có trọng số theo cosine) + tag đã có khớp alias trong text;
  - tối đa 3 chip, chỉ gợi ý tag đã tồn tại trong thư viện (không tự tạo tag mới, tránh rác);
  - bấm thì lưu qua `LibraryStore.update(markTitleEdited: false)`; bỏ qua thì ghi `dismissed`, không gợi ý lại.
- [ ] **Bảng tra cứu cho Share**:
  - nội dung: tên miền → top topic/tag (đếm từ assignment manual + generated đã được chấp nhận), alias/từ khóa của topic, danh sách topic (id, tên);
  - JSON ≤200 KB, ghi atomic sau mỗi lần commit có thay đổi (debounce);
  - không chứa URL đầy đủ hay nội dung note.
- [ ] Share Extension:
  - đọc bảng tra cứu; khớp domain/từ khóa trong caption/title → hiện ≤2 chip topic và ≤3 chip tag;
  - bảng thiếu hoặc hỏng → không gợi ý, việc lưu vẫn bình thường;
  - đo bộ nhớ extension không tăng đáng kể.
- [ ] Payload cũ (không có field mới) và payload mới đều import đúng. Test decode cả hai.

## Acceptance

- Link mẫu có og:description hiện tóm tắt.
- Ảnh/ghi chú trống có tiêu đề hợp lý, tiêu đề đã sửa tay không bị đổi qua relaunch và qua lúc runner chạy lại.
- Tag gợi ý đúng ≥50% theo nhãn Phase 01 (mục tiêu đề xuất).
- Share trên iPhone: chọn chip → mục xuất hiện đúng topic/tag. Bảng hỏng → vẫn lưu được.

## Rủi ro

- og:description là quảng cáo/rác → lọc chuỗi trùng site name, quá ngắn.
- Dòng OCR không có nghĩa → ngưỡng độ dài/tỷ lệ chữ cái.
- Payload đổi → field optional, có test.

Quay lui: tắt titler/tag suggester; tiêu đề đã ghi vẫn là title bình thường, người dùng sửa được.
