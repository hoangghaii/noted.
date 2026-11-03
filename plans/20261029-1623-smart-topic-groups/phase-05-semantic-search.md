# Phase 05 — Tìm kiếm theo nghĩa

Ngày 2026-11-03. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc Phase 02 (vector cache). Ưu tiên trung bình. Overview: [plan.md](plan.md).

## Mục tiêu

Tìm “quán cà phê yên tĩnh” vẫn ra mục ghi “cafe làm việc ở Đà Nẵng”. Chạy offline. Tìm từ khóa hiện có vẫn là đường chính và đường lui.

## File ảnh hưởng

- Modify `Noted./Noted/Core/Search/SearchService.swift` — giữ `matches` hiện có, thêm xếp hạng kết hợp.
- Create (đề xuất) `Noted./Noted/Core/Intelligence/SemanticSearch.swift` — embed truy vấn (`role: .query`), so cosine với vector cache, lấy top-K theo ngưỡng.
- Modify `Noted./Noted/Features/Search/SearchView.swift` — section “Liên quan theo nghĩa” bên dưới kết quả từ khóa.
- Create (đề xuất) `Noted./NotedTests/SemanticSearchTests.swift`.

## Bước

- [ ] Debounce 300 ms, hủy truy vấn cũ khi người dùng gõ tiếp. Embedding chạy ngoài main actor. Truy vấn < 2 ký tự → chỉ tìm từ khóa.
- [ ] Kết quả = mục khớp từ khóa (giữ thứ tự mới nhất như hiện tại), rồi đến mục khớp theo nghĩa (cosine ≥ ngưỡng từ Phase 01, tối đa 20), loại trùng ID và loại trash.
- [ ] Brute-force cosine trên vector đã nạp vào bộ nhớ. Đủ nhanh tới vài nghìn mục. Đo ở 1k và 5k mục giả lập; chỉ khi chậm mới tối ưu.
- [ ] Mục chưa có vector → chỉ tìm được bằng từ khóa; ghi chú nhỏ “N mục đang phân tích”.
- [ ] Tôn trọng filter đang chọn (pill/collection). Chế độ nhóm theo chủ đề (Phase 03) áp lên tập kết quả cuối.
- [ ] Engine lỗi hoặc tắt AI → ẩn section theo nghĩa, tìm từ khóa không bị ảnh hưởng.

## Acceptance

- Bộ 10–20 truy vấn mẫu (Phase 01): recall@10 cao hơn tìm từ khóa, mục tiêu đề xuất +20 điểm phần trăm.
- p95 từ lúc dừng gõ tới khi có kết quả ≤400 ms trên iPhone 12 Pro với thư viện thật.
- Offline vẫn chạy.

## Rủi ro

Kết quả theo nghĩa nhiễu → ngưỡng chặt, tách section riêng để không lẫn với kết quả chính xác. Quay lui: tắt section, SearchService giữ nguyên.
