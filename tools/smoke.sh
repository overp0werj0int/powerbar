#!/bin/bash
# smoke.sh: desktop smoke test in a private omabox. Never touches the user's
# desktop. Usage: tools/smoke.sh [BOX_NAME]   (default powerbar-smoke)
# Set SMOKE_SHOT=/path/shot.png to keep a screenshot of the bar.
# Needs: omabox, an Omarchy install, rsync, node. Exit non-zero on any failure.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="${1:-powerbar-smoke}"
ID=p0werj0int.powerbar
failed=0

cleanup() { omabox down "$NAME" >/dev/null 2>&1; }
trap cleanup EXIT

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1${2:+ ($2)}"; failed=1; }
check() { # check NAME ACTUAL EXPECTED
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got '$2', want '$3'"; fi
}
ipc() { omabox run -b "$NAME" -- omarchy-shell powerbar "$@" 2>&1; }
# jsget JSON-on-stdin EXPRESSION-OF-o: prints the value, or "unparseable"
jsget() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);console.log(String('"$1"'))}catch(e){console.log("unparseable")}})'; }

omabox down "$NAME" >/dev/null 2>&1
omabox up "$NAME" >/dev/null 2>&1 || { fail "omabox up"; exit 1; }
HOME_DIR="$(omabox path "$NAME")/home"
PLUGIN_DIR="$HOME_DIR/.config/omarchy/plugins/$ID"
mkdir -p "$PLUGIN_DIR"
rsync -a --delete --exclude .git --exclude .claude --exclude docs --exclude tests \
  "$ROOT/" "$PLUGIN_DIR/" || { fail "copy plugin"; exit 1; }
# omabox seeds the box from the user's config; start from Omarchy's defaults.
omabox run -b "$NAME" -- omarchy bar defaults >/dev/null 2>&1
omabox run -b "$NAME" -- omarchy bar use "$ID" >/dev/null 2>&1
omabox restart-shell -b "$NAME" >/dev/null 2>&1   # "crashed while starting" is harmless here
if omabox wait -b "$NAME" --timeout 60s cmd -- omarchy-shell powerbar help >/dev/null 2>&1; then
  pass "powerbar IPC answers"
else
  fail "powerbar IPC answers" "timed out"
  omabox log -b "$NAME" shell -n 30 2>&1 | tail -30
  exit 1
fi

# The box runs this checkout's code, not a cached or older copy.
if bash "$ROOT/tools/build-check.sh" -b "$NAME" >/dev/null 2>&1; then pass "build is this checkout"
else fail "build is this checkout" "$(bash "$ROOT/tools/build-check.sh" -b "$NAME" 2>&1)"; fi
check "status is JSON with settings/widgets/runtime" \
  "$(ipc status | jsget '["settings","widgets","runtime"].every(k=>k in o)')" "true"
check "managedStatus is [] on a fresh install" "$(ipc managedStatus | tr -d ' \n')" "[]"
check "shell.json has no powerbarVisibility key" \
  "$(grep -c '"powerbarVisibility"' "$HOME_DIR/.config/omarchy/shell.json" 2>/dev/null)" "0"
check "get position = top" "$(ipc get position | tr -d '" \n')" "top"
check "set spacing 4" "$(ipc set spacing 4)" "ok"
check "get spacing = 4" "$(ipc get spacing | tr -d ' \n')" "4"
out="$(ipc set spacing 99)"
case "$out" in error:*) pass "set spacing 99 is refused" ;; *) fail "set spacing 99 is refused" "got '$out'" ;; esac

ipc keysOn >/dev/null
sleep 0.5
check "keysStatus active while on" "$(ipc keysStatus | jsget 'o.active')" "true"
ipc keysOff >/dev/null

omabox run -b "$NAME" -- omarchy bar position bottom >/dev/null 2>&1
pos=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pos="$(ipc get position | tr -d '" \n')"
  [ "$pos" = bottom ] && break
  sleep 0.5
done
check "omarchy bar position bottom -> get position = bottom" "$pos" "bottom"

if [ -n "${SMOKE_SHOT:-}" ]; then
  if omabox shot -b "$NAME" -o "$SMOKE_SHOT" >/dev/null 2>&1; then pass "screenshot -> $SMOKE_SHOT"; else fail "screenshot"; fi
fi

[ "$failed" -eq 0 ] && echo "smoke: all passed" || echo "smoke: FAILED"
exit "$failed"
