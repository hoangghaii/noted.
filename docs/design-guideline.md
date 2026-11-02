# Noted design foundations — Paper pinboard

Status: Phases 01–04 are implemented in the app icon, shared SwiftUI tokens, components, Library, Search, Collections, Capture, Share Extension, Trash and backup. Phase 05 has physical iPhone 12 Pro screenshots and behavior evidence in [the 2026-11-02 device report](evidence/20261102-iphone12pro/ui-redesign-summary.md). The [interactive component lab](design-preview/component-lab.html) was reviewed in Chrome at desktop and responsive 400 px. Native iOS controls and personal data differ from the HTML sample; no numerical visual similarity percentage has been measured.

## Identity — Giấy & Rừng (2026-11-02)

User-approved color direction: cream paper, forest green navigation and honey save actions. Use flat, quiet surfaces inspired by a personal notebook. Phase 03 of the paper pinboard plan replaces Folded N with the user-selected “Noted.” pinboard artwork. The original icon is preserved at `design-preview/icon-concepts/noted-folded-n-backup.png`; `scripts/ui-fidelity/make-icon.sh` reproduces the full-bleed, opaque 1024 px asset and four mask previews. Physical Home Screen acceptance is tracked in the Phase 03 evidence report.

## Tokens

| Role | Light | Dark |
|---|---|---|
| brand | `#224431` | `#A6CDB7` |
| brandSoft | `#DFE5D8` | `#293D33` |
| accent | `#EDB55E` | `#E9BD70` |
| accentText | `#302719` | `#302719` |
| paper | `#FAF6ED` | `#191E1A` |
| chip | `#EDE7DB` | `#303A31` |
| toneCream | `#FBF4E6` | `#292E27` |
| toneHoney | `#F2BF65` | `#E0AE59` |
| toneSage | `#DFE5D8` | `#303F33` |
| folderTab | `#EAB65E` | `#E0AE59` |
| field | `#F8F4EB` | `#242C25` |
| bar | `#F8F3EB` | `#242C25` |
| surface | `#FFFDF7` | `#242C25` |
| primaryText | `#1E2A23` | `#F3F0E7` |
| secondaryText | `#6B6A62` | `#B6BFAF` |
| border | `#DEDFD3` | `#455044` |
| error | `#A33F36` | `#F3A499` |
| errorSoft | `#FBECE7` | `#462E29` |
| onBrand | `#FFFDF7` | `#192B21` |
| hero | `#284739` | `#2B4437` |
| heroText | `#FFFDF7` | `#FFFDF7` |
| heroMuted | `#C8D8BF` | `#C8D8BF` |

Use `onBrand` on selected brand-filled controls, `accentText` on honey actions, and `heroText`/`heroMuted` on the capture panel. Never substitute a surface token for a button foreground. These shared adaptive tokens cover the app and Share Extension.

## Type and shape

- Use the iOS system font with Dynamic Type. Web preview uses `-apple-system`, `BlinkMacSystemFont`, `Helvetica Neue`, then Arial; inspect Vietnamese glyphs including `Ă Â Đ Ê Ô Ơ Ư` in the type specimen.
- Use semantic SwiftUI text styles (`largeTitle`, `title2`, `headline`, `body`, `caption`) so Dynamic Type scales by default. The prototype's 32/38, 24/30, 17/23, 15/22 and 12/17 values are visual references, not fixed app line heights. Use `@ScaledMetric` where a later component needs a custom dimension that should scale with text.
- Spacing rhythm: 4, 8, 12, 16, 24, 32 pt. Corners: 8 for thumbnails/decorative badges, 10 for inputs, 12 for cards and 6 for folder tabs. All custom text action buttons use `Capsule()` (primary, secondary, quiet, destructive, Lưu nhanh and Share save). Icon-only options use `Circle()` with a 44 pt target. Filter chips remain capsules. Native toolbar/menu controls retain their system presentation.
- iPhone touch targets should remain at least 44 pt. Keep text labels visible for controls that could be ambiguous as icons alone.
- Keep Vietnamese labels readable without truncating essential actions. Check `Ă Â Đ Ê Ô Ơ Ư`, lowercase accents, and “giữ”, “tìm kiếm”, “bộ sưu tập” in the live app.

## Component behavior

- Primary, secondary, quiet and destructive buttons have distinct roles. A busy action disables repeat submission and names the operation in progress.
- Input labels stay visible. Required content shows a specific error and moves focus to the field. Optional caption fields say so explicitly.
- Library cards show content kind, title, useful excerpt or source, and secondary date or collection. Pinned state uses a label as well as a symbol.
- Filters use a selected state that is distinguishable by shape and contrast. Empty, loading and error states explain the next useful action and preserve unsaved drafts.
- Keep the three existing destinations: Thư viện, Tìm kiếm and Bộ sưu tập. Lưu nhanh opens as a sheet. This preview does not implement automatic topic groups from the separate topic plan.

## Verification boundary

The HTML/CSS/JavaScript prototype is a design artifact with sample data. Browser layout and interactions were checked in Chrome; the icon, main screens and Share preview have physical iPhone evidence in the linked report. Native sheet/navigation chrome and real content can differ from the sample. Full VoiceOver, dark mode and a pixel-based 98–100% comparison have not been measured.

## Paper pinboard foundations (2026-11-02, Phase 02)

`Shared/NotedDesign.swift` is the source of truth. Shared paper assets are compiled into both app and extension. `paperBackground` supplies static tiled grain: a neutral 50% grey tile (sd ≈ 13/255) composited with soft light (pages/cards 0.35, hero 1.0), so token colours and ΔE probes are preserved while the speckle shows; callers clip to their component shape. `Shared/NotedPaperUI.swift` supplies PaperCard (tone/grain/curl), EqualWidthPillGroup, NotedPill, CircleIconButton, PaperField, TagChip and the shared NotedButtonStyle. Library filters show four equal pills before scrolling; capture modes use three equal pills. Standard pills have a 36 pt visual capsule inside a 44 pt minimum hit area; mode pills use 44 pt. Dimensions grow with Dynamic Type. Primary prominent buttons are 50 pt; soft buttons use sage and regular text. Tab icons are 24 pt with 12 pt labels on the bar token, without a hairline. Screen-wide adoption continues in later phases. Texture does not generate noise during rendering.

`PaperTone` uses FNV-1a over canonical `UUID.uuidString`: links sage, images cream, one third of notes honey. Non-image curls use hash % 8 == 3; this can overlap honey (the original plan's non-overlap comment was mathematically incorrect). Folder tones alternate cream/sage by displayed index. Honey retains a light background in dark mode and uses `PaperTone.foreground` (`accentText`) for readable text. Do not use dark-theme primaryText on honey.

The nine `NotedDesign.Sketch` images use template rendering. SVG sources and preview live under `design-preview/assets/sketch/`; `scripts/ui-fidelity/make-grain.sh` regenerates the seeded tile.

Calculated WCAG sRGB contrast for solid tokens (device texture probes remain Phase 08):

| Theme | Pair | Contrast |
|---|---|---|
| Light | primaryText / paper | 13.80:1 |
| Light | primaryText / surface | 14.64:1 |
| Light | primaryText / toneCream | 13.60:1 |
| Light | primaryText / toneSage | 11.58:1 |
| Light | primaryText / chip | 12.09:1 |
| Light | primaryText / field | 13.56:1 |
| Light | primaryText / bar | 13.48:1 |
| Light | secondaryText / paper | 5.04:1 |
| Light | secondaryText / surface | 5.34:1 |
| Light | secondaryText / toneCream | 4.97:1 |
| Light | secondaryText / toneSage | 4.23:1 |
| Light | secondaryText / chip | 4.41:1 |
| Light | secondaryText / field | 4.95:1 |
| Light | secondaryText / bar | 4.92:1 |
| Light | onBrand / brand | 10.65:1 |
| Light | accentText / accent | 7.95:1 |
| Light | accentText / toneHoney | 8.68:1 |
| Light | heroText / hero | 10.07:1 |
| Light | heroMuted / hero | 6.84:1 |
| Light | error / errorSoft | 5.50:1 |
| Dark | primaryText / paper | 14.84:1 |
| Dark | primaryText / surface | 12.61:1 |
| Dark | primaryText / toneCream | 12.17:1 |
| Dark | primaryText / toneSage | 9.78:1 |
| Dark | primaryText / chip | 10.38:1 |
| Dark | primaryText / field | 12.61:1 |
| Dark | primaryText / bar | 12.61:1 |
| Dark | secondaryText / paper | 8.91:1 |
| Dark | secondaryText / surface | 7.57:1 |
| Dark | secondaryText / toneCream | 7.30:1 |
| Dark | secondaryText / toneSage | 5.87:1 |
| Dark | secondaryText / chip | 6.23:1 |
| Dark | secondaryText / field | 7.57:1 |
| Dark | secondaryText / bar | 7.57:1 |
| Dark | onBrand / brand | 8.54:1 |
| Dark | accentText / accent | 8.38:1 |
| Dark | accentText / toneHoney | 7.25:1 |
| Dark | heroText / hero | 10.40:1 |
| Dark | heroMuted / hero | 7.07:1 |
| Dark | error / errorSoft | 6.29:1 |

The two light pairs secondaryText/toneSage (4.23:1) and secondaryText/chip (4.41:1) fall below 4.5:1: use primaryText on sage/chip. `PaperTone.secondaryForeground` enforces the card pairing; honey uses accentText. All other listed pairs meet 4.5:1. Texture changes the rendered colors: final ΔE probes, native tint verification and physical scroll performance remain pending until the components use these assets. Dark mode and VoiceOver have not received full device acceptance.

### Collections and supporting screens (Phase 06)

Collection rows use app-only folder cards with a honey tab (64×14 pt), cream/sage bodies alternating by displayed index, 60 pt sketch icons and a name/count stack. Names remain sorted by the store. Folder motifs fold Vietnamese diacritics and match inspiration/reading/private/travel keywords, falling back to the stable UUID hash across four motifs; no model field is added.

Collections exposes the same Backup/Trash destinations as Library. Detail uses paper surfaces and tag chips; the editor retains native Form behavior with PaperField inputs and capsule/circle actions. Native alert/control touches must bypass the window keyboard-dismiss observer so saving an alert works in one tap.
