#!/bin/bash
# validate.sh: everything that must pass before a commit. Offscreen; it never
# touches the running shell.
#   1. node unit tests (tests/*.test.cjs)
#   2. QML tests (tests/qml) against Omarchy's own Commons and Ui
#   3. the startup probe (QtTest over startup bindings that tests/startup-probe.cjs
#      slices out of Bar.qml and LayoutEditor.qml as text; Bar.qml itself is not loaded)
#   4. `omarchy plugin validate` (Omarchy's manifest and plugin checks)
#   5. qmlformat parses every QML file
#   6. no bare palette reference: Qt 6.12's QtQuick has its own Color type,
#      so Omarchy's palette is always Commons.Color (import qs.Commons as Commons)
#   7. the Omarchy contract (tools/omarchy-contract.cjs): every Omarchy line,
#      theme token and type Powerbar relies on is still there; a failure names
#      the Omarchy file and the missing text
# Needs: node, Qt 6 (qmltestrunner, qmlformat), an Omarchy install.
# Exit status is non-zero when any step fails.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OMARCHY="${OMARCHY_PATH:-/usr/share/omarchy}"
QT_BIN="${QT_BIN:-/usr/lib/qt6/bin}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software
failed=0

echo "== node tests"
node --test tests/*.test.cjs >"$TMP/node.log" 2>&1 || failed=1
grep -E "^ℹ (pass|fail)" "$TMP/node.log"
grep -E "^not ok" "$TMP/node.log"

echo "== QML tests"
mkdir -p "$TMP/kit/qs"
ln -s "$OMARCHY/shell/Commons" "$OMARCHY/shell/Ui" "$TMP/kit/qs/"
timeout 300 "$QT_BIN/qmltestrunner" -import tests/qml/imports -import "$TMP/kit" -input tests/qml -o "$TMP/qml.log,txt" >/dev/null 2>&1 || failed=1
grep -E "^Totals|^FAIL" "$TMP/qml.log" | head -20

echo "== startup probe"
mkdir -p "$TMP/probe"
if node tests/startup-probe.cjs "$TMP/probe" >/dev/null; then
  "$QT_BIN/qmltestrunner" -input "$TMP/probe" -o "$TMP/probe.log,txt" >/dev/null 2>&1 || failed=1
  grep -E "^Totals|^FAIL" "$TMP/probe.log"
else
  echo "startup probe could not be prepared"; failed=1
fi

echo "== omarchy plugin validate"
omarchy plugin validate "$ROOT" 2>&1 | tail -1
[ "${PIPESTATUS[0]}" -eq 0 ] || failed=1

echo "== qmlformat"
for f in *.qml; do "$QT_BIN/qmlformat" --normalize "$f" >/dev/null 2>&1 || { echo "qmlformat fails: $f"; failed=1; }; done

echo "== omarchy contract"
node tools/omarchy-contract.cjs "$OMARCHY" || failed=1

echo "== palette references"
bare=$(/usr/bin/grep -rnP '(?<![\w.])Color\.' --include=*.qml --exclude-dir=node_modules . || true)
[ -z "$bare" ] || { echo "bare Color. (use Commons.Color.):"; echo "$bare" | head -20; failed=1; }

[ "$failed" -eq 0 ] && echo "validate: all passed" || echo "validate: FAILED"
exit "$failed"
