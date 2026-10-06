# Recipes

## Record frames inside an app or bench (not a single widget)

When the bug needs the whole bar (zones, drawers, drag), add a recorder to
that app's offscreen host instead of the harness. Powerbar's bench
(`~/Projects/powerbar/docs/rendering-bench`, `run.sh <plugin> <scenario> 1`)
is the worked example: a shim `shell.qml` playing the Omarchy host, stand-in
widgets for the user's layout, and scenarios driven by queued steps.

```qml
property bool rec: false
property string last: ""
property real t0: 0
function frameState() {            // only what the bug is about, rounded
  return slots.filter(visible).map(s => name(s) + ":" + x(s).toFixed(1) + "+" + s.width.toFixed(1)).join(" ")
}
FrameAnimation {
  running: rec
  onTriggered: { var f = frameState(); if (f !== last) { log("FRAME", Date.now() - t0, f); last = f } }
}
// at the moment of interest: t0 = Date.now(); last = frameState(); rec = true
```

Record from just before the action (release, click, config write) until
everything settles plus a margin, then `timeline.py log --settle <ms>`.
Log what the eye judges: island edges and widths, the moving item's
content position (slot x + inset), opacity of things that fade.

Keep temporary scenarios out of the repo: copy the bench file aside, patch,
run, copy it back, `grep -c <scenario> shell.qml` to prove it is gone.

## Emulate the host faithfully

A bug that appears "after a drop" may come from the host's reaction, not
the widget. Make the shim do what the real host does on a config write:
re-register widgets with fresh metadata objects, set the config twice
(write, then file reload 50–60 ms later). Log `host-write` / `host-reload`
on the same timeline as the frames.

## A/B against the last commit or master

```bash
# working tree vs HEAD, same scenario (stash also hides untracked files)
run scenario > new.txt; git stash -q -u; run scenario > old.txt; git stash pop -q
cmp -s new.txt old.txt && echo same
# against master, without touching the working tree
mkdir /tmp/master && git archive master | tar -x -C /tmp/master
```

Compare saved layouts and geometry dumps exactly; timing only as medians of
several runs. A stash also stashes the bench file: restore patched scenario
files before stashing, or the "old" run has no scenario.

## Hit-test census inside an app

For "clicks open the wrong thing": for every visible item, sweep points
across it and ask the app's own hit test who takes the press; report every
point where the owner is not the item.

```js
for (var s of slots) if (s.visible && s.width > 0)
  for (var x = 2; x < s.width; x += 4) {
    var t = clickTargetAt(s, x, s.height / 2), owner = ownerOf(t)
    if (t && owner !== s) log("STEAL", name(s), x, "->", name(owner))
  }
```

Run it at rest and in each state (expanded, after collapse, after a drawer
opened and closed); compare with master to see whether it is a regression.

## Live: tagged logging, the user reproduces

1. Add `console.info("[DEBUG-<topic>] ...")` at decisions, not in hot paths:
   presses, drag start/finish, open/close with reason, the state a decision
   read (opened, keyboardMode, grabReady, the drop target).
2. Load offscreen first (a broken file makes the shell fall back).
3. `live.sh restart <ipc-target>`; tell the user exactly what to do, once.
4. `live.sh grep '[DEBUG-<topic>]'`, read it as a timeline; look for the step
   that is missing (a press with no drag start, a drag with no finish).
5. Remove every tag (`live.sh leftovers <repo> DEBUG`), re-run checks,
   restart.

Never move the user's pointer or send synthetic input while they are active.
A grim capture of just the bar strip (`grim -g "0,0 1512x60"`) shows state
without touching anything.

## Find who calls something

`console.trace()` inside the function prints the QML stack including signal
handlers (`expression for onHoveredChanged (Bar.qml:4232)`);
`new Error().stack` does not. Remove it afterwards.

## Profile the live shell

```bash
hyprctl dispatch 'hl.dsp.exec_cmd("env QS_DISABLE_FILE_WATCHER=1 QS_NO_RELOAD_POPUP=1 quickshell -n --debug 3768 -p /usr/share/omarchy/shell")'
/usr/lib/qt6/bin/qmlprofiler --interactive -a localhost -p 3768 -o trace.qtd   # r to record, q to stop
# restore the normal shell afterwards: live.sh restart
```

## When offscreen and live disagree

Offscreen windows never unmap and items keep `visible: true`, so bugs that
come from the compositor (remaps, hidden windows, DPMS) do not reproduce
there. Add a probe tagged `DEBUG-<NAME>` that logs the suspect values at a few
fixed delays after the trigger (0, 150, 500, 1500 ms), load offscreen, restart,
ask the user to do the one action and take a screenshot, then read
`live.sh grep DEBUG-<NAME>` against the picture. Keep the probe through the
fix attempt (log the new guard's state too) and remove it with
`live.sh leftovers . DEBUG-<NAME>` once the user confirms.

## Audit an invariant across every configuration

When one widget shows a geometry bug, check the rule for every slot and
configuration before fixing the one case. In a temporary copy of the bench,
log one line per visible slot in `finish()` and only the failures:

```js
var p = a.cellPlace, ink = a.ink
if (p.inkStart < -0.5 || p.inkStart + p.shown > p.extent + 0.5) problems.push("ink outside slot")
if (p.spill < -0.5) problems.push("highlight shorter than ink")
```

Loop the config with `BENCH_SHELL_JSON` (position top/left x
`powerbarSpacingMode` slots/gaps x `powerbarLargeBar`), run the same loop on
`git archive HEAD` extracted to a temp folder for the before numbers, and
report both.

## A config change as a scenario

Hide-and-show, style switches and theme-dependent settings: write the config
the way Preferences does (`bar.writeConfig(fn)` then `bar.flushConfigWrites()`),
wait about a second per step, and log registry sizes and anything left
pointing at destroyed objects. Repeat the cycle three times; the counts must
come back the same.

## Checks before telling the user it works

- Pure rules (placement, ordering, boundaries) in a `.js` model with node
  tests, fuzzed where a property holds for every input.
- `qmlformat` on every touched QML file; QML tests offscreen; plugin validate.
- The A/B: saved layouts identical where behaviour should not change.
- Frames clean (`timeline.py` exit 0) for the scenario that was broken.
- Live restart registers the plugin and the log has no errors.
