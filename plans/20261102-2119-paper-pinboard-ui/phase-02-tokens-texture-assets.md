# Phase 02 — Token, texture giấy, asset vẽ tay

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 01 · Trạng thái: chưa bắt đầu · Review: chưa

## Insight

- `Shared/NotedDesign.swift` đã có palette adaptive dùng chung app + Share Extension; chỉ cần bổ sung/điều chỉnh, không đổi kiến trúc.
- Màu lấy mẫu từ mock v3 (trung bình 5×5 px):

| Vai trò | Mock | Token hiện tại | Đề xuất light |
|---|---|---|---|
| paper (nền màn) | `#FAF6ED` | `#F6F2E9` | `#FAF6ED` |
| sheet background | `#F9F5EC` | — | dùng `paper` |
| hero | `#29453A` / `#244235` | `#253F34` | `#274337` + texture |
| brand (filter/pill chọn) | `#244836` / `#1F402F` | `#285448` | `#224431` |
| accent honey (nút) | `#EEBC6A` / `#ECA748` | `#E6B45B` | `#EDB55E` (đo lại nút lưu) |
| filter/pill không chọn, nút tròn | `#EEE8DC` / `#EDE6D9` / `#EDE7DB` | — | mới `chip` `#EDE7DB` |
| card cream | `#FBF4E6` | surface `#FFFDF7` | mới `toneCream` `#FBF4E6` |
| card honey | `#F2BF65` | — | mới `toneHoney` `#F2BF65` |
| card/folder sage, pill tạo, chip thẻ | `#DEE3D6` / `#E3E9DD` / `#DCE2D5` | brandSoft `#E5EDE5` | mới `toneSage` `#DFE5D8` |
| tab folder | `#EAB65E` | — | dùng `toneHoney` hoặc `#EAB65E` |
| ô nhập | `#F8F4EB` | surface | mới `field` `#F8F4EB` + viền `border` |
| tab bar | `#F8F3EB` | surface | mới `bar` `#F8F3EB` |
| chữ chính | gần đen ánh lục | `#27352C` | `#1E2A23` |
| chữ phụ | ~`#6E6A63` | `#646D61` | `#6B6A62` |

Giá trị cuối chốt bằng `color-probes.json` sau khi phủ texture (texture làm tối ~1–2%). Thêm giá trị dark tương ứng (giữ nguyên tắc tương phản ≥ 4,5:1 đã có trong guideline).

- Chữ trên card honey: `accentText` `#302719` (đã đạt 7,7:1 trên accent).

## File

| Đường dẫn | Hành động | Lý do |
|---|---|---|
| `/Users/hainguyen/LocalData/Noted./Shared/NotedDesign.swift` | sửa | Palette mới, `Radius` (card 12, field 10, folderTab 6), `Tone` enum + quy tắc chọn tông/cong |
| `/Users/hainguyen/LocalData/Noted./Noted/Assets.xcassets/PaperGrain.imageset/` (đề xuất) | tạo | Tile 256×256 xám, seed cố định |
| `/Users/hainguyen/LocalData/Noted./NotedShare/` asset catalog (đề xuất, nếu extension chưa có) | tạo/sửa | Share Extension cần PaperGrain riêng hoặc target membership chung |
| `/Users/hainguyen/LocalData/Noted./Noted/Assets.xcassets/Sketch*.imageset/*.svg` (đề xuất) | tạo | `SketchLightbulb`, `SketchFolderLeaf`, `SketchFolderBook`, `SketchFolderHeart`, `SketchFolderMountain`, `SketchFolderPlain`, `SketchNote`, `SketchPhoto`, `SketchLink`; “Preserve Vector Data”, render as Template |
| `/Users/hainguyen/LocalData/Noted./docs/design-preview/assets/sketch/*.svg` (đề xuất) | tạo | Nguồn SVG + ảnh preview |
| `/Users/hainguyen/LocalData/Noted./scripts/ui-fidelity/make-grain.sh` (đề xuất) | tạo | Tái tạo texture có seed |

## Quy tắc tông & góc cong (ổn định)

```swift
enum PaperTone { case cream, honey, sage }
static func tone(for item: Item) -> PaperTone {
    if item.kind == "link" { return .sage }
    if item.kind == "image" { return .cream }
    return stableHash(item.id) % 3 == 0 ? .honey : .cream   // ~1/3 ghi chú honey
}
static func curls(_ item: Item) -> Bool {
    item.kind != "image" && stableHash(item.id) % 8 == 3     // ~1/8, không trùng điều kiện honey
}
```
`stableHash` = FNV-1a trên `uuidString` (không dùng `hashValue` vì đổi mỗi lần chạy). Fixture Phase 01 chọn UUID khớp kết quả mock. Folder: tông theo vị trí chẵn/lẻ (cream, sage, cream, sage).

## Bước

1. Cập nhật palette + dark values; tính lại bảng tương phản, ghi vào `docs/design-guideline.md`.
2. Texture: `magick -size 256x256 xc:gray80 -seed 20261102 +noise Gaussian -colorspace Gray -blur 0x0.5 -level 40%,60% PaperGrain.png` (tinh chỉnh); tile liền mạch (kiểm tra bằng ghép 2×2). Dùng `Image("PaperGrain").resizable(resizingMode: .tile).blendMode(.multiply).opacity(0.05…0.08)`; hero 0.12–0.18 dùng `.overlay` sáng (`.screen`) để ra hạt kem như mock.
3. Vẽ SVG tay: nét 2–2,5 pt, đầu tròn, đường hơi run (lệch 0,5–1 pt), một màu. Bóng đèn có tia sáng; thư mục có biểu tượng bên trong (lá, sách, tim, núi). So hình với mock ở cùng kích thước.
4. Gom thành `NotedDesign.Sketch` (tên asset) + `PaperBackground` modifier.

## Todo

- [ ] Palette light/dark mới + bảng tương phản
- [ ] PaperGrain tile + script
- [ ] 9 SVG vẽ tay + preview
- [ ] `PaperTone`, `stableHash`, `curls` + unit test phân bố (1000 UUID: honey 28–38%, curl 9–16%)

## Nghiệm thu

- Unit test phân bố đạt; cùng UUID cho cùng kết quả qua nhiều lần chạy.
- Probe màu nền/hero/tông card trên ảnh thiết bị (Phase 08) ΔE ≤ 3.
- Build app + Share Extension thành công; Instruments/quan sát cuộn 60 fps không giảm rõ khi có texture (ghi nhận thủ công trên iPhone).

## Rủi ro

- Texture làm giảm tương phản chữ → giữ opacity thấp, đo lại tương phản trên ảnh thật.
- SVG trong asset catalog cần iOS 13+ và “Preserve Vector Data”; kiểm tra template tint hoạt động trong extension.
