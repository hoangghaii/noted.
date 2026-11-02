# Phase 04 — Nghiệm thu iPhone

Ngày 2026-10-29. Trạng thái: Pending. Review: chưa nghiệm thu. Phụ thuộc phase 03; ưu tiên cao.

## File ảnh hưởng

- Create `/Users/nhhai7/LocalData/Noted./NotedUITests/TopicGroupingUITests.swift` — Group/filter/correction flows với fixture riêng (đường dẫn dự kiến).
- Create `/Users/nhhai7/LocalData/Noted./docs/topic-grouping-verification.md` — Bằng chứng runtime, quality, limitations (đường dẫn dự kiến).
- Modify `/Users/nhhai7/LocalData/Noted./README.md` — Cách dùng, offline/API privacy, model và backup.
- Modify `/Users/nhhai7/LocalData/Noted./docs/verification.md` — Liên kết evidence mới, không thay historical results.

## Bước thực hiện và kiểm chứng

- [ ] Chạy tests engine/lifecycle trên iPhone thật, rồi UI fixture: ca phe/đà nẵng, tìm việc, Carepath, thu nhập, humor; ghi expected ID sets, không chỉ screenshot tên nhóm.
- [ ] Đánh giá holdout chưa dùng tune; ghi confusion theo nhóm, unknown/coverage, user-corrected examples riêng. Không claim hiểu meme/ảnh không text; chụp giao diện nhóm, pending và sửa nhóm.
- [ ] Đo model load, thời gian item/batch, peak memory/thermal trên iPhone 12 Pro. Kiểm tra capture ngay trong lúc batch AI chạy và cancel/background/relaunch không duplicate job.
- [ ] Chứng minh offline thật bằng probe mạng mới thất bại, mở cached groups và note/image capture; local engine phân nhóm mới được; nếu API engine thì item mới pending, xem cache vẫn được. Không reinstall trong lúc test offline.
- [ ] Fault matrix: cache corrupt/model missing, response sai schema/topic ID, timeout/rate limit/API quota, edit/trash/delete trong inference, backup đang chạy. Retry không vô hạn, manual overrides giữ nguyên.
- [ ] Roundtrip backup v1 → app mới, mới → mới với topic name/merge/override; cài đè cùng bundle ID giữ originals/checksum và nhóm. Không uninstall.
- [ ] Chạy build và cài bản cuối lên iPhone; người dùng tự nghiệm thu chủ đề trên nội dung đã chọn. Phân biệt build, unit, UI và đánh giá chất lượng thực.

Lệnh dự kiến (sau khi thêm targets/files):
```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=00008101-001A2519266B001E' -only-testing:NotedTests/TopicQualityTests -only-testing:NotedTests/TopicLifecycleTests test
```
UI dùng scheme có NotedUITests đang cấu hình, xác minh scheme trước chạy, không giả lệnh trên đã gồm UI.

Acceptance: có report với số đạt/trượt/thời gian/engine version và artifact thực; mọi acceptance còn thiếu ghi pending. Nếu local gate không đạt và API chưa có cấu hình, không bật AI mặc định hoặc claim complete.

Quay lui: tắt tự nhóm, dùng flat list/cache hợp lệ; giữ user corrections và dữ liệu gốc. Chưa có evidence trước phase này.
