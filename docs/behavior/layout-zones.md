# Layout zones behavior

Powerbar organizes widgets into three zones (left, center, right) along a horizontal bar or (top, middle, bottom) along a vertical bar. Zones never overlap: a solver adjusts widget visibility and positioning to keep a gap (the cell size plus widget spacing) between zones. Widgets folded for lack of room wait behind drawer handles and (in inline mode) behind dots at the zone's end.

Sources: ZoneFitModel.js (fit, fitLasting, fitMoment), CellModel.js (spacing tokens), ZoneOrderModel.js (on-demand ordering), BarModel.js (config, bar style, position), BarPlacement.qml (orientation), tests/zone-fit.test.cjs (fit behaviors, hysteresis, moments, yields), tests/zone-order.test.cjs (drawing order, drop landing), tests/cell.test.cjs (spacing modes), tests/zone-fit-notice.test.cjs (fold notification), README.md (orientation, zone architecture, configuration keys), docs/zone-fit-implementation.md, docs/spacing-implementation.md.

## Zones and placement

- **ZONE-1** The bar divides into three visible zones: **left** (or top on a vertical bar), **center** (or middle), and **right** (or bottom). All widgets begin in one zone, set in Preferences and stored in `bar.layout.<zone>` in shell.json.

- **ZONE-2** A bar may have no center zone (leaving only left and right), in which case the center anchor is null and no center widgets show. The left and right zones then face each other without a center gap.

- **ZONE-3** A center zone with an anchor widget keeps that widget exactly centered, with left-side widgets before it and right-side widgets after. The anchor is stored in `bar.centerAnchor` in shell.json (a module id string; empty string disables anchoring). Anchors never fold or yield; they always show.

- **ZONE-4** When a bar has no center (anchor is null), the left and right zones remain separate. Any drop or drag remains within a zone.

## Zone fit (no overlap)

- **ZONE-5** The three zones never overlap along the bar line. A minimum gap (the cell size plus widget spacing, typically 20 px on a 26 px bar with spacing 0) separates each visible zone from its neighbours.

- **ZONE-6** Given a bar length (horizontal: width; vertical: height), an inset margin (typically 3 px), a gap between zones (the cell size plus widget spacing, typically 20 px for spacing 0), widget widths and their visibility mode, the fit solver produces a result: which widgets show, which fold into drawers, and where each zone starts along the bar.

- **ZONE-7** The solver runs in two modes: **lasting** (one-time folding for a static bar layout) and **moment** (transient, for inline expansions and reveals). Lasting fits are cached; moments update live while the pointer hovers.

- **ZONE-8** A lasting fit keeps the previous folding when a bar grows slightly (small growth does not unfold). When a bar shrinks and must refold, the folding is hysteresis-stable: alternating ±1 px around the threshold causes at most one folding change across 20 iterations.

## Folding: longest zone first, from the far end

- **ZONE-9** When widgets must fold, the solver picks the longest zone first. From that zone it folds the widget at the end away from the zone's anchor: the left zone's last widget, the right zone's first widget, or the center's end with more widgets (if before and after are equal length, before folds from its end).

- **ZONE-10** Folded widgets wait behind a drawer handle at the zone's end. The left zone's handle sits at its end; the right zone's handle sits at its start. A center with folded widgets shows one or two handles: at the start if it folds before-anchor widgets, at the end if it folds after-anchor widgets, or both. Without an anchor, the center's handle sits at its end.

- **ZONE-11** The folding order is tracked in `result.order` (the sequence in which widgets were folded). When a bar grows and can unfold, this order is preserved: widgets unfold in reverse order of folding.

- **ZONE-12** Anchors never fold. If no zone can shed widgets without losing its anchor, `result.fits` is false.

- **ZONE-13** A left zone's first widget (its anchor if present, or leftmost) never folds. A right zone's last widget (its anchor if present, or rightmost) never folds. A center anchor never folds. This ensures zones remain identifiable.

## Inline mode: dots and handles

- **ZONE-14** In inline on-demand mode (`bar.powerbarOnDemand: "inline"`), a zone with hidden on-demand widgets shows a drawer handle with a count badge (if `powerbarDotsBadge` is true, the default). The handle appears at the zone's end away from its anchor (same positions as in ZONE-10).

- **ZONE-15** The handle (dots, ⋯ on horizontal bars and ⋯ on vertical bars) is a placeholder: its width/height is `input.handle.extent` (typically the icon cell size). It reserves space in the lasting fit so the zone doesn't shrink when on-demand widgets appear.

- **ZONE-16** The count badge shows the number of folded widgets plus the number of on-demand widgets on that side. For a center without an anchor, the count is the number of center on-demand widgets. For a center with an anchor, the start-side handle counts before-anchor on-demand and folded widgets; the end-side handle counts after-anchor ones.

- **ZONE-17** On-demand widgets draw at the zone's end (the side facing the gap), in their saved order. Left zone on-demand widgets appear at the left end; right zone ones at the right end; center on-demand widgets appear at the anchor's side (before-anchor on-demand at the start, after-anchor on-demand at the end).

- **ZONE-18** When a zone expands inline (the dots are hovered and the expansion fits), folded widgets in that zone return to view for the moment; their drawn order is: shown widgets, then folded widgets (at the dots' end). The expansion collapses after the pointer leaves the zone by the exit grace period (5 s).

## Spacing modes and sizing

- **ZONE-19** Two spacing modes arrange slots along the bar. **Equal slots** (default): every item gets a cell (square for glyphs, text plus air on both sides) plus a gutter on each end. Cells are one gutter apart. **Equal gaps** (`powerbarSpacingMode: "gaps"`): every glyph gets the same gap before and after; text gets its own cell and spill, with the gap between glyphs.

- **ZONE-20** A cell's size is the bar's thickness minus two insets (top/bottom on horizontal bars, left/right on vertical bars). On a 26 px bar, a cell is 20 px (inset 3 px). On a large bar (38 px), a cell is 32 px. On a 28 px vertical bar, a cell is 22 px.

- **ZONE-21** Text is capped at 160 px of painted ink unless it is a compound or vertical stack (uncapped). The cell length is the maximum of the icon cell size or the ink (capped for free text) plus air on both sides (air = (cell - 12) / 2). Glyphs read as icons if marked as such or painted ≤16 px.

- **ZONE-22** Widget spacing (`powerbarSpacing`, range 0–8 in Preferences) widens gutters and gaps, never cells. On a standard bar, `spacing: 0` → gutter: 3, gap: 12; `spacing: 4` → gutter: 7, gap: 16. Changing spacing resets width hold on all widgets.

- **ZONE-23** Bar size (`powerbarLargeBar: true`) makes the bar 12 px thicker: 38 px horizontal (standard 26), 40 px vertical (standard 28). Cells grow accordingly; highlights and island radius scale with the bar.

- **ZONE-24** The bar's extent along the screen edge is `renderedBarSize + (flat ? 0 : edgeGap * 2)`, where `renderedBarSize` is the visible bar's length (widgets plus zone spacing) and `edgeGap` is 0 for flat bars, or the theme's surface gap for floating/islands bars.

## Ordering within zones

- **ZONE-25** On-demand (managed) widgets draw as one run at their zone's end, in saved order, separate from always-shown widgets. Always-shown widgets stay put and never move when on-demand widgets appear.

- **ZONE-26** In a center zone with an anchor, on-demand widgets are split by side: those saved before the anchor draw at the start, those after draw at the end. Each side draws its on-demand widgets in their saved order.

- **ZONE-27** When a drop lands in the bar, the widget joins the run of its visibility (always-shown or on-demand) at the gap. Its position in the saved layout is: before the first on-demand (or always-shown) widget of the same run at the gap, else after the last one before the gap, else beside the anchor (for center), else at the zone's end.

- **ZONE-28** Dragging onto the zone's dots moves the widget to the dots' end (the zone's end away from the anchor) and sets it to on-demand (managed). In center zones, dragging onto the start-side dots places it before the anchor (managed); dragging onto the end-side dots places it after the anchor.

## Moments and yields

- **ZONE-29** A **moment** is a transient state during inline expansion, activity reveal, or other growth. Moments don't slide the center; instead, neighbours yield to every growing zone. When two growing zones meet, the higher-priority one keeps its growing widget and yields the rest; if that is not enough, the lower-priority one falls back (`result.fallback`).

- **ZONE-30** A zone yields by hiding widgets from its end facing the growing zone: the left zone yields from its end, the right zone from its start, the center from the side facing growth. Yielded widgets are marked in `result.yielded` (a list of keys); their end of the zone shows a marker cell (a quiet, non-interactive dots icon with the yielded count, or the same marker as a handle if the zone's drawer handle is there).

- **ZONE-31** An inline expansion that would need an anchor to yield instead hides that entire neighbour zone (`result.hidden`), then hides the zone past it if it still collides. The expansion falls back only when it cannot fit the bar line (both screen edges).

- **ZONE-32** Multiple moments can run at once (drag gap, activity reveal, inline expansion, indicators reveal). Each moment is a `transient` entry with `{ zone, sourceKey, unfold }` and optional `side`. The solver processes them in list order (highest priority first).

- **ZONE-33** Moments keep a smaller gap than lasting fits (by default, `momentGap: 4` px, half the lasting gap). This reduces yields and keeps the bar tighter while hovering.

- **ZONE-34** Fallback reasons: **folded** (the widget is already folded and cannot grow), **screen** (the zone or its growth would run off-screen), **anchor** (the zone's anchor would have to yield, which is forbidden for unfolds). When a moment falls back, it is removed from the active set and `result.fallbacks` records the reason.

## Moments unfold on-demand widgets

- **ZONE-35** An inline expansion (unfold) brings folded widgets back temporarily. Given `transient: { zone: "left", unfold: "left" }`, the left zone's on-demand widgets that are folded return to draw; the on-demand run expands inline, and the zone's drawer handle disappears for the moment (no dots).

- **ZONE-36** For a center zone, an unfold is split by side: `unfold: "center", side: "start"` unfolds the before-anchor on-demand run; `side: "end"` unfolds the after-anchor run. Each side unfolds its own folded widgets and expands on its own; the other side's folds stay folded.

- **ZONE-37** An inline expansion uses the hidden widgets' measured cells (they stay loaded, opacity 0) to test if expansion fits before showing them. If it would fall back, the zone's drawer opens instead.

## Configuration and IPC

- **ZONE-38** Bar position (top, bottom, left, right) is stored in `bar.position` in shell.json and set with `omarchy bar position <edge>`. Dragging empty bar space (click-and-hold) to a screen edge moves the bar there and updates the config.

- **ZONE-39** Widget zones are stored in `bar.layout.<zone>` (left, center, right) as arrays of entry objects. Each entry has `id` (module id, required), `powerbarInstance` (unique key, assigned once), and `powerbarVisibility` (shown, managed, or hidden; no explicit choice defaults to shown for system widgets, managed for custom).

- **ZONE-40** Center anchor (the module pinned to the center) is stored in `bar.centerAnchor` (a module id string). Empty string or missing disables anchoring; the center becomes a simple zone. Changing the anchor does not rewrite the center's on-demand or folded state.

- **ZONE-41** Bar style is stored in `bar.powerbarStyle` (flat, floating, or islands). Flat bars hug screen edges with no gap or rounding. Floating bars hold all zones in one island off the edges (the original theme background shows). Islands wrap each visible zone in its own themed surface. Configs before style keys used `powerbarIslands: true` (reads as islands) or false/missing (reads as flat).

- **ZONE-42** Widget spacing (`bar.powerbarSpacing`, range 0–8) widens gutters and gaps. Default is 0. Set via Preferences → Bar → Size, or edit shell.json and restart the shell.

- **ZONE-43** Spacing mode (`bar.powerbarSpacingMode`, "slots" or "gaps") sets the layout mode for all items. No UI control; set in shell.json only. Default is slots (Equal slots).

- **ZONE-44** Large bar (`bar.powerbarLargeBar: true`) makes the bar thicker. Default is false. Set via Preferences → Bar → Size.

- **ZONE-45** On-demand display mode (`bar.powerbarOnDemand: "inline"` or omitted/falsy) switches between drawer-only (default) and inline expansion. Inline mode shows dots and allows hovering to expand; drawer-only uses only the drawer.

- **ZONE-46** Count badge on dots (`bar.powerbarDotsBadge`, true by default) shows the count of folded + on-demand widgets on the handle. The handle tooltip shows the count either way.

- **ZONE-47** `omarchy-shell powerbar managed <zone>` (zone: left, center, or right) opens that zone's on-demand drawer. With inline mode, opens the drawer if expansion would fall back.

- **ZONE-48** `omarchy-shell powerbar keysStatus` reports keyboard mode; `omarchy-shell powerbar drawerStatus` reports the open drawer or group menu; `omarchy-shell powerbar managedStatus` reports on-demand state (zone, revealed, on the bar).

## Orientation and vertical bars

- **ZONE-49** A vertical bar runs left or right of the workspace. `bar.position: "left"` or `"right"`. Zones align top-to-bottom (top zone, middle zone, bottom zone). Horizontal rules (zones, gaps, handles) apply vertically: top zone at the top, middle in the middle, bottom at the bottom.

- **ZONE-50** All widgets work in all four positions (top, bottom, left, right). Vertical bars are 28 px wide (standard) or 40 px wide (large). Text widgets on vertical bars fall back to icon-only (e.g., media hides its label). Glyphs are centred across the bar by their ink width.

- **ZONE-51** Popups from widgets in a vertical bar anchor on the side opposite the bar edge: left bar pops to the right, right bar to the left.

- **ZONE-52** Each position has its own bar size setting. `barSizeFor(vertical)` returns 26 (horizontal) or 28 (vertical), plus 12 px per side (`largeBarLip`) on the large bar. Orientation or bar size changes reset width hold.

## Visible extent and markers

- **ZONE-53** A folded zone shows its drawer handle (the dots icon with a count badge) as a placeholder at its end. When widgets yield to an inline expansion, they show a marker cell (the same dots icon with the yielded count) on the yielded side next to the zone's remaining widgets.

- **ZONE-54** The marker cell is reserved in the moment fit (input.marker or input.handle defines its size). Visible marks never appear between shown widgets; they sit at the end of the zone's visible run, on the side that yielded.

- **ZONE-55** An island's visible extent (its bounding box along the bar) includes the zone's widgets plus any yielded marker; it spans from the first widget's start (with padding) to the last widget's or marker's end (with padding). An empty zone has no island.

## Notifications and feedback

- **ZONE-56** When widgets fold due to bar shortage, Preferences' Layout page shows a notice: "<n> widgets don't fit on <screen>. They're in the <zones> drawer(s)." This reflects the current lasting fit across all monitors, updated live as the bar size or layout changes.

- **ZONE-57** The notice lists affected zones alphabetically (Left, Center, Right). If only one widget folds, it says "widget"; if more than one, "widgets". If only one zone is affected, it says "drawer"; if more than one, "drawers" and lists them joined by commas and "and".

- **ZONE-58** Offline (with no monitor or fit data), the notice shows nothing.

## Edge cases and limits

- **ZONE-59** A bar shorter than the inset gaps on both ends cannot fit any widgets; all fold. `result.fits: false`.

- **ZONE-60** A zone with only one widget (typically an anchor) always shows it even if `result.fits` is false. That widget and its zone remain on the bar.

- **ZONE-61** An empty center zone (all on-demand, all folded) still draws its handle if there are folded widgets or on-demand ones. If the center is only its handle, it acts as an anchor for layout purposes but shows no widget, only the dots or handle.

- **ZONE-62** The left zone's first widget (if it exists) and the right zone's last widget (if it exists) never fold. They anchor their zones visually.

- **ZONE-63** On-demand widgets never prevent lasting folding; folding happens first, then on-demand widgets wait behind the fold handle.

- **ZONE-64** Width hold (animations): when a widget's width shrinks and then grows again, it does not jump back if the hold (typically 8 s) has not elapsed. Losing at least one icon cell (snap point) shrinks at once without waiting.

## Open questions

- None identified; all behaviors traced to code.
