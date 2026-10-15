#!/bin/bash
# benchdiff.sh: does a change move anything? The offscreen bench's geometry
# (BENCH GEO lines) and errors, before and after, scenario by scenario.
#
#   benchdiff.sh BASE_DIR CHANGED_DIR [SCENARIO...]   (default: drawer dnd inline)
#
# BASE_DIR is usually the main checkout (master), CHANGED_DIR the worktree.
# Runs the bench's run.sh ($POWERBAR_BENCH, by default ../powerbar-skill/bench
# beside this checkout; kept outside the plugin) with animations on, keeps the logs in
# $BENCH_WORK/diff (default $XDG_RUNTIME_DIR/powerbar-bench), prints the
# line counts and the first differing lines. Offscreen: never touches a shell.
#
# Noise seen run to run on master itself: drawer 0.1 px, inline 0.1-0.4 px in
# mid-motion samples, and dnd alternates between two outcomes of its fit line
# (handles null vs set). Re-run the base when a difference looks like that.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BENCH=${POWERBAR_BENCH:-$ROOT/../powerbar-skill/bench}
[ -x "$BENCH/run.sh" ] || [ -f "$BENCH/run.sh" ] || { echo "benchdiff.sh: no bench at $BENCH (set POWERBAR_BENCH)" >&2; exit 2; }
A=${1:?usage: benchdiff.sh BASE_DIR CHANGED_DIR [SCENARIO...]}; Z=${2:?changed dir}; shift 2
[ $# -gt 0 ] || set -- drawer dnd inline
W=${BENCH_WORK:-${XDG_RUNTIME_DIR:-/tmp}/powerbar-bench}; mkdir -p "$W/diff"
for sc in "$@"; do
  for side in base:"$A" changed:"$Z"; do
    BENCH_WORK=$W bash "$BENCH/run.sh" "${side#*:}" "$sc" 1 > "$W/diff/$sc-${side%%:*}.log" 2>&1
  done
  a=$(grep -E 'GEO|rror' "$W/diff/$sc-base.log"); b=$(grep -E 'GEO|rror' "$W/diff/$sc-changed.log")
  if [ "$a" = "$b" ]; then echo "== $sc: same ($(echo "$a" | grep -c .) lines)"
  else
    echo "== $sc: differs (base $(echo "$a" | grep -c .), changed $(echo "$b" | grep -c .) lines; errors: $(echo "$b" | grep -c rror))"
    diff <(echo "$a") <(echo "$b") | head -12
  fi
done
