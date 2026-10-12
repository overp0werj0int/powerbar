#!/bin/bash
# BuildStamp.sh DIR: what the Powerbar code in DIR is, as one JSON line:
#   {"digest":"<12 hex>","commit":"<short sha or empty>","dirty":true|false}
# The digest covers every file the shell loads (the top-level *.qml, *.js,
# *.sh and manifest.json), names and contents, so a copy (omarchy plugin add,
# a box) and the checkout it came from agree. The bar runs this once when it
# loads (`omarchy-shell powerbar build`); tools/build-check.sh runs it on the
# checkout and compares, so a shell still running older code is caught.
set -u
dir=${1:?usage: BuildStamp.sh DIR}
cd "$dir" 2>/dev/null || { echo '{"digest":"","commit":"","dirty":false}'; exit 1; }
files=$(LC_ALL=C command find . -maxdepth 1 -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name manifest.json \) | LC_ALL=C sort)
digest=$(printf '%s\n' "$files" | while IFS= read -r f; do printf '%s %s\n' "$f" "$(sha256sum < "$f" | cut -c1-64)"; done | sha256sum | cut -c1-12)
commit="" dirty=false
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  commit=$(git rev-parse --short=7 HEAD 2>/dev/null || true)
  # Only the loaded files count: an edited doc or test is not a different build.
  # shellcheck disable=SC2086
  [ -n "$(printf '%s\n' "$files" | xargs -d '\n' git status --porcelain -- 2>/dev/null)" ] && dirty=true
fi
printf '{"digest":"%s","commit":"%s","dirty":%s}\n' "$digest" "$commit" "$dirty"
