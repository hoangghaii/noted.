# Noted — Đọc hiểu link

Tạo 2026-11-04 theo góp ý của người dùng khi gán nhãn Phase 01. Trạng thái: In progress, Phase 01–03 xong, tiếp theo Phase 04. Ưu tiên: cao, **làm trước** khi đánh giá lại Phase 01. Plan liên quan: [Lớp AI trên máy](../20261029-1623-smart-topic-groups/plan.md), [Đọc hiểu ảnh](../20261104-0902-ocr-image-summary/plan.md).

## Vì sao

Khi gán nhãn 75 mục thật, người dùng chọn “Không rõ” cho phần lớn link, vì app chỉ có URL và `<title>`. Không có mô tả thì người dùng không gán nhãn được, và engine chủ đề cũng không phân nhóm được ([kết quả](../../docs/intelligence-evaluation.md#nhãn-thật-trên-iphone-2026-11-04)).

## Mục tiêu

Mỗi link có một **bản đọc hiểu** (`LinkDigest`) gồm: tiêu đề, tên trang/tác giả, tóm tắt 1–3 câu và trạng thái đọc được hay không. Bản này hiển thị trên thẻ, trong Detail và trong màn gán nhãn DEBUG, đồng thời làm đầu vào cho engine chủ đề.

- Nguồn ưu tiên: **Facebook / Instagram / Threads**. Đây là chỗ khó nhất, vì nội dung thường nằm sau màn đăng nhập.
- Thứ tự lấy dữ liệu: meta (og/twitter/JSON-LD) → nội dung chính của trang (kiểu reader mode) → tùy chọn tóm tắt bằng API LLM miễn phí, do người dùng tự bật.

Ngoài phạm vi:
- đăng nhập Facebook/Instagram trong app, dùng cookie Safari, giả danh crawler của Meta;
- chạy JavaScript của trang (WKWebView ẩn) ở bản đầu, trừ khi Phase 01 chứng minh là cần và người dùng đồng ý;
- tải video hoặc ảnh của bài viết; dịch nội dung.

## Quyết định đã chốt (với người dùng, 2026-11-04)

- Plan riêng, làm trước. Bước “Link” ở Phase 04 của plan Lớp AI sẽ dùng `LinkDigest` thay vì tự lấy og:description.
- Lấy cả meta và nội dung chính. API LLM là tùy chọn, mặc định tắt.
- Màn gán nhãn DEBUG không cần sửa lỗi danh sách “Chủ đề khác…” (chỉ có trong DEBUG).

## Quyết định kiến trúc

- **Không đổi schema `library.store`.** `LinkDigest` nằm trong `intelligence.store`. Plan nào tới trước thì tạo `IntelligenceStore`; plan sau chỉ thêm entity (spec ở [Phase 02 Đọc hiểu ảnh](../20261104-0902-ocr-image-summary/phase-02-digest-store-and-runner.md)).
- Chỉ dùng **một request** HTTP cho mỗi link (cộng redirect), qua `PublicURLPolicy` và `BoundedMetadataDownload` có sẵn. oEmbed bị loại: Phase 01 cho thấy Threads trả HTTP 400 khi không có token. Trang lớn hơn 512 KB được đọc phần đầu (meta nằm trong vài KB đầu), không coi là lỗi.
- Dùng chung client `RemoteTextGenerator` với ảnh (DRY). Protocol `DigestGenerator` chung được hoãn tới Phase 05: đầu vào của ảnh (OCR blocks) và link (trang HTML) khác nhau, chỉ cần protocol khi có bản API thứ hai.
- Digest là dữ liệu dẫn xuất: không đưa vào backup, rebuild được.
- Trang yêu cầu đăng nhập thì ghi trạng thái `loginWall`, không bịa tóm tắt. UI gợi ý người dùng tự thêm ghi chú.

## Các phase

| Phase | Trạng thái | Phụ thuộc | Đầu ra |
|---|---|---|---|
| [01 — Spike nguồn link trên 21 link thật](phase-01-link-source-spike.md) | Done (FB/IG chưa có dữ liệu; 1 lượt đo hợp lệ) | — | Tỷ lệ đọc được theo domain và chiến lược, chọn chiến lược |
| [02 — Trích xuất meta & nội dung chính](phase-02-extraction.md) | Done | 01 | `LinkPageParser`, `ExtractiveLinkDigester`, test fixture |
| [03 — Kho LinkDigest & runner](phase-03-store-and-runner.md) | Done | 02 | Entity `LinkDigest`, `LinkDigestRunner` |
| [04 — Giao diện & màn gán nhãn](phase-04-ui-and-labeling.md) | Pending | 03 | Dòng tóm tắt trên thẻ, Detail, màn gán nhãn DEBUG, đầu vào cho evaluator |
| [05 — API LLM text-only (tùy chọn)](phase-05-optional-llm-api.md) | Pending | 02; client chung với plan ảnh | Viết lại tóm tắt khi người dùng bật |
| [06 — Nghiệm thu & đánh giá lại Phase 01](phase-06-acceptance-and-reevaluation.md) | Pending | 04 (05 nếu làm) | Evidence trên iPhone, gán nhãn lại link, chạy lại đánh giá |

Phase 05 làm song song được với 03–04.

## Cơ sở nguồn hiện tại

- `LinkMetadataService.title(for:)` chỉ lấy `<title>` bằng regex, giới hạn 512 KB, timeout 8/12 s, có `PublicURLPolicy` chặn mạng nội bộ.
- `EnrichmentRunner` gọi preview cho `item.kind == "link"` khi `previewStatus == "pending"`, ghi vào title nếu `!userEditedTitle`.
- Thư viện thật: 21 link (số đếm 2026-11-04). Chưa biết tỷ lệ theo domain.

## Giả định và câu hỏi còn mở

- **Đã xác minh cho Threads** (8/8 bài có og:description khi không đăng nhập; og:title là tác giả). **Chưa xác minh** cho Facebook/Instagram vì thư viện chưa có link của hai nguồn này.
- oEmbed Threads không token: HTTP 400 ở 8/8 link. Không dùng oEmbed.
- Có chấp nhận WKWebView ẩn (chạy JS của trang, không đăng nhập) cho trang SPA không? Chỉ hỏi lại người dùng nếu Phase 01 cho thấy nó giúp được đáng kể.
- Khi bật API: có gửi kèm URL đầy đủ không, hay chỉ text đã trích và domain? Mặc định đề xuất là chỉ text và domain.
