# Phase 02 — Component chung và khung app

Ngày 2026-11-02. Ưu tiên cao. Phụ thuộc: phase 01. Triển khai: component và shell đã có; tab bar, chip, nút và trạng thái được chụp/kiểm tra trên iPhone thật trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md). Review: đã rà soát mã, sửa hai vùng chạm dưới 44 pt.

## Phạm vi và file

- Create `/Users/nhhai7/LocalData/Noted./Noted/UI/NotedComponents.swift` (đề xuất) — button roles, filter chip, field container và feedback presentation **chỉ khi** dùng lại từ nhiều view; chia file theo trách nhiệm nếu lớn.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/App/RootView.swift` — tab/toolbar, entry Lưu nhanh, tint và loading overlay.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/App/LibraryLifecycleView.swift` — màu/status khi mở app, nhập Shared content, OCR/preview; giữ keyboard dismissal hiện có.
- Modify `/Users/nhhai7/LocalData/Noted./Noted.xcodeproj/project.pbxproj` qua `scripts/update-project.rb` nếu thêm source.
- Reference: [web component lab](../../docs/design-preview/component-lab.html), [guideline](../../docs/design-guideline.md).

## Bước triển khai

- [x] Map component web sang SwiftUI semantic: primary coral, secondary ink, quiet, destructive; selected filter; input label/help/error; card surface; loading/empty/error. Dùng `Button`, `Label`, `TextField`, `TextEditor`, `ProgressView` native thay vì dựng gesture giả. Đã có button/chip/status và loading; input/card thuộc phase 03–04.
- [x] Giữ ba tab “Thư viện”, “Tìm kiếm”, “Bộ sưu tập” và đường vào capture/Trash/Backup. Có thể dùng “Tìm lại” làm headline nội dung, nhưng tab label và `accessibilityIdentifier` hiện có giữ ổn định.
- [x] Thống nhất CTA Lưu nhanh: dễ thấy ở Thư viện và vẫn có entry trên các tab; không tạo hai sheet hoặc hai thao tác lưu từ một lần chạm. Hai nút dùng cùng `showCapture`, với guard khi sheet đang mở.
- [x] Tái dùng `operationLoading` hiện có hoặc chuyển vào component chung nếu được dùng rộng hơn; khi busy hiển thị tiến trình, khóa submit lặp và vẫn nhìn thấy khi bàn phím mở. Modifier được chuyển nguyên hành vi sang `NotedComponents.swift`.
- [x] Tối thiểu 44 pt vùng chạm cho nút/chip/tab; focus/selected/disabled/destructive có nhãn và sắc độ rõ. Tôn trọng safe area, không che tab bar và thông báo nhập nội dung. Đã sửa vùng chạm clear/search và pending discard.
- [x] Xem lại font hệ thống/line limit/truncation cho tiếng Việt. Không biến web “density switch” thành setting trong app nếu chưa có nhu cầu sản phẩm. Chip dùng system subheadline, có horizontal scroll và không cắt nhãn.

## Nghiệm thu

- Tab, toolbar và sheet hoạt động như trước; loading không chặn thoát sau hoàn tất và không cho lưu hai lần.
- Cùng kiểu button/chip/feedback xuất hiện nhất quán ở các màn hình áp dụng; trạng thái empty/error có bước tiếp theo rõ.
- Build iPhoneOS thành công. Các test định danh `libraryTab`, `searchTab`, `collectionsTab`, `captureAdd`, `operationLoading` vẫn tìm được hoặc được sửa có chủ đích; không dùng build làm bằng chứng UI E2E.

Rủi ro: style chung nuốt trạng thái `.disabled` hoặc thay vùng chạm. Kiểm tra trên màn hình thật; nếu component trừu tượng làm layout phức tạp, giữ style modifier nhỏ. Rollback: quay lại style từng view, không liên quan dữ liệu.

## Bằng chứng trước nghiệm thu thiết bị

Các ghi chú thiết bị `unavailable` dưới đây là trạng thái của lượt triển khai trước Phase 05; kết quả iPhone thật mới nằm trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md).

- `ruby scripts/update-project.rb` đã thêm `Noted/UI/NotedComponents.swift` vào target Noted; `plutil -lint Noted.xcodeproj/project.pbxproj` đạt.
- `xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/noted-phase02-derived CODE_SIGNING_ALLOWED=NO build` đạt `BUILD SUCCEEDED`. Lần chạy sandbox đầu bị chặn `swift-plugin-server`; chạy lại với quyền Xcode đầy đủ đã đạt.
- Static review xác nhận định danh `libraryTab`, `searchTab`, `collectionsTab`, `captureAdd`, `operationLoading` còn trong mã. Đây chưa phải bằng chứng UI E2E.
- `xcrun devicectl list devices` báo iPhone 12 Pro vật lý `unavailable`. Chưa kiểm tra chạm/tab/sheet/loading và chữ tiếng Việt trên iPhone thật; không chấm nghiệm thu UI hoàn tất.
