#!/bin/bash
# prof.sh <plugin-dir> <scenario> <animations 0|1> <out.qtd>
# Records a QML profiler trace of one scenario; analyze.py summarises it.
B=$(cd "$(dirname "$0")" && pwd)
PORT=$((30000 + RANDOM % 20000))
W=${BENCH_WORK:-${XDG_RUNTIME_DIR:-/tmp}/powerbar-bench}
mkdir -p "$W"
BENCH_QS_ARGS="--debug $PORT --waitfordebug" "$B/run.sh" "$1" "$2" "$3" > "$W/prof-app.log" &
APP=$!
sleep 1.5
timeout 150 /usr/lib/qt6/bin/qmlprofiler -a localhost -p $PORT -o "$4" > "$W/prof-tool.log" 2>&1
wait $APP
echo "app log: $W/prof-app.log"
