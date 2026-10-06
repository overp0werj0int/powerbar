#!/bin/bash
# framedebug.sh <widget.qml> [driver.qml] [-- extra env assignments]
# Runs one Omarchy bar widget offscreen in the harness and prints its FD lines
# (FRAME, HIT, STEP, CALL, LOADED, END) plus any QML warnings.
#   FD_SETTINGS='{"key":1}' FD_BAR=30 FD_VERTICAL=1 FD_WATCH=name,name FD_DEPTH=2
#   FD_SECONDS=3 (no driver)  FD_KEEP=1 keeps the work folder
# Nothing touches the live shell: no Wayland or Hyprland connection, a private
# cache, and `omarchy-shell` is blocked on PATH.
set -e
here=$(cd "$(dirname "$0")" && pwd)
widget=$(realpath "$1"); driver=${2:-}
[ -f "$widget" ] || { echo "usage: framedebug.sh <widget.qml> [driver.qml]" >&2; exit 2; }
# Outside any folder Quickshell watches, or it reloads mid-run.
work=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/framedebug.XXXXXX")
trap '[ -n "$FD_KEEP" ] || rm -r "$work"' EXIT
cp "$here/harness/shell.qml" "$work/"
[ -n "$driver" ] && cp "$(realpath "$driver")" "$work/Driver.qml"
ln -s /usr/share/omarchy/shell/Commons "$work/Commons"
ln -s /usr/share/omarchy/shell/Ui "$work/Ui"
mkdir -p "$work/cache"
module=$(basename "$(dirname "$widget")")
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
  PATH="$here/harness/bin:$PATH" XDG_CACHE_HOME="$work/cache" \
  QT_QPA_PLATFORM="offscreen:configfile=${FD_SCREENS:-$here/harness/screens.json}" QT_QUICK_BACKEND=software \
  FD_WIDGET="$widget" FD_MODULE="${FD_MODULE:-$module}" \
  timeout "${FD_TIMEOUT:-60}" qs -p "$work/shell.qml" 2>&1 \
  | sed -u 's/\x1b\[[0-9;]*m//g' | grep --line-buffered -E "FD |WARN|ERROR|TypeError|ReferenceError" \
  | grep --line-buffered -v "window masks" | sed -u -E 's/^ *(INFO|WARN|ERROR|DEBUG)( [a-z.]+)?: //; s/^qml: //'
[ -n "$FD_KEEP" ] && echo "work folder kept: $work" >&2
exit 0
