# Paper pinboard — Phase 06

2026-11-02. Implemented and tested on Noted iPhone 12 Pro simulator, iOS 18.6 (`7D44052B-6FFC-4464-82CA-2769CEF28163`). No schema, Share payload or backup format changes. Earlier uncommitted work preserved.

## Changes

- Collections: new subtitle, circular options menu for Backup/Trash, full-width sage create capsule, cream/sage paper folder rows with honey tabs, name/count and sketch motifs. Store name ordering, context menus, IDs and alerts retained.
- Folder motifs match Vietnamese names after case/diacritic folding; unknown names use stable UUID hashing. Unit coverage includes the four mock names and fallback vectors.
- Detail, editor, Trash and Backup use paper backgrounds and shared fields/chips/capsule/circle controls; editor draft/error/save and all IDs retained.
- Fixed the window keyboard-dismiss observer to skip native alerts and UIControl ancestors. Evidence showed the original observer dismissed the keyboard/repositioned the alert on the first Create tap, leaving the alert open and no new fixture collection; final test creates/renames with one action tap.
- Trash regression now waits for the second confirmation sheet to close and the Library options to reappear before opening Trash.

## Verification

- Simulator build succeeded with `-sdk iphonesimulator`, `SUPPORTED_PLATFORMS=iphonesimulator`, ad-hoc signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`).
- Unit suite: **46 tests, zero failures**. `/tmp/noted-phase6-unit.xcresult`, `/tmp/noted-phase6-unit-sim.log`.
- Final selected UI suite: **4 tests, zero failures**, 154.235 seconds. `/tmp/noted-phase6-final.xcresult`, `/tmp/noted-phase6-final.log`.
- UI coverage: fixture Collections; create/open/rename/delete and Backup/Trash menu navigation; editor save failure/draft retention/foreground import; Trash restore/cancel/permanent delete/relaunch.
- Earlier initial command used the project-default device SDK and failed to launch on simulator; corrected SDK/signing for all verification above. Initial UI run exposed the alert observer and missing second Trash transition wait; final suite passes after the targeted fixes.
- Independent static review: no blocking finding, including observer fix. `git diff --check` passed.
- App left running with isolated Collections mock fixture on the simulator. Personal data was not used by the UI acceptance tests.

## Visual evidence and remaining acceptance

- [Collections](collections-simulator.png), [Editor](editor-simulator.png), [Trash confirmation](trash-confirmation.png).
- [Comparison report](comparison/report.json), [side by side](comparison/side-by-side.png). Analysis completed: **15/17 color probes** within ΔE2000 ≤3. Two tab samples miss their reference coordinates; tab offset/shape and sketch artwork still differ from raster mock.
- This probe count and SSIM are supporting measurements, **not the weighted checklist score**. Font/icon/geometry checklist ≥98% and 100% critical criteria are not established. Fidelity acceptance remains open for Phase 06/08; this phase is not marked fully complete.
- Alphabetical ordering intentionally differs from the mock, per the approved plan. Simulator verification does not replace Phase 08 physical-device acceptance.
