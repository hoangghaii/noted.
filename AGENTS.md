<!-- agentkit:begin -->
<!-- Managed by AgentKit Engineer. Put project-specific instructions outside this block; edits inside are kept but stop receiving AgentKit updates. -->
# AgentKit Engineer

## How to work

- Small, well-understood change: do it directly. Larger work: state the acceptance criteria first, then plan → implement → test → review.
- Respect the requested stage. Brainstorm compares options, plan writes plans, debug diagnoses, test runs checks, review reports findings. None of these edit application code unless the user also asked for a fix or implementation.
- Delegate only independent, substantial work: `scout` to locate code, `researcher` for external facts, `planner`, `tester`, `code-reviewer`, `debugger`. Give each one the objective, paths, constraints and expected output. Without delegation, do the same stages yourself.
- Load only the skills the task needs. Skill resources and scripts resolve relative to the installed skill directory, not the shell directory. Check the version the project actually uses before applying a bundled API example.

## Workflows

Invoke `kit-plan`, `kit-implement`, `kit-debug`, `kit-fix`, `kit-test` and `kit-review` (Codex `$kit-plan`, Claude `/kit-plan` or the installed aliases). Use `kit-tdd` only when TDD is selected and the quality pack is installed.

Plans live in `plans/YYYYMMDD-HHmm-<topic>/`: a `plan.md` overview plus one `phase-NN-<name>.md` per phase, unless the user wants the plan inline. When executing a plan, read the overview and the current phase only. Tick todos and update statuses only after their acceptance checks pass. Workflow details are in `.agentkit/workflows/`.

## Before saying "done"

1. Run the project's real test, type-check and build commands for what you changed, and read the output.
2. Report each command and its result. Say explicitly which checks failed, were skipped or could not run. Never present a skipped check as passing.
3. Review your own diff for unrelated changes, debugging leftovers and secrets.
4. Hand off: changed paths, checks run, remaining risks.

Preserve existing project instructions, user edits, configuration and public APIs. Never silence errors with `any`, broad casts, skipped tests or suppression comments. Commit, push, publish or deploy only when the user asks.

## Principles

YAGNI: build only what is required now. KISS: choose the simplest solution that works. DRY: keep one source of truth, but do not abstract prematurely.
<!-- agentkit:end -->

# Noted — hướng dẫn riêng của project

App SwiftUI + SwiftData cá nhân, **chỉ cho iPhone** (deployment target iOS 27.0, `SUPPORTED_PLATFORMS = iphoneos`, Swift 5). Không backend, không tài khoản, không dịch vụ AI bên ngoài mặc định. Tài liệu, plan và báo cáo viết bằng tiếng Việt.

## Cấu hình & build

- Bundle ID, App Group và team lấy từ `.env` → chạy `python3 scripts/configure-env.py` để sinh `Config/Local.xcconfig` (được `Config/Defaults.xcconfig` include). Cả hai bị Git ignore. Không hard-code ID trong source/script; không đổi bundle ID/App Group, không uninstall app hay xóa container để sửa lỗi signing (mất dữ liệu thật của người dùng).
- Project dùng file reference thường (không phải synchronized folder): **file `.swift` mới phải được thêm vào target** bằng `ruby scripts/update-project.rb` (cần gem `xcodeproj`; file trong `Shared/` được thêm vào cả `Noted` và `NotedShare`). `scripts/generate-project.rb` chỉ dùng lần đầu, từ chối ghi đè.
- Build kiểm tra biên dịch (không cần thiết bị):
  `xcodebuild -project Noted.xcodeproj -scheme Noted -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/noted-derived CODE_SIGNING_ALLOWED=NO build`
- Build/test trên iPhone thật (lấy UDID bằng `xcrun devicectl list devices`):
  `xcodebuild -project Noted.xcodeproj -scheme Noted -destination 'platform=iOS,id=<UDID>' -allowProvisioningUpdates test`
  Một class/test: thêm `-only-testing:NotedTests/LinkDigestTests` (hoặc `.../LinkDigestTests/testName`).
- Simulator chỉ là phương án phụ, phải ghi đè `SUPPORTED_PLATFORMS='iphoneos iphonesimulator'` và giữ ký ad-hoc (`CODE_SIGN_IDENTITY=-`), vì `CODE_SIGNING_ALLOWED=NO` làm mất App Group entitlement. Lệnh đầy đủ ở `docs/device-setup.md`. UI test trên simulator: một simulator riêng mỗi phiên + `-parallel-testing-enabled NO`.
- Python tooling: `python3 -B scripts/ui-fidelity/test_compare.py`; `cd scripts/topic-model-evaluation && python3 -m unittest test_compare_vectors` (export model E5 cần venv Python 3.11 riêng, xem README của thư mục đó; output model để ở `/tmp`, không commit).

## Schemes & targets

- `Noted` (app) + `NotedShare` (Share Extension) dùng chung App Group. Scheme **Noted** chạy `NotedTests` (unit/integration dữ liệu).
- Scheme **Noted-DeviceGate** chạy `NotedUITests`; cần người dùng bật Enable UI Automation trên máy. Locator Safari/Photos phụ thuộc UI iOS — chỉ chạy đúng test được yêu cầu, không chạy cả bộ rồi coi là E2E. `NotedGateHost` là app nguồn tổng hợp chỉ để kiểm chứng Share, không thuộc app.
- Màn DEBUG được bật bằng launch argument trong `NotedApp.swift` (`--device-gate-fixtures`, `--e5-load-probe`); các fixture (`*Fixtures.swift`, `IntelligenceLabelingView`) chỉ có trong DEBUG.

## Kiến trúc

- **Luồng capture:** `NotedShare/ShareViewController` decode nội dung (`Shared/IncomingContentDecoder`) và ghi batch vào `ShareGate` trong shared container (`Shared/ShareGateStore`). Khi mở app, `LibraryStore` nhập batch qua `CaptureImporter`: copy originals (`AttachmentStore`, có checksum) → commit SwiftData + receipt `ProcessedBatch` → mới cleanup batch nguồn. Thứ tự này đảm bảo không mất/nhân đôi khi crash; test dùng các `*FaultPoint` + fault injector để kiểm tra từng bước. Giữ nguyên tên queue/format manifest cũ để đọc được dữ liệu đã lưu.
- **`LibraryStore`** (`@MainActor @Observable`) là single writer cho thư viện: CRUD, tag/collection, trash, khóa `isDataOperationInProgress` cho backup.
- **Hai store tách biệt:**
  - `library.store` (`ModelStore`, `NotedSchemaV1`: `Item`, `Attachment`, `ItemCollection`, `ProcessedBatch`) — dữ liệu gốc. Không bao giờ xóa/tạo lại store hỏng; marker schema lạ bị từ chối. **Không đổi schema** khi chưa có plan migration + snapshot.
  - `intelligence.store` (`IntelligenceStore`, `IntelligenceSchemaV1`, hiện có `LinkDigest`) — dữ liệu dẫn xuất, rebuild được: store hỏng/lệch version bị đặt sang `intelligence.store.corrupt*` và tạo mới. Không đưa vào backup. Tính năng AI mới thêm entity vào đây, không vào `library.store`.
- **Enrichment:** `EnrichmentRunner` chạy OCR (Apple Vision, `OCRService`) và link preview (`LinkMetadataService`). Mọi request mạng phải qua `PublicURLPolicy` + `BoundedMetadataDownload` (chặn URL không public, giới hạn kích thước). `Core/Digest` (`HTMLTokenizer` → `LinkPageParser` → `ExtractiveLinkDigester`, `LinkDigestRunner`) tạo bản đọc hiểu link; trang đòi đăng nhập ghi `loginWall`, không bịa tóm tắt.
- **Intelligence (spike):** `TextEmbeddingEngine` với `CoreMLEmbeddingEngine` (multilingual-e5-small, tokenizer native `XLMRobertaTokenizer` phải khớp token ID với Python) và `KeywordBaseline`. Dùng `.cpuAndNeuralEngine` — các compute unit khác OOM hoặc ra NaN trên iPhone 12 Pro. Test parity tự skip khi chưa copy model vào app container.
- **Search:** `SearchService` hỗ trợ tiếng Việt có/không dấu, gồm cả text OCR.
- **Backup:** `BackupService`/`BackupManifest` xuất/nhập `.notedbackup` qua Files, chưa mã hóa, gồm thùng rác; xung đột thì giữ cả hai bản.
- **UI:** `Features/*` theo màn hình; design system "paper" dùng chung app/extension nằm trong `Shared/NotedDesign.swift`, `Shared/NotedPaperUI.swift`, `Shared/PaperAssets.xcassets`. Spec ở `docs/design-guideline.md` và `docs/design-preview/`; so sánh screenshot bằng `scripts/ui-fidelity/compare.sh`.

## Kiểm chứng & tài liệu

- Build thành công ≠ test đã chạy ≠ nghiệm thu trên iPhone. Ghi rõ cái nào chưa chạy (thường do iPhone không kết nối, chưa bật UI Automation, profile hết hạn hoặc chạm giới hạn 3 app của Personal Team).
- Kết quả kiểm chứng ghi vào `docs/verification.md`, bằng chứng vào `docs/evidence/<YYYYMMDD>-<topic>/`; kết quả đánh giá AI vào `docs/intelligence-evaluation.md`. Không commit nội dung cá nhân của người dùng (text, ảnh, link thật) làm fixture — dùng corpus tổng hợp.
