# Phase 01 — đánh giá engine chủ đề

Ngày 2026-11-03. **Trạng thái: đang triển khai spike; chưa chọn engine, chưa qua quality/resource gate.**

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

## Quy trình đo trước quyết định

1. Trên thư viện mục tiêu, ghi số mục từng loại, ảnh có/không OCR; gán nhãn ít nhất 150 mục và ít nhất 10 mục mỗi nhóm nếu dữ liệu đủ. Người dùng mô tả Carepath và nhóm mơ hồ bằng 3–5 ví dụ. Giữ holdout cố định.
2. Dùng cùng input của `Item` cho mọi candidate: title do người dùng viết, body, tags, OCR, domain đã bỏ query/fragment, nhãn Vision; og:description chưa lưu nên phải đánh dấu là thiếu. Chia đoạn theo giới hạn token và dùng pooling nhất quán. Không đưa dữ liệu cá nhân vào repo.
3. Chỉnh ngưỡng nhận và khoảng cách top-1/top-2 trên calibration; unknown nếu mơ hồ. Với ảnh không chữ, so nhãn Vision và feature print k-NN với ảnh đã gán. Đo gợi ý tag và recall@10 bằng 10 câu truy vấn mẫu.
4. Báo confusion theo **từng nhóm và từng loại mục** trên holdout, precision nhóm chính ≥85%, coverage text ≥70%, so với baseline. Báo rõ kích thước holdout và khoảng sai số; score cosine không phải xác suất.
5. Gate iPhone 12 Pro: cold load ≤3 s, warm p95 text ≤300 ms/mục, Vision ≤500 ms/ảnh, memory delta ≤250 MB, batch 50 mục không chậm thao tác lưu; ghi dung lượng app tăng và `engineVersion`/threshold. Simulator không thay thế phép đo này.

**Quyết định hiện tại:** chưa đủ bằng chứng chọn engine hay bật phân nhóm tự động. Không đổi schema `library.store`, không cài model vào app, không ghi tiêu đề hay topic vào dữ liệu người dùng. Phase 02 vẫn phụ thuộc kết quả của Phase 01.
