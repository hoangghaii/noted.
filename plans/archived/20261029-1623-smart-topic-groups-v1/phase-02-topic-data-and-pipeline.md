# Phase 02 — Dữ liệu và pipeline

Ngày 2026-10-29. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc phase 01; ưu tiên cao.

## File ảnh hưởng

- Create `Noted./Noted/Core/Models/Topic.swift` — Topic, item assignment/override và alias/merge (đường dẫn dự kiến).
- Create `Noted./Noted/Core/Topics/TopicGroupingService.swift` — Nhận nhóm, discovery, stable IDs (đường dẫn dự kiến).
- Create `Noted./Noted/Core/Topics/TopicRunner.swift` — Job tuần tự, fingerprint, cancel/retry/cache (đường dẫn dự kiến).
- Modify `Noted./Noted/Core/Persistence/ModelStore.swift` — Đăng ký model và migration không mất dữ liệu.
- Modify `Noted./Noted/Core/Persistence/LibraryStore.swift` — Single-writer topic mutations và lifecycle.
- Modify `Noted./Noted/App/LibraryLifecycleView.swift` — Gắn runner launch/foreground sau OCR/preview.
- Modify `Noted./Noted/Core/Backup/BackupManifest.swift` — Version mới cho tên nhóm/override; v1 vẫn import được.
- Modify `Noted./Noted/Core/Backup/BackupService.swift` — Import/export topic ID remapping, merge và tombstones.
- Create `Noted./NotedTests/TopicLifecycleTests.swift` — Stale result, retry, migration, backup và overrides (đường dẫn dự kiến).

## Bước thực hiện và kiểm chứng

- [ ] Đọc schema/store version hiện có, lập migration additive. Topic dùng UUID ổn định, normalized name và mô tả; assignment tách generated và manual override (kể cả manual unknown/exclusion), fingerprint và engineVersion.
- [ ] Cache vector dạng versioned sidecar atomic, key itemID/fingerprint/engine. Không đưa vector vào backup; rebuild an toàn. Metadata cache hỏng không làm store thất bại.
- [ ] Dùng source text giữ dấu cho model; chuẩn hóa tìm tên/alias riêng. Chunk dài theo tokenizer, giữ giới hạn và pooling nhất quán. Không lưu API key/payload cá nhân vào log.
- [ ] TopicRunner chạy 1 inference một lúc, snapshot ngoài actor chính, commit trên LibraryStore; dừng khi backup lock, item bị xóa/trash hoặc fingerprint thay đổi. OCR/preview xong thì requeue đúng item; pin không re-embed.
- [ ] Job pending/running/complete/failed/insufficientText; running sau crash → pending. Retry có giới hạn/backoff; lỗi không kẹt vòng lặp. Mất mạng giữ cache và capture bình thường. AI local dừng inference mới khi background, không hứa chạy khi app tắt.
- [ ] Giữ nhóm/override ổn định qua thêm dữ liệu, filter và relaunch. Quy tắc deterministic tie-break và centroid chỉ cập nhật sau commit; manual override thắng mọi kết quả AI về sau.
- [ ] Thêm rename/move/merge/dismiss topic proposal; merge giữ alias và chuyển assignment atomically, không thay collection/tag/original. Người dùng có thể tạo topic với tên/mô tả/ví dụ.
- [ ] Backup version mới bảo toàn topic tên/sửa tay và mapping khi xung đột; đọc v1 như chưa có topic. Generated/cache có thể bỏ để rebuild; không âm thầm bỏ user corrections. Xác định fingerprint backup để derived updates không tạo bản duplicate.

Acceptance: migration trên bản sao store cũ giữ item/checksum; relaunch giữ nhóm/sửa tay; edit/OCR stale không commit; trash ẩn, restore có nhóm, delete cleanup cache; API/local failure giữ thư viện dùng được; v1 import và version mới roundtrip giữ manual overrides.

Quay lui: tắt runner/grouped UI, giữ schema additive và dữ liệu; không cài binary cũ nếu schema không tương thích, không uninstall.
