# Noted — Đọc hiểu & tóm tắt ảnh chụp màn hình

Tạo 2026-11-04 sau brainstorm. Trạng thái: Pending, chưa triển khai. Ưu tiên: cao. Plan liên quan: [Lớp AI trên máy](../20261029-1623-smart-topic-groups/plan.md).

## Mục tiêu

Với mỗi ảnh có chữ, app tự tạo một **bản tóm tắt ảnh** (`ImageDigest`) gồm: loại ảnh, tiêu đề, tóm tắt 1–3 câu và các dữ kiện (ngày, giờ, số điện thoại, link, số tiền, địa điểm…). Bản tóm tắt hiển thị ở **cả hai nơi**: 1 dòng trên thẻ Thư viện và đầy đủ trong Detail.

- Loại ảnh ưu tiên: **bài viết**, **chat** và **tin tuyển dụng**. Loại khác vẫn có tóm tắt chung.
- Mặc định chạy offline, theo kiểu trích xuất. Người dùng có thể **tự bật** API LLM miễn phí. Khi bật, app chỉ gửi **text OCR đã làm sạch**, không gửi ảnh.

Ngoài phạm vi:
- ảnh không có chữ;
- tóm tắt link và ghi chú (thuộc plan Lớp AI, Phase 04);
- gửi ảnh lên cloud, LLM đóng gói trong app;
- Foundation Models của Apple: iPhone 12 Pro không hỗ trợ và người dùng chưa có ý định đổi máy;
- chatbot, đồng bộ.

## Quyết định đã chốt (với người dùng, 2026-11-04)

- **Minimum deployment target = iOS 27** cho mọi target (hiện đang là 17.0). Nhờ đó dùng được API Vision mới mà không cần nhánh `#available`.
- Ảnh chủ yếu là screenshot bài viết, chat và tin tuyển dụng. Tóm tắt hiển thị trên cả thẻ lẫn Detail.
- Đồng ý gửi text OCR lên API miễn phí khi người dùng tự bật. Mặc định vẫn tắt.
- Không làm nhánh Foundation Models.

## Quyết định kiến trúc

- **Không đổi schema `library.store`** (v1, `ModelStore` từ chối version khác) và **không ghi đè `Item.title`**. Ảnh có tiêu đề trống thì UI hiện `digest.title` thay cho "Ảnh đã lưu". `item.ocrText` giữ nguyên, tìm kiếm không đổi.
- Digest lưu trong `intelligence.store` riêng, chỉ có entity `ImageDigest`. Phase 02 của plan Lớp AI sẽ **mở rộng** store này (thêm Topic, GeneratedText…), không tạo store thứ hai.
- Digest là dữ liệu dẫn xuất: không đưa vào backup, xóa đi thì rebuild được.
- Pipeline tự chạy nhận dạng có cấu trúc (khối, đoạn, vị trí) trên ảnh gốc. Không phân tích lại `ocrText` phẳng.
- Có hai bộ tạo nội dung chung một interface `DigestGenerator`: `ExtractiveDigester` (luôn có) và `RemoteDigester` (API, tùy chọn). API lỗi hoặc hết hạn mức thì quay về bản trích xuất.
- Client API viết để **dùng lại** được cho Phase 06 của plan Lớp AI (DRY).

## Các phase

| Phase | Trạng thái | Phụ thuộc | Đầu ra |
|---|---|---|---|
| [01 — iOS 27 & spike OCR có cấu trúc](phase-01-ios27-and-structured-ocr-spike.md) | Pending | — | Target 27, chọn API Vision, bộ làm sạch, phân loại ảnh đo trên 27 ảnh thật |
| [02 — Kho digest & runner](phase-02-digest-store-and-runner.md) | Pending | 01 | `intelligence.store`, `ImageDigest`, `DigestRunner` |
| [03 — Tóm tắt trích xuất theo loại ảnh](phase-03-extractive-digest.md) | Pending | 02 | Bài viết / chat / tin tuyển dụng / khác, dữ kiện |
| [04 — Giao diện thẻ & Detail](phase-04-card-and-detail-ui.md) | Pending | 03 | Dòng tóm tắt trên thẻ, section Tóm tắt trong Detail |
| [05 — API LLM text-only (tùy chọn)](phase-05-optional-llm-api.md) | Pending | 03 (UI cài đặt cần 04) | Viết lại tóm tắt, mặc định tắt |
| [06 — Nghiệm thu iPhone](phase-06-device-acceptance.md) | Pending | 04, 05 | Evidence chất lượng, tài nguyên, offline, lỗi |

Phase 04 và 05 làm song song được sau 03.

## Cơ sở nguồn hiện tại

- `OCRService` dùng `VNRecognizeTextRequest` (`.accurate`, ưu tiên vi/en/ja), nối các dòng bằng `\n`, không giữ cấu trúc.
- `EnrichmentRunner` chạy OCR tuần tự. `ItemDetailView` hiển thị `ocrText` thô.
- Thư viện thật có 73 mục, trong đó 27 ảnh và cả 27 đều có OCR ([evaluation](../../docs/intelligence-evaluation.md)).
- Thiết bị: iPhone 12 Pro, iOS 27.0.1.

## Giả định và câu hỏi còn mở

- **Chưa xác minh** API nhận dạng tài liệu mới của Vision có hỗ trợ tiếng Việt không. Phase 01 đo thực tế; nếu không hỗ trợ thì dùng `RecognizeTextRequest` và tự gom khối theo bounding box.
- 27 ảnh là mẫu nhỏ. Mọi ngưỡng trong các phase là mục tiêu đề xuất, chưa phải kết quả đo.
- Chưa chọn nhà cung cấp API: chọn lúc triển khai Phase 05, theo điều khoản hiện hành.
- README đang ghi "không cần dịch vụ AI bên ngoài". Phase 05 sẽ sửa câu này khi tính năng tùy chọn được thêm vào.
