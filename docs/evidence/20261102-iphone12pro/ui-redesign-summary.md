# Phase 05 — Design Lab trên iPhone 12 Pro

Ngày 2026-11-02. Thiết bị vật lý iPhone 12 Pro, iOS 27.0.1, UDID `00008101-001A2519266B001E`; app `dev.nhhai7.Noted`. Thiết bị kết nối dây, đã ghép đôi và bật Developer Mode. Build Debug ký hợp lệ; cài đè cùng bundle ID, không gỡ app.

## Đối chiếu hình ảnh

Ảnh dưới đây chụp từ iPhone thật sau khi chỉnh lại theo [Design Lab](../../design-preview/component-lab.html). Fixture UI tách khỏi thư viện cá nhân. Đã đối chiếu hierarchy, màu, cỡ chữ, khoảng cách và vị trí thao tác ở cấu hình chữ mặc định.

| Màn               | Bằng chứng                                                                                               | Kết quả quan sát                                                      |
| ----------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Home Screen       | [Icon](00-home-icon.png)                                                                                 | Folded N hiện rõ ở kích thước icon thật.                              |
| Thư viện          | [Library](01-library.png)                                                                                | Header, hero xanh, CTA san hô, filter, card hai cột và tab bar phẳng. |
| Tìm kiếm          | [Search](02-search.png)                                                                                  | Kết quả dạng hàng, trường tìm kiếm và tab bar.                        |
| Bộ sưu tập        | [Danh sách](03-collections.png), [chi tiết](03a-collection-detail.png)                                   | Hàng thư mục, điều hướng vào và quay lại.                             |
| Nội dung          | [Chi tiết](04-note-detail.png), [biên tập](05-note-editor.png)                                           | Chữ, hành động và đường quay lại.                                     |
| Lưu nhanh         | [Ghi chú](06-capture-note.png), [link](07-capture-link.png), [ảnh](08-capture-image.png)                 | Sheet có ba loại nội dung, form và CTA cố định.                       |
| Thùng rác, backup | [Thùng rác](09-empty-trash.png), [backup](10-data-backup.png), [xác nhận xóa](14-trash-confirmation.png) | Trạng thái trống, hành động dữ liệu và xác nhận xóa.                  |
| Share Extension   | [Photos preview](15-photos-share-preview.png), [Safari preview](16-safari-share-preview.png)             | Preview nguồn thật trước khi nhấn Lưu.                                |

Design Lab là HTML với dữ liệu mẫu; ảnh thật có status bar, sheet/Files/Photos picker và dữ liệu khác. Không có phép đo pixel tương đương để khẳng định chính xác 98–100%. Các phần chính được đối chiếu trực quan; sai khác native và nội dung được ghi riêng thay vì coi là đạt phần trăm.

## Thiết bị và dữ liệu

Trước cài đè, thư viện cá nhân có 17 mục, gồm ảnh, link và ghi chú; [ảnh trước cài](before-install-library.png). Sau lần cài đầu, 17 mục cũ vẫn hiển thị; [ảnh sau cài](after-install-library.png). Các ca Share nguồn thật thêm 5 mục thử vào thư viện cá nhân. Sau build/ký/cài đè bản cuối và mở lại, thư viện hiển thị 22 mục, gồm các mục cũ và mục thử; [ảnh sau cài bản cuối](after-final-install-library.png). Không xóa dữ liệu cá nhân để dọn fixture. UI acceptance khác dùng kho DEBUG riêng.

## Kết quả kiểm thử

- **42/42 unit tests đạt** trên iPhone thật với source cuối: `/private/tmp/noted-ui-phase5-final-unit-2.xcresult`.
- Build iPhoneOS cuối **BUILD SUCCEEDED**: `/private/tmp/noted-ui-phase5-release-build.log`. `codesign --verify --deep --strict` app và `codesign --verify --strict` Share extension đều đạt; bundle ID kiểm tra từ Info.plist là `dev.nhhai7.Noted`, icon nằm trong app bundle. `devicectl install app` và `process launch` đều thành công trên thiết bị.
- Safari và Photos Share preview/payload: 2/2 trên iPhone thật, `/private/tmp/noted-ui-phase5-share-preview.xcresult`. Preview được chụp trước khi lưu. Photos dùng nội dung thử có kiểm soát.
- Files backup export/import: 1/1 trên iPhone thật, `/private/tmp/noted-ui-phase5-backup-final.xcresult`; ca này dùng thư viện cá nhân hiện có, xuất một gói vào “Trên iPhone” rồi nhập lại, kết quả 0 mục mới, không tạo mục trùng. Gói backup được giữ trong Files.
- Phân trang, lọc, ghim và mở lại: 1/1 trên iPhone thật, `/private/tmp/noted-ui-phase5-pagination-final.xcresult`. Nút “Xem thêm” nhìn thấy và nhận chạm; XCTest `isHittable` trả false dù nút hoạt động, nên ca cuối xác nhận vị trí trên vùng nhìn thấy và chạm tọa độ trung tâm.
- Bộ UI cuối: **9/9 đạt** trên iPhone thật, `/private/tmp/noted-ui-phase5-final-ui-2.xcresult`. Gồm chụp màn, Home icon, lưu và ghim, editor/draft, keyboard, ảnh/link, phân trang, pending import và Trash restore/cancel/xóa trên fixture. Ảnh xác nhận xóa ở trên lấy từ chính lượt này.

## Giới hạn còn mở

Chưa đo tương đồng pixel 98–100%, chưa kiểm thử VoiceOver/dark mode toàn diện. Thông báo xác nhận xóa tự dựng chưa chứa focus VoiceOver như alert hệ thống. Chưa có fault injection riêng cho trường hợp lưu thành công nhưng ghim thất bại, hoặc đo loading/chạm lặp ngay khi busy; mã có đường thoát “Về Thư viện” và guard chống submit lặp. Không dùng ca xóa trên thư viện cá nhân. Các lỗi bật Automation Mode và trust chứng chỉ trước test body trong lượt đầu là lỗi hạ tầng; các ca được chạy lại sau khi phiên thiết bị ổn định.
