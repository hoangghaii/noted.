# Phase 05 — Thư viện và Tìm kiếm

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 04 · Trạng thái: đã triển khai trên simulator; kiểm thử UI còn bất ổn, chờ nghiệm thu fidelity · Review: đã review tĩnh, không có lỗi chặn

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

- [x] Header + hero + bóng đèn
- [x] Filter bằng nhau, thứ tự mới
- [x] Lưới hàng cao bằng nhau
- [x] ItemCard 3 biến thể + tông + cong + menu
- [x] Định dạng ngày
- [x] Tìm kiếm đồng bộ
- [x] Sửa UI tests bị ảnh hưởng

## Nghiệm thu

- Fixture `library` trên iPhone: checklist Thư viện ≥ 98%, mục trọng yếu 100% (`compare.sh`).
- Chạm “…” trên card mở menu, không điều hướng; Ghim/Thùng rác hoạt động, có test UI.
- Phân trang 50 + “Xem thêm”, lọc, mở chi tiết vẫn đạt (test cũ).

## Rủi ro

- `Menu` lồng trong `NavigationLink` nuốt chạm → dùng overlay ngoài label như bước 6.
- Excerpt 5 dòng với ghi chú rất dài → `lineLimit(5)` và cắt `prefix(400)` trước khi render để tránh layout chậm.

## Kết quả triển khai — 2026-11-02

- Thực hiện trên iPhone 12 Pro simulator / iOS 18.6 theo yêu cầu phiên này. Giữ dữ liệu cá nhân; test dùng fixture cô lập.
- Build simulator đạt; unit suite 45/45 đạt. Các kịch bản UI đều có lượt đạt qua nhiều lần chạy: fixture Thư viện, bốn test component cũ, menu/ngày/chiều cao hàng mới, filter Tìm kiếm và mở chi tiết mới, phân trang/lọc/ghim sau relaunch cũ.
- Chưa có một lượt UI suite xanh hoàn toàn: runner bị `Test crashed with signal kill` ngẫu nhiên, kể cả khi tắt parallel và timeout. Không coi các lần runner bị kill là test đạt. Chi tiết lần chạy và ảnh: [báo cáo](../../docs/evidence/20261102-paper-phase5/README.md).
- Review tĩnh độc lập không phát hiện lỗi chặn; `git diff --check` đạt.
- `compare.sh` đã chạy trên ảnh simulator; 11/16 probe màu đạt. Đây không phải điểm checklist. Còn lệch hình học/màu hero so với mock; **chưa đạt/chưa xác nhận ≥98% và chưa nghiệm thu iPhone thật**. Giữ nghiệm thu fidelity mở cho vòng Phase 08.

## Retest 2026-11-03

- Simulator riêng `Claude Test iPhone 12 Pro` (iOS 18.6): unit 46/46, UI 23/23 (PaperComponents, MockFidelity, Library, PhaseFourAcceptance), 0 runner restart. Lỗi “signal kill” trước đó do hai phiên chạy test cùng lúc trên một simulator, không phải lỗi test.
- Chi tiết sửa và số đo: [retest evidence](../../docs/evidence/20261103-paper-phase5-6-retest/summary.md).
- Bám mock: hero 111 pt một dòng + bóng đèn overlay, nhịp dọc 12,5/14 pt, card chữ 15,5/12,5 pt, icon 24 pt, ↗ sau tên miền, curl 30 pt, texture soft-light, hero `#284739`. Probe màu Thư viện 11/16 → **16/16**. Checklist ≥98% vẫn là cổng Phase 08; còn lệch: tiêu đề link xuống 2 dòng, ngắt dòng trích đoạn.
