# Noted — cập nhật UI/UX và app icon

Ngày 2026-11-02. Trạng thái: **Phase 01–04 đã có triển khai và bằng chứng trên iPhone thật; Phase 05 đạt build/ký/cài đè và các ca chức năng chính, còn mở phép đo tương đồng 98–100% và stress test loading/chạm lặp. Kết quả trong [báo cáo thiết bị](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md).** Workspace: `/Users/nhhai7/LocalData/Noted.`

## Mục tiêu

Đưa hướng **Folded N** từ [preview tổng thể](../../docs/design-preview/noted-direction-a.html) và [Design Lab tương tác](../../docs/design-preview/component-lab.html) vào app SwiftUI trên iPhone. Icon dễ nhận ra ở Home Screen; các màn hình dùng cùng màu, chữ, khoảng cách, nút, form, card và phản hồi. Kiểm chứng thao tác thật, khả năng đọc tiếng Việt và dữ liệu còn nguyên sau cài đè.

Yêu cầu bổ sung ngày 2026-11-02 trong Phase 05: UI/UX app phải bám sát 98–100% Design Lab, đặc biệt khung preview iPhone tương tác, form và các trạng thái. Đối chiếu bằng ảnh thật từng màn và hành vi; không dùng con số phần trăm như kết quả đo khi nội dung mẫu, tỉ lệ khung và chrome của iOS khác nhau.

## Phạm vi và quyết định

- Phạm vi: icon; Thư viện, Tìm kiếm, Bộ sưu tập, chi tiết/chỉnh sửa, Lưu nhanh, Share Extension, Thùng rác, Dữ liệu & backup, trạng thái mở app/nhập nội dung. Giữ ba tab và các luồng hiện có.
- Dùng **SwiftUI native**, theme/tokens nhỏ dùng chung giữa app và Share Extension. Web preview là đặc tả hướng nhìn và tương tác, không nhúng WebView hay sao chép CSS máy móc. Tạo component chung khi có cùng trách nhiệm ở ít nhất hai nơi.
- Giữ `NOTED_BUNDLE_ID = dev.nhhai7.Noted`, App Group, model, backup format, receipt và logic lưu/tìm/Share. Không uninstall app, không TestFlight; cài đè lên iPhone thật để giữ dữ liệu. **Ngoại lệ riêng plan này theo yêu cầu 2026-11-02:** build và mở Phase 01 trên simulator iPhone 12 Pro để kiểm tra kỹ thuật. Kết quả simulator được ghi riêng và không thay thế nghiệm thu dữ liệu, Home Screen hay Share sheet trên iPhone vật lý.
- Hướng A là giả định thiết kế cho kế hoạch này. Nếu người dùng điều chỉnh preview trước triển khai, cập nhật token/icon và tiêu chí hình ảnh trong phase 01, rồi tiếp tục các phase còn lại.
- Màn hình sáng là mục tiêu hình ảnh chính. Preview tối là phương án tham khảo; vẫn dùng màu semantic đủ đọc khi iOS ở dark mode, nhưng không biến nghiệm thu dark mode/VoiceOver/chữ lớn toàn diện thành blocker vì người dùng đã rút chúng khỏi phạm vi MVP trước đây. Kiểm tra vùng chạm, nhãn và chữ tiếng Việt ở cấu hình mặc định.
- Kế hoạch [nhóm nội dung tự động](../20261029-1623-smart-topic-groups/plan.md) độc lập: chưa triển khai topic UI, không đổi ý nghĩa filter/search. Khi phase nhóm được làm sau, tái dùng token/component tại đây.

## Nguồn và rủi ro chính

- [Design guideline](../../docs/design-guideline.md) có màu, typo, spacing, button/form/card. Icon preview PNG là RGBA; Phase 01 đã xuất asset app **opaque RGB** 1024² từ SVG và kiểm tra ở kích thước 56/33 px. Còn thiếu đối chiếu trên iPhone thật.
- `RootView.swift` và `LibraryLifecycleView.swift` đang dùng `.indigo`; `LibraryView.swift`/`SearchView.swift` dùng grid và filter riêng; `CaptureSheet.swift` dùng `Form`; `NotedShare/ShareViewController.swift` là SwiftUI trong extension. Đổi trình bày không được làm đổi payload hay trạng thái lưu.
- UI tests hiện dựa vào `accessibilityIdentifier` như `captureAdd`, `captureSave`, `libraryFilters`, `searchQuery`, `item_<UUID>`, `shareSave`. Giữ định danh hoặc cập nhật test có chủ đích. Những ca UI cũ chưa đạt vẫn phải báo riêng, không được tính là đạt nhờ build.

## Phases

| Phase                                                             | Trạng thái                                                                          | Kết quả                                                                          |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| [01 — Icon và nền tảng thị giác](phase-01-brand-foundations.md)   | Icon đã thấy trên Home Screen iPhone 12 Pro                                         | Icon thật, token SwiftUI, guideline chốt                                         |
| [02 — Component chung và khung app](phase-02-components-shell.md) | Đã chụp trên iPhone; tab/chip/nút hoạt động trong UI tests                          | Nút, chip, feedback dùng lại; tab/toolbar nhất quán; input/card theo phase 03–04 |
| [03 — Nội dung và khám phá](phase-03-library-discovery.md)        | Đã chụp trên iPhone; filter, pagination, search, collection, editor qua UI tests    | Thư viện, tìm kiếm, bộ sưu tập, chi tiết/chỉnh sửa                               |
| [04 — Lưu và luồng phụ](phase-04-capture-share-utility.md)        | Capture, Share nguồn thật, Trash và backup Files có test thiết bị; UI suite 9/9 đạt | Capture, Share, Trash, backup, loading/error/empty                               |
| [05 — Nghiệm thu iPhone](phase-05-device-acceptance.md)           | Đạt các ca chính; còn hai tiêu chí nêu ở đầu plan                                   | Build, cài đè, bằng chứng hình ảnh và hành vi, review                            |

## Điều kiện hoàn tất

UI trên iPhone thật thể hiện hướng Folded N và Design Lab một cách nhất quán; tác vụ lưu/tìm/sửa/khôi phục/Share/backup trọng yếu vẫn hoạt động; dữ liệu cũ còn sau cài đè; không phát sinh mất dữ liệu, nút khó chạm, loading kẹt hoặc nhập lặp. Kết quả phải ghi riêng **đã kiểm chứng**, **chưa kiểm chứng** và **lỗi hạ tầng**.

## Câu hỏi còn mở

- Hướng Folded N là baseline từ cuộc trao đổi; màu/hình icon và copy trong web preview vẫn có thể được chỉnh trước khi phase 01 hoàn tất. Không cần đổi kiến trúc vì chỉnh này.
- Design Lab đã được xem trực tiếp trong Chrome Guest ở desktop và viewport responsive 400 px. Ảnh iPhone vật lý và khác biệt native được ghi trong báo cáo Phase 05; chưa có phép đo tương đồng pixel để xác nhận con số 98–100%.
