# Paper sketch assets

Nine original, single-color SVG drawings; 2.2 unit strokes with rounded caps and joins. Folder icons use a 48 unit canvas, content icons 32, and the hero bulb 64. Render them as templates using the shared palette. The asset catalog stores an identical SVG copy for each source here.

`preview.png` shows Book, Heart, Leaf / Mountain, Plain, Lightbulb / Link, Note, Photo at 96px. Its green ink is illustrative; the app supplies tint. Preview rasterization uses ImageMagick's `-draw "scale 3,3 path '…'"` on the SVG path data because the installed SVG decoder produces empty images. Apple asset compilation and tint verification remain native build/device checks.

`grain-2x2.png` shows the unblended tile repeated twice in both axes. The 256px grayscale tile mirrors a deterministic 128px seeded noise quadrant so opposite edges match exactly. Generate it with `scripts/ui-fidelity/make-grain.sh`; an optional first argument changes the output path. ImageMagick 7.1.2-9 produces SHA256 `8b4d37f83fcfd62db5e095a7d3b128a722030b93704b390cd7263105830c3644`. Texture should be applied at low opacity, rather than shown at this preview's full strength.
