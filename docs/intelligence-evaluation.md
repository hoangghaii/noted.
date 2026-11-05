# Phase 01 — đánh giá engine chủ đề

Ngày 2026-11-03. **Trạng thái: đang triển khai spike; chưa chọn engine. Đã có số đếm và số đo tài nguyên trên iPhone thật (xem [mục iPhone](#iphone-12-pro-thật-2026-11-03)); quality gate chưa đo vì chưa có nhãn.**

## Phạm vi và dữ liệu

- Build: Noted 1.0 (1), Debug, iOS Simulator 27.0, iPhone 12 Pro simulator `C66461EB-A8D0-424A-84FF-DC4A800E88B0`.
- Màn DEBUG trên simulator đếm **12 mục: 0 ảnh (0 có OCR, 0 không OCR), 0 link, 12 ghi chú; 0 nhãn**. Đây là dữ liệu thử nghiệm trên simulator, **không phải số mục của iPhone thật** và không đủ để đánh giá ảnh hay phân nhóm. [Báo cáo JSON tổng hợp](evidence/20261103-topic-phase01/simulator-report.json) ghi baseline thiếu nhãn, NL asset chưa có và Vision thiếu ảnh gán nhãn; không có precision/confusion để kết luận. Ảnh chụp UI nằm tạm tại `/private/tmp/noted-topic-label-attachments/` để tránh đưa nội dung mục vào repo.
- Màn **Dữ liệu & backup → Đánh giá AI · DEBUG → Gán nhãn chủ đề** cho phép gán một topic và các tag mong muốn trên từng mục. Số ảnh có/không OCR được tính tại chỗ. Nhãn nằm ở `Application Support/IntelligenceEvaluation/labels.json`, ngoài `NotedLibrary/library.store`; chỉ xuất JSON bằng thao tác ShareLink rõ ràng. JSON có ID, nhãn và tag mong muốn, không có nội dung mục. Chưa có nhãn thật đủ để đo; tránh xuất nếu ID/tag cũng là thông tin cá nhân cần giữ kín.
- Nút **Chạy đánh giá local** tạo `Application Support/IntelligenceEvaluation/report.json` chỉ chứa số đếm, metric, confusion theo topic/loại và thời gian; không ghi nội dung mục hay ID. Người dùng chủ động chọn xuất. Baseline tên topic, Natural Language và Vision feature-print 1-NN được đo trên calibration/holdout, gồm cả nhãn “Không rõ” làm trường hợp âm khi hiệu chỉnh ngưỡng. Báo cáo tách coverage của mục có text khỏi coverage chung; chỉ hiện precision khi candidate thực sự có dự đoán.
- `splitSeed = noted-topic-evaluation-v1` phân calibration/holdout theo ID trước khi hiệu chỉnh ngưỡng. Chưa dùng holdout để chọn ngưỡng.
- Định nghĩa Carepath do người dùng cung cấp 2026-11-03: con đường sự nghiệp, gồm định hướng công việc, cập nhật CV để có job, cơ hội giúp thăng tiến, và công cụ hỗ trợ công việc/phát triển sự nghiệp. Ví dụ người dùng nêu: công nghệ/AI tool/tip AI có thể giúp phát triển sự nghiệp; một job theo đánh giá cá nhân giúp thăng tiến. “Tìm việc” **có thể là chủ đề phụ của Carepath tùy mục**, không ép hai nhóm loại trừ nhau. Màn gán nhãn vì vậy lưu tối đa hai chủ đề phụ; gate nhóm chính vẫn tính riêng. Cần thêm mục thật do người dùng gán để đo biên chồng lấn này.

## Candidate và mức kiểm chứng

| Candidate | Có trong spike | Kiểm chứng hiện tại | Còn thiếu |
|---|---|---|---|
| Alias/từ khóa | `KeywordBaseline` chuẩn hóa dấu tiếng Việt, từ khớp nguyên token, trả unknown khi hòa | Unit test các ví dụ cà phê, tìm việc, Java lập trình, Việt/Anh | Alias của từng nhóm từ nhãn người dùng; precision/coverage trên holdout. Baseline không được gọi là AI. |
| Apple Natural Language | `ContextualEmbeddingEngine` mean-pool token, L2, chia đoạn theo ký tự, báo `engineVersion`; không tự tải asset | Compile cho iOS 17 simulator; test phát hiện candidate tiếng Việt | Kiểm tra `hasAvailableAssets`, xác minh không mất token trên OCR dài vì giới hạn ký tự chỉ là proxy, đo chất lượng và thời gian. Không dùng kết quả khi asset vắng. |
| Vision | `VNClassifyImageRequest` và `VNGenerateImageFeaturePrintRequest`, ảnh downsample tối đa 1600 px; evaluator có feature-print 1-NN và ngưỡng chọn trên calibration | Compile; fixture ảnh tổng hợp thử trên simulator nhưng Vision trả `NSOSStatusErrorDomain -1: Failed to create espresso context` | Chạy fixture trên iPhone thật, đo confusion ảnh đã gán nhãn, tỷ lệ giảm unknown ở ảnh không OCR và p95. |
| multilingual-e5-small | Recipe pin revision, SHA-256 các file lớn, MIT model card, xuất fp16/int8 weight và fixture parity | `compare_vectors.py` có 3 test; Python syntax check | Chưa tải/convert model. Tokenizer là XLM-R SentencePiece, cần implementation native và token-ID parity trước khi chạy app; cosine ≥0.99, đo tài nguyên/chất lượng sau đó. |

Apple ghi `NLContextualEmbedding.languages` có tiếng Việt từ iOS 17, nhưng khả năng có asset và chất lượng trên máy vẫn phải kiểm tra: [Apple Natural Language](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding/languages). E5 cần `query: `/`passage: ` và giới hạn tối đa 512 token theo [model card](https://huggingface.co/intfloat/multilingual-e5-small); recipe spike dùng 128 token và kiểm tra tokenizer [ở pinned revision](https://huggingface.co/intfloat/multilingual-e5-small/tree/fd1525a9fd15316a2d503bf26ab031a61d056e98).

## Kết quả chạy được ghi nhận

- Build simulator: `xcodebuild ... -destination 'platform=iOS Simulator,id=C66461EB-A8D0-424A-84FF-DC4A800E88B0' ... build` thành công. App Group cần ad hoc signing với entitlement trong bản build tạm; bản unsigned mở lên nhưng không truy cập được App Group. Bản signed cài đè và mở Thư viện, không gỡ app.
- Cả cấu hình Debug (`build-for-testing`) và Release (`build`) cho iPhone 12 Pro simulator biên dịch thành công; màn gán nhãn và evaluator chỉ có trong DEBUG. `.env` và `Config/Local.xcconfig` không đổi.
- `IntelligenceEngineTests`: 5 pass, 1 skip, 0 fail trên iPhone 12 Pro simulator. Vision được skip **chỉ khi** runtime trả lỗi Espresso `NSOSStatusErrorDomain -1` đã quan sát; không tính là Vision pass. `xcresult`: `/private/tmp/noted-topic-engine-tests-checked.xcresult`. Fixture không chứa dữ liệu cá nhân.
- Toàn bộ `NotedTests` sau sửa review: **56 pass, 1 skip Vision, 0 fail** trên cùng simulator. `xcresult`: `/private/tmp/noted-topic-final3-units.xcresult`.
- `python3 -m unittest discover -s scripts/topic-model-evaluation -p 'test_*.py'`: 3/3.
- UI test màn gán nhãn DEBUG và chạy/xuất báo cáo local: **1/1** trên simulator sau khi ký ad hoc App Group entitlement cho bản build tạm và chạy `test-without-building`. `xcresult`: `/private/tmp/noted-topic-final3-ui.xcresult`. Lần test trước với app unsigned không thể mở thư viện; không tính là pass.
- Verify lại 2026-11-03 trên simulator **mới, sạch** `iPhone 12 Pro (Topic P01 Verify)` `94FA34A3-E6CC-41A5-A46B-D7AEF98C6C71` (iOS 27.0), DerivedData riêng: `NotedTests` **57 test, 56 pass, 1 skip Vision (Espresso), 0 fail**; `IntelligenceLabelingUITests` 1/1 (scheme `Noted-DeviceGate`); Release build thành công và binary không chứa chuỗi màn gán nhãn; Python 3/3. Lưu ý: project đặt `SUPPORTED_PLATFORMS = iphoneos`, nên lệnh simulator phải có `-sdk iphonesimulator`, nếu không sẽ build ra binary máy thật và cài lên simulator thất bại.
- Môi trường hiện có Python 3.14, thiếu torch/transformers/coremltools và model E5 chưa cached. Recipe chưa chạy conversion; không có số cosine native/reference.

## iPhone 12 Pro thật (2026-11-03)

Máy `Hải - iPhone 12 Pro` (iPhone13,3), iOS 27.0.1 (24A446), Noted 1.0 (1) Debug, bundle `dev.nguyenhoanghai861.Noted`, thư viện nhập từ `.notedbackup`. Báo cáo `report.json` schema v2 lấy ra bằng `xcrun devicectl device copy from --domain-type appDataContainer`; chỉ có số đếm/số đo, không có nội dung hay ID. Không đưa file vào repo.

**Thư viện thật: 73 mục** — 27 ảnh (37%; cả 27 có OCR, 0 ảnh không OCR), 20 link (27%), 26 ghi chú (36%); 0 nhãn. Tỷ lệ khác ước lượng 50/40/10 trong plan. 73 mục < 150 nên gate nhãn (≥150, ≥10/nhóm) **không thể đạt** với thư viện hiện tại; theo plan, nhóm tự khám phá sẽ yếu và nên dựa vào topic người dùng khai báo. Chưa có ảnh không chữ nên không đo được việc Vision giảm “Chưa phân nhóm” cho loại này.

| Phép đo (gate) | Kết quả | Gate |
|---|---|---|
| NL contextual cold load, chỉ `load()` (≤3 s) | 55,6 ms | Đạt |
| NL warm p95 / mục, 50 lượt lặp trên 73 mục (≤300 ms) | 37,1 ms; batch 50 tổng 1,18 s; 0 lỗi | Đạt |
| Vision cold, ảnh đầu (tham khảo) | 175,7 / 209,2 ms (2 lượt) | — |
| Vision warm p95 / ảnh, 50 lượt lặp trên 27 ảnh (≤500 ms) | 98,6 / 106,4 ms (2 lượt), 0 lỗi | Đạt |
| Memory delta Vision (≤250 MB) | +40,6 / +38,8 MB `phys_footprint` | Đạt |
| Memory delta NL (≤250 MB) | −18,7 MB — **không tin cậy**: đo sau Vision nên lẫn bộ nhớ Vision được giải phóng; chưa đo peak | Chưa kết luận |
| Batch 50 không làm chậm thao tác lưu | Chưa đo (evaluator chạy trong màn DEBUG, không song song thao tác lưu) | Chưa đo |

- `engineVersion`: `nl-contextual-5C45D94E-BAB4-4927-94B6-8B5745C46289-r1-mean-v1`, `vision-classify-r2-feature-r2-v1`.
- Asset NL tiếng Việt tải được qua nút **Tải model Natural Language tiếng Việt** (người dùng bấm). Sau đó hai lượt chạy qua UI test (mỗi lượt cài lại app bằng `xcodebuild test`) lại báo `assets unavailable`. Chưa xác định nguyên nhân (cài lại app hay lý do khác); Phase 02 không được giả định asset luôn có và phải xử lý trạng thái vắng asset.
- Số đo tài nguyên **không** chứng minh chất lượng phân nhóm; chưa có precision/coverage/confusion vì 0 nhãn.
- Test trên máy: `IntelligenceEngineTests` 9/9 (Vision feature print pass, không skip như simulator); `IntelligenceLabelingUITests` 1/1 (scheme `Noted-DeviceGate`).

## Bộ mẫu tổng hợp trên iPhone (2026-11-03) — không phải dữ liệu người dùng

`IntelligenceSyntheticCorpus` (`synthetic-corpus-v1`, chỉ DEBUG, không ghi vào `library.store`): 175 mục do AI viết kèm nhãn do AI đặt, gồm 141 ghi chú và 34 link, không có ảnh. Mỗi nhóm có 30 mục, riêng “Không rõ” có 25. Dữ liệu trộn Việt có dấu, không dấu, tiếng Anh, kiểu OCR và có các ca khó (Java/CoffeeScript → Không rõ; bán cà phê → Kiếm thêm thu nhập; Carepath sát Tìm việc). Calibration 140 mục, holdout 35 mục, cùng `splitSeed`. Kết quả này chỉ cho biết engine có phân biệt được các chủ đề theo cách viết của bộ mẫu hay không; **không dùng để nghiệm thu gate** (`sufficientLabelsForGate = false`).

| Candidate (holdout 35) | Ngưỡng | Precision | Coverage | Ghi chú |
|---|---|---|---|---|
| Baseline tên topic (không phải AI) | — | 3/3 = 100% | 8,6% | Chỉ bắt được khi chữ trùng tên topic |
| NL contextual mean-pool | cosine ≥0,90, margin 0,02 | 8/10 = 80% | 28,6% | Dưới gate 85% / 70% |

- Confusion NL trên holdout: đúng Cà phê 3, Hài hước 3, Kiếm thêm thu nhập 2. Sai: một mục Không rõ → Carepath và một mục Không rõ → Cà phê. Toàn bộ Carepath (6) và Tìm việc (7) thành unknown; link gần như luôn unknown.
- Ngưỡng chọn được rất cao (0,90) nên vector mean-pool của NL có thể rất giống nhau giữa các chủ đề. Đây là suy luận, chưa đo phân bố cosine.
- Tài nguyên (lượt này): NL cold load 80,4 ms, warm p95 20,8 ms, batch 50 mất 0,95 s, memory +0,9 MB.
- Holdout chỉ 35 mục, mỗi nhóm 5–7 mục, nên sai số lớn. Dù vậy, **NL contextual mean-pool không đạt gate ngay cả trên dữ liệu tổng hợp tương đối sạch**. Đây là tín hiệu bất lợi cho candidate này; quyết định cuối vẫn cần nhãn thật.

## Mean-centering và E5 trên iPhone (2026-11-03) — bộ mẫu tổng hợp

Mean-centering: trừ vector trung bình của toàn bộ mục (không dùng nhãn) rồi chuẩn hóa lại, áp dụng cho mọi engine chữ. E5 `multilingual-e5-small` ở revision pin `fd1525a`, convert bằng `export.py` (Python 3.11.14, coremltools 8.3.0, torch 2.5.1, transformers 4.44.2). Model chạy trên máy qua `CoreMLEmbeddingEngine` với tokenizer native `XLMRobertaTokenizer`. File model được copy vào Application Support của bản Debug, không đóng gói vào app.

**Parity:**
- Token ID của tokenizer native khớp Python **187/187** bản ghi (175 mục tổng hợp và 12 ca biên: emoji, full-width, NFD, ligature, CJK, zero-width, chuỗi 300 ký tự, chuỗi rỗng).
- Vector trên iPhone so với PyTorch: fp16 cosine 0,99989–1,0004; int8 0,99984–1,0002. Ngưỡng yêu cầu ≥0,99.
- Compute units: int8 với `.all`/`.cpuAndGPU` bị `LLVM ERROR: out of memory`; `.cpuOnly` cho vector NaN; chỉ `.cpuAndNeuralEngine` đạt parity.

**Chất lượng** (holdout 35 mục, **dữ liệu tổng hợp, không dùng để nghiệm thu**):

| Candidate | Ngưỡng / margin | Precision | Coverage |
|---|---|---|---|
| Baseline tên topic (không phải AI) | — | 100% (3/3) | 8,6% |
| NL contextual | 0,90 / 0,02 | 80% (8/10) | 28,6% |
| NL contextual mean-centered | 0,35 / 0,06 | 85,7% (12/14) | 40% |
| E5 fp16 hoặc int8, vector gốc | 0 / 0,02 | 100% (1/1) | 2,9% |
| **E5 fp16 hoặc int8, mean-centered** | 0,10 / 0,04 | **83,3% (25/30)** | **85,7%** |

- E5 fp16 và int8 cho kết quả giống hệt nhau trên holdout này.
- Lỗi của E5 mean-centered: cả 3 mục “Không rõ” trong holdout bị gán vào chủ đề (Cà phê 2, Carepath 1); 2 mục Tìm việc thành Carepath. Ngoài ra Hài hước 2, Kiếm thêm thu nhập 2 và Tìm việc 1 trả về unknown.
- E5 dạng vector gốc gần như không dự đoán, vì cosine giữa các mục đều cao. Mean-centering là bước bắt buộc với E5.

**Tài nguyên E5 trên iPhone:**
- Cold load (parse tokenizer 16 MB + load model): int8 735 ms, fp16 755 ms. **Đã đính chính 2026-11-04:** đây là lần load sau NL và sau model kia trong cùng process, không phải cold load thật. Xem [mục đo riêng](#gate-tài-nguyên-e5-đo-riêng-2026-11-04).
- Warm p95: int8 3,1 ms/mục, fp16 3,4 ms/mục; batch 50 mục int8 mất 146 ms. Gate ≤300 ms.
- Memory delta khoảng +16,7 MB. Không tin cậy vì đo sau NL và chưa đo peak.
- Dung lượng `.mlmodelc`: int8 113 MB, fp16 224 MB, cộng tokenizer 16 MB.

**Kết luận tạm (2026-11-03, đã thay bằng mục dưới):** E5 int8 mean-centered là candidate tốt nhất. Coverage vượt gate và precision sát 85%, nhưng chỉ trên dữ liệu tổng hợp với holdout 35 mục. Chưa chọn engine: cần nhãn thật để đo precision/confusion, cần đo thêm memory peak và ảnh hưởng tới thao tác lưu.

## Gate tài nguyên E5, đo riêng (2026-11-04)

Đo trên iPhone 12 Pro, iOS 27.0.1, bản Debug, `.cpuAndNeuralEngine`, theo hai cách:
- **Test `testE5IsolatedResourceGateOnDevice`** (opt-in `TEST_RUNNER_NOTED_E5_RESOURCE=1`, chạy một mình nên process sạch và chỉ có E5). App lưu 30 ghi chú khi rảnh, rồi lưu 30 ghi chú trên main actor trong lúc một task nền embed liên tục các batch 50 mục của bộ tổng hợp. Peak lấy từ `ledger_phys_footprint_peak`. Mỗi lần `xcodebuild test` cài lại app.
- **Probe khi mở app** (`--e5-load-probe <variant>`, chỉ có trong DEBUG): mỗi lần app khởi động thì load E5 một lần và ghi thêm một dòng vào `IntelligenceEvaluation/e5-load-probe.jsonl`. Cài app một lần, rồi mở lại nhiều lần bằng `devicectl device process launch --terminate-existing`, không cài lại. Delta memory của probe có lẫn phần app khởi động.

| | int8 | fp16 | Gate |
|---|---|---|---|
| Load lần đầu sau khi cài (test, 4 lần chạy) | 25,7–31,1 s | 14,5 s | ≤3 s ✗ |
| Load lần đầu sau khi cài (probe) | 22,9 s | 14,5 s | ≤3 s ✗ |
| Load ở các lần mở app sau (probe, 2 lần mỗi model) | 2,23–2,25 s | 2,24–2,29 s | ≤3 s ✓ (sát) |
| Instance thứ hai trong cùng process (test) | 2,37 s | 2,13 s | — |
| Memory sau load / sau các batch (test) | +224 / +225–293 MB | +39 / +96 MB | ≤250 MB |
| Peak tăng, lần đầu sau khi cài (test) | **+591 MB** | +97 MB | ≤250 MB |
| Peak tăng, các lần mở sau (probe) | +104 MB | +104 MB | ≤250 MB ✓ |
| Warm p95 mỗi mục (test) | 4,3–8,9 ms | 4,6 ms | ≤300 ms ✓ |
| Một batch 50 mục (test) | 159–266 ms | 181–225 ms | — |
| Lưu ghi chú p95, khi rảnh → trong lúc batch chạy | 8,9–15,0 → 11,2–21,7 ms | 8,8 → 11,2 ms | không chậm ✓ |

**Nhận xét:**
- Lần load đầu sau khi cài hoặc cập nhật app chậm, vì Core ML specialize model cho Neural Engine. Bản đã specialize được cache và vẫn còn sau khi tắt và mở lại app. Mỗi lần cài lại thì mất cache. Lần trả phí đầu này vi phạm gate cold load, nên model phải được load trong task nền, không chặn UI hay thao tác lưu, và các mục đó tạm ở trạng thái “Chưa phân nhóm” cho tới khi model sẵn sàng.
- int8 nhỏ hơn trên đĩa (113 MB so với 224 MB) nhưng tốn RAM hơn: lần đầu peak +591 MB, vượt gate. Sau khi load thì giữ khoảng +225 MB, khác với fp16 chỉ +39 MB. Có thể Neural Engine giải nén weight int8 ra bộ nhớ (chưa kiểm chứng). Trên bộ tổng hợp, chất lượng của hai bản giống hệt nhau.
- Lưu ghi chú trong lúc batch chạy chậm thêm khoảng 2–3 ms ở median, p95 dưới 22 ms. Người dùng không nhận ra được độ chậm này.

**Kết luận tài nguyên:** chọn **E5 fp16** (`e5-small-fd1525a-fp16-t128-mean-v1`), không chọn int8. Với fp16, các gate p95, memory, batch/lưu và cold load khi đã có cache đều đạt. Gate cold load không đạt ở lần đầu sau khi cài hoặc cập nhật (14,5 s); điều này chấp nhận được nếu load chạy nền như mô tả ở trên. App tăng khoảng 240 MB (model 224 MB và tokenizer 16 MB) nếu đóng gói model. Quyết định engine cuối cùng vẫn chờ chất lượng trên nhãn thật.

## Nhãn thật trên iPhone (2026-11-04)

Người dùng gán nhãn 75 mục (28 ảnh đều có OCR, 21 link, 26 ghi chú), bằng màn DEBUG, rồi chạy đánh giá local. Asset NL tiếng Việt đã được tải lại trước khi chạy. Chưa ai gán tag mong muốn.

- **Phân bố nhãn:** Cà phê 39, Không rõ 24, AI 4, Tiếng Anh 2, Tìm việc 2. Mac App, Đồ ăn, Noted. update note và Vệ sinh mỗi nhóm 1 mục. Carepath và Kiếm thêm thu nhập không có mục nào. Chỉ Cà phê và Không rõ đạt ≥10 mục.
- **Chia nhóm:** calibration 63 mục, holdout 12 mục, theo seed cố định. Gate ≥150 nhãn và ≥10 mục mỗi nhóm không đạt, nên số dưới đây chỉ để tham khảo. Mỗi mục holdout tương đương 8,3 điểm phần trăm.
- **Link:** người dùng cho biết hầu hết link khó gán nhãn vì app chỉ có URL và `<title>`, nên thường chọn “Không rõ”. Cần bản mô tả link trước khi đánh giá lại link.

| Candidate | Ngưỡng / margin | Precision | Coverage holdout |
|---|---|---|---|
| Baseline tên topic (không phải AI) | — | 100% (8/8) | 66,7% |
| NL contextual, gốc hoặc mean-centered | 0,90 / 0,02 · 0,50 / 0,12 | 90% (9/10) | 83,3% |
| E5 fp16/int8 gốc | 0 / 0,04 | 100% (8/8) | 66,7% |
| E5 fp16/int8 mean-centered | 0,35 / 0,14 | 88,9% (8/9) | 75% |
| Vision feature-print 1-NN (5 ảnh) | 0,41 | 100% (1/1) | 20% |

- Lỗi duy nhất của các engine embedding là một link “Tiếng Anh” bị gán thành “AI”. Baseline trả “Không rõ” cho mục này.
- Engine thắng baseline nhiều nhất là NL contextual (+1 mục đúng, +2 mục được gán). Khác biệt này nằm trong sai số của 12 mục, nên **chưa có engine nào thắng baseline rõ ràng**. Theo Acceptance, chưa chốt engine dựa trên chất lượng.
- Vision trên lần chạy này: p95 99,2 ms/ảnh, cold load 334 ms, memory +38 MB.

## Nguồn link trên iPhone (2026-11-04)

Thuộc [Phase 01 Đọc hiểu link](../plans/20261104-2113-link-understanding/phase-01-link-source-spike.md). Công cụ: màn gán nhãn DEBUG → **Nguồn link · DEBUG** → “Đo nguồn link”. Mỗi link chạy 4 chiến lược, mỗi chiến lược 1 lần, cách nhau ~1,2 s: GET mặc định của `URLSession`, GET với User-Agent Safari iOS, `LPMetadataProvider` (chỉ so tiêu đề), oEmbed công khai không token. Một chiến lược được tính “dùng được” khi không lỗi, không có login wall, và có mô tả ≥40 ký tự hoặc nội dung chính ≥200 ký tự. Mô tả giống hệt nhau ở ≥2 link khác nhau bị coi là boilerplate. File `link-sources.json` chỉ chứa domain đã chuẩn hóa, cờ, độ dài, hash và đánh giá Đủ/Không đủ của người dùng.

Build 1.0 (1), iOS 27.0.1, iPhone 12 Pro (iPhone13,3). Thư viện có 21 link: 8 Threads, 1 iCloud Notes, 12 `example.com`. 12 link `example.com` là dữ liệu fixture nên bị loại khỏi bảng.

- **Lượt 14:32 và 14:37 UTC (không hợp lệ):** Threads 8/8 lỗi `oversized`. Trang khoảng 600 KB, vượt giới hạn 512 KB, nên không đọc được meta. Đây là lỗi của công cụ đo. Đã sửa bằng cách đọc 512 KB đầu (`keepPrefixWhenOversized`).
- **Lượt 14:47 UTC (sau khi sửa):**

| Domain | Link | GET mặc định | GET UA Safari | LPMetadataProvider | oEmbed không token | Người dùng: đủ để gán |
|---|---|---|---|---|---|---|
| threads | 8 | 8/8 có og:description (76–487 ký tự) | 8/8, giống hệt GET mặc định | chỉ tiêu đề = tác giả | 0/8 (HTTP 400) | 7/8 |
| icloud.com | 1 | 0/1 (og:description 22 ký tự) | 0/1, giống hệt | chỉ tiêu đề | không có endpoint | 0/1 |

- **Threads:** og:title là “Tên (@handle) on Threads”, tức tác giả chứ không phải nội dung. og:description là nội dung bài, nằm trong khoảng 4 KB đầu trang. Cả 8 lần đều qua 1–2 redirect và bị cắt ở 512 KB. Không thấy login wall với link bài viết. Trang profile không đăng nhập (kiểm tra bằng curl) trả boilerplate “Join Threads… Log in with your Instagram.” Thời gian thường 1,0–1,4 s, chậm nhất 4,4 s. Với 1 bài, người dùng đánh giá chưa đủ dù có 127 ký tự mô tả.
- **iCloud Notes:** chỉ có tiêu đề (dòng đầu của ghi chú). Nội dung được tải bằng JavaScript, không có trong HTML.
- **Facebook, Instagram:** thư viện không có link nào, nên chưa có số đo thật.
- **Còn mở:** chỉ có 1 lượt hợp lệ, chưa đo lại ở thời điểm thứ hai như plan yêu cầu.

**Quyết định:**
1. Mặc định dùng 1 GET với User-Agent mặc định, đọc tối đa 512 KB đầu trang (không coi là lỗi khi vượt), theo thứ tự og → twitter → meta description → nội dung chính. UA Safari không mang lại gì thêm (hash mô tả giống hệt), nên không dùng.
2. Bỏ oEmbed (Threads cần token, IG/FB theo tài liệu cũng cần token) và bỏ `LPMetadataProvider` (chỉ trùng og:title).
3. Với Threads, og:title được lưu làm tác giả/tên trang, không làm tiêu đề nội dung; og:description là phần tóm tắt.
4. Ghi `loginWall` khi redirect tới trang đăng nhập hoặc mô tả khớp mẫu boilerplate (kể cả mô tả lặp ở nhiều link). Facebook/Instagram dùng cùng quy tắc này nhưng **chưa được xác minh trên dữ liệu thật**; cần đo khi thư viện có link của hai nguồn này.
5. Với iCloud Notes và các trang chỉ có tiêu đề, ghi trạng thái chỉ-có-tiêu-đề và gợi ý người dùng tự thêm ghi chú. Không chạy JavaScript ẩn trong bản đầu.

## Digest link trích xuất trên iPhone (2026-11-04)

Thuộc [Phase 02 Đọc hiểu link](../plans/20261104-2113-link-understanding/phase-02-extraction.md). Đo bằng chiến lược `extractiveDigest` (`fetchPage` + `ExtractiveLinkDigester`, `link-extractive-v1`), build 1.0 (1), iOS 27.0.1, iPhone 12 Pro, lượt 15:04 UTC. Không tính 12 link fixture `example.com`.

| Domain | Link | Digest `complete` | Người dùng: đủ để gán | So với Phase 01 |
|---|---|---|---|---|
| threads | 8 | 8/8 (tóm tắt 76–217 ký tự) | 8/8 | 8/8 dùng được; người dùng 7/8 |
| icloud.com | 1 | 0/1 (`titleOnly`) | 0/1 | như Phase 01 |

Không có login wall. Mỗi link mất 1,05–2,41 s, gồm cả tải. Có 1 og:title Threads không khớp mẫu tác giả nên vẫn được giữ làm tiêu đề.

## Quy trình đo trước quyết định

1. Trên thư viện mục tiêu, ghi số mục từng loại, ảnh có/không OCR; gán nhãn ít nhất 150 mục và ít nhất 10 mục mỗi nhóm nếu dữ liệu đủ. Người dùng mô tả Carepath và nhóm mơ hồ bằng 3–5 ví dụ. Giữ holdout cố định.
2. Dùng cùng input của `Item` cho mọi candidate: title do người dùng viết, body, tags, OCR, domain đã bỏ query/fragment, nhãn Vision; og:description chưa lưu nên phải đánh dấu là thiếu. Chia đoạn theo giới hạn token và dùng pooling nhất quán. Không đưa dữ liệu cá nhân vào repo.
3. Chỉnh ngưỡng nhận và khoảng cách top-1/top-2 trên calibration; unknown nếu mơ hồ. Với ảnh không chữ, so nhãn Vision và feature print k-NN với ảnh đã gán. Đo gợi ý tag và recall@10 bằng 10 câu truy vấn mẫu.
4. Báo confusion theo **từng nhóm và từng loại mục** trên holdout, precision nhóm chính ≥85%, coverage text ≥70%, so với baseline. Báo rõ kích thước holdout và khoảng sai số; score cosine không phải xác suất.
5. Gate iPhone 12 Pro: cold load ≤3 s, warm p95 text ≤300 ms/mục, Vision ≤500 ms/ảnh, memory delta ≤250 MB, batch 50 mục không chậm thao tác lưu; ghi dung lượng app tăng và `engineVersion`/threshold. Simulator không thay thế phép đo này.

**Quyết định hiện tại:** chưa đủ bằng chứng chọn engine hay bật phân nhóm tự động. Không đổi schema `library.store`, không cài model vào app, không ghi tiêu đề hay topic vào dữ liệu người dùng. Phase 02 vẫn phụ thuộc kết quả của Phase 01.
