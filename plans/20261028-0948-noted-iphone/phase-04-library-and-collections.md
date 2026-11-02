# Phase 04 — Library, chi tiết và tổ chức

Trạng thái: đang hoàn thiện nghiệm thu; ngày 2026-10-29 có 11 lifecycle tests đạt trong 42 unit tests trên iPhone thật. UI 4/6 luồng đạt; restore và editor foreground/import còn mở. Phụ thuộc thiết kế: [03](phase-03-capture-and-share.md).
Mục tiêu: duyệt, sửa và tổ chức nội dung trên iPhone.

## Quyết định

Ba tab Library, Search, Collections; Search hoàn thiện phase 05.
Library All/Images/Links/Notes, mới nhất trước; grid dùng thumbnail.
Inbox là item chưa có collection. Mỗi item tối đa một collection; tag nhiều giá trị; pin độc lập.
Trash qua `trashedAt`, không auto-purge trong MVP.

## File dự kiến — Create

- `/Users/nhhai7/LocalData/Noted./Noted/App/RootView.swift`: tabs/navigation.
- `/Users/nhhai7/LocalData/Noted./Noted/Features/Library/LibraryView.swift`: filters/grid/list.
- `/Users/nhhai7/LocalData/Noted./Noted/Features/Library/ItemCard.swift`: card theo loại.
- `/Users/nhhai7/LocalData/Noted./Noted/Features/Detail/ItemDetailView.swift`: xem/sửa/share/pin.
- `/Users/nhhai7/LocalData/Noted./Noted/Features/Collections/CollectionsView.swift`: collection/tag CRUD.
- `/Users/nhhai7/LocalData/Noted./Noted/Features/Trash/TrashView.swift`: restore/xóa vĩnh viễn.
- `/Users/nhhai7/LocalData/Noted./Noted/Core/Storage/ThumbnailService.swift`: thumbnail/cache có giới hạn.
- `/Users/nhhai7/LocalData/Noted./NotedTests/LibraryLifecycleTests.swift`: lifecycle và save failure.

## Các bước

Source cho các chức năng dưới đây đã có. Ô chưa đánh dấu nghĩa là chưa đủ bằng chứng nghiệm thu toàn bộ dòng, không đồng nghĩa chức năng chưa được implement.

- [x] Library lazy rendering/pagination, empty/pending-error state, thêm nội dung (UI: phân trang/lọc đạt, thư viện rỗng/thêm note đạt, pending retry/discard đạt trên iPhone).
- [x] Detail theo loại; mở URL chỉ sau thao tác; share ảnh gốc mở system share sheet (UI đạt; chưa kiểm tra bytes sau khi app nhận).
- [ ] Sửa note/caption/title/tag; save lỗi giữ draft.
- [x] Collection một cấp; xóa collection đưa item về Inbox, không xóa originals (lifecycle test; test ảnh giữ file khi trash/restore).
- [x] Pin/unpin; item trong Trash bị loại khỏi Library/Search mặc định (UI test đạt các bước này trước khi dừng ở locator Restore).
- [ ] Restore/xóa vĩnh viễn qua UI; vòng đời service đã đạt unit tests, nhưng UI chưa xác minh được nút Restore trong hàng Trash.
- [x] Xóa vĩnh viễn có xác nhận; journal deletion trước cleanup file, recovery khi gián đoạn (fault tests sau commit/trước cleanup; save rollback giữ file/checksum).
- [x] Thumbnail nền, fallback ảnh hỏng; detail decode theo kích thước cần (UI fallback đạt; unit decode grid/detail đạt 400/900 px, original bytes giữ nguyên).
- [ ] Vùng chạm và bố cục dùng được ở cấu hình mặc định trên iPhone.
- [ ] Incoming import/foreground không ghi đè draft đang sửa.

## Kiểm chứng và acceptance

- [x] Bộ lọc/thứ tự đúng sau relaunch; pin/tag/collection còn nguyên (UI pagination/order/filter/pin đạt; lifecycle reopen kiểm tra tags/collection).
- [x] Xóa collection không xóa item/file; restore về collection còn tồn tại hoặc Inbox (unit tests, gồm collection chứa ảnh đang ở Trash).
- [x] Trash giữ originals đến lúc xóa vĩnh viễn; cleanup gián đoạn phục hồi được (hai điểm gián đoạn, reopen store; 2026-10-29).
- [ ] Save lỗi/import mới không làm mất note đang sửa.
- [x] Bàn phím dùng được trên iPhone thật ở cấu hình mặc định (UI nhập/lưu note từ empty state đạt; không bao gồm ngoài phạm vi cỡ chữ lớn).

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<IPHONE_UDID>' -only-testing:NotedTests/LibraryLifecycleTests test
```

Điều chỉnh phạm vi theo yêu cầu người dùng ngày 2026-10-29: không yêu cầu workload 500 item, VoiceOver, chữ lớn/Dynamic Type hoặc dark mode để nghiệm thu. Giữ hỗ trợ sẵn có; không đánh dấu các mục bỏ khỏi phạm vi là đã test đạt.

## Bằng chứng bổ sung 2026-10-29

- [39 unit tests, 0 lỗi](../../docs/evidence/20261029-iphone12pro/phase4-unit-summary.json), gồm 8 `LibraryLifecycleTests`; iPhone 12 Pro/iOS 27.0.1. Artifact cuối: `/private/tmp/noted-phase4-all-unit-v2.xcresult`.
- Test mới: pin/tag/collection/trash tồn tại khi mở store mới; save bị lỗi không mất draft trên đĩa; import queue không thay draft; xóa gián đoạn phục hồi; save xóa bị rollback giữ ảnh/checksum; link chưa có metadata vẫn có tiêu đề.
- [UI editor đạt 1/1](../../docs/evidence/20261029-iphone12pro/phase4-editor-ui-summary.json): tạo note, sửa tiêu đề, đóng editor, terminate/relaunch, mở lại draft và lưu. Artifact: `/private/tmp/noted-phase4-editor-ui-v2.xcresult`. Chưa có import mới trong lúc editor đang mở.
- Giữ journal khi save/refresh ném lỗi để lần mở sau cleanup an toàn. Thêm trạng thái ghim đọc được, filter cao tối thiểu 44pt và actions thùng rác xếp dọc khi cỡ chữ trợ năng.
- Các kiểm chứng UI còn trong phạm vi chỉ đánh dấu sau khi có bằng chứng thực; unit test draft không thay thế UI editor khi foreground/import.
- UI acceptance 2026-10-29 (iPhone 12 Pro): 4/6 luồng đạt. Đạt: pagination/filter/order/pin sau relaunch; empty/add/keyboard/relaunch; pending error retry/discard/relaunch; fallback ảnh, share sheet original, và explicit URL opening. Còn mở: editor save-error/import (form scroll chưa tới tags) và restore UI (nút trong hàng `StaticText` chưa định vị được). Artifact lần đầu: `/private/tmp/noted-phase4-acceptance-ui-v1.xcresult`; targeted rerun: `/private/tmp/noted-phase4-acceptance-ui-v2.xcresult` (1/3 đạt).

## Rủi ro và quay lui

Không decode toàn bộ originals trong grid; không auto-purge trash để lấy chỗ.
Rollback UI/service giữ schema và dữ liệu; app cũ không mở store đã migrate.
Còn mở: tinh chỉnh card sau sử dụng thật; chính sách trash ngoài MVP.
