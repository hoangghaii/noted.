# Phase 02 — Trích xuất meta & nội dung chính

Ngày 2026-11-04. Trạng thái: Done. Review: chưa nghiệm thu. Phụ thuộc Phase 01. Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Từ HTML đã tải (một request), trích ra tiêu đề, tên trang/tác giả, mô tả, nội dung chính, rồi tạo tóm tắt 1–3 câu theo kiểu trích xuất. Chạy offline sau khi tải.

## File ảnh hưởng

- Modify `Noted./Noted/Core/Enrichment/LinkMetadataService.swift`: thêm `fetchPage(for:) -> LinkPage {finalURL, html, statusCode}`, dùng lại `BoundedMetadataDownload`. Có thể nâng giới hạn từ 512 KB lên mức Phase 01 đề xuất (tối đa 2 MB). `title(for:)` giữ nguyên hành vi cho `EnrichmentRunner`.
- Create (đề xuất) `Noted./Noted/Core/Digest/LinkPageParser.swift`: parse thành `LinkPageFields`
  - `og:title`, `twitter:title`, `<title>`;
  - `og:description`, `twitter:description`, `meta name=description`;
  - `og:site_name`, `article:author`, JSON-LD (`headline`, `description`, `articleBody`, `author.name`);
  - nội dung chính: bỏ `script/style/nav/header/footer/aside/form`, chọn khối `<article>`/`<main>` hoặc khối `<p>` dày chữ nhất;
  - giải mã HTML entity đầy đủ (`&#NNN;`, `&#xHH;`, entity có tên thường gặp).
- Create (đề xuất) `Noted./Noted/Core/Digest/ExtractiveLinkDigester.swift`: chọn tiêu đề và tóm tắt, phát hiện `loginWall`. Dùng chung protocol `DigestGenerator` với ảnh nếu protocol đã có; nếu chưa thì tạo tại đây theo spec của plan ảnh.
- Create (đề xuất) `Noted./NotedTests/LinkDigestTests.swift` + `NotedTests/Fixtures/links/*.html`: fixture HTML tổng hợp (không chép trang thật có dữ liệu cá nhân).

## Bước

- [x] Parser không dùng regex cho cả trang. Dùng một tokenizer HTML tối giản (thẻ, thuộc tính, text), đủ để đọc `<meta>`, `<script type="application/ld+json">` và khối text. Không thêm dependency ngoài.
- [x] Tiêu đề: `og:title` → JSON-LD `headline` → `<title>` (bỏ hậu tố “| Facebook”, “• Instagram”, “- YouTube”) → host.
- [x] Tóm tắt:
  - ưu tiên mô tả meta nếu ≥40 ký tự và không trùng tiêu đề hay tên trang;
  - nếu không có thì lấy 1–3 câu đầu của nội dung chính;
  - giới hạn ≤240 ký tự, cắt theo ranh giới câu; bỏ chuỗi quảng cáo hoặc cookie banner thường gặp.
- [x] Mạng xã hội (theo kết quả Phase 01):
  - Facebook/Instagram/Threads: og:description thường có dạng “<số> likes, <số> comments – <tên> on <ngày>: "<nội dung>"”. Tách tác giả và phần nội dung trong ngoặc;
  - chuỗi login chung chung → `status = loginWall`, `summary = nil`.
- [x] `textForEmbedding`: ghép tiêu đề, tên trang/tác giả, tóm tắt và tối đa ~1.000 ký tự nội dung chính. Đây là đầu vào cho engine chủ đề (thay cho “domain + og:description giả lập” trong Phase 01 của plan Lớp AI).
- [x] `engineVersion` (ví dụ `link-extractive-v1`): đổi khi đổi luật trích xuất.

## Tiến độ (2026-11-04)

- `Noted/Core/Digest/HTMLTokenizer.swift`: tokenizer một lượt trên byte UTF-8, không đệ quy, chịu được tài liệu bị cắt (thẻ dở thì dừng).
- `Noted/Core/Digest/LinkPageParser.swift`: `LinkPageFields`, gồm meta, JSON-LD (đi qua `@graph`, giới hạn 200 node), nội dung chính (`<article>` → `<main>` → container có nhiều chữ `<p>` nhất) và giải mã entity số/có tên.
- `Noted/Core/Digest/ExtractiveLinkDigester.swift`: `LinkDigestContent` gồm `title`, `siteName`, `author`, `summary`, `textForEmbedding`, `status` (complete/titleOnly/loginWall), với `engineVersion = link-extractive-v1`.
  - Threads: og:title “Tên (@handle) on Threads” → `author`; tiêu đề lấy từ câu đầu của bài (≤80 ký tự).
  - FB/IG: tách tác giả và nội dung trong ngoặc từ og:description/og:title.
  - Luật login wall và chuẩn hóa domain được chuyển từ spike sang đây (spike gọi lại, DRY).
- `LinkMetadataService.fetchPage(for:) -> LinkPage`: một request, đọc tối đa 512 KB đầu trang (không nâng lên 2 MB vì Phase 01 cho thấy meta nằm trong vài KB đầu), ghi lại redirect tới login. `title(for:)` giữ nguyên hành vi, phần parse tách thành `title(fromHTML:url:)` để test hồi quy.
- Spike DEBUG thêm chiến lược `extractiveDigest`, chạy đúng pipeline production. Màn đánh giá hiển thị tiêu đề · tác giả và tóm tắt của digest.
- Lệch so với đề xuất:
  - **Chưa tạo protocol `DigestGenerator` chung.** Spec bên ảnh nhận OCR blocks, không hợp với trang web; protocol để Phase 05 định nghĩa khi có bản API thứ hai (YAGNI).
  - **Fixture HTML viết inline trong `LinkDigestTests.swift`** thay cho `NotedTests/Fixtures/links/*.html`, để không phải thêm resource vào test target. Toàn bộ là nội dung tổng hợp.
  - **Thêm trạng thái `titleOnly`** (theo quyết định Phase 01 cho iCloud Notes); Phase 03 cần thêm vào danh sách status.
- Evidence: build-for-testing `generic/platform=iOS` không lỗi/warning. `LinkDigestTests` 18/18 và `SearchAndEnrichmentTests` 6/6 đạt; toàn bộ `NotedTests` 88 test, 0 lỗi, 2 test opt-in bị bỏ qua, trên iPhone 12 Pro iOS 27.0.1.
- Đo trên iPhone (2026-11-04 15:04 UTC, `link-extractive-v1`): Threads `extractiveDigest` 8/8 `complete` (Phase 01: 8/8 có mô tả dùng được). Người dùng đánh giá đủ để gán **8/8** (Phase 01: 7/8). iCloud 1/1 `titleOnly`, đúng quyết định Phase 01, người dùng đánh giá không đủ. Không có login wall. Cả 8 trang Threads bị cắt ở 512 KB nhưng vẫn đọc được meta. Thời gian 1,05–2,41 s mỗi link, gồm tải.
- Quan sát: 7/8 tiêu đề Threads lấy từ câu đầu của bài (53–78 ký tự). 1 link vẫn giữ tiêu đề 19 ký tự, bằng độ dài og:title, tức og:title không khớp mẫu “… on Threads”. Định dạng og:title của link này chưa rõ (file đo không lưu text).

## Acceptance

- [x] Unit test xanh cho các fixture: bài báo, blog có JSON-LD, trang SPA rỗng, post Facebook/Instagram/Threads dạng og:description có nội dung, trang login wall, entity tiếng Việt (`&#7871;`…), trang vượt giới hạn dung lượng.
- [x] `title(for:)` cũ vẫn trả cùng kết quả (test hồi quy).
- [x] Trên 21 link thật, tỷ lệ có tóm tắt dùng được không thấp hơn kết quả Phase 01 của chiến lược đã chọn.

## Rủi ro

- HTML lỗi hoặc rất dài → tokenizer chịu lỗi, giới hạn dung lượng, không đệ quy.
- og:description là quảng cáo/rác → lọc chuỗi trùng site name, quá ngắn, danh sách mẫu chung chung.
- Nội dung chính chọn nhầm sidebar → ưu tiên `<article>`/JSON-LD, đo trên link thật.

Quay lui: runner dùng lại `title(for:)` cũ, bỏ parser mới.
