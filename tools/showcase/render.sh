#!/usr/bin/env bash
# Renders tools/showcase/card.html to preview.jpg (2400x1350: 1200x675 at
# 2x), the README hero and plugin preview. The card frames two captures,
# screenshots/hero-prefs.jpg and screenshots/hero-bar.jpg (DEVELOPMENT.md,
# README images). Needs a Chromium; the page loads only files from this
# repository.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
browser=${CHROMIUM:-$(command -v chromium || command -v chromium-browser || command -v google-chrome-stable)}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
out=${1:-$root/preview.jpg}
"$browser" --headless=new --disable-gpu --hide-scrollbars --no-first-run \
  --user-data-dir="$tmp" --force-device-scale-factor=2 --window-size=1200,675 \
  --virtual-time-budget=3000 --screenshot="$tmp/card.png" "file://$root/tools/showcase/card.html" >/dev/null 2>&1
magick "$tmp/card.png" -crop 2400x1350+0+0 +repage -strip -quality 88 -sampling-factor 4:2:0 "$out"
echo "$out"
