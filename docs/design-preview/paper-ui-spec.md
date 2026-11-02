# Đặc tả Paper UI v3 và thước đo nghiệm thu

Nguồn: `noted-paper-ui-mock-v3.png` (1536×1024). Đo raster ngày 2026-11-02; đây là đích thiết kế, chưa phải kết quả UI.

## Hệ tọa độ và ảnh chuẩn

Biên nội dung được kiểm tra trực quan tại pixel nền trong viền máy. Crop loại status bar và home indicator, giữ tab bar/sheet. Không kéo giãn chiều cao.

| Màn | Crop nguồn x,y,w,h px | Scale px/pt | Ảnh chuẩn |
|---|---|---|---|
| Thư viện | 72,178,425,804 | 425/390 | v3-library.png |
| Bộ sưu tập | 561,178,413,804 | 413/390 | v3-collections.png |
| Lưu nhanh | 1039,178,425,804 | 425/390 | v3-capture.png |

Ảnh chuẩn rộng 1170px = 390pt. Tọa độ dưới đây là pt từ đỉnh crop, độc lập status bar. Mock có méo và ba khung không cùng chiều rộng; lấy biên trong ở vùng thân thẳng (bo góc không dùng đo chiều rộng). Các số frame làm tròn gần lưới 4pt khi hợp lý, dung sai ±2pt; không coi ước lượng font từ raster là xác định font gốc. Font dùng SF Pro native, đo lại bằng bounding box chữ hoa khi nghiệm thu.

## Cách chấm

Mỗi dòng dưới là một tiêu chí, trạng thái ban đầu **chưa đo**. Dòng trọng yếu có trọng số 3, các dòng khác trọng số 1. Điểm màn = Σ trọng số đạt / Σ toàn bộ trọng số ×100; tiêu chí chưa đo tính chưa đạt. Cần ≥98% mỗi màn và toàn bộ dòng trọng yếu đạt. Hình học ±2pt; màu ΔE2000 ≤3 từ trung bình 5×5px; hình dạng/nội dung/thứ tự phải đúng. SSIM chỉ tham khảo. Các ngoại lệ đã duyệt (thứ tự collection, icon card theo loại, ngày tuyệt đối, tùy chọn mở rộng) không trừ điểm.

## library — 47 tiêu chí

| ID | Phần tử | Thuộc tính | Đích | Trọng số | Kết quả |
|---|---|---|---|---|---|
| L01 | Nền nội dung | toàn màn | cream theo probes | 3 [trọng yếu] | Chưa đo |
| L02 | Thứ tự cấu trúc | trên xuống | theo bảng hình học | 3 [trọng yếu] | Chưa đo |
| L03 | Lề trái | x | 16 | 3 [trọng yếu] | Chưa đo |
| L04 | Lề phải | trailing | 16 | 3 [trọng yếu] | Chưa đo |
| L05 | Tiêu đề | font | 34 bold / capture 28 bold | 1 | Chưa đo |
| L06 | Màu chữ chính | ink | theo ảnh | 3 [trọng yếu] | Chưa đo |
| L07 | Chữ phụ | font | 17 regular | 1 | Chưa đo |
| L08 | Nội dung chữ | text | nguyên văn mock và ngoại lệ plan | 3 [trọng yếu] | Chưa đo |
| L09 | Nút đóng/menu | shape | Circle | 3 [trọng yếu] | Chưa đo |
| L10 | Nút đóng/menu | hit target | 44×44 | 1 | Chưa đo |
| L11 | Icon nút | size | 20 | 1 | Chưa đo |
| L12 | Nền nút | color | probe nút | 3 [trọng yếu] | Chưa đo |
| L13 | Khoảng cách dọc | grid | 4pt, sai số ±2pt | 1 | Chưa đo |
| L14 | Texture | opacity | so trực quan cạnh ảnh | 1 | Chưa đo |
| L15 | Độ tương phản | text | đọc được ở 100% | 1 | Chưa đo |
| L16 | Header | frame | 20,12,350,68 | 1 | Chưa đo |
| L17 | Hero | frame | 14,93,364,112 | 1 | Chưa đo |
| L18 | Hero | radius | 16 | 1 | Chưa đo |
| L19 | Hero title | frame/font | 34,118 / 19 medium | 1 | Chưa đo |
| L20 | Hero bulb | frame | 280,108,64,80 | 1 | Chưa đo |
| L21 | Lưu nhanh | frame | 32,147,144,40 | 1 | Chưa đo |
| L22 | Lưu nhanh | shape | Capsule | 3 [trọng yếu] | Chưa đo |
| L23 | Vừa lưu | frame/font | 20,225 / 19 semibold | 1 | Chưa đo |
| L24 | 12 mục | frame/font | 326,230 / 14 | 1 | Chưa đo |
| L25 | Filter | frame | 14,256,364,40 | 1 | Chưa đo |
| L26 | Filter widths | width | 85.75 mỗi pill + 3 khoảng 7 = 364; 4 pill bằng nhau | 3 [trọng yếu] | Chưa đo |
| L27 | Filter | shape | Capsule | 3 [trọng yếu] | Chưa đo |
| L28 | Filter labels | text | Tất cả, Inbox, Ảnh, Link | 3 [trọng yếu] | Chưa đo |
| L29 | Grid | columns | 2 | 3 [trọng yếu] | Chưa đo |
| L30 | Grid | gap | 12 | 3 [trọng yếu] | Chưa đo |
| L31 | Card top left | frame | 14,306,174,186 | 1 | Chưa đo |
| L32 | Card top right | frame | 202,306,176,186 | 1 | Chưa đo |
| L33 | Card bottom left | frame | 14,505,174,170 | 1 | Chưa đo |
| L34 | Card bottom right | frame | 202,505,176,174 | 1 | Chưa đo |
| L35 | Card | radius | 12 | 1 | Chưa đo |
| L36 | Card icon | size | 24 | 1 | Chưa đo |
| L37 | Card menu | size | 20 | 1 | Chưa đo |
| L38 | Card title | font | 16 semibold | 1 | Chưa đo |
| L39 | Card body | font | 14 regular | 1 | Chưa đo |
| L40 | Card date | font | 12 regular | 1 | Chưa đo |
| L41 | Photo | height | 119 | 1 | Chưa đo |
| L42 | Photo title | font | 13 medium | 1 | Chưa đo |
| L43 | Link domain | text | vietcetera.com | 1 | Chưa đo |
| L44 | Fold | density | 1/8 tối đa, honey card trong fixture | 3 [trọng yếu] | Chưa đo |
| L45 | Tab bar | frame | 0,684,390,54 | 1 | Chưa đo |
| L46 | Tab icon | size | 24 | 1 | Chưa đo |
| L47 | Tab labels | font | 12 | 3 [trọng yếu] | Chưa đo |

## collections — 45 tiêu chí

| ID | Phần tử | Thuộc tính | Đích | Trọng số | Kết quả |
|---|---|---|---|---|---|
| C01 | Nền nội dung | toàn màn | cream theo probes | 3 [trọng yếu] | Chưa đo |
| C02 | Thứ tự cấu trúc | trên xuống | theo bảng hình học | 3 [trọng yếu] | Chưa đo |
| C03 | Lề trái | x | 16 | 3 [trọng yếu] | Chưa đo |
| C04 | Lề phải | trailing | 16 | 3 [trọng yếu] | Chưa đo |
| C05 | Tiêu đề | font | 34 bold / capture 28 bold | 1 | Chưa đo |
| C06 | Màu chữ chính | ink | theo ảnh | 3 [trọng yếu] | Chưa đo |
| C07 | Chữ phụ | font | 17 regular | 1 | Chưa đo |
| C08 | Nội dung chữ | text | nguyên văn mock và ngoại lệ plan | 3 [trọng yếu] | Chưa đo |
| C09 | Nút đóng/menu | shape | Circle | 3 [trọng yếu] | Chưa đo |
| C10 | Nút đóng/menu | hit target | 44×44 | 1 | Chưa đo |
| C11 | Icon nút | size | 20 | 1 | Chưa đo |
| C12 | Nền nút | color | probe nút | 3 [trọng yếu] | Chưa đo |
| C13 | Khoảng cách dọc | grid | 4pt, sai số ±2pt | 1 | Chưa đo |
| C14 | Texture | opacity | so trực quan cạnh ảnh | 1 | Chưa đo |
| C15 | Độ tương phản | text | đọc được ở 100% | 1 | Chưa đo |
| C16 | Header | frame | 20,14,350,68 | 1 | Chưa đo |
| C17 | Create pill | frame | 18,108,354,48 | 1 | Chưa đo |
| C18 | Create pill | shape | Capsule | 3 [trọng yếu] | Chưa đo |
| C19 | Create label | font | 17 regular | 1 | Chưa đo |
| C20 | Create icon | size | 20 | 1 | Chưa đo |
| C21 | Folder 1 | frame | 18,195,358,98 | 1 | Chưa đo |
| C22 | Folder 2 | frame | 18,320,358,98 | 1 | Chưa đo |
| C23 | Folder 3 | frame | 18,444,358,98 | 1 | Chưa đo |
| C24 | Folder 4 | frame | 18,570,358,100 | 1 | Chưa đo |
| C25 | Folder | radius | 12 | 1 | Chưa đo |
| C26 | Folder tab | size | 64×14 | 1 | Chưa đo |
| C27 | Folder tab | offset | 20,-14 | 1 | Chưa đo |
| C28 | Folder tab | color | honey | 3 [trọng yếu] | Chưa đo |
| C29 | Folder icon | size | 64×60 | 1 | Chưa đo |
| C30 | Folder title | font | 20 semibold | 1 | Chưa đo |
| C31 | Folder count | font | 14 regular | 1 | Chưa đo |
| C32 | Folder chevron | size | 16 | 1 | Chưa đo |
| C33 | Folder cream | color | probes 6/7 | 3 [trọng yếu] | Chưa đo |
| C34 | Folder sage | color | probes 9/10 | 3 [trọng yếu] | Chưa đo |
| C35 | Folder names | text | Cảm hứng, Đọc sau, Góc riêng, Chuyến đi | 3 [trọng yếu] | Chưa đo |
| C36 | Folder counts | text | 24, 18, 12, 15 | 3 [trọng yếu] | Chưa đo |
| C37 | Folder order | rule | sort tên; ngoại lệ được chấp nhận | 3 [trọng yếu] | Chưa đo |
| C38 | Tab bar | frame | 0,703,390,54 | 1 | Chưa đo |
| C39 | Tab icon | size | 24 | 1 | Chưa đo |
| C40 | Tab labels | font | 12 | 3 [trọng yếu] | Chưa đo |
| C41 | Selected tab | text | Bộ sưu tập | 1 | Chưa đo |
| C42 | Card shadow | offset | 0,2 | 1 | Chưa đo |
| C43 | Card shadow | blur | 4 | 1 | Chưa đo |
| C44 | Folder rows | count | 4 | 1 | Chưa đo |
| C45 | Folder icons | motifs | lá/sách/tim/núi | 1 | Chưa đo |

## capture — 47 tiêu chí

| ID | Phần tử | Thuộc tính | Đích | Trọng số | Kết quả |
|---|---|---|---|---|---|
| Q01 | Nền nội dung | toàn màn | cream theo probes | 3 [trọng yếu] | Chưa đo |
| Q02 | Thứ tự cấu trúc | trên xuống | theo bảng hình học | 3 [trọng yếu] | Chưa đo |
| Q03 | Lề trái | x | 16 | 3 [trọng yếu] | Chưa đo |
| Q04 | Lề phải | trailing | 16 | 3 [trọng yếu] | Chưa đo |
| Q05 | Tiêu đề | font | 34 bold / capture 28 bold | 1 | Chưa đo |
| Q06 | Màu chữ chính | ink | theo ảnh | 3 [trọng yếu] | Chưa đo |
| Q07 | Chữ phụ | font | 17 regular | 1 | Chưa đo |
| Q08 | Nội dung chữ | text | nguyên văn mock và ngoại lệ plan | 3 [trọng yếu] | Chưa đo |
| Q09 | Nút đóng/menu | shape | Circle | 3 [trọng yếu] | Chưa đo |
| Q10 | Nút đóng/menu | hit target | 44×44 | 1 | Chưa đo |
| Q11 | Icon nút | size | 20 | 1 | Chưa đo |
| Q12 | Nền nút | color | probe nút | 3 [trọng yếu] | Chưa đo |
| Q13 | Khoảng cách dọc | grid | 4pt, sai số ±2pt | 1 | Chưa đo |
| Q14 | Texture | opacity | so trực quan cạnh ảnh | 1 | Chưa đo |
| Q15 | Độ tương phản | text | đọc được ở 100% | 1 | Chưa đo |
| Q16 | Sheet | frame | 0,5,390,733 | 1 | Chưa đo |
| Q17 | Sheet | radius | 28 top | 1 | Chưa đo |
| Q18 | Handle | frame | 169,17,48,5 | 1 | Chưa đo |
| Q19 | Title | frame | 22,51,300,32 | 1 | Chưa đo |
| Q20 | Close | frame | 337,23,40,40; hit44 | 1 | Chưa đo |
| Q21 | Modes | frame | 22,102,350,46 | 1 | Chưa đo |
| Q22 | Mode widths | width | 115,115,115 chuẩn hóa bằng nhau | 3 [trọng yếu] | Chưa đo |
| Q23 | Mode | shape | Capsule | 3 [trọng yếu] | Chưa đo |
| Q24 | Mode labels | text | Ghi chú, Link, Ảnh | 3 [trọng yếu] | Chưa đo |
| Q25 | Mode icon | size | 22 | 1 | Chưa đo |
| Q26 | Title label | frame/font | 22,171 / 15 | 1 | Chưa đo |
| Q27 | Title field | frame | 20,197,352,42 | 1 | Chưa đo |
| Q28 | Title field | radius | 10 | 1 | Chưa đo |
| Q29 | Title value | text | Ý tưởng cuối tuần | 3 [trọng yếu] | Chưa đo |
| Q30 | Body label | frame/font | 22,255 / 15 | 1 | Chưa đo |
| Q31 | Body field | frame | 22,282,350,182 | 1 | Chưa đo |
| Q32 | Body field | radius | 12 | 1 | Chưa đo |
| Q33 | Body text | font | 17 regular | 1 | Chưa đo |
| Q34 | Body text | content | • Đi Đà Lạt / • Chụp ảnh phim / • Tìm quán cà phê mới | 3 [trọng yếu] | Chưa đo |
| Q35 | Collection label | frame | 22,483 | 1 | Chưa đo |
| Q36 | Collection field | frame | 20,507,352,47 | 1 | Chưa đo |
| Q37 | Collection value | text | Góc riêng | 3 [trọng yếu] | Chưa đo |
| Q38 | Tags label | frame | 22,574 | 1 | Chưa đo |
| Q39 | Tags field | frame | 20,596,352,51 | 1 | Chưa đo |
| Q40 | Tag chip | frame | 78,605,100,33 | 1 | Chưa đo |
| Q41 | Tag chip | shape | Capsule | 3 [trọng yếu] | Chưa đo |
| Q42 | Tag value | text | cảm hứng | 3 [trọng yếu] | Chưa đo |
| Q43 | Save button | frame | 20,671,354,50 | 1 | Chưa đo |
| Q44 | Save button | shape | Capsule | 3 [trọng yếu] | Chưa đo |
| Q45 | Save label | font | 18 semibold | 1 | Chưa đo |
| Q46 | Save label | text | Lưu ghi chú | 1 | Chưa đo |
| Q47 | More options | visibility | dưới thẻ, ngoài khung đầu theo quyết định plan | 1 | Chưa đo |

## Màu và fixture

`reference/color-probes.json` lưu tối thiểu 16 vùng/màn; tọa độ pt và hex là trung bình 5×5 trên ảnh đã scale. Không dùng pixel chữ/viền làm màu token. Đây là dữ liệu đo, Phase02 chọn token đại diện từ nhiều vùng cùng vật liệu.

Fixture chỉ bật trong DEBUG qua `NOTED_MOCK_FIXTURE=library|collections|capture`; kho và draft tách khỏi dữ liệu cá nhân. Ảnh cà phê crop nguồn 189×130+89+729 chỉ dùng fixture. Library 12 mục, bốn mục đầu theo mock; collections 69 mục chia 24/18/12/15, không dùng chung biến thể library. Capture có bản nháp; các trường metadata sẽ hiển thị khi Phase07 thực hiện UI tương ứng. ID cố định là đầu vào cho quy tắc màu/góc cong Phase02, cần xác nhận lại mapping tại phase đó.

## Chạy so sánh

```sh
scripts/ui-fidelity/compare.sh docs/evidence/20261102-iphone12pro/01-library.png docs/design-preview/reference/v3-library.png docs/design-preview/reference/color-probes.json /private/tmp/noted-fidelity-library
```

Ảnh thiết bị mặc định cắt 47pt status và 34pt home, chuẩn hóa rộng1170; cắt theo chiều cao ảnh chuẩn (báo lỗi nếu ảnh thiết bị ngắn hơn), không méo hình. Capture sheet căn theo đỉnh nội dung, không tự căn dựa vào chữ để che sai lệch. Kết quả `side-by-side.png`, `overlay.png`, `diff.png` cùng probe/SSIM là bằng chứng hỗ trợ, chưa tự chấm font/hình học/nội dung. Self-test dùng `FIDELITY_CONTENT_INPUT=1` với ảnh chuẩn làm cả hai đầu vào.
