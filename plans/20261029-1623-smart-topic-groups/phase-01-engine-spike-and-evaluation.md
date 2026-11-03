# Phase 01 — Spike engine & bộ đánh giá

Ngày 2026-11-03. Trạng thái: In progress trên simulator. Review: chưa nghiệm thu. Không phụ thuộc. Ưu tiên cao. Overview: [plan.md](plan.md).

Tiến độ 2026-11-03: đã thêm engine thử nghiệm Natural Language/Vision, baseline từ khóa, màn gán nhãn DEBUG lưu JSON riêng, recipe E5 có pin nguồn và parity checker, cùng fixture test. [Báo cáo phép đo và khoảng thiếu](../../docs/intelligence-evaluation.md). Chưa chọn engine: bộ nhãn thật, native tokenizer E5/parity, confusion holdout và gate tài nguyên trên iPhone 12 Pro chưa có. Các checkbox bên dưới vẫn mở vì chưa đạt toàn bộ tiêu chí tương ứng.

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

- [ ] Đếm số mục và tỷ lệ ảnh/link/ghi chú thực tế, ảnh có/không có OCR. Ghi vào evaluation doc (chỉ số lượng, không ghi nội dung).
- [ ] Màn gán nhãn: hiển thị từng mục, người dùng chọn topic (Cà phê, Tìm việc, Carepath, Kiếm thêm thu nhập, Hài hước…, “Không rõ”) và tag mong muốn. Nhãn lưu local (JSON trong Application Support), không rời máy. Mục tiêu ≥150 mục, ≥10 mục mỗi nhóm nếu thư viện đủ lớn. Chia calibration/holdout theo seed cố định **trước khi** chỉnh ngưỡng.
- [ ] Người dùng cung cấp mô tả + 3–5 ví dụ cho Carepath và các nhóm mơ hồ.
- [ ] Engine chữ: đo baseline, `NLContextualEmbedding` (xác nhận `languages` có `vi`, asset tải được), e5-small Core ML (fp16 và int8, kiểm cosine với reference ≥0.99). Pin revision/checksum/license, không chạy mã model tùy ý.
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
