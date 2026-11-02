# Noted — UI “Giấy & Bảng ghim” theo mock v3

Ngày 2026-11-02. Trạng thái: **chưa triển khai**. Nguồn: [cuộc trao đổi](../../docs/chat-exports/20261102-noted-design-conversation.md), [mock UI v3](../../docs/design-preview/noted-paper-ui-mock-v3.png), [icon bảng ghim](../../docs/design-preview/icon-concepts/noted-pinboard-selected.png), [ghi chú concept](../../docs/design-preview/paper-concept.md).

## Mục tiêu

Đưa mock v3 vào SwiftUI trên iPhone 12 Pro với độ bám sát **≥ 98% theo bảng tiêu chí đo được** (Phase 01), 100% với tiêu chí trọng yếu: bố cục, thứ tự, màu, hình pill/tròn, pill cùng nhóm rộng bằng nhau, góc giấy cong thưa. Thay app icon bằng bảng ghim “Noted.”. Không làm mất dữ liệu, không đổi logic lưu/tìm/backup/Share.

## Phạm vi

- Trong phạm vi: token màu/nền giấy/texture, asset nét vẽ tay, app icon, tab bar, Thư viện, Bộ sưu tập, Lưu nhanh (Ghi chú/Link/Ảnh), Share Extension; Tìm kiếm, Chi tiết, Thùng rác, Dữ liệu & Backup dùng lại component để đồng bộ (mock không vẽ các màn này).
- Ngoài phạm vi: topic groups, đồng bộ, đổi schema SwiftData, đổi format backup/payload Share, icon dark/tinted, nghiệm thu VoiceOver/dark mode toàn diện (giữ token dark đủ đọc).

## Quyết định chính

- SwiftUI native; mock là raster AI nên “98%” đo bằng **checklist có số đo** (vị trí/kích thước ±2 pt, màu ΔE2000 ≤ 3 so với màu lấy mẫu, bán kính, cỡ/độ đậm chữ, nội dung, icon) trên **fixture tái tạo đúng dữ liệu mock**. SSIM chỉ là số tham khảo, không phải ngưỡng đạt.
- Màu lấy mẫu trực tiếp từ mock (bảng trong Phase 02). Tông card cream/honey/sage và góc cong chọn **ổn định theo `item.id`**, không random mỗi lần render; tối đa ~1/8 card cong.
- Pill cùng nhóm rộng bằng nhau: filter Thư viện (4 pill đầu lấp đầy hàng, phần còn lại cuộn ngang), 3 pill Ghi chú/Link/Ảnh độc lập. Nút có chữ dùng `Capsule()`, nút icon dùng `Circle()` 44 pt.
- Lưu nhanh thêm Tiêu đề, Bộ sưu tập, Thẻ như mock bằng cách gọi `LibraryStore.update` sau khi item xuất hiện (cùng cơ chế “Ghim sau khi lưu” hiện có) — không đổi `ShareGatePayload`.
- Asset nét vẽ tay: SVG vẽ tay, template rendering (đổi màu theo token). Texture giấy: một tile PNG xám sinh bằng ImageMagick với seed cố định, phủ `multiply` độ mờ thấp.
- Giữ mọi `accessibilityIdentifier`; UI tests đang dùng `segmentedControls` cho chế độ Lưu nhanh phải sửa có chủ đích sang `buttons["captureMode_note|link|photo"]`.

## Phụ thuộc và giả định

- iPhone 12 Pro `00008101-001A2519266B001E` đã pair; ký bằng `.env`/`Config/Local.xcconfig` hiện có; cài đè, không gỡ app.
- ImageMagick 7 (`/opt/homebrew/bin/magick`) có sẵn; Python không có PIL nên script so sánh dùng `magick`.
- Mock phone ≈ 425 px rộng ↔ 390 pt; hệ số ≈ 0,918 pt/px. Số đo trong phase là ước lượng; Phase 01 chốt.

## Phases

| Phase | Trạng thái | Kết quả |
|---|---|---|
| [01 — Đặc tả đo và bộ so sánh](phase-01-spec-and-fidelity-harness.md) | Chưa bắt đầu | Ảnh tham chiếu cắt từ mock, spec số đo, checklist, fixture dữ liệu mock, script so sánh |
| [02 — Token, texture, asset vẽ tay](phase-02-tokens-texture-assets.md) | Chưa bắt đầu | Palette mới, PaperGrain, SVG lightbulb/folder/kind, quy tắc tông & góc cong |
| [03 — App icon bảng ghim](phase-03-app-icon.md) | Chưa bắt đầu | AppIcon 1024 opaque, kiểm tra 60/120/180 px và Home Screen |
| [04 — Component chung & tab bar](phase-04-components-and-tab-bar.md) | Chưa bắt đầu | PaperCard, EqualWidthPills, CircleIconButton, PaperField, TagChip, tab bar |
| [05 — Thư viện & Tìm kiếm](phase-05-library-and-search.md) | Chưa bắt đầu | Header, hero, filter, lưới card theo hàng, menu card |
| [06 — Bộ sưu tập & Chi tiết](phase-06-collections-and-detail.md) | Chưa bắt đầu | Folder card có tab mật ong, icon theo bộ sưu tập |
| [07 — Lưu nhanh & Share Extension](phase-07-capture-and-share.md) | Chưa bắt đầu | Sheet như mock, Tiêu đề/Bộ sưu tập/Thẻ, Share đồng bộ |
| [08 — Vòng bám sát & nghiệm thu iPhone](phase-08-fidelity-loop-and-device-acceptance.md) | Chưa bắt đầu | Điểm checklist ≥ 98%, test xanh, dữ liệu còn nguyên |

Thứ tự: 01 → 02 → 04 → (05, 06, 07) → 08. Phase 03 chạy song song sau 01.

## Điều kiện hoàn tất

Báo cáo Phase 08 có: ảnh iPhone thật cạnh mock cho 3 màn, điểm checklist từng màn ≥ 98% và 100% tiêu chí trọng yếu, danh sách sai khác còn lại có lý do; unit 42/42 và UI suite cập nhật đạt; dữ liệu cá nhân còn đủ sau cài đè; icon thật trên Home Screen.

## Quyết định đã chốt (2026-11-02)

Người dùng đồng ý cả 4 đề xuất:

1. Ghim sau khi lưu, Dán nội dung, Xóa bản nháp, đếm ký tự: gom vào “Tùy chọn khác” thu gọn **dưới** trường Thẻ, ngoài khung nhìn đầu tiên ([Phase 07](phase-07-capture-and-share.md)).
2. Giữ sắp bộ sưu tập theo tên, không đổi schema; thứ tự khác mock là sai khác chấp nhận, không trừ điểm ([Phase 06](phase-06-collections-and-detail.md)).
3. Ngày trên card luôn dạng “12 thg 4, 2024”; bỏ “Hôm nay/Hôm qua” ([Phase 05](phase-05-library-and-search.md)).
4. Icon card theo loại nội dung (ghi chú/ảnh/link); bóng đèn chỉ ở hero. Icon bóng đèn trên card vàng của mock là sai khác chấp nhận.

## Câu hỏi còn mở

Không còn.
