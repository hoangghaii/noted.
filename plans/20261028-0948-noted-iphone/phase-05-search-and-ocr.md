# Phase 05 — Search, OCR và preview

Trạng thái: nguồn đã triển khai; 5 search/OCR/preview tests đạt trên iPhone, gồm fixture tiếng Việt; URL network edge cases chưa đo; workload 500 item đã bỏ khỏi phạm vi theo yêu cầu người dùng ngày 2026-10-29. Phụ thuộc thiết kế: [04](phase-04-library-and-collections.md).
Mục tiêu: tìm lại nội dung không cần nhớ collection.

## Quyết định

Search local trên title/body/URL/domain/tag/OCR. Document chuẩn hóa lowercase, Unicode/diacritic folding và `đ` → `d`; giữ nguyên bản gốc.
Debounce, giới hạn kết quả, chưa thêm vector/external index. OCR [Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images) chạy trên máy, đọc ngôn ngữ hỗ trợ từ runtime/revision thực tế.
Không cam kết OCR tiếng Việt nếu runtime không hỗ trợ; caption/note vẫn tìm được có/không dấu.
OCR/preview chạy khi app hoạt động; không hứa chạy khi app đã đóng.
URL preview lỗi vẫn giữ original URL. Fetch chỉ http/https, giới hạn response/time/redirect và concurrency; kiểm tra đích loopback/private/link-local cả sau redirect. Nếu dùng API hệ thống không kiểm soát được network policy thì ghi giới hạn và chọn cách fetch có kiểm soát trước khi claim policy đạt.

## File dự kiến

| Hành động | Đường dẫn tuyệt đối | Mục đích |
|---|---|---|
| Create | `/Users/nhhai7/LocalData/Noted./Noted/Features/Search/SearchView.swift` | Query và type/date/collection filters |
| Create | `/Users/nhhai7/LocalData/Noted./Noted/Core/Search/SearchService.swift` | Normalize/query |
| Create | `/Users/nhhai7/LocalData/Noted./Noted/Core/Enrichment/OCRService.swift` | Vision/languages/retry |
| Create | `/Users/nhhai7/LocalData/Noted./Noted/Core/Enrichment/LinkMetadataService.swift` | Preview/fallback/network policy |
| Create | `/Users/nhhai7/LocalData/Noted./Noted/Core/Enrichment/EnrichmentRunner.swift` | Queue có giới hạn |
| Modify | `/Users/nhhai7/LocalData/Noted./Noted/Core/Models/Item.swift` | OCR/search/status versioned |
| Create | `/Users/nhhai7/LocalData/Noted./NotedTests/SearchAndEnrichmentTests.swift` | Search/retry/stale result/network failure |

## Các bước

- [ ] Fixture note tiếng Việt, URL, tag và OCR text biết trước; trash loại khỏi kết quả.
- [ ] Normalize và cập nhật search document sau edit/tag/OCR; rebuild được từ dữ liệu nguồn.
- [ ] Search UI/filter/debounce, hủy query cũ để tránh kết quả lỗi thời.
- [ ] OCR giới hạn bộ nhớ/concurrency; ảnh không đọc được vẫn là item hợp lệ.
- [ ] Status pending/running/complete/failed; running sau crash retry được.
- [ ] Ghi supported languages và OCR fixture thật; không gắn complete giả cho dữ liệu không nhận diện được.
- [ ] Preview không ghi đè title do người dùng sửa; kết quả enrichment chỉ áp dụng đúng revision item.
- [ ] URL đăng nhập/chống bot/lỗi/quá lớn có fallback domain/URL, không retry vô hạn.
- [ ] Xác minh ảnh/note không gửi đến dịch vụ ngoài; không log URL cá nhân.

## Kiểm chứng và acceptance

- [ ] `ca phe`/`cà phê`, `DA NANG`/`đà nẵng` khớp fixture theo quy tắc.
- [ ] Query đúng note/title/domain/tag/OCR; edit cập nhật, trash không xuất hiện.
- [ ] Screenshot ngôn ngữ hỗ trợ tìm được; unsupported được báo trung thực.
- [ ] Offline search hoạt động; preview lỗi không chặn capture.
- [ ] Terminate OCR rồi relaunch retry được, original không đổi.
- [ ] Đổi title khi preview đang chạy không mất title mới.
Workload 500 item và mục tiêu đo tương ứng không còn là điều kiện nghiệm thu (yêu cầu người dùng ngày 2026-10-29).
- [ ] URL invalid/private/redirect/response lớn được xử lý theo policy đã kiểm chứng.

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<IPHONE_UDID>' -only-testing:NotedTests/SearchAndEnrichmentTests test
```

## Rủi ro, quay lui và câu hỏi

OCR là dữ liệu máy tạo, không thay note gốc; cho retry. Preview liên hệ host URL, không dùng cloud AI/proxy.
Index lỗi thì rebuild, không xóa thư viện. Còn mở: ngôn ngữ, chất lượng OCR và hiệu năng trên máy thật.

## Cập nhật triển khai 2026-10-29

`PublicURLPolicy` đã được siết để từ chối thêm các dải IPv4 đặc biệt/tài liệu và IPv6 ngoài global-unicast, cùng tên `.internal` và localhost có dấu chấm cuối. Chưa đánh dấu acceptance URL policy: `URLSession` tự phân giải DNS sau bước kiểm tra, nên vẫn có cửa sổ DNS rebinding giữa validate và connect; chưa có kiểm chứng runtime về redirect, timeout, response quá lớn hoặc tiến trình bị dừng rồi relaunch. Không xem thay đổi policy này là bằng chứng đã chặn mọi SSRF.
