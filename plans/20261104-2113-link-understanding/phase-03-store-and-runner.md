# Phase 03 — Kho LinkDigest & runner

Ngày 2026-11-04. Trạng thái: Done. Review: nghiệm thu trên iPhone 12 Pro 2026-11-05 ([verification](../../docs/verification.md#2026-11-05--đọc-hiểu-link-phase-03-kho-linkdigest--runner-trên-iphone-12-pro)). Phụ thuộc Phase 02. Ưu tiên cao. Overview: [plan.md](plan.md).

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

- [x] Fingerprint = SHA-256 của URL gốc đã bỏ fragment + `engineVersion`. Pin, trash, tag hay sửa tiêu đề không làm digest chạy lại.
- [x] Runner chọn `kind == "link"`, chưa vào trash, chưa có digest hoặc fingerprint khác; mục mới lưu trước.
- [x] Mỗi lần 1 link: snapshot trên main actor → tải và trích xuất ngoài main actor → commit sau khi kiểm tra item còn tồn tại, fingerprint chưa đổi và `!store.isDataOperationInProgress`.
- [x] Vòng đời:
  - `running` sau crash → `pending`;
  - lỗi mạng retry tối đa 3 lần với backoff, sau đó `unreachable`;
  - `loginWall` không retry tự động; có nút “Thử đọc lại” trong Detail;
  - offline thì dừng, chạy tiếp khi có mạng.
- [x] Tiêu đề: nếu `!userEditedTitle` và title hiện tại đang là host hoặc `<title>` thô, cập nhật bằng `digest.title` qua đường ghi tiêu đề hiện có. Tiêu đề người dùng sửa thì không bao giờ ghi đè.
- [x] Không log URL đầy đủ hay nội dung trang.

## Tiến độ (2026-11-05)


- `Noted/Core/Intelligence/IntelligenceStore.swift`: `intelligence.store` + `schema-version.txt` (v1) trong `NotedLibrary/Intelligence/`. Store không mở được hoặc version lạ → đổi tên thành `intelligence.store.corrupt*` (giữ bản gần nhất), tạo store mới, `recoveredFromCorruption = true`. Không chạm `library.store`.
- `Noted/Core/Digest/LinkDigest.swift`: `@Model LinkDigest` theo spec, thêm `nextRetryAt` cho backoff; `LinkDigestState` (pending/running/complete/titleOnly/loginWall/unreachable/failed). Fingerprint = SHA-256(URL bỏ fragment + `\n` + `engineVersion`).
- `Noted/Core/Digest/LinkDigestRunner.swift`:
  - chọn link chưa vào trash, **đã xong preview** (`previewStatus` khác pending/running, để `EnrichmentRunner` không ghi đè tiêu đề digest), mục mới trước; mỗi run thử mỗi item tối đa 1 lần;
  - tải + trích xuất trong `Task.detached`, commit sau khi kiểm tra digest còn, item còn và chưa vào trash, fingerprint chưa đổi, `!isDataOperationInProgress`;
  - lỗi mạng: thử lại sau 1 phút, rồi 4 phút; lần thứ 3 lỗi → `unreachable`. `unsafeURL`/URL hỏng → `failed`, không retry;
  - offline/Low Data Mode (`URLError.networkUnavailableReason`, `.notConnectedToInternet`, `.dataNotAllowed`…) → dừng run, không tính lượt, `isOffline = true`;
  - `loginWall` không retry; `retry(itemID:)` cho nút “Thử đọc lại” (UI ở Phase 04);
  - dọn digest của item không còn trong thư viện ở đầu mỗi run (xóa hẳn, import backup); item trong trash giữ digest;
  - không log URL hay nội dung.
- Tiêu đề: chỉ ghi khi `!userEditedTitle` và tiêu đề hiện tại rỗng, bằng host, bằng `<title>` thô của chính trang vừa tải, hoặc bằng tiêu đề digest trước (khi engine/URL đổi). Không ghi với `loginWall`.
- `LinkMetadataService.fetchPage` đặt `allowsConstrainedNetworkAccess = false` (thêm tham số cho `BoundedMetadataDownload`, mặc định giữ hành vi cũ cho `title(for:)`).
- `LibraryLifecycleView`: `runPipelines()` = `EnrichmentRunner` rồi `LinkDigestRunner` ở mọi điểm kích hoạt cũ (mở app, foreground, capture/thay đổi item, đóng màn dữ liệu); `recoverInterrupted()` lúc mở; `NWPathMonitor` chạy lại khi có mạng nếu run trước dừng vì offline; banner “Đang đọc nội dung link…”. Fixture DEBUG (`NOTED_MOCK_FIXTURE`, `NOTED_PHASE4_RUN`) không bật runner.
- Lệch so với đề xuất:
  - **Không sửa `permanentlyDelete`**: dọn digest lúc runner chạy (mỗi lần thư viện đổi), phủ cả trường hợp import backup thay item. Plan cho phép “dọn lúc khởi động”.
  - **Ghi tiêu đề qua `LibraryStore.applyGeneratedTitle`** (mới, theo spec Phase 02 plan Lớp AI) thay vì `update(...)`: không đặt `userEditedTitle`, không đổi `updatedAt`.
- Test: `NotedTests/LinkDigestPipelineTests.swift`, 21 test, loader giả, không gọi mạng. Gồm: fingerprint; complete + so sánh snapshot `library.store` trước/sau (chỉ đổi tiêu đề, cả sau khi mở lại từ đĩa); tiêu đề thô/người dùng/chia sẻ; chờ preview xong; mục mới trước; trash giữa chừng; URL đổi giữa chừng; pin/tag/sửa tiêu đề không chạy lại; đổi engine version; phục hồi `running`; retry + backoff → `unreachable`; `unsafeURL` → `failed`; `loginWall` + `retry`; offline; Low Data Mode; data operation chặn commit; xóa hẳn → dọn digest; bỏ qua mục không phải link; xóa `intelligence.store` → rebuild đủ; store hỏng; schema version lạ.
- Evidence (2026-11-05, iPhone 12 Pro iOS 27.0.1):
  - `LinkDigestPipelineTests` 21/21 đạt; toàn bộ `NotedTests` 109 test, 0 lỗi, 2 test opt-in bị bỏ qua;
  - dữ liệu thật: 22 link đang dùng → 21 `complete` + 1 `titleOnly` (iCloud), 1 lượt mỗi link, digest `running` còn lại sau khi app bị tắt được phục hồi;
  - rebuild (version lạ → `.corrupt`, store mới) 22/22 trong 14,6 s; `library.store` ngoài tiêu đề không đổi.
- Còn mở: chưa có snapshot `library.store` trước lần chạy digest đầu tiên trên máy (tiêu đề đã được thay khi app host khởi động lúc chạy test), nên quy tắc thay tiêu đề chỉ được kiểm bằng unit test. Chưa thử offline/Low Data Mode trên máy. Plan ghi 21 link vì đếm ngày 2026-11-04; nay thư viện có 22.

## Acceptance

- Unit test xanh: bỏ kết quả cũ khi fingerprint đổi hoặc item vào trash, phục hồi sau crash, retry có giới hạn, `loginWall` không retry, xóa item thì digest bị dọn, store hỏng phục hồi được.
- Xóa `intelligence.store` → app vẫn mở được và rebuild đủ digest cho 21 link.
- `library.store` không đổi ngoài tiêu đề được phép (test so sánh trước và sau).

## Rủi ro

- Hai plan cùng tạo `IntelligenceStore` → plan nào làm trước thì tạo; plan sau chỉ thêm entity và tăng schema version theo migration có kiểm thử.
- Runner tải mạng khi người dùng không muốn → chỉ chạy khi app mở, tôn trọng Low Data Mode (`allowsConstrainedNetworkAccess = false`).

Quay lui: không khởi động runner, xóa entity `LinkDigest`; `library.store` không bị ảnh hưởng.
