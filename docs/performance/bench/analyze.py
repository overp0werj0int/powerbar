#!/usr/bin/env python3
# analyze.py <trace.qtd> <app.log> [top] [from] [to]
# Self and inclusive time per QML location between two BENCH log lines
# (default: from "CPU settled" to "CPU end", the scenario itself).
import sys, re, collections
import xml.etree.ElementTree as ET
trace, applog = sys.argv[1], sys.argv[2]
top = int(sys.argv[3]) if len(sys.argv) > 3 else 40
lines = [l for l in open(applog, errors="replace") if "BENCH " in l]
smark = sys.argv[4] if len(sys.argv) > 4 else "CPU settled"
emark = sys.argv[5] if len(sys.argv) > 5 else "CPU end"
marker = next(i for i, l in enumerate(lines) if smark in l)
end_marker = next((i for i, l in enumerate(lines) if emark in l), None)
events = {}
ranges = []
msg = []
for ev, el in ET.iterparse(trace, events=("end",)):
    if el.tag == "event":
        events[int(el.get("index"))] = (el.findtext("type"), el.findtext("filename") or "", el.findtext("line") or "", el.findtext("details") or "")
        el.clear()
    elif el.tag == "range":
        idx = int(el.get("eventIndex")); st = int(el.get("startTime")); d = el.get("duration")
        t = events.get(idx, ("?",))[0]
        if t == "DebugMessage" and events[idx][1].endswith("shell.qml"): msg.append(st)
        elif d is not None and t in ("Binding", "Javascript", "HandlingSignal", "Creating", "Compiling"):
            ranges.append((st, int(d), idx))
        el.clear()
start = msg[marker]
stop = msg[end_marker] if end_marker is not None and end_marker < len(msg) else float("inf")
ranges = [r for r in ranges if start <= r[0] < stop]
ranges.sort(key=lambda r: (r[0], -r[1]))
selft = collections.Counter(); incl = collections.Counter(); count = collections.Counter()
stack = []
total = 0
for st, d, idx in ranges:
    en = st + d
    while stack and stack[-1][1] <= st: stack.pop()
    if stack: selft[stack[-1][2]] -= d
    else: total += d
    selft[idx] += d; incl[idx] += d; count[idx] += 1
    stack.append((st, en, idx))
print("window %.1f ms, top-level QML time %.1f ms" % ((min(stop, ranges[-1][0]) - start) / 1e6 if ranges else 0, total / 1e6))
def name(idx):
    t, f, l, det = events[idx]
    return "%-14s %s:%s %s" % (t, f.replace("qs:@/qs/", ""), l, det[:60].replace("\n", " "))
print("%9s %9s %8s  %s" % ("self ms", "incl ms", "count", "location"))
for idx, v in selft.most_common(top):
    print("%9.1f %9.1f %8d  %s" % (v / 1e6, incl[idx] / 1e6, count[idx], name(idx)))
