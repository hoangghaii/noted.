# Phase 03 — Giao diện nhóm

Ngày 2026-10-29. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc phase 02; ưu tiên cao.

## File ảnh hưởng

- Modify `Noted./Noted/Features/Library/LibraryView.swift` — Render intersection filter với topic sections.
- Modify `Noted./Noted/Features/Search/SearchView.swift` — Render nhóm từ kết quả query/filter có sẵn.
- Create `Noted./Noted/Features/Topics/TopicSectionsView.swift` — Shared grouped grid, collapse và pagination (đường dẫn dự kiến).
- Create `Noted./Noted/Features/Topics/TopicManagementView.swift` — Rename/move/merge và engine settings (đường dẫn dự kiến).
- Modify `Noted./Noted/Features/Detail/ItemDetailView.swift` — Nhóm chính/phụ, sửa và lý do theo từ khóa nguồn.
- Modify `Noted./Noted/App/RootView.swift` — Lối vào quản lý chủ đề và toggle chế độ xem.

## Bước thực hiện và kiểm chứng

- [ ] Pipeline UI: exclude trash → pill/collection/query/time filters → topic grouping → section pagination. Không gọi model trong body/results computed property hoặc mỗi lần gõ search.
- [ ] Toggle “Theo chủ đề / Tất cả”; mặc định nhóm khi có kết quả đã phân loại. Section: Cà phê · 3, Tìm việc · 2, Carepath · 2…; unknown ghi “Chưa phân nhóm”, pending thêm nhãn đang phân tích. Không dùng “Khác” để che tất cả lỗi.
- [ ] Count là số mục trong kết quả đã lọc, không phải toàn nhóm; một item xuất hiện một lần. Thứ tự nhóm cố định theo tên tiếng Việt, unknown cuối; giữ pin-first/newest trong nhóm tại Library, newest tại Search. Giữ tên/ID/expanded state khi đổi pill.
- [ ] Dùng shared presentation cho Library/Search; giới hạn render theo section có Xem thêm, không áp prefix toàn list trước grouping làm mất nhóm. Scroll/collapse không gọi inference.
- [ ] Loading không chặn capture: “Đang phân nhóm 3/12”; cache hiển thị ngay; pending/failed có retry rõ, lỗi offline API không spinner vô hạn. Tác vụ rename/merge lâu có loading và chặn double tap.
- [ ] Detail và menu nhóm cho đổi nhóm, đổi tên/hợp nhất, hủy AI assignment hoặc xác nhận đề xuất. Không giả lý do generative; có thể hiển thị mô tả topic/từ khóa nguồn và nhãn “Gợi ý tự động”.
- [ ] Nhóm mới như Carepath được đề xuất hoặc người dùng tạo và đưa ví dụ; alias cafe/cà phê gom cùng chủ đề. Hài hước/Vui nhộn chỉ gộp khi người dùng chọn merge.
- [ ] Input quản lý nhóm theo cơ chế ẩn keyboard hiện tại; giữ bản nháp khi lỗi; tiếng Việt có dấu đúng. Cài setting model không khả dụng/download/API permission với loading và fallback flat list.

Acceptance trên iPhone: All/Images/Links/Notes/Inbox/Pinned và collection/search trả đúng ID tập kết quả trước/sau grouping, không mất/duplicate item; nhóm rỗng ẩn; edit/move/merge cập nhật đúng; relaunch giữ state dữ liệu, loading không kẹt; sửa tay không bị AI ghi đè.

Rủi ro: nhiều section làm khó tìm; toggle flat và collapse giữ được. Quay lui UI qua toggle, không thay nội dung.
