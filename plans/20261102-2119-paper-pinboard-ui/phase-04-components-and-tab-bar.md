# Phase 04 — Component chung và tab bar

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 02 · Trạng thái: chưa bắt đầu · Review: chưa

## Insight

- `Noted/UI/NotedComponents.swift` đã có `NotedButtonStyle` (Capsule), `NotedFilterChip` (width cố định 96 → không lấp đầy hàng như mock), `NotedStatusBanner`, `operationLoading`.
- `RootView.destinationBar` là tab bar tự dựng: nền `surface` + hairline, icon `square.grid.2x2`/`magnifyingglass`/`folder`. Mock: Thư viện = tài liệu đầy, Tìm kiếm = kính lúp, Bộ sưu tập = chồng lớp đầy; chọn màu forest, không chọn xám; nền `bar`, không thấy hairline rõ.
- Share Extension không link `Noted/UI` → component dùng ở cả hai phải nằm trong `Shared/` (hoặc thêm target membership). Đề xuất `Shared/NotedPaperUI.swift`.

## Component

| Component | Đặc tả (chốt số ở Phase 01) | Dùng ở |
|---|---|---|
| `NotedButtonStyle` | thêm role `.soft` (nền `toneSage`, chữ brand, regular); `.primary` honey cao 50 khi `prominent` | Hero, tạo bộ sưu tập, nút lưu, Share |
| `EqualWidthPillGroup` | `HStack` các pill `frame(maxWidth: .infinity)`; tham số `visibleCount` để nhóm dài cuộn ngang mà 4 pill đầu vẫn = (rộng − 3·gap)/4 (đo bằng `GeometryReader`/`containerRelativeFrame`) | Filter Thư viện, chế độ Lưu nhanh, Share (nếu có) |
| `NotedPill` | Capsule, cao visual 36 (filter) / 44 (chế độ), vùng chạm ≥ 44; chọn: brand + onBrand; không chọn: `chip` + primaryText; icon tuỳ chọn | như trên |
| `CircleIconButton` | 44 pt, nền `chip`, icon 17 pt semibold primaryText, không viền | “…” header, X đóng sheet |
| `PaperCard` | nền theo `PaperTone`, bán kính card, grain overlay, bóng rất nhẹ (y 1, blur 2, 6%), không viền hoặc viền 0,5 pt tông tối hơn; `curl: Bool` | Card Thư viện/Tìm kiếm, folder |
| `PaperCurl` | overlay góc dưới phải ~22 pt: tam giác gấp sáng + gradient + che góc bằng màu nền, như card honey mock | Card được chọn bởi `curls()` |
| `PaperField` | nhãn phía trên (15 pt secondary), ô nền `field`, viền `border` 1 pt, bán kính 10, cao ≥ 44, padding 14 | Lưu nhanh, Share, editor |
| `TagChip` | Capsule `toneSage`, chữ 15 pt primaryText, padding 12×6 | Thẻ Lưu nhanh, chi tiết |
| `PaperBackground` | `paper` + grain toàn màn | Mọi màn |

## File

| Đường dẫn | Hành động | Lý do |
|---|---|---|
| `/Users/hainguyen/LocalData/Noted./Shared/NotedPaperUI.swift` (đề xuất) | tạo | Component dùng chung app + extension |
| `/Users/hainguyen/LocalData/Noted./Noted/UI/NotedComponents.swift` | sửa | Chuyển/thay `NotedFilterChip` bằng `NotedPill`; thêm role `.soft`; giữ API cũ đến khi màn cuối chuyển xong rồi xoá phần thừa |
| `/Users/hainguyen/LocalData/Noted./Noted/App/RootView.swift` | sửa | Tab bar: symbol `doc.text(.fill)`, `magnifyingglass`, `square.stack.3d.up(.fill)`; icon 24, nhãn 12; nền `bar`; giữ id `libraryTab/searchTab/collectionsTab` |
| `/Users/hainguyen/LocalData/Noted./Noted.xcodeproj/project.pbxproj` | sửa | Thêm file mới vào target Noted + NotedShare |

## Bước

1. Tạo `NotedPaperUI.swift` với các component trên; preview SwiftUI có cả 3 tông, curl, pill chọn/không chọn.
2. `EqualWidthPillGroup`: kiểm tra với nhãn dài nhất “Đã ghim”, “Ghi chú” và Dynamic Type lớn (nhãn co `minimumScaleFactor(0.85)`, không cắt dấu tiếng Việt).
3. Đổi tab bar; so sánh với probe tab bar của Phase 01.
4. Cập nhật pbxproj (thêm file vào cả hai target).

## Todo

- [ ] `NotedPaperUI.swift` + Preview
- [ ] Pill bằng nhau có test layout (UI test đọc `frame.width` các pill `libraryFilter_*`, chênh ≤ 1 pt)
- [ ] Tab bar mới
- [ ] Build app + extension

## Nghiệm thu

- UI test: chiều rộng 4 pill filter đầu bằng nhau (±1 pt) và tổng + gap = chiều rộng nội dung (±1 pt); 3 pill chế độ bằng nhau.
- Mọi nút có chữ là Capsule, nút icon là Circle 44 pt (review code + ảnh).
- `accessibilityIdentifier` cũ còn nguyên.

## Rủi ro

- `containerRelativeFrame` cần iOS 17+ — kiểm tra deployment target; nếu thấp hơn dùng `GeometryReader`.
- Bóng + texture trên nhiều card trong lưới → kiểm tra cuộn mượt; nếu giật, `drawingGroup()` cho lớp texture.
