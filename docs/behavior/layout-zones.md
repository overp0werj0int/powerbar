# Layout zones behavior

Powerbar organizes widgets into five zones, Omarchy's sections: Left, Left of center, Center, Right of center and Right on a horizontal bar (Top, Above center, Center, Below center and Bottom on a vertical one). For the fit, Left of center, Center and Right of center make one center zone around the center box. Zones never overlap: a solver keeps one zone gap (the icon cell plus the widget spacing) between them, folding widgets behind a drawer handle when the bar is too short. This file owns zones, placement and order, spacing, zone fit, dots, bar position and bar size. Preferences controls for these are in preferences.md; the CLI and IPC calls (`set spacing`, `set largeBar`, `set style`, `set position`, `managed <zone>`, `keysStatus`, `drawerStatus`, `managedStatus`) are in integration.md.

Sources: SectionsModel.js (read, write), ZoneFitModel.js (fit, fitLasting, fitMoment), CellModel.js (tokens, flatEdge), ZoneOrderModel.js, ZoneFitNotice.js, BarModel.js (options, barStyle, pinTrayToInner), AppearanceModel.js (ranges.spacing), Bar.qml (grep: zoneFit, zoneGap, edgeGap, islandScreenInset, barSizeFor, FoldHandle, YieldMarker, beginBarMove), tests/zone-fit.test.cjs, tests/zone-order.test.cjs, tests/cell.test.cjs, tests/zone-fit-notice.test.cjs, tests/clean-defaults.test.cjs.

Numbers below use Omarchy's default theme tokens: bar 26 px (horizontal) or 28 px (vertical), icon slot 27 px, and Powerbar's default spacing 4.

## Zones and placement

- **ZONE-1** Widgets are stored per zone in `bar.layout.left`, `centerBegin`, `center`, `centerEnd` and `right` of shell.json, in that order along the bar; `bar.layout.tray` holds the widgets Omarchy draws in its tray's drawer. On a vertical bar (`bar.position` left or right) the same lists draw top to bottom. Every edit works on these five lists; an Omarchy without the new sections gets three lists back (ZONE-93). Code: SectionsModel.lists; Bar.qml normalizeLayout.

- **ZONE-2** A zone with nothing to draw has no island and adds no gap: with an empty center, left and right keep one zone gap from each other; with an empty left or right zone, the remaining zones are limited only by the screen inset (ZONE-66). Code: ZoneFitModel.layout (a zone of length 0 adds no gap).

- **ZONE-3** The center box is `bar.layout.center`. With room, the box is centred on the middle of the bar line; Left of center (`centerBegin`) hangs off its start, growing away from it, and Right of center (`centerEnd`) off its end. If the left or right zone needs the room, the whole center slides by the least distance that keeps one zone gap, then widgets fold (ZONE-9). An empty box is a mark of no length where the two sides meet, at the middle. Code: Bar.qml CenterModules; ZoneFitModel.zoneItems, resultOf (centerShift).

- **ZONE-5** Zones never overlap along the bar line: two neighbouring visible islands are at least the zone gap apart, `zoneGap = cell + spacing` (default 20 + 4 = 24 px on the 26 px bar), and every zone stays inside the screen inset. Moments (ZONE-29) keep a smaller gap (ZONE-33). Code: Bar.qml zoneGap; tests/zone-fit.test.cjs assertClear.

- **ZONE-6** The fit runs once per bar window (one per monitor, ZONE-71) along the bar line (width on a horizontal bar, height on a vertical one). Inputs: line length, screen inset, zone gap, each zone's widget extents, and which zones have dots. Output: which widgets show, which fold behind the zone's drawer handle, and how far the center slides. It re-runs when an input changes (a widget's size, spacing, bar size, monitor size). Code: ZoneFitModel.fit; Bar.qml refit().

- **ZONE-7** Two kinds of fit: **lasting** (the resting layout, which decides folding) and **moment** (temporary growth: drag gap, indicators reveal, activity reveal, inline expansion). A lasting fit slides the center and folds; a moment slides nothing and makes neighbours yield (ZONE-29). Code: ZoneFitModel.fitLasting, fitMoment.

- **ZONE-8** Hysteresis: a folded widget unfolds only when its zone would then still have one gutter (3 px plus spacing) to spare. One pixel of growth leaves the folds unchanged, and a widget whose size alternates by 1 px around the threshold changes the folding at most once in 20 changes. Code: fitLasting (`lo + gutter <= hi`); test "hysteresis".

## Folding: longest zone first, from the far end

- **ZONE-9** When the line is too short, one widget folds at a time, from the longest zone, until the zones fit (ties go to left, then right, then center). From the left zone the last widget folds; from the right zone the first; from the center, the first widget of Left of center or the last of the box and Right of center together, taken from the side with more shown widgets (Left of center on a tie). Code: ZoneFitModel.foldOne.

- **ZONE-10** Folded widgets wait behind the zone's drawer handle (dots), at the end facing the gap: the left zone's last cell, the right zone's first cell. The center has one handle per side that has folded or hidden on-demand widgets: at the start of Left of center, at the end of Right of center, or both. Folded widgets of the box wait with Right of center's. Code: ZoneFitModel.handlesOf, centerHandles.

- **ZONE-11** Unfolding runs in reverse order of folding: when the bar grows enough (ZONE-8), the most recently folded widget returns first. Code: fitLasting.

- **ZONE-12** If nothing more can fold and the zones still collide, the fit reports `fits: false`; the center then sits directly after the left zone and may overlap the right zone. Nothing is dropped. Code: foldOne returns false; resultOf.

- **ZONE-13** Never folded: the box's first widget, the left zone's first widget, and the right zone's last widget (always the Preferences button, ZONE-69). A side zone folds only while it holds more than one unfolded widget. Code: foldOne.

## Dots (drawer handle) and counts

- **ZONE-14** A zone shows dots only while something waits behind them: widgets folded for lack of room, and with `powerbarOnDemand: "inline"` or `"menu"` also its hidden on-demand widgets. In the default `"drawer"` mode with nothing folded there are no dots. They draw as one small empty circle, 4 px across with a 1 px outline in the bar's foreground at 55 % opacity, on either orientation, centred in a glyph-sized cell so it is as easy to point at as an icon. Code: Bar.qml FoldHandle (shown when count > 0); ZoneDot.qml.

- **ZONE-15** The dots take one glyph cell (a 12 px glyph's slot: 27 px at spacing 4) and the lasting fit reserves it, so a zone does not change length when its on-demand widgets hide or return. The cell eases in and out over 120 ms with Animations on. Code: ZoneFitModel.slotsOf; FoldHandle width Behavior.

- **ZONE-16** The count badge on the dots is the number of folded widgets plus, in inline and menu modes only, the on-demand widgets hidden on that side (the center's two handles each count their own side). It reads "99+" above 99. `powerbarDotsBadge: false` (Preferences > Bar > On demand > Count on the dots) hides the badge on the dots and on yield markers; the dots' tooltip, "1 more widget" or "N more widgets", shows either way. Code: FoldHandle count, label.

- **ZONE-18** Hovering the dots in inline mode, or clicking them, expands the zone in the bar and brings back that zone's folded widgets for the moment; see on-demand-drawers.md, "Inline expansion", for timing (90 ms intent, 170 ms settle, 1 s exit grace by default) and the drawer fallback. In drawer mode hovering or clicking the dots opens the zone's drawer, which lists the folded widgets. Code: Bar.qml inlineEnter; FoldHandle MouseArea.

## Spacing and cell sizes

- **ZONE-19** `powerbarSpacingMode` (Preferences > Bar > Size > Spacing: "Equal slots", "Equal gaps") is `"slots"` by default (any value but `"gaps"` reads as slots). **Equal slots**: every item gets a cell (a square for glyphs) plus a gutter, so cells sit one gutter apart. **Equal gaps**: every glyph gets the same gap before and after it, and a cell may spill past its ink into the gaps. Code: BarModel.options; CellModel.place.

- **ZONE-20** A cell is the bar thickness minus two insets: `inset = min(3, (bar - 16) / 2)`, `cell = bar - 2 * inset`. 26 px bar: inset 3, cell 20. Large bar (38 px): cell 32. Vertical 28 px: cell 22. Large vertical (40 px): cell 34. The cell is also the hover highlight. Code: CellModel.tokens.

- **ZONE-21** An item is a glyph if its widget says so or its ink is at most 16 px; a glyph's cell is square (the cell size) while its ink fits. Any other item takes `max(cell, ink + 2 * air)` with `air = (cell - 12) / 2` (4 px on the 26 px bar). Free text (a window title, a media label) is capped at 160 px of ink; compounds (several click targets) and vertical stacks are not. The ink is what the widget paints, not the box it asks for: a drawn icon with text of its own beside it (omabox's mark and its box count) spans both, so its cell, on the bar and in a drawer strip, holds the count whole (a menu row still centres the icon alone in its icon cell, GROUP-96). Code: CellModel.isGlyph, cellLength, MAX_INK; HighlightModel.inkRect, textBeside.

- **ZONE-22** Space between widgets (`powerbarSpacing`; Preferences > Look > Size > "Widget spacing") takes whole units from 0 ("None") to 16, default 4, scaled by the theme's spacing scale; a stored value outside that range reads as the nearest limit, a non-number as 4. It widens gutters and gaps, never cells: `gutter = inset + spacing`, `gap = cell / 2 + 2 + spacing`. Standard bar: spacing 0 gives gutter 3 and gap 12; the default 4 gives gutter 7 and gap 16, so in Equal slots icons sit 27 px apart (20 + 7), Omarchy's own icon slot. Changing spacing, spacing mode, bar size or orientation resets every widget's width hold (ZONE-64). Code: AppearanceModel.ranges.spacing, CellModel.tokens; tests/clean-defaults.test.cjs.

- **ZONE-23** `powerbarLargeBar: true` (Preferences > Bar > Size > Large bar; default off) makes the bar 12 px thicker, a 6 px lip above and below: 26 to 38 px horizontal, 28 to 40 px vertical. Widgets keep their own size and gain room around them; cells, highlights and island ends grow with the bar. Code: Bar.qml barSizeFor, largeBarLip.

- **ZONE-24** The bar reserves `barSize` px of the screen edge on a flat bar, and `barSize + 8` px (2 x `edgeGap` 4) on floating and islands bars. An autohidden bar reserves nothing (see appearance.md, "Bar auto-hide"). Code: Bar.qml barExtent, exclusiveZone.

## Ordering within zones

- **ZONE-25** On-demand widgets draw as one run at their zone's dots end, in saved order: the left zone's end, the right zone's start. Always-shown widgets keep their saved order and never move when on-demand widgets appear (an expansion, an activity reveal, a drop preview). The saved layout is not rewritten; only the drawing differs. Code: ZoneOrderModel.arrange.

- **ZONE-26** Each on-demand widget of the center waits behind its own side's dots: Left of center's at its start, Right of center's at its end. The box's on-demand widgets are counted on the dots of the side of the camera it sits on (ZONE-96; Right of center's unless `powerbarCenterSide` is "left") and draw with that run. Code: ZoneOrderModel.arrange (lists `centerBegin`, `center`, `centerEnd`); SectionsModel.sideOf.

- **ZONE-27** A drop into a bar gap writes the widget into the saved layout so it lands exactly at the gap: into the list of the widget it lands beside, before the first widget of its own run (always-shown or on-demand) after the gap; else after the last such widget before the gap; else at the list's end. Code: ZoneOrderModel.dropBefore; tests/zone-order.test.cjs.

- **ZONE-28** A drop on a zone's dots makes the widget On demand at that zone's dots end: see drag-edit.md DRAG-28 and DRAG-29.

## Moments and yields

- **ZONE-29** A moment is temporary growth of one zone: a drag gap, the indicators' held reveal, an activity reveal, an inline expansion. Several may run at once, highest priority first, an expansion last. Nothing slides; every neighbour of a growing zone yields: whole widgets hide from the end facing the growing zone (left zone from its end, right zone from its start, center from the facing side), fading out but keeping their space, and the island ends at its last visible cell. A moment other than a held inline expansion that lasts over 10 s counts as lasting and is dropped from the fit. Code: ZoneFitModel.fitMoment; Bar.qml zoneFitMoments, ageMoments.

- **ZONE-30** Where widgets yielded, a quiet marker (the dots' circle at 35 % opacity, not interactive) takes the first freed cell, with the count of widgets out of view (badge as ZONE-16). Resting the pointer on the marker for 90 ms ends the moment that made them give way. Code: Bar.qml YieldMarker, releaseYield.

- **ZONE-31** An inline expansion whose neighbour would have to yield its anchor (a widget that never folds, ZONE-13) hides that whole neighbour zone instead (dots included; its island fades with no marker); if the zone past it still collides, it yields in turn or hides whole. The camera's slot is never hidden or crossed (ZONE-89): an expansion that would need the centre, with that slot, to hide falls back to its drawer (ZONE-34, reason `notch`). An expanding center that would run off the bar slides back onto it by the least distance. Code: fitMoment attempt(), hide().

- **ZONE-32** When two growing zones meet, the higher-priority one keeps its growing widget and yields the rest towards the other; if it cannot (an anchor would have to yield), the lower one falls back. Code: fitMoment attempt().

- **ZONE-33** A moment keeps a smaller gap than a lasting fit: `momentGap = edgeGap = 4 px` (not a share of the zone gap), so hovering the indicators does not hide neighbours that still fit. Code: Bar.qml zoneFitInputs momentGap.

- **ZONE-34** A moment that cannot be served falls back, for one reason: `folded` (its source widget is folded), `screen` (the zone would run off the bar line), `anchor` (an anchor would have to yield and the moment is not an inline expansion), `neighbour` (two growing zones meet and the other cannot yield) or `notch` (an inline expansion would run over the camera, ZONE-31). An inline expansion that falls back collapses and the zone's drawer opens instead. Code: fitMoment fallbacks; Bar.qml refit().

## Inline expansion in the fit

- **ZONE-35** An inline expansion counts the zone's hidden on-demand widgets as shown at their measured size (they stay loaded at opacity 0), unfolds that zone's folded widgets, and drops that zone's dots for the moment. Code: Bar.qml zoneFitList(expand), inlinePlan; fitMoment unfold.

- **ZONE-36** The center expands one side at a time: the dots at Left of center's start expand and unfold its run, the dots at Right of center's end the run of the box and Right of center (tokens `center:start`, `center:end`); the other side's folds stay folded. Code: fitMoment sides; Bar.qml inlineToken.

- **ZONE-37** Before expanding, the bar fits the zone as if expanded beside every other moment running; if that would fall back, the zone's drawer opens instead and the bar does not change. Code: Bar.qml inlinePlan.

## Position, style and configuration

- **ZONE-38** The bar edge is `bar.position` (top, bottom, left, right; anything else reads as top), also set by Preferences > Bar > Screen edge. Pressing empty bar space and holding 200 ms, or moving 4 px with the button down, starts a bar move: overlays show the candidate edge (the screen is split along its diagonals, so the pointer's nearest edge wins); releasing over a different edge writes `bar.position`. A plain click on empty space does not move the bar. Code: Bar.qml CenterGestureArea, nearestScreenEdge, setBarPosition.

- **ZONE-39** A layout entry has `id` (widget id), `powerbarInstance` (a unique key Powerbar assigns once) and optionally `powerbarVisibility` (`shown`, `managed`, `hidden`). A widget with no `powerbarVisibility` is shown, third-party widgets included; see on-demand-drawers.md, "Managed widget modes", for the modes, and integration.md, "Config healing", for the one-time heal (`bar.powerbarVisibilityDefault: "shown"`) that keeps older configs' third-party widgets on demand. Code: ManagedModel.mode, healVisibility.

- **ZONE-40** There is no pinned widget: what sits in the center box is centred. Earlier versions' `bar.centerAnchor` ("Pinned to screen center") is read once as the box (ZONE-91) and is gone after the next write, except on an Omarchy without the new sections (ZONE-93). Code: SectionsModel.read.

- **ZONE-41** `bar.powerbarStyle` is `flat` (default), `floating`, `islands` or `notch`; for any other value, `powerbarIslands: true` (older configs) reads as islands, else flat. **Flat**: one square, borderless surface edge to edge, like Omarchy's bar. **Floating**: one rounded, bordered surface held 4 px off the edge and the screen's sides. **Islands**: each zone with something to draw on its own such surface. **Notch**: black ears around the camera on a notched screen's top edge, islands everywhere else (ZONE-82). Rounding and borders apply to floating and islands, not to the flat strip. Code: BarModel.barStyle; Bar.qml notchStyle, barStyle, mainStrip, floating surface, IslandSurface.

- **ZONE-42** Default spacing is 4 (ZONE-22): a shell.json with no `powerbarSpacing` draws icons 27 px apart.

- **ZONE-43** Default spacing mode is slots (ZONE-19).

- **ZONE-44** Default large bar is off (ZONE-23).

- **ZONE-45** `bar.powerbarOnDemand` is `"drawer"` (default; any value except `"inline"` and `"menu"` reads as drawer), `"inline"` or `"menu"`. Switching it collapses an open expansion and closes an open drawer or menu at once. See on-demand-drawers.md. Code: BarModel.options; Bar.qml onOnDemandModeChanged.

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

- **ZONE-61** A center whose widgets are all on demand or all folded still draws its dots; an empty box keeps its mark at the middle, so the two sides keep their places when other zones yield. Code: ZoneFitModel.zoneItems (the box's mark); fitMoment.

- **ZONE-63** Hidden on-demand widgets take no room in the lasting fit; only their dots do, and only in inline and menu modes. Folding is decided first, then on-demand widgets wait behind the dots. Code: Bar.qml zoneFitList (hidden widgets have fitExtent 0).

- **ZONE-64** Width hold: a widget's cell grows at once and shrinks only after it has been narrower for 8 s, so a changing value does not make the bar breathe; losing at least one icon cell (20 px on the standard bar) shrinks at once. The hold arms 2 s after the bar loads. A widget with `powerbarWidthHold: false` (the tray, Indicators) opts out. Code: CellModel.hold; Bar.qml updateHold, widthHoldMs.

## Clean defaults and widgets that draw nothing

- **ZONE-65** With none of the `powerbar*` keys set, Powerbar lays out Omarchy's bar plus its Preferences button: flat, top, the theme's size (26 px, 26 px reserved), spacing 4 (icons 27 px apart), Equal slots, nothing on demand. Code: BarModel.options; tests/clean-defaults.test.cjs.

- **ZONE-66** On a flat bar the zones keep their end glyphs where Omarchy's bar has them: the first and last glyph's centre sits 8 + 27 / 2 = 21.5 px from the screen's side. The zone inset is `max(0, 8 + iconSlot / 2 - inset - cell / 2)`, 8.5 px on the 26 px bar and 2.5 px on the large bar, at every spacing and in both spacing modes. Floating and islands bars keep 4 px (`edgeGap`) instead. Code: CellModel.flatEdge; Bar.qml islandScreenInset.

- **ZONE-67** A widget with nothing to show (no updates, Bluetooth off, an empty tray) draws nothing and takes no room, as on Omarchy's bar, unless the user placed it: an explicit `powerbarVisibility: "shown"` or On demand keeps a fallback icon in its cell. Code: ManagedModel.placeholder; Bar.qml needsPlaceholder.

- **ZONE-68** `omarchy.tray` is pinned to its zone's inner end: first in the right zone, last in the left and center zones, wherever the saved layout lists it. Code: BarModel.pinTrayToInner.

- **ZONE-69** The Preferences button (nine dots, 3 x 3) is the last cell of the right zone (bottom of a vertical bar); it counts in the fit and never folds. Code: Bar.qml zoneFitInputs ("prefs").

- **ZONE-70** With Animations on the center's slide takes 200 ms (cubic-bezier 0.77, 0, 0.175, 1) and a widget's cell resizes over 120 ms; with Animations off both land in one frame. Code: Bar.qml fitShift Behavior; slot motionDuration.

- **ZONE-71** Each monitor's bar fits independently from its own length: a short monitor folds widgets that a long one shows. Code: Bar.qml zoneFitInputs (per bar window).

## Five zones and older configs

- **ZONE-91** Every config is read into the five lists before it is drawn or edited (`SectionsModel.read`):
  - Omarchy's six sections are read as they are.
  - Powerbar's three zones with `bar.centerAnchor`: the center splits at the anchor, which becomes the box; what was before it becomes Left of center, what was after it Right of center. Groups go with the list their widget went to. Without an anchor (missing, empty or not in the center), the whole center is the box.
  - The retired zone modes (`bar.powerbarZones`): two zones keep their left and right lists; the notch's left and right become Left of center and Right of center, in the Notch style (ZONE-82).
  - `centerAnchor`, `powerbarZones` and `powerbarZoneLayouts` are gone after the next write.

  Code: SectionsModel.read, needsRead; ConfigStore.mutate.

- **ZONE-92** The arrangements the zone modes kept for the modes not in use (`bar.powerbarZoneLayouts`) are not used. The first time Powerbar starts on such a config, it copies them to `~/.cache/powerbar/zone-layouts-<date>.json` (private to the user, never overwritten, never read back), then saves the config in the five lists. If the copy fails, shell.json keeps them. Code: Bar.qml retireZoneModes.

- **ZONE-93** An Omarchy without the new sections (`Util.barSections` lacks them) keeps `left`, `center` and `right`. Powerbar writes the three center lists there as one `center` list, with `bar.centerAnchor` naming the box's widget and `bar.powerbarFiveZones` (`{ begin, center }`, the lengths of Left of center and the box) beside it, so the next read finds the same five lists. Omarchy's own bar centres that anchor, so the box holds one widget there: when it holds more, the others lead Right of center, with their groups. A count that no longer fits (another writer changed the center) falls back to the anchor. Code: SectionsModel.write, oneInBox.

- **ZONE-94** One layout serves every screen and every edge; nothing is kept per screen or per style. Code: Bar.qml normalizeLayout.

- **ZONE-95** A drag dropped on the bar away from any widget goes to the zone it is over: the left, the center or the right third of the bar, and in the center the side of the box it is on. Code: Bar.qml barZoneAt, zoneDropList.
- **ZONE-96** On a notched screen the Center zone's widgets sit beside the camera, on the right of it unless `powerbarCenterSide` is "left" (default right; `omarchy-shell powerbar set centerSide left|right`; Preferences > Layout, the dot beside the camera, PREFS-105). On the left they come after Left of center, next to the camera, and count with Left of center's dots; on the right they come before Right of center, next to the camera, and count with its dots. A screen without a camera is not affected: the three center lists share the center. In the split styles (ZONE-89) the fit then puts the camera's slot after the box, which ends at the camera with Left of center and folds with it, from Left of center's far end in; in the Notch style (ZONE-82) the box joins the left side's run. Code: BarModel.options centerSide; ZoneFitModel.prepare (`boxBefore`); RenderModel.zoneOf, records; SectionsModel.sideOf; Bar.qml CenterModules `boxBefore`, zoneLists, reconcileWidgets; tests/notch.test.cjs.

- **ZONE-89** On a notched screen with a top bar, in the Flat, Floating and Islands styles, the center splits around the camera:
  - Left of center ends at the camera's left edge. The box and Right of center start at its right edge (the box on the other side with `powerbarCenterSide` "left", ZONE-96).
  - The keep-out is the camera's width (ZONE-80) plus a screen edge's inset (`islandScreenInset`) on each side. Each side's island edge sits exactly on it, from its own end pad.
  - The fit places the keep-out as a fixed slot just before the box, padded by the end pads of the cells beside it (`notchPads`). So the center never slides over the camera, and widgets fold towards their own side.
  - An inline expansion of the left zone makes Left of center yield up to the camera, never past it; one that still collides opens its drawer, as a second island under the bar (ZONE-31).
  - In islands style each side is its own island. A screen without a notch keeps one center as before.

  Code: Bar.qml notchSplit, notchKeepOut, notchSlotOf, CenterModules; ZoneFitModel zoneItems.

## Notch

- **ZONE-79** A screen has a notch when Omarchy's platform package describes it in `/usr/share/omarchy-platform/display-cutouts.json` (`{ "panels": [ { "connector", "width", "height", "top" } ] }`). The screen's connector name must start with `connector`, and its physical mode, as Hyprland reports it, must be `width` x `height` within 4 px.
  - A panel turned a quarter or upside down has no notch, and neither does a mode that leaves out the notch rows (Asahi's).
  - Until Hyprland reports the mode, the logical size times Qt's whole-number ratio stands in. If that matches no panel but a described connector names the screen, the bar waits for the mode, 2 s at most, before it maps.
  - These are the rules of Omarchy's own bar, so both bars agree.
  - `POWERBAR_DISPLAY_CUTOUTS` points at another file (for tests).

  Code: NotchModel.panelOf, pending; Bar.qml displayCutouts, notchFor.

- **ZONE-80** Only a top bar meets the notch.
  - Height: `powerbarNotchHeight` (logical px) when set, otherwise Omarchy's calibrated `[bar] notch-height` (`Style.bar.notchHeight`) when the theme sets one, otherwise the described rows scaled to logical px (32 on a 14" MacBook Pro at scale 2).
  - Width: `powerbarNotchWidth` (logical px) when set, otherwise the panel's camera housing, scaled. Omarchy's file has no width, so Powerbar's `notch-panels.json` lists each panel's, matched by mode the same way: 382 panel px on the 14" Pro (191 at scale 2), 384 on the 16", 325 on the 13" Air and 317 on the 15". A panel it lacks takes the 14" Pro's. Each row was measured on Apple's product bezel artwork, which draws the screen 1:1, and names its source.
  - Shape: each row also gives the housing's bottom-corner `radius` and its `shoulder`, the inside curve where the screen's top edge turns down into it (20 and 6 panel px on the 14" Pro, 10 and 3 at scale 2; 19 and 7 on the 16", 18 and 6.5 and 17 and 6 on the Airs). The width is along the top edge, so below the shoulders the housing is the width less two shoulders: 370 on the Pros, which is what macOS reports as the notch. A row without them takes the 14" Pro's.
  - Screen corners: each row gives `screenRadius`, the radius of the screen's own top corners (40 panel px on the 14" Pro, 20 at scale 2; 42, 36 and 35 on the others). The bottom corners are square. Apple's curves are continuous, so every curve is given as the quarter circle of the same area. Both are kept within the notch's height and shrink together to fit a narrower set width.

  Code: NotchModel.notchOf, parsePanels, housingOf, cornersOf; notch-panels.json.

- **ZONE-81** On a notched screen, the strip is at least as tall as the notch in every style (exactly as tall for a flat bar, ZONE-90). That way no window peeks out beside the camera. A floating bar that wraps the camera grows further, to keep a band under it (appearance.md LOOK-147). The exclusive zone, popups, drawers and the autohide distance all use that extent, and Omarchy's notch-height reports per screen take the same value (`screenBarSizes`). Code: Bar.qml extent, extentOf, screenBarSizes.

- **ZONE-82** The Notch style (`powerbarStyle: "notch"`) grows the bar out of the camera:
  - On the notched screen's top edge the bar has two ears. The left ear holds Left and Left of center and ends at the camera's left edge; the right ear holds Center, Right of center and Right and starts at its right edge. Both are drawn as black islands that run on under the camera. Their outer ends have the camera's corners: its shoulder at the top, its bottom radius below (appearance.md LOOK-143).
  - An ear's dots sit at its far end, by the screen edge: the left ear's start, the right ear's end. Its on-demand widgets expand there, so an expansion grows toward the edge and wraps (ZONE-85).
  - The keep-out gap there is the camera plus the inset a zone keeps from a screen edge, on each side.
  - On a screen without a notch the five zones are black islands with the camera's corners (appearance.md LOOK-143). On any other edge the Notch style draws as Islands in the bar's own look. The bar can move to another edge like any other.
  - On the notched screen, windows stop under the camera: the camera's height stays reserved while the bar autohides or is switched off.

  Code: Bar.qml notchStyle, notchMode, notchLook, notchLeft, notchRight, notchKeepOut, barStyle, exclusiveZone, zoneModels; RenderModel.zoneOf (ears); ZoneFitModel handlesOf (input.wrap); ZoneOrderModel.arrange (outward).

- **ZONE-83** In the Notch style on the notched screen the bar is always large, and the large bar is exactly as tall as the notch, on every screen. `powerbarLargeBar` applies to the other styles, and to the Notch style where it draws as islands. Code: Bar.qml largeBar, barSizeFor.

- **ZONE-84** On-demand widgets on the notch always wait behind their zone's dots: they expand in the bar, or with `powerbarOnDemand: "menu"` open in a menu under the dots (on-demand-drawers.md DEMAND-94); `"drawer"` reads as `"inline"` there, since the notch has no drawers. Code: Bar.qml onDemandMode.

- **ZONE-85** A zone that grows past the screen edge on the notch (an inline expansion on the notched screen) wraps onto a second row under the first:
  - **Which items move:** the left zone's first items or the right zone's last ones, as one block. The outermost still meets the screen edge, and the row reads from the edge toward the camera.
  - **Preferences stays put:** the Preferences button is the corner icon and never wraps. It keeps its place at the right screen edge in the first row; the first row's widgets stop where it begins, and those past that point wrap.
  - **No yielding:** a moment never makes another zone yield or hide.
  - **No fallback:** running past the screen edge is no reason to fall back.
  - **Shape:** the black is one coat-hanger shape. A cap at the screen edge spans both rows with the camera's corners (the shoulder at the top, its bottom radius below), and the second row ends toward the camera with the same radius, meeting the first with an inside curve.

  Code: NotchModel.wrapRow; ZoneFitModel (input.wrap); Bar.qml zoneWrap, applyWrap; NotchHanger.qml.

- **ZONE-86** The second row opens from the screen edge over 200 ms (ease-out). Moved items take their places at once and fade in over 90 ms as the black reaches them. When the expansion ends, they return to the first row at once and the empty row closes back into the edge over 200 ms. The keyboard cursor, its highlight and hover cards follow the items into the second row, and a card from the first row keeps clear of the second. Code: NotchHanger reach; Bar.qml wrapOpacity, cellHighlight, wrapRowNear.

- **ZONE-87** With autohide on the notch, or with the bar switched off there (appearance.md LOOK-144):
  - The strip does not slide off the screen. Each zone slides sideways into the camera and is clipped at the camera's edge.
  - The camera alone reveals an autohidden bar; a switched-off bar stays in.
  - An activity peek brings the widget that changed out of the camera on its own badge; the zones stay in.

  Code: Bar.qml slideNotch, zoneOut, autoHideStrip, PeekBadge; ZoneClip.

- **ZONE-88** On the notched screen a group's drawer (a strip or a menu) comes out of the bar as the zones come out of the camera, downward:
  - **Attached:** it hangs from the bar's bottom edge with no gap, black with the bar's light text, and no border.
  - **Shape:** where it meets the bar, its top corners curve up into the bar's edge with the camera's shoulder, as the screen's top edge curves into the camera; its bottom corners have the camera's bottom radius (appearance.md LOOK-143).
  - **Motion:** it slides down out of the bar, cut at the bar's bottom edge: 220 ms with the zones' spring (overshoot held to 4 px) out, 140 ms ease-out back in. While the spring overshoots, its top stays on the bar and the drawer stretches by those few px instead of leaving a gap. It does not fade or scale.
  - **Size:** as on every bar (on-demand-drawers.md DEMAND-92).
  - Other screens keep the floating island drawer.

  Code: ManagedDrawer.qml fromNotch, clipper (overshoot), Behavior on reveal; NotchShape.qml.

- **ZONE-90** A flat top bar on a notched screen, large or small, is exactly as tall as the notch (32 px on a 14" MacBook Pro at scale 2, or the set height, ZONE-80). It lines up with the camera's bottom edge, like macOS's menu bar.
  - The two look the same there: "Large bar" changes nothing on that screen, since the strip is the camera's height either way. Cells are the large bar's along the bar (its cell, gaps and the inset off the screen's sides); across it they are the strip less the usual 3 px inset on each side (26 px in a 32 px strip). Highlights, drop outlines, the dots, their badge, the yield marker and the peek badge follow.
  - Only on the notched screen: other screens keep the bar's own size and cells, so bars on different screens can differ.
  - The exclusive zone and Omarchy's per-screen bar size (`screenBarSizes`, read by notifications) take the notch's height.
  - The islands and floating styles and the Notch style keep their own rules (ZONE-81, ZONE-83).

  Code: Bar.qml fitsNotch, notchTokensFor, tokensIn, sizeIn, thicknessIn, screenInsetIn, endPadIn, zoneGapIn, highlightRadiusIn, cellHighlight; barWindow notchFit, barSize, cellTokens, extent.

## Retired IDs

ZONE-72 to ZONE-78 described the zone modes (three zones, two zones, the notch), each with its own saved arrangement; they gave way to the five zones (ZONE-91 to ZONE-95) and the Notch style (ZONE-82).

## Doc drift

- docs/design/zone-fit.md:218 says the fit's `inset` is "0 on Flat, edgeGap otherwise". Code: a flat bar's inset is `CellModel.flatEdge` (8.5 px on the 26 px bar), Bar.qml:1848.
- docs/design/spacing.md:102 puts the "Spacing" choice in a "Style section"; in Preferences it is in the Look page's Size strip (LookEditor.qml, preferences.md PREFS-66).
- CONTEXT.md ("Inline expansion") says the zone falls back to the drawer "only when the expanded zone can't fit the bar line"; the fit also falls back when the source widget is folded, when two growing zones meet and the other cannot yield, or when it would run over a camera notch (ZoneFitModel.js fitMoment, reasons `folded`, `neighbour` and `notch`).

## Open questions

- None. Resolved from code: the on-demand exit grace is 1 s by default (`powerbarManagedExitGraceSeconds`), spacing runs 0 to 16, `powerbarSpacingMode` has a Preferences control, and the moment gap is a fixed 4 px.
