# Phase 06 — Bộ sưu tập và Chi tiết

Ngày 2026-11-02 · Ưu tiên: cao · Phụ thuộc: Phase 04 · Trạng thái: đã triển khai simulator, unit 46/46 + UI 4/4 đạt; fidelity còn mở · Review: không có blocker (review tĩnh)

## Khác biệt hiện tại ↔ mock (Bộ sưu tập)

| Phần | Hiện tại | Mock v3 |
|---|---|---|
| Phụ đề | “Sắp xếp theo cách của bạn.” | “Mỗi ý tưởng, một góc riêng.” |
| Nút “…” | không có | `CircleIconButton` bên phải tiêu đề |
| Nút tạo | `.secondary` brandSoft | pill sage full width, “＋ Tạo bộ sưu tập”, chữ forest regular |
| Hàng | icon `folder.fill` trong ô vuông, tên, 2 tiêu đề con, số bên phải, chevron | thẻ giấy có **tab mật ong** nhô ở mép trên trái; icon thư mục vẽ tay có biểu tượng; tên 19 semibold; “24 mục” dưới tên; chevron; tông cream/sage xen kẽ |
| Chân | ghi chú Inbox | không thấy trong khung nhìn (giữ, nằm dưới danh sách) |

## File

| Đường dẫn | Hành động | Lý do |
|---|---|---|
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Collections/CollectionsView.swift` | sửa | Header, pill tạo, `FolderCard` |
| `/Users/hainguyen/LocalData/Noted./Shared/NotedPaperUI.swift` | sửa | `FolderCard` (tab + thân) nếu Share cũng hiển thị bộ sưu tập; nếu không, đặt trong `Noted/UI` |
| `/Users/hainguyen/LocalData/Noted./Noted/App/RootView.swift` | sửa | Truyền `onManageData`/`onShowTrash` vào CollectionsView cho menu “…” |
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Detail/ItemDetailView.swift` | sửa | Nền giấy, PaperField trong editor, TagChip, nút Capsule/Circle |
| `/Users/hainguyen/LocalData/Noted./Noted/Features/Trash/TrashView.swift`, `Noted/App/DataManagementView.swift` | sửa | Nền giấy + component (đồng bộ, không theo mock cụ thể) |

## Bước

1. Header như Thư viện + “…” (cùng menu Dữ liệu & Backup, Thùng rác).
2. Pill tạo: `NotedButtonStyle(.soft)`, cao ~46, `maxWidth: .infinity`; id `collectionCreate`.
3. `FolderCard`: `ZStack(alignment: .topLeading)`: tab = `UnevenRoundedRectangle` honey ~64×14 lệch trái 24 pt, nằm sau thân, nhô 10 pt; thân `PaperCard` tông theo index chẵn/lẻ, cao ~96; nội dung `HStack`: `Image(Sketch…)` 56–60 pt tint primaryText | VStack(tên, “N mục”) | chevron. Khoảng cách dọc giữa thẻ chừa chỗ tab (~28 pt).
4. Biểu tượng thư mục: `NotedDesign.folderSketch(for name:)` — từ khoá (bỏ dấu, so khớp chứa): “cam hung/y tuong” → lá; “doc/sach/bai viet” → sách; “rieng/yeu/thich” → tim; “di/du lich/chuyen” → núi; còn lại chọn theo `stableHash(id) % 4` trong 4 hình trên. Không đổi schema.
5. Giữ context menu Đổi tên/Xoá, id `collection_<UUID>`, alert tạo/đổi tên.
6. Chi tiết/Editor/Thùng rác/Backup: áp `PaperBackground`, `PaperField`, nút Capsule/Circle, giữ mọi id và luồng.

## Todo

- [x] Header + menu “…”
- [x] Pill tạo sage
- [x] FolderCard + tab mật ong + tông xen kẽ
- [x] Ánh xạ biểu tượng thư mục + unit test
- [x] Chi tiết, Thùng rác, Backup đồng bộ

## Nghiệm thu

- Fixture `collections`: checklist ≥ 98%, trọng yếu 100% (đã chốt: giữ sắp theo tên; thứ tự hàng khác mock không trừ điểm, chấm từng hàng theo nội dung tương ứng).
- Unit test ánh xạ: 4 tên mock ra đúng lá/sách/tim/núi.
- UI tests tạo/mở/đổi tên/xoá bộ sưu tập, editor, Trash restore vẫn đạt.

## Rủi ro

- Tab nhô lên có thể bị cắt bởi `ScrollView` clip ở thẻ đầu → thêm padding top.
- Tên bộ sưu tập dài 2 dòng làm lệch chiều cao → `lineLimit(2)`, thẻ co giãn, tab cố định.

## Kết quả triển khai simulator — 2026-11-02

- [x] Unit ánh xạ icon và toàn suite: 46/46 đạt.
- [x] UI tạo/mở/đổi tên/xóa + menu Backup/Trash, editor draft/lỗi lưu, Trash restore/xóa: 4/4 đạt trong một lượt cuối.
- [x] Review độc lập không có blocker; `git diff --check` đạt.
- [ ] Checklist fidelity ≥98%, trọng yếu 100%: chưa đạt nghiệm thu; probe màu 15/17 không thay cho điểm checklist.

Bằng chứng và giới hạn: [Phase 06 evidence](../../docs/evidence/20261102-paper-phase6/README.md). Simulator đang chạy fixture Collections tách dữ liệu cá nhân. Có sửa bổ sung observer đóng bàn phím trong `LibraryLifecycleView.swift`: bỏ qua native alert/control để nút Tạo/Lưu hoạt động bằng một lần chạm.

## Retest 2026-11-03

- Simulator riêng `Claude Test iPhone 12 Pro` (iOS 18.6): unit 46/46, UI 23/23 (PaperComponents, MockFidelity, Library, PhaseFourAcceptance), 0 runner restart. Lỗi “signal kill” trước đó do hai phiên chạy test cùng lúc trên một simulator, không phải lỗi test.
- Chi tiết sửa và số đo: [retest evidence](../../docs/evidence/20261103-paper-phase5-6-retest/summary.md).
- Bám mock: icon thư mục 66 pt nét 3, tim tô đặc, tab 72×20, bước hàng 125,5 pt khớp v3. Probe màu Bộ sưu tập 15/17 → **17/17**. Tìm kiếm/Chi tiết/Editor/Thùng rác/Backup kiểm tra ảnh, không vỡ layout.
