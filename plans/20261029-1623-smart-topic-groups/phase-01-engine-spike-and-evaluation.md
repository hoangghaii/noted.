# Phase 01 — Spike engine & bộ đánh giá

Ngày 2026-11-03. Trạng thái: In progress trên iPhone thật. Review: chưa nghiệm thu. Không phụ thuộc. Ưu tiên cao. Overview: [plan.md](plan.md).

Tiến độ 2026-11-03: đã thêm engine thử nghiệm Natural Language/Vision, baseline từ khóa, màn gán nhãn DEBUG lưu JSON riêng, recipe E5 có pin nguồn và parity checker, cùng fixture test. [Báo cáo phép đo và khoảng thiếu](../../docs/intelligence-evaluation.md). Chưa chọn engine: bộ nhãn thật, native tokenizer E5/parity, confusion holdout và gate tài nguyên trên iPhone 12 Pro chưa có. Các checkbox bên dưới vẫn mở vì chưa đạt toàn bộ tiêu chí tương ứng.

Tiến độ 2026-11-03 (iPhone 12 Pro thật, iOS 27.0.1): thư viện có 73 mục (27 ảnh đều có OCR, 20 link, 26 ghi chú), nên gate ≥150 nhãn không đạt được với dữ liệu hiện có. Evaluator đo được cold load NL 55,6 ms, warm p95 NL 37,1 ms, Vision p95 98,6–106,4 ms, memory Vision +39–41 MB. Memory NL chưa tin cậy và chưa đo ảnh hưởng tới thao tác lưu. Asset NL tải được nhưng không còn sau khi cài lại app. Chi tiết: [mục iPhone](../../docs/intelligence-evaluation.md#iphone-12-pro-thật-2026-11-03). Trên bộ mẫu tổng hợp 175 mục do AI viết (không dùng cho gate), NL contextual mean-pool đạt precision 80% và coverage 28,6% trên holdout 35 mục, dưới gate; baseline đạt 100% và 8,6%. E5 small đã convert và chạy trên máy. Tokenizer native khớp 187/187, vector khớp Python với cosine ≥0,9998 cho cả fp16 và int8, khi dùng `.cpuAndNeuralEngine`. E5 int8 mean-centered đạt precision 83,3% và coverage 85,7% trên bộ tổng hợp. Cold load 0,74 s, p95 3,1 ms/mục, model 113 MB. Xem [mục E5](../../docs/intelligence-evaluation.md#mean-centering-và-e5-trên-iphone-2026-11-03--bộ-mẫu-tổng-hợp).

## Mục tiêu

Chọn engine embedding chữ + cách hiểu ảnh bằng số đo trên iPhone 12 Pro, với dữ liệu thật đã được người dùng gán nhãn. Chưa đổi dữ liệu người dùng.

## File ảnh hưởng (đều là đường dẫn đề xuất)

- Create `Noted./Noted/Core/Intelligence/TextEmbeddingEngine.swift` — protocol `embed(_ text:, role: .query|.passage) -> [Float]` (đã chuẩn hóa L2) + `engineVersion`.
- Create `Noted./Noted/Core/Intelligence/ContextualEmbeddingEngine.swift` — candidate `NLContextualEmbedding` (mean-pool token vectors).
- Create `Noted./Noted/Core/Intelligence/CoreMLEmbeddingEngine.swift` — candidate multilingual-e5-small (tiền tố `query:`/`passage:`) hoặc MiniLM, kèm tokenizer.
- Create `Noted./Noted/Core/Intelligence/ImageSignals.swift` — `VNClassifyImageRequest` (top nhãn > ngưỡng) + `VNGenerateImageFeaturePrintRequest`.
- Create `Noted./Noted/Core/Intelligence/KeywordBaseline.swift` — baseline alias/từ khóa để so sánh.
- Create `Noted./Noted/App/IntelligenceLabelingView.swift` — màn gán nhãn nhanh, **chỉ có trong DEBUG**, nằm dưới Dữ liệu & Backup.
- Create `Noted./scripts/topic-model-evaluation/` — export Core ML, so vector native với reference Python, ghi checksum/revision/license.
- Create `Noted./docs/intelligence-evaluation.md` — kết quả đo, confusion theo nhóm, quyết định engine.
- Create `Noted./NotedTests/IntelligenceEngineTests.swift` — fixture tổng hợp (không chứa dữ liệu cá nhân): Java lập trình ↔ cà phê, không dấu, OCR lỗi, Việt/Anh.

## Bước

- [x] Đếm số mục và tỷ lệ ảnh/link/ghi chú thực tế, ảnh có/không có OCR. Ghi vào evaluation doc (chỉ số lượng, không ghi nội dung).
- [ ] Màn gán nhãn: hiển thị từng mục, người dùng chọn topic (Cà phê, Tìm việc, Carepath, Kiếm thêm thu nhập, Hài hước…, “Không rõ”) và tag mong muốn. Nhãn lưu local (JSON trong Application Support), không rời máy. Mục tiêu ≥150 mục, ≥10 mục mỗi nhóm nếu thư viện đủ lớn. Chia calibration/holdout theo seed cố định **trước khi** chỉnh ngưỡng.
- [ ] Người dùng cung cấp mô tả + 3–5 ví dụ cho Carepath và các nhóm mơ hồ.
- [x] Engine chữ: đo baseline, `NLContextualEmbedding` (xác nhận `languages` có `vi`, asset tải được), e5-small Core ML (fp16 và int8, kiểm cosine với reference ≥0.99). Pin revision/checksum/license, không chạy mã model tùy ý.
- [ ] Đầu vào text: title (nếu người dùng viết), body, tags, OCR, domain + og:description (giả lập bằng dữ liệu đã có), nhãn Vision dạng chữ. Chia đoạn dài theo giới hạn token, pooling nhất quán.
- [ ] Ảnh: đo xem nhãn Vision + feature print làm giảm bao nhiêu % “Chưa phân nhóm” trên ảnh không chữ. Cách gán qua feature print: so với các ảnh đã gán nhãn gần nhất (k-NN), ngưỡng riêng.
- [ ] Phân loại: cosine với vector đại diện topic (mô tả + ví dụ đã gán nhãn), ngưỡng nhận + margin top-1/top-2 calibrate trên calibration. Mơ hồ → unknown. Score không phải xác suất.
- [ ] Đo nhanh khả năng dùng cho tag (gợi ý tag từ k-NN đúng bao nhiêu % so với tag mong muốn) và tìm theo nghĩa (10 câu truy vấn mẫu, recall@10). Dữ liệu này dùng cho Phase 04/05.
- [ ] Gate đề xuất (đo trên holdout, tách theo từng nhóm và từng loại mục):
  - precision nhóm chính ≥85%;
  - coverage ≥70% với mục có text, báo riêng ảnh không chữ;
  - engine phải thắng baseline rõ ràng.
- [ ] Gate tài nguyên trên iPhone 12 Pro:
  - warm p95 ≤300 ms/mục cho text, ≤500 ms/ảnh cho Vision;
  - cold load ≤3 s;
  - bộ nhớ tăng ≤250 MB;
  - batch 50 mục không làm chậm thao tác lưu.
- [ ] Ghi quyết định: engine được chọn, `engineVersion`, ngưỡng, kích thước app tăng thêm.

## Acceptance

`docs/intelligence-evaluation.md` có số đo thật trên máy (kèm build, engine version), confusion theo nhóm và lý do chọn engine. Nếu không engine nào qua gate: giữ Pending, chỉ làm phần topic thủ công ở Phase 03 và báo người dùng. Không lấy kết quả của baseline ra trình bày như AI.

## Rủi ro

- Export/tokenizer lệch vector → so với reference.
- `NLContextualEmbedding` không hỗ trợ tiếng Việt → dùng e5.
- Meme vẫn khó dù có Vision → chấp nhận unknown, cho người dùng gán tay.
- Thư viện nhỏ → holdout yếu, ghi rõ khoảng sai số.

Quay lui: spike không ghi gì vào `library.store`. Màn gán nhãn chỉ có trong DEBUG.

## Handoff 2026-11-03 → tiếp tục 2026-11-04

**Trạng thái:** In progress. Chưa chọn engine. Candidate dẫn đầu là E5 small int8 mean-centered (`e5-small-fd1525a-int8-t128-mean-v1-centered`), mới đo trên bộ mẫu tổng hợp nên không dùng để nghiệm thu.

**Đang chờ người dùng:** gán nhãn 73 mục thật trên iPhone, ở **Dữ liệu & Backup → Đánh giá AI · DEBUG**. Chọn chủ đề chính theo cảm nhận, phân vân thì chọn “Không rõ”; tag và chủ đề phụ là tùy chọn. Sau đó bấm **Tải model Natural Language tiếng Việt**, rồi **Chạy đánh giá local**.

**Việc kỹ thuật khi có nhãn:**
1. Lấy báo cáo: `xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier dev.nguyenhoanghai861.Noted --source "Library/Application Support/IntelligenceEvaluation/report.json" --destination <file>`. Ghi precision, coverage và confusion theo nhóm/loại mục của từng candidate vào `docs/intelligence-evaluation.md`. 73 mục < 150 nên vẫn chỉ là số tham khảo.
2. Đo gate tài nguyên còn thiếu: memory peak của E5 khi đo riêng (không chạy sau NL/Vision), và ảnh hưởng của batch 50 mục tới thao tác lưu.
3. Nếu E5 vẫn gán nhầm mục lạc đề trên nhãn thật, thử prototype riêng cho “Không rõ” hoặc ngưỡng theo nhóm; chỉnh trên calibration thật, không chỉnh theo bộ tổng hợp.
4. Ghi quyết định engine, ngưỡng và dung lượng, rồi tick các checkbox còn lại khi đạt.

**Môi trường cần biết:**
- iPhone đang cài bản Debug `dev.nguyenhoanghai861.Noted`, team `DBC9RB6Z6U`, chiếm 2/3 slot free profile. Thư viện 73 mục đã nhập từ backup.
- File E5 (khoảng 350 MB: `e5-int8.mlmodelc`, `e5-fp16.mlmodelc`, `tokenizer.json`, `reference-vectors.json`, `token-fixture.json`) nằm trong `Library/Application Support/IntelligenceEvaluation/e5/` của app trên máy. Cài đè bằng `xcodebuild test` vẫn giữ các file này. **Gỡ app sẽ mất các file này**; khi đó tạo lại theo [README recipe](../../scripts/topic-model-evaluation/README.md#device-spike-2026-11-03-iphone-12-pro).
- Venv Python 3.11 và output convert nằm trong thư mục tạm của phiên làm việc, có thể đã bị xóa. Tạo lại bằng `uv venv --python 3.11` theo README.
- Asset NL tiếng Việt có thể mất sau mỗi lần cài lại app; cần bấm tải lại trước khi đánh giá.
- Chạy test trên máy: `xcodebuild test -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<UDID>' -allowProvisioningUpdates -only-testing:NotedTests/IntelligenceEngineTests`. Thêm `TEST_RUNNER_NOTED_SPIKE_REPORT=1` để in báo cáo trên bộ tổng hợp ra log (dòng `NOTED_SPIKE_REPORT_JSON`). Lần chạy gần nhất: 14/14 pass. `IntelligenceLabelingUITests` chạy với scheme `Noted-DeviceGate`, 1/1 pass.
