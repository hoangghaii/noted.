# Phase 04 — Giao diện & màn gán nhãn

Ngày 2026-11-04. Trạng thái: Implemented — build, unit và UI test iPhone đạt; còn nghe VoiceOver thủ công. Review: tự rà soát diff, chưa nghiệm thu accessibility đầy đủ. Phụ thuộc Phase 03. Giao diện thẻ/Detail theo layout của plan [Giấy & Bảng ghim](../archived/20261102-2119-paper-pinboard-ui/plan.md) (đã lưu trữ). Ưu tiên cao. Overview: [plan.md](plan.md).

## Mục tiêu

Người dùng nhìn thẻ link là biết link nói về gì. Màn gán nhãn DEBUG và evaluator Phase 01 dùng cùng bản đọc hiểu đó.

## File ảnh hưởng

- Modify `Noted./Noted/Features/Library/ItemCard.swift`: 1–2 dòng tóm tắt dưới tiêu đề, kèm tên trang/tác giả. `loginWall` → dòng phụ “Không đọc được nội dung (cần đăng nhập)”.
- Modify `Noted./Noted/Features/Detail/ItemDetailView.swift`: section “Tóm tắt” (tiêu đề, tác giả, tóm tắt, nguồn trích xuất/API), nút “Thử đọc lại”. `loginWall` gợi ý thêm ghi chú.
- Modify `Noted./Noted/App/IntelligenceLabelingView.swift` (DEBUG): hiển thị tóm tắt link khi gán nhãn.
- Modify `Noted./Noted/Core/Intelligence/IntelligenceSpikeEvaluator.swift` (DEBUG): đầu vào text của link dùng `LinkDigest.textForEmbedding` khi có, ghi `linkDigestCoverage` vào report.
- Modify `Noted./Noted/Core/Search/SearchService.swift`: (đề xuất) tìm thêm trong tóm tắt link, không đổi luật chuẩn hóa hiện có.

## Bước

- [x] Thẻ: chỉ hiện khi `status == complete` và có `summary`; không hiện placeholder lúc đang chạy.
- [x] Detail: hiện nguồn của tóm tắt (“Trích từ trang” hoặc “Viết lại bằng AI”), ngày đọc.
- [x] Màn gán nhãn: hiện tiêu đề, tên trang/tác giả và tóm tắt dưới URL.
- [x] Evaluator: báo riêng precision/coverage cho link có digest và link `loginWall`.
- [x] VoiceOver đọc được tóm tắt; Dynamic Type không cắt chữ quá mức.

## Acceptance

- Trên iPhone: link có og:description hiện tóm tắt trên thẻ và Detail; link login wall hiện thông báo đúng.
- Màn gán nhãn DEBUG hiển thị tóm tắt cho tất cả link đọc được.
- UI test hiện có (`IntelligenceLabelingUITests`, scheme `Noted-DeviceGate`) vẫn pass.

## Rủi ro

- Thẻ dày hơn → giới hạn 2 dòng, kiểm tra với layout giấy.
- Tóm tắt sai gây hiểu nhầm → luôn hiện nguồn, người dùng mở link gốc được.

Quay lui: ẩn section tóm tắt; dữ liệu digest vẫn còn.

## Triển khai 2026-11-05

- Dùng runner trong SwiftUI environment và cache theo item ID; UI/evaluator loại digest cũ khi URL hoặc engine fingerprint đổi. Không sửa schema `library.store`/`intelligence.store`.
- Thẻ có byline + 2 dòng summary khi `complete`, mở rộng ở cỡ chữ accessibility; login wall có thông báo riêng. Detail có nguồn, thời điểm đọc, ghi chú và đọc lại. Sheet gán nhãn nhận cùng runner.
- Report JSON **schema v4**: `linkDigestCoverage` = số link có summary hoàn chỉnh / tổng link đang dùng; mỗi candidate có `linksWithDigest` và `linksLoginWall` (evaluated/predicted/correct/precision/coverage trên holdout). Không dự đoán thì precision null; không có mẫu thì coverage null. Không xuất nội dung digest.
- Search trong summary là đề xuất tùy chọn, chưa làm trong phase này.
- Kiểm chứng và giới hạn: [báo cáo](../../docs/evidence/20261105-link-phase4/summary.md).

Kết quả cuối: build đạt; 24 test pipeline/report đạt (0 skip), 4/4 UI test đạt trên iPhone. Nghiệm thu UI dùng corpus tổng hợp; không kết luận chất lượng link thật hay gán nhãn lại (Phase 06).
