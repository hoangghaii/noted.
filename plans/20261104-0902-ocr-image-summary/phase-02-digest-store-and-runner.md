# Phase 02 — Kho digest & runner

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 01. Ưu tiên cao. Overview: [plan.md](plan.md).

> 2026-11-05: `IntelligenceStore` (`NotedLibrary/Intelligence/intelligence.store`, schema v1, chỉ có `LinkDigest`) đã được tạo ở [Phase 03 Đọc hiểu link](../20261104-2113-link-understanding/phase-03-store-and-runner.md). Phase này chỉ thêm `ImageDigest` vào `IntelligenceSchemaV1.models` → tăng `schemaVersion` kèm migration có test (store là dữ liệu dẫn xuất, version lạ hiện bị reset).

## Mục tiêu

Lưu bản tóm tắt ảnh ở store riêng và chạy nền tuần tự sau OCR, không đụng tới `library.store`.

## File ảnh hưởng

- Create (đề xuất) `Noted./Noted/Core/Intelligence/IntelligenceStore.swift`: mở `intelligence.store` với `ModelContainer` và schema version riêng. Store hỏng thì đổi tên file hỏng, tạo store mới, xếp lại job. Tên file và cách phục hồi khớp spec Phase 02 của [plan Lớp AI](../20261029-1623-smart-topic-groups/phase-02-intelligence-store-and-pipeline.md), để plan đó mở rộng chứ không tạo lại.
- Create (đề xuất) `Noted./Noted/Core/Digest/ImageDigest.swift`: `@Model` gồm
  - `itemID` (unique), `fingerprint`, `engineVersion`;
  - `kind`, `title?`, `summary?`, `facts` (JSON mảng `{type, value}`);
  - `source` extractive|api, `status` pending|running|complete|insufficientText|failed;
  - `attempts`, `updatedAt`.
- Create (đề xuất) `Noted./Noted/Core/Digest/DigestRunner.swift`: chạy tuần tự, `@MainActor @Observable`, theo pattern của `EnrichmentRunner`.
- Modify `Noted./Noted/App/LibraryLifecycleView.swift`: chạy `DigestRunner` sau `EnrichmentRunner` khi app foreground và sau capture.
- Modify `Noted./Noted/Core/Persistence/LibraryStore.swift`: khi xóa hẳn item thì xóa digest tương ứng. Có thể dùng hook/callback, hoặc dọn lúc khởi động.
- Create (đề xuất) `Noted./NotedTests/DigestPipelineTests.swift`.

## Bước

- [ ] Fingerprint = SHA-256 của `attachment.checksum` + `engineVersion`. Pin, trash, tag, collection hay sửa tiêu đề đều không làm digest chạy lại.
- [ ] Runner chọn item có `kind == "image"`, `ocrStatus == "complete"`, chưa vào trash, và chưa có digest hoặc digest có fingerprint khác. Ưu tiên mục mới lưu trước.
- [ ] Mỗi lần xử lý 1 ảnh, theo 3 bước:
  - lấy snapshot (URL attachment, id, fingerprint) trên main actor;
  - OCR có cấu trúc + `DigestGenerator` chạy ngoài main actor;
  - commit trên main actor sau khi kiểm tra item còn tồn tại, chưa vào trash, fingerprint chưa đổi và `!store.isDataOperationInProgress`.
- [ ] Vòng đời:
  - `running` sau crash → `pending`;
  - retry tối đa 3 lần;
  - text sau làm sạch < ~40 ký tự → `insufficientText`, không retry;
  - app vào background thì dừng nhận ảnh mới.
- [ ] Đổi `engineVersion` → toàn bộ digest chạy lại.
- [ ] Ở phase này dùng một `DigestGenerator` tạm, trả `kind` + câu đầu tiên. Phase 03 thay bằng bản thật.
- [ ] Không log text OCR hay nội dung digest.

## Acceptance

- Unit test xanh cho: kết quả cũ bị bỏ khi fingerprint đổi hoặc item vào trash, phục hồi sau crash, retry có giới hạn, xóa item thì digest bị dọn, store hỏng phục hồi được.
- Xóa file `intelligence.store` → app vẫn mở được và rebuild đủ digest cho 27 ảnh.
- `library.store` và checksum attachment không đổi sau khi runner chạy (test so sánh trước và sau).

## Rủi ro

- Hai store lệch nhau, ví dụ digest của item đã xóa → lọc theo item còn tồn tại và dọn khi khởi động.
- Runner chạy cùng lúc với backup → kiểm tra `isDataOperationInProgress` trước khi commit, giống `EnrichmentRunner`.

Quay lui: không khởi động runner và xóa `intelligence.store`. `library.store` không bị ảnh hưởng.
