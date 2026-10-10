#!/bin/bash
# edges.sh: the keyboard card on the bar's first and last widget, in one PNG.
#
#   edges.sh BOX OUT.png [-g "X,Y WxH"] [--vertical]
#
# Walks the cursor to the start (16 x Left, or Up) and shoots, then to the end
# (32 x Right, or Down) and shoots; the two shots are stacked (side by side
# for a tall area). A card at either end of the screen should sit whole on it
# (appearance.md LOOK-137). Default area: a top bar, "0,0 1512x110".
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOX=${1:?usage: edges.sh BOX OUT.png [-g GEOM] [--vertical]}; OUT=${2:?out png}; shift 2
G="0,0 1512x110"; BK=Left; FW=Right
while [ $# -gt 0 ]; do
  case "$1" in
    -g) G=$2; shift 2 ;;
    --vertical) BK=Up; FW=Down; shift ;;
    *) echo "edges.sh: unknown $1" >&2; exit 2 ;;
  esac
done
B=$BOX; source "$DIR/drive.sh"
reset
for i in $(seq 1 16); do k $BK; done; ks
a=$(omabox shot -b "$BOX" -g "$G" 2>&1 | tail -1)
for i in $(seq 1 32); do k $FW; done; ks
b=$(omabox shot -b "$BOX" -g "$G" 2>&1 | tail -1)
python3 - "$a" "$b" "$OUT" <<'PY'
import sys
from PIL import Image
a, b = (Image.open(f) for f in sys.argv[1:3])
W, H = a.size
M = Image.new('RGB', (W, 2 * H + 2) if W > H else (2 * W + 2, H), (255, 0, 0))
M.paste(a, (0, 0)); M.paste(b, (0, H + 2) if W > H else (W + 2, 0))
M.save(sys.argv[3]); print(sys.argv[3])
PY
