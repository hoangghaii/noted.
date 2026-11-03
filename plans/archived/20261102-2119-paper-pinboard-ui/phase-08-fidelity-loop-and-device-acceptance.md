# Phase 08 — Vòng bám sát và nghiệm thu iPhone

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 03, 05, 06, 07 · Trạng thái: hoàn tất (2026-11-03) · Review: [code-reviewer](reports/20261103-code-reviewer-phase07-08.md)

## Mục đích

Đo, chỉnh, đo lại tới khi đạt ngưỡng; xác nhận không hồi quy chức năng và dữ liệu.

## File

| Đường dẫn                                                     | Hành động   | Lý do                                                                          |
| ------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------ |
| `Noted./docs/evidence/20261102-paper-ui/` (đề xuất)           | tạo         | Ảnh thiết bị, side-by-side, overlay, diff, bảng điểm, log test                 |
| `Noted./docs/evidence/20261102-paper-ui/summary.md` (đề xuất) | tạo         | Báo cáo: đã kiểm chứng / chưa kiểm chứng / lỗi hạ tầng                         |
| `Noted./docs/design-guideline.md`                             | sửa         | Identity “Giấy & Bảng ghim”, token mới, component, quy tắc tông/cong, icon mới |
| `Noted./docs/design-preview/paper-concept.md`                 | sửa         | Ghi “đã triển khai” + link evidence                                            |
| `Noted./README.md`                                            | sửa nếu cần | Nhắc fixture `NOTED_MOCK_FIXTURE` chỉ dùng kiểm chứng                          |

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

- [x] Vòng bám sát Thư viện (98.7%, 7 vòng; người dùng cho phép vượt 5 vòng)
- [x] Vòng bám sát Bộ sưu tập (98.7%)
- [x] Vòng bám sát Lưu nhanh (98.8%)
- [x] Unit + UI + Share + backup (unit 57/57, UI 32/32)
- [x] Dữ liệu trước/sau cài đè: không áp dụng. Bundle ID đổi theo quyết định người dùng; app cũ đã được backup trước khi gỡ
- [x] Ảnh Home Screen (`testPhaseFiveHomeScreenIcon`)
- [x] Cập nhật guideline, concept, báo cáo evidence
- [x] Review code (`code-reviewer`): đã sửa M1–M3, L3; M4 và Low còn mở

## Nghiệm thu

- `summary.md` có bảng điểm: mỗi màn ≥ 98%, trọng yếu 100%, kèm side-by-side.
- Mọi test liệt kê đạt hoặc lỗi được ghi rõ là hạ tầng và chạy lại.
- Số mục cá nhân sau cài đè ≥ trước; không mất ảnh/attachment.

## Rủi ro / rollback

- Thiết bị mất kết nối/Automation Mode → ghi là lỗi hạ tầng, chạy lại; không tính đạt.
- Rollback: mọi thay đổi chỉ ở UI/asset/draft tương thích ngược → cài lại build trước; dữ liệu không đổi schema.

## Tiến độ 2026-11-03

Báo cáo: [evidence/20261103-paper-phase8](../../../docs/evidence/20261103-paper-phase8/summary.md).

- Máy thật: unit 57/57 (50 của plan này), UI 30/30, gồm Share Safari/Photos/hệ thống, backup export và icon Home Screen. `ExternalShareUITests` không chạy vì thiếu slot free profile.
- Fidelity có trọng số: Thư viện 82.3%, Bộ sưu tập 87.0%, Lưu nhanh 92.6%. Trọng yếu 100% cả ba. **Chưa đạt 98%.** Thư viện đã dùng hết 5 vòng.
- Spec được đo lại có bằng chứng (lề, font, filter, folder tab). Khung hình học giữ nguyên vì khớp mock.
- Dữ liệu: bundle ID đổi, nên không có phép cài đè; người dùng đã backup app cũ.
- Todo còn mở: các vòng cho Bộ sưu tập / Lưu nhanh; ảnh trước/sau dữ liệu; cuộn ~50 mục; chữ có dấu; guideline/concept; review code.

### Cập nhật 2026-11-03 (vòng 6–8, sau duyệt quyết định 6–8)

- Bộ sưu tập **98.7%**, Lưu nhanh **98.8%**: đạt ngưỡng.
- Thư viện **87.3%**: đã dùng 5 vòng; còn L07/L13/L16/L18/L19/L20/L23/L24/L37/L40 (chi tiết trong evidence).
- Tỉ lệ lật mép ~1/4.
- Máy thật lần cuối: unit 57/57, UI 30/30.

### Hoàn tất 2026-11-03

- Thư viện 98.7% sau vòng 6–7. Bộ sưu tập 98.7%. Lưu nhanh 98.8%.
- Máy thật: unit 57/57, UI 32/32, gồm `ExternalShareUITests` (đã sửa lỗi tearDown).
- Kiểm thủ công: người dùng xác nhận đạt.
