# Phase 04 — Giao diện thẻ & Detail

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 03. Ưu tiên trung bình-cao. Overview: [plan.md](plan.md).

## Mục tiêu

Hiển thị digest trên thẻ Thư viện (1 dòng) và trong Detail (đầy đủ), theo hệ giao diện Giấy & Bảng ghim hiện có.

## File ảnh hưởng

- Modify `Noted./Noted/Features/Library/ItemCard.swift`: ảnh có tiêu đề trống thì hiện `digest.title`, không hiện "Ảnh đã lưu". Thêm 1 dòng `summary` (lineLimit 1) và badge loại nhỏ (Bài viết / Chat / Tuyển dụng).
- Modify `Noted./Noted/Features/Detail/ItemDetailView.swift`: section **Tóm tắt** đặt trên section OCR hiện có, gồm:
  - loại ảnh;
  - summary;
  - chip dữ kiện, chạm được: link mở Safari, số điện thoại gọi, ngày giờ copy;
  - nhãn nguồn "Trích xuất" hoặc "AI";
  - nút "Tạo lại".
  Text OCR gốc vẫn giữ nguyên bên dưới.
- Modify `Noted./Noted/Features/Search/SearchView.swift`: kết quả là ảnh dùng cùng dòng tóm tắt (tái sử dụng component của thẻ).
- Create (đề xuất) `Noted./Noted/Features/Detail/DigestSection.swift`.
- Modify `Noted./Noted/App/MockFixtures.swift`: thêm fixture digest cho UI test.
- Create (đề xuất) `Noted./NotedUITests/DigestUITests.swift`.

## Bước

- [ ] Đọc `docs/design-guideline.md`, tái sử dụng component trong `Noted/UI/NotedComponents.swift` và `Shared/NotedPaperUI.swift`. Không tạo style mới nếu đã có.
- [ ] Đọc digest qua một view model nhỏ: tra theo `itemID`, quan sát được để cập nhật khi runner commit.
- [ ] Trạng thái trên Detail:
  - đang chạy: "Đang tóm tắt…";
  - `insufficientText`: ẩn section;
  - `failed`: hiện nút thử lại.
- [ ] "Tạo lại": đặt digest về `pending` và chạy runner. Nếu API đang bật thì dùng API.
- [ ] Tìm kiếm không đổi: tìm trên `ocrText` như cũ.
- [ ] Accessibility: VoiceOver đọc được loại, tóm tắt và từng chip; Dynamic Type không cắt chip.

## Acceptance

- UI test với fixture: thẻ hiện tiêu đề và dòng tóm tắt; Detail hiện đủ section, chip link mở đúng URL.
- Ảnh đã có tiêu đề người dùng đặt thì thẻ vẫn hiện tiêu đề đó.
- Kiểm tra trên iPhone: cuộn Thư viện 73 mục vẫn mượt, không tải digest đồng bộ trên main thread mỗi lần render.

## Rủi ro

- Thẻ chật → summary cắt 1 dòng, badge chỉ hiện khi loại khác `other`.

Quay lui: ẩn section/dòng bằng điều kiện. Dữ liệu digest vẫn còn.
