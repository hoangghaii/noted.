#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MAGICK="${MAGICK:-/opt/homebrew/bin/magick}"
SOURCE="$ROOT/docs/design-preview/icon-concepts/noted-pinboard-selected.png"
OUTPUT="${1:-$ROOT/Noted/Assets.xcassets/AppIcon.appiconset/AppIcon.png}"
PREVIEWS="${2:-$ROOT/docs/evidence/20261102-paper-phase3}"
mkdir -p "$(dirname "$OUTPUT")" "$PREVIEWS"
# Full-bleed corkboard: crop inside the artwork's own green frame (cork spans
# x≈145..1115, y≈155..1105 in the 1254 px source) so the iOS mask is the only
# edge. Keeping the drawn frame produced an "icon inside an icon" seam and flat
# corner fills; thin frame slivers came out uneven because the art is not square.
"$MAGICK" "$SOURCE" -crop 950x950+155+155 +repage \
  -colorspace sRGB -alpha off -filter Lanczos -resize 1024x1024 \
  -depth 8 -strip -define png:color-type=2 "$OUTPUT"
for size in 1024 180 120 60; do
  radius=$(awk "BEGIN {print $size * 0.2237}")
  last=$((size - 1))
  # Rounded rectangle approximates the system mask; actual iOS evidence is separate.
  "$MAGICK" "$OUTPUT" -resize "${size}x${size}" \
    \( -size "${size}x${size}" xc:black -fill white \
       -draw "roundrectangle 0,0,$last,$last,$radius,$radius" \) \
    -alpha off -compose CopyOpacity -composite \
    -background '#FAF6ED' -alpha remove -alpha off \
    "$PREVIEWS/icon-mask-${size}.png"
done
"$MAGICK" identify -format '%[channels] %wx%h\n' "$OUTPUT"
