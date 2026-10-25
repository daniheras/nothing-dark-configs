#!/usr/bin/env bash
# Frame a screenshot for a README: rounded corners, subtle border, drop
# shadow on a transparent canvas. Looks right on any GitHub theme.
#
#   docs/image-frame.sh screenshots/*.png
#
# Env overrides: RADIUS=24 BORDER="#3F3F3F" MARGIN=48 SHADOW="40x20+0+10"
set -euo pipefail

RADIUS=${RADIUS:-24}
BORDER=${BORDER:-"#3F3F3F"}
MARGIN=${MARGIN:-48}
SHADOW=${SHADOW:-"40x20+0+10"}

frame() {
  local img=$1
  local sh=$SHADOW gz=${SHADOW%%x*}

  local W H
  W=$(magick identify -format '%w' "$img")
  H=$(magick identify -format '%h' "$img")
  local cr=$((RADIUS - 1))
  local cw=$((W - 1)) ch=$((H - 1))

  local tmp
  tmp=$(mktemp --suffix=.png)
  trap 'rm -f "$tmp"' RETURN

  # 1. Round the corners (classic IM corner-mask recipe).
  magick "$img" \
    \( +clone -alpha extract \
       -draw "fill black polygon 0,0 0,$cr $cr,0 fill white circle $cr,$cr $cr,0" \
       \( +clone -flip \) \( +clone -flop \) \
       \( +clone -flip \( +clone -flip \) -delete 0 \) \
       \( +clone -flop \( +clone -flop \) -delete 0 \) \
       -compose Multiply -composite \) \
    -alpha off -compose CopyOpacity -composite "$tmp"

  # 2. 2px border drawn along the rounded contour.
  magick "$tmp" \
    \( -size "${W}x${H}" xc:none -fill none \
       -stroke "$BORDER" -strokewidth 2 \
       -draw "roundrectangle 1,1 $cw,$ch $cr,$cr" \) \
    -compose over -composite "$tmp"

  # 3. Drop shadow on a transparent canvas.
  magick "$tmp" \
    \( +clone -background none -shadow "$SHADOW" \) +swap \
    -background none -compose over -composite "$tmp"

  # 4. Symmetric padding to leave room for the blur.
  magick "$tmp" -gravity center -background none \
    -extent $((W + 2 * MARGIN))x$((H + 2 * MARGIN)) "$img"
}

for img in "$@"; do
  frame "$img"
  echo "framed: $img"
done
