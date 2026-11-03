# Noted — Lớp AI trên máy: chủ đề, tiêu đề/tóm tắt, tag, tìm theo nghĩa

Tạo 2026-10-29, viết lại 2026-11-03 sau brainstorm. Trạng thái: Phase 01 đang triển khai trên simulator; chưa nghiệm thu. Ưu tiên: cao. Bản cũ (4 phase, chỉ phân nhóm): [archive v1](../archive/20261029-1623-smart-topic-groups-v1/plan.md).

## Mục tiêu

Thêm lớp AI chạy offline trên iPhone 12 Pro, chi phí 0 đồng:
1. **Phân nhóm theo chủ đề** trong Thư viện/Tìm kiếm (section Cà phê · 3, Tìm việc · 2, Carepath…), áp sau pill filter/search.
2. **Tiêu đề/tóm tắt tự động**: ghi vào tiêu đề còn trống; tiêu đề người dùng đã sửa (`userEditedTitle`) luôn giữ.
3. **Gợi ý tag**: chip gợi ý, người dùng bấm mới lưu vào `item.tags`.
4. **Tìm kiếm theo nghĩa**: kết hợp tìm từ khóa hiện có, chạy offline.
5. **Gợi ý chủ đề/tag ngay trong Share Extension**.

Ngoài phạm vi: chatbot, backend/proxy, đồng bộ, vector DB, LLM trên máy (chỉ ghi nhận là hướng tương lai), API trả phí.

## Quyết định đã chốt (với người dùng, 2026-11-03)

- **Topic là khái niệm mới, do AI quản lý**: mỗi mục có 1 nhóm chính và tối đa 2 chủ đề phụ; người dùng sửa/gộp/đổi tên/tạo được. **Tag**: AI chỉ gợi ý. **Collection**: giữ thủ công, AI không động vào.
- Ngân sách 0 đồng → mọi tính năng chính chạy **local**. API miễn phí chỉ là tùy chọn, mặc định tắt, chỉ dùng để sinh câu văn (Phase 06). Không âm thầm gửi dữ liệu.
- Tỷ lệ thư viện ước lượng: ảnh 50% / link 40% / ghi chú 10%. Vì vậy phải dùng **Vision của Apple** (nhãn ảnh + feature print), không chỉ đọc OCR.
- Chấp nhận app nặng thêm ≥120 MB nếu phải đóng gói model embedding.
- Todo “List k có group nhóm lại” đã bỏ vì trùng mục tiêu 1.

## Quyết định kiến trúc

- **Một nền embedding dùng chung**: vector tính một lần, cache theo `itemID + fingerprint + engineVersion`, phục vụ phân nhóm, gợi ý tag và tìm theo nghĩa.
- **Dữ liệu AI đặt ở store riêng** `intelligence.store`, có `ModelContainer` và schema version riêng. `library.store` (schema v1, `ModelStore` đang từ chối mọi version khác) **không đổi schema**. Ngoại lệ duy nhất: tiêu đề AI ghi vào `Item.title` có sẵn. Xóa store AI thì rebuild được; phần người dùng sửa tay đi vào backup.
- Fingerprint tính từ nội dung (title nếu do người dùng viết, body, URL đã bỏ query/fragment, OCR, nhãn Vision). Không dùng `updatedAt`, vì pin/trash cũng cập nhật trường này.
- `IntelligenceRunner` chạy tuần tự sau `EnrichmentRunner`, chỉ khi app đang mở. Commit qua single-writer, bỏ kết quả cũ khi fingerprint đổi.
- Tiêu đề/tóm tắt mặc định là **trích xuất** (og:title/og:description, câu đầu, dòng OCR nổi bật), không phải sinh văn bản.
- Share Extension không nạp model (giới hạn bộ nhớ), chỉ tra bảng nhỏ do app chính xuất vào App Group.

## Các phase

| Phase | Trạng thái | Phụ thuộc | Đầu ra |
|---|---|---|---|
| [01 — Spike engine & bộ đánh giá](phase-01-engine-spike-and-evaluation.md) | In progress; gate iPhone chưa đo | — | Chọn engine bằng số đo trên iPhone, gán nhãn dữ liệu thật, đếm số mục thư viện |
| [02 — Kho AI & pipeline](phase-02-intelligence-store-and-pipeline.md) | Pending | 01 | `intelligence.store`, runner, cache vector, backup v2 |
| [03 — Chủ đề & giao diện nhóm](phase-03-topics-and-grouped-ui.md) | Pending | 02, plan UI giấy Phase 08 | Section theo chủ đề, khởi tạo topic, học từ sửa tay, quản lý topic |
| [04 — Tiêu đề, tóm tắt, tag & Share](phase-04-titles-tags-and-share.md) | Pending | 02 | og:description, tiêu đề trống, chip tag, gợi ý trong Share Extension |
| [05 — Tìm kiếm theo nghĩa](phase-05-semantic-search.md) | Pending | 02 | Kết hợp từ khóa + vector, offline |
| [06 — (Tùy chọn) API miễn phí](phase-06-optional-free-api.md) | Pending, có thể bỏ | 04 | Viết lại tiêu đề/tóm tắt, mặc định tắt |
| [07 — Nghiệm thu iPhone](phase-07-device-acceptance.md) | Pending | 03–05 (06 nếu làm) | Evidence chất lượng/tài nguyên/offline/backup |

Phase 03, 04, 05 có thể làm song song sau 02. Phase 03 chỉ đụng tới màn Thư viện/Tìm kiếm sau khi plan [Giấy & Bảng ghim](../20261102-2119-paper-pinboard-ui/plan.md) nghiệm thu xong, để khỏi làm lại.

## Cơ sở nguồn hiện tại

- `Item` có title/body/originalURL/tags/ocrText/userEditedTitle; chưa có topic/embedding.
- `EnrichmentRunner` chạy OCR/preview tuần tự, so revision bằng `updatedAt`.
- `LinkMetadataService` chỉ lấy `<title>`, giới hạn 512 KB.
- `SearchService` so chuỗi đã chuẩn hóa.
- `ShareGatePayload` có `schemaVersion` optional. `BackupManifest` đang ở version 1.

## Giả định và câu hỏi còn mở

- Chưa biết số mục thư viện; Phase 01 sẽ đếm. Nếu có < ~50 mục, việc tự khám phá nhóm sẽ yếu, khi đó dựa vào topic người dùng khai báo.
- `NLContextualEmbedding` hỗ trợ tiếng Việt và chất lượng vector câu **chưa xác minh**.
- Carepath là chủ đề riêng của người dùng; cần mô tả + ví dụ từ người dùng.
- Mọi ngưỡng trong các phase là mục tiêu đề xuất, chưa phải kết quả đo.
- Phase 06: nhà cung cấp miễn phí chọn lúc triển khai, theo điều khoản hiện hành (không dùng dữ liệu để huấn luyện, có hạn mức free). Hiện chưa có tên cụ thể.
