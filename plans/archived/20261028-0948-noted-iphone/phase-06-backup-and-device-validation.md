# Phase 06 — Backup/restore và nghiệm thu iPhone

Trạng thái: nguồn backup v1 đã triển khai; 6 backup tests và Files export/import UI đạt trên iPhone; nghiệm thu toàn bộ thiết bị còn mở. Phụ thuộc thiết kế: [05](phase-05-search-and-ocr.md).
Mục tiêu: bảo toàn dữ liệu và có evidence để sử dụng cá nhân.

## Thiết kế

Package `.notedbackup`: schema version, metadata JSON, originals, checksum; không cần ZIP dependency.
Bao gồm collection/tag/trash; thumbnail/search document tái tạo được, không export secret/device identifier.
Trước snapshot nhập ready batches, tạm khóa mutation; extension vẫn có thể ghi queue mới. Phân biệt dữ liệu có trong snapshot và batch đến sau cutoff; không tuyên bố đã backup phần chưa nhập.
Export lỗi/hủy không bàn giao package hoàn tất. Batch đang lỗi phải báo trong kết quả.
Import merge, không replace; UUID/content hash tránh trùng. Collision khác nội dung giữ cả hai, dùng mapping ổn định theo source ID/hash để import lặp không tạo thêm bản sao conflict; remap collection/attachment references tương ứng.
Validate trước commit; staging/journal/resume cho filesystem/database, không ghi đè note cũ.
Backup chưa mã hóa ở MVP; UI nói rõ trước export để chọn nơi lưu phù hợp.

## File dự kiến

| Hành động | Đường dẫn tuyệt đối | Mục đích |
| --- | --- | --- |
| Create | `Noted./Noted/Core/Backup/BackupManifest.swift` | Schema/checksums |
| Create | `Noted./Noted/Core/Backup/BackupService.swift` | Export/import staging/journal |
| Create | `Noted./Noted/Features/Settings/DataManagementView.swift` | Backup UI/storage usage |
| Create | `Noted./Noted/Supporting/Info.plist` | UTType backup package |
| Create | `Noted./NotedTests/BackupRoundTripTests.swift` | Round-trip/corruption/collision |
| Modify | `Noted./Noted.xcodeproj/project.pbxproj` | Document type/build config |
| Modify | `Noted./docs/device-setup.md` | Cài đè/ký lại/backup |
| Modify | `Noted./docs/verification.md` | Evidence/giới hạn cuối |

## Các bước

- [ ] Package v1 chỉ nhận relative path; giới hạn count/size; reject traversal/symlink/missing file/checksum sai/unsupported schema.
- [ ] Export snapshot nhất quán; báo số item và cutoff/pending batches; không mất capture đến trong lúc export.
- [ ] Files exporter/importer round-trip với provider thực; hỗ trợ security-scoped access khi cần.
- [ ] Import validate toàn bộ trước commit; collision không overwrite, retry idempotent cả conflict copies.
- [ ] Test gián đoạn export/import; journal tiếp tục được, nguồn giữ nguyên.
- [ ] Snapshot store/files trước migration; bản cũ không mở schema mới; hướng dẫn phục hồi an toàn.
- [ ] Round-trip vào store kiểm chứng riêng trên cùng iPhone, không xóa/gỡ thư viện cá nhân.
- [ ] Chạy lại Safari/Photos/text, offline, terminate, trash/restore, lỗi dung lượng bằng fault injection.
- [x] Build/cài đè cùng bundle ID; người dùng xác nhận ảnh cũ còn sau cập nhật.
- [x] Export/import lại qua Files sau cập nhật; 1 UI test đạt trên cùng iPhone, không gỡ app.
- [ ] Review capture commit/recovery/file deletion/privacy log; hoàn thiện hướng dẫn tự build/cài/backup.

## Kiểm chứng

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'platform=iOS,id=<IPHONE_UDID>' build
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<IPHONE_UDID>' test
```

Xcode Product → Run là đường cài chính. Không dùng Simulator hoặc generic build thay evidence device.
Evidence ghi device/iOS/Xcode, build, expected/actual, pass/fail/blocked và artifact khử dữ liệu cá nhân.

## Acceptance

- [ ] Round-trip giữ count/text/URL/collection/tag/trash và checksum originals; conflict có mapping rõ.
- [ ] Import hai lần không trùng, bao gồm tình huống collision khác nội dung.
- [ ] Backup hỏng/schema mới bị từ chối trước thay đổi thư viện.
- [ ] Crash export không tạo package hoàn tất giả; crash import resume không mất/trùng.
- [ ] Capture đến trong export vẫn còn queue và được phân biệt với snapshot đã xuất.
- [ ] Package lưu/mở lại qua Files thành công trên iPhone thật và store thử riêng.
- [x] Cài đè giữ ảnh đã Share; không uninstall/xóa container.
- [ ] Phase 01–05 đạt với evidence; ghi các lỗi/giới hạn còn lại, không đánh Complete giả.
- [ ] Hướng dẫn signing expiry, build/cài/backup rõ; không phụ thuộc backend/TestFlight/Simulator.

## Rủi ro, quay lui và câu hỏi

Backup chứa dữ liệu cá nhân chưa mã hóa, không upload tự động. Kiểm tra dung lượng staging trước export.
Không lấp đầy iPhone cá nhân để test thiếu dung lượng; fault-inject writer trên máy thật.
Import/migration lỗi giữ bản gốc/journal, dừng mutation, phục hồi snapshot/backup đã xác minh; không gỡ app.
Còn mở: provider Files/nơi lưu backup và dung lượng thực tế; reminder backup để sau MVP.
