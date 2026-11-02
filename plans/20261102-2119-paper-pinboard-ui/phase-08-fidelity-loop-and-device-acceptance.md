# Phase 08 — Vòng bám sát và nghiệm thu iPhone

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 03, 05, 06, 07 · Trạng thái: chưa bắt đầu · Review: chưa

## Mục đích

Đo, chỉnh, đo lại tới khi đạt ngưỡng; xác nhận không hồi quy chức năng và dữ liệu.

## File

| Đường dẫn | Hành động | Lý do |
|---|---|---|
| `/Users/hainguyen/LocalData/Noted./docs/evidence/20261102-paper-ui/` (đề xuất) | tạo | Ảnh thiết bị, side-by-side, overlay, diff, bảng điểm, log test |
| `/Users/hainguyen/LocalData/Noted./docs/evidence/20261102-paper-ui/summary.md` (đề xuất) | tạo | Báo cáo: đã kiểm chứng / chưa kiểm chứng / lỗi hạ tầng |
| `/Users/hainguyen/LocalData/Noted./docs/design-guideline.md` | sửa | Identity “Giấy & Bảng ghim”, token mới, component, quy tắc tông/cong, icon mới |
| `/Users/hainguyen/LocalData/Noted./docs/design-preview/paper-concept.md` | sửa | Ghi “đã triển khai” + link evidence |
| `/Users/hainguyen/LocalData/Noted./README.md` | sửa nếu cần | Nhắc fixture `NOTED_MOCK_FIXTURE` chỉ dùng kiểm chứng |

## Vòng lặp bám sát (mỗi màn: library, collections, capture)

1. Build + cài đè iPhone 12 Pro (scheme Noted, không gỡ app).
2. Chạy `MockFidelityUITests` → xuất ảnh từ `.xcresult` (`xcrun xcresulttool export attachments`).
3. `scripts/ui-fidelity/compare.sh` → SSIM (tham khảo), bảng probe màu, overlay.
4. Chấm checklist trong `paper-ui-spec.md` (probe tự động + số đo trên overlay). Ghi điểm theo vòng.
5. Sửa sai khác lớn nhất theo trọng số → lặp. Dừng khi ≥ 98% và 100% trọng yếu; tối đa 5 vòng mỗi màn, nếu chưa đạt thì báo cáo mục còn lệch và lý do (vd. giới hạn native).

Sai khác **chấp nhận được** (không trừ điểm, liệt kê rõ): status bar/home indicator, khung máy, nhiễu/méo do ảnh AI, ảnh cà phê độ phân giải thấp, khác biệt render chữ SF thật so với chữ trong ảnh AI, các quyết định đã chốt trong plan.md: thứ tự bộ sưu tập theo tên, icon card theo loại thay vì bóng đèn, “Tùy chọn khác” nằm ngoài khung nhìn đầu.

## Kiểm thử hồi quy

- Unit: scheme Noted trên iPhone, kỳ vọng 42/42 + test mới (tông/cong, ánh xạ thư mục, draft, post-capture).
- UI suite (scheme Noted-DeviceGate): 9 ca hiện có (đã sửa locator) + `MockFidelityUITests` + pill bằng nhau + menu card.
- Share Safari/Photos 2/2; backup export/import 1/1 (như báo cáo trước).
- Dữ liệu: đếm mục thư viện cá nhân trước và sau cài đè; ảnh before/after.
- Icon: ảnh Home Screen.
- Thủ công: cuộn thư viện ~50 mục mượt; chữ tiếng Việt `Ă Â Đ Ê Ô Ơ Ư` không bị cắt trên card/pill.

## Todo

- [ ] Vòng bám sát Thư viện (điểm từng vòng)
- [ ] Vòng bám sát Bộ sưu tập
- [ ] Vòng bám sát Lưu nhanh
- [ ] Unit + UI + Share + backup
- [ ] Dữ liệu trước/sau cài đè
- [ ] Ảnh Home Screen
- [ ] Cập nhật guideline, concept, báo cáo evidence
- [ ] Review code (`code-reviewer`)

## Nghiệm thu

- `summary.md` có bảng điểm: mỗi màn ≥ 98%, trọng yếu 100%, kèm side-by-side.
- Mọi test liệt kê đạt hoặc lỗi được ghi rõ là hạ tầng và chạy lại.
- Số mục cá nhân sau cài đè ≥ trước; không mất ảnh/attachment.

## Rủi ro / rollback

- Thiết bị mất kết nối/Automation Mode → ghi là lỗi hạ tầng, chạy lại; không tính đạt.
- Rollback: mọi thay đổi chỉ ở UI/asset/draft tương thích ngược → cài lại build trước; dữ liệu không đổi schema.
