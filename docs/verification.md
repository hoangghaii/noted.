# Kiểm chứng Noted trên iPhone thật

Ngày 2026-10-28. Thiết bị: Hải - iPhone 12 Pro (`00008101-001A2519266B001E`, iPhone13,3), iOS 27.0.1 (24A446), Xcode 27.0 (27A266a), iPhoneOS SDK 27.0. Không dùng Simulator hoặc TestFlight.

## Đã xác minh

Cập nhật 2026-10-29 — phase 04: 39/39 unit tests đạt trên iPhone 12 Pro/iOS 27.0.1, gồm 8 lifecycle tests. [Unit summary](evidence/20261029-iphone12pro/phase4-unit-summary.json). Các ca mới kiểm tra tổ chức sau reopen, draft qua save lỗi/import, deletion journal sau commit/trước cleanup, rollback giữ original/checksum và tiêu đề link khi chưa có metadata. Lượt cuối bổ sung xóa collection chứa ảnh trong Trash. Artifact: `/private/tmp/noted-phase4-all-unit-v2.xcresult`.

UI editor cơ bản đạt 1/1: tạo note, sửa tiêu đề, đóng editor, terminate/relaunch, mở lại draft và lưu. [UI summary](evidence/20261029-iphone12pro/phase4-editor-ui-summary.json); `/private/tmp/noted-phase4-editor-ui-v2.xcresult`. Test nâng cao save-error + foreground import trong editor vẫn thất bại ở locator cuộn tới trường tag; chưa kết luận hành vi import editor.

Đã sửa giữ journal khi save/refresh lỗi, fallback tiêu đề link ở thùng rác, trạng thái ghim cho accessibility, chiều cao filter tối thiểu 44pt và layout dọc actions Trash ở cỡ chữ trợ năng. Review độc lập không còn lỗi quan trọng được phát hiện. Chưa nghiệm thu foreground import khi editor đang mở. Theo yêu cầu người dùng ngày 2026-10-29, workload 500 item, VoiceOver, chữ lớn và dark mode đã bỏ khỏi phạm vi nghiệm thu; các mục này chưa được test đạt. Unit tests chỉ chứng minh draft trên đĩa không bị import ghi đè. Console unit có cảnh báo SQLite lúc teardown xóa temporary test stores đang được giữ bởi framework; không dùng kết quả này để kết luận stress/memory đã đạt.

Phase 4 UI run: bốn luồng đạt trên thiết bị (pagination/filter/order/pin, empty/add/keyboard, pending retry/discard, image fallback/share sheet/explicit link opening). Hai luồng còn mở: editor save-error/foreground import do test chưa cuộn tới tag field; restore do row được XCTest biểu diễn thành `StaticText` nên selector nút chưa tìm được. Hủy/xác nhận xóa đã tới dialog nhưng chưa có kết quả đủ để đánh dấu. Artifacts: `/private/tmp/noted-phase4-acceptance-ui-v1.xcresult` và targeted rerun `/private/tmp/noted-phase4-acceptance-ui-v2.xcresult`.

| Phạm vi | Kết quả | Bằng chứng |
|---|---|---|
| Build, ký, cài và mở app cùng Share Extension trên iPhone | Đạt | `codesign --verify --deep --strict`; App Group `group.dev.nhhai7.Noted` khớp; thiết bị đã Trust chứng chỉ và mở Noted |
| Thư viện, queue, backup, tìm kiếm và OCR | 31 unit tests đạt, 0 lỗi trên iPhone, gồm decoder caption và OCR tiếng Việt | [Kết quả unit](evidence/20261028-iphone12pro/unit-summary.json); `/private/tmp/noted-final-unit-v4.xcresult` |
| Phase 2: recovery và kiểm tra ảnh hỏng | 34 unit tests đạt trên iPhone, trong đó 11 recovery tests; ảnh không giải mã được không commit item và batch ready được giữ để xử lý | [Kết quả mới](evidence/20261028-iphone12pro/phase2-unit-summary.json); `/private/tmp/noted-phase2-all-unit-v2.xcresult` |
| Phase 2: lưu và mở lại khi offline thật | Safari báo không có Internet với URL mới; người dùng lưu 1 note, 1 link, batch 3 ảnh trong Noted và xác nhận đủ 5 mục, 3 ảnh mở được sau CoreDevice terminate/relaunch | [Bằng chứng thủ công](evidence/20261028-iphone12pro/phase2-offline-manual.json) |
| Tạo note, đóng/mở app, tìm lại | 1 UI test đạt | [Kết quả Library](evidence/20261028-iphone12pro/library-ui-summary.json); `/private/tmp/noted-library-ui.xcresult` |
| Files export rồi import lại cùng package | 1 UI test đạt, bản trùng được bỏ qua | [Kết quả Files](evidence/20261028-iphone12pro/files-roundtrip-summary.json); `/private/tmp/noted-files-roundtrip-v2.xcresult` |
| Ảnh không còn kẹt “Đang đọc ảnh…” | Đã tái hiện lỗi và 1 UI regression đạt sau sửa | [Kết quả ảnh](evidence/20261028-iphone12pro/image-regression-summary.json); `/private/tmp/noted-image-fixed.xcresult` |
| Safari → Share → Noted | Người dùng xác nhận lưu thành công trên thiết bị | Thử thủ công của người dùng trong phiên này |
| Photos → Share → Noted | Người dùng xác nhận ảnh hiện bình thường, hết “Đang đọc ảnh…” trên bản mới | Thử thủ công của người dùng trong phiên này |
| Safari chọn text → Share → Noted | Người dùng xác nhận Noted xuất hiện và text lưu đúng sau sửa activation keys | Thử thủ công của người dùng trên iPhone |
| Notes → Gửi bản sao → Noted | Noted xuất hiện nhưng chỉ lưu link mở lại Notes; không có bản sao text độc lập | [Snapshot type payload](evidence/20261028-iphone12pro/notes-provider-types.json): chỉ `public.url`, `attributedTextLength: 0`; không ghi nội dung ghi chú |
| Cài đè bản mới giữ dữ liệu | Người dùng xác nhận ảnh đã Share trước đó vẫn còn; chú thích OCR mới xuất hiện | `devicectl device install app` thành công với cùng bundle ID, app launch thành công, xác nhận thủ công sau update |
| Files export/import sau cài đè | 1 UI test đạt, 0 lỗi trên iPhone | [Kết quả sau cập nhật](evidence/20261028-iphone12pro/files-postupdate-summary.json); `/private/tmp/noted-files-postupdate.xcresult` |

Các test dữ liệu gồm retry khi gián đoạn copy/metadata, batch hỏng, ID collision, tránh nhân đôi, vòng đời trash/collection, backup checksum/path/schema/conflict và tìm kiếm tiếng Việt. `testNewContextReopensSavedTextAndLinkOffline` kiểm tra storage không cần mạng; đây không phải thử bật Airplane Mode thực trên iPhone.

Phase 2 bổ sung kiểm tra ảnh có byte hỏng trước khi commit SwiftData, fixture PNG thật cho các test import, và fault injection sau chuẩn bị file/trước cleanup nguồn. Build iPhoneOS và 34 unit tests đạt. Sau đó người dùng bật Airplane Mode, tắt Wi-Fi; Safari báo không có Internet với URL có mã mới. Người dùng lưu note, link, batch ba ảnh và xác nhận đủ sau CoreDevice terminate/relaunch. Đây là quan sát thủ công trên iPhone, không phải unit test. Hai lần `xcodebuild test` trong trạng thái offline bị iOS chặn trước test body vì bản phát triển cài đè cần tin cậy chứng chỉ; không tính là kết quả chức năng. Lỗi dung lượng thật chưa được thử.

## Sửa lỗi và kiểm chứng bổ sung

- Share image kèm text: `IncomingContentDecoder` đưa text vào caption của ảnh, tránh tạo thêm note rời. Bốn unit tests đạt trên iPhone. Review phát hiện 3 ảnh + 1 text caption bị raw-provider guard từ chối; đã cho phép 4 raw providers, kiểm tra tối đa 3 entry sau grouping, build/cài/mở lại trên iPhone. Trường hợp bốn provider thực chưa chạy E2E.
- Vision OCR: chọn đúng định danh tiếng Việt do runtime hỗ trợ (thiết bị báo `vi-VT`); fixture tiếng Việt đạt trên iPhone.
- Library: hiển thị 50 item mỗi lượt với “Xem thêm” để tránh dựng toàn bộ danh sách cùng lúc.
- UI test Share từ host app độc lập đã viết. Lần chạy đầu thất bại trước thao tác Share vì Xcode mất kết nối RemoteXPC (`CoreDeviceError 3`, sau đó `4016`). Sau khi cắm lại, iPhone từ chối cài `Noted Share Check` vì free developer profile đã có đủ ba app: Noted, XCTest runner và `com.dayward.countdown` của người dùng. Không xóa app cá nhân để vượt giới hạn. Kết quả: `/private/tmp/noted-external-share-authorized.xcresult`, `/private/tmp/noted-external-share-v2.xcresult`. Hai lần này chưa kết luận chức năng Share ảnh/text đạt hay lỗi.
- UI test Photos thêm ảnh fixture tổng hợp bằng quyền add-only rồi mở Photos. iOS 27 lộ grid qua `content_scroll_view`, đã sửa locator. Test vẫn dừng an toàn trước Share vì ảnh được chọn không qua kiểm tra OCR marker fixture; không gửi ảnh cá nhân. Kết quả: `/private/tmp/noted-photos-gate.xcresult`, `/private/tmp/noted-photos-gate-v2.xcresult`. Hai ảnh fixture được thêm vào Photos, chưa xóa vì app chỉ xin quyền thêm ảnh.
- Người dùng ban đầu không thấy Noted khi Share đoạn text được chọn từ Safari hoặc “Gửi bản sao” từ Notes. Đối chiếu [tên key activation chính thức của Apple](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/AppExtensionKeys.html) phát hiện plist dùng sai `NSExtensionSupports...` thay vì `NSExtensionActivationSupports...`. Đã sửa cả text/image/web URL; built appex plist chứa đúng ba key, app ký hợp lệ, cài đè/mở thành công. Thử lại: Safari text lưu đúng; Notes hiện Noted nhưng mục được lưu là link về Notes.

## Giới hạn nghiệm thu còn lại

- Safari text thuần đã lưu đúng qua Share; cần xác nhận nội dung còn sau relaunch. Ảnh Photos đã hiển thị bình thường, và người dùng xác nhận ảnh còn sau khi cài đè/mở lại app; chưa có tự động hóa cho payload Photos. Notes “Gửi bản sao” chỉ cung cấp `public.url` trong lần đo, nên không thể lấy bản text từ payload đó; dùng Sao chép → Dán nội dung trong app để giữ nội dung offline.
- Đã thử Airplane Mode/Wi-Fi off với lưu trong app và một batch ba ảnh qua PhotosPicker; ba ảnh còn mở được sau relaunch. Chưa thử ba ảnh trong một lần Share từ Photos, ảnh nguồn bị xóa, hoặc kiểm tra checksum của ảnh sau relaunch.
- Kiểm chứng Library/detail/tổ chức, vùng chạm và bàn phím ở cấu hình mặc định; foreground import khi editor đang mở. Workload 500 item, VoiceOver, chữ lớn và dark mode không còn là điều kiện nghiệm thu theo yêu cầu người dùng ngày 2026-10-29.
- Thử các trạng thái lỗi thực tế của URL preview, export bị gián đoạn và capture tới khi đang export. Policy URL chặn địa chỉ private theo DNS resolve trước request, chưa pin kết quả resolve cho toàn phiên tải.
- Backup v1 từ chối schema mới; chưa có migration vì chưa phát hành schema v2. Backup hiện không mã hóa; chọn nơi lưu phù hợp trong Files.

Người dùng quan sát OCR của ảnh có thể nhận `@` thành `&`. Đây là lỗi nhận diện ký tự từ ảnh, không phải sai payload Share text: ảnh gốc vẫn hiển thị đúng. Giao diện detail đã thêm giải thích OCR có thể sai và có thể thêm từ khóa vào ghi chú ảnh để tìm lại. Bản mới đã `BUILD SUCCEEDED` cho iPhoneOS, qua `codesign --verify --deep --strict`, cài đè và mở thành công trên iPhone; người dùng thấy chú thích mới và ảnh cũ. Share text thuần từ Safari đã được xác minh đúng. Chẩn đoán tạm trên iPhone cho Notes chỉ có `public.url`, không có `attributedContentText`; mã chẩn đoán đã gỡ khỏi source, bản sạch đã build/ký, cài đè và mở thành công trên iPhone.

Code review cuối không còn phát hiện Critical/Important đã xác nhận sau các sửa về ID collision và backup conflict. Phần chưa chạy được ghi là chưa kiểm chứng, không quy về lỗi sản phẩm.

## Tiếp tục phase 3 — 2026-10-29

Share Extension đã có preview tóm tắt loại nội dung, số ảnh và caption trước khi lưu. Payload quá giới hạn hoặc không hỗ trợ được báo trước và nút Lưu bị vô hiệu. Lệnh build iOS `xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/noted-phase3-tester-derived CODE_SIGNING_ALLOWED=NO build` đạt sau thay đổi cuối; log lần build đầu: `/private/tmp/noted-phase3-tester-build.log`. Build trong sandbox riêng thất bại ở Swift macro plugin server, không phải lỗi biên dịch source. Lúc kiểm tra đầu tiên iPhone 12 Pro không khả dụng qua `devicectl`; diễn biến sau khi kết nối lại ghi dưới đây.

Sau khi iPhone 12 Pro kết nối lại, `xcodebuild` đã ký/cài đè bản mới cùng bundle ID và 4/4 `IncomingContentTests` đạt trên thiết bị thật, không bỏ qua test nào ([result bundle](/private/tmp/noted-phase3-incoming-20261029.xcresult)). `codesign --verify --deep --strict` đạt, extension có App Group `group.dev.nhhai7.Noted`. Lần chạy UI test Share text đầu tiên dừng trước test body vì timeout bật Automation Mode (`/private/tmp/noted-phase3-share-text-20261029.xcresult`); sau khi người dùng bật, Xcode không thấy iPhone trong lần chạy lại vì kết nối chuyển sang `unavailable`. Hai lỗi hạ tầng này không chứng minh Share text đạt hay lỗi. Các acceptance trên Photos, text relaunch và thời gian vẫn mở.

Sau khi kết nối ổn định lại, UI test Safari URL Share đạt (`/private/tmp/noted-phase3-safari-url-retry2-20261029.xcresult`) và UI test Photos Share một ảnh mẫu đạt (`/private/tmp/noted-phase3-photos-one-retry2-20261029.xcresult`) trên iPhone 12 Pro, mỗi bundle 1/1 đạt. Photos test kiểm tra marker “NOTED DEVICE GATE” bằng OCR trước khi chạm Share; không chọn ảnh cá nhân. Locator iOS 27 phải vuốt hàng app bằng tọa độ và chọn đúng cell Thêm. Share text từ chính Noted không thấy extension của mình trong picker; host app độc lập không cài được vì free developer profile đã đủ ba app (Noted, UI test runner và app cá nhân). Lần chạy thêm assertion preview/URL duy nhất dừng vì RemoteXPC mất kết nối với UI runner trước khi test hoàn tất (`/private/tmp/noted-phase3-safari-url-preview-20261029.xcresult`), nên chưa tính là pass.

Người dùng xác nhận thủ công trên iPhone 12 Pro ngày 2026-10-29: Share cùng lúc ba ảnh mẫu tím; cả ba ảnh vẫn mở được trong Noted sau khi xóa ảnh nguồn trong Photos; Safari Share text giữ nguyên sau khi đóng/mở lại Noted. Chưa đo số lần chạm hoặc thời gian.

## 2026-11-02 — Phase 05 UI/UX theo Design Lab trên iPhone 12 Pro

Thiết bị vật lý iPhone 12 Pro, iOS 27.0.1, UDID `00008101-001A2519266B001E`, kết nối dây, Developer Mode bật. Bundle ID `dev.nhhai7.Noted`. Build iPhoneOS cuối đạt (`/private/tmp/noted-ui-phase5-release-build.log`), codesign app và Share extension đạt; đã cài đè cùng ID, không gỡ app, mở lại thành công. Trước cài có 17 mục cá nhân gồm ảnh, link và ghi chú; sau lần cài đầu vẫn thấy 17 mục cũ. Hai ca Share thật đã thêm 5 mục thử nên ảnh sau cài bản cuối có 22 mục. Ảnh trước/sau, Home icon và màn UI nằm tại [báo cáo thiết bị](evidence/20261102-iphone12pro/ui-redesign-summary.md).

Bộ UI acceptance cuối trên iPhone: **9/9 đạt** (`/private/tmp/noted-ui-phase5-final-ui-2.xcresult`), gồm Home icon, Library/Search/Collections, detail/editor, Capture note/link/ảnh, ghim sau lưu, keyboard/draft, phân trang/lọc, lỗi import và Trash. Safari/Photos Share preview từ app nguồn thật: **2/2 đạt** (`/private/tmp/noted-ui-phase5-share-preview.xcresult`); preview được kiểm tra trước khi lưu. Backup Files xuất vào “Trên iPhone” rồi nhập lại: **1/1 đạt** (`/private/tmp/noted-ui-phase5-backup-final.xcresult`), mục có sẵn không bị nhân đôi. Ca phân trang cuối riêng đạt (`/private/tmp/noted-ui-phase5-pagination-final.xcresult`); nút “Xem thêm” nhìn thấy và nhận chạm trên máy mặc dù XCTest báo `isHittable = false`, nên test dùng vị trí nút đang hiển thị để chạm và xác nhận kết quả sau chạm.

42/42 unit tests đạt với source cuối (`/private/tmp/noted-ui-phase5-final-unit-2.xcresult`). Review mã phát hiện đường thoát chưa rõ khi lưu thành công nhưng ghim lỗi; nút thông báo đã đổi thành “Về Thư viện”. VoiceOver/dark mode toàn diện và phép đo pixel 98–100% so với HTML Design Lab chưa thực hiện. UI dùng status bar, sheet, Files/Photos picker native và dữ liệu thật, khác preview mẫu. Các lỗi CoreDevice/Automation Mode trước test body ở lượt đầu là hạ tầng, đã chạy lại các ca sau khi phiên thiết bị ổn định.

## 2026-11-05 — Đọc hiểu link, Phase 03 (kho `LinkDigest` & runner) trên iPhone 12 Pro

Thiết bị: iPhone 12 Pro, iOS 27.0.1, kết nối dây. App cài đè bằng `xcodebuild ... -allowProvisioningUpdates test`, cùng bundle ID, không gỡ app.

- `xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<UDID>' -allowProvisioningUpdates test -only-testing:NotedTests/LinkDigestPipelineTests`: **21/21 đạt**. Các dòng `CoreData: error ... (259)` trong log là của test store hỏng, đúng kỳ vọng.
- Toàn bộ `-only-testing:NotedTests`: **109 test, 0 lỗi**, 2 test opt-in của E5 bị bỏ qua như trước.
- Dữ liệu thật (chỉ đếm trạng thái, không đọc hay lưu nội dung; bản copy tạm đã xóa):
  - thư viện có 22 link đang dùng và 2 link trong thùng rác;
  - lần chạy đầu bị cắt khi test kết thúc, để lại 1 digest `running`. Mở lại app thì digest đó được phục hồi và đọc tiếp, kết quả **21 `complete` + 1 `titleOnly`** (iCloud Notes), mỗi link 1 lượt, không có `loginWall`/`unreachable`. Link trong thùng rác không được đọc;
  - rebuild: ghi đè `Intelligence/schema-version.txt` bằng `0` (`devicectl` không xóa được file), rồi mở app. Store cũ được đặt sang `intelligence.store.corrupt*` (còn đủ 22 bản ghi), store mới rebuild **22/22 trong 14,6 s** (21 `complete` + 1 `titleOnly`), `schema-version.txt` được ghi lại là `1`;
  - `library.store` trước và sau rebuild: không trường nào ngoài tiêu đề thay đổi (body, URL, `updatedAt`, pin, trash, trạng thái OCR/preview, `userEditedTitle`, tag), và không tiêu đề nào đổi.
- Chưa kiểm chứng trên máy: snapshot `library.store` **trước** lần chạy digest đầu tiên (tiêu đề link đã được thay ngay lúc app host khởi động trong phiên test). Quy tắc chỉ thay tiêu đề host/`<title>` thô và không đụng tiêu đề người dùng đã sửa được kiểm bằng unit test. Chưa thử offline/Low Data Mode trên máy thật.

## 2026-11-05 — Đọc hiểu link, Phase 04 (UI & evaluator)

Đã nối LinkDigest tới thẻ giấy, Detail (nguồn/ngày đọc/đọc lại/login wall), sheet gán nhãn DEBUG và input evaluator. Report JSON v4 có coverage digest và precision/coverage theo nhóm link complete/loginWall. Không sửa stored schema hoặc backup.

- `xcodebuild ... -scheme Noted ... CODE_SIGNING_ALLOWED=NO build`: **đạt** trên source cuối. Lượt sandbox đầu không chạy được SwiftData macro; build ngoài sandbox đạt.
- `xcodebuild ... -scheme Noted ... -only-testing:NotedTests/LinkDigestPipelineTests -only-testing:NotedTests/IntelligenceEngineTests`: **38 test, 0 lỗi, 2 skip opt-in** của E5/resource report.
- Chạy lại source cuối: `LinkDigestPipelineTests` + `IntelligenceEngineTests/testReportSchemaV4CarriesResourceFieldsWithoutLabels`: **24 test, 0 lỗi, 0 skip**.
- `xcodebuild ... -scheme Noted-DeviceGate ... -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:NotedUITests/IntelligenceLabelingUITests test`: **4/4 đạt trên iPhone 12 Pro**. Có ca riêng kiểm tra complete/login wall, summary trong sheet và Dynamic Type accessibility XXXL. Test cũ được sửa để chờ computation rồi cuộn đến hàng xuất report trong lazy Form; không bỏ assertion. Các lượt thất bại ban đầu và diagnostics bị kẹt được ghi trong evidence.
- `git diff --check`: đạt; tự review diff và đường truyền environment/fingerprint/retry/snapshots.

[Evidence, lệnh đầy đủ và ảnh tổng hợp](evidence/20261105-link-phase4/summary.md). Chưa nghe VoiceOver thủ công hoặc nghiệm thu dark mode đầy đủ; todo VoiceOver của phase giữ mở. Không xuất screenshot/nội dung cá nhân vào repo. Search trong summary là tùy chọn chưa làm; nghiệm thu chất lượng link thật và đánh giá lại chủ đề thuộc Phase 06.


## 2026-11-05 — Link Phase 05: API Groq text-only tùy chọn

Đã triển khai client/Keychain, toggle mặc định tắt có consent, payload preview ≤2.000 ký tự không kèm URL đầy đủ, runner fallback và hạn mức chung 50 request/ngày. Bật áp dụng cho link mới hoặc đọc lại; tắt hủy tác vụ cloud. Không đổi schema hoặc dữ liệu gốc. Các sửa đổi Phase 04 có trước phiên được giữ nguyên.

- `ruby scripts/update-project.rb`: đạt; nguồn mới vào target.
- `xcodebuild ... -destination 'generic/platform=iOS' ... CODE_SIGNING_ALLOWED=NO build`: **đạt**, cũng kiểm chứng Swift type-check. Lượt sandbox đầu không chạy được macro; cùng lệnh ngoài sandbox đạt.
- `xcodebuild ... -only-testing:NotedTests/RemoteLinkDigesterTests -only-testing:NotedTests/LinkDigestPipelineTests -only-testing:NotedTests/LinkDigestTests -only-testing:NotedTests/BackupRoundTripTests test`: **61/61 đạt trên iPhone**, không skip; có 14 test remote mới, URLProtocol giả, Keychain thật với service riêng và khóa tổng hợp, kiểm tra package backup.
- `xcodebuild ... -scheme Noted-DeviceGate ... -only-testing:NotedUITests/RemoteAISettingsUITests test`: **1/1 đạt trên iPhone**, chỉ fixture tổng hợp; xác nhận mặc định tắt, hủy consent, bật và tắt. Lượt đầu lỗi locator; lượt kế phát hiện confirmationDialog iOS 27 ẩn nút Hủy; đã sửa bằng alert và retest đạt.
- `git diff --check`: đạt; đã tự rà diff/call path. Warning còn lại: AppIntents metadata; clean build có warning có sẵn của Share/AccentColor.

Không gọi Groq thật hoặc kiểm chứng chất lượng tiếng Việt; chưa đánh giá API tốt hơn trên đa số link. Không chạy toàn bộ suite/Share Safari/Photos hoặc nghiệm thu VoiceOver thủ công. Phase giữ **Implemented, chờ quality gate**, không ghi Done. [Lệnh đầy đủ, kết quả và screenshot](evidence/20261105-link-phase5/summary.md), [điều khoản nhà cung cấp](intelligence-evaluation.md#link-phase-05--nhà-cung-cấp-api-tùy-chọn-2026-11-05).
