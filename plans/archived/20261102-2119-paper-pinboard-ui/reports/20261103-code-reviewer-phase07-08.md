# Code review — Phase 07/08 (2026-11-03, code-reviewer)

Phạm vi: Lưu nhanh, Share Extension, component dùng chung, tinh chỉnh Library/Collections, bundle ID, UI tests. Bỏ qua Intelligence (plan khác). Kiểm chứng: build-for-testing generic iOS, không ký → TEST BUILD SUCCEEDED. Reviewer không chạy test.

Không có lỗi Critical.

## Medium

| ID | Vấn đề | Trạng thái |
|---|---|---|
| M1 | Banner lỗi ghi bản nháp nằm dưới khung đầu (`CaptureSheet`), người dùng không thấy | **Đã sửa** 2026-11-03: banner đặt trên thanh Lưu |
| M2 | Tiêu đề/thẻ/bộ sưu tập bị bỏ khi item mới không khớp (đang có import khác, hoặc import kéo thêm batch khác) vì draft đã bị xoá; có thể báo “hàng đợi” sai | **Đã sửa** 2026-11-03. Xem ghi chú M2 bên dưới. |
| M3 | Cỡ chữ cố định (đo từ mock) không co giãn theo Dynamic Type: CaptureSheet, PaperFieldLabel, NotedButtonStyle prominent, ItemCard, CollectionsView, Share | **Đã sửa** 2026-11-03. Xem ghi chú M3 bên dưới. |
| M4 | UI test hard-code `dev.nhhai7.Noted`/`NotedGateHost` trong khi build lấy từ `.env` | Mở. Đề xuất `XCUIApplication()` và tiêm ID host qua build setting |

### Ghi chú sửa M2

- `PostCaptureOptions` được lưu bền theo payload id (`pending-capture-options.json`) trước khi publish.
- Sau mỗi `importPending`, options áp dụng cho các item có `captureID` bắt đầu bằng `<payload>.`.
- Sheet không còn đoán item qua đếm số lượng. Khi chưa áp dụng xong, sheet báo rằng tùy chọn sẽ tự áp dụng.
- Unit test mới cho 4 tình huống:
  - import bị hoãn hoặc lỗi;
  - batch khác được import cùng lúc;
  - mở lại app trước khi import;
  - batch đã bị bỏ thì options được dọn.

### Ghi chú sửa M3

- Thêm `scaledFont(_:weight:relativeTo:)`: `@ScaledMetric` scale một hệ số chứ không scale chính cỡ chữ, vì ScaledMetric làm tròn theo lưới pixel nên 15.5 sẽ thành 15.67 ngay ở cỡ mặc định.
- Ở cỡ L, mọi giá trị đo giữ nguyên. Ảnh fixture ở cả 3 màn trùng lần chạy trước M3 (sai khác ≤0.04% điểm ảnh, chủ yếu ở đồng hồ).
- Cột icon trong Lưu nhanh dùng `@ScaledMetric` nguyên.
- UI test mới `testMeasuredTextSizesScaleWithDynamicType`: chữ đã đo phải cao hơn ≥15% ở cỡ XXXL.
- Tab bar (`RootView`, 24/12 pt) chưa đổi: nằm ngoài phạm vi review.

## Low

- **L1** — mở: chip thẻ cao 33 pt, chạm một lần là xoá, không undo.
- **L2** — mở: ô nhập thẻ có thể bị cuộn khuất khi có nhiều thẻ.
- **L3** — **đã sửa**: “Xóa bản nháp” giờ xoá cả `tagInput`.
- **L4** — mở: chưa có test riêng cho việc tự cuộn khi mở “Tùy chọn khác”.
- **L5** — mở: VoiceOver
  - hàng Bộ sưu tập chưa có nhãn “Bộ sưu tập”;
  - tiêu đề “Lưu nhanh” và tiêu đề Share thiếu trait header.
- **L6** — mở: phần khớp item và xoá draft trong `save()` chưa có unit test; điều kiện bị lặp với `CapturePostOptions.apply`.
- **L7** — mở: test chưa kiểm hết điều tên test hứa:
  - chưa đếm số mục được ghim;
  - chưa kiểm thẻ/bộ sưu tập còn sau relaunch;
  - `MockFidelityUITests.testCapture` chỉ kiểm nội dung;
  - chưa có UI test lưu link/ảnh qua sheet.
- **L8** — mở: thanh Lưu dùng `paper` phẳng, còn Share dùng `paperBackground`.
- **L9** — mở: tham chiếu cũ:
  - comment trong `MockFixtures.swift:30`;
  - `docs/device-setup.md` còn ID `dev.nguyenhoanghai861`;
  - UTType backup cũ được giữ có chủ đích.
- **L10** — mở: các trường draft mới sai kiểu làm mất cả body; nên dùng `try?` cho từng trường.

## Đã kiểm, ổn

- Không lưu hai lần.
- `onGeometryChange` không tạo vòng lặp layout.
- ID trong DisclosureGroup đúng.
- `markTitleEdited` đúng.
- Draft cũ vẫn đọc được.
- Hợp đồng payload, giới hạn và identifier của Share Extension giữ nguyên.
- Entitlements đúng.
- Token dark mode có đủ.
- Quy tắc lật mép `% 4` độc lập với tông.
