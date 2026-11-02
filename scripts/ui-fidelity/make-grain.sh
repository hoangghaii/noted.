#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MAGICK="${MAGICK:-/opt/homebrew/bin/magick}"
OUTPUT="${1:-$ROOT/Shared/PaperAssets.xcassets/PaperGrain.imageset/PaperGrain.png}"
mkdir -p "$(dirname "$OUTPUT")"
# Mirror a seeded quadrant: both opposite edges match exactly, including after tiling.
# One worker and stripped PNG metadata make reruns byte-for-byte reproducible.
# Neutral 50% grey with visible spread (sd ≈ 13/255): composited with soft light, the
# mean colour of the surface is preserved and only the speckle shows (see PaperBackground).
"$MAGICK" -limit thread 1 -size 128x128 xc:gray50 -seed 20261102 \
  -attenuate 1.5 +noise Gaussian -colorspace Gray -blur 0x0.6 \
  \( +clone -flop \) +append \( +clone -flip \) -append \
  -depth 8 -strip -define png:exclude-chunks=date,time -define png:color-type=0 PNG:"$OUTPUT"
