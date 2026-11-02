# Phase 05 — Thư viện và Tìm kiếm

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 04 · Trạng thái: chưa bắt đầu · Review: chưa

## Khác biệt hiện tại ↔ mock (Thư viện)

| Phần | Hiện tại | Mock v3 |
|---|---|---|
| Nút “…” | nền surface + viền, icon brand | nền `chip`, không viền, icon tối |
| Hero | eyebrow “NOTED TRÊN IPHONE”, không minh hoạ | không eyebrow; tiêu đề + pill honey; bóng đèn vẽ tay bên phải; hạt giấy |
| Filter | 6 chip 96 pt, thứ tự Tất cả/Ghi chú/Ảnh/Link/Inbox/Đã ghim | 4 pill bằng nhau lấp hàng: Tất cả/Inbox/Ảnh/Link |
| Lưới | `LazyVGrid`, card cao tự do, min 156 | 2 cột, hai card mỗi hàng cao bằng nhau |
| Card | nhãn “GHI CHÚ” in hoa + icon, excerpt 1 dòng, tag, “ngày · bộ sưu tập” | icon vẽ tay trái, “…” phải; tiêu đề semibold; excerpt tới 5 dòng (giữ gạch đầu dòng); ngày “12 thg 4, 2024”; tông cream/honey/sage; 1 card cong |
| Card ảnh | thumb 72 pt trong padding | ảnh tràn mép trên ~120 pt, icon ảnh + “…” đè lên ảnh (màu sáng), chú thích + ngày dưới |
| Card link | host 1 dòng | tiêu đề, mô tả 3 dòng, `domain ↗`, ngày |

## File

| Đường dẫn | Hành động | Lý do |
|---|---|---|
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Library/LibraryView.swift` | sửa | Header, hero, filter, lưới theo hàng |
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Library/ItemCard.swift` | sửa | Bố cục card mới 3 biến thể, tông/cong, menu |
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Search/SearchView.swift` | sửa | Ô tìm `PaperField`, filter dùng `NotedPill`, kết quả dùng cùng `ItemCard`/hàng giấy |
| `/Users/hainguyen/LocalData/Noted./NotedUITests/PhaseFourAcceptanceUITests.swift`, `LibraryUITests.swift` | sửa nếu cần | Thứ tự filter đổi; `libraryFilters` vẫn là scroll view |

## Bước

1. Header: giữ `Menu` (Dữ liệu & Backup, Thùng rác), đổi nhãn thành `CircleIconButton`; id `libraryOptions`.
2. Hero: bỏ eyebrow; `HStack` [tiêu đề + pill] | `Image("SketchLightbulb")` tint heroText ~64 pt; nền hero + grain; id `captureAdd` giữ.
3. “Vừa lưu” + “N mục” (`.monospacedDigit`).
4. Filter: thứ tự `[.all, .inbox, .images, .links, .notes, .pinned]` trong `EqualWidthPillGroup(visibleCount: 4)` cuộn ngang; id mỗi pill `libraryFilter_<rawValue>`.
5. Lưới: `LazyVStack` các hàng; mỗi hàng `HStack(alignment: .top, spacing: 12)` 2 card, `.fixedSize(horizontal: false, vertical: true)` + card `maxHeight: .infinity` để cao bằng nhau; Dynamic Type accessibility → 1 cột. Giữ `limit`/“Xem thêm”.
6. `ItemCard`:
   - Ghi chú: `Sketch` icon theo loại 22 pt (đã chốt: không dùng bóng đèn trên card); tiêu đề 17 semibold 2 dòng; excerpt 14 pt secondary tới 5 dòng (hiển thị “•” cho dòng bắt đầu bằng `- `/`• `); ngày caption cuối.
   - Ảnh: ảnh `fill` tràn mép trên, clip theo bán kính card phía trên; icon + “…” overlay; tiêu đề 15 pt 1–2 dòng; ngày.
   - Link: icon link; tiêu đề; mô tả (body/preview) 3 dòng; `host` + `arrow.up.right.square`; ngày.
   - Ghim: giữ nhãn “Đã ghim” + `pin.fill` nhỏ cạnh ngày (không mất trạng thái).
   - Nút “…”: `Menu` (Ghim/Bỏ ghim → `store.togglePin`, Chuyển vào Thùng rác → `store.trash`) đặt bằng `.overlay(alignment: .topTrailing)` **ngoài** `NavigationLink` label để chạm không mở chi tiết; vùng chạm 44 pt; id `itemMenu_<UUID>`.
7. Ngày: `item.createdAt.formatted(.dateTime.day().month(.defaultDigits).year().locale(Locale(identifier: "vi_VN")))` → kiểm tra ra đúng “12 thg 4, 2024”; nếu không, format tay `"\(d) thg \(m), \(y)"` (đã chốt: luôn dùng dạng này, bỏ “Hôm nay/Hôm qua”).
8. Tìm kiếm: tiêu đề + phụ đề cùng kiểu header; ô tìm `PaperField` có kính lúp; filter loại/thời gian/bộ sưu tập dùng `NotedPill` (nhóm bằng nhau); kết quả dùng lưới như Thư viện. Giữ `searchQuery` và logic debounce.

## Todo

- [ ] Header + hero + bóng đèn
- [ ] Filter bằng nhau, thứ tự mới
- [ ] Lưới hàng cao bằng nhau
- [ ] ItemCard 3 biến thể + tông + cong + menu
- [ ] Định dạng ngày
- [ ] Tìm kiếm đồng bộ
- [ ] Sửa UI tests bị ảnh hưởng

## Nghiệm thu

- Fixture `library` trên iPhone: checklist Thư viện ≥ 98%, mục trọng yếu 100% (`compare.sh`).
- Chạm “…” trên card mở menu, không điều hướng; Ghim/Thùng rác hoạt động, có test UI.
- Phân trang 50 + “Xem thêm”, lọc, mở chi tiết vẫn đạt (test cũ).

## Rủi ro

- `Menu` lồng trong `NavigationLink` nuốt chạm → dùng overlay ngoài label như bước 6.
- Excerpt 5 dòng với ghi chú rất dài → `lineLimit(5)` và cắt `prefix(400)` trước khi render để tránh layout chậm.
