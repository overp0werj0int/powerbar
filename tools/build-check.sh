#!/bin/bash
# build-check.sh: is the running Powerbar this checkout's code?
#   tools/build-check.sh            the shell on this desktop
#   tools/build-check.sh -b BOX     the shell in an omabox box
# Compares `omarchy-shell powerbar build` (BuildStamp.sh, run as the bar
# loaded) with BuildStamp.sh run on the checkout now. Exit 0 current, 1 stale
# (the shell runs other code: restart it), 2 no answer (Powerbar not running,
# or the shell still starting). Agents on a guarded desktop: omabox host -- …
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ipc=(omarchy-shell powerbar build)
[ "${1:-}" = "-b" ] && [ -n "${2:-}" ] && ipc=(omabox run -b "$2" -- omarchy-shell powerbar build)

here=$(bash "$ROOT/BuildStamp.sh" "$ROOT")
running=$("${ipc[@]}" 2>/dev/null)
# One field of a JSON object on stdin, as plain text (console.log would colour
# a boolean when FORCE_COLOR is set).
field() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let v="";try{v=JSON.parse(s)[process.argv[1]]??""}catch(e){}process.stdout.write(String(v)+"\n")})' "$1"; }

want=$(field digest <<<"$here")
got=$(field digest <<<"$running")
if [ -z "$got" ]; then
  echo "no answer: Powerbar is not running there, or the shell is still starting${running:+ ($running)}"
  exit 2
fi
# "69c7a50", "69c7a50 + edits" (loaded files differ from the commit), or "no git".
desc() {
  local commit dirty
  commit=$(field commit <<<"$1")
  dirty=$(field dirty <<<"$1")
  if [ -z "$commit" ]; then echo "no git"
  elif [ "$dirty" = true ]; then echo "$commit + edits"
  else echo "$commit"
  fi
}
if [ "$got" = "$want" ]; then
  echo "current: $got ($(desc "$running"), loaded $(field loadedAt <<<"$running"))"
  exit 0
fi
echo "stale: the shell runs $got ($(desc "$running"), loaded $(field loadedAt <<<"$running")); the checkout is $want ($(desc "$here")). Restart the shell."
exit 1
