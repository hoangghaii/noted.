# Paper pinboard — Phase 05

2026-11-02. Implemented Library and Search on iPhone 12 Pro simulator / iOS 18.6. Existing work from previous phases preserved. No schema, Share payload or backup format changes.

## Changes

- Library options use the chip circle style. Hero removes eyebrow, adds sketch bulb and paper grain. Filters show All / Inbox / Images / Links, with Notes and Pinned reachable horizontally.
- Shared `ItemCardGrid` uses lazy rows with equal-height cards and switches to one column at accessibility Dynamic Type sizes. Existing 50-item pagination retained.
- Note/photo/link cards use deterministic tones/curls, multiline bounded excerpts with bullet conversion, edge-to-edge 120 pt photos, absolute Vietnamese dates and pinned labels.
- Each card menu overlays outside its navigation label, has a 44 pt target, supports pin/unpin and trash, and surfaces mutation errors.
- Search uses PaperField and equal-width pills for kind/time/collection, retains debounce and uses the same card rows and menus.
- Added UI coverage for equal row heights, date, menu actions without navigation, trash exclusion in search, search filters and detail navigation. Updated first-four filter expectations.

## Verification

- Simulator Debug build: passed (`/tmp/noted-phase5-build.log`).
- Unit suite: **45 tests, zero failures** (`/tmp/noted-phase5-unit.xcresult`, `/tmp/noted-phase5-unit.log`).
- UI results are mixed because the test runner intermittently exits with **Test crashed with signal kill**; no single completely green selected suite is claimed.
- First run `/tmp/noted-phase5-tests.xcresult`: 3 passed / 5 killed. Passed menu/date/equal-height/trash-search test, large filter widths and large capture widths.
- Sequential rerun `/tmp/noted-phase5-retest.xcresult`: 6 passed / 2 killed. Passed mock Library, capture widths normal/large, library filter widths/tabs, search filters/detail, and pagination/filter/order/pin after relaunch (48.898 seconds).
- Final targeted run `/tmp/noted-phase5-final.xcresult`: 2 passed / 1 killed. Large filter widths and search filters/detail passed; menu test runner killed (the same test passed in the first run). Retry flags did not recover runner termination. These failures remain visible.
- All eight distinct selected scenarios have a successful run across these executions; this does not establish suite stability. No UI assertion failure was reported; killed runs remain failures.
- Independent static review: no blocking finding. `git diff --check`: passed.
- Screenshots inspected: [Library](library-simulator.png), [Search](search-simulator.png). App left running with isolated mock fixture on the simulator.

## Fidelity remains open

`compare.sh` completed; [report](comparison/report.json), [side-by-side](comparison/side-by-side.png). 11/16 color probes pass; positions, hero grain color and card geometry still differ from reference. Probe ratio and SSIM are not the weighted checklist score. Do not claim ≥98% or physical-device acceptance. Those acceptance gates remain pending in Phase 05/08.
