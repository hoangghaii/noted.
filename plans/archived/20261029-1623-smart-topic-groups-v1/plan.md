# Noted — Nhóm nội dung theo chủ đề

Ngày 2026-10-29. Trạng thái: chỉ lập kế hoạch, chưa triển khai. Ưu tiên: cao.

## Mục tiêu và trải nghiệm

Sau pill filter hiện có, hiển thị các section theo ý nghĩa: Cà phê, Tìm việc, Carepath, Kiếm thêm thu nhập, Hài hước… Mỗi section có tên, số mục khớp bộ lọc, thu gọn/mở rộng và Xem thêm. Một mục hiển thị một lần trong nhóm chính; có thể có chủ đề phụ trong chi tiết. Giữ collection thủ công, pin, Inbox và Trash như hiện tại.

Nhóm được xác định trên thư viện, rồi lấy giao với kết quả filter/search; không chạy AI hoặc tạo lại nhóm khi đổi pill. Ví dụ pill Link chỉ cho thấy link thuộc Cà phê và các nhóm khác; nhóm rỗng ẩn. Không đủ bằng chứng → Chưa phân nhóm. Nội dung vừa lưu xuất hiện ngay, AI xử lý sau. Người dùng có thể đổi nhóm, đổi tên, hợp nhất, loại đề xuất và tắt nhóm tự động.

## Quyết định và phụ thuộc

- Người dùng xác nhận: ưu tiên offline; nếu không khả thi có thể dùng API AI. Đây là cho phép hướng API, chưa có provider/key/ngân sách cụ thể.
- iPhone mục tiêu: iPhone 12 Pro; Apple Intelligence không phải engine khả dụng trên máy này theo [yêu cầu Apple](https://support.apple.com/en-mide/121115). Không mặc định API Apple hoạt động chỉ vì chạy iOS mới.
- Thử embedding đa ngôn ngữ nhỏ chạy local trước; candidate [multilingual-e5-small](https://huggingface.co/intfloat/multilingual-e5-small) và [multilingual MiniLM](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2). Đây là candidate, chưa chuyển Core ML hoặc benchmark trên máy. Kiểm tra license/tokenizer/pooling/model revision trước đóng gói.
- Apple [NLEmbedding](https://developer.apple.com/documentation/naturallanguage/nlembedding) trả model theo ngôn ngữ/runtime; không giả định tiếng Việt có sentence embeddings.
- Embedding tìm mức tương đồng; không tự đặt tên nhóm tốt hoặc hiểu mọi meme. Tên nhóm lấy từ chủ đề được mô tả, từ khóa đại diện và người dùng xác nhận; không cần LLM lớn chỉ để đặt tên.
- Hướng local được chọn nếu qua gate phase 1. Nếu không, API xử lý text tối thiểu đã chọn, cache kết quả trên máy; offline vẫn xem/tìm nhóm cũ, mục mới chờ xử lý. Không âm thầm chuyển local → cloud.
- Text nguồn: title/body/tags/OCR; URL dùng title/domain, loại query/fragment khỏi dữ liệu AI mặc định. Không tải trang web thêm chỉ để phân nhóm. Ảnh không chữ/URL không mô tả được để Chưa phân nhóm; chưa có vision AI trong phạm vi.
- Không đổi original, không dùng collectionID làm topic ID. Tính fingerprint từ dữ liệu nội dung thực, không dùng updatedAt vì pin/trash cũng cập nhật trường đó.
- Một single-writer SwiftData; snapshot immutable cho inference; kết quả gắn itemID + fingerprint + engineVersion. Cache là dữ liệu dẫn xuất, rebuild được; sửa tay phải được giữ qua backup.
- Không cần vector DB, backend, chatbot, hay semantic search mới trong phạm vi này. API provider nếu chọn mới xác định có cần proxy; không tự triển khai server.

## Các phase

| Phase | Trạng thái | Đầu ra |
|---|---|---|
| [01 — Engine và chất lượng](phase-01-engine-and-quality.md) | Pending | Fixture, benchmark local, chọn local/API có bằng chứng |
| [02 — Dữ liệu và pipeline](phase-02-topic-data-and-pipeline.md) | Pending; phụ thuộc 01 | Topic ổn định, cache/retry, sửa tay và backup |
| [03 — Giao diện nhóm](phase-03-grouped-library-ui.md) | Pending; phụ thuộc 02 | Filter/search → section theo chủ đề, loading và correction |
| [04 — Nghiệm thu iPhone](phase-04-device-acceptance.md) | Pending; phụ thuộc 03 | Kiểm chứng dữ liệu, offline, chất lượng và cài đè |

## Cơ sở nguồn hiện tại

LibraryView.swift và SearchView.swift đang lọc/sắp xếp rồi render grid phẳng. Item có title/body/URL/tags/OCR nhưng chưa có topic/embedding. LibraryStore là writer chính. EnrichmentRunner xử lý OCR/preview tuần tự khi app hoạt động. ModelStore/BackupManifest/BackupService cần được đánh giá migration trước thêm schema.

## Giả định và câu hỏi còn mở

- Carepath là tên chủ đề riêng của người dùng; không suy đoán nó đồng nghĩa Tìm việc. Cho khai báo mô tả và ví dụ.
- Hài hước và Vui nhộn ban đầu là hai nhãn có thể hợp nhất nếu người dùng muốn; không gộp âm thầm.
- Chưa có tập nội dung thực đã gán nhãn. Phase 1 cần người dùng xác nhận các ví dụ mơ hồ, không dùng mock làm bằng chứng chất lượng trên dữ liệu thật.
- Ngưỡng chất lượng/tài nguyên dưới đây là mục tiêu đề xuất để ra quyết định, chưa là kết quả đo. Nếu cần API: provider, ngân sách, lưu giữ dữ liệu và nơi cấu hình key còn mở; không chặn nghiên cứu offline.
