# Noted paper concept — mock v1

The user selected the pinboard icon on 2026-11-02. Original selected artwork is preserved in icon-concepts/noted-pinboard-selected.png; the production asset catalog has not been replaced.

UI preview: noted-paper-ui-mock-v1.png. Generated with the built-in imagegen tool using the selected icon as the visual reference. Prompt direction: three native iPhone screens (Library, Collections, Quick Capture); warm cream, forest, honey and sage; fine matte paper texture, sparse hand-drawn accents, subtle curled card corners, aligned readable content, capsule actions and circular icon controls. Keep actual reading text in a clear system font, retain existing save/link/photo/collection flows, and reserve illustrated strokes for accents. Paper tones express visual variation, not a newly implemented categorization feature.

This is a raster design proposal, not implemented or measured native UI. Text, example dates/counts, decorative symbols and specific controls in the generated mock are illustrative. Font coverage, contrast after texture composition, Dynamic Type and device performance require implementation-stage verification. No SwiftUI source or app icon asset was changed in this mock-only request.

## Revision 2

Preview: noted-paper-ui-mock-v2.png, edited with built-in imagegen from v1. User requested sparse casually distributed paper curls and uniform pill widths. Prompt preserves all screens and identity, removes all UI curls except one on the honey Library note, and requests equal widths within Library filters and capture mode choices. Primary actions retain contextual widths. The raster concept approximates geometry; exact equal widths and Capsule shapes must be enforced in native layout during implementation.

Implementation direction for sparse curls: select a small stable subset of eligible content cards (approximately one in eight, capped at one visible accent per small grid). Base selection on stable item identity, not fresh randomness per render, to avoid visual flicker. Do not curl controls, hero panels or editor fields. This is a proposed implementation rule, not implemented behavior.

## Revision 3

Preview: noted-paper-ui-mock-v3.png. Built-in imagegen targeted edit: Quick Capture modes are three independent equal-width capsule buttons, with visible gaps and no enclosing segmented background. Selected mode uses forest fill; other modes use pale neutral fill. Enforce actual Capsule geometry and equal flexible widths in SwiftUI implementation; raster output is a visual reference only.

## Implementation status (2026-11-03)

Mock v3 is implemented natively in SwiftUI (plan `plans/archived/20261102-2119-paper-pinboard-ui/`). The pinboard icon is in the production asset catalog. Measured fidelity on a physical iPhone 12 Pro, critical criteria and approved deviations are in [the Phase 08 report](../evidence/20261103-paper-phase8/summary.md).

The curl rule changed from the proposed ~1/8 to ~1/4 of notes at the user's request (stable `UUID` hash, still never on photos, controls, hero panels or editor fields). The Quick Capture body field has no curl, matching v3.
