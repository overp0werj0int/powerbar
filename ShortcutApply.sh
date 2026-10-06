#!/usr/bin/env bash
# Writes Powerbar's shortcut block into the user's Hyprland bindings
# (ShortcutStore.qml runs it; tests/shortcut-apply.test.cjs checks it).
#
#   $1 the block ("" removes it)   $2 $3 its begin and end markers
#   $4 $5 the markers of the old loader in hyprland.lua (removed if whole)
#
# The block goes between its markers in bindings.lua, or at the end the first
# time; every other line stays as it is on disk now. Nothing is written unless
# the markers are whole (none, or one begin with one end after it), and the
# file is replaced in one step (a sibling file moved over it), so a failure
# part way leaves it as it was. Hyprland then reloads; a new config error puts
# the file back and answers "error <Hyprland's message>". Anything else that
# stops the write answers "fail <reason>" with exit status 2; success, "ok".
set -u

fail() { rm -f "${next:-}" "${prev:-}"; echo "fail $*"; exit 2; }

# Whether $1's markers $2/$3 are whole.
paired() {
  local b e lb le
  b=$(grep -cxF -- "$2" "$1") e=$(grep -cxF -- "$3" "$1")
  [ "$b" = 0 ] && [ "$e" = 0 ] && return 0
  [ "$b" = 1 ] && [ "$e" = 1 ] || return 1
  lb=$(grep -nxF -- "$2" "$1" | cut -d: -f1) le=$(grep -nxF -- "$3" "$1" | cut -d: -f1)
  [ "$le" -gt "$lb" ]
}

# Writes file $1 into file $4 with the lines from marker $2 to marker $3
# replaced by block $5 (none if empty), appended when $1 has no block.
render() {
  BLOCK="$5" awk -v b="$2" -v e="$3" '
    $0 == b { skip = 1; if (ENVIRON["BLOCK"] != "" && !done) { print ENVIRON["BLOCK"]; done = 1 }; next }
    skip { if ($0 == e) skip = 0; next }
    { print }' "$1" > "$4" || return 1
  if [ -n "$5" ] && ! grep -qxF -- "$2" "$1"; then
    if [ -s "$4" ]; then printf '\n' >> "$4" || return 1; fi
    printf '%s\n' "$5" >> "$4" || return 1
  fi
}

c=${POWERBAR_HYPR_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr}
mkdir -p "$c" || fail "cannot create $c"
f="$c/bindings.lua"
[ -e "$f" ] || : > "$f" || fail "cannot create $f"
# A linked bindings.lua (dotfiles) is written where it points, link kept.
f=$(readlink -f -- "$f") || fail "cannot resolve $c/bindings.lua"
[ -r "$f" ] && [ -w "$f" ] || fail "$f is not writable"
paired "$f" "$2" "$3" || fail "$f has a damaged Powerbar block (a marker without its pair); fix or remove it by hand"

dir=$(dirname -- "$f")
prev="$dir/.bindings.lua.powerbar-prev" next="$dir/.bindings.lua.powerbar-new"
cp -p -- "$f" "$prev" || fail "cannot back up $f"
render "$f" "$2" "$3" "$next" "$1" || fail "cannot write $next"
chmod --reference="$f" -- "$next" 2>/dev/null
mv -f -- "$next" "$f" || fail "cannot replace $f"
next=""

# The loader of the old powerbar.lua, only when its block is whole.
main="$c/hyprland.lua"
if [ -f "$main" ] && [ -w "$main" ] && grep -qxF -- "$4" "$main" && paired "$main" "$4" "$5"; then
  main=$(readlink -f -- "$main")
  cp -p -- "$main" "$main.bak.$(date +%Y%m%d%H%M%S)-powerbar" &&
    render "$main" "$4" "$5" "$main.powerbar-new" "" &&
    mv -f -- "$main.powerbar-new" "$main" || rm -f "$main.powerbar-new"
fi
rm -f -- "$c/powerbar.lua"

before=$(hyprctl configerrors 2>/dev/null)
hyprctl reload config-only >/dev/null 2>&1
sleep 0.3
after=$(hyprctl configerrors 2>/dev/null)
if [ "$after" != "$before" ] && [ -n "$(printf '%s' "$after" | tr -d '[:space:]')" ]; then
  mv -f -- "$prev" "$f"
  hyprctl reload config-only >/dev/null 2>&1
  echo "error $(printf '%s' "$after" | head -1)"
  exit 1
fi
rm -f -- "$prev"
echo ok
