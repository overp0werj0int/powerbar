#!/usr/bin/env bash
# One look at a lab page before publishing: a full-page headless Chromium
# screenshot, cut into slices small enough to read.
#
#   screenshot.sh PAGE.html OUTDIR [height=9000] [light|dark] [fragment]
#
# Writes OUTDIR/full.png and OUTDIR/slice-N.png (1280 x 1400 each, halved).
# A fragment (for example "ghost-150") is appended as #ghost-150, so a page
# with a state hook can be captured mid-interaction; run once per state.
set -euo pipefail
page=$(realpath "$1"); out=$2; height=${3:-9000}; scheme=${4:-dark}; frag=${5:+#$5}
mkdir -p "$out"
browser=$(command -v chromium || command -v google-chrome-stable || true)
[ -n "$browser" ] || { echo "No chromium or google-chrome-stable found" >&2; exit 1; }
flags=(--headless=new --disable-gpu --no-sandbox --hide-scrollbars --window-size=1280,"$height" --virtual-time-budget=4000)
[ "$scheme" = dark ] && flags+=(--force-dark-mode --blink-settings=preferredColorScheme=0) || flags+=(--blink-settings=preferredColorScheme=1)
# Render the page the way the Artifact host serves it: the host wraps it in a
# skeleton whose base stylesheet includes img { max-width: 100% } and a 14px
# body font. Without this, squeezed captures only show up after publishing.
shot="$(dirname "$page")/.shot-$(basename "$page")"
{ printf '%s' '<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1"><style>body{margin:0;padding:0;font:14px -apple-system,BlinkMacSystemFont,sans-serif}img{max-width:100%}</style></head><body>'; cat "$page"; } > "$shot"
trap 'rm -f "$shot"' EXIT
timeout 90 "$browser" "${flags[@]}" --screenshot="$out/full.png" "file://$shot$frag" >/dev/null 2>&1
python3 - "$out" <<'EOF'
import sys
from PIL import Image
out = sys.argv[1]
im = Image.open(f"{out}/full.png").convert("RGB")
# Trim the empty ground below the page.
bg = im.getpixel((5, im.height - 5))
bottom = im.height
while bottom > 0 and all(im.getpixel((x, bottom - 1)) == bg for x in range(0, im.width, 40)):
    bottom -= 1
for n, top in enumerate(range(0, bottom, 1400)):
    im.crop((0, top, 1280, min(bottom, top + 1400))).resize((640, (min(bottom, top + 1400) - top) // 2)).save(f"{out}/slice-{n}.png")
print(f"{(bottom + 1399) // 1400} slices in {out}")
EOF
