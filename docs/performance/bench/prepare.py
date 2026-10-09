#!/usr/bin/env python3
# prepare.py <plugin-dir> <work-dir>
# Builds an offscreen-runnable copy of Powerbar in <work-dir>: layer-shell
# windows become plain windows (BenchPanel), the layout comes from the user's
# shell.json, and Omarchy's own Commons and Ui modules are linked in unchanged.
# The work dir must sit outside the plugin: Quickshell reloads on file changes.
import json, os, re, shutil, sys
src, work = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
pb = os.path.join(work, "Powerbar")
shutil.rmtree(pb, ignore_errors=True)
os.makedirs(pb)
for name in os.listdir(src):
    if name.endswith((".qml", ".js")) or name == "qmldir":
        shutil.copy(os.path.join(src, name), pb)
for name in ("BenchPanel.qml", "BenchAnchors.qml", "BenchMargins.qml", "BenchPrefs.qml"):
    shutil.copy(os.path.join(here, name), pb)
shutil.copy(os.path.join(here, "shell.qml"), work)
for name in ("Bar.qml", "Preferences.qml"):
    p = os.path.join(pb, name)
    s = open(p).read()
    s = re.sub(r"\bPanelWindow\s*\{", "BenchPanel {", s)
    if os.environ.get("BENCH_STUB_PREFS"):
        s = s.replace("Preferences { id: preferencesPane; bar: root }", "BenchPrefs { id: preferencesPane; bar: root }")
    s = s.replace("implicitWidth: root.vertical ? root.barExtent + drawerExtent : 0",
                  "implicitWidth: root.vertical ? root.barExtent + drawerExtent : (screen ? screen.width : 1512)")
    s = s.replace("implicitHeight: root.vertical ? 0 : root.barExtent + drawerExtent",
                  "implicitHeight: root.vertical ? (screen ? screen.height : 945) : root.barExtent + drawerExtent")
    s = re.sub(r"(?m)^\s*WlrLayershell\.[^\n]*\n", "", s)
    # Offscreen, a window that shows becomes active and Qt cancels the bar's
    # pointer grab; the real ghost is a layer surface that never takes focus.
    if os.environ.get("BENCH_NO_GHOST"):
        s = s.replace('visible: active && String(root.barDragImageUrl) !== ""', "visible: false")
    open(p, "w").write(s)
shell_json = os.environ.get("BENCH_SHELL_JSON") or os.path.expanduser("~/.config/omarchy/shell.json")
bar = json.load(open(shell_json))["bar"]
bar["id"] = "p0werj0int.powerbar"  # Powerbar writes only a config that names it (BarModel.ownsBarConfig)
json.dump(bar, open(os.path.join(work, "bar.json"), "w"), indent=1)
for link in ("Commons", "Ui"):
    l = os.path.join(work, link)
    if not os.path.islink(l): os.symlink("/usr/share/omarchy/shell/" + link, l)
