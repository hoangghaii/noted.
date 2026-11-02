# Phase 03 — Nội dung và khám phá

Ngày 2026-11-02. Ưu tiên cao. Phụ thuộc: phase 02. Triển khai: code và ảnh iPhone thật đã có cho Thư viện, Tìm kiếm, Bộ sưu tập, chi tiết/chỉnh sửa trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md); phân trang/lọc/ghim và editor qua UI tests. Review: đã rà soát mã và biên dịch test targets.

## Phạm vi và file

- Modify `/Users/nhhai7/LocalData/Noted./Noted/Features/Library/LibraryView.swift` — hierarchy, filter, empty/pending state, CTA và pagination.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/Features/Library/ItemCard.swift` — card note/link/ảnh, pin, thumbnail/loading/fallback.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/Features/Search/SearchView.swift` — field tìm, filter và kết quả/empty state.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/Features/Collections/CollectionsView.swift` — danh sách/empty/tạo/sửa collection.
- Modify `/Users/nhhai7/LocalData/Noted./Noted/Features/Detail/ItemDetailView.swift` — detail, editor, action menu và form state.
- Reference: [Design Lab](../../docs/design-preview/component-lab.html), [topic UI plan độc lập](../20261029-1623-smart-topic-groups/phase-03-grouped-library-ui.md).

## Bước triển khai

- [x] Thư viện: áp dụng tiêu đề gọn → filter → card, với CTA Lưu nhanh cố định từ phase 02. Giữ `LibraryFilter.includes`, pin-first/newest, collection scoping, giới hạn 50 mục/lượt, “Xem thêm” và pending import retry/discard.
- [x] Card: hiển thị loại, tiêu đề, excerpt/domain, ngày/collection; pin có nhãn. Thumbnail giữ tỷ lệ, loading và lỗi giải mã không che thao tác hoặc làm mất bản gốc.
- [x] Search: tăng nổi bật ô nhập và bộ lọc, giữ debounce 250 ms, SearchService tiếng Việt có/không dấu, kind/time/collection filter và URL chỉ mở khi người dùng chạm trong detail.
- [x] Collections/detail/editor: dùng cùng token và form/error style; giữ tạo/đổi tên/xóa collection, sửa item, bản nháp sau đóng/lỗi, copy/share original, OCR disclaimer và confirm destructive.
- [x] Giữ `accessibilityIdentifier` và hành vi filter/search; cập nhật UI test cho bước xác nhận chuyển vào Thùng rác. Không thêm topic grouping từ kế hoạch riêng, không đổi model hoặc query semantics.
- [ ] Kiểm tra màn hình trống, nội dung dài, tiếng Việt có dấu, ảnh lỗi, item ghim, kết quả rỗng, keyboard focus và cuộn form.

## Nghiệm thu

- Cùng tập item và thứ tự trước/sau redesign cho All/Inbox/Ảnh/Link/Ghi chú/Đã ghim, collection và Search; không mất/nhân đôi item khi đổi filter hoặc load more.
- Tạo/sửa item và collection, đóng/mở lại vẫn giữ dữ liệu/bản nháp; lỗi có thông báo và thao tác tiếp theo. URL không tự mở khi vào detail.
- UI test fixture hiện có cho pagination/filter/pin, empty/add/keyboard, detail/ảnh và search được chạy lại trên iPhone thật; test đang lỗi locator được sửa và báo kết quả riêng.

Rủi ro: hero/CTA chiếm chỗ danh sách trên iPhone 12 Pro. Giảm chiều cao theo thực tế, giữ item đầu tiên thấy được và card có vùng chạm đủ lớn. Rollback trình bày theo từng màn hình; không rollback dữ liệu.

## Bằng chứng trước nghiệm thu thiết bị

Các ghi chú thiết bị `unavailable` dưới đây là trạng thái của lượt triển khai trước Phase 05; kết quả iPhone thật mới nằm trong [báo cáo Phase 05](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md).

- `xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/noted-phase03-derived CODE_SIGNING_ALLOWED=NO build` đạt `BUILD SUCCEEDED`.
- Cùng cấu hình với `build-for-testing` đạt `TEST BUILD SUCCEEDED` sau sửa accessibility; UI tests chỉ được biên dịch, chưa thực thi.
- `xcrun devicectl list devices` báo iPhone 12 Pro vật lý `unavailable`; lần kiểm tra sau bị CoreDevice timeout khi khởi tạo. Chưa có bằng chứng UI cho tập item/thứ tự sau redesign, thao tác dữ liệu, màn hình trống/ảnh lỗi/chữ dài, vùng chạm hay keyboard; checkbox kiểm tra UI và nghiệm thu vẫn mở.
