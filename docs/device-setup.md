# Build và cài Noted trên iPhone thật

## Cấu hình

- Xcode hiện kiểm tra: 27.0 (27A266a), iPhoneOS SDK 27.0.
- Deployment target 27.0; đã chạy thực tế trên iPhone 12 Pro (iPhone13,3), iOS 27.0.1 (24A446), kết nối cáp và Developer Mode enabled.
- App: `dev.nguyenhoanghai861.Noted`; extension: `dev.nguyenhoanghai861.Noted.Share`.
- App Group: `group.dev.nguyenhoanghai861.Noted`; entitlement đã được ký vào cả hai target.
- Scheme: `Noted`, test target: `NotedTests`; supported platforms chỉ `iphoneos`.

Ngày 2026-11-02 chuyển namespace sang `nguyenhoanghai861`, team `DBC9RB6Z6U`. Bundle ID/App Group mới dùng vùng dữ liệu riêng; app cũ không bị gỡ và dữ liệu không tự chuyển. Các báo cáo trước thời điểm này áp dụng cho namespace cũ. Có thể dùng xuất/nhập backup để chuyển nội dung.

Team lấy từ tài khoản hiện có trong Xcode → Settings → Accounts. Copy `.env.example` thành `.env`, điền thông tin rồi chạy `python3 scripts/configure-env.py` để sinh `Config/Local.xcconfig`. Chạy lại script sau mỗi lần đổi `.env`. Hai file cá nhân bị Git ignore; chỉ commit `.env.example` với giá trị mẫu. Không lưu mật khẩu, token, chứng chỉ, khóa hoặc provisioning profile trong `.env`. Apple ID trong file không đăng nhập Xcode thay bạn.

## Cài/chạy

1. Cắm iPhone bằng cáp, mở khóa, Trust máy Mac nếu được hỏi; bật Developer Mode khi cần.
2. Mở `Noted.xcodeproj` trong Xcode. Chọn scheme `Noted` và iPhone vật lý.
3. Signing & Capabilities: chọn team hợp lệ cho app/extension. Kiểm tra cả hai có cùng App Group.
4. Product → Run. Không chọn Simulator. Nếu thiết bị unavailable, xử lý kết nối trước.
5. Mở thư viện Noted. Safari → Share → More/Thêm → Noted nếu chưa thấy. Với Safari thanh địa chỉ gọn, Share nằm trong Menu của trang.
6. Share một link, một ảnh Photos và plain text từ app hỗ trợ Share. Bấm Lưu, đợi xác nhận, Xong; quay lại Noted để xem.
7. Đóng/mở lại Noted rồi build/cài đè cùng bundle ID, xác nhận nội dung còn nguyên.

Mỗi lượt hỗ trợ tối đa 3 mục sau khi gộp caption; có thể kèm một text provider bổ sung (tối đa 4 providers thô). Mỗi file ảnh tối đa 20 MB. Đã kiểm chứng ảnh mẫu; chưa đo đầy đủ ảnh 20 MB/HEIC/iCloud và áp lực bộ nhớ ở giới hạn tối đa.
Text-only qua attributedContentText được hỗ trợ. Payload lạ/không đầy đủ báo lỗi, không báo đã lưu.
Extension không ép mở app chính; app đọc lại khi launch/foreground hoặc Làm mới.

## Test trên thiết bị

Thay `<IPHONE_UDID>` bằng ID thiết bị thật được xác minh qua `xcrun devicectl list devices`:

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'platform=iOS,id=<IPHONE_UDID>' -derivedDataPath /private/tmp/noted-device -allowProvisioningUpdates build
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<IPHONE_UDID>' -only-testing:NotedTests/ShareGateStoreTests test
```

Các test dữ liệu gồm recovery trước/sau commit, UUID collision, originals/checksum, trash/restore, OCR, search tiếng Việt và backup merge/round-trip/corruption.
Test build thành công không có nghĩa tests đã chạy; Share Safari/Photos/text cần thao tác thực tế.

## UI test

Scheme `Noted-DeviceGate` chứa các test giao diện. iPhone có thể yêu cầu nhập mật mã trực tiếp để bật **Enable UI Automation**; không nhập hoặc lưu mật mã trong source/script.
Các luồng đã chạy đạt và artifact cụ thể nằm trong [verification.md](verification.md). Không chạy nguyên bộ locator Safari/Photos rồi coi build là E2E; một số ca chẩn đoán còn phụ thuộc phiên bản UI hệ thống.

`NotedGateHost` là app nguồn mẫu độc lập, không có App Group hoặc quyền đọc ảnh cá nhân. Build `Noted-DeviceGate` với `build-for-testing`, cài `NotedGateHost.app` bằng Xcode/devicectl rồi chạy `ExternalShareUITests` trên iPhone nếu tài khoản ký còn chỗ cài app. Free developer profile trên iPhone hiện tại đã chạm giới hạn ba app khi có Noted, XCTest runner và một app cá nhân; không xóa app cá nhân chỉ để chạy diagnostic host. App nguồn thử không được đóng gói vào Noted và không cần khi sử dụng hằng ngày.

## Giữ dữ liệu và signing

- Không uninstall, xóa container hoặc đổi bundle ID/App Group để sửa lỗi signing.
- Extension ghi batch vào `ShareGate` của shared container; app chính copy originals, commit SwiftData và receipt rồi mới cleanup batch.
- Tên queue cũ được giữ để nhập được dữ liệu đã lưu từ phase 01. Manifest cũ thiếu checksum/version vẫn đọc được, sau đó originals được xác minh khi nhập.
- Menu Tùy chọn thư viện → Dữ liệu & Backup: export/import qua Files. Đã kiểm chứng xuất rồi nhập lại trên iPhone, không nhân đôi dữ liệu.
- Backup chưa mã hóa, chứa cả thùng rác. Giữ một bản bên ngoài vùng dữ liệu của app nếu muốn bảo vệ trước uninstall/mất máy.
- Schema hiện là v1. App từ chối marker schema không hỗ trợ; chưa có migration sang v2. Trước khi triển khai migration phải có snapshot store/files và kiểm chứng riêng.
- Profile có thời hạn; kiểm tra profile thực tế và ký/cài đè khi cần. [Personal Team có giới hạn 7 ngày](https://developer.apple.com/help/account/basics/about-your-developer-account).

## Giới hạn kiểm chứng

Kết nối/trust đã được giải quyết và app chạy được. Bộ UI test mới có thể chờ người dùng xác thực Enable UI Automation sau phiên làm việc dài. Trạng thái mới nhất nằm trong verification và plan; không dùng Simulator/TestFlight thay cho iPhone.

## Build cho iPhone 12 Pro Simulator

Đã kiểm chứng ngày 2026-11-02 trên iOS18.6, simulator `Noted iPhone 12 Pro` (`7D44052B-6FFC-4464-82CA-2769CEF28163`). Project mặc định chỉ bật iphoneos; ghi đè tạm thời khi build simulator:

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/noted-iphone12pro-simulator \
  SUPPORTED_PLATFORMS='iphoneos iphonesimulator' \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
xcrun simctl install 7D44052B-6FFC-4464-82CA-2769CEF28163 \
  /private/tmp/noted-iphone12pro-simulator/Build/Products/Debug-iphonesimulator/Noted.app
xcrun simctl launch 7D44052B-6FFC-4464-82CA-2769CEF28163 dev.nguyenhoanghai861.Noted
```

Giữ ad-hoc signing cho simulator: `CODE_SIGNING_ALLOWED=NO` bỏ simulated App Group entitlement và khiến thư viện báo không truy cập được vùng lưu chung. Bản ký ad-hoc đã xác nhận có `group.dev.nguyenhoanghai861.Noted` trong `Noted.app-Simulated.xcent` và mở được màn Thư viện. Không cần đổi App Group hay provisioning cho iPhone thật.

Chạy UI test trên **một simulator riêng cho mỗi phiên** (ví dụ tạo bằng `xcrun simctl create "Test iPhone 12 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-12-Pro com.apple.CoreSimulator.SimRuntime.iOS-18-6`) và thêm `-parallel-testing-enabled NO`. Hai lệnh `xcodebuild test` cùng lúc trên một simulator sẽ kill runner của nhau (“Test crashed with signal kill”); xem [retest 2026-11-03](evidence/20261103-paper-phase5-6-retest/summary.md).
