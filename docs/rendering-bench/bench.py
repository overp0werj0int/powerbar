#!/usr/bin/env python3
# bench.py <plugin-dir> <label> [runs] [scenario,...]
# Runs every scenario `runs` times and prints the medians. Each run also leaves
# a geometry dump (and the saved layout, for drag scenarios) in
# <work>/geo/<label>-<scenario>.txt, so two versions can be compared exactly.
import json, os, statistics, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
work = os.environ.get("BENCH_WORK") or os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "powerbar-bench")
src, label = sys.argv[1], sys.argv[2]
runs = int(sys.argv[3]) if len(sys.argv) > 3 else 3
only = sys.argv[4].split(",") if len(sys.argv) > 4 else None
scenarios = [("startup", "0"), ("idle", "0"), ("commit", "0"), ("commit", "1"), ("drag", "1"), ("churn", "1"),
    ("settings", "0"), ("drawer", "1"), ("activity", "1"), ("flash", "1"), ("dnd", "1"), ("dnd", "0"), ("prefs", "1"), ("inline", "0"), ("inline", "1")]
quiet = ("Detected function", "window masks", "not placed in the graphics scene", "sourceSize request")
geo_dir = os.path.join(work, "geo")
os.makedirs(geo_dir, exist_ok=True)
results = {}
for name, anim in scenarios:
    key = name + ("+anim" if anim == "1" else "")
    if only and key not in only: continue
    rows = []
    for r in range(runs):
        env = dict(os.environ, BENCH_SHOT=os.path.join(geo_dir, f"{label}-{key}.png"))
        out = subprocess.run([os.path.join(here, "run.sh"), src, name, anim], capture_output=True, text=True, env=env).stdout
        m, cpu, geo = {}, {}, []
        for line in out.splitlines():
            i = line.find("BENCH ")
            if i < 0: continue
            parts = line[i + 6:].split(" ")
            if parts[0] == "CPU": cpu[parts[1]] = int(parts[2])
            elif parts[0] == "GEO": geo.append(" ".join(parts[1:]))
            elif len(parts) >= 2 and parts[0].endswith("_ms"):
                try: m[parts[0]] = float(parts[1])
                except ValueError: pass
        if "before-create" in cpu and "settled" in cpu: m["cpu_startup"] = cpu["settled"] - cpu["before-create"]
        if "settled" in cpu and "end" in cpu: m["cpu_scenario"] = cpu["end"] - cpu["settled"]
        warnings = [l for l in out.splitlines() if ("WARN" in l or "ERROR" in l) and not any(q in l for q in quiet)]
        m["warnings"] = len(warnings)
        rows.append(m)
        open(os.path.join(geo_dir, f"{label}-{key}.txt"), "w").write("\n".join(geo) + "\n\n" + "\n".join(warnings))
    keys = sorted(set(k for r in rows for k in r))
    results[key] = {k: statistics.median([r[k] for r in rows if k in r]) for k in keys}
    print(key, json.dumps(results[key]), flush=True)
json.dump(results, open(os.path.join(work, label + ".json"), "w"), indent=1)
