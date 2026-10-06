# Drag-edit behavior

Drag and drop on the live bar, into drawers and onto zone dots. The bar controller captures a widget icon once, tracks the pointer, and resolves the drop destination. The dragged icon follows the pointer, drop targets open on hover, and a preview gap shows where the widget will land. On release the image glides to its target and commits with a config change. Cancelled drags glide back to the source.

## Sources

- `DragModel.js`: movement logic and decision functions
- `HighlightModel.js`: ink measurement of a widget's painted content (`inkRect`); its `pill()` has tests but no caller
- `DropOutline.qml`: drop target preview outline
- `HoverHighlight.qml`: hover and selection fill
- `CellModel.js`: gap and highlight geometry, `dragDuration`
- `ManagedDrawer.qml`: drawer rows as drag sources and drop surfaces
- `tests/drag-preview.test.cjs`: test cases for DragModel
- `tests/highlight.test.cjs`: test cases for HighlightModel
- `Bar.qml`: drag capture, movement, settlement, and configuration (Code: beginIconDrag, updateIconDrag, finishIconDrag, dragSettleDuration)

## Drag initiation

- **DRAG-1** Pressing a widget or group icon with the left button and moving the pointer so that |dx| + |dy| >= 4 px (`Style.space(4)`) starts a drag; the cursor becomes a closed hand. Releasing earlier is a click. Needs a writable shell config (`mutateShellConfig`); otherwise icons do not drag. Code: Bar.qml `modulePointer.onPositionChanged`, `beginIconDrag()`

- **DRAG-2** The dragged icon's image is grabbed from the widget when the drag starts. Until that image is ready no gap opens and the source slot stays where it is (`dragPreview.ready`). A drawer row that shows the widget with its name drags the widget alone; a row without one drags its whole cell.

- **DRAG-3** The image keeps the grab point: it sits under the pointer at the same offset the pointer had inside the icon when pressed.

- **DRAG-4** Starting a drag while an open drawer is in its own keyboard mode turns that drawer's keyboard cursor off; the drawer stays open. Nothing in `BarKeys.qml` reacts to a drag, so the bar's keyboard mode (keyboard.md) carries on. (unverified at runtime)

- **DRAG-5** Dragging a group icon whose own drawer is open closes that drawer at once. Dragging one of its members does not (DRAG-33).

## Drag movement and preview

- **DRAG-6** While the image is ready, the drop target under the pointer opens a gap along the bar's axis (width on a horizontal bar, height on a vertical one) before or after the target cell, and the dragged widget's slot hides. Nothing is reordered in the saved layout yet (DRAG-59).

- **DRAG-7** The gap is the dragged widget's own landing extent (`dragLandingExtent`: its cell plus a gutter in Equal slots, its glyph plus a gap in Equal gaps; see layout-zones.md). Without one it is max(bar size, image size / bar scale) + gutter.

- **DRAG-8** Neighbours make way over `150 * sqrt(gap / iconGap)` ms, clamped to 150..250 ms, with a sine in-out ease (see DRAG-67). With animations off (`powerbarAnimations: false`) slots move at once and there is no settle glide (DRAG-35).

- **DRAG-10** The side of the gap (before or after a cell) flips only when the probe point crosses that cell's centre by more than the 3 px dead zone (`Style.space(3)`): with no earlier decision after = probe > centre; once after, it stays after while probe >= centre - 3; once before, it flips to after only when probe > centre + 3. Code: DragModel.afterCentre()

- **DRAG-11** Drawers (zone and group), menus and empty zones use the same preview rules as the bar: before, after, into, or hidden, decided by `DragModel.slot()` and `endGap()`.

- **DRAG-12** The dragged widget's own slot hides. While the pointer is still over its original spot (`self`) the slot keeps its width/height so neighbours do not jump.

- **DRAG-13** A group icon makes way for a dragged icon like any other icon: a gap opens before or after it. No preview appears before the image is ready.

- **DRAG-14** A widget dragged from a drawer (a zone drawer or a group drawer) onto a group icon on the bar is dropped into that group: the icon shows the "into" state (no gap) and the widget becomes a member (it leaves any group it was in). A widget dragged from the bar onto a group icon gets a gap beside it instead (DRAG-31).

- **DRAG-15** A widget (not a group icon, not a drawer member) held over a group icon on the bar for 400 ms (`springOpen`) opens that group's drawer without entering it. The drawer stays while the pointer is on the icon, on the drawer, or on the path between them (reach = drawer gap + bar extent + `Style.space(8)`, side margin `Style.space(12)`); once the pointer is on none of them it closes after 450 ms (`springClose`).

- **DRAG-16** A widget (not a drawer member) held over a zone's dots (`handle`) for 400 ms (`springHandle`) opens the zone: inline expansion when `powerbarOnDemand` is `inline` (its drawer if the zone cannot expand), else the zone's drawer, not entered. A spring-opened drawer closes 450 ms after the pointer leaves it as in DRAG-15.

- **DRAG-17** Where the widget will land, a 1 px outline of its cell (colour: the bar foreground at 45 % alpha, corner radius = the highlight radius) is drawn inside the open gap, on whole pixels, one pixel inside the gap's edges. It shows in every drop surface: bar zones, drawer strips, menu rows. It is visible only while the gap is longer than 1 px. Code: DropOutline.qml

- **DRAG-18** When the drop lands On demand (on the dots, inside an inline run, in a zone drawer) the outline holds a dots glyph (`󰇘` on a horizontal bar, `󰇙` on a vertical one, 45 % alpha) instead of being empty.

- **DRAG-19** The outline fades in with the gap: opacity = min(1, gapLength / full gap).

- **DRAG-20** Hover and selection draw a soft rounded fill behind an item (`HoverHighlight`); its opacity animates over 90 ms (OutCubic). Colours and shape: see appearance.md.

- **DRAG-21** Where two lit highlights overlap (Equal gaps) the older fades to 45 % opacity and the newer draws on top.

## Drop resolution

- **DRAG-22** The drop target is found from the dragged widget's painted centre along the bar's axis (the pointer position corrected by the widget's measured ink), falling back to the pointer itself; the first visible slot under either point wins, else the nearest slot of the zone under the pointer, else the zone's end. Widgets yielded to an expansion or in a hidden zone take no drops.

- **DRAG-23** A release up to 0.6 x bar size beyond the bar's inner edge (away from the screen edge) still lands on the bar, unless it is over an open drawer.

- **DRAG-24** Dropping on an open zone drawer (on a row, or on its empty area) saves the widget with `powerbarVisibility: "managed"` in that drawer's zone (appended to the zone's end when dropped on empty drawer area). Dropping on a group drawer makes it a member of that group (membership only).

- **DRAG-25** Dropping on the bar saves the widget with `powerbarVisibility: "shown"`, written explicitly even though shown is the default for a widget with no saved value, and places it before or after the slot under it. A group icon dragged to the bar keeps its group's visibility the same way. Code: Bar.qml `dropAt()`, `BarModel.moveInstanceInConfig()`

- **DRAG-26** Dropping on a zone where nothing is under the pointer lands next to the nearest widget of that zone (`BarModel.nearestDropTarget`), or at the end of the zone, saved `"shown"`, when it has none.

- **DRAG-27** After a drop into a group's drawer or a zone's drawer the drawer stays open (it counts as entered) and closes after the exit grace once the pointer leaves (on-demand-drawers.md).

- **DRAG-28** Dropping on a zone's dots saves `"managed"`: with the dots at the zone's start the widget goes before the zone's first other entry; with dots at the end, to the end of the zone's list. Each side of the centre zone's two dots takes its own.

- **DRAG-29** Resting on the dots for 400 ms opens the zone (DRAG-16).

- **DRAG-30** Dropping inside an inline expansion's run saves `"managed"`; dropping where the shown widgets meet the expansion saves `"shown"` (the gap joins the run of the widget under the pointer). Code: ZoneOrderModel.landsOnDemand()

- **DRAG-31** Dropping on a widget row beside a group icon on the bar places the widget next to the group, not in it: it takes the group's place and the group re-anchors in front of it.

- **DRAG-32** Releasing outside the bar and drawers, or back over the icon's own spot, changes nothing in the config; the image glides back to the source slot (DRAG-42).

- **DRAG-33** A drag that starts on a drawer row leaves the drawer open throughout (drawers hold while `dragMotionActive`) and, after a drop into a drawer, as in DRAG-27.

- **DRAG-34** The widget's tooltip hides when a drag begins.

## Drag settlement and animation

- **DRAG-35** On release the image stays visible and glides to its target over 180 ms (`dragSettleDuration`, OutCubic), following the target slot frame by frame if it is still moving. With animations off there is no glide.

- **DRAG-36** Drops with an open gap to aim at (a bar gap beside a slot that is not the clock, a group icon, a drawer gap) glide into the open gap with the gap still drawn, then commit; the commit rebuilds every slot in one frame, swapping gap and slot.

- **DRAG-37** Drops with no gap to aim at (a zone's end, the dots, beside the clock/centre anchor) commit first, then the image glides from the release point to the widget's new slot.

- **DRAG-38** A widget whose new home is not visible glides into its group icon and fades there when it joined a group, or fades where released when it has no visible home.

- **DRAG-39** Settle frames interpolate from the release point to the target (`DragModel.settleFrame`): opacity 1 and scale 1; when fading, opacity = 1 - p and scale = 1 - 0.4 p.

- **DRAG-40** After the 180 ms glide, a fading image disappears and the drag state clears; a glide that committed first also ends there.

- **DRAG-41** After a glide-then-commit drop, if the committed slot is 2 px or more from where the image landed, a 90 ms correction glide (`dragSettleCorrectionDuration`) follows, the image staying frozen where it landed in between; less than 2 px ends at once.

- **DRAG-42** A cancelled drag (DRAG-32) glides back to the source over the same 180 ms as the source regains its space. There is no Escape binding for a drag.

## Preview gap mechanics

- **DRAG-43** A slot's state comes from `DragModel.slot(state, key, surface)`: hidden if it is the source on the source surface; before or after if it is the target (not hidden); `holdSpace` for the source while `self`; `into` for a group icon that takes the drop. Nothing shows while `ready` is false.

- **DRAG-44** An end gap (no target key) opens at the end of the zone or drawer whose surface is the target, when ready. Code: DragModel.endGap()

- **DRAG-45** The gap sits inside the outline's boundary by 1 px: the outline starts at gapStart + min(landingOffset, max(0, gapLength - cellAlong - 1)) when a landing offset is given (named menus), else centred in the gap.

## Drag constraints and special cases

- **DRAG-47** Groups do not nest: a group icon has no drop surface in a group drawer.

- **DRAG-48** A group icon dropped beside another group icon reorders the groups; dropped on a zone drawer or the dots it becomes On demand (the group's visibility `"managed"`); dropped on the bar `"shown"`.

- **DRAG-49** A widget dragged from a drawer never spring-opens another group's drawer; the group icon is a drop-into target for it (DRAG-14).

- **DRAG-50** See DRAG-5.

- **DRAG-51** Drawer lifetime after a drop: on-demand-drawers.md (entry grace default 1 s, exit grace default 1 s, each 1..15 s; `ManagedModel.dismissDelay()`).

- **DRAG-52** The ghost takes the style of the group drawer under it: native icon, name, or both (the group's `memberDisplay`).

- **DRAG-54** A released icon settles on its own drawer cell if shown, else its own bar slot if shown, else the group icon that now contains it (fading), else fades where released. Code: DragModel.settleTarget()

- **DRAG-55** Every drop writes the visibility it implies: bar and "shown" spots `"shown"`, drawer, dots and on-demand run spots `"managed"`, group drawers membership only. A drop never writes `"hidden"`.

- **DRAG-57** The clock (centre anchor) stays centred: a gap beside it opens in the neighbouring list, not in its own slot, and a drop beside it commits first (DRAG-37).

- **DRAG-58** The bar applies the edit to its own copy of the config at once and writes shell.json once, after the drag, glide and settle have finished (`configWriteSettled`); a bar move (DRAG-74) also holds writes.

- **DRAG-59** shell.json is unchanged while the pointer is down; the cue is the gap and the moving image only.

- **DRAG-60** The drag image is drawn by an overlay-layer surface (`omarchy-bar-drag-ghost`, all edges) with an empty input region, so it sits under the pointer without taking the mouse grab.

- **DRAG-61** The image is the widget's own look. Over a group drawer whose members show their names (`memberDisplay` name or both) it is drawn as a labelled row (name, or icon plus name) in the menu's shape.

- **DRAG-62** A drawer row that has a label and a native widget drags (and lands as) the native image only; the label is added by the target's style.

## Highlight geometry

- **DRAG-63** A hover fill or the drop outline's cell is `thickness` across the bar, thickness = bar size - 2 x inset with inset = min(3, (bar size - 16) / 2) px; its length along the bar is the widget's cell (CellModel.cellLength): square for an icon, ink + 2 x air for text. See layout-zones.md.

- **DRAG-65** The highlight's corner radius is min(thickness / 2, island rounding - inset) (`CellModel.radius`, floor 0).

## Configuration

- **DRAG-67** Drag motion: `CellModel.dragDuration(gap, icon)` = round(clamp(150 x sqrt(gap / icon), 150, 250)) ms.

- **DRAG-68** Settle glide 180 ms; correction glide 90 ms.

- **DRAG-69** Dead zone for gap side changes: 3 px.

- **DRAG-70** Spring open (group drawer, zone dots): 400 ms. Spring close grace: 450 ms (DRAG-71).

- **DRAG-72** Group spring path: see DRAG-15.

- **DRAG-73** Drag is pointer only; there are no keyboard bindings for it (the keyboard mode's keys are in keyboard.md).

- **DRAG-74** Pressing and holding the clock's (centre anchor) empty area for 200 ms, or pressing it and moving 4 px, lifts the bar: an indicator shows on each screen edge, the one nearest the pointer (by the screen's diagonals) lights, and releasing writes `bar.position` to that edge (nothing if it is the current edge). Code: Bar.qml `CenterGestureArea`, `nearestScreenEdge()`; position: layout-zones.md ZONE-38.

## Doc drift

None found: CONTEXT.md (lines 73, 111) says main-bar drops set Always shown and drawer drops set Managed, as the code does.

## Open questions

- `HighlightModel.pill()` (and DRAG-63..66's old wording) is not called anywhere; the bar's highlight comes from CellModel. Remove it or keep it as test-only?
- DRAG-4: should a bar drag end the bar's keyboard mode? Today it does not.
