#!/bin/bash
# live-keys.sh: drive Powerbar's keyboard mode on the REAL desktop, safely.
# Only when the user has asked for a live test. Prefer omabox otherwise
# (`omabox keys …`, `omabox run -- omarchy-shell powerbar keysStatus`).
#
#   live-keys.sh start          enter the mode by IPC (no key needed)
#   live-keys.sh key K...       send keys by wtype name (Escape, Down, Return, …)
#   live-keys.sh type TEXT      type text one character at a time (spaces too)
#   live-keys.sh status         the mode's state in one line
#   live-keys.sh stop           leave the mode by IPC
#
# Safety: wtype sends keys to whatever holds the keyboard, which can be the
# terminal running the agent. Before EVERY key this checks keysStatus (the mode
# is active, its bar window holds the keyboard, no panel has it); otherwise it
# sends nothing, leaves the mode by IPC and exits 3. It refuses while the
# session is locked. wtype bypasses input methods (fcitx5): paths that depend
# on the real keyboard need the user's own hands.
set -u
status() { omarchy-shell powerbar keysStatus; }
held() {
  status | python3 -c "import json,sys; s=json.load(sys.stdin); sys.exit(0 if s['active'] and s['windowActive'] and (s['focused'] or s['drawerFocused']) and not s['suspended'] else 1)"
}
active() { status | python3 -c "import json,sys; sys.exit(0 if json.load(sys.stdin)['active'] else 1)"; }
bail() { echo "live-keys: the bar does not hold the keyboard; nothing sent, leaving the mode" >&2; active && omarchy-shell powerbar keys; exit 3; }
if command -v omarchy-hyprland-session-locked >/dev/null && omarchy-hyprland-session-locked; then
  echo "live-keys: the session is locked; not sending anything" >&2; exit 2
fi
case "${1:-}" in
  start) active || omarchy-shell powerbar keys; sleep 0.6; held || bail; echo started ;;
  key) shift; for k in "$@"; do held || bail; wtype -k "$k"; sleep 0.35; done ;;
  type)
    shift; t="$*"
    for ((i = 0; i < ${#t}; i++)); do
      held || bail
      c="${t:i:1}"
      if [ "$c" = " " ]; then wtype -k space; else wtype "$c"; fi
      sleep 0.3
    done ;;
  status)
    status | python3 -c "
import json, sys
s = json.load(sys.stdin); d = s['drawer']
print({k: s[k] for k in ('active', 'cursor', 'query', 'matches', 'searching', 'inline')},
      'drawer:', d and {k: d[k] for k in ('group', 'zone', 'cursor', 'member', 'previewing')}, 'card:', s['card'])" ;;
  stop) active && omarchy-shell powerbar keys; echo stopped ;;
  *) sed -n '2,20p' "$0"; exit 1 ;;
esac
