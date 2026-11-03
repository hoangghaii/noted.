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
- Cold load (parse tokenizer 16 MB + load model): int8 735 ms, fp16 755 ms. Gate ≤3 s.
- Warm p95: int8 3,1 ms/mục, fp16 3,4 ms/mục; batch 50 mục int8 mất 146 ms. Gate ≤300 ms.
- Memory delta khoảng +16,7 MB. Không tin cậy vì đo sau NL và chưa đo peak.
- Dung lượng `.mlmodelc`: int8 113 MB, fp16 224 MB, cộng tokenizer 16 MB.

**Kết luận tạm:** E5 int8 mean-centered là candidate tốt nhất. Coverage vượt gate và precision sát 85%, nhưng chỉ trên dữ liệu tổng hợp với holdout 35 mục. Chưa chọn engine: cần nhãn thật để đo precision/confusion, cần đo thêm memory peak và ảnh hưởng tới thao tác lưu.

## Quy trình đo trước quyết định

1. Trên thư viện mục tiêu, ghi số mục từng loại, ảnh có/không OCR; gán nhãn ít nhất 150 mục và ít nhất 10 mục mỗi nhóm nếu dữ liệu đủ. Người dùng mô tả Carepath và nhóm mơ hồ bằng 3–5 ví dụ. Giữ holdout cố định.
2. Dùng cùng input của `Item` cho mọi candidate: title do người dùng viết, body, tags, OCR, domain đã bỏ query/fragment, nhãn Vision; og:description chưa lưu nên phải đánh dấu là thiếu. Chia đoạn theo giới hạn token và dùng pooling nhất quán. Không đưa dữ liệu cá nhân vào repo.
3. Chỉnh ngưỡng nhận và khoảng cách top-1/top-2 trên calibration; unknown nếu mơ hồ. Với ảnh không chữ, so nhãn Vision và feature print k-NN với ảnh đã gán. Đo gợi ý tag và recall@10 bằng 10 câu truy vấn mẫu.
4. Báo confusion theo **từng nhóm và từng loại mục** trên holdout, precision nhóm chính ≥85%, coverage text ≥70%, so với baseline. Báo rõ kích thước holdout và khoảng sai số; score cosine không phải xác suất.
5. Gate iPhone 12 Pro: cold load ≤3 s, warm p95 text ≤300 ms/mục, Vision ≤500 ms/ảnh, memory delta ≤250 MB, batch 50 mục không chậm thao tác lưu; ghi dung lượng app tăng và `engineVersion`/threshold. Simulator không thay thế phép đo này.

**Quyết định hiện tại:** chưa đủ bằng chứng chọn engine hay bật phân nhóm tự động. Không đổi schema `library.store`, không cài model vào app, không ghi tiêu đề hay topic vào dữ liệu người dùng. Phase 02 vẫn phụ thuộc kết quả của Phase 01.
