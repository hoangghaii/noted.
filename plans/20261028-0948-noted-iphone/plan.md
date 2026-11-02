# Noted — MVP cá nhân trên iPhone

Lập ngày 2026-10-28. Trạng thái: đã triển khai nguồn; nghiệm thu thiết bị còn mục chưa kiểm chứng. Workspace: `/Users/nhhai7/LocalData/Noted.`

## Mục tiêu và phạm vi

Lưu nhanh ảnh, link, note; nội dung gốc nằm trên iPhone; tìm lại, phân loại và backup. Build/cài trực tiếp bằng Xcode lên iPhone thật. Không dùng Simulator, TestFlight, backend, đăng nhập, đồng bộ hoặc tính năng cộng tác.

## Quyết định triển khai

- SwiftUI + SwiftData cho metadata, file ảnh gốc riêng, thumbnail tái tạo được.
- Share Extension ghi batch `.partial` rồi `.ready` vào App Group; app chính là writer SwiftData duy nhất. Dùng lại `Shared/ShareGateStore.swift` cho queue thay vì thêm loại envelope song song.
- ID/receipt cố định giúp retry sau gián đoạn không nhân đôi hoặc hồi sinh item đã xóa. Import queue khi launch/foreground; không hứa xử lý khi app đóng.
- Search local có chuẩn hóa tiếng Việt; OCR Vision và link preview chạy sau capture. Ảnh/note không được gửi tới cloud; URL preview chỉ tải metadata của link công khai.
- Backup package `.notedbackup` v1 với manifest/checksum, export/import qua Files và merge không ghi đè. Giao diện ở `Noted/App/DataManagementView.swift`.

## Tiến độ theo phase

| Phase | Nguồn đã triển khai | Nghiệm thu còn lại |
|---|---|---|
| [01 — Thiết bị và Share](phase-01-device-and-share-gate.md) | Build/ký/cài/mở iPhone; Safari link/text và Photos ảnh được người dùng xác nhận; ảnh còn sau cài đè | Notes “Gửi bản sao” chỉ cung cấp URL, nên lưu link; text relaunch, đo batch |
| [02 — Dữ liệu bền vững](phase-02-durable-local-data.md) | Model, originals, queue, receipt, recovery; 11 recovery tests đạt; lưu/mở lại offline thật với note, link, batch ba ảnh | Thử lỗi dung lượng trên máy; checksum ảnh sau relaunch |
| [03 — Capture](phase-03-capture-and-share.md) | Note/link/PhotosPicker/paste; decoder tests 4/4, Safari URL/text Share, Photos một/ba ảnh (ba ảnh còn mở sau khi xóa nguồn) đạt trên iPhone | Kiểm chứng preview UI; đo thao tác/thời gian |
| [04 — Library](phase-04-library-and-collections.md) | Library pagination/empty/add/filter/pin; detail/share sheet; collection; thumbnail/fallback; journal recovery; 42 unit tests; 4/6 UI flows đạt | Restore UI; editor save-error/import; vùng chạm |
| [05 — Search/OCR](phase-05-search-and-ocr.md) | Search tiếng Việt, filter/debounce, OCR local và preview; 5 tests đạt | URL network edge cases, OCR relaunch từ tiến trình bị kill |
| [06 — Backup/kiểm chứng](phase-06-backup-and-device-validation.md) | Backup v1 + Files roundtrip thật trước và sau cài đè; 6 backup tests đạt; README/thiết bị | Export bị ngắt, capture trong export, toàn bộ nghiệm thu Share/offline còn mở |

Tổng cộng **34 unit tests đạt trên iPhone 12 Pro** sau sửa phase 02, cộng 4 UI test runs đã đạt trước đó (note/relaunch/search, Files roundtrip trước/sau update, ảnh hết kẹt spinner). Chi tiết và bằng chứng: [verification](../../docs/verification.md). Không diễn giải unit test là E2E cho các trường hợp chưa chạy.

Cập nhật phase 04 ngày 2026-10-29: **39 unit tests đạt**, gồm 8 lifecycle tests; **1 UI editor test đạt** qua đóng editor/relaunch/khôi phục draft/lưu. Đây là lượt chạy mới trên cùng iPhone vật lý; không cộng số tests của các lần chạy với nhau. Phase 04 vẫn chưa nghiệm thu toàn bộ.

## Điều kiện hoàn tất chưa đạt đầy đủ

- Safari link/text và Photos Share đã được người dùng xác nhận lưu; ảnh Photos còn sau cài đè. Lưu trong app khi offline thực đã đạt với note, link, batch ba ảnh; Share text relaunch còn mở. Notes chỉ cung cấp URL trong lần đo, cần Sao chép → Dán để lưu bản text độc lập.
- Cài đè cùng bundle ID giữ payload đã chia sẻ; không uninstall để sửa signing.
- Kiểm chứng các luồng Library/detail/tổ chức và bàn phím ở cấu hình mặc định trên iPhone. Workload 500 item, VoiceOver, chữ lớn và dark mode được bỏ khỏi phạm vi theo yêu cầu người dùng ngày 2026-10-29.
- Xuất/nhập backup đã đạt qua Files, nhưng các fault case thời điểm export còn cần thử.

Thiết bị: Hải - iPhone 12 Pro (iPhone13,3), iOS 27.0.1; Xcode 27.0, SDK 27.0. Workspace chưa là Git repository; `Config/Local.xcconfig` chứa team ký riêng và được ignore. Hướng dẫn build/cài/backup: [device setup](../../docs/device-setup.md).
