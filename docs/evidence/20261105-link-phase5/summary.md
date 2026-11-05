# Link Phase 05 — API text-only tùy chọn

Ngày 2026-11-05. Dữ liệu kiểm chứng tổng hợp; không gọi Groq thật, không nhập khóa thật. Người dùng chọn Groq trong phiên. Không đổi schema, Bundle ID/App Group, không uninstall hoặc xóa container.

## Phạm vi

- `RemoteTextGenerator` + `APIKeyStore`: mặc định tắt, endpoint HTTPS/model chỉnh được, Keychain `WhenUnlockedThisDeviceOnly`, không đồng bộ; 50 request/ngày, timeout request/resource 15 giây, retry tối đa hai lần cho 5xx, 429 dừng thêm request một giờ trong phiên.
- `RemoteLinkDigester`: cùng hàm tạo payload cho preview/runner, JSON domain/title/description/mainText ≤2.000 ký tự sau serialize, loại URL HTTP(S)/www trong text, bỏ qua loginWall/titleOnly. Prompt coi trang là dữ liệu, chỉ nhận đúng title≤80 và summary≤300. Nội dung sinh không được thực thi.
- Runner: fallback về trích xuất, source `api` khi hợp lệ; kiểm tra lại mục sau cả tải trang lẫn gọi API. Tắt hủy request, xóa task trong bộ nhớ, bỏ kết quả cũ kể cả khi bật lại. Không tạo cloud queue trên đĩa.
- Dữ liệu & backup → AI tùy chọn: toggle có consent, quản lý key, endpoint/model, bộ đếm và xem trước text. Link cũ tạo lại qua Chi tiết → Thử đọc lại.

## Cách kiểm chứng

Build biên dịch/type-check:

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/noted-derived CODE_SIGNING_ALLOWED=NO build
```

Unit/integration trên iPhone 12 Pro, iOS 27.0.1 (`<UDID>` lấy qua devicectl):

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<UDID>' -derivedDataPath /private/tmp/noted-phase5-device -allowProvisioningUpdates -collect-test-diagnostics never -only-testing:NotedTests/RemoteLinkDigesterTests -only-testing:NotedTests/LinkDigestPipelineTests -only-testing:NotedTests/LinkDigestTests -only-testing:NotedTests/BackupRoundTripTests test
```

UI test chỉ chạy màn được yêu cầu, thư viện và preferences fixture tách biệt:

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted-DeviceGate -destination 'platform=iOS,id=<UDID>' -derivedDataPath /private/tmp/noted-phase5-ui -allowProvisioningUpdates -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:NotedUITests/RemoteAISettingsUITests test
```

## Kết quả cuối

- Build/type-check generic iOS: **BUILD SUCCEEDED**. Swift compile đạt; không có lệnh type-check riêng. Còn warning AppIntents không có framework; clean build trước đó có warning có sẵn của Share API/AccentColor.
- Unit/integration iPhone: **61/61 đạt, 0 thất bại, 0 skip**, gồm `RemoteLinkDigesterTests` 14, `LinkDigestPipelineTests` 23, `LinkDigestTests` 18, `BackupRoundTripTests` 6. [Kết quả từng test](unit-results.txt).
- UI iPhone: **1/1 đạt**, kiểm tra mặc định tắt → mở consent/hủy → bật có xác nhận → tắt. [Kết quả](ui-results.txt), [screenshot cuối](ai-settings-iphone.png) đã mở xem, không thấy chữ bị cắt ở vùng đang hiển thị.
- `ruby scripts/update-project.rb`: đạt, file mới đã vào đúng target. `git diff --check`: đạt.
- URLProtocol giả kiểm tra đúng payload gửi qua POST body stream, key chỉ trong Authorization, 429/timeout/offline/schema sai fallback, không retry các lỗi này; 5xx tối đa ba lần tổng cộng. Có test hạn mức chung/persist, hủy/bật lại, runner API→extractive và grep package backup với khóa tổng hợp. Keychain thật trên iPhone kiểm chứng save/update/read/delete và accessibility device-only bằng service riêng, không chạm khóa người dùng.
- Không chạy toàn bộ test suite, UI Safari/Photos hoặc test Groq thật. Không xem các phần chưa chạy là đạt. Log đầy đủ/xcresult nằm ở `/private/tmp/noted-phase5-*`, không đưa diagnostics thiết bị vào Git.

## Các lỗi phát hiện trong quá trình kiểm chứng

- Build trong sandbox không chạy được Swift macro plugin. Chạy cùng lệnh ngoài sandbox thành công; không sửa source để né macro.
- UI locator chạm giữa hàng thay vì UISwitch con. Hierarchy chứng minh có switch con; locator được sửa để thao tác control thật.
- iOS 27 hiển thị confirmationDialog dạng popover không có nút Hủy. Đổi consent sang alert có nút Hủy rõ ràng; lượt UI test sau đó đạt.
- Sau khi nâng mock từ transport closure sang URLProtocol, test payload thất bại vì URLSession chuyển POST body thành `httpBodyStream` trên thiết bị. Bộ thu request test đọc stream thật thay vì chỉ kiểm tra `httpBody`.

## Rà soát và giới hạn

Đã tự rà call path, source marker, consent/cancellation, hạn mức, secret storage, backup và diff; bảo toàn các sửa đổi Phase 04 có trước phiên. Không có thay đổi `library.store`/schema hoặc dữ liệu ảnh. Không có API thật nên chưa xác minh tài khoản Groq/model bằng key, chất lượng tiếng Việt và so sánh người dùng trên đa số link. Chưa nghe VoiceOver/dark mode thủ công hoặc đo tài nguyên API trên mạng thật. Các phần này không được tính là đạt; phase ở trạng thái triển khai xong kỹ thuật, chờ nghiệm thu chất lượng.
