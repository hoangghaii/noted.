# Phase 01 — Icon và nền tảng thị giác

Ngày 2026-11-02. Ưu tiên cao. Phụ thuộc: không. Triển khai: icon và token đã có; icon Folded N đã chụp trên Home Screen iPhone 12 Pro trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md). Review: đã đối chiếu icon và nguồn asset; phép đo tương đồng pixel với Design Lab chưa thực hiện.

## Phạm vi và file

- Modify `Noted./Noted/Assets.xcassets/AppIcon.appiconset/AppIcon.png` — thay icon thật; giữ `Contents.json` đang trỏ tới asset này.
- Create `Noted./Shared/NotedDesign.swift` (đề xuất) — bảng màu semantic, kiểu chữ/spacing/radius tối thiểu dùng bởi app và Share Extension; chỉ dùng API hợp lệ trong extension.
- Modify `Noted./docs/design-guideline.md` — chốt token sau khi đối chiếu preview và iPhone; đổi nhãn “proposal” khi đã triển khai.
- Modify `Noted./Noted.xcodeproj/project.pbxproj` qua `scripts/update-project.rb` **chỉ nếu** thêm Swift source và project chưa tự nhận; không chạy `generate-project.rb` trên project hiện có.
- Nguồn thiết kế: [SVG Folded N](../../docs/design-preview/noted-folded-n.svg), [Design Lab](../../docs/design-preview/component-lab.html), [guideline](../../docs/design-guideline.md).

## Bước triển khai

- [x] Mở web preview ở desktop/mobile, đối chiếu icon 1024/56/33 px và palette. Ghi các điều chỉnh hướng A cần thiết vào guideline trước khi đóng băng token. Đã mở Design Lab trong Chrome Guest qua `file://`, xem desktop và responsive 400 px; chuyển sáng/tối và lọc mẫu hoạt động. Không cần chỉnh hướng A.
- [x] Dùng SVG làm nguồn hình; xuất PNG 1024×1024, **RGB opaque**, nền phủ kín. Không chép trực tiếp preview RGBA vào AppIcon. Kiểm tra đường nét và góc gấp không mất ở kích thước Home Screen/Spotlight. Đã xem PNG ở 1024, 56 và 33 px.
- [x] Thay đúng `AppIcon.png`; không thay bundle ID, App Group hoặc cấu trúc catalog. Xác minh Xcode target Noted dùng asset mới; icon Share sheet/extension theo hệ thống được xem trên máy thật. Asset và build đã xác minh.
- [x] Tạo token màu semantic: ink/brand, coral CTA, paper/surface, primary/secondary/error text, border; nền và chữ có biến thể đọc được theo appearance hệ thống. Token typography dùng font hệ thống và `@ScaledMetric`/semantic text style tại nơi cần. `Shared/NotedDesign.swift` dùng semantic text styles; `@ScaledMetric` sẽ được đặt ở component cần kích thước tùy chỉnh trong phase sau.
- [x] Chỉ thêm những giá trị dùng thật; tránh bộ theme lớn hoặc hardcode màu lặp lại trong từng view. Ghi quy tắc tương phản và chữ tiếng Việt vào guideline.

## Nghiệm thu

- Asset 1024×1024, RGB không alpha, build app nhận icon đúng; xem icon trên Home Screen ở kích thước thực sau **cài đè**.
- Màu CTA và chữ chính đọc rõ ở nền tương ứng; font hệ thống render đầy đủ `Ă Â Đ Ê Ô Ơ Ư` và các cụm “giữ”, “tìm kiếm”, “bộ sưu tập”.
- Không đổi bất kỳ file SwiftData/model/backup hoặc cấu hình bundle ID. Kiểm tra `file`, `sips`, build iPhoneOS; ảnh preview chỉ là tham chiếu, không tính là bằng chứng thiết bị.

Rủi ro: icon sắc ở 1024 px nhưng mất điểm gấp ở 33–60 px. Giảm chi tiết trong SVG/điều chỉnh tỷ lệ, xuất lại RGB rồi kiểm tra trên iPhone. Rollback: phục hồi PNG cũ và token trước phase này; dữ liệu không bị tác động.

## Bằng chứng trước nghiệm thu thiết bị

Các ghi chú thiết bị `unavailable` dưới đây là trạng thái của lượt triển khai trước Phase 05; kết quả iPhone thật mới nằm trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md).

- `file`/`sips`: `AppIcon.png` là PNG RGB 1024×1024, `hasAlpha: no`; biểu tượng thu nhỏ 56/33 px vẫn thấy chữ N và góc gấp.
- `xcodebuild -scheme Noted -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`: **BUILD SUCCEEDED**. Build biên dịch `NotedDesign.swift` trong cả Noted và NotedShare; `Noted.app/Info.plist` giữ `dev.nhhai7.Noted` và `CFBundleIconName = AppIcon`; icon 120 px trích từ build đúng Folded N.
- Ngoại lệ simulator chỉ cho plan này: `xcodebuild -scheme Noted -sdk iphonesimulator -destination 'platform=iOS Simulator,id=C66461EB-A8D0-424A-84FF-DC4A800E88B0' CODE_SIGNING_ALLOWED=NO build`: **BUILD SUCCEEDED** trên iPhone 12 Pro simulator (iOS 27.0). `xcrun simctl install` thành công; `xcrun simctl launch` trả `dev.nhhai7.Noted: 33980`. Đây là bằng chứng build/cài/mở, chưa phải kiểm tra giao diện hoặc dữ liệu trên iPhone vật lý.
- Tính tương phản theo WCAG cho các cặp sáng: primary/surface 15.04:1, secondary/surface 4.92:1, brand/paper 9.59:1, accentText/accent 5.85:1. Chưa kiểm tra chữ tiếng Việt trong app trên iPhone.
- `xcrun devicectl list devices` thấy iPhone vật lý ở trạng thái `unavailable`; chưa cài đè, chưa xem icon ở Home Screen/Share sheet và chưa xác nhận dữ liệu sau cài đè. Giữ nghiệm thu Phase 01 mở cho kiểm tra thiết bị này.
- Browser host của phiên công cụ trả `The browser access host is unavailable` ngay lúc tạo tab và không liệt kê browser nào; đây là lỗi kết nối host, không phải lỗi HTML. Đã mở chính file Design Lab bằng Chrome Guest qua điều khiển app gốc: desktop 1200 px hiển thị đủ icon, palette và preview iPhone; responsive 400 px hiển thị đúng bố cục một cột; theme sáng/tối và lọc “Ghi chú” đổi trạng thái/nội dung như dự kiến. Không sửa HTML/CSS/JS vì preview hoạt động.
