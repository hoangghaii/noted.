# Paper pinboard — Phase 04

2026-11-02. Shared components and tab bar, plus minimal filter/capture integration for layout acceptance. No schema, backup, Share payload or personal-data changes.

## Changes

- `Shared/NotedPaperUI.swift` is a source member of both app and Share Extension. Includes button roles (soft/prominent), equal-width scrolling groups, pills, circle icon buttons, paper cards/curls, labeled fields, tag chips and a SwiftUI preview. Uses Phase 02's PaperBackground and tone tokens.
- Library shows four equal-width filters before horizontal scrolling. Capture uses three equal-width buttons with captureMode_note/link/photo identifiers. Existing UI tests migrated deliberately from segmented controls; libraryFilters remains on the scrolling element. Focus is explicitly cleared when changing capture modes.
- Tab bar uses document/search/stack symbols, 24 pt icons, 12 pt labels, bar background without a hairline. Tab identifiers and selection traits preserved.
- Existing unrelated changes from Phases 01–03 preserved. Remaining screen restyling belongs to Phases 05–07.

## Verification

- Final Debug iPhoneOS build-for-testing passed, including app, Share Extension, GateHost and UI test sources. Unsigned compile check: `/private/tmp/noted-phase4-build-final.log`.
- Simulator runtime: **5/5 tests passed, 0 failures** on iPhone 12 Pro / iOS 18.6. Four PaperComponentsUITests verify first four library widths, three capture widths, gaps (8 pt ±1), viewport fill (±1), minimum 44 pt hit height, scrolling to pinned, selection and tabs at normal/XXXL sizes. Existing `testEmptyLibraryAndAddNoteWithKeyboard` passed mode-change keyboard dismissal, save and relaunch persistence on isolated fixtures. Result: `/private/tmp/noted-phase4-sim-final.xcresult`; log: `/private/tmp/noted-phase4-sim-final.log`.
- Screenshots exported alongside this report and inspected: no Vietnamese label truncation for Ghi chú/Đã ghim at XXXL; equal pill groups and updated tab bar render correctly. Full mock fidelity is not claimed; other screen changes belong to later phases.
- Runtime exposed inherited group IDs overwriting pill IDs; explicit accessibility containers fixed this, then the full selected five-test run passed.
- `git diff --check`: passed.
- Independent static review: all three findings addressed (scroll identifier, capture focus and XXXL pinned-pill coverage); no unresolved code finding.
- Initial sandbox build could not execute Swift macro plugins; rerun outside sandbox succeeded.
- Physical iPhone unavailable: `devicectl list devices` showed only the booted simulated iPhone 12 Pro. No uninstall or personal container reset performed.
- Simulator test launch required explicit `-sdk iphonesimulator SUPPORTED_PLATFORMS=iphonesimulator` and local ad-hoc signing because project defaults target physical devices. These are command-line overrides; project signing configuration was preserved.

## Pending

Physical tab-bar comparison to the reference probe, curl/card visual acceptance and scrolling performance remain pending. Component availability does not imply every screen has adopted them.
