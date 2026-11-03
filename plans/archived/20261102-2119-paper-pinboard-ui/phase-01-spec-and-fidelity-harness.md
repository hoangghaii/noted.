# Phase 01 — Đặc tả đo và bộ so sánh bám sát

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: không · Trạng thái: hoàn tất · Review: đã rà soát, sửa các lỗi checklist

## Mục đích

Biến mock raster thành đặc tả đo được, để “98–100%” là con số kiểm chứng được, không phải cảm nhận. Plan trước ([20261102-1004](../20261102-1004-noted-ui-icon/plan.md)) dừng ở “chưa đo tương đồng” vì không có fixture và thước đo; phase này lấp khoảng trống đó.

## Insight

- Mock 1536×1024: phone Thư viện x≈72–497, Bộ sưu tập x≈560–975, Lưu nhanh x≈1040–1465 (đo lại chính xác). Màn mock tỉ lệ ≈ 0,49; iPhone 12 Pro 390×844 pt (0,462) → so khớp theo **chiều rộng**, căn từ đỉnh vùng nội dung (dưới status bar), bỏ status bar và home indicator.
- Mock có nội dung cụ thể (tiêu đề, ngày, số mục, ảnh cà phê) → cần fixture dựng đúng dữ liệu đó trong kho DEBUG riêng, theo mẫu `PhaseFourFixtures` (store tách khỏi thư viện cá nhân).
- Dữ liệu mock không nhất quán: Thư viện “12 mục” nhưng các bộ sưu tập cộng 69 mục → fixture tách 3 biến thể theo màn.
- Không có PIL; dùng `magick` (IM7 có `compare -metric SSIM`, lấy màu bằng `%[hex:p{0,0}]`).

## File

| Đường dẫn | Hành động | Lý do |
| --- | --- | --- |
| `Noted./docs/design-preview/reference/v3-library.png` (đề xuất) | tạo | Ảnh cắt màn Thư viện, scale về 1170 px rộng |
| `.../reference/v3-collections.png`, `.../reference/v3-capture.png` (đề xuất) | tạo | Tương tự |
| `Noted./docs/design-preview/paper-ui-spec.md` (đề xuất) | tạo | Spec số đo từng phần tử + checklist có trọng số |
| `Noted./docs/design-preview/reference/color-probes.json` (đề xuất) | tạo | Điểm lấy màu (toạ độ pt) + hex kỳ vọng + dung sai ΔE |
| `Noted./scripts/ui-fidelity/compare.sh` (đề xuất) | tạo | Cắt/scale ảnh thiết bị, side-by-side, overlay 50%, diff, SSIM, kiểm màu theo probes |
| `Noted./Noted/App/MockFixtures.swift` (đề xuất) | tạo | `#if DEBUG`; env `NOTED_MOCK_FIXTURE=library | collections | capture`, store riêng trong Application Support |
| `Noted./Noted/App/NotedApp.swift` | sửa | Mở store fixture khi có env, như `PhaseFourFixtures.openIfRequested()` |
| `Noted./NotedTests/Fixtures/mock-coffee.jpg` hoặc bundle DEBUG (đề xuất) | tạo | Ảnh cà phê cắt từ mock cho card ảnh (chỉ dùng kiểm chứng) |
| `Noted./NotedUITests/MockFidelityUITests.swift` (đề xuất) | tạo | Mở từng fixture, chờ ổn định, chụp màn → attachment |

## Bước

1. Đo biên màn hình 3 phone trong mock (pixel đầu/cuối của nền màn), ghi vào spec. Cắt bằng `magick mock -crop WxH+X+Y -resize 1170x` → `reference/`.
2. Đo mọi phần tử trên ảnh tham chiếu (đổi px → pt theo chiều rộng): lề, khoảng cách, chiều cao/rộng, bán kính, cỡ chữ (chiều cao chữ hoa), màu. Ghi bảng trong `paper-ui-spec.md`. Giá trị ước lượng ban đầu (chốt lại khi đo):
   - Lề ngang 16 pt; khoảng cách cột/hàng card 12–13 pt.
   - Header: tiêu đề largeTitle bold ~34 pt; phụ đề ~17 pt secondary; nút “…” tròn 44 pt nền `#EDE7DB`, không viền.
   - Hero: cao ~110 pt, bán kính ~16, nền `#29453A` + texture; tiêu đề ~19 pt trắng; pill “＋ Lưu nhanh” honey cao 40–44 pt; bóng đèn vẽ tay ~64 pt bên phải.
   - Filter: 4 pill rộng bằng nhau lấp đầy hàng, cao visual ~36 pt (vùng chạm 44 pt).
   - Card: ~173×186 pt, bán kính ~10–12, hàng cùng chiều cao; card ảnh có ảnh tràn mép trên ~120 pt.
   - Tab bar: icon ~24 pt + nhãn ~12 pt; nền `#F8F3EB`.
   - Bộ sưu tập: pill tạo cao ~46 pt nền sage; folder card cao ~96 pt, tab mật ong ~64×14 pt nhô trên mép trái, icon thư mục vẽ tay ~60 pt.
   - Lưu nhanh: tiêu đề ~28 pt bold; nút X tròn 44 pt; 3 pill chế độ cao ~44 pt có icon + nhãn; ô nhập cao ~44 pt bán kính ~10; vùng Nội dung cao ~180 pt; nút lưu cao ~50 pt full width.
3. Viết checklist có trọng số, mỗi màn 40–60 mục, gắn nhãn **[trọng yếu]** cho: thứ tự/cấu trúc phần tử, màu nền chính, hình capsule/circle, pill cùng nhóm bằng nhau, card cong thưa, nội dung chữ. Điểm = tổng trọng số đạt / tổng trọng số.
4. `color-probes.json`: ≥ 15 điểm mỗi màn (nền, hero, filter chọn/không chọn, 3 tông card, tab bar, pill tạo, tab folder, 2 tông folder, nền sheet, pill chế độ, ô nhập, nút lưu, chip thẻ, nút X). Lấy màu trung bình vùng 5×5 để tránh nhiễu texture.
5. `MockFixtures.swift`: seed đúng dữ liệu mock với UUID cố định chọn sẵn để quy tắc tông/cong (Phase 02) ra đúng: “Một góc yên tĩnh” cream, “Ý tưởng cuối tuần” honey + cong, “Buổi sáng ở Đà Lạt” ảnh, “Sống chậm một chút” link sage `vietcetera.com`; tổng 12 mục; ngày 12/10/8/5 thg 4 2024. Biến thể collections: Cảm hứng 24, Đọc sau 18, Góc riêng 12, Chuyến đi 15. Biến thể capture: bản nháp “Ý tưởng cuối tuần”, 3 dòng gạch đầu dòng, bộ sưu tập Góc riêng, thẻ “cảm hứng”, mở sẵn sheet.
6. `compare.sh <device.png> <reference.png> <probes.json> <out-dir>`: crop status bar (47 pt × 3), scale về 1170 px, xuất `side-by-side.png`, `overlay.png`, `diff.png`, in SSIM, in bảng probe đạt/không đạt (ΔE tính bằng `magick -metric DE2000`… nếu IM không có thì so ΔE76 trong Lab, ghi rõ).
7. `MockFidelityUITests`: 3 test, mỗi test đặt env fixture, chụp `XCUIScreen.main.screenshot()` sau khi chờ ổn định 1 s, lưu attachment `keepAlways`.

## Todo

- [x] Đo biên 3 phone, cắt ảnh tham chiếu
- [x] Viết `paper-ui-spec.md` với số đo pt
- [x] Checklist có trọng số + nhãn trọng yếu
- [x] `color-probes.json`
- [x] `MockFixtures.swift` 3 biến thể, store tách biệt
- [x] `compare.sh` chạy thử với ảnh cũ `docs/evidence/20261102-iphone12pro/01-library.png`
- [x] `MockFidelityUITests` chụp được 3 màn trên iPhone

## Nghiệm thu

- `scripts/ui-fidelity/compare.sh docs/evidence/20261102-iphone12pro/01-library.png docs/design-preview/reference/v3-library.png docs/design-preview/reference/color-probes.json /tmp/...` tạo đủ 3 ảnh + bảng probe (điểm thấp là mong đợi — đây là baseline UI cũ).
- Chạy fixture không ghi vào thư viện cá nhân: số mục thư viện cá nhân trước/sau như nhau.
- Spec có số cho mọi phần tử nhìn thấy trong 3 màn mock.

## Rủi ro

- Mock AI có méo nhẹ (chữ, khoảng cách không đều) → khi số đo mâu thuẫn, chọn giá trị theo lưới 4 pt gần nhất và ghi trong spec.
- Ảnh cà phê cắt từ mock độ phân giải thấp → chỉ dùng trong fixture DEBUG, không ship Release.

## Kết quả thực hiện 2026-11-02

- Spec: `docs/design-preview/paper-ui-spec.md`, 139 tiêu chí (47 library / 45 collections / 47 capture), trọng số và tiêu chí trọng yếu; ảnh reference rộng1170 và 49 probe màu tổng cộng.
- Harness: `scripts/ui-fidelity/compare.sh`, CIEDE2000 Python stdlib; 2 test đạt (gồm vector chuẩn, crop, lỗi ảnh ngắn, self compare). Baseline ảnh cũ tạo đủ artifacts `/private/tmp/noted-fidelity-baseline`, màu 1/16. Self compare 16/16,17/17,16/16; ΔE0. SSIM của IM hiện tại trả distortion0 khi giống hệt, chỉ tham khảo.
- Debug/Release unsigned iPhoneOS build và build-for-testing đạt; coffee chỉ có trong Debug.
- iPhone thật: 4/4 `MockFidelityUITests` đạt, gồm ba ảnh và test số mục cá nhân trước/sau ba fixture bằng nhau. `.xcresult`: `/private/tmp/noted-paper-phase1-device-retry.xcresult`. Ảnh + summary: `docs/evidence/20261102-paper-phase1/`.
- Review độc lập: sửa bảng Markdown, ID trùng, trọng yếu capsule/nội dung, phép tính chiều rộng pill. Không còn blocker được tìm thấy.

### Giới hạn và chuyển tiếp

- Đây là bộ đo/baseline, chưa đạt UI98%; không triển khai Phase02 trở đi.
- Capture fixture seed body hiện hữu; title/collection/tags có constants DEBUG chờ Phase07 hiển thị. ID cố định1/2/3/4 dành cho cream/honey+curl/photo/sage, Phase02 phải xác nhận mapping.
- Số mục cá nhân không đổi không chứng minh toàn vẹn byte/draft. Không sao chép nội dung cá nhân; auto-review từ chối xuất container vì nhạy cảm, đã dùng kiểm tra UI ít xâm lấn.
- Lần chạy đầu không cài được runner vì giới hạn3 app free profile. Người dùng đã chọn gỡ Noted cũ `dev.nhhai7.Noted` và dữ liệu của nó; đã gỡ rồi chạy lại thành công. App hiện tại `dev.nguyenhoanghai861.Noted` được giữ.
