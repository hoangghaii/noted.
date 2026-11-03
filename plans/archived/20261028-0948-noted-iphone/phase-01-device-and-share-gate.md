# Phase 01 — Signing và Share trên iPhone thật

Trạng thái: nguồn đã triển khai, nghiệm thu Share còn mở. App chạy trên iPhone 12 Pro; Safari link/text và Photos ảnh được người dùng xác nhận; Notes “Gửi bản sao” lưu link về Notes. Phụ thuộc: iPhone vật lý, Xcode, Apple account.
Mục tiêu: chứng minh cài app và nhận Share trước khi xây toàn bộ MVP.

## Bối cảnh

Xcode 27.0 (27A266a) đã xác minh. Ngoài sandbox, devicectl nhận iPhone 12 paired nhưng unavailable; thử cài lỗi CoreDeviceError 4016. Build/ký và test build thành công, codesign strict/entitlement đạt ở binary; runtime chưa kiểm chứng. [Evidence](../../docs/verification.md).
[Share Extension](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html) nhận nội dung host; [App Group](https://developer.apple.com/documentation/xcode/configuring-app-groups) chia sẻ container với app.
Không mặc định team miễn phí cấp đầy đủ capability. Không thay Share Extension bằng luồng khác mà không thống nhất scope.

## File dự kiến — Create

Các đường dẫn sau đã tạo; đây vẫn là app shell kiểm chứng phase 01, không phải MVP hoàn tất:

- `Noted./Noted.xcodeproj/project.pbxproj`: app, extension, device test target, signing.
- `Noted./Noted.xcodeproj/xcshareddata/xcschemes/Noted.xcscheme`: shared scheme.
- `Noted./Noted/App/NotedApp.swift`: app shell và đọc payload thử.
- `Noted./NotedShare/ShareViewController.swift`: nhận payload mẫu.
- `Noted./NotedShare/Info.plist`: activation rules.
- `Noted./Noted/Noted.entitlements`: App Group app.
- `Noted./NotedShare/NotedShare.entitlements`: cùng App Group.
- `Noted./docs/device-setup.md`: setup/cài đè/signing.
- `Noted./docs/verification.md`: evidence đã khử dữ liệu cá nhân.

## Các bước

- [x] Xác minh iPhone 12 Pro vật lý kết nối wired, iOS27.0.1/Developer Mode enabled; người dùng đã Trust và app mở được.
- [x] Chọn deployment target 17.0, SDK 27.0 đã xác minh; cached device details báo iOS 26.6.1, cần xác nhận khi kết nối.
- [x] Xác định team từ certificate OU, bundle IDs app/extension và App Group; local team ở file Git ignore, entitlement đã ký khớp.
- [x] Tạo app shell, Share target, shared scheme `Noted`, device test target `NotedTests`; build-for-testing thành công.
- [x] Build, cài và launch qua Xcode CLI lên đúng iPhone 12 Pro; 5 XCTest dữ liệu chạy thật, 0 failures. Product → Run vẫn là đường hướng dẫn thao tác tay.
- [x] Extension ghi payload thử vào App Group; app đọc được, không ép mở app từ extension (Safari/Photos được người dùng xác nhận trong app).
- [x] Share Safari URL, Photos image và plain text chọn trong Safari từ app hỗ trợ Share; người dùng xác nhận ba loại trên iPhone.
- [ ] Đo payload/batch thực tế, ghi giới hạn ban đầu; loại bỏ demo trước dữ liệu cá nhân.

## Lệnh kiểm chứng

Chạy tại workspace sau khi project tồn tại; thay placeholder bằng giá trị xác minh:

```sh
xcodebuild -version
xcrun devicectl list devices
xcodebuild -list -project Noted.xcodeproj
xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'platform=iOS,id=<IPHONE_UDID>' -derivedDataPath /private/tmp/noted-derived build
codesign -d --entitlements :- /private/tmp/noted-derived/Build/Products/Debug-iphoneos/Noted.app
codesign -d --entitlements :- /private/tmp/noted-derived/Build/Products/Debug-iphoneos/Noted.app/PlugIns/NotedShare.appex
```

Build thành công chưa phải Share E2E; lưu kết quả thao tác thật trong `docs/verification.md`.

## Acceptance

- [x] App/extension ký và chạy trên iPhone thật; entitlement khớp và shared container truy cập được.
- [x] Ba loại Share có evidence thao tác thủ công đúng payload; app đọc được sau extension kết thúc. Text/URL/ảnh chưa cùng được UI test tự động end-to-end.
- [x] Cài đè cùng bundle ID giữ payload ảnh Photos; người dùng xác nhận ảnh còn và chú thích OCR mới đã xuất hiện.
- [x] Không Simulator/TestFlight; không ghi ID giả thành kết quả.
- [ ] Gate chưa đạt thì ghi prerequisite/Blocked cụ thể, chưa đánh dấu MVP hoàn thành.

## Rủi ro, quay lui và câu hỏi

[Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account) có profile hết hạn sau 7 ngày. Khôi phục cấu hình signing trước đó khi cần; không gỡ app, đổi bundle ID hoặc xóa container có dữ liệu.
Nếu entitlement không được cấp, trình bày lựa chọn tài khoản hoặc giảm scope để người dùng quyết định.
Còn mở: thiết bị/iOS/team/quyền App Group và giới hạn payload.
