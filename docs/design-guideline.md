# Noted design foundations — Folded N

Status: Phases 01–04 are implemented in the app icon, shared SwiftUI tokens, components, Library, Search, Collections, Capture, Share Extension, Trash and backup. Phase 05 has physical iPhone 12 Pro screenshots and behavior evidence in [the 2026-11-02 device report](evidence/20261102-iphone12pro/ui-redesign-summary.md). The [interactive component lab](design-preview/component-lab.html) was reviewed in Chrome at desktop and responsive 400 px. Native iOS controls and personal data differ from the HTML sample; no numerical visual similarity percentage has been measured.

## Identity — Giấy & Rừng (2026-11-02)

User-approved color direction: cream paper, forest green navigation and honey save actions. Use flat, quiet surfaces inspired by a personal notebook. The existing Folded N app icon remains the installed identity asset; this pass updates interface colors, not icon artwork.

## Tokens

| Role | Light | Dark |
|---|---|---|
| brand | `#285448` | `#A6CDB7` |
| brandSoft | `#E5EDE5` | `#293D33` |
| accent | `#E6B45B` | `#E9BD70` |
| accentText | `#302719` | `#302719` |
| paper | `#F6F2E9` | `#191E1A` |
| surface | `#FFFDF7` | `#242C25` |
| primaryText | `#27352C` | `#F3F0E7` |
| secondaryText | `#646D61` | `#B6BFAF` |
| border | `#DEDFD3` | `#455044` |
| error | `#A33F36` | `#F3A499` |
| errorSoft | `#FBECE7` | `#462E29` |
| onBrand | `#FFFDF7` | `#192B21` |
| hero | `#253F34` | `#2B4437` |
| heroText | `#FFFDF7` | `#FFFDF7` |
| heroMuted | `#C8D8BF` | `#C8D8BF` |

Use `onBrand` on selected brand-filled controls, `accentText` on honey actions, and `heroText`/`heroMuted` on the capture panel. Never substitute a surface token for a button foreground. These shared adaptive tokens cover the app and Share Extension.

## Type and shape

- Use the iOS system font with Dynamic Type. Web preview uses `-apple-system`, `BlinkMacSystemFont`, `Helvetica Neue`, then Arial; inspect Vietnamese glyphs including `Ă Â Đ Ê Ô Ơ Ư` in the type specimen.
- Use semantic SwiftUI text styles (`largeTitle`, `title2`, `headline`, `body`, `caption`) so Dynamic Type scales by default. The prototype's 32/38, 24/30, 17/23, 15/22 and 12/17 values are visual references, not fixed app line heights. Use `@ScaledMetric` where a later component needs a custom dimension that should scale with text.
- Spacing rhythm: 4, 8, 12, 16, 24, 32 pt. Corners: 8 for thumbnails/decorative badges, 14 for inputs and 20 for cards. All custom text action buttons use `Capsule()` (primary, secondary, quiet, destructive, Lưu nhanh and Share save). Icon-only options use `Circle()` with a 44 pt target. Filter chips remain capsules. Native toolbar/menu controls retain their system presentation.
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

## Color refresh verification (2026-11-02)

Calculated sRGB contrast for actual token pairs:

| Theme | Pair | Contrast |
|---|---|---|
| Light | primaryText / surface | 12.65:1 |
| Light | secondaryText / paper | 4.82:1 |
| Light | secondaryText / surface | 5.29:1 |
| Light | brand / brandSoft | 7.17:1 |
| Light | onBrand / brand | 8.42:1 |
| Light | accentText / accent | 7.72:1 |
| Light | heroText / hero | 11.22:1 |
| Light | heroMuted / hero | 7.63:1 |
| Light | error / errorSoft | 5.50:1 |
| Dark | primaryText / surface | 12.61:1 |
| Dark | secondaryText / paper | 8.91:1 |
| Dark | secondaryText / surface | 7.57:1 |
| Dark | brand / brandSoft | 6.65:1 |
| Dark | onBrand / brand | 8.54:1 |
| Dark | accentText / accent | 8.38:1 |
| Dark | heroText / hero | 10.40:1 |
| Dark | heroMuted / hero | 7.07:1 |
| Dark | error / errorSoft | 6.29:1 |

All listed normal-text pairs meet 4.5:1. Typography remains the iOS system font; existing physical-device screenshots include Vietnamese diacritics. No new font or font fallback was introduced. Fresh native glyph rendering, Dynamic Type and dark-mode device screenshots remain unverified for this color pass.
