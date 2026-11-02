# Paper pinboard — Phase 04–06 retest and fixes (2026-11-03)

Dedicated simulator `Claude Test iPhone 12 Pro` (iOS 18.6, `397BDEFA-B67E-4FEB-B14F-EB681B6CAC64`), Debug, command-line overrides `SUPPORTED_PLATFORMS='iphoneos iphonesimulator' SDKROOT=iphonesimulator`, ad-hoc signing, `-parallel-testing-enabled NO`. Project settings unchanged.

## Root cause of "Test crashed with signal kill"

Two sessions ran `xcodebuild test` on the same simulator (`Noted iPhone 12 Pro`) at the same time (observed 2026-11-02 23:13: a second `xcodebuild … -resultBundlePath /tmp/noted-phase5-retest.xcresult` started mid-run). Each run reinstalls/terminates the app and runner, killing the other's runner. On a dedicated simulator the full selected suites ran with **zero** runner restarts. Run UI tests on one simulator per session.

## Fixes

| Area | Change | Why |
|---|---|---|
| `NotedUITests/PhaseFourAcceptanceUITests.swift` | `reachable()` guard (on-screen centre, not under keyboard) before `isHittable`; keyboard dismissal in `revealEditor`; wait for trash confirmation and detail close; pin switch: tap the knob and wait for value `1` | On the simulator `isHittable` throws for off-screen pills; the software keyboard covers editor rows; tapping during the sheet animation dismissed it without trashing; switch value is number or string by runtime. Same 4 failures reproduced on the pre-paper baseline `9c56135`, so they were not Phase 04 regressions. |
| `Noted/App/LibraryLifecycleView.swift` | Keyboard-dismiss recognizer: `delaysTouchesEnded = false`, dismiss on next run loop | With the keyboard open, the first tap on a SwiftUI control (pin Toggle) was lost because dismissal reflowed the layout before touch-end. Probe: value 0 → 1 on first tap after fix. |
| `Shared/PaperAssets…/PaperGrain.png`, `scripts/ui-fidelity/make-grain.sh`, `PaperBackground` | Neutral 50% grey tile (sd ≈ 13/255), soft-light blend (page/card 0.35, hero 1.0) | Old tile (65% grey, sd ≈ 1) with multiply/screen only tinted surfaces: hero measured mean 79 / sd 0.07 vs mock 63 / 6.4. Now hero 60 / 4.1 and token colours preserved. |
| Library hero / rhythm (`LibraryView.swift`) | 111 pt hero, one-line 19 pt title, bulb overlay 76 pt; 12.5 pt header→pills, 14 pt pills→cards, top inset −8 pt | Measured against v3 reference. |
| Cards (`ItemCard.swift`) | Icon 24 pt (stroke 3), title 15.5/13 pt, excerpt 12.5 pt, title at ~46 pt, domain then ↗ | v3 text metrics (~26 chars/line). |
| Collections (`CollectionsView.swift`, folder SVGs) | 66 pt folder art, stroke 3, filled heart, 28 pt gap, 72×20 tab at −15 pt, row pitch 125.5 pt | Tab rows measured in v3 at 179.7/305.3/430.3/556.7 pt. |
| Tokens | hero `#274337` → `#284739` (heroText 10.07:1, heroMuted 6.84:1) | Balances both v3 hero probes (ΔE 2.32 / 1.94). |
| `PaperCard` curl | 22 → 30 pt | v3 curl is clearly visible. |

## Results

- Unit (scheme Noted): **46/46 passed**.
- UI (PaperComponents 6, MockFidelity 5, Library 3, PhaseFourAcceptance 9): **23/23 passed**, 0 runner restarts.
- Colour probes (ΔE2000 ≤ 3, 5×5 mean): Library **16/16** (was 11/16), Collections **17/17** (was 15/17). [Library](side-by-side-library.jpg) · [Collections](side-by-side-collections.jpg) · reports `report-*.json`.
- Non-mock screens (Search, collection detail, note detail, editor, Trash, Backup): [strip](non-mock-screens.jpg) — consistent, no clipping.

## Not established

- Weighted checklist score ≥ 98 % (Phase 08 gate). Probes are supporting evidence only. Known residual differences: link title "Sống chậm một chút" wraps to two lines; excerpt line breaks differ slightly; bulb vs note icon on the honey card and alphabetical collection order are approved deviations.
- Capture screen (6/16 probes) belongs to Phase 07, not started.
- Device-only share tests (PhaseOne, ExternalShare, PhotosGate) not run: they need Safari/Photos/GateHost on a physical iPhone. No physical-iPhone acceptance in this pass.
