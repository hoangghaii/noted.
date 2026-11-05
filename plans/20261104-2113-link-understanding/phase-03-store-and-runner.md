# Phase 03 — Kho LinkDigest & runner

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 02. Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Lưu bản đọc hiểu link ở `intelligence.store` và chạy nền tuần tự, không đụng tới `library.store`.

## File ảnh hưởng

- Create hoặc Modify `Noted./Noted/Core/Intelligence/IntelligenceStore.swift`: nếu plan ảnh chưa tạo thì tạo theo đúng spec [Phase 02 Đọc hiểu ảnh](../20261104-0902-ocr-image-summary/phase-02-digest-store-and-runner.md) (tên file, schema version, phục hồi store hỏng); nếu đã có thì thêm entity.
- Create (đề xuất) `Noted./Noted/Core/Digest/LinkDigest.swift`: `@Model` gồm
  - `itemID` (unique), `fingerprint`, `engineVersion`;
  - `title?`, `siteName?`, `author?`, `summary?`, `textForEmbedding?`;
  - `source` extractive|api, `status` pending|running|complete|titleOnly|loginWall|unreachable|failed (`titleOnly` thêm theo Phase 01/02);
  - `attempts`, `fetchedAt`, `updatedAt`.
- Create (đề xuất) `Noted./Noted/Core/Digest/LinkDigestRunner.swift`: `@MainActor @Observable`, theo pattern của `EnrichmentRunner` và `DigestRunner`.
- Modify `Noted./Noted/App/LibraryLifecycleView.swift`: chạy runner sau `EnrichmentRunner` khi app foreground và sau capture.
- Modify `Noted./Noted/Core/Persistence/LibraryStore.swift`: xóa hẳn item thì xóa digest (hoặc dọn lúc khởi động, dùng chung cơ chế với ảnh).
- Create (đề xuất) `Noted./NotedTests/LinkDigestPipelineTests.swift`: loader giả, không gọi mạng.

## Bước

- [ ] Fingerprint = SHA-256 của URL gốc đã bỏ fragment + `engineVersion`. Pin, trash, tag hay sửa tiêu đề không làm digest chạy lại.
- [ ] Runner chọn `kind == "link"`, chưa vào trash, chưa có digest hoặc fingerprint khác; mục mới lưu trước.
- [ ] Mỗi lần 1 link: snapshot trên main actor → tải và trích xuất ngoài main actor → commit sau khi kiểm tra item còn tồn tại, fingerprint chưa đổi và `!store.isDataOperationInProgress`.
- [ ] Vòng đời:
  - `running` sau crash → `pending`;
  - lỗi mạng retry tối đa 3 lần với backoff, sau đó `unreachable`;
  - `loginWall` không retry tự động; có nút “Thử đọc lại” trong Detail;
  - offline thì dừng, chạy tiếp khi có mạng.
- [ ] Tiêu đề: nếu `!userEditedTitle` và title hiện tại đang là host hoặc `<title>` thô, cập nhật bằng `digest.title` qua đường ghi tiêu đề hiện có. Tiêu đề người dùng sửa thì không bao giờ ghi đè.
- [ ] Không log URL đầy đủ hay nội dung trang.

## Acceptance

- Unit test xanh: bỏ kết quả cũ khi fingerprint đổi hoặc item vào trash, phục hồi sau crash, retry có giới hạn, `loginWall` không retry, xóa item thì digest bị dọn, store hỏng phục hồi được.
- Xóa `intelligence.store` → app vẫn mở được và rebuild đủ digest cho 21 link.
- `library.store` không đổi ngoài tiêu đề được phép (test so sánh trước và sau).

## Rủi ro

- Hai plan cùng tạo `IntelligenceStore` → plan nào làm trước thì tạo; plan sau chỉ thêm entity và tăng schema version theo migration có kiểm thử.
- Runner tải mạng khi người dùng không muốn → chỉ chạy khi app mở, tôn trọng Low Data Mode (`allowsConstrainedNetworkAccess = false`).

Quay lui: không khởi động runner, xóa entity `LinkDigest`; `library.store` không bị ảnh hưởng.
