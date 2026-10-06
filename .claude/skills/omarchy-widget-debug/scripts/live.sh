#!/bin/bash
# live.sh: the live half of the loop, against the running Omarchy shell.
#   live.sh pid                  the running shell's process id
#   live.sh log                  path of its live log
#   live.sh restart [ipc-target] restart the shell; with a target, confirm it
#                                registered (e.g. powerbar) and show load errors
#   live.sh follow TAG [SECONDS] print new log lines carrying TAG (default 120 s)
#   live.sh grep TAG             every line carrying TAG so far
#   live.sh leftovers DIR [TAG]  debug tags still in the code (default DEBUG)
# Restarting needs HYPRLAND_INSTANCE_SIGNATURE; outside a Hyprland terminal it
# is taken from the newest /run/user/$UID/hypr entry.
set -e
runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
# The Omarchy shell's instance, found by its config path: other Quickshell
# instances (a plugin's preview shell started by another session) can run
# beside it, and the first or newest instance is not necessarily it.
shell_dir=${OMARCHY_PATH:-/usr/share/omarchy}/shell
pid() {
  qs list --all 2>/dev/null | awk -v want="$shell_dir/shell.qml" '
    /Process ID:/ { p = $3 } /Config path:/ { if ($3 == want) { print p; exit } }'
}
logfile() { echo "$runtime/quickshell/by-pid/$(pid)/log.log"; }
case "$1" in
  pid) pid ;;
  log) logfile ;;
  restart)
    export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$runtime/hypr" | head -1)}
    # Omarchy refuses while the session is locked (the lock screen is part of
    # the shell); say so instead of reporting the old shell as restarted.
    if omarchy-hyprland-session-locked 2>/dev/null; then echo "session is locked: not restarting"; exit 1; fi
    before=$(pid)
    out=$(omarchy-restart-shell 2>&1) || true
    [ -n "$out" ] && echo "$out" | grep -v '^$' | head -3
    sleep 5
    p=$(pid); echo "shell pid $p"
    [ "$p" = "$before" ] && { echo "the shell did not restart (same pid)"; exit 1; }
    if [ -n "$2" ]; then
      if qs ipc --pid "$p" show 2>/dev/null | grep -q "target $2"; then echo "$2 is registered"
      else echo "$2 is NOT registered: the shell may have fallen back (check the log)"; fi
    fi
    grep -E "ERROR|TypeError|ReferenceError|unavailable|set multiple times" "$(logfile)" | head -10 || true ;;
  follow)
    timeout "${3:-120}" tail -n0 -f "$(logfile)" | grep --line-buffered "$2" || true ;;
  grep) grep "$2" "$(logfile)" || true ;;
  leftovers)
    grep -rn --include=*.qml --include=*.js "${3:-DEBUG}" "${2:-.}" && exit 1 || echo "no ${3:-DEBUG} tags left" ;;
  *) sed -n '2,11p' "$0"; exit 2 ;;
esac
