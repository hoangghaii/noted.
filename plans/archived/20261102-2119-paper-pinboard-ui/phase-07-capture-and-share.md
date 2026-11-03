# Phase 07 — Lưu nhanh và Share Extension

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 04 · Trạng thái: hoàn tất (2026-11-03) · Review: [code-reviewer](reports/20261103-code-reviewer-phase07-08.md); M2 đã sửa

## Khác biệt hiện tại ↔ mock (Lưu nhanh, chế độ Ghi chú)

| Phần | Hiện tại (`CaptureSheet.swift`) | Mock v3 |
| --- | --- | --- |
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
| --- | --- | --- |
| `Noted./Noted/Features/Capture/CaptureSheet.swift` | sửa | Bố cục mới, pill chế độ, trường mới, hàng “Tùy chọn khác” |
| `Noted./Noted/Features/Capture/NoteDraftStore.swift` | sửa | Trường draft mới, tương thích ngược |
| `Noted./NotedShare/ShareViewController.swift` | sửa | Nền giấy, preview `PaperCard`, `PaperField`, nút Lưu Capsule honey, “Hủy” → `CircleIconButton` X nếu không phá chuẩn extension |
| `Noted./NotedTests/CaptureRecoveryTests.swift` | sửa | Test draft cũ đọc được; áp tiêu đề/thẻ/bộ sưu tập sau lưu |
| `Noted./NotedUITests/LibraryUITests.swift`, `PhaseFourAcceptanceUITests.swift` | sửa | `segmentedControls.buttons[...]` → `buttons["captureMode_note | link | photo"]`; “Đóng” →`buttons["captureClose"]` |

## Bước

1. Đầu sheet: ẩn nav bar; `HStack` tiêu đề 28 bold + `CircleIconButton("xmark")` id `captureClose`, label VoiceOver “Đóng”; `presentationDragIndicator(.visible)`, detent `.large` (khớp mock), nền `paper`, `presentationCornerRadius` ~ đo từ mock.
2. Chế độ: `EqualWidthPillGroup` 3 `NotedPill` cao 44 với icon `doc.text` / `link` / `photo` (hoặc Sketch), id `captureMode_<mode>`, trait selected; giữ id nhóm `captureMode`.
3. Ghi chú: Tiêu đề (`PaperField`, id `captureTitle`) → Nội dung (TextEditor nền `toneCream` + grain, cao ~180, id `captureBody`, placeholder giữ) → Bộ sưu tập (`Menu` liệt kê “Inbox” + collections; hàng icon thư mục + tên + chevron; id `captureCollection`) → Thẻ (icon `tag` + các `TagChip` có nút xoá + `TextField` thêm thẻ khi Enter/dấu phẩy; id `captureTags`).
4. Link: Tiêu đề → “Liên kết *” (`captureURL`, lỗi hợp lệ giữ nguyên) → “Ghi chú đi kèm” → Bộ sưu tập → Thẻ. Ảnh: ô chọn ảnh (giữ `capturePhotos`, viền nét đứt, nền `toneSage`) → Ghi chú đi kèm → Bộ sưu tập → Thẻ. Nút lưu đổi nhãn theo chế độ như hiện tại.
5. “Tùy chọn khác” (đã chốt): `DisclosureGroup` thu gọn dưới Thẻ chứa Ghim sau khi lưu (`capturePinAfterSave`), Dán nội dung (`capturePaste`), dòng offline, đếm ký tự, Xoá bản nháp — ngoài khung nhìn đầu tiên trên iPhone 12 Pro.
6. Nút lưu: `NotedButtonStyle(.primary)` prominent cao 50, full width, `safeAreaInset` nền `paper`; id `captureSave`; giữ busy/`operationLoading`/chống chạm lặp.
7. Share Extension: áp nền, `PaperCard` cho preview, field style, nút Lưu honey Capsule full width; không đổi payload, kích thước giới hạn, `shareSave`, `sharePreview`, `sharePreflightError`.

## Todo

- [x] Draft fields + test tương thích ngược
- [x] Đầu sheet + X tròn
- [x] Pill chế độ bằng nhau
- [x] Trường Tiêu đề / Nội dung / Bộ sưu tập / Thẻ cho 3 chế độ
- [x] `applyPostCaptureOptions` + test
- [x] “Tùy chọn khác”
- [x] Share Extension đồng bộ
- [x] Cập nhật UI tests

## Nghiệm thu

- Fixture `capture`: checklist ≥ 98%, trọng yếu 100%.
- Unit: draft JSON cũ (không có trường mới) đọc được; lưu ghi chú có tiêu đề/thẻ/bộ sưu tập → item có đúng giá trị.
- UI: lưu ghi chú/link/ảnh, ghim sau lưu, keyboard không che nút lưu, đóng sheet giữ bản nháp; Share Safari/Photos 2/2 đạt.

## Rủi ro

- Áp tiêu đề/thẻ sau khi import là hai bước → lỗi giữa chừng: nội dung vẫn còn, báo rõ; không lặp lưu.
- Bàn phím che trường Thẻ ở cuối → `scrollDismissesKeyboard` + `ScrollViewReader` cuộn tới trường đang focus.
- Share Extension giới hạn bộ nhớ ~120 MB → texture tile nhỏ, không ảnh lớn.

## Tiến độ 2026-11-03

Đã triển khai giao diện Lưu nhanh theo mock cho ba chế độ, trường Tiêu đề/Bộ sưu tập/Thẻ, bản nháp tương thích JSON cũ, áp metadata và ghim sau lưu, cùng giao diện giấy của Share Extension. Fixture capture và locator UI được cập nhật. `LibraryStore.update` nhận tùy chọn `markTitleEdited` mặc định `true` để việc thêm thẻ/bộ sưu tập không khóa tiêu đề tự động của link khi người dùng bỏ trống Tiêu đề.

Kiểm chứng: `xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/noted-phase7-derived CODE_SIGNING_ALLOWED=NO build-for-testing` → `** TEST BUILD SUCCEEDED **` (2026-11-03). Đây là kết quả biên dịch, chưa phải kết quả chạy unit/UI test.

`xcrun devicectl list devices` chỉ thấy iPhone 12 Pro simulated đang kết nối; iPhone 12 Pro vật lý trong giả định của plan không hiện là thiết bị khả dụng. Vì vậy checklist fidelity ≥98%, unit/UI chạy trên iPhone, Safari/Photos Share 2/2 và dữ liệu sau cài đè vẫn chờ kiểm chứng. Giữ các ô Todo chưa đánh dấu cho tới khi nghiệm thu trên iPhone thật.

## Retest simulator 2026-11-03 (kit-test)

Simulator iPhone 12 Pro iOS 27.0 (`C66461EB-…`), Debug, override `SUPPORTED_PLATFORMS='iphoneos iphonesimulator' SDKROOT=iphonesimulator`, `-parallel-testing-enabled NO`.

- Unit (scheme Noted): **50/50 passed**, gồm `testLegacyCaptureDraftDecodesWithEmptyNewFields`, `testCapturePostOptionsApplyTitleTagsCollectionAndPin`, `testCaptureTagsWithoutCustomTitleLeaveLinkTitleAvailableForMetadata`, `testPhotoCaptureDoesNotApplyHiddenNoteTitle`.
- UI (PaperComponents, MockFidelity, Library, PhaseFourAcceptance): **19/24**; 2 failure không phải env tái hiện khi chạy riêng.
  - **Lỗi Phase 07:** `testCapturePinsSavedNoteOnce` (`PhaseFourAcceptanceUITests.swift:192`). `.accessibilityIdentifier("captureMoreOptions")` trên `DisclosureGroup` (`CaptureSheet.swift:235`) ghi đè id con: switch Ghim và nút Dán đều mang id `captureMoreOptions`, không còn `capturePinAfterSave`/`capturePaste`.
  - Env: 3 test `LibraryUITests` hard-code `dev.nguyenhoanghai861.Noted`, còn `.env` build `dev.nhhai7.Noted` → không launch được.
  - Không do Phase 07: `testEditorRetainsDraftAfterSaveFailureAndForegroundImport:322`. Trên iOS 27, hàng `fixtureImportCount` của `ItemDetailView` (không đổi) nằm dưới mép màn nên List chưa render.
- Fidelity capture: chưa đo được do thiếu ImageMagick (`magick`). So bằng mắt với mock thấy chevron xuống (mock: sang phải), nhãn “Nội dung *” đậm có dấu sao, vùng nội dung phẳng không có vân giấy/góc cong, ô Bộ sưu tập không có viền/nền trắng, ô Thẻ cao hơn mock vì có dòng “Thêm thẻ”.
- Chưa chạy: Share Safari/Photos (cần iPhone thật), lưu link/ảnh qua UI, bàn phím che nút lưu.

### Sửa và retest 2026-11-03 (sau kit-test)

- Sửa `CaptureSheet.swift`: id `captureMoreOptions` chỉ gắn vào nhãn `DisclosureGroup`; `capturePinAfterSave`/`capturePaste` có lại id riêng.
- UI test: `testCapturePinsSavedNoteOnce` ẩn bàn phím, cuộn header lên trên thanh Lưu rồi mới bấm, sau đó chờ switch xuất hiện (3/3 lần đạt). `testCaptureDraftAndMetadataSurviveRelaunch` đổi selector `app.sheets.scrollViews` (không khớp gì) sang scroll view chứa `captureBody` (3/3). `testEditorRetainsDraft…` cuộn tới `fixtureImportCount` trước khi đọc.
- Bundle ID chuẩn hóa `dev.nhhai7.Noted` (Defaults.xcconfig, 4 file UI test, NotedGateHost `dev.nhhai7.NotedGateHost`). Giữ UTType backup `dev.nguyenhoanghai861.Noted.backup` để không đổi format file.
- Kết quả: unit **50/50**; UI **23/24**. Còn `LibraryUITests.testBackupLocalFilesPicker` chập chờn (2/4 lần fail): lúc fail, picker Files vẫn mở với nút Save → lần chạm Save của test không ăn khi picker đang chuyển tới “On My iPhone”. Lỗi đồng bộ của test, không phải code backup.
- Probe màu capture (ImageMagick): **11/16** (trước Phase 07: 6/16). Fail 02/16 (drag indicator/góc sheet), 13–15 (ô Thẻ cao hơn mock vì dòng “Thêm thẻ” và nhãn “Nội dung *” to hơn đẩy chip thẻ và nút Lưu xuống). Chưa đạt ≥98%.
- Chưa chạy: Share Safari/Photos, lưu link/ảnh qua UI, nghiệm thu trên iPhone thật.

### Sửa fidelity + backup test, retest simulator 2026-11-03 (lần cuối)

- `CaptureSheet.swift` theo spec Q16–Q47:
  - Header: handle tự vẽ 48×5 ở y 17 (ẩn handle hệ thống), nút X tròn 40 pt (vùng chạm 44) ở y 23, tiêu đề ở y 51.
  - Nhịp dọc của các section đo theo spec.
  - Nhãn “Nội dung” (bỏ dấu *, giữ hint VoiceOver “Bắt buộc”) cao cố định 182 pt.
  - Vùng nội dung dùng `PaperCard` cream có góc cong.
  - Bộ sưu tập là `PaperField` có viền, chevron sang phải.
  - Thẻ một hàng: chip bắt đầu ở x 78, ô nhập inline.
  - `safeAreaInset(spacing: 0)` bỏ dải trắng 8 pt phía trên thanh Lưu.
  - Khối nội dung chính có `minHeight` = chiều cao khung nhìn, nên “Tùy chọn khác” luôn nằm dưới khung đầu.
- Shared: `CircleIconButton(diameter:)`, `PaperField(spacing:minHeight:)`, `PaperFieldLabel`, `TagChip(verticalPadding:)`, token `Palette.handle`; mặc định giữ nguyên cho các màn khác.
- `LibraryUITests.testBackupLocalFilesPicker`: chờ Save bật rồi mới chạm. Nếu picker còn mở (chạm bị bỏ) thì chạm lại, tối đa 3 lần.
- Kết quả: unit **50/50**, UI **24/24** (PaperComponents, MockFidelity, Library, PhaseFourAcceptance). Probe màu capture **14/16**; hai probe còn fail (capture-14, 15: vị trí nút Lưu cố định) là sai khác đã duyệt (plan, quyết định 5).
- Còn chờ iPhone thật (Phase 08): Share Safari/Photos 2/2, checklist có trọng số ≥98%, dữ liệu sau cài đè.

### Nghiệm thu trên máy thật 2026-11-03

Ghi chung trong [báo cáo Phase 08](../../../docs/evidence/20261103-paper-phase8/summary.md):

- Đạt:
  - fixture capture 98.8%, trọng yếu 100%;
  - unit cho draft cũ và post-capture options;
  - UI lưu ghi chú, ghim sau khi lưu, đóng sheet giữ bản nháp;
  - Share Safari/Photos/hệ thống/app ngoài.
- Chưa có UI test lưu link/ảnh qua sheet (review L7).
- “Bàn phím không che nút lưu” chỉ được kiểm gián tiếp: thanh Lưu cố định nổi lên trên bàn phím.
