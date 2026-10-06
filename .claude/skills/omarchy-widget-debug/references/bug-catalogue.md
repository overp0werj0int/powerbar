# Bug catalogue: what each class looks like, and the fix that held

Every entry was found and fixed in Powerbar (October 2026) with the loop in
SKILL.md. "Frames" means FRAME output through `timeline.py`; "log" means a
tagged live log. Match the symptom, confirm the signature, then apply the fix.

## Motion and geometry

**Wobble after a drop** (the island swells, then shrinks back)
- Frames: `wobble` on an island's width and x, peaking right after the
  commit; the new slot's width overshoots its final size.
- Cause: state that sizes the transition was cleared at the commit, before the
  settle ended. The gap width came from the drag source; clearing the source
  made it fall back to a generic, larger size.
- Fix: keep whatever the transition needs until it has finished (a "settle
  landing size" captured at release). Rule: never derive in-flight geometry
  from state the commit clears.

**Slide after a drop** (the icon lands, then slides again)
- Frames: the dropped item appears at one x and moves 50–100 px; the save
  shows it next to the gap, not in it.
- Cause 1: the release recomputed the drop target from the current layout,
  which the open gap had already shifted. Fix: commit the drop the preview
  shows; compute only if none is shown.
- Cause 2: a gap trailing the previous item is that item's slot end; easing
  it out while the new slot eases in moves the new slot's left edge. Fix: the
  gap and its replacement are the same size at the same spot, so swap them in
  one frame (disable the size Behaviors for that frame, then re-enable).

**One-pixel jitter** (`jitter` in timeline.py)
- Fractional positions rounding differently each frame under animation.
  Usually harmless; if visible, round layout positions once (whole pixels)
  instead of per item.

**Late motion** (`late` with `--settle`)
- Something keeps easing after it should be at rest: a held width shrinking,
  a Behavior on a property that a later config reload rewrote. Find the key,
  then the Behavior.

**Icons spread apart, or the bar resettles, after a blur toggle or a screen
move** (Powerbar, 4 October)
- Log: a tagged probe on every slot (position, width, measured ink, held
  width, natural size) at 0/150/500/1500 ms after the toggle. At t0 every slot
  read `nat40/i40` (a placeholder the bar's size) and the hold had already
  jumped to 59 px; after the window returned the ink was real (`i12`) but the
  held 59 px stayed for the 8 s hold.
- Cause: the layer-shell window is unmapped for 60 ms to change its namespace
  (blur) or re-place it (Omarchy's `ScreenMoveRemap`). Meanwhile every widget
  reports `visible: false`, so slots measured empty placeholders; the "grow at
  once, shrink after 8 s" hold kept the wrong size, and the geometry animated
  back afterwards. `Window.window.visible` stays true, so a guard on it never
  fires. **Offscreen never reproduces it** (items stay visible there).
- Fix: the window freezes its slots' measurements *before* it hides (a
  `layoutFrozen` flag set in the same handler that starts the remap, and on the
  screen's x/y change, since the remap guard waits 200 ms) and thaws them 250 ms
  after it is shown again; slots expose frozen natural size and ink while it
  is set, and the hold doesn't update. Rule: never measure items in a window
  you are hiding; freeze before you hide.

**A glyph sits off the bar's centre line next to a badge** (notification bell
with an unread dot)
- Cause: the widget's root had two painted children, its kit button and a dot
  drawn inside the button's box, so "measure the kit glyph when it is the only
  content" failed and the ink span covered bell plus dot.
- Fix: a child lying entirely inside the one kit button's box is a badge
  (`HighlightModel.withoutBadges`), ignored for measuring and centring, as
  Omarchy's bar (which centres the button box) effectively does.

## Input

**Clicks reach the wrong widget**
- Probe: a hit census (`h.census`, or the in-app version in recipes.md)
  finds points where the press taker is not the visible item there.
- Cause: a global hit test over every click target on the bar. Hidden widgets
  keep their content at full size inside zero-width slots, and Qt positioners
  do not move zero-size items, so their content sits at a stale x (often a
  list's start). The target's own `opacity` was checked, not its ancestors'.
- Fix: scope the hit test to the clicked item's own targets.

**A press never starts a drag** (only part of a row is draggable)
- Probe: the census shows the press taker is a child `MouseArea` (the
  widget's own), not the row's handler.
- Cause: Qt delivers the press to the topmost accepting item; a parent's
  `DragHandler` never sees a press a child `MouseArea` accepted.
- Fix: put the row's drag and click handling on an overlay `Item` above the
  content (higher `z`, `anchors.fill`), so it takes every press in the row.

**Hover on things that should be inert**
- Qt 6 delivers hover to disabled items (by design, for tooltips), and a
  `MouseArea` has its own `enabled` that a disabled parent does not change.
- Fix: make inert items deaf with `hoverEnabled: false` / the handler's own
  `enabled`, and guard handlers (`if (!enabled) return`).

**No hover while a button is held**
- Hover events are not delivered during a press-drag; after release Qt sends a
  frame-synchronous hover at the pointer, so `HoverHandler.hovered` updates a
  frame or so later. Do not decide "the pointer left" from hover during a drag.

**The bar freezes mid-drag** (ghost stays, every target stays highlighted)
- Log: drag started, no finish, no error.
- Cause: the item whose handler drives the drag was destroyed (a drawer
  closed under it, a JS-array Repeater model changed and rebuilt every
  delegate, starting a new drag committed a pending one that closed the
  drawer). A destroyed handler never reports the release.
- Fix: hold the source alive for the drag's duration (keep the drawer
  presenting and freeze its rows), set the hold before anything that can
  close it, and in the row's `Component.onDestruction` cancel the drag if it
  still owns it, so it can never be stuck.

**The next click does not focus another window**
- Log: the drawer was in keyboard mode (`WlrKeyboardFocus.Exclusive`) with a
  `HyprlandFocusGrab`; the outside click was spent clearing the grab.
- Fix: a pointer interaction ends keyboard mode (drop exclusive focus and the
  grab); keyboard mode only for keyboard-opened surfaces that close on use.

## Placement

**Drops land one row late in a menu**
- Cause: an offset measured along the bar (ink centre, x) applied to a
  surface whose axis differs (a vertical menu under a horizontal bar). Fix:
  apply axis-bound offsets only when the surface's axis equals the bar's.

**A boundary gap gives different results from each side**
- Where two runs meet (shown | on demand), the gap looks the same but the
  result depended on which neighbour the pointer was nearer. Fix: one rule
  for the boundary (it belongs to the shown run), tested in a pure JS model,
  with hidden items skipped as neighbours.

**A drop "beside the group" lands on its other side**
- Groups (headers) are not layout entries; resolvers that skip them as
  references put the item before the header. Fix: when the item before the
  gap is a header of the same run, use the "after the group" path (take its
  place, re-anchor the group in front).

**A stacked widget overflows its slot on a side bar**
- Signature: ScratchPeek's mark over its count runs into the next widget
  (Equal slots), or its highlight cuts through the stack (Equal gaps). Slot
  25 px for a 44 px button; cell 22 px for 32 px of ink.
- Cause: on a vertical bar the ink rect calls a kit button a glyph when it is
  narrow *across* the bar (`across <= 16`), however long it is *along* it,
  and a glyph got a square cell. Fix (CellModel.cellLength): a glyph keeps
  its square cell only while its ink fits it; longer ink gets the text rule
  (ink + air each side).
- Find the class, not the case: audit every slot for "ink inside the slot"
  and "highlight >= ink" across top/side x Equal slots/gaps x normal/large
  (recipes: "Audit an invariant across every configuration"). A kit button's
  transparent 8.5 px margins reaching a few px past its slot are harmless.

## Lifecycle

**TypeError in cleanup when a widget is hidden**
- Signature: `Value is undefined and could not be converted to an object`
  in a cleanup function, once per hidden widget; dead records pile up and a
  registry (clickTargets) grows across hide/show cycles (77 -> 82).
- Cause: a record kept a reference to a slot; hiding destroys the slot, and
  its widget's buttons unregister after the slot's properties are gone. The
  throw stops the cleanup halfway. Fix: the owner drops its records in its
  own `Component.onDestruction`, and the cleanup skips an owner whose
  properties read undefined. Repro: a bench scenario that writes
  `powerbarVisibility: hidden` and back, logging the registry sizes per step;
  three cycles must return to the same counts.

## Colour

**The bar goes blank after a theme switch**
- Signature: islands drawn, every glyph and label invisible; captured images
  still visible. `barForeground` equals the bar background.
- Cause: an explicit "Dark" text choice made in a light theme resolves to the
  darker of the theme's pair, which in a dark theme is the background. Fix:
  scope explicit colour choices to the theme they were made in
  (`powerbarForeground: { "<theme>": "dark" }`, theme from
  `~/.local/state/omarchy/current/theme.name`). Check any colour setting by
  switching between a light and a dark theme offscreen: the bench reads the
  current theme, so log the resolved colours.

## Performance

- A `Repeater` whose model holds QObjects exposes every property as a role:
  about 2 ms per object. Use identity tokens (`String(obj)`) as the model and
  look the objects up in a plain table.
- `signal.connect(obj.method)` is not dropped when `obj` dies; disconnect in
  `Component.onDestruction`.
- A `var` binding that returns the same object emits no change signal; a
  Repeater given an equal array keeps its delegates.
- Host config writes can be expensive (Omarchy re-registers every bar widget,
  about 370 ms, twice: write and file reload). Apply edits to a local copy at
  once and flush them after the interaction settles.

## Tooling traps

- `Error().stack` in QML omits signal-handler frames; `console.trace()`
  prints them ("expression for onHoveredChanged (Bar.qml:4232)").
- A second `onXChanged:` handler for the same property fails the whole file
  ("Property value set multiple times") and the shell falls back to the stock
  bar: always load offscreen before restarting the live shell.
- Offscreen artefacts: no hover from QtTest mouse moves; Qt treats the
  pointer as resting at (0, 0), so synthetic hover after a scene change hits
  the top-left item. Do not chase behaviour that only that hover causes.
- Quickshell has no offscreen `PanelWindow` backend: swap it for a
  `FloatingWindow` shim (the Powerbar bench's `prepare.py` does it with sed).
- A work folder inside the Quickshell config folder reloads mid-run on every
  write; keep it outside.
- `QT_QUICK_BACKEND=software` draws `ClippingRectangle` content as nothing:
  wallpaper previews and minis look empty in bench screenshots. Run a
  temporary copy of the bench's run script with `QT_QUICK_BACKEND=rhi`.
- `grim` hangs while the display is asleep (`hyprctl monitors -j`,
  `dpmsStatus: false`); with autohide on, the bar is parked off screen.
  Ask the user for a screenshot instead of hovering.
- `pkill -f <pattern>` can match the bash command that runs it and kill your
  own shell (exit 144).
- Qt's JavaScript engine splits `Array.from(string)` by UTF-16 unit, so
  Material Nerd Font glyphs (U+F0000 and up) come out as two halves; node
  splits by code point, so node tests pass. Walk surrogate pairs by hand and
  run string rules in `qmltestrunner` too.
- In QML scope an id beats a property of the same name: a `face` property
  inside a component that also has `id: face` reads the Item.
- Measuring text inside a binding by setting a shared `TextMetrics` or
  `FontMetrics` font loops ("Binding loop detected"). Create one
  `FontMetrics` per font once (`Qt.createQmlObject`) and call
  `tightBoundingRect(text)`; cache the results in a plain object.
- Plugins do not run offscreen: the bench registers stand-in buttons, so
  plugin faces, names (ids instead of manifest names) and anything read from
  them are artefacts. To reproduce a plugin's layout, read its source and add
  a stand-in that draws the same thing (ScratchPeek: `"\u25cf\n1"` in a
  button at least 44 px tall on a side bar).
- Saved captures are 2 x device pixel ratio: a bench screen at `dpr: 1`
  reads a 1.6 laptop's images at the wrong size. Set the bench screen's dpr
  to the user's (`BENCH_SCREENS` with `"dpr": 1.6`).
- `omarchy-restart-shell` refuses while the session is locked ("Refusing to
  restart Omarchy shell while the session is locked") and exits 1; `live.sh
  restart` then reports the old pid. Check the pid changed.
- Dark-on-dark widgets after a style change: check where the foreground comes
  from before suspecting stacking. Omarchy's transparent bar picks text from
  the wallpaper; a surface drawn behind the widgets makes that colour wrong.
