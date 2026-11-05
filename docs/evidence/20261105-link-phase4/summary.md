# Đọc hiểu link — Phase 04 (2026-11-05)

Đã triển khai thẻ, Detail, gán nhãn DEBUG và evaluator dùng chung LinkDigest. Không đổi schema dữ liệu; không đưa digest vào backup. Search trong summary chưa làm (tùy chọn).

## Kiểm chứng

- Build Debug iPhone không ký: đạt. Lượt sandbox đầu lỗi SwiftData macro plugin; chạy ngoài sandbox đạt. Log: `/private/tmp/noted-phase4-build.log`.
- `NotedTests/LinkDigestPipelineTests` + `NotedTests/IntelligenceEngineTests` trên iPhone 12 Pro: 38 test, 0 lỗi, 2 skip opt-in (`testE5IsolatedResourceGateOnDevice`, `testSyntheticSpikeReportOnDevice`). Log: `/private/tmp/noted-phase4-tests.log`.
- UI lượt đầu: thẻ/Detail tổng hợp đạt; ca gán nhãn cũ timeout khi chờ report 30 s. `xcodebuild` kẹt sau khi test body kết thúc, phải dừng tiến trình. Giữ lỗi này trong báo cáo; không coi lượt đó đạt.
- Lượt chẩn đoán tiếp theo: ca cũ đạt sau khi chờ computation riêng rồi cuộn Form; thẻ/Detail và Dynamic Type accessibility XXXL đạt. Test gán nhãn mới chưa tới được link sau các lần bấm Sau (video cho thấy vẫn ở mục ảnh). Fixture được đổi để có nhãn tổng hợp cho 3 mục đầu, mở trực tiếp link chưa gán nhãn; ca này chạy riêng đã đạt.
- Source cuối: `LinkDigestPipelineTests` + `IntelligenceEngineTests/testReportSchemaV4CarriesResourceFieldsWithoutLabels`: **24 test, 0 lỗi, 0 skip**. Log `/private/tmp/noted-phase4-tests-final.log`, bundle `/private/tmp/noted-phase4-device/Logs/Test/Test-Noted-2026.11.05_21-24-03-+0700.xcresult`.
- Lượt cuối **4/4 IntelligenceLabelingUITests đạt**, 0 lỗi, trên iPhone 12 Pro: test gán nhãn cũ, sheet đọc hiểu link, thẻ/Detail/login wall, accessibility XXXL. Log `/private/tmp/noted-phase4-ui-complete.log`; bundle `/private/tmp/noted-phase4-device/Logs/Test/Test-Noted-DeviceGate-2026.11.05_21-25-08-+0700.xcresult`. Thu sysdiagnose tắt bằng `-collect-test-diagnostics never`; không tắt test hay assertion.
- Build source cuối: **BUILD SUCCEEDED** (`/private/tmp/noted-phase4-build.log`). `git diff --check`: đạt. Không có lệnh type-check riêng cho Swift; Xcode build đã biên dịch app và extension.

Fixture UI chỉ bật qua `--link-digest-ui-fixtures` cùng thư viện thử `NOTED_PHASE4_RUN=<UUID>`. Nội dung mẫu dùng example.com, loader giả, không gọi mạng. Không đưa ảnh/nội dung/link cá nhân vào evidence.

## Hợp đồng báo cáo

JSON v4 thêm `linkDigestCoverage` và metric từng candidate cho `linksWithDigest` / `linksLoginWall`. Hai nhóm chỉ tính holdout được gán nhãn; độ chính xác không tính các dự đoán abstain. Không có prediction → precision null, không có mẫu → coverage null. Các field tài nguyên và nhãn giữ nguyên ý nghĩa.

## Giới hạn

Chưa nghe VoiceOver thủ công, chưa kiểm chứng dark mode toàn diện. Test accessibility kiểm tra nội dung đầy đủ trong cây accessibility, không thay cho nghe VoiceOver. Nghiệm thu chất lượng digest thật và đánh giá lại chủ đề thuộc Phase 06.

## Lệnh kiểm chứng

Thiết bị dùng UDID đã xác nhận qua `xcrun devicectl list devices`. Các lệnh thực tế dùng derived data `/private/tmp/noted-phase4-device` (test) và `/private/tmp/noted-derived` (build).

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/noted-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<UDID>' -derivedDataPath /private/tmp/noted-phase4-device -allowProvisioningUpdates -collect-test-diagnostics never -only-testing:NotedTests/LinkDigestPipelineTests -only-testing:NotedTests/IntelligenceEngineTests/testReportSchemaV4CarriesResourceFieldsWithoutLabels test
xcodebuild -project Noted.xcodeproj -scheme Noted-DeviceGate -destination 'platform=iOS,id=<UDID>' -derivedDataPath /private/tmp/noted-phase4-device -allowProvisioningUpdates -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:NotedUITests/IntelligenceLabelingUITests test
```

## Ảnh tổng hợp đã xem lại

- [Detail: tóm tắt, byline, nguồn, ngày đọc và đọc lại](detail-synthetic.png).
- [Sheet gán nhãn: bản đọc hiểu dưới URL](labeling-synthetic.png).
- [Thẻ ở cỡ chữ accessibility XXXL: summary mở rộng, có thể cuộn để đọc đầy đủ](accessibility-synthetic.png).

## Rà soát

Đã tự đọc diff và trace environment qua Root/Detail/sheet Dữ liệu → gán nhãn, runner retry, fingerprint và snapshots chạy ở MainActor trước khi chuyển dữ liệu Sendable vào evaluator. Không có file Swift mới cần thêm target; không sửa public format capture/backup, stored schema hay ID cấu hình. Không có suppression, test skip mới hoặc nội dung cá nhân trong diff.
