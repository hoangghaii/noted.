# Phase 03 — Chủ đề & giao diện nhóm

Ngày 2026-11-03. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 02 và [plan Giấy & Bảng ghim](../20261102-2119-paper-pinboard-ui/plan.md) Phase 08. Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Phân nhóm chủ đề có học từ sửa tay; section theo chủ đề trên Thư viện/Tìm kiếm dùng component giấy mới; quản lý topic.

## File ảnh hưởng

- Create (đề xuất) `Noted./Noted/Core/Intelligence/TopicClassifier.swift` — vector đại diện, ngưỡng/margin, gán nhóm chính/phụ.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/TopicDiscovery.swift` — gom cụm các mục unknown, đề xuất tên.
- Create (đề xuất) `Noted./Noted/Features/Topics/TopicSectionsView.swift` — section dùng chung cho Library/Search, thu gọn/mở rộng, Xem thêm.
- Create (đề xuất) `Noted./Noted/Features/Topics/TopicManagementView.swift` — tạo/đổi tên/gộp/xóa topic, mô tả + ví dụ, bật/tắt AI.
- Create (đề xuất) `Noted./Noted/Features/Topics/TopicOnboardingView.swift` — màn khởi tạo topic.
- Create (đề xuất) `Noted./Noted/Features/Topics/QuickConfirmView.swift` — hàng đợi xác nhận các mục có độ chắc chắn thấp.
- Modify `Noted./Noted/Features/Library/LibraryView.swift`, `Noted./Noted/Features/Search/SearchView.swift` — toggle “Theo chủ đề / Tất cả”, render section.
- Modify `Noted./Noted/Features/Detail/ItemDetailView.swift` — nhóm chính/phụ, đổi nhóm, nhãn “Gợi ý tự động”.
- Modify `Noted./Noted/App/RootView.swift` — lối vào quản lý topic.
- Create (đề xuất) `Noted./NotedTests/TopicClassifierTests.swift`, `Noted./NotedUITests/TopicGroupingUITests.swift`.

## Bước

- [ ] **Khởi tạo (cold start)**: lần đầu bật tính năng, gợi ý danh sách topic gồm các nhóm người dùng đã nêu và các cụm phát hiện được (≥3 mục, độ gắn kết vượt ngưỡng; tên lấy từ từ khóa đại diện). Người dùng chọn/đổi tên/thêm mô tả. Sau đó chạy phân nhóm toàn thư viện, có tiến độ.
- [ ] **Vector đại diện mỗi topic** = mô tả + tên + alias + `TopicExample` (mục người dùng đã xác nhận hoặc sửa tay). Sửa tay → thêm example → tính lại vector đại diện → chạy lại các mục `generated` có score gần ngưỡng. Manual luôn thắng.
- [ ] Ảnh: nếu vector chữ yếu, dùng k-NN theo feature print với các ảnh đã gán nhóm (ngưỡng từ Phase 01).
- [ ] **Xác nhận nhanh**: hàng đợi các mục có margin thấp, vuốt để chấp nhận hoặc đổi nhóm. Mỗi lần xác nhận đều thành example.
- [ ] Tự khám phá nhóm mới: chạy theo batch, kết quả cố định (deterministic), chỉ trên các mục unknown, chỉ khi mở màn quản lý hoặc sau mỗi N mục mới. Không gom cụm lại mỗi lần đổi filter. Nhóm mới chỉ là *đề xuất* cho tới khi người dùng chấp nhận.
- [ ] Pipeline hiển thị: loại trash → pill/collection/query → nhóm theo assignment đã cache → phân trang theo section. Không gọi model trong `body` của view.
- [ ] Section:
  - đếm số mục trong kết quả đã lọc; mỗi mục chỉ xuất hiện một lần;
  - nhóm rỗng thì ẩn;
  - thứ tự nhóm theo tên tiếng Việt, “Chưa phân nhóm” ở cuối;
  - trong mỗi nhóm: pin trước rồi mới nhất (Library), mới nhất (Search);
  - giữ trạng thái thu gọn/mở khi đổi pill.
- [ ] Mục đang chờ hiện nhãn “Đang phân tích”; lỗi có nút thử lại; không spinner vô hạn.
- [ ] Gộp topic (ví dụ Hài hước + Vui nhộn): chỉ khi người dùng chọn. Atomic, giữ alias, chuyển assignment + example. Có undo trong phiên.
- [ ] Dùng `PaperCard`/`EqualWidthPills`, giữ `accessibilityIdentifier`. VoiceOver đọc được “Cà phê, 3 mục”.

## Acceptance

- Trên iPhone, mọi pill All/Images/Links/Notes/Inbox/Pinned + collection/search: tập ID trước và sau khi nhóm khớp nhau, không mất và không duplicate.
- Sửa/gộp/đổi tên cập nhật đúng. Relaunch giữ state. Sửa tay không bị AI ghi đè.
- Precision trên holdout không thấp hơn Phase 01; precision sau 10 lần sửa tay tăng hoặc giữ nguyên (báo cáo số liệu).

## Rủi ro

Quá nhiều section làm khó tìm → giữ toggle “Tất cả” + thu gọn. Hai section trùng nghĩa → gợi ý gộp, không tự gộp. Quay lui: toggle về danh sách phẳng, không đổi dữ liệu.
