#!/usr/bin/env bash
# Renders tools/showcase/card.html to preview.jpg (2400x1350: 1200x675 at
# 2x), the README hero and plugin preview. With --wall, renders only the
# field under the card's screen at 1920x1080 instead: the background for the
# box that takes screenshots/hero-nord.jpg. Needs a Chromium; the page loads
# only files from this repository.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
browser=${CHROMIUM:-$(command -v chromium || command -v chromium-browser || command -v google-chrome-stable)}
wall=; [ "${1:-}" = --wall ] && { wall=1; shift; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
url="file://$root/tools/showcase/card.html${wall:+#wall}"
"$browser" --headless=new --disable-gpu --hide-scrollbars --no-first-run \
  --user-data-dir="$tmp" --force-device-scale-factor=2 --window-size=1200,675 \
  --virtual-time-budget=3000 --screenshot="$tmp/card.png" "$url" >/dev/null 2>&1
if [ -n "$wall" ]; then
  out=${1:?usage: render.sh --wall OUT.png}
  # The screen is 880x495 at 160,90 in the page: 1760x990 at 320,180 here.
  magick "$tmp/card.png" -crop 1760x990+320+180 +repage -resize 1920x1080! -strip "$out"
else
  out=${1:-$root/preview.jpg}
  magick "$tmp/card.png" -crop 2400x1350+0+0 +repage -strip -quality 88 -sampling-factor 4:2:0 "$out"
fi
echo "$out"
