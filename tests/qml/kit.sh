#!/bin/bash
# kit.sh DIR: the import tree the QML tests run against, built in DIR.
#   qs/        Omarchy's Ui and the qs.Commons singletons Powerbar uses (Qt
#              6.12 loads every type a module lists, and Omarchy's others need
#              Quickshell services the test runner has no stand-in for)
#   Powerbar/  this checkout as a module with a qmldir, so its singletons
#              (Ink, Gap, Round, Tuning) resolve as Quickshell resolves them
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OMARCHY="${OMARCHY_PATH:-/usr/share/omarchy}"
DIR="$1"
mkdir -p "$DIR/qs/Commons" "$DIR/Powerbar"
ln -s "$OMARCHY/shell/Ui" "$DIR/qs/"
ln -s "$OMARCHY"/shell/Commons/* "$DIR/qs/Commons/"
rm "$DIR/qs/Commons/qmldir"
{ echo "module qs.Commons"; grep -E "^singleton (Border|Color|Style|Util) " "$OMARCHY/shell/Commons/qmldir"; } >"$DIR/qs/Commons/qmldir"
ln -s "$ROOT"/*.qml "$ROOT"/*.js "$ROOT"/*.json "$ROOT/shaders" "$DIR/Powerbar/"
{
  echo "module Powerbar"
  for f in "$ROOT"/*.qml; do
    n="$(basename "$f" .qml)"
    if grep -q "^pragma Singleton" "$f"; then echo "singleton $n 1.0 $n.qml"; else echo "$n 1.0 $n.qml"; fi
  done
} >"$DIR/Powerbar/qmldir"
