# Zone fit implementation plan

The design is final (2 October 2026). The spec of record is
[zone-fit-lab/zone-fit-lab.html](zone-fit-lab/zone-fit-lab.html): open it in a
browser, where it renders your cached widget captures. This plan turns the spec
into work, in an order that can land without breaking drag and drop, the
drawers or the spacing spec. Each step lists files, tests and how to accept it.

If this plan and the spec disagree, the spec wins.

## Status, 2 October 2026

Steps 1–7 are written on branch `zone-fit`, not yet checked on the live
desktop. `ZoneFitModel.js` (10 node tests, including a 2000-case fuzz),
`AnimatedSlot.motionDelay` (QML test), the slot fold/yield flags, per-window
`refit()`, the centre slide, island ends around yielded widgets, the fold
handle and drawer listing, the fit motion, and the Layout page note
(`ZoneFitNotice.js`, 4 node tests).

Differences from the steps below:
- **No growth delay for the indicators.** The widget animates its own width, so
  its slot can't wait for the yield; neighbours fade in 80 ms while it grows.
  Activity reveals do wait 80 ms (`motionDelay`).
- **The Layout page note sits above the layout grid.** The page has no bar
  preview; the preview is on the Appearance page.
- **Markers everywhere (decided 2 October, after the first live run).** Every
  collapse shows dots with a count badge: folded widgets behind the clickable
  drawer handle, yielded widgets behind a quiet, non-interactive marker in the
  first freed cell (the solver reserves that cell). The dots run along the bar
  (󰇙 on vertical bars, 󰇘 on horizontal ones).
- **Moments keep a 4 px gap** (`momentGap: root.edgeGap`) instead of the zone
  gap, so hovering the indicators no longer hides Workspaces on a 945 px bar.
- **Multi-line labels are measured from what they paint.** TextMetrics measured
  one line, so Scratchpeek's vertical label ("◌" over its count) was clipped.
- **The temporary live-check logs are removed.** `refit()` logged every fit
  while the bar was checked live; that logging is gone.

## Inline on-demand mode (2 October 2026)

General > On-demand widgets: **In a drawer** (default, unchanged) or **In the
bar** (`bar.powerbarOnDemand: "inline"`). The Managed visibility is labelled
"On demand" in Preferences.

- **Dots.** A zone with hidden on-demand widgets keeps its handle at rest
  (`input.dots`), on the side the zone grows: the left zone's end, the right
  zone's start, and for the centre the side of its anchor where most of its
  hidden widgets are (`dots.center: "start" | "end"`; folds decide when the
  centre has any). One handle per zone: its count is folded widgets plus hidden
  on-demand ones. The solver reserves it in the lasting fit. Its length eases
  (120 ms) and it fades, keeping its last count, so the island end never jumps.
- **Concurrent moments.** `input.transient` is a list, highest priority first:
  drag gap, the indicators' held reveal, activity reveals (one per zone), and
  last the inline expansion. Nothing slides; every neighbour yields to every
  growing zone (the centre at both ends without counting twice). When two
  growing zones meet, the higher one keeps its growing widget and yields the
  rest; if that isn't enough, the lower one falls back (`result.fallbacks`).
  The live run that found this: a swipe held the indicators' reveal open while
  the bottom zone expanded, and only one moment was fitted, so the centre ran
  into the top zone.
- **The queue** (`InlineQueue.js`, node tests): the pointer rests 90 ms on the
  dots before a zone opens, so a swipe opens nothing; a request for another
  zone collapses the open one at once and opens the next only 170 ms later
  (0 without animations), so two zones never move together; opening a zone
  other than the centre releases the indicators' held reveal and waits for it
  to settle the same way. A click skips the hover intent.
- **One step.** Showing or hiding an expansion and fitting the bar happen in
  one call (`inlineApply` then `refit(true)`), so the widgets and their
  neighbours' yields land in the same frame. `refit` skips the model when its
  inputs are unchanged.
- **Hold and collapse.** It holds while the dots or any of the zone's slots
  are hovered, a panel is open from the zone, a drag runs, or a group drawer is
  open; then it collapses after the exit grace. Hovering another zone collapses
  it at once. It never ages into lasting content; other moments age after 10 s
  each.
- **Fallback.** Before expanding, the bar fits the zone as if expanded, beside
  every moment running, using the hidden widgets' measured cells (they stay
  loaded; only their opacity is 0). If it would fall back, the zone's drawer
  opens instead. If a later fit can't serve it, it collapses into the drawer.
- **Keyboard.** The bar takes no keyboard focus, so Enter on the dots and the
  `managed` IPC call open the drawer in both modes.
- **Empty centre.** With no centre, a side moment makes the opposite zone
  yield, and a centre that is only its handle keeps it like an anchor.
- **Drag and drop.** The dots are a drop target in both modes: dropping there
  makes the widget On demand at that end of the zone (the dots' side), and
  they light with the selected fill while targeted. Resting 400 ms on them
  opens the zone (inline expansion, or the drawer), which holds while the drag
  runs; a drop beside a widget the expansion shows keeps the widget On demand.
- **Count badge.** General > Count on the dots (`powerbarDotsBadge`, on by
  default) shows or hides the count on the drawer handle and the yield
  markers; the handle's tooltip keeps the count either way.
- **Groups keep their place.** A group sits before its anchor entry, so moving
  that entry (a drop on the dots moves it to the zone's start) dragged the group
  along. Every move path (bar drops, a drop after a group, the Layout editor)
  now re-anchors such groups on the entry that followed (GroupsModel
  `nextAnchor` / `reanchor`); a change in place leaves them alone.
- **Drop outline.** The gap outline is the dragged cell kept one pixel inside
  the gap, on whole pixels. In Equal gaps a cell can be longer than the slot it
  lands in, and the gap's clipping slot cut the border on that side.

## The rule in one paragraph

Zones are laid out on one line per bar window, keeping the zone gap
`g = cellTokens.cell + widgetSpacing` between them.

- **Lasting length** first slides the centre by the smallest clamp that fits.
  If sliding can't fit, the longest zone folds its widget farthest from its
  anchor into the zone's drawer, and repeats until the line fits.
- **A moment** (the indicators' hover reveal, an activity reveal, a drag gap)
  never moves anything. The neighbour's whole widgets within `g` of the
  growing zone yield, which means they fade to 0 and keep their space.
- **Anchors** never fold or yield: the centre anchor, the left zone's first
  widget, and the preferences button.
- **Drawer fallback.** A moment opens in its zone's drawer instead of the bar
  when any of these holds:
  - it would need an anchor to yield;
  - it doesn't fit on the screen;
  - its widget is folded.

## What the current code does (b3383c2)

- **Centre placement.** The centre is centred with `anchors.centerIn: parent`
  on `groupModules` and `centerAnchorModule` (`CenterModules`). Nothing
  compares it with the side zones.
- **Paint order.** `barContents` paints the side islands, then the centre
  island and its widgets, then the side widgets. Where zones overlap, side
  glyphs draw over the centre's surface and its widgets, and they take the
  clicks.
- **Indicators reveal.** `centerSectionRevealHeld` makes the indicators widget
  grow its own width. That pushes the centre's "before" list outward from the
  anchor, unchecked.
- **Zone drawer handle.** The 󰇘 `WidgetButton` in the `zoneTarget` Repeater
  shows only when the zone has no visible widget, so folded widgets have no
  way back yet.

## Steps

### 1. `ZoneFitModel.js`, pure, with node tests

A `.pragma library` module next to `CellModel.js`, written in the same ES5
style so it loads in QML and in node.

```js
fit({
  length,          // along-bar length in bar px: mainStrip length / barScale
  inset,           // islandScreenInset (0 on Flat, edgeGap otherwise)
  gap,             // cellTokens.cell + widgetSpacing
  tokens,          // cellTokens, for CellModel.endPad and the handle's cell
  zones: {         // visible slots in order; each item { key, extent, spill }
    left: [], right: [],            // right ends with the preferences button
    before: [], anchor: null, after: [],
    center: []                      // used when there is no anchor
  },
  previous,        // last result, for hysteresis
  transient        // null, or { zone, frozen: true } (see step 2)
}) -> {
  centerStart,     // along-bar start of the centre island
  centerShift,     // centreOfAnchor - length / 2 (0 when it fits centred)
  folded: { left: [keys], center: [keys], right: [keys] },
  handles: { left: "end"|null, center: "start"|"end"|null, right: "start"|null },
  yielded: [keys],
  fallback: null | { zone, reason: "anchor"|"screen"|"folded" }
}
```

- **Zone length** is the sum of `extent`, plus `CellModel.endPad(tokens, spill)`
  at both ends, plus the handle's `CellModel.place(tokens, 12.5, true).extent`
  when the zone has folded widgets. This is the same arithmetic that
  `ModuleList` and the islands already use.
- **Fold order:**
  1. Take the longest zone first.
  2. A side zone folds from its inner end.
  3. The centre folds from the far end of its longer side (`before[0]` or
     the last of `after`).
  4. The left zone never folds `left[0]`. The right zone never folds the
     preferences button. The centre never folds its anchor.
  5. Put the centre's handle where its first fold happened.
- **Hysteresis.** A folded widget comes back only when it fits with
  `extent + tokens.gutter` to spare. Compare with `previous` so a value near
  the limit never flaps.
- **Tests** go in `tests/zone-fit.test.cjs`, ported from the lab's fuzz, which
  passed 4,000 random configs with no failures:
  - no two visible zones closer than `gap`;
  - every visible zone on screen;
  - no anchor folded or yielded;
  - a moment never changes `centerStart`;
  - no fold while the line fits;
  - no flapping when one extent oscillates by ±2 px around the limit;
  - each fallback reason.

**Accept:** `node tests/zone-fit.test.cjs` passes, and the model agrees with
the lab page for the hero and edge-case configurations.

### 2. Feed the model from each bar window

Bar windows already own their slots (`widgetModels`: `left`, `right`,
`center`, `before`, `anchor`, `after`), and every monitor has its own length,
so the fit is per window.

- **Base visibility.** Add `baseVisible` on `ModuleSlot`, holding today's
  `mainVisible` expression, and make
  `mainVisible: baseVisible && !fitFolded`. The model reads only
  `baseVisible`, `cellExtent` and `cellSpill`, never its own outputs. Switch
  `updateHold()` to `baseVisible` too, so folding never resets a held width
  and re-triggers the fit.
- **Run it imperatively.** Add `barWindow.refit()` and call it through
  `Qt.callLater` when any input changes, like `updateHold`. Inputs are slot
  `cellExtent`, `baseVisible`, model membership, window length, `barScale`,
  `cellTokens`, `islandScreenInset`, and the transient state. The result goes
  in `barWindow.zoneFit`. One binding-free pass avoids loops between extents
  and outputs.
- **Moments.** The moment's zone is the centre while `centerSectionRevealHeld`
  is set, or a slot's region while it is managed and `activityVisible` or
  hover-revealed. During a drag it is the zone of `dragPreview.targetSurface`
  (`"bar:<zone>"`), with the gap from `dragGapWidth` / `dragGapHeight`.
  - While a moment is active, the lasting solution (`centerStart`, `folded`)
    is frozen. Only the yields are computed from the current extents.
  - When the moment ends, the fit runs again.
  - A moment that lasts more than 10 s (a widget that keeps reporting
    activity) is treated as lasting content and refits. Moments are short by
    definition.

**Accept:** a temporary `console.info("powerbar zone-fit", …)` probe on the
945 px right bar logs the same slide and fold as the lab's hero. Remove the
probe afterwards.

### 3. Place the centre from the fit

Keep the centring code and add the fit's shift to the transform that
`CenterModules` already has for autohide:
`Translate { x: shiftX(centerShift) + (vertical ? 0 : fitShift); y: shiftY(centerShift) + (vertical ? fitShift : 0) }`.
Hit testing and highlights follow transforms, so nothing else moves. Don't
switch anchors by orientation.

**Accept:** with a drawn long title in the left zone, the clock leaves the
middle by exactly the lab's figure, and returns when the title goes.

### 4. Fold into the zone's drawer

- **Slot state.** `fitFolded` on `ModuleSlot` reads
  `homeWindow.zoneFit.folded`. A folded slot has `mainVisible` false, so
  `targetWidth` is 0 and the existing slot motion closes the gap.
- **Drawer list.** `managedSlots(zone, window)` includes folded slots first.
  `ManagedDrawer.slots` already reads it, and `drawerHost` already reparents
  the presentation.
- **Handle.** Add a `FoldHandle` inside `ModuleList`, at the end the fit
  names. It is a glyph cell (`CellModel.place`) drawing 󰇘 with the same
  count badge as group icons (`CellModel.badge`, the `cellBadge` pattern).
  - Hovering it calls `managedDrawer.sourceEnter(zone)`.
  - It is focusable: Enter or Space calls `drawer.openZone(zone, true)`.
  - Tooltip: "3 more widgets".
- **Activity.** Activity on a folded widget flashes the handle, the way
  `autoHidePeek` redirects members to their group icon.
- **Tray.** `pinTrayToInner` puts the tray at the inner end, so it is the
  first candidate to fold. Check that it renders in the drawer. If it
  doesn't, skip it and fold the next widget.

**Accept:** at 900 px top (or a 945 px right bar), the handles show the lab's
counts, hovering opens the drawer with the folded widgets first, and each one
works from there.

### 5. Yield for moments

- **Slot state.** `fitYielded` on `ModuleSlot`: the presentation's opacity
  goes to 0, `enabled` to false, the hover handler is disabled and the slot
  leaves the Tab order. `targetWidth` is unchanged, so nothing moves.
- **Island ends.** `ModuleList` exposes the extent of yielded slots at each
  end (`fitTrimLead` and `fitTrimTrail`). The island `x` and `width` (or
  `y` and `height`) subtract them, so the island ends at its last visible
  cell. Flat and Floating draw no island.
- **Fallback.** On a fallback, the moment opens in the zone's drawer:
  - for the indicators, open the centre's drawer instead of setting
    `centerSectionRevealHeld`;
  - for activity, flash the handle;
  - for a drag, use the zone's managed drop target.

**Accept:** hovering the cup on the 945 px right bar fades Workspaces and the
AI group, keeps Keystroke, and moves nothing. Leaving the bar brings them back.

### 6. Motion

- **Opening.** Yielded widgets fade out in 80 ms (`OutCubic`, gated by
  `animationsEnabled`). The growing zone's slots wait 80 ms, then animate.
  Add `motionDelay` to `AnimatedSlot`, a `PauseAnimation` before the
  `NumberAnimation` inside the Behavior. `AnimatedSlot` already clips, so the
  widget's own growth stays hidden until its slot opens.
- **Closing.** The zone shrinks in 150 ms, then yielded widgets fade in for
  160 ms with a 150 ms delay.
- **Centre slide.** A `Behavior` on `fitShift`: 200 ms,
  `Easing.BezierSpline [0.77, 0, 0.175, 1, 1, 1]`.
- **Fold.** The slot fades out in 110 ms. The handle animates from scale 0.96
  and opacity 0 in 160 ms.
- **Animations off.** Every Behavior is disabled and all of it lands in one
  update. Add no `FrameAnimation`.

**Accept:** `tests/qml/tst_AnimatedSlot.qml` gains `motionDelay` cases (off
means immediate). Screenshots with animations off show no state with two
zones in one place.

### 7. Preferences

Under the Layout page preview, add one line when any window has folds. Root
aggregates `{ screen, zone, count }`, and the line reads, for example:
"3 widgets don't fit on eDP-1. They're in the Center drawer." Use "Center and
Right drawers" when there are two.

**Accept:** the line appears and disappears with the folds, in sentence case.

## Verify on the desktop

Back up `~/.config/omarchy/shell.json` before any configuration change and
restore it byte for byte (`cmp`). Turn autohide off for captures.

1. Right edge, 945 px, Large, Equal gaps (your bar):
   - at rest, there is a slide and folds with handles;
   - hovering the cup makes the top zone yield;
   - a weather reveal makes the top zone yield for 2.5 s;
   - a drag into the top zone makes the centre's end yield.
2. Top edge, with a long title widget or a narrow length (Large bar plus
   spacing 8): slide, then fold.
3. Flat at 0% opacity, and Islands at 100%: island ends retract when widgets
   yield, and zones keep the zone gap.
4. Animations off: no transitional overlap in rapid `grim` captures.
5. Two monitors of different lengths fold differently and independently.
6. Read the shell log after every reload:
   `quickshell log -p /usr/share/omarchy/shell | grep -i powerbar`.

## Risks

- **Binding loops.** Avoided by the imperative `refit()` and by inputs
  (`baseVisible`, `cellExtent`) that never read outputs.
- **Churn.** Only assign `zoneFit` when the result changes (`RenderModel.equal`).
- **Hold interaction.** Held widths are the input, so ticking values never
  refold. Folding must not reset holds (step 2).
- **Drag.** During a drag the lasting solution is frozen. The commit after
  the drop runs a fresh fit, and a drop that makes the zone too long folds
  after the settle glide lands.
