# Phase 01 — iOS 27 & spike OCR có cấu trúc

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Không phụ thuộc phase nào. Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

1. Nâng minimum deployment target lên iOS 27.
2. Chọn cách nhận dạng có cấu trúc, viết bộ làm sạch và bộ phân loại loại ảnh, đo trên 27 ảnh thật trước khi xây pipeline.

## File ảnh hưởng

- Modify `Noted./Noted.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 17.0` → `27.0` ở **mọi** build configuration (Noted, NotedShare, NotedGateHost, NotedTests, NotedUITests; hiện có 12 chỗ: 5 target × Debug/Release và 2 ở cấp project).
- Modify `Noted./scripts/generate-project.rb`: đổi giá trị target nếu script có ghi cứng, để lần tạo project sau không quay về 17.
- Modify các chỗ có `#available(iOS …)` hoặc `@available` thấp hơn 27 trong `Noted./Noted`, `Noted./Shared`, `Noted./NotedShare`: bỏ nhánh không còn cần.
- Create (đề xuất) `Noted./Noted/Core/Digest/StructuredOCR.swift`: trả về các khối `{text, boundingBox, role?}` (đoạn, dòng, danh sách, bảng nếu API có).
- Create (đề xuất) `Noted./Noted/Core/Digest/OCRCleaner.swift`: bỏ nhiễu screenshot, gồm:
  - thanh trạng thái (giờ, %, nhà mạng ở ~6% chiều cao trên cùng);
  - thanh tab/nút điều hướng ở đáy;
  - dòng toàn ký hiệu hoặc số;
  - dòng lặp;
  - nối dòng bị ngắt giữa câu.
- Create (đề xuất) `Noted./Noted/Core/Digest/ScreenshotClassifier.swift`: luật phân loại `article | chat | jobPosting | other`, kèm điểm tin cậy.
- Modify `Noted./Noted/App/IntelligenceLabelingView.swift` (màn DEBUG đã có): thêm chế độ "Đánh giá tóm tắt ảnh" để gán loại đúng và chấm điểm. Nhãn lưu ngoài `library.store`, giống `labels.json` hiện có.
- Create (đề xuất) `Noted./NotedTests/StructuredOCRTests.swift`: fixture **tổng hợp**, gồm ảnh render từ text giả cho bài viết, chat bong bóng trái/phải và tin tuyển dụng.
- Modify `Noted./docs/intelligence-evaluation.md`: thêm section kết quả đo, không chứa nội dung ảnh.

## Bước

- [ ] Đổi deployment target, build Debug lên iPhone thật, chạy toàn bộ unit test scheme **Noted**. Ghi lỗi cảnh báo deprecation mới phát sinh (nếu có).
- [ ] Gọi `supportedRecognitionLanguages` của cả hai API (nhận dạng text và nhận dạng tài liệu) trên máy, ghi xem có `vi` hay không.
- [ ] So sánh hai API trên 27 ảnh thật bằng màn DEBUG:
  - tỷ lệ giữ dấu tiếng Việt (người dùng chấm nhanh từng ảnh: tốt / mất dấu ít / hỏng);
  - có trả về cấu trúc đoạn không;
  - thời gian p95 mỗi ảnh.
  Chọn API có chất lượng tiếng Việt tốt hơn. Nếu API tài liệu không hỗ trợ `vi` thì dùng API text và gom khối theo khoảng cách dọc giữa các dòng.
- [ ] Bộ làm sạch: dùng tọa độ chuẩn hóa của khối. Không dựa vào nội dung cụ thể của app nào.
- [ ] Bộ phân loại (luật, không dùng model):
  - **chat**: nhiều khối ngắn, lệch trái/phải xen kẽ, có mốc giờ ngắn (`10:24`), ít câu dài;
  - **jobPosting**: từ khóa vi/en (tuyển, vị trí, mức lương, kinh nghiệm, JD, apply, salary, yêu cầu, quyền lợi, hạn nộp); ≥2 nhóm từ khóa thì nhận;
  - **article**: đa số là đoạn dài ≥2 câu, có khối tiêu đề ở đầu (chữ cao hơn nếu API trả về chiều cao dòng);
  - còn lại là **other**. Mơ hồ thì cũng chọn other, không đoán.
- [ ] Người dùng gán loại đúng cho 27 ảnh. Đo độ chính xác của bộ phân loại.

## Acceptance

- Mọi target build được với iOS 27 trên iPhone thật, unit test scheme Noted xanh.
- Đã ghi vào `docs/intelligence-evaluation.md`: API được chọn và lý do, có `vi` hay không, p95 mỗi ảnh.
- Bộ phân loại đúng ≥80% trên 27 ảnh (mục tiêu đề xuất). Nhầm sang `other` thì chấp nhận được; nhầm giữa hai loại chính thì ghi lại từng ca.
- Unit test cleaner/classifier xanh trên fixture tổng hợp.

## Rủi ro

- Nâng target có thể làm lộ API bị deprecated trong code cũ (`VNRecognizeTextRequest`) → chỉ ghi nhận, `OCRService` hiện có không đổi trong plan này.
- 27 ảnh dễ overfit luật → giữ luật đơn giản, ghi rõ ca sai, không tinh chỉnh theo từng ảnh.
- Dữ liệu cá nhân: ảnh và text không vào repo. Evidence chỉ gồm số đếm và tỷ lệ.

Quay lui: target có thể hạ về 17 bằng git revert. Các file `Core/Digest` chưa được gọi từ luồng chính nên gỡ được.
