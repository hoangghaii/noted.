# Phase 01 — Spike nguồn link trên link thật

Ngày 2026-11-04. Trạng thái: Done, còn hai điểm mở (Facebook/Instagram chưa có dữ liệu thật; mới có 1 lượt đo hợp lệ). Review: chưa nghiệm thu. Không phụ thuộc. Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Đo trên chính 21 link của người dùng xem mỗi chiến lược lấy được gì, rồi chọn chiến lược theo số đo. Không ghi gì vào `library.store` hay `intelligence.store`.

## File ảnh hưởng

- Create (đề xuất) `Noted./Noted/Core/Enrichment/LinkSourceSpike.swift` (DEBUG): chạy từng chiến lược cho mỗi link, trả số liệu tổng hợp.
- Modify `Noted./Noted/App/IntelligenceLabelingView.swift` (DEBUG): nút “Đo nguồn link”, ghi `IntelligenceEvaluation/link-sources.json`.
- Modify `Noted./docs/intelligence-evaluation.md`: thêm mục kết quả.

## Bước

- [x] Đếm link theo domain đã chuẩn hóa (`m.facebook.com`, `fb.watch`, `facebook.com/share/…` gộp về `facebook`; tương tự `instagram`, `threads`), chỉ ghi số lượng.
- [x] Với mỗi link, chạy các chiến lược dưới đây và ghi lại cho mỗi chiến lược: HTTP status, có redirect tới trang login không, có `og:title`/`og:description`/JSON-LD/nội dung chính ≥200 ký tự không, độ dài, thời gian.
  1. GET hiện tại (User-Agent mặc định của `URLSession`);
  2. GET với User-Agent Safari iOS thật của máy (không giả danh crawler);
  3. `LPMetadataProvider` của LinkPresentation (chỉ để so tiêu đề);
  4. oEmbed công khai nếu có (Threads, YouTube, TikTok…); ghi rõ endpoint nào cần token.
- [~] Phát hiện login wall: redirect tới `/login`, `/accounts/login`, hoặc og:description chung chung (“Log in or sign up…”, “Đăng nhập Facebook…”). Lập danh sách mẫu chuỗi từ kết quả thật.
- [x] Người dùng xem bảng tổng hợp và cho biết với từng link, thông tin lấy được có đủ để gán chủ đề không. Ghi tỷ lệ “đủ để gán” theo domain.
- [x] Chọn chiến lược mặc định và thứ tự fallback; ghi lý do trong evaluation doc.

## Tiến độ (2026-11-04)

- Đã có `LinkSourceSpike.swift` (DEBUG) và mục **Nguồn link · DEBUG** trong màn gán nhãn: nút “Đo nguồn link”, bảng tổng hợp domain × chiến lược, màn “Xem và đánh giá từng link” (Đủ/Không đủ), xuất `IntelligenceEvaluation/link-sources.json`. Mỗi lần đo được nối thêm vào `runs` nên đo được 2 thời điểm.
- `BoundedMetadataDownload` nhận thêm User-Agent và danh sách MIME tùy chọn, ghi lại HTTP status và redirect. Mặc định giữ nguyên request preview hiện tại.
- Evidence: build-for-testing `generic/platform=iOS` không lỗi/warning; `SearchAndEnrichmentTests` 8/8 đạt trên iPhone 12 Pro iOS 27.0.1 (3 test mới: chuẩn hóa domain, đọc meta/JSON-LD/nội dung chính, login wall và boilerplate lặp).
- Chưa làm: chạy đo trên 21 link thật (2 lần), người dùng đánh giá từng link, điền bảng và quyết định vào evaluation doc. Các checkbox ở trên chỉ tick sau khi có số đo.
- Giới hạn đã biết: `LPMetadataProvider` tự đi theo redirect, không qua `PublicURLPolicy` (chỉ kiểm tra URL đầu, chấp nhận vì là DEBUG). oEmbed lỗi chỉ ghi được HTTP status, không đọc body lỗi. Nội dung trang chỉ giữ trong bộ nhớ, đóng màn là mất, nên cần đánh giá ngay sau khi đo.

## Kết quả lần đo 1 (2026-11-04, 2 lượt 14:32 và 14:37 UTC, build 1.0 (1), iOS 27.0.1, iPhone13,3)

- Thư viện có 21 link, nhưng 12 link là `example.com` (dữ liệu fixture/test). Link thật chỉ có 8 Threads và 1 iCloud Notes. Bảng tổng hợp chưa đại diện cho thư viện thật.
- Threads 8/8: GET trả 200 nhưng trang khoảng 600 KB, vượt giới hạn 512 KB, nên lỗi `oversized` và không đọc được meta nào. **Đây là lỗi của công cụ đo, không phải login wall.** oEmbed `graph.threads.net` không token trả 400 ở 8/8 link, nên không dùng được nếu không có token. `LPMetadataProvider` chỉ trả tiêu đề, mà tiêu đề đó là og:title của Threads = “Tên (@handle) on Threads”, tức tên tác giả.
- Kiểm tra bằng curl trên bài công khai: og:title là tác giả, og:description là nội dung bài và nằm trong ~4 KB đầu trang. Bài có ảnh hoặc text dài có thể không có og:description. Trang profile không đăng nhập thì trả boilerplate “Join Threads…”.
- iCloud Notes 1/1: có og:title (20 ký tự) và og:description 22 ký tự, dưới ngưỡng 40. Nội dung ghi chú không có trong HTML.
- Sửa công cụ: `BoundedMetadataDownload(keepPrefixWhenOversized:)` cắt ở 512 KB và vẫn parse phần đầu; ghi cờ `truncated`. Chế độ preview mặc định không đổi. Đã chạy 9/9 `SearchAndEnrichmentTests` trên iPhone. Cần đo lại.

## Kết quả lần đo 2 (2026-11-04 14:47 UTC, sau khi sửa)

- Threads 8/8 có og:description 76–487 ký tự với cả hai kiểu GET (hash giống hệt). Người dùng đánh giá 7/8 đủ để gán. oEmbed 0/8 (HTTP 400). iCloud 0/1: chỉ có tiêu đề, người dùng đánh giá không đủ.
- Login wall: không xuất hiện ở link thật. Mẫu “Join Threads… Log in with your Instagram” có được từ curl trang profile; mẫu của FB/IG vẫn là mẫu đoán (vì vậy bước này đánh `[~]`).
- Bảng và quyết định: [evaluation doc](../../docs/intelligence-evaluation.md#nguồn-link-trên-iphone-2026-11-04). Phase 02 cần: đọc 512 KB đầu thay vì lỗi; og:title của Threads là tác giả.

## Acceptance

- `docs/intelligence-evaluation.md` có bảng: domain × chiến lược × tỷ lệ có mô tả dùng được, kèm build, iOS và ngày đo. Không ghi URL đầy đủ hay nội dung bài.
- Có quyết định rõ cho Facebook, Instagram, Threads: đọc được tới đâu, và khi nào ghi `loginWall`.

## Rủi ro

- Meta đổi hành vi theo IP, vùng hoặc thời điểm → đo 2 lần ở 2 thời điểm, ghi ngày.
- Request lặp nhiều có thể bị rate-limit → mỗi link chạy mỗi chiến lược 1 lần, có giãn cách.
- Riêng tư: file kết quả chỉ chứa domain, cờ và độ dài, không chứa nội dung.

Quay lui: bỏ nút DEBUG, xóa `link-sources.json`.
