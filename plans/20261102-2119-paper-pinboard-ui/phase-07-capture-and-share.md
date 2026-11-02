# Phase 07 — Lưu nhanh và Share Extension

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 04 · Trạng thái: chưa bắt đầu · Review: chưa

## Khác biệt hiện tại ↔ mock (Lưu nhanh, chế độ Ghi chú)

| Phần | Hiện tại (`CaptureSheet.swift`) | Mock v3 |
|---|---|---|
| Đầu sheet | nav bar inline “Lưu nhanh”, nút chữ “Đóng” | drag indicator; tiêu đề lớn “Lưu nhanh” trái; nút X tròn phải |
| Chế độ | `Picker(.segmented)` trong khung brandSoft | 3 pill độc lập bằng nhau, icon + nhãn, khoảng cách, không khung chung |
| Trường | “Điều bạn muốn giữ *” + TextEditor | “Tiêu đề” (ô 1 dòng) → “Nội dung” (vùng giấy lớn) → “Bộ sưu tập” (hàng icon thư mục + tên + chevron) → “Thẻ” (icon tag + chip) |
| Phụ trợ | dòng “Bản nháp…”, Ghim sau khi lưu, Dán, offline, đếm ký tự, Xoá bản nháp | không có trong khung nhìn |
| Nút lưu | honey trong `safeAreaInset` | honey full width cao ~50, chữ forest đậm “Lưu ghi chú” |

## Kiến trúc cho Tiêu đề / Bộ sưu tập / Thẻ

- `NoteDraft` thêm `title: String`, `collectionID: UUID?`, `tags: [String]` với `decodeIfPresent` mặc định → bản nháp cũ vẫn đọc được.
- `store.captureText/captureLink/captureImageFiles` giữ nguyên (không đổi `ShareGatePayload`). Sau khi lưu, tìm item mới bằng cơ chế `existingIDs`/`matchesCapture` đang dùng cho “Ghim sau khi lưu”, rồi gọi `store.update(item, title:, body: item.body, tags:, collectionID:)` và `togglePin` nếu cần. Gom thành một hàm `applyPostCaptureOptions`.
- Nếu item chưa xuất hiện (vào hàng đợi) hoặc update lỗi: nội dung **đã lưu**; hiện alert như luồng ghim hiện có, nêu rõ phần nào chưa áp dụng.
- Tiêu đề rỗng → giữ hành vi `displayTitle` hiện tại. Ghi `userEditedTitle` qua `update` nếu hàm đó đặt cờ (kiểm tra; nếu không thì để LinkMetadata không ghi đè tiêu đề người dùng).

## File

| Đường dẫn | Hành động | Lý do |
|---|---|---|
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Capture/CaptureSheet.swift` | sửa | Bố cục mới, pill chế độ, trường mới, hàng “Tùy chọn khác” |
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Capture/NoteDraftStore.swift` | sửa | Trường draft mới, tương thích ngược |
| `/Users/hainguyen/LocalData/Noted./NotedShare/ShareViewController.swift` | sửa | Nền giấy, preview `PaperCard`, `PaperField`, nút Lưu Capsule honey, “Hủy” → `CircleIconButton` X nếu không phá chuẩn extension |
| `/Users/hainguyen/LocalData/Noted./NotedTests/CaptureRecoveryTests.swift` | sửa | Test draft cũ đọc được; áp tiêu đề/thẻ/bộ sưu tập sau lưu |
| `/Users/hainguyen/LocalData/Noted./NotedUITests/LibraryUITests.swift`, `PhaseFourAcceptanceUITests.swift` | sửa | `segmentedControls.buttons[...]` → `buttons["captureMode_note|link|photo"]`; “Đóng” → `buttons["captureClose"]` |

## Bước

1. Đầu sheet: ẩn nav bar; `HStack` tiêu đề 28 bold + `CircleIconButton("xmark")` id `captureClose`, label VoiceOver “Đóng”; `presentationDragIndicator(.visible)`, detent `.large` (khớp mock), nền `paper`, `presentationCornerRadius` ~ đo từ mock.
2. Chế độ: `EqualWidthPillGroup` 3 `NotedPill` cao 44 với icon `doc.text` / `link` / `photo` (hoặc Sketch), id `captureMode_<mode>`, trait selected; giữ id nhóm `captureMode`.
3. Ghi chú: Tiêu đề (`PaperField`, id `captureTitle`) → Nội dung (TextEditor nền `toneCream` + grain, cao ~180, id `captureBody`, placeholder giữ) → Bộ sưu tập (`Menu` liệt kê “Inbox” + collections; hàng icon thư mục + tên + chevron; id `captureCollection`) → Thẻ (icon `tag` + các `TagChip` có nút xoá + `TextField` thêm thẻ khi Enter/dấu phẩy; id `captureTags`).
4. Link: Tiêu đề → “Liên kết *” (`captureURL`, lỗi hợp lệ giữ nguyên) → “Ghi chú đi kèm” → Bộ sưu tập → Thẻ. Ảnh: ô chọn ảnh (giữ `capturePhotos`, viền nét đứt, nền `toneSage`) → Ghi chú đi kèm → Bộ sưu tập → Thẻ. Nút lưu đổi nhãn theo chế độ như hiện tại.
5. “Tùy chọn khác” (đã chốt): `DisclosureGroup` thu gọn dưới Thẻ chứa Ghim sau khi lưu (`capturePinAfterSave`), Dán nội dung (`capturePaste`), dòng offline, đếm ký tự, Xoá bản nháp — ngoài khung nhìn đầu tiên trên iPhone 12 Pro.
6. Nút lưu: `NotedButtonStyle(.primary)` prominent cao 50, full width, `safeAreaInset` nền `paper`; id `captureSave`; giữ busy/`operationLoading`/chống chạm lặp.
7. Share Extension: áp nền, `PaperCard` cho preview, field style, nút Lưu honey Capsule full width; không đổi payload, kích thước giới hạn, `shareSave`, `sharePreview`, `sharePreflightError`.

## Todo

- [ ] Draft fields + test tương thích ngược
- [ ] Đầu sheet + X tròn
- [ ] Pill chế độ bằng nhau
- [ ] Trường Tiêu đề / Nội dung / Bộ sưu tập / Thẻ cho 3 chế độ
- [ ] `applyPostCaptureOptions` + test
- [ ] “Tùy chọn khác”
- [ ] Share Extension đồng bộ
- [ ] Cập nhật UI tests

## Nghiệm thu

- Fixture `capture`: checklist ≥ 98%, trọng yếu 100%.
- Unit: draft JSON cũ (không có trường mới) đọc được; lưu ghi chú có tiêu đề/thẻ/bộ sưu tập → item có đúng giá trị.
- UI: lưu ghi chú/link/ảnh, ghim sau lưu, keyboard không che nút lưu, đóng sheet giữ bản nháp; Share Safari/Photos 2/2 đạt.

## Rủi ro

- Áp tiêu đề/thẻ sau khi import là hai bước → lỗi giữa chừng: nội dung vẫn còn, báo rõ; không lặp lưu.
- Bàn phím che trường Thẻ ở cuối → `scrollDismissesKeyboard` + `ScrollViewReader` cuộn tới trường đang focus.
- Share Extension giới hạn bộ nhớ ~120 MB → texture tile nhỏ, không ảnh lớn.
