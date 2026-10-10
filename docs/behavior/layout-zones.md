# Layout zones behavior

Powerbar organizes widgets into three zones (left, center, right on a horizontal bar; top, middle, bottom on a vertical one). Zones never overlap: a solver keeps one zone gap (the icon cell plus the widget spacing) between them, folding widgets behind a drawer handle when the bar is too short. This file owns zones, placement and order, spacing, zone fit, dots, bar position and bar size. Preferences controls for these are in preferences.md; the CLI and IPC calls (`set spacing`, `set largeBar`, `set style`, `set position`, `managed <zone>`, `keysStatus`, `drawerStatus`, `managedStatus`) are in integration.md.

Sources: ZoneFitModel.js (fit, fitLasting, fitMoment), CellModel.js (tokens, flatEdge), ZoneOrderModel.js, ZoneFitNotice.js, BarModel.js (options, barStyle, pinTrayToInner), AppearanceModel.js (ranges.spacing), Bar.qml (grep: zoneFit, zoneGap, edgeGap, islandScreenInset, barSizeFor, FoldHandle, YieldMarker, beginBarMove), tests/zone-fit.test.cjs, tests/zone-order.test.cjs, tests/cell.test.cjs, tests/zone-fit-notice.test.cjs, tests/clean-defaults.test.cjs.

Numbers below use Omarchy's default theme tokens: bar 26 px (horizontal) or 28 px (vertical), icon slot 27 px, and Powerbar's default spacing 4.

## Zones and placement

- **ZONE-1** Widgets are stored per zone in `bar.layout.left`, `bar.layout.center` and `bar.layout.right` of shell.json. On a vertical bar (`bar.position` left or right) the same lists draw as top, middle and bottom. Code: Bar.qml normalizeLayout.

- **ZONE-2** A zone with nothing to draw has no island and adds no gap: with an empty center, left and right keep one zone gap from each other; with an empty left or right zone, the remaining zones are limited only by the screen inset (ZONE-66). Code: ZoneFitModel.layout (a zone of length 0 adds no gap).

- **ZONE-3** `bar.centerAnchor` names one widget id in the center zone (the anchor). With room, the anchor's centre sits exactly at the middle of the bar line, with the center's widgets saved before it drawn before it and those saved after it drawn after it. If the left or right zone needs the room, the whole center slides by the least distance that keeps one zone gap, then widgets fold (ZONE-9). A missing, empty or unmatched `centerAnchor` means no anchor: the center is one list, centred as a whole. Code: RenderModel.split; ZoneFitModel.resultOf (centerShift).

- **ZONE-5** Zones never overlap along the bar line: two neighbouring visible islands are at least the zone gap apart, `zoneGap = cell + spacing` (default 20 + 4 = 24 px on the 26 px bar), and every zone stays inside the screen inset. Moments (ZONE-29) keep a smaller gap (ZONE-33). Code: Bar.qml zoneGap; tests/zone-fit.test.cjs assertClear.

- **ZONE-6** The fit runs once per bar window (one per monitor, ZONE-71) along the bar line (width on a horizontal bar, height on a vertical one). Inputs: line length, screen inset, zone gap, each zone's widget extents, and which zones have dots. Output: which widgets show, which fold behind the zone's drawer handle, and how far the center slides. It re-runs when an input changes (a widget's size, spacing, bar size, monitor size). Code: ZoneFitModel.fit; Bar.qml refit().

- **ZONE-7** Two kinds of fit: **lasting** (the resting layout, which decides folding) and **moment** (temporary growth: drag gap, indicators reveal, activity reveal, inline expansion). A lasting fit slides the center and folds; a moment slides nothing and makes neighbours yield (ZONE-29). Code: ZoneFitModel.fitLasting, fitMoment.

- **ZONE-8** Hysteresis: a folded widget unfolds only when its zone would then still have one gutter (3 px plus spacing) to spare. One pixel of growth leaves the folds unchanged, and a widget whose size alternates by 1 px around the threshold changes the folding at most once in 20 changes. Code: fitLasting (`lo + gutter <= hi`); test "hysteresis".

## Folding: longest zone first, from the far end

- **ZONE-9** When the line is too short, one widget folds at a time, from the longest zone, until the zones fit (ties go to left, then right, then center). From the left zone the last widget folds; from the right zone the first; from the center with an anchor, the first widget before the anchor or the last after it, taken from the side with more shown widgets (before on a tie); from the center without an anchor, its first widget if the left zone is at least as long as the right, else its last. Code: ZoneFitModel.foldOne.

- **ZONE-10** Folded widgets wait behind the zone's drawer handle (dots), at the end facing the gap: the left zone's last cell, the right zone's first cell. The center has one handle per side that has folded or hidden on-demand widgets: at its start, at its end, or both (with an anchor, by the side of the anchor; without, folds taken from the start wait at the start). Code: ZoneFitModel.handlesOf, centerHandles.

- **ZONE-11** Unfolding runs in reverse order of folding: when the bar grows enough (ZONE-8), the most recently folded widget returns first. Code: fitLasting.

- **ZONE-12** If nothing more can fold and the zones still collide, the fit reports `fits: false`; the center then sits directly after the left zone and may overlap the right zone. Nothing is dropped. Code: foldOne returns false; resultOf.

- **ZONE-13** Never folded: the center anchor, the left zone's first widget, and the right zone's last widget (always the Preferences button, ZONE-69). A side zone folds only while it holds more than one unfolded widget. Code: foldOne.

## Dots (drawer handle) and counts

- **ZONE-14** A zone shows dots only while something waits behind them: widgets folded for lack of room, and with `powerbarOnDemand: "inline"` also its hidden on-demand widgets. In the default `"drawer"` mode with nothing folded there are no dots. The glyph is 󰇘 on a horizontal bar and 󰇙 on a vertical one. Code: Bar.qml FoldHandle (shown when count > 0).

- **ZONE-15** The dots take one glyph cell (a 12 px glyph's slot: 27 px at spacing 4) and the lasting fit reserves it, so a zone does not change length when its on-demand widgets hide or return. The cell eases in and out over 120 ms with Animations on. Code: ZoneFitModel.slotsOf; FoldHandle width Behavior.

- **ZONE-16** The count badge on the dots is the number of folded widgets plus, in inline mode only, the on-demand widgets hidden on that side (the center's two handles each count their own side). It reads "99+" above 99. `powerbarDotsBadge: false` (Preferences > Bar > On demand > Count on the dots) hides the badge on the dots and on yield markers; the dots' tooltip, "1 more widget" or "N more widgets", shows either way. Code: FoldHandle count, label.

- **ZONE-18** Hovering the dots in inline mode, or clicking them, expands the zone in the bar and brings back that zone's folded widgets for the moment; see on-demand-drawers.md, "Inline expansion", for timing (90 ms intent, 170 ms settle, 1 s exit grace by default) and the drawer fallback. In drawer mode hovering or clicking the dots opens the zone's drawer, which lists the folded widgets. Code: Bar.qml inlineEnter; FoldHandle MouseArea.

## Spacing and cell sizes

- **ZONE-19** `powerbarSpacingMode` (Preferences > Bar > Size > Spacing: "Equal slots", "Equal gaps") is `"slots"` by default (any value but `"gaps"` reads as slots). **Equal slots**: every item gets a cell (a square for glyphs) plus a gutter, so cells sit one gutter apart. **Equal gaps**: every glyph gets the same gap before and after it, and a cell may spill past its ink into the gaps. Code: BarModel.options; CellModel.place.

- **ZONE-20** A cell is the bar thickness minus two insets: `inset = min(3, (bar - 16) / 2)`, `cell = bar - 2 * inset`. 26 px bar: inset 3, cell 20. Large bar (38 px): cell 32. Vertical 28 px: cell 22. Large vertical (40 px): cell 34. The cell is also the hover highlight. Code: CellModel.tokens.

- **ZONE-21** An item is a glyph if its widget says so or its ink is at most 16 px; a glyph's cell is square (the cell size) while its ink fits. Any other item takes `max(cell, ink + 2 * air)` with `air = (cell - 12) / 2` (4 px on the 26 px bar). Free text (a window title, a media label) is capped at 160 px of ink; compounds (several click targets) and vertical stacks are not. Code: CellModel.isGlyph, cellLength, MAX_INK.

- **ZONE-22** Space between widgets (`powerbarSpacing`; Preferences > Bar > Size > "Space between widgets") takes whole units from 0 ("None") to 16, default 4, scaled by the theme's spacing scale; a stored value outside that range reads as the nearest limit, a non-number as 4. It widens gutters and gaps, never cells: `gutter = inset + spacing`, `gap = cell / 2 + 2 + spacing`. Standard bar: spacing 0 gives gutter 3 and gap 12; the default 4 gives gutter 7 and gap 16, so in Equal slots icons sit 27 px apart (20 + 7), Omarchy's own icon slot. Changing spacing, spacing mode, bar size or orientation resets every widget's width hold (ZONE-64). Code: AppearanceModel.ranges.spacing, CellModel.tokens; tests/clean-defaults.test.cjs.

- **ZONE-23** `powerbarLargeBar: true` (Preferences > Bar > Size > Large bar; default off) makes the bar 12 px thicker, a 6 px lip above and below: 26 to 38 px horizontal, 28 to 40 px vertical. Widgets keep their own size and gain room around them; cells, highlights and island ends grow with the bar. Code: Bar.qml barSizeFor, largeBarLip.

- **ZONE-24** The bar reserves `barSize` px of the screen edge on a flat bar, and `barSize + 8` px (2 x `edgeGap` 4) on floating and islands bars. An autohidden bar reserves nothing (see appearance.md, "Bar auto-hide"). Code: Bar.qml barExtent, exclusiveZone.

## Ordering within zones

- **ZONE-25** On-demand widgets draw as one run at their zone's dots end, in saved order: the left zone's end, the right zone's start. Always-shown widgets keep their saved order and never move when on-demand widgets appear (an expansion, an activity reveal, a drop preview). The saved layout is not rewritten; only the drawing differs. Code: ZoneOrderModel.arrange.

- **ZONE-26** With a center anchor, each on-demand widget stays on its saved side: those saved before the anchor draw as a run at the center's start, those saved after at its end. Without an anchor the center's run is at its end. Code: ZoneOrderModel.arrange (lists "before", "after", "center").

- **ZONE-27** A drop into a bar gap writes the widget into the saved layout so it lands exactly at the gap: before the first widget of its own run (always-shown or on-demand) after the gap; else after the last such widget before the gap; else beside the anchor on the gap's side (before the anchor for a gap before it); else at the zone's end. Code: ZoneOrderModel.dropBefore; tests/zone-order.test.cjs.

- **ZONE-28** A drop on a zone's dots makes the widget On demand at that zone's dots end: see drag-edit.md DRAG-28 and DRAG-29.

## Moments and yields

- **ZONE-29** A moment is temporary growth of one zone: a drag gap, the indicators' held reveal, an activity reveal, an inline expansion. Several may run at once, highest priority first, an expansion last. Nothing slides; every neighbour of a growing zone yields: whole widgets hide from the end facing the growing zone (left zone from its end, right zone from its start, center from the facing side), fading out but keeping their space, and the island ends at its last visible cell. A moment other than a held inline expansion that lasts over 10 s counts as lasting and is dropped from the fit. Code: ZoneFitModel.fitMoment; Bar.qml zoneFitMoments, ageMoments.

- **ZONE-30** Where widgets yielded, a quiet marker (the dots at 45% opacity, not interactive) takes the first freed cell, with the count of widgets out of view (badge as ZONE-16). Resting the pointer on the marker for 90 ms ends the moment that made them give way. Code: Bar.qml YieldMarker, releaseYield.

- **ZONE-31** An inline expansion whose neighbour would have to yield its anchor hides that whole neighbour zone instead (dots included; its island fades with no marker); if the zone past it still collides, it yields in turn or hides whole. An expanding center that would run off the bar slides back onto it by the least distance. Code: fitMoment attempt(), hide().

- **ZONE-32** When two growing zones meet, the higher-priority one keeps its growing widget and yields the rest towards the other; if it cannot (an anchor would have to yield), the lower one falls back. Code: fitMoment attempt().

- **ZONE-33** A moment keeps a smaller gap than a lasting fit: `momentGap = edgeGap = 4 px` (not a share of the zone gap), so hovering the indicators does not hide neighbours that still fit. Code: Bar.qml zoneFitInputs momentGap.

- **ZONE-34** A moment that cannot be served falls back, for one reason: `folded` (its source widget is folded), `screen` (the zone would run off the bar line), `anchor` (an anchor would have to yield and the moment is not an inline expansion) or `neighbour` (two growing zones meet and the other cannot yield). An inline expansion that falls back collapses and the zone's drawer opens instead. Code: fitMoment fallbacks; Bar.qml refit().

## Inline expansion in the fit

- **ZONE-35** An inline expansion counts the zone's hidden on-demand widgets as shown at their measured size (they stay loaded at opacity 0), unfolds that zone's folded widgets, and drops that zone's dots for the moment. Code: Bar.qml zoneFitList(expand), inlinePlan; fitMoment unfold.

- **ZONE-36** A center with an anchor expands one side at a time: the dots at its start expand and unfold the before-anchor run, the dots at its end the after-anchor run (tokens `center:start`, `center:end`); the other side's folds stay folded. Code: fitMoment sides; Bar.qml inlineToken.

- **ZONE-37** Before expanding, the bar fits the zone as if expanded beside every other moment running; if that would fall back, the zone's drawer opens instead and the bar does not change. Code: Bar.qml inlinePlan.

## Position, style and configuration

- **ZONE-38** The bar edge is `bar.position` (top, bottom, left, right; anything else reads as top), also set by Preferences > Bar > Screen edge. Pressing empty bar space and holding 200 ms, or moving 4 px with the button down, starts a bar move: overlays show the candidate edge (the screen is split along its diagonals, so the pointer's nearest edge wins); releasing over a different edge writes `bar.position`. A plain click on empty space does not move the bar. Code: Bar.qml CenterGestureArea, nearestScreenEdge, setBarPosition.

- **ZONE-39** A layout entry has `id` (widget id), `powerbarInstance` (a unique key Powerbar assigns once) and optionally `powerbarVisibility` (`shown`, `managed`, `hidden`). A widget with no `powerbarVisibility` is shown, third-party widgets included; see on-demand-drawers.md, "Managed widget modes", for the modes, and integration.md, "Config healing", for the one-time heal (`bar.powerbarVisibilityDefault: "shown"`) that keeps older configs' third-party widgets on demand. Code: ManagedModel.mode, healVisibility.

- **ZONE-40** The anchor is `bar.centerAnchor` (a widget id). Preferences > Bar > "Pinned to screen center" lists the center's always-shown widgets; "None" clears it. Empty or missing means no anchor (ZONE-3). Code: Bar.qml applyBarConfig.

- **ZONE-41** `bar.powerbarStyle` is `flat` (default), `floating` or `islands`; for any other value, `powerbarIslands: true` (older configs) reads as islands, else flat. **Flat**: one square, borderless surface edge to edge, like Omarchy's bar. **Floating**: one rounded, bordered surface held 4 px off the edge and the screen's sides. **Islands**: each zone with something to draw on its own such surface. Rounding and borders apply to floating and islands, not to the flat strip. Code: BarModel.barStyle; Bar.qml mainStrip, floating surface, IslandSurface.

- **ZONE-42** Default spacing is 4 (ZONE-22): a shell.json with no `powerbarSpacing` draws icons 27 px apart.

- **ZONE-43** Default spacing mode is slots (ZONE-19).

- **ZONE-44** Default large bar is off (ZONE-23).

- **ZONE-45** `bar.powerbarOnDemand` is `"drawer"` (default; any value except `"inline"` reads as drawer) or `"inline"`. Switching it collapses an open expansion and closes an open drawer at once. See on-demand-drawers.md. Code: BarModel.options; Bar.qml onOnDemandInlineChanged.

- **ZONE-46** `powerbarDotsBadge` is on unless set to false (ZONE-16).

## Orientation and vertical bars

- **ZONE-49** On a left or right bar the zones run top (left zone), middle (center), bottom (right zone, with the Preferences button last), and every zone rule above applies along the bar's height. The bar is 28 px wide (40 px large). Code: Bar.qml vertical, barSizeFor.

- **ZONE-50** On a vertical bar glyphs are centred across the bar by their painted ink; wide text must come from a widget's vertical form (the clock's HH / mm stack); a group face that does not fit falls back to its glyph. Code: Bar.qml crossShift; docs/design/spacing.md.

- **ZONE-52** `barSizeFor(vertical)` is the theme's `size-vertical` (28) or `size-horizontal` (26) bar token, plus 12 px on the large bar. A theme that sets other tokens changes every size above with them. There is no separate setting per edge. Code: Bar.qml barSizeFor.

## Markers and island extent

- **ZONE-53** A zone with folded widgets shows the dots as a clickable handle; a zone whose widgets yielded to a moment shows the quiet marker (ZONE-30) at the yielded end of its remaining widgets. Neither appears between shown widgets.

- **ZONE-54** The solver reserves the marker's cell in the moment fit, so the island ends one end padding past the marker or the last shown widget. Code: yieldSlots (input.marker or input.handle).

- **ZONE-55** An island spans from its first visible cell's start to its last visible cell's or marker's end, each plus the end padding; a zone with nothing visible has no island. Code: Bar.qml IslandSurface (visible only when shownLength > 0).

## Notice in Preferences

- **ZONE-56** When the lasting fit folds widgets on a monitor, Preferences' Layout page shows one line per monitor, sorted by monitor name: "N widgets don't fit on <monitor>. They're in the <zones> drawer." With one folded widget: "1 widget doesn't fit on <monitor>. It's in the Left drawer." The line follows bar size, spacing and layout changes. Code: ZoneFitNotice.sentence; LayoutEditor.fitNotes.

- **ZONE-57** The zones are listed in the fixed order Left, Center, Right, joined "Left and Center" or "Left, Center and Right"; the last word is "drawers" when more than one zone is named, else "drawer". Code: ZoneFitNotice.zoneList.

- **ZONE-58** With no folds on any monitor, or no fit data yet, there is no line. Moments never add to it.

## Edge cases and limits

- **ZONE-59** On a bar too short for the never-folded widgets (ZONE-13), everything else folds, `fits` is false and the zones may overlap (ZONE-12). Code: foldOne.

- **ZONE-60** A zone with one widget shows it whatever `fits` says (ZONE-13).

- **ZONE-61** A center whose widgets are all on demand or all folded still draws its dots; with no anchor, a center that is only its dots keeps them like an anchor when other zones yield. Code: fitMoment centerAnchor.

- **ZONE-63** Hidden on-demand widgets take no room in the lasting fit; only their dots do, and only in inline mode. Folding is decided first, then on-demand widgets wait behind the dots. Code: Bar.qml zoneFitList (hidden widgets have fitExtent 0).

- **ZONE-64** Width hold: a widget's cell grows at once and shrinks only after it has been narrower for 8 s, so a changing value does not make the bar breathe; losing at least one icon cell (20 px on the standard bar) shrinks at once. The hold arms 2 s after the bar loads. A widget with `powerbarWidthHold: false` (the tray, Indicators) opts out. Code: CellModel.hold; Bar.qml updateHold, widthHoldMs.

## Clean defaults and widgets that draw nothing

- **ZONE-65** With none of the `powerbar*` keys set, Powerbar lays out Omarchy's bar plus its Preferences button: flat, top, the theme's size (26 px, 26 px reserved), spacing 4 (icons 27 px apart), Equal slots, nothing on demand. Code: BarModel.options; tests/clean-defaults.test.cjs.

- **ZONE-66** On a flat bar the zones keep their end glyphs where Omarchy's bar has them: the first and last glyph's centre sits 8 + 27 / 2 = 21.5 px from the screen's side. The zone inset is `max(0, 8 + iconSlot / 2 - inset - cell / 2)`, 8.5 px on the 26 px bar and 2.5 px on the large bar, at every spacing and in both spacing modes. Floating and islands bars keep 4 px (`edgeGap`) instead. Code: CellModel.flatEdge; Bar.qml islandScreenInset.

- **ZONE-67** A widget with nothing to show (no updates, Bluetooth off, an empty tray) draws nothing and takes no room, as on Omarchy's bar, unless the user placed it: an explicit `powerbarVisibility: "shown"` or On demand keeps a fallback icon in its cell. Code: ManagedModel.placeholder; Bar.qml needsPlaceholder.

- **ZONE-68** `omarchy.tray` is pinned to its zone's inner end: first in the right zone, last in the left and center zones, wherever the saved layout lists it. Code: BarModel.pinTrayToInner.

- **ZONE-69** The Preferences button (nine dots, 3 x 3) is the last cell of the right zone (bottom of a vertical bar); it counts in the fit and never folds. Code: Bar.qml zoneFitInputs ("prefs").

- **ZONE-70** With Animations on the center's slide takes 200 ms (cubic-bezier 0.77, 0, 0.175, 1) and a widget's cell resizes over 120 ms; with Animations off both land in one frame. Code: Bar.qml fitShift Behavior; slot motionDuration.

- **ZONE-71** Each monitor's bar fits independently from its own length: a short monitor folds widgets that a long one shows. Code: Bar.qml zoneFitInputs (per bar window).

## Doc drift

- docs/design/zone-fit.md:218 says the fit's `inset` is "0 on Flat, edgeGap otherwise". Code: a flat bar's inset is `CellModel.flatEdge` (8.5 px on the 26 px bar), Bar.qml:1848.
- docs/design/spacing.md:102 puts the "Spacing" choice in a "Style section"; in Preferences it is in the Size tile (Preferences.qml:633, :644).
- CONTEXT.md ("Inline expansion") says the zone falls back to the drawer "only when the expanded zone can't fit the bar line"; the fit also falls back when the source widget is folded or when two growing zones meet and the other cannot yield (ZoneFitModel.js fitMoment, reasons `folded` and `neighbour`).

## Open questions

- None. Resolved from code: the on-demand exit grace is 1 s by default (`powerbarManagedExitGraceSeconds`), spacing runs 0 to 16, `powerbarSpacingMode` has a Preferences control, and the moment gap is a fixed 4 px.
