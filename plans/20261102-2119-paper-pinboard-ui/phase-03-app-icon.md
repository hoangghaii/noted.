# Phase 03 — App icon bảng ghim “Noted.”

Ngày 2026-11-02 · Ưu tiên: trung bình · Phụ thuộc: Phase 01 (chỉ cần quy trình chụp) · Trạng thái: chưa bắt đầu · Review: chưa

## Insight

- Ảnh chọn `docs/design-preview/icon-concepts/noted-pinboard-selected.png` 1254×1254, có **viền kem và góc bo sẵn** quanh khung xanh. iOS tự áp mask squircle → asset phải **vuông, tràn mép, không alpha**, nếu không sẽ thấy viền kem.
- `Noted/Assets.xcassets/AppIcon.appiconset` chỉ có một `AppIcon.png` 1024 universal (Folded N) → thay file, giữ `Contents.json`.

## File

| Đường dẫn | Hành động | Lý do |
|---|---|---|
| `/Users/hainguyen/LocalData/Noted./Noted/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | thay | Icon bảng ghim 1024 RGB opaque |
| `/Users/hainguyen/LocalData/Noted./docs/design-preview/icon-concepts/noted-folded-n-backup.png` (đề xuất) | tạo | Lưu icon cũ để rollback |
| `/Users/hainguyen/LocalData/Noted./scripts/ui-fidelity/make-icon.sh` (đề xuất) | tạo | Tái tạo icon từ ảnh gốc |

## Bước

1. Sao lưu `AppIcon.png` hiện tại.
2. Xác định biên ngoài khung xanh (≈ x/y 75–1180): `magick src -fuzz 8% -trim` trên ảnh đã thay nền kem bằng trong suốt, hoặc đo tay.
3. Cắt vuông theo biên khung, tô 4 góc kem còn sót bằng màu khung xanh (`#2A4A3A` – lấy mẫu), `-alpha off`, resize 1024 Lanczos, sRGB.
4. Xem mô phỏng mask iOS (squircle ~22,4% bán kính) ở 1024/180/120/60 px; chữ “Noted.” phải đọc được ở 60 px. Nếu khung xanh bị mask ăn quá dày/mỏng, chỉnh lề cắt ±2%.
5. Build, cài đè, chụp Home Screen.

## Todo

- [ ] Backup icon cũ
- [ ] Script cắt/tô góc/resize
- [ ] Kiểm tra `magick identify -format '%[channels] %wx%h'` → `srgb 1024x1024`
- [ ] Preview mask 4 kích thước
- [ ] Ảnh Home Screen iPhone thật

## Nghiệm thu

- Asset 1024×1024, không alpha; Xcode không cảnh báo icon.
- Home Screen: không thấy viền kem, “Noted.” đọc được; ảnh lưu vào evidence Phase 08.

## Rủi ro / rollback

- Ảnh gốc AI có hạt mịn có thể nhòe ở 60 px → nếu chữ không đọc được, tăng nhẹ tương phản/sharpen (`-unsharp 0x1`) chỉ trong bản 1024.
- Rollback: chép lại file backup.
