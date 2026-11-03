# Phase 02 — Dữ liệu local bền vững

Trạng thái: nguồn đã triển khai; 11 recovery tests và 34 unit tests đạt trên iPhone ngày 2026-10-28. Đã kiểm chứng thủ công lưu note, link, batch ba ảnh và mở lại khi Airplane Mode bật/Wi-Fi tắt. Lỗi dung lượng thực còn mở. Phụ thuộc thiết kế: [01](phase-01-device-and-share-gate.md).
Mục tiêu: một đường lưu chung, phục hồi được khi gián đoạn.

## Thiết kế

App chính là writer SwiftData duy nhất; extension chỉ ghi staging App Group.
`Item`: UUID, captureID duy nhất, type, title/body/originalURL, createdAt/updatedAt, pinned, trashedAt, collection/tag và enrichment status.
`Attachment`: UUID, itemID, relative path, type, byte count, checksum, thumbnail path.
Giữ bản gốc; trường chuẩn hóa chỉ phục vụ search. Collection một cấp, mỗi item tối đa một collection.

Batch: `<batchID>.partial/` → copy đủ file và manifest versioned → validate → atomic rename `<batchID>.ready/`.
Chỉ báo lưu sau khi file/manifest ready ghi thành công. Import copy vào originals ổn định, commit metadata, rồi cleanup staging.
Không giả định transaction bao trùm filesystem và database: dùng captureID/checksum, recovery journal và retry idempotent.
Ảnh trong cùng batch có ID/thứ tự ổn định; cả batch hiển thị sau commit metadata thành công.

## File dự kiến — Create

- `Noted./Noted/Core/Models/Item.swift`: model và quan hệ.
- `Noted./Noted/Core/Persistence/ModelStore.swift`: container/schema/migration.
- `Noted./Shared/CaptureEnvelope.swift`: manifest/identity/version.
- `Noted./Shared/CaptureQueue.swift`: staging commit.
- `Noted./Noted/Core/Storage/AttachmentStore.swift`: originals/checksum/paths.
- `Noted./Noted/Core/Capture/CaptureImporter.swift`: serial import/recovery.
- `Noted./NotedTests/CaptureRecoveryTests.swift`: fault/retry tests.

## Các bước

- [x] Chốt schema v1 và migration strategy; không lưu blob ảnh lớn trong model.
- [x] Tạo file store, kiểm tra path tương đối và checksum; thumbnail tách khỏi originals.
- [x] Queue ghi temporary files rồi ready; batch thiếu file không xác nhận thành công.
- [x] Import một writer; retry sau file copy hoặc metadata commit không nhân đôi.
- [x] Reconcile khi launch/foreground; không tự xóa nguồn đang cần phục hồi.
- [x] Partial/failed batch có trạng thái và retry/discard chủ động; không trộn vào Library.
- [ ] Note update save lỗi giữ draft; không tự reset database khi mở store thất bại.
- [x] File protection phù hợp; cache tái tạo được tách khỏi backup; không log nội dung.
- [x] Fault injection Debug/tests ở trước/sau ready, copy originals, metadata commit và cleanup.

## Kiểm chứng và acceptance

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<IPHONE_UDID>' -only-testing:NotedTests/CaptureRecoveryTests test
```

- [x] Note, URL, batch ba ảnh còn đủ sau terminate/relaunch và offline. Người dùng xác nhận đủ 5 mục, 3 ảnh mở được; [bằng chứng](../../docs/evidence/20261028-iphone12pro/phase2-offline-manual.json).
- [x] Retry batch không đổi số item/checksum.
- [x] Trước ready không báo thành công; sau ready phục hồi đủ batch.
- [x] Crash sau metadata commit/trước cleanup không tạo bản sao.
- [x] File thiếu/hỏng không tạo item thành công có attachment mất; dữ liệu cũ nguyên vẹn.
- [ ] Lỗi dung lượng/save hiển thị đúng; queue không bị xóa như đã hoàn tất.
- [ ] Thumbnail tái tạo được, originals không bị thay thế.

## Rủi ro và quay lui

Stream/copy file thay vì decode nhiều ảnh trong extension. Snapshot store/files khi writer đã đóng trước migration; không cho bản app cũ mở schema mới.
Không rollback bằng xóa app/database. Giữ snapshot, queue và journal.
Còn mở: giới hạn batch/bytes theo phase 01 và chính sách phục hồi partial.
