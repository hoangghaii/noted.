# Phase 05 — Nghiệm thu trên iPhone thật

Ngày 2026-11-02. Ưu tiên cao. Phụ thuộc: phase 01–04. Triển khai: build/ký/cài đè và các ca thiết bị chính đã đạt; hai tiêu chí định lượng 98–100% và kiểm tra tải/chạm lặp khi busy vẫn mở. Review: đã thực hiện, xem [báo cáo thiết bị](../../docs/evidence/20261102-iphone12pro/ui-redesign-summary.md).

## Phạm vi và file

- Modify `Noted./NotedUITests/PhaseFourAcceptanceUITests.swift` và `Noted./NotedUITests/LibraryUITests.swift` **chỉ phần locator/fixture cần cho UI mới**; giữ assertion nghiệp vụ.
- Modify `Noted./NotedUITests/ExternalShareUITests.swift` **nếu Share UI thay hierarchy**; không thay test thành kiểm tra text đơn thuần.
- Modify `Noted./docs/verification.md` — kết quả mới, thiết bị, phiên bản, file evidence và hạn chế.
- Create `Noted./docs/evidence/YYYYMMDD-iphone12pro/ui-redesign-summary.md` (đường dẫn dự kiến) — checklist, ảnh chụp màn hình và kết quả thực; ngày tạo theo ngày chạy.
- Review `Noted./docs/design-guideline.md` để khớp bản triển khai cuối.

## Bước kiểm chứng

- [ ] Đối chiếu từng màn với [Design Lab](../../docs/design-preview/component-lab.html) theo yêu cầu bám sát 98–100%: header, hero, card, kết quả tìm kiếm, bộ sưu tập, tab bar, sheet/form, màu, typography, khoảng cách, nút và phản hồi. Chụp lại sau mỗi lượt chỉnh. Ghi riêng khác biệt do native iOS, dữ liệu thật và các sai khác còn tồn tại; không tuyên bố phần trăm đã đo nếu chưa có phép đo tương đương.

- [x] Xác minh thiết bị iPhone hiện kết nối, bundle ID và signing trước build. Build iPhoneOS bằng scheme Noted; kiểm tra icon trong app bundle/asset, codesign cả app + extension. Log build và kết quả codesign trong báo cáo.
- [x] Ghi trạng thái dữ liệu có sẵn trước cài đè bằng quan sát an toàn (ví dụ một note, một link, một ảnh và tổng số mục); nếu cần, tạo backup đã kiểm chứng. **Không gỡ app**. Cài đè cùng `dev.nhhai7.Noted`, mở lại và đối chiếu nội dung cũ/ảnh gốc. 17 mục cũ trước/sau lần đầu; bản cuối mở được và hiện 22 mục sau 5 mục Share thử.
- [x] Chụp màn Home Screen với icon ở kích thước thật; chụp Thư viện, Tìm kiếm, Bộ sưu tập, form note/link/ảnh, chi tiết, Share sheet, Trash và backup. So với [Design Lab](../../docs/design-preview/component-lab.html) theo hierarchy, màu, chữ, spacing; ghi rõ sai khác hợp lý của native UI.
- [x] Chạy unit/build checks liên quan trên iPhone thật. Chạy UI tests bằng fixture store cho filter/pagination, search, keyboard/capture, draft, image fallback, Trash/backup; không dùng dữ liệu cá nhân cho ca xóa. Với Share, dùng nguồn Safari/Photos thật và kiểm tra destination state/preview trước kết luận. 42/42 unit, 9/9 UI, 2/2 Share, 1/1 backup Files.
- [ ] Kiểm tra vùng chạm và màn hình cuộn trên iPhone 12 Pro ở cấu hình mặc định, chữ tiếng Việt đủ dấu; loading có tiến trình, submit không lặp, empty/error có lối tiếp tục. Cuộn, chạm, chữ Việt, empty/error và lưu một lần đã có UI evidence; chưa có đo riêng thời gian loading hoặc thao tác chạm lặp đúng lúc busy. Dark mode toàn diện nằm ngoài phạm vi acceptance.
- [x] Review thay đổi với source và evidence; cập nhật status từng phase chỉ khi acceptance tương ứng đã đạt. Phân biệt lỗi sản phẩm với lỗi Xcode/RemoteXPC/trust, và ghi ca còn mở.

## Điều kiện hoàn tất

Icon mới và các màn chính hiển thị đúng trên iPhone thật; cài đè giữ nội dung; các luồng bị UI chạm tới vẫn hoạt động, screenshot/evidence gắn với build và thiết bị; không có regression quan trọng đã xác nhận. Build hoặc unit tests đơn lẻ không đủ để gọi nghiệm thu UI/Share.

Rủi ro: test runner/RemoteXPC có thể gián đoạn, và UI locator cũ có thể không tìm thấy control mới. Sửa locator dựa trên hierarchy/screenshot thật, chạy lại ca chưa xong; không báo NG sản phẩm từ lỗi hạ tầng. Rollback nếu có regression: cài đè bản app trước đó với cùng bundle ID, giữ dữ liệu và backup; không uninstall.
