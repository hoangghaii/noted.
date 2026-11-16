# Phase 06 — Nghiệm thu & đánh giá lại Phase 01

Ngày 2026-11-04. Trạng thái: Done (2026-11-16); Facebook mới có 1 mẫu, Instagram chưa có link. Review: người dùng nghiệm thu trên iPhone. Phụ thuộc Phase 04 (và 05 nếu làm). Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Chứng minh trên iPhone 12 Pro rằng link đã đọc hiểu được, rồi quay lại gán nhãn link để Phase 01 của plan Lớp AI có dữ liệu link dùng được.

## Bước

- [x] Trên iPhone (bản Debug, dữ liệu thật): chạy runner cho 21 link, ghi số `complete` / `loginWall` / `unreachable` theo domain vào `docs/intelligence-evaluation.md` (chỉ số đếm).
- [x] Đo thời gian đọc mỗi link (p50/p95) và đảm bảo lưu link mới không bị chậm khi runner đang chạy.
- [x] Offline: lưu link khi tắt mạng → mục vẫn lưu, digest chạy khi có mạng lại.
- [x] Backup/restore: digest không nằm trong backup; sau restore runner tạo lại.
- [x] Người dùng gán nhãn lại các link đang là “Không rõ” trong màn DEBUG, dựa trên tóm tắt.
- [x] Chạy lại “Chạy đánh giá local”, so precision/coverage của link trước và sau khi có digest. Cập nhật Phase 01 của plan Lớp AI.
- [x] Nếu bật Phase 05: so bản API với bản trích xuất trên link đọc được.

## Acceptance

- Tỷ lệ link có tóm tắt dùng được đạt mục tiêu chốt ở Phase 01 của plan này (theo domain), với Facebook/Instagram/Threads báo riêng.
- Số link nhãn “Không rõ” giảm so với lần gán 2026-11-04, và evaluation doc có kết quả đánh giá lại.
- Test unit/UI liên quan pass trên máy; build Release thành công.

## Rủi ro

- Phần lớn link Meta là `loginWall` → báo người dùng rõ con số; khi đó gợi ý thêm ghi chú khi share, hoặc cân nhắc WKWebView ẩn như một quyết định riêng.

## Chuẩn bị 2026-11-15 (chưa nghiệm thu bước nào)

Trước đó không có cách đếm trạng thái digest theo domain hay đo thời gian đọc, nên bước 1–2 không làm được kể cả khi có iPhone. Đã thêm:

- `LinkDigestRunner.fetchMilliseconds`: thời gian tải và trích xuất của lần đọc gần nhất mỗi link, chỉ lưu trong bộ nhớ, không tính lần lỗi do offline, không gồm thời gian gọi API. `retryAll()` (chỉ có trong DEBUG) đặt mọi digest về `pending`.
- `Core/Digest/LinkDigestReport.swift` (DEBUG): đếm complete/titleOnly/loginWall/unreachable/failed/chưa đọc và số bản API theo domain, kèm p50/p95 (nearest-rank). Facebook/Instagram/Threads xếp đầu. File `link-digest-report.json` chỉ chứa domain và số đếm.
- Màn gán nhãn DEBUG → mục “Nghiệm thu digest”: nút “Đọc lại tất cả link và đo” và nút xuất JSON.

Kiểm chứng: build Debug và Release generic iOS đạt. 127 test của `NotedTests` (5 skip, 0 fail) chạy trên iPhone 12 Pro **Simulator** iOS 27.2 (phương án phụ, vì iPhone không kết nối), gồm 2 test mới trong `LinkDigestPipelineTests`. Sau đó chạy lại trên **iPhone 12 Pro thật**: 127 test, 0 fail, 2 skip (`testE5IsolatedResourceGateOnDevice`, `testSyntheticSpikeReportOnDevice` là phép đo opt-in, skip khi không đặt biến môi trường), 2 test mới pass. Chưa đo trên dữ liệu thật.

Cách làm khi có máy: mở bản Debug → màn gán nhãn → “Đọc lại tất cả link và đo” → xuất JSON → chép số đếm vào `docs/intelligence-evaluation.md`. Một link lỗi mạng tạm thời được tính là “chưa đọc” cho tới lượt retry sau backoff.

## Kết quả đo 2026-11-15

Bước 1 đạt: 13 link thật (loại 12 fixture `example.com`). 12 `complete`, 1 `titleOnly` (iCloud Notes), 0 login wall, 0 lỗi. Facebook 1/1 `complete`, Threads 10/10, Instagram chưa có link. Thời gian đọc p95 ≤ 1,69 s. Chi tiết ở [intelligence-evaluation.md](../../docs/intelligence-evaluation.md#nghiệm-thu-digest-link-trên-iphone-2026-11-15). Bước 2 mới đo được một nửa: có p50/p95, chưa kiểm tra việc lưu link khi runner đang chạy.

## Kết quả người dùng kiểm tra trên iPhone 2026-11-16

- Bước 2: người dùng share link mới trong lúc runner đang đọc lại tất cả; link được lưu ngay.
- Bước 3: link share lúc offline vẫn được lưu. Lúc đầu người dùng thấy thẻ chưa có tóm tắt. Store chép từ máy (chỉ đọc metadata) cho thấy digest được đọc xong 20 s sau khi nhập (`complete`, 1 lần thử). Runner có chạy lại khi có mạng; khoảng chờ là do preview chạy trước digest.
- Bước 5: người dùng đã gán nhãn lại các link.
- Lỗi tìm ra: tóm tắt Facebook chỉ lặp một phần tiêu đề, nên thẻ trông như không có tóm tắt. Đã sửa trong `ExtractiveLinkDigester`: mô tả nằm trong tiêu đề bị bỏ. Tăng engine lên `link-extractive-v2`, nên mọi link sẽ được đọc lại một lần. Có test `testFacebookDescriptionRepeatingPartOfTitleIsTitleOnly`. Trên iPhone: 128 test, 0 fail, 2 skip. Build Release đạt.
- Sau v2, người dùng vẫn thấy thẻ Facebook như cũ. Đúng như dự kiến: share link Facebook khi không đăng nhập chỉ trả về một tiêu đề, không có nội dung bài. Người dùng chọn tách tiêu đề và gợi ý ghi chú. Engine `link-extractive-v3`: tiêu đề Facebook `đoạn trích | tên | …` được tách thành tiêu đề và dòng tác giả/trang. Chỉ áp quy tắc bỏ mô tả nằm trong tiêu đề cho mô tả lấy từ meta. Thẻ và Detail của link `titleOnly` hiện dòng tác giả cùng gợi ý thêm ghi chú (Detail trước đây báo nhầm “Chưa đọc được”). Trên iPhone: 129 test, 0 fail, 2 skip. Build Release đạt. Chưa chạy UI test `NotedUITests`.
- Bước 4 kiểm chứng bằng integration test `testBackupExcludesDigestsAndRestoreRebuildsThem`, chạy trên iPhone 12 Pro thật với dữ liệu tổng hợp và `BackupService` thật. Gói backup chỉ có `manifest.json` và `originals/`, không chứa tóm tắt hay fingerprint của digest. Thư viện restore bắt đầu không có digest; runner đọc lại 1 lần và tạo `complete`. Cố ý không restore vào thư viện thật: xung đột sẽ giữ cả hai bản, làm nhân đôi dữ liệu người dùng.
- Ghi chú E5: 2 test skip (`testE5IsolatedResourceGateOnDevice`, `testSyntheticSpikeReportOnDevice`) là phép đo opt-in, chỉ chạy khi có `TEST_RUNNER_NOTED_E5_RESOURCE=1` hoặc `TEST_RUNNER_NOTED_SPIKE_REPORT=1`. Model E5 vẫn có trong container app (`IntelligenceEvaluation/e5`, ngày 2026-11-03).
- Bước 6 (2026-11-16): link thật “Không rõ” còn 2/14. Baseline từ khóa gán đúng cả 3 link thật trong holdout, E5 fp16 gán đúng 1/3. Gate số nhãn vẫn chưa đạt (89 < 150). Chi tiết ở [intelligence-evaluation.md](../../docs/intelligence-evaluation.md#đánh-giá-lại-sau-khi-có-digest-link-2026-11-16).
- Bước 7, chuẩn bị (2026-11-16): thêm màn DEBUG `RemoteDigestComparisonView` (Gán nhãn chủ đề → Nghiệm thu digest → “So sánh bản API với bản trích xuất”). Màn này đọc lại từng link thật đang `complete` (bỏ fixture `example.com`), gọi API một lần, hiện hai bản cạnh nhau cho người dùng chọn, rồi xuất `digest-comparison.json` (chỉ domain và lựa chọn). Kết quả API không ghi vào digest. Khóa Groq do người dùng nhập vào Keychain qua màn AI tùy chọn; app không đọc `.env` và không nhúng khóa vào bản build. Trên iPhone: 131 test, 0 fail, 2 skip. Build Release đạt. Chưa gọi API thật.
- Bước 7 (2026-11-16): API tốt hơn 5/12, ngang 7, kém 0, lỗi 0. Phase 05 không đạt gate đa số, nên giữ mặc định tắt.

## Kết luận Acceptance (2026-11-16)

- Tỷ lệ theo domain, so với quyết định Phase 01: Threads 10/10 có tóm tắt (đạt). iCloud Notes `titleOnly` (đúng dự đoán). Facebook 0/1 có tóm tắt, chỉ có tiêu đề, không login wall: mới 1 mẫu nên **chưa đủ để kết luận**. Instagram **chưa có dữ liệu**. Hai nguồn này được giữ là điểm mở và không chặn phase.
- Link thật “Không rõ” giảm còn 2/14. Evaluation doc đã có kết quả đánh giá lại.
- Trên iPhone: 131 test, 0 fail, 2 skip (opt-in). Build Release đạt. Chưa chạy UI test `NotedUITests` trong phase này.
