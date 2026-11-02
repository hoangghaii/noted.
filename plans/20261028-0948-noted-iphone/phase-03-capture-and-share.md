# Phase 03 — Share, note, ảnh và paste

Trạng thái: nguồn đã triển khai; 4/4 decoder tests, Safari URL Share, Photos một ảnh mẫu và Photos ba ảnh mẫu sau khi xóa nguồn đạt trên iPhone 12 Pro. Người dùng xác nhận Safari text còn sau khi đóng/mở lại Noted ngày 2026-10-29. Preview mới đã được cài đè; assertion UI riêng cho preview còn chờ. Số lần chạm/thời gian chưa đo. Notes chỉ gửi `public.url`, không có bản sao text. Phụ thuộc thiết kế: [02](phase-02-durable-local-data.md).
Mục tiêu: lưu không bắt đặt tên hoặc chọn collection.

## Scope và file dự kiến

Dùng chung queue phase 02. Extension nhận text/URL/ảnh; app có note composer, Photos picker và paste chủ động.
Ảnh được copy vào Noted, không giữ URL tạm của host làm nguồn lâu dài.

| Hành động | Đường dẫn tuyệt đối | Mục đích |
|---|---|---|
| Modify | `/Users/nhhai7/LocalData/Noted./NotedShare/ShareViewController.swift` | Decode, preview nhẹ, save/retry/cancel |
| Modify | `/Users/nhhai7/LocalData/Noted./NotedShare/Info.plist` | Activation rules theo hỗ trợ thực tế |
| Create | `/Users/nhhai7/LocalData/Noted./Shared/IncomingContentDecoder.swift` | Chọn representation, tránh trùng |
| Create | `/Users/nhhai7/LocalData/Noted./Noted/Features/Capture/CaptureSheet.swift` | Note/ảnh/paste |
| Create | `/Users/nhhai7/LocalData/Noted./Noted/Features/Capture/NoteDraftStore.swift` | Draft bền vững |
| Create | `/Users/nhhai7/LocalData/Noted./NotedTests/IncomingContentTests.swift` | Mixed payload/batch validation |

Create là đường dẫn đề xuất; Modify trỏ tới file tạo ở phase trước.

## Các bước

- [ ] Decoder chọn URL/text/image representation phù hợp; URL và title của cùng link không thành hai item.
- [ ] Giữ caption/text đi kèm khi có; payload mixed không hỗ trợ phải báo rõ, không bỏ âm thầm.
- [ ] Nhiều ảnh thành batch all-or-nothing trước ready, mỗi ảnh một item; vượt giới hạn báo trước save.
- [ ] Extension có preview nhỏ, Lưu/Hủy, progress/lỗi; mặc định Inbox, không ép mở app.
- [ ] Tạo note/Photos picker; draft chỉ xóa sau commit lưu thành công.
- [ ] Paste chỉ khi bấm; http/https thành link, text khác thành note.
- [ ] Launch/foreground import queue, refresh Library; thông báo “đã lưu trên máy” đúng trạng thái.
- [ ] Xác minh file copy độc lập với host/temp file và ảnh trong Photos.

## Kiểm chứng và acceptance

- [ ] Safari Share tạo đúng một URL gốc; title/text đi kèm được giữ.
- [ ] Photos Share một/ba ảnh, đủ file gốc; vẫn mở được sau xóa ảnh nguồn.
- [ ] Plain text/Unicode/nhiều dòng giữ nguyên nội dung.
- [ ] Offline lưu đủ ba loại, không đợi preview/OCR.
- [ ] Hủy/lỗi giữa batch không báo lưu một phần thành thành công.
- [ ] Retry cùng capture không trùng; thao tác cố ý lưu lần mới không bị mất do dedupe quá rộng.
- [ ] Đóng extension/app sau xác nhận rồi mở lại không mất nội dung.
- [ ] Đo số thao tác/thời gian trên iPhone thật; không khẳng định đạt mục tiêu khi chưa đo.

```sh
xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<IPHONE_UDID>' -only-testing:NotedTests/IncomingContentTests test
```

Unit test bổ trợ; Safari/Photos/text Share cần thao tác thật và evidence.

## Tiếp tục ngày 2026-10-29

- Share Extension hiện tóm tắt loại nội dung, số ảnh và caption từ host trước khi bấm Lưu; payload quá giới hạn hoặc không hỗ trợ được báo trước và nút Lưu bị vô hiệu. Build `generic/platform=iOS` với `CODE_SIGNING_ALLOWED=NO` đạt sau thay đổi cuối. Bản build này chưa được cài lên iPhone.
- `devicectl list devices` báo iPhone 12 Pro và các iPhone khác không khả dụng. Các ô nghiệm thu liên quan ba ảnh trong một lần Photos Share, xóa ảnh nguồn, Share text sau relaunch và đo thao tác/thời gian vẫn mở. Kết quả unit và xác nhận thủ công ngày 2026-10-28 là bằng chứng lịch sử, không thay cho chạy lại.
- Sau khi iPhone 12 Pro kết nối, bản mới đã được ký/cài đè và `IncomingContentTests` đạt 4/4 trên thiết bị thật (`/private/tmp/noted-phase3-incoming-20261029.xcresult`). Lần UI test Share text đầu tiên dừng trước test body vì hết thời gian bật Automation Mode; sau khi bật, iPhone chuyển sang `unavailable` trước lần chạy lại. Chưa tính các lần này là kết quả Share/relaunch.
- UI test Safari → Noted → URL đạt trên iPhone sau sửa locator vuốt hàng app (`/private/tmp/noted-phase3-safari-url-retry2-20261029.xcresult`). UI test Photos → Noted → một ảnh mẫu đạt sau khi đợi nhận diện ảnh mẫu và chọn đúng ô Thêm (`/private/tmp/noted-phase3-photos-one-retry2-20261029.xcresult`). Cả hai xác minh Share thực qua app nguồn khác, không đại diện cho ba ảnh hoặc text relaunch.
- Lần bổ sung assertion preview/URL duy nhất dừng do RemoteXPC mất kết nối với UI runner trước khi test xong (`/private/tmp/noted-phase3-safari-url-preview-20261029.xcresult`); không dùng làm bằng chứng cho preview.
- Người dùng xác nhận Photos Share đồng thời ba ảnh mẫu tím, mở đủ ảnh sau khi xóa ảnh nguồn; Safari Share văn bản còn nguyên sau khi đóng/mở lại Noted. Đây là kiểm chứng thủ công ngày 2026-10-29; số thao tác và thời gian chưa được ghi.

## Rủi ro, quay lui và câu hỏi

Host cung cấp payload khác nhau; dùng fixture khử dữ liệu cá nhân. Không âm thầm nén originals.
Decoder lỗi thì giữ batch retry, phục hồi decoder trước; không xóa dữ liệu đã lưu.
Còn mở: ứng dụng nguồn thường dùng, loại ảnh và giới hạn batch phù hợp.
