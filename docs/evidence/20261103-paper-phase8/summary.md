# Phase 08 — Nghiệm thu trên iPhone 12 Pro thật (2026-11-03)

Thiết bị: iPhone 12 Pro `00008101-001A2519266B001E`, iOS 27, Debug, bundle `dev.nhhai7.Noted`, team `8D4HNUUVQ9` (Personal Team). Không đổi cài đặt project; ký tự động với `-allowProvisioningUpdates`.

## Kết quả kiểm thử (lần chạy cuối, sau mọi chỉnh sửa)

| Bộ | Kết quả |
|---|---|
| Unit (scheme Noted) | **61/61**: 54 test của plan này (thêm 4 test M2), 7 test thuộc plan khác |
| UI (PaperComponents, MockFidelity, Library, PhaseFourAcceptance, PhaseOne, PhotosGate, ExternalShare) | **33/33** (thêm `testMeasuredTextSizesScaleWithDynamicType`) |
| Share Safari / Photos / hệ thống | `testSafariURLShare`, `testPhotosImageShare`, `testSystemURLShare`, `testSystemPNGShare`, `testSystemTextSharePersistsAfterRelaunch`: đạt |
| Backup export (Files, On My iPhone) | `testBackupLocalFilesPicker`: đạt |
| Icon Home Screen | `testPhaseFiveHomeScreenIcon`: đạt |
| Tỉ lệ lật mép ~1/4 | `NotedDesignTests` (1000 note → 200–300 lật; 4 card fixture đầu như mock): đạt |
| `ExternalShareUITests` (2) | **2/2** (người dùng đã giải phóng một slot app). Trước đó test lỗi ở `tearDown`: `hasSucceeded` vẫn false trong lúc teardown, nên luôn snapshot `ShareUIService` đã thoát. Đã sửa sang `failureCount` và bỏ qua app không chạy. |

Lỗi gặp khi chạy và cách xử lý:

- `testCapturePinsSavedNoteOnce`: lúc mở, nội dung “Tùy chọn khác” nằm sau thanh Lưu, nên lần chạm switch Ghim rơi vào nút Lưu. Sửa ở app: tự cuộn tới phần vừa mở. Test chỉ chạm khi switch đã ra khỏi thanh Lưu. Kết quả 3/3 trên máy.
- `testBackupLocalFilesPicker`: export thành công, nhưng section “Kết quả” nằm dưới mép màn của `List` lazy nên chưa được render. Test giờ cuộn tới kết quả.
- Lưu ý UX (chưa sửa, ngoài phạm vi): sau khi xuất backup, người dùng cũng phải cuộn mới thấy dòng “Đã xuất…”.

## Dữ liệu cá nhân

Bundle ID đổi từ `dev.nguyenhoanghai861.Noted` sang `dev.nhhai7.Noted` (quyết định của người dùng), nên bản mới là một app riêng, không phải cài đè.

- App cũ và test runner cũ đã được gỡ theo đồng ý của người dùng, sau khi người dùng xác nhận đã backup.
- Tiêu chí “số mục sau cài đè ≥ trước” vì vậy không áp dụng được. `testPersonalLibraryCountIsUnchanged` đạt cho kho mới.
- Rủi ro: `PhaseOneUITests`/`LibraryUITests` ghi mục thử (vd. “NOTED DEVICE GATE TEXT…”) vào kho cá nhân của app mới. Nên chạy các test này trước khi nhập backup thật, hoặc xóa mục thử sau đó.

## Bám sát mock (≥98% mỗi màn)

Phương pháp:

- Mock v3 và ảnh máy thật được đo bằng cùng công cụ [`measure.py`](measure.py): flood-fill vùng màu → bounding box; với chữ và icon, lấy bounding box mực. Số liệu trong [`geometry-measurements.json`](geometry-measurements.json).
- Màu: `scripts/ui-fidelity/compare.sh`, ΔE2000 ≤ 3.
- Khung hình học trong `paper-ui-spec.md` khớp mock nên giữ nguyên. Các ước lượng Phase 01 bị phép đo bác bỏ được đo lại, có bằng chứng, ở mục “Đo lại 2026-11-03” của spec.
- Tiêu chí chưa đo tính là chưa đạt. Sai khác đã duyệt (plan, quyết định 2–8) không trừ điểm.

| Màn | Probe màu | Trọng yếu | Điểm có trọng số | Kết luận | Ảnh |
|---|---|---|---|---|---|
| Thư viện | 15/16 (1 đã duyệt) | 16/16 | **98.7%** (78/79) | **Đạt** (7 vòng; vòng 6–7 được người dùng cho phép) | [side-by-side](side-by-side-library.jpg) |
| Bộ sưu tập | 17/17 | 16/16 | **98.7%** (76/77) | **Đạt** | [side-by-side](side-by-side-collections.jpg) |
| Lưu nhanh | 14/16 (2 đã duyệt) | 17/17 | **98.8%** (80/81) | **Đạt** | [side-by-side](side-by-side-capture.jpg) |

### Tiêu chí chưa đạt

| ID | Đích (mock) | Máy | Lý do |
|---|---|---|---|
| L20 | bóng đèn kèm tia ~69×80 | ~69×67 | Nét vẽ bóng đèn dẹt hơn ảnh AI. Khớp theo chiều rộng và tâm |
| C29 | icon thư mục ~61×54 (mực) | 57×45 | Tỉ lệ nét vẽ khác mock (1.13 so với 1.27). Phóng to sẽ làm hàng thư mục cao hơn 98 pt và làm hỏng C21–C24 |
| Q16 | sheet y 5 | 0 | Detent `.large` do hệ thống đặt; giới hạn native |

Sai khác đã duyệt: nút Lưu cố định (Q43, probe capture-14/15), pill Lưu nhanh 44 pt (L21), tab bar neo đáy (L45/C38, probe library-16), thứ tự bộ sưu tập, icon card theo loại, ngày tuyệt đối, “Tùy chọn khác” ngoài khung đầu. Tỉ lệ lật mép ~1/4 (quyết định 8, L44).

Lưu nhanh: dấu “×” nhỏ trên chip thẻ (mock không có) được giữ để người dùng còn thấy cách xóa thẻ. Chip vẫn khớp khung 78,605,99×33.

## Các vòng chỉnh trong Phase 08

| Vòng | Màn | Thay đổi | Đo sau |
|---|---|---|---|
| 1 | Thư viện / Lưu nhanh | hero +2.5 pt; khoảng ngày→đáy card; lề Lưu nhanh 20; bỏ góc cong vùng Nội dung (mock không có) | hero y 93.3 ✓ |
| 2 | Thư viện | lề 14; line spacing 1.8 | tiêu đề link 1 dòng ✓ |
| 3 | Thư viện | min card 174 | hàng 1 = 188 |
| 4 | Thư viện | tiêu đề ảnh 11.5; khoảng chữ card ảnh | tiêu đề ảnh y 633.3 ✓ |
| 5 | Thư viện | icon card top 10; khoảng hàng 14 | hàng 185/176 ở y 306/505 ✓ |
| 6 | Bộ sưu tập | chữ header thụt 4 và lên 2.5; nút tạo 354 rộng ở x 18; bóng card y 2 | header, nút tạo, tab, thư mục trong ±2 ✓ |
| 6–8 | Lưu nhanh | tiêu đề lên 3 / vào 3 (bù khoảng phía trên pill); icon chế độ 17.5; nhãn Lưu 18 semibold; chip gọn, ở x 78 | mọi khung trong ±2 ✓ |
| 6 | Thư viện | chữ header thụt 5.5 và tiêu đề xuống 2.3; phụ đề 17; tiêu đề hero +2.6/+4.7 (pill giữ chỗ); “Vừa lưu” 19 semibold; số mục 13; ⋯ card 14.5 | header, hero, “Vừa lưu”, số mục, ⋯ trong ±2 ✓ |
| 7 | Thư viện | ngày về 11 pt (mock đo 70.3 pt rộng); bóng đèn khung 80, tâm x ≈317 | ngày ✓; bóng đèn khớp rộng/tâm |
| — | Chung | tỉ lệ lật mép 1/8 → ~1/4 (quyết định người dùng) | unit đạt |

## Kiểm thủ công và review

- Cuộn ~50 mục mượt; chữ `Ă Â Đ Ê Ô Ơ Ư` không bị cắt: **người dùng xác nhận đạt** (2026-11-03).
- Review code: [báo cáo](../../../plans/archived/20261102-2119-paper-pinboard-ui/reports/20261103-code-reviewer-phase07-08.md). Không có lỗi Critical.
  - Đã sửa:
    - M1: banner lỗi bản nháp bị khuất.
    - M2: options lưu bền theo payload id.
    - M3: `scaledFont`, giữ nguyên giá trị đo ở cỡ L; ảnh fixture trùng trước khi sửa.
    - L3: xoá bản nháp chưa xoá ô thẻ.
  - Còn mở: M4 (bundle ID hard-code trong UI test), L1–L2, L4–L10.

## Chưa kiểm chứng

- VoiceOver và dark mode chưa được nghiệm thu đầy đủ trên máy.
- Chưa có UI test lưu link/ảnh qua sheet Lưu nhanh (review L7).
