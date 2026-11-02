# Phase 03 — Pinboard app icon

2026-11-02. User-selected source: `docs/design-preview/icon-concepts/noted-pinboard-selected.png` (1254×1254).

- Previous Folded N asset backed up to `docs/design-preview/icon-concepts/noted-folded-n-backup.png`; bytes match the original asset in Git HEAD.
- `scripts/ui-fidelity/make-icon.sh` crops 1108×1108 at +74+73, flood-fills only the connected exterior cream through a temporary border, flattens onto #2A4A3A and resizes with Lanczos to opaque 8-bit RGB/sRGB 1024×1024. Catalog metadata unchanged.
- Asset SHA256: `337c58cbd3c58d09306d8508c22f80315c4e2e956e420d50613f22dc33fae9bc`; fresh reproduction matches exactly.
- `magick identify`: srgb, 3 channels, opaque True, 1024×1024. Inspected full asset and 60 px preview; “Noted.” remains readable. Four previews use a rounded-rectangle mask approximating iOS (22.4% radius): `icon-mask-{1024,180,120,60}.png`.
- Signed Debug build passed: `/private/tmp/noted-paper-phase3-build-final.log`. No AppIcon warning/error. Existing unrelated `AccentColor` missing warning remains.
- Installed over existing app on physical iPhone 12 Pro `00008101-001A2519266B001E`: bundle ID `dev.nguyenhoanghai861.Noted`. No uninstall or data-container clearing.
- Home Screen capture pending: iPhone was actively in a game; did not switch its foreground app. No screenshot of unrelated personal activity was saved to the repository.

Independent review: no concrete findings; `bash -n`, reproducibility, backup bytes, preview readability and `git diff --check` passed.

Home Screen border/readability acceptance remains open until a real device image is inspected. Asset-only change: no new unit tests needed. Rollback by copying the backup over `Noted/Assets.xcassets/AppIcon.appiconset/AppIcon.png` and rebuilding/installing over the same app.

## Revision 2 — full-bleed cork (2026-11-02)

User judged revision 1 ugly. Cause: the artwork's own rounded green frame sat inside the iOS mask ("icon inside an icon"), and the flat `#2A4A3A` corner fill did not match the textured frame. Thin-frame crops were tested and rejected: the drawn frame is uneven, so a sliver looked thicker on one side.

- `make-icon.sh` now crops the cork interior `950x950+155+155` (cork measured x≈145..1115, y≈155..1105), with no flood fill or flat fill. The iOS mask is the only edge; “Noted.” is ~15% larger than in revision 1.
- Asset SHA256 `cee171b9e0afcc33fbb415bc9cb2c5c6f443d46a6b69ce4e2b36884f35c1a967`; second run is byte-identical. srgb, 3 channels, opaque, 1024×1024. Previews regenerated (mask radius 22.37%).
- Unsigned Debug simulator build passed (override `SUPPORTED_PLATFORMS`/`SDKROOT` on the command line, project unchanged). Installed on simulator “Noted iPhone 12 Pro” (iOS 18.6); Home Screen crop: [simulator-home-icon.png](simulator-home-icon.png). No cream border or seam; “Noted.” readable at Home Screen size.
- Still pending: physical iPhone Home Screen (simulator does not replace device acceptance). Superseded revision 1 values above are kept for history.
