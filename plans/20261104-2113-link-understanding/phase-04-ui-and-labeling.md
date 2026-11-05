# Phase 04 — Giao diện & màn gán nhãn

Ngày 2026-11-04. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 03. Giao diện thẻ/Detail theo layout của plan [Giấy & Bảng ghim](../archived/20261102-2119-paper-pinboard-ui/plan.md) (đã lưu trữ). Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Người dùng nhìn thẻ link là biết link nói về gì. Màn gán nhãn DEBUG và evaluator Phase 01 dùng cùng bản đọc hiểu đó.

## File ảnh hưởng

- Modify `Noted./Noted/Features/Library/ItemCard.swift`: 1–2 dòng tóm tắt dưới tiêu đề, kèm tên trang/tác giả. `loginWall` → dòng phụ “Không đọc được nội dung (cần đăng nhập)”.
- Modify `Noted./Noted/Features/Detail/ItemDetailView.swift`: section “Tóm tắt” (tiêu đề, tác giả, tóm tắt, nguồn trích xuất/API), nút “Thử đọc lại”. `loginWall` gợi ý thêm ghi chú.
- Modify `Noted./Noted/App/IntelligenceLabelingView.swift` (DEBUG): hiển thị tóm tắt link khi gán nhãn.
- Modify `Noted./Noted/Core/Intelligence/IntelligenceSpikeEvaluator.swift` (DEBUG): đầu vào text của link dùng `LinkDigest.textForEmbedding` khi có, ghi `linkDigestCoverage` vào report.
- Modify `Noted./Noted/Core/Search/SearchService.swift`: (đề xuất) tìm thêm trong tóm tắt link, không đổi luật chuẩn hóa hiện có.

## Bước

- [ ] Thẻ: chỉ hiện khi `status == complete` và có `summary`; không hiện placeholder lúc đang chạy.
- [ ] Detail: hiện nguồn của tóm tắt (“Trích từ trang” hoặc “Viết lại bằng AI”), ngày đọc.
- [ ] Màn gán nhãn: hiện tiêu đề, tên trang/tác giả và tóm tắt dưới URL.
- [ ] Evaluator: báo riêng precision/coverage cho link có digest và link `loginWall`.
- [ ] VoiceOver đọc được tóm tắt; Dynamic Type không cắt chữ quá mức.

## Acceptance

- Trên iPhone: link có og:description hiện tóm tắt trên thẻ và Detail; link login wall hiện thông báo đúng.
- Màn gán nhãn DEBUG hiển thị tóm tắt cho tất cả link đọc được.
- UI test hiện có (`IntelligenceLabelingUITests`, scheme `Noted-DeviceGate`) vẫn pass.

## Rủi ro

- Thẻ dày hơn → giới hạn 2 dòng, kiểm tra với layout giấy.
- Tóm tắt sai gây hiểu nhầm → luôn hiện nguồn, người dùng mở link gốc được.

Quay lui: ẩn section tóm tắt; dữ liệu digest vẫn còn.
