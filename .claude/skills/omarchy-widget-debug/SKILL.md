---
name: omarchy-widget-debug
description: Frame-by-frame debugging for Omarchy Quickshell (QML) bar widgets, drawers and plugins such as Powerbar. Use when something visibly misbehaves for a moment — a wobble, a slide or jump after a drop, flicker, an island that swells and shrinks, an icon that lands in the wrong place — or when input goes wrong: clicks opening the wrong widget, a part of a row that will not drag, hover reaching hidden things, a drag that freezes the bar, focus that will not return to other windows. Gives an offscreen harness that loads any bar widget and records every frame that changes, a press-taker probe, a timeline analyser that flags wobble/jump/jitter/late motion, and the live-logging loop for bugs only the real desktop shows.
---

# Omarchy widget debugging, frame by frame

Most widget bugs that users describe as "it wobbles", "it slides again",
"it froze" or "it opened the wrong thing" last a few frames or depend on which
item takes a press. Reading code rarely finds them; recording does. This skill
is the loop that found and fixed a dozen of them in Powerbar, and the tools it
used.

Companion skills: `omarchy-widget-ux` (how it should behave), `diagnosing-bugs`
(the general discipline), `omarchy` (desktop config).

## The loop

1. **Name the symptom precisely.** What moves, from where to where, when (on
   release, after a config write, after a group opens), and how to make it
   happen. Ask for a screenshot if the user has one (`ls -t ~/Pictures`).
2. **Pick the instrument** (table below). Offscreen first: it is
   repeatable, needs nothing from the user, and can be compared with master.
3. **Record the bad case.** Frames from just before the action until well
   after it settles. Run `timeline.py`; read the raw FRAME lines around the
   flagged time too.
4. **Explain the signature before changing code.** Match it against
   `references/bug-catalogue.md`. The fix should explain every number you
   saw (6.7 px swell = 41 px fallback gap − 25 px cell + easing).
5. **Fix at the cause**, in the smallest place. Pure rules go into a `.js`
   model with node tests.
6. **Re-record**: the same scenario must come back clean (`timeline.py`
   exit 0), and an A/B against HEAD or master must show behaviour that should
   not change did not (saved layouts identical).
7. **Confirm live** when the bug involves real input, hover, focus or the
   compositor: tagged logs, the user reproduces once, read the log
   (`references/recipes.md`, "Live").
8. **Clean up**: remove probes and temporary scenarios (`live.sh leftovers`),
   rerun the checks, restart the shell, report with the numbers.

## Which instrument

| Symptom | Instrument |
| --- | --- |
| Something moves that should not; a jump, slide, swell, flicker | Frame recording + `timeline.py` |
| One widget's own motion or layout | `framedebug.sh <widget.qml> [driver]` (harness) |
| Bar-level (zones, drawers, drags, config writes) | A recorder in the app's offscreen bench (recipes) |
| Clicks open the wrong widget; part of a row is dead | Press-taker probe (`h.census`) or an in-app hit census |
| Freezes, stuck states, focus, hover, real pointer paths | Tagged live logging; the user reproduces |
| "Who calls this?" | `console.trace()` in the function (shows handler frames) |
| Slowness, hitches | `qmlprofiler` on the live shell, or the bench's timings |

## The harness: one widget, offscreen

```bash
S=~/.claude/skills/omarchy-widget-debug/scripts
$S/framedebug.sh ~/.config/omarchy/plugins/<id>/BarWidget.qml [my-driver.qml] > run.log
$S/timeline.py run.log --after 200 --settle 1500     # exit 1 when it finds something
```

- Loads the widget as the Omarchy bar does: `bar` is a real `PluginBarApi`
  (qs.Ui) with logging stubs (`CALL tooltip|requestPopout|run …`),
  `moduleName`, `settings` (`FD_SETTINGS='{…}'`). `FD_BAR`, `FD_VERTICAL=1`.
- Records `FRAME <ms> key=x,y,WxH[,oOpacity][,hidden] …` whenever any watched
  item changes: the widget and its children by default (`FD_DEPTH=2` for
  deeper), or named items (`FD_WATCH=objectName,…`; give the items you care
  about an `objectName`).
- A driver (`scripts/examples/Driver.qml`) is a list of timed steps with the
  harness as `h`: change properties, call widget functions, `h.census(tag)`.
  `HIT <tag> <px> press: <who takes a press> | top: <topmost item>`: when
  the two differ, the topmost item lets the press through; when the press
  taker is not the item you expect, that is the bug.
- Nothing reaches the live shell (no Wayland/Hyprland, private cache,
  `omarchy-shell` blocked). Limits: no hover or real pointer offscreen;
  `PanelWindow` panels cannot load (no offscreen backend), so panels are
  tested live.

## timeline.py

Reads FRAME lines (the harness format, or `key:x+w` from bar recorders) and
reports per key and field:

- `wobble`: leaves the span between its first and last value and comes back
- `jump`: one step much larger than its neighbours (`--jump` px)
- `jitter`: about a pixel back and forth, repeatedly
- `late`: changes after `--settle` ms
- `flicker`: disappears and comes back

A deliberate change shows up too (a jump where you set a property); read
findings against what the driver did.

## Live

`scripts/live.sh restart <ipc-target>` (restarts with the Hyprland signature
set, confirms the plugin registered, prints load errors; `live.sh pid` finds
Omarchy's shell by its config path, since other Quickshell instances such as
a plugin's preview shell can run beside it), `live.sh grep TAG`,
`live.sh follow TAG 120`, `live.sh leftovers <repo>`. Full procedure and the
profiling recipe: `references/recipes.md`.

**A locked session:** the lock screen is part of the Omarchy shell. Never
restart the shell while it is locked (the log's last `omarchy lock` line says
`secure=true`, and a screenshot shows the lock view); a restart could drop the
lock. File edits don't reload the live shell, so keep working offscreen and
leave the live checks for when the user is back. A closed lid powers the panel
off (`dpms` false) and `grim` waits forever; `hyprctl dispatch
'hl.dsp.dpms({action="enable"})'` wakes it, and turn it back off after.

**Real input offscreen:** the rendering bench can drive a real pointer and real
keys through QtTest without a compositor: put `import QtTest` and
`TestCase { id: pointer; when: false }` in the bench shell, then
`pointer.mouseMove(window.contentItem, x, y)` delivers true hover (handlers,
`containsMouse`, tooltips) and `pointer.keyClick(Qt.Key_Backtab,
Qt.ShiftModifier)` goes through shortcuts and `Keys` like a keyboard. Powerbar's
bench has `hover`, `tooltip`, `prefskeys`, `toggle` and `shortcut` scenarios
built this way. A tooltip window that opens offscreen can steal the pointer
from the bar; on Wayland it opens beside it.

**Driving the live desktop yourself** (when the user hands it over):
`hyprctl dispatch 'hl.dsp.cursor.move({ x = X, y = Y })'` moves the real
pointer, but a warp inside the same surface is not delivered until the next
pointer event; enter the surface from outside (a point off the bar, then the
target) to get a clean enter at the target. `wtype` types into the focused
surface (`-M shift -k ISO_Left_Tab` for a real Shift+Tab, `-P Shift_L` for the
Shift press itself), but its virtual keyboard fires no Hyprland binds and
`hl.is_key_down` does not see its keys: call the bind's command directly, and
leave held-key checks to a physical keyboard. Screenshot each step with
`grim -g` (logical coordinates) and make a contact sheet; log state with a
temporary tag and remove it before committing.

## Rules learned the hard way

- Load offscreen before every live restart: a duplicate handler or a missing
  import makes the shell fall back to the stock bar.
- Record what the eye judges (island edges, the moving item's content
  position), rounded to 0.1 px, and only when it changes.
- Never let in-flight geometry depend on state the commit clears.
- Commit what the preview shows; never recompute at release.
- A gap and the item that replaces it swap in one frame.
- A handler that drives a gesture must outlive the gesture.
- Scope hit tests to the item that was pressed.
- Offscreen artefacts are not bugs (pointer at 0,0, no hover); confirm odd
  offscreen behaviour live before fixing it.
- Ask the user to reproduce once, with exact steps; read the log as a
  timeline and look for the missing step.
- Freeze measurements before hiding a window; hidden items report invisible
  live but not offscreen (bug catalogue: blur toggle).
- One widget's geometry bug is usually a rule's: audit the invariant over
  every slot, edge, spacing mode and bar size before and after the fix
  (recipes). ScratchPeek's overflow was every side-bar stack.
- Merge-time conflicts between fix branches that share a hunk: compare the
  merged tree with the tested branch (`git diff <branch> --stat`) and run the
  tests on the merge before committing it.

See `references/bug-catalogue.md` for every class with its signature and fix.

## Offscreen drags (Powerbar bench, October 2026)

QtTest `mousePress`/`mouseMove(..., -1, Qt.LeftButton)` drive real drags in
`docs/rendering-bench` (`dragdots` scenario, `BENCH_DRAG="<widget> <waypoints>"`).
Offscreen, a window that shows becomes active and Qt cancels the bar's press
(`onCanceled` fires mid-drag): set `BENCH_NO_GHOST=1` so the drag ghost window
stays hidden. A walker that chases a moving target (dots pushed by a gap) can
loop forever: that loop is a real oscillation, test it with fixed points
(`pt:<along>`) and `~` pass-through waypoints.
Live pointer warps (`hl.dsp.cursor.move`) inside one surface are unreliable
for hover tests: a jump inside the bar is sometimes never delivered, or comes
as a leave. Enter from outside the bar for a single point; for paths (hover
from the clock to another zone) use the bench's real pointer events instead.

## Testing in an omabox box (preferred over the live desktop)

Never drive the user's desktop for tests; use omabox. A bar-replacing plugin
(Powerbar) can't use `omabox up --plugin`: `up` waits for an `omarchy-bar`
layer. Start a plain box, copy the plugin into `$(omabox path)/home/.config/
omarchy/plugins/<id>/`, `omabox restart-shell`, and edit the box's shell.json
for edges and settings. An IPC that reports state as JSON (Powerbar's
`keysStatus`, `drawerStatus`) turns every key test into one text line instead
of a screenshot.

Keyboard focus on a layer surface, learned shipping Powerbar's keyboard mode:
HyprlandFocusGrab never cleared for the bar; Exclusive alone sends every click
to that surface; OnDemand alone loses the keyboard to focus-follows-mouse. Use
Omarchy's KeyboardPanel pattern: Exclusive for ~200 ms, then OnDemand, plus a
full-screen transparent layer under the pointer (mask minus the bar) whose
click ends the mode. And a watchdog that hides tooltips whose target isn't
hovered will also hide a keyboard-driven one: exempt the cursor's target.

Before restarting the user's shell, check `omarchy-hyprland-session-locked`
(exit 0 = locked): the lock screen is ext-session-lock, not a layer, so
`hyprctl layers` never shows it. `omarchy-restart-shell` refuses while locked;
`live.sh restart` now says so and fails instead of reporting the old pid.

Live keyboard tests on the user's desktop (only when they ask): wtype keys go
to whatever has the keyboard, which can be the terminal running the agent.
Guard every key with a state check (Powerbar: `keysStatus` windowActive and
focused/drawerFocused) and bail out by IPC. A box with no other windows hides
focus hand-back bugs: an Omarchy panel returns focus to the previous window
after its fade-out, so test panel round-trips with a real window open.

### Clicks and focus checks on the real desktop

- Nothing installed clicks on the real desktop: `hl.dsp.cursor.move` warps
  (no hover inside a surface, no clicks), wtype is keys only (no binds, no
  fcitx5), and omabox's `omabox-pointer` refuses to run outside a box by
  design (don't work around it). Omarchy's way is `omarchy-dev-install-ydoo`:
  it installs ydotool, adds the user to `input` and a uinput udev rule (needs
  their password and a relogin; `input` lets programs read and inject input,
  so it's the user's call). ydotool's keys and clicks go through the kernel
  like real devices: binds fire and fcitx5 sees them. Use absolute moves
  (scale 1.6 needs calibrating), keep the per-key focus guard.
- Which layer has the keyboard isn't reported, but `hyprctl repl` with
  `hl.get_layers()` gives each layer's `namespace` and `interactivity`
  (0 none, 1 exclusive, 2 on demand): an exclusive layer that just opened has
  the keys, so typing a harmless probe there (then checking a screenshot) is safe.

