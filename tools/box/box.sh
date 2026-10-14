#!/bin/bash
# box.sh: an omabox box running this checkout with the user's bar layout.
# Never touches the user's desktop; reads ~/.config/omarchy/shell.json only.
#
#   box.sh up NAME [PLUGIN_DIR]    box at 1512x945, the plugin copied in, the
#                                  user's bar config (autohide off), shell up
#   box.sh sync NAME [PLUGIN_DIR]  copy the plugin in again, restart the shell,
#                                  wait until Powerbar answers
#   box.sh conf NAME KEY=VALUE...  set bar keys in the box's shell.json (VALUE
#                                  is JSON when it parses, else a string); the
#                                  box applies it live
#   box.sh path NAME               the box's shell.json
#
# BOX_UP_ARGS adds options to `up`'s omabox up (word-split), e.g.
# BOX_UP_ARGS="--env POWERBAR_DISPLAY_CUTOUTS=/home/sbx/cutouts.json --monitor 3024x1964,scale=2"
#
# PLUGIN_DIR defaults to this checkout. Widgets from plugins the box lacks
# show as placeholders, which is enough for layout and motion.
set -u
ID=p0werj0int.powerbar
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cmd=${1:-}; N=${2:-}
[ -n "$cmd" ] && [ -n "$N" ] || { sed -n '2,20p' "$0"; exit 2; }
SRC=${3:-$ROOT}

home() { echo "$(omabox path "$N")/home"; }

copy() {
  local dst; dst="$(home)/.config/omarchy/plugins/$ID"
  mkdir -p "$dst"
  rsync -a --delete --exclude .git --exclude .claude --exclude docs --exclude tests "$SRC/" "$dst/"
}

ready() {
  omabox wait -b "$N" --timeout 60s cmd -- omarchy-shell powerbar help >/dev/null 2>&1 || { echo "box.sh: Powerbar did not answer in $N" >&2; return 1; }
  omabox wait -b "$N" still >/dev/null 2>&1
  return 0
}

case "$cmd" in
  up)
    omabox up "$N" --size 1512x945 ${BOX_UP_ARGS:-} >/dev/null 2>&1 || { echo "box.sh: omabox up failed" >&2; exit 1; }
    copy
    omabox run -b "$N" -- omarchy bar use "$ID" >/dev/null 2>&1
    python3 - "$(home)/.config/omarchy/shell.json" "$ID" <<'PY'
import json, os, sys
p, pid = sys.argv[1], sys.argv[2]
cfg = json.load(open(p))
bar = json.load(open(os.path.expanduser('~/.config/omarchy/shell.json')))['bar']
bar['id'] = pid
bar['powerbarAutoHide'] = False
cfg['bar'] = bar
tmp = p + '.tmp'; json.dump(cfg, open(tmp, 'w'), indent=1); os.replace(tmp, p)
PY
    omabox restart-shell -b "$N" >/dev/null 2>&1
    ready && echo "box.sh: $N up"
    ;;
  sync)
    copy
    omabox restart-shell -b "$N" >/dev/null 2>&1
    ready
    ;;
  conf)
    shift 2
    python3 - "$(home)/.config/omarchy/shell.json" "$@" <<'PY'
import json, os, sys
p = sys.argv[1]
cfg = json.load(open(p))
for kv in sys.argv[2:]:
    k, v = kv.split('=', 1)
    try: v = json.loads(v)
    except ValueError: pass
    cfg['bar'][k] = v
tmp = p + '.tmp'; json.dump(cfg, open(tmp, 'w'), indent=1); os.replace(tmp, p)
PY
    omabox wait -b "$N" still >/dev/null 2>&1
    ;;
  path) echo "$(home)/.config/omarchy/shell.json" ;;
  *) sed -n '2,20p' "$0"; exit 2 ;;
esac
