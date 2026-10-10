#!/bin/bash
# burst.sh: record a fast keyboard walk frame by frame and count the cards.
#
#   burst.sh BOX [-g "X,Y WxH"] [-n FRAMES] [--vertical] [--band A B] [-- KEYSPEC...]
#
# Resets the keyboard mode (cursor on the anchor widget), then sends the keys
# while taking FRAMES shots 40 ms apart of the area -g. The default walk, 90 ms
# a key: back 6, forward 8, back 3, forward 4 (Left/Right, or Up/Down with
# --vertical). Prints the frames' directory, then cards.py's summary over the
# band A..B (rows under a horizontal bar, columns beside a vertical one; in the
# shot's own pixels). Defaults suit a top bar: -g "0,0 1512x100", band 46 100.
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOX=${1:?usage: burst.sh BOX [-g GEOM] [-n FRAMES] [--vertical] [--band A B] [-- KEYS...]}; shift
G="0,0 1512x100"; NF=70; AXIS=h; A=46; Z=100; KEYS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -g) G=$2; shift 2 ;;
    -n) NF=$2; shift 2 ;;
    --vertical) AXIS=v; shift ;;
    --band) A=$2; Z=$3; shift 3 ;;
    --) shift; KEYS=("$@"); break ;;
    *) echo "burst.sh: unknown $1" >&2; exit 2 ;;
  esac
done
if [ ${#KEYS[@]} -eq 0 ]; then
  if [ $AXIS = v ]; then BK=Up; FW=Down; else BK=Left; FW=Right; fi
  add() { local i; for i in $(seq 1 "$2"); do KEYS+=("$1" -s 90); done; }
  add $BK 6; add $FW 8; add $BK 3; add $FW 4
fi
B=$BOX; source "$DIR/drive.sh"
reset
out=$(omabox shot -b "$BOX" -g "$G" --burst "$NF" --every 40ms --after -- keys "${KEYS[@]}" 2>&1 | tail -1)
D=$(echo "$out" | sed -n 's/.* in \(\/[^;]*\);.*/\1/p')
[ -d "$D" ] || { echo "burst.sh: no frames: $out" >&2; exit 1; }
echo "$D"
python3 "$DIR/cards.py" "$D" --axis $AXIS --band "$A" "$Z" --summary
