#!/usr/bin/env python3
"""timeline.py [log] [--after MS] [--before MS] [--keys REGEX] [--jump PX] [--settle MS]

Reads FRAME lines (one per frame in which something changed) and reports the
motion bugs that per-frame recording exposes:

  wobble   a value leaves the span between its first and last value and
           comes back (an island swelling then shrinking, an icon sliding
           past its spot and back)
  jump     a single-frame step much larger than the steps around it
  jitter   a value alternating by about a pixel (rounding under animation)
  late     a change after --settle MS (geometry that should be at rest)
  flicker  an item that disappears and reappears

Accepted FRAME formats, mixed freely:
  FRAME <ms> key=x,y,WxH[,oOPACITY][,hidden] ...   (framedebug.sh harness)
  FRAME <ms> key:x+w ... / KEY:x+w                 (bar-style recorders)
Lines may carry a log prefix (INFO qml: BENCH ...). Reads stdin with no file.
"""
import argparse, re, sys
from collections import defaultdict

ap = argparse.ArgumentParser()
ap.add_argument("log", nargs="?")
ap.add_argument("--after", type=float, default=0, help="ignore frames before this time")
ap.add_argument("--before", type=float, default=float("inf"), help="ignore frames after this time")
ap.add_argument("--keys", default="", help="only keys matching this regex")
ap.add_argument("--jump", type=float, default=8, help="a jump is a step at least this large (px)")
ap.add_argument("--settle", type=float, default=None, help="flag any change after this time (ms)")
args = ap.parse_args()

num = re.compile(r"-?\d+(?:\.\d+)?")
series = defaultdict(list)  # (key, field) -> [(t, value)]
present = defaultdict(list)  # key -> [(t, bool)]
keys_seen = set()
frames = 0
for line in (open(args.log) if args.log else sys.stdin):
    m = re.search(r"FRAME (\d+(?:\.\d+)?) (.*)$", line.strip())
    if not m:
        continue
    t = float(m.group(1))
    if t < args.after or t > args.before:
        continue
    frames += 1
    here = set()
    for tok in m.group(2).split():
        sep = tok.find("=") if "=" in tok else tok.find(":")
        if sep <= 0:
            continue
        key, val = tok[:sep], tok[sep + 1:]
        if args.keys and not re.search(args.keys, key):
            continue
        nums = [float(n) for n in num.findall(val)]
        if "=" in tok:
            names = ["x", "y", "w", "h"]
            fields = dict(zip(names, nums[:4]))
            o = re.search(r",o(-?\d+(?:\.\d+)?)", val)
            fields["opacity"] = float(o.group(1)) if o else 1.0
            hidden = "hidden" in val
        else:
            fields = dict(zip(["x", "w"], nums[:2]))
            hidden = False
        here.add(key)
        keys_seen.add(key)
        present[key].append((t, not hidden))
        for f, v in fields.items():
            series[(key, f)].append((t, v))
    for key in keys_seen - here:
        present[key].append((t, False))

findings = []
for (key, field), pts in series.items():
    vals = [v for _, v in pts]
    if len(vals) < 2:
        continue
    first, last = vals[0], vals[-1]
    lo, hi = min(first, last), max(first, last)
    over = max(max(vals) - hi, lo - min(vals))
    if over >= 1.0:
        tpeak = pts[max(range(len(vals)), key=lambda i: max(vals[i] - hi, lo - vals[i]))][0]
        findings.append((3, "wobble", key, field, f"leaves {first:g}->{last:g} by {over:.1f} (peak at {tpeak:g} ms)"))
    steps = [(pts[i][0], vals[i] - vals[i - 1]) for i in range(1, len(vals))]
    for i, (t, d) in enumerate(steps):
        nb = [abs(s) for _, s in steps[max(0, i - 2):i] + steps[i + 1:i + 3]]
        typical = max(nb) if nb else 0
        if abs(d) >= args.jump and abs(d) > 3 * max(typical, 0.5):
            findings.append((2, "jump", key, field, f"{d:+.1f} in one frame at {t:g} ms (neighbours <= {typical:.1f})"))
    signs = [1 if d > 0 else -1 for _, d in steps if abs(d) > 0.05]
    flips = sum(1 for a, b in zip(signs, signs[1:]) if a != b)
    small = all(abs(d) <= 1.5 for _, d in steps if abs(d) > 0.05)
    if flips >= 3 and small:
        findings.append((1, "jitter", key, field, f"{flips} reversals of about a pixel"))
    if args.settle is not None:
        late = [t for t, d in steps if abs(d) > 0.05 and t > args.settle]
        if late:
            findings.append((2, "late", key, field, f"{len(late)} changes after {args.settle:g} ms (last at {late[-1]:g} ms)"))
for key, pts in present.items():
    seen = [p for _, p in pts]
    gaps = sum(1 for a, b in zip(seen, seen[1:]) if a and not b)
    back = sum(1 for a, b in zip(seen, seen[1:]) if not a and b)
    if gaps and back:
        findings.append((2, "flicker", key, "-", f"disappears {gaps}x and comes back {back}x"))

print(f"{frames} frames with changes, {len(keys_seen)} keys")
if not findings:
    print("clean: no wobble, jump, jitter, late motion or flicker")
    sys.exit(0)
findings.sort(key=lambda f: (-f[0], f[2], f[3]))
w = max(len(f[2]) for f in findings)
for _, kind, key, field, text in findings:
    print(f"{kind:8} {key:<{w}} {field:8} {text}")
sys.exit(1)
