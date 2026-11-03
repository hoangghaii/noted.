# Phase 02 — Kho AI & pipeline

Ngày 2026-11-03. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 01. Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Hạ tầng dùng chung cho Phase 03–05: store dữ liệu AI riêng, runner, cache vector, backup giữ phần người dùng sửa tay. Không đổi schema `library.store`.

## File ảnh hưởng

- Create (đề xuất) `Noted./Noted/Core/Intelligence/IntelligenceModels.swift` — các model:
  - `Topic` (UUID, name, normalizedName, description, aliases, createdBy user|suggested, mergedInto?);
  - `TopicAssignment` (itemID, primaryTopicID?, secondary[≤2], source generated|manual, manualUnknown, fingerprint, engineVersion, score);
  - `TopicExample` (topicID, itemID — ví dụ đã xác nhận, dùng làm vector đại diện);
  - `TagSuggestion` (itemID, tags, dismissed[]);
  - `GeneratedText` (itemID, title?, summary?, source extractive|api, fingerprint);
  - `IntelligenceJob` (itemID, status pending|running|complete|failed|insufficientText, attempts, nextRetryAt).
- Create (đề xuất) `Noted./Noted/Core/Intelligence/IntelligenceStore.swift` — mở `intelligence.store` với schema version riêng. Store hỏng: đổi tên file hỏng, tạo store mới, xếp lại job, **không** chạm `library.store`.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/VectorCache.swift` — sidecar nhị phân có version, ghi atomic, key `itemID/fingerprint/engineVersion`, gồm vector chữ + feature print ảnh. Không đưa vào backup.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/IntelligenceRunner.swift` — job tuần tự.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/ContentFingerprint.swift` — SHA-256 của các trường nội dung.
- Modify `Noted./Noted/App/LibraryLifecycleView.swift` — khởi động runner sau EnrichmentRunner, khi foreground, sau capture/edit.
- Modify `Noted./Noted/Core/Persistence/LibraryStore.swift` — phát tín hiệu thay đổi item (capture/edit/trash/restore/delete). Khi delete thì dọn assignment/cache. Thêm hàm `applyGeneratedTitle` (không set `userEditedTitle`).
- Modify `Noted./Noted/Core/Backup/BackupManifest.swift` — `version = 2` với section optional `intelligence`: topics, aliases, merges, assignment manual, manualUnknown, examples, tag đã bỏ qua. v1 vẫn đọc được (coi như chưa có AI).
- Modify `Noted./Noted/Core/Backup/BackupService.swift` — export/import section trên, remap topic ID khi trùng tên, giữ manual override. Dữ liệu generated/cache không backup, sẽ rebuild sau import.
- Create (đề xuất) `Noted./NotedTests/IntelligencePipelineTests.swift`.

## Bước

- [ ] Viết model và store riêng. Test mở/đóng, store hỏng phục hồi được, `library.store` và checksum attachment không đổi.
- [ ] Fingerprint: title chỉ tính khi `userEditedTitle` (tránh vòng lặp: AI ghi title → fingerprint đổi → chạy lại), cộng body, URL đã bỏ query/fragment, OCR, tags. Pin/trash/collection không làm fingerprint đổi.
- [ ] Runner:
  - mỗi lần 1 inference; snapshot immutable lấy trên main actor, inference chạy ngoài main actor, commit lại trên main actor;
  - trước khi commit kiểm tra item còn tồn tại, chưa vào trash, fingerprint chưa đổi, không có backup/data operation đang chạy (`isDataOperationInProgress`).
- [ ] Vòng đời job:
  - job `running` sau crash → `pending`;
  - retry tối đa 3 lần, backoff;
  - text không đủ → `insufficientText`, không retry.
  - Background: dừng nhận inference mới. Không hứa chạy khi app đã tắt.
- [ ] Thứ tự ưu tiên: mục mới lưu và mục vừa sửa trước, phần thư viện cũ chạy sau. Hiển thị tiến độ “Đang phân tích 12/240”.
- [ ] Đổi `engineVersion` → xếp lại toàn bộ job, giữ nguyên manual.
- [ ] `applyGeneratedTitle`: chỉ ghi khi `title` trống, hoặc khi `title` đang trùng đúng bản `GeneratedText.title` trước đó, và `!userEditedTitle`. Gọi `rebuildSearchDocument()`. Không đổi `updatedAt`, để khỏi làm EnrichmentRunner tưởng mục đã bị sửa.
- [ ] Backup v2: kiểm tra 3 chiều v1→mới, mới→mới, import trùng không tạo bản duplicate. Bản dẫn xuất không làm thay đổi fingerprint của backup.
- [ ] Không log nội dung note, payload hay key.

## Acceptance

- Unit test xanh cho: stale result bị bỏ, retry có giới hạn, crash recovery, delete dọn cache, roundtrip backup v1/v2.
- Xóa `intelligence.store` + cache → app vẫn mở, rebuild được, override đã khôi phục từ backup.
- Cài đè trên iPhone giữ nguyên item/checksum.

## Rủi ro

- Hai store lệch nhau, ví dụ assignment trỏ tới item đã bị xóa → dọn khi khởi động và lọc theo item còn tồn tại.
- Ghi title làm vòng lặp fingerprint → đã loại title AI khỏi fingerprint.

Quay lui: tắt runner, xóa `intelligence.store`. `library.store` không đổi, nên an toàn.
