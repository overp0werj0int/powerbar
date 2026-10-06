#!/bin/bash
# run.sh <plugin-dir> <scenario> [animations 0|1]
# One offscreen run; prints the BENCH lines. Nothing touches the live shell:
# no Wayland or Hyprland connection, a private widget image cache, and shell
# commands that Powerbar might run are stubbed.
B=$(cd "$(dirname "$0")" && pwd)
W=${BENCH_WORK:-${XDG_RUNTIME_DIR:-/tmp}/powerbar-bench}
mkdir -p "$W/cfg" "$W/cache" "$W/hypr"
# Shortcut changes write here, never to ~/.config/hypr (hyprctl is stubbed too).
rm -f "$W/hypr"/*; cp "${XDG_CONFIG_HOME:-$HOME/.config}"/hypr/*.lua "$W/hypr/" 2>/dev/null
python3 "$B/prepare.py" "$1" "$W/cfg" || exit 1
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
  PATH="$B/bin:$PATH" XDG_CACHE_HOME="$W/cache" POWERBAR_HYPR_DIR="$W/hypr" \
  QT_QPA_PLATFORM="offscreen:configfile=${BENCH_SCREENS:-$B/screens.json}" QT_QUICK_BACKEND=${BENCH_BACKEND:-software} \
  BENCH_SCENARIO="$2" BENCH_ANIM="${3:-0}" BENCH_SHOT="${BENCH_SHOT:-/dev/null}" \
  timeout 90 qs ${BENCH_QS_ARGS:-} -p "$W/cfg/shell.qml" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -v "^\s*$"
