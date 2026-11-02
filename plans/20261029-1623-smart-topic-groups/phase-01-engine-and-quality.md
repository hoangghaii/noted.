# Phase 01 — Engine và chất lượng

Ngày 2026-10-29. Trạng thái: Pending. Review: chưa nghiệm thu. Không phụ thuộc; ưu tiên cao.

## File ảnh hưởng

- Create `/Users/nhhai7/LocalData/Noted./docs/topic-grouping-evaluation.md` — Tập ví dụ, gold labels, nguồn/license/model revision, đo chất lượng và tài nguyên (đường dẫn dự kiến).
- Create `/Users/nhhai7/LocalData/Noted./scripts/topic-model-evaluation` — Công cụ thử tokenizer, export Core ML và đối chiếu output; chỉ tạo file cần dùng (đường dẫn dự kiến).
- Create `/Users/nhhai7/LocalData/Noted./Noted/Core/Topics/TopicEmbeddingEngine.swift` — Protocol + local candidate chỉ sau chọn engine (đường dẫn dự kiến).
- Create `/Users/nhhai7/LocalData/Noted./NotedTests/TopicQualityTests.swift` — Fixture văn bản tiếng Việt và đánh giá grouping (đường dẫn dự kiến).

## Bước thực hiện và kiểm chứng

- [ ] Lập 60 fixture tổng hợp không chứa dữ liệu cá nhân: ≥8 ví dụ mỗi nhóm người dùng nêu, kèm mục đa nghĩa, không chủ đề, không dấu, OCR lỗi, Việt/Anh, “Java” lập trình đối lập cà phê. Tách calibration và holdout trước chỉnh ngưỡng; bổ sung dữ liệu thật khi người dùng chọn.
- [ ] Xác nhận mô tả Carepath và ví dụ khó; chưa rõ để unknown. Không phân loại chỉ vì hostname hay một từ khóa.
- [ ] Benchmark hai candidate tối đa trên iPhone thật: chuyển Core ML/tokenizer/pooling/normalization đúng model card; so sánh vector native với reference để loại lỗi chuyển model. Pin revision/checksum/license; không tải hay chạy mã model tùy ý.
- [ ] Thử cosine với các topic có mô tả/prototype; ngưỡng nhận nhóm và margin top-1/top-2 calibrate trên tập riêng. Không dùng score cosine làm xác suất AI. Tối đa một nhóm chính và hai chủ đề phụ; ambiguous → unknown.
- [ ] Khám phá nhóm mới từ các mục unknown có embedding gần nhau: batch deterministic, yêu cầu ≥2 mục và cohesion vượt ngưỡng; đề xuất tên dựa cụm từ đại diện, người dùng có thể đổi tên. Không ép mọi mục vào nhóm, không tái cluster mỗi filter.
- [ ] Gate đề xuất: ≥85% precision nhóm chính trên holdout có nhãn, coverage ≥70% mục đủ text; đo riêng từng nhóm để không che lỗi Hài hước/Carepath. Ghi cả mục không thể hiểu chỉ bằng text.
- [ ] Gate tài nguyên đề xuất trên iPhone 12 Pro: warm p95 ≤2 giây/mục, peak memory tăng ≤200 MB, model+tokenizer ≤180 MB sau đóng gói; đo cold load/battery/thermal và batch 30 mục, không ảnh hưởng capture. Mốc chưa đo phải để pending.
- [ ] Nếu local đạt: dùng local; không đạt thì ghi lý do và thử API với cùng holdout. Provider chọn ở đây theo tiếng Việt, structured output, data retention, giá hiện hành; ghi chi phí dự kiến trên số item đo được, hạn mức rõ trước bật.
- [ ] API fallback: local setting bật rõ ràng, xem trước loại text gửi; Keychain cho key cá nhân, không hardcode key trong binary/log/backup. Validate ID/schema/topic output, timeout/token limit/bounded retry; text là dữ liệu, không thực thi chỉ dẫn trong note.

Acceptance: báo cáo engine có bằng chứng trên máy thật; không lấy mock regex làm AI thành công. Nếu cả hai engine chưa đạt, phase giữ pending, không bật tự phân nhóm sai. Chỉ thông qua gate mới bắt đầu phase 2.

Rủi ro: export/tokenizer lệch vector, thiếu ngữ cảnh, humor khó hiểu chỉ từ OCR. Quay lui: giữ flat list; không thay đổi dữ liệu người dùng trong spike.
