# Drag-edit behavior

Drag and drop on the live bar, into drawers and onto zone dots. The bar controller captures a widget icon once, tracks the pointer, and resolves the drop destination. The dragged icon follows the pointer, drop targets open on hover, and a preview gap shows where the widget will land. On release the image glides to its target and commits with a config change. Cancelled drags glide back to the source.

## Sources

- `DragModel.js`: movement logic and decision functions
- `HighlightModel.js`: highlight geometry
- `DropOutline.qml`: drop target preview outline
- `HoverHighlight.qml`: hover and selection highlighting
- `tests/drag-preview.test.cjs`: test cases for DragModel
- `tests/highlight.test.cjs`: test cases for HighlightModel
- `Bar.qml`: drag capture, movement, settlement, and configuration (Code: beginIconDrag, updateIconDrag, finishIconDrag, dragSettleDuration)

## Drag initiation

- **DRAG-1** A drag begins when pointer movement exceeds dragThreshold (Style.space(4)) before release; the gesture is captured at that point.

- **DRAG-2** The bar controller captures the dragged widget's visual presentation (icon image) from the source widget and keeps the source slot visible until the image is ready.

- **DRAG-3** The original grab point on the source icon is preserved: the image follows the pointer with the same offset from source grab to image centre that the pointer had from drag initiation.

- **DRAG-4** If keyboard mode is active (Super+B entered) when drag begins, keyboard mode ends: the cursor and keyboard focus are released.

- **DRAG-5** If a group's drawer is open and the drag starts on a group member or starts while hovering the group, the group's drawer closes.

## Drag movement and preview

- **DRAG-6** As the pointer moves during drag, a preview gap opens at the target location showing where the widget will land; the gap closes around the widget's slot and animates along the bar's axis (width on horizontal bars, height on vertical bars).

- **DRAG-7** The preview gap size is the source widget's landing extent (length along the bar); if no landing extent is recorded, the gap width is max(bar size, image width / bar scale) + gutter for horizontal bars, and max(bar size, image height / bar scale) + gutter for vertical bars.

- **DRAG-8** The gap animates to its new size with sine ease (Easing.InOutSine); duration ranges from 150 ms to 260 ms depending on gap size and icon width.

- **DRAG-9** The preview gap fades in as it opens, proportional to its opening: opacity starts at gapLength / fullGap and rises to 1 when fully open.

- **DRAG-10** When a preview gap appears before or after a cell, the decision holds within a 3 px dead zone; the gap does not flip sides until the pointer's centre crosses the target cell's centre by more than the dead zone (3 px).

- **DRAG-11** The same preview policy applies to dragging in drawers and empty islands as on the bar: before/after/into/hidden are determined identically.

- **DRAG-12** The dragged icon leaves its source slot and the slot appears hidden; if the source remains under the pointer (holdSpace=true), the slot retains its width/height to avoid neighbors jumping.

- **DRAG-13** A group icon makes way for a dragged icon like any other widget; no preview appears before the drag gesture is captured (ready=false).

- **DRAG-14** A group icon can be a drop target for a widget dragged out of its drawer; when into=true, the slot shows the "into" state (not before/after).

- **DRAG-15** When dragging over a group icon on the main bar, after 400 ms (springOpen timer) the group's drawer opens if the pointer continues resting on the icon or is on the group icon, its drawer, or within a spring path zone; leaving both the icon and the spring path starts a 450 ms close grace (springClose timer).

- **DRAG-16** When dragging over a zone's fold handle (dots/end fold marker) on the main bar, after 400 ms (springHandle timer) the zone opens: inline expansion if onDemandInline is true, or its drawer, and the spring-opened drawer closes on exit after the spring grace.

- **DRAG-17** The drop outline (`DropOutline.qml`) is drawn at each drop surface (zones, drawers, menus) and shows a cell outline inside the open gap; the outline is kept one pixel inside the gap boundary and positioned on whole pixels.

- **DRAG-18** For on-demand (managed) zones, the drop outline shows dots (󰇙 or 󰇘 characters depending on orientation) instead of a full cell outline, indicating the widget will be placed on demand.

- **DRAG-19** The drop outline's opacity fades with the gap: opacity = min(1, gapLength / max(1, fullGap)).

- **DRAG-20** Hover highlighting (`HoverHighlight.qml`) shows a soft rounded fill behind hovered items; opacity animates with 90 ms ease-out (Easing.OutCubic) when hover state changes.

- **DRAG-21** Where two lit highlights overlap (equal gaps), the older one fades to 0.45 opacity so the eye follows the newer action; the newer one draws on top (z=1).

## Drop resolution

- **DRAG-22** The drop target is resolved per pointer position: (1) dragged widget's painted centre if source has ink measured along the bar's axis, else (2) pointer position itself; then hit-test against all visible candidate slots.

- **DRAG-23** A release that drifts up to 60% of bar size (0.6 * barSize) off the bar's inner edge still lands on the bar, unless an open drawer is closer.

- **DRAG-24** Dragging into an open managed drawer (zone or group) sets the widget to Managed visibility and places it in that drawer's zone or group.

- **DRAG-25** Dragging onto the main bar (outside all drawers) sets the widget to Always shown and places it in the targeted zone.

- **DRAG-26** Dragging onto an empty zone (no visible widgets) creates a gap at the zone's end; dropping there sets the widget Always shown in that zone.

- **DRAG-27** Dragging into a group's drawer causes the widget to join (or move within) that group; the drawer remains open after the drop and closes after exit grace.

- **DRAG-28** Dragging onto a zone's fold handle (dots) places the widget in that zone's managed widgets; the widget is positioned at the end of the on-demand run on that side of the centre (for the centre zone's two dot pairs, each side expands on its own).

- **DRAG-29** Dragging onto the zone's dots and resting 400 ms opens that zone (inline or drawer, by on-demand display mode).

- **DRAG-30** Dragging inside an inline expansion's run places the widget as Managed; where shown widgets meet the expansion it lands Always shown (at the visible/managed boundary).

- **DRAG-31** Dragging a widget beside a group icon places it next to the group on the main bar (not inside the group).

- **DRAG-32** Dragging outside valid surfaces (bar, drawers, dots) cancels the drag without a config change and glides the image back to the source.

- **DRAG-33** When a drag starts in a drawer or group drawer, the drawer stays open (managed owner enters=true) and remains open after the drop, closing only after the exit grace when the pointer leaves.

- **DRAG-34** Tooltip is hidden when drag begins (hideTooltip called on source's activeItem).

## Drag settlement and animation

- **DRAG-35** On release, the captured image stays visible and glides to its target over 180 ms (dragSettleDuration); the glide follows the dragged widget's slot if the slot is moving.

- **DRAG-36** For main-bar gaps and group icon targets, the image glides into the open preview gap first with the gap still drawn, then commits; commit rebuilds every slot synchronously.

- **DRAG-37** For managed-drawer drops and zone dots, the commit happens first, then the image glides from release point to the widget's new slot, following it frame by frame.

- **DRAG-38** A widget whose new home is not visible (in a hidden zone or inside a group) glides into and fades over its group icon (if in a group), or fades in place (if no visible home).

- **DRAG-39** The image settlement animation uses DragModel.settleFrame: it interpolates position from release point (barDragSettleFromX/Y) to target with opacity 1 and scale 1; when fading, opacity = 1 - progress and scale = 1 - 0.4 * progress.

- **DRAG-40** After the settle animation ends (180 ms), if the image is fading (no visible home), it disappears and drag is cleared; otherwise a correction glide begins.

- **DRAG-41** If correction is needed (the image has already landed but not at the committed slot), a second 90 ms glide (dragSettleCorrectionDuration) covers the offset; this keeps the image frozen where it landed between settlement and correction.

- **DRAG-42** A cancelled drag (pointer released outside valid surfaces or escape) glides back to the source and animates with the same 180 ms ease, fading out as the source regains its space.

## Preview gap mechanics

- **DRAG-43** The preview gap's position is determined by DragModel.slot: given a drag state (sourceKey, sourceSurface, targetKey, targetSurface, after) and a slot (key, surface), the slot is hidden if it is the source, shows before/after the target, holds space if source, or shows into state for groups.

- **DRAG-44** An end gap (no targetKey, matching surface) is drawn at a zone's or drawer's end when the preview is ready; determined by DragModel.endGap.

- **DRAG-45** The preview gap is kept one pixel inside the drop outline's boundary; on horizontal bars it is gapStart + min(landingOffset, max(0, gapLength - along - 1)) for offset >= 0, else centered; on vertical bars the same logic applies vertically.

- **DRAG-46** All drag gap and inset transitions (slot width/height changes and inset animations) share sine ease (Easing.InOutSine, dragMotionEasing) with duration calculated per DRAG-67 (150–260 ms).

## Drag constraints and special cases

- **DRAG-47** Groups do not nest: a group icon has no drop surface inside any group drawer.

- **DRAG-48** A group icon beside another group icon reorders the groups; dropping it into a managed drawer makes the whole group Managed.

- **DRAG-49** A widget dragged out of a drawer cannot open another group's drawer; for it, a group icon is a container it drops into (after 400 ms spring wait).

- **DRAG-50** A group's own drawer (owned by the icon being moved) closes immediately when drag starts on a member of that group.

- **DRAG-51** A drawer held open by keepDrawerThroughEdit=true stays open after the drop and closes after dismissDelay: entryGrace seconds (default 1 s, max 15 s) if not yet entered, or exitGrace seconds (default 1 s, max 15 s) if entered. Code: ManagedModel.dismissDelay()

- **DRAG-52** The dragged widget's presentation (how it displays: native icon, name, or both) follows the target group's member display style while dragging over that group's drawer; the ghost shows the appropriate form.

- **DRAG-53** Dragging a member from one group drawer onto another group icon transfers membership; the member takes the target group's display style.

- **DRAG-54** A released icon settles by preferring its own drawer cell if it exists and is shown (not hidden), else its own main-bar slot if shown, else the group icon now containing it (with fade), else fades where it was released.

- **DRAG-55** The source slot's visibility mode (Always shown, Managed, Hidden) is preserved unless the drop explicitly changes it (on main bar → Always shown, in drawer → Managed, in group → membership only).

- **DRAG-56** When a widget is moved from an inline expansion to another location, the expansion's run updates and the zone may collapse if no longer needed.

- **DRAG-57** The center anchor opens its gap in the neighboring list so the anchored icon stays centered during layout changes from drag commits.

- **DRAG-58** Drag layout changes are queued and applied once drag, glide, and settlement are complete (configWriteSettled = !barDragSource && !barDragSettling).

- **DRAG-59** No widget model is reordered during the drag gesture; the moving icon and opening space provide the reorder cue visually; reordering happens on commit.

- **DRAG-60** The drag ghost panel (DragGhostPanel) is an overlay on the screen over all other content (WlrLayer.Overlay) and sits under the cursor without stealing the mouse grab; its input region is empty (mask: Region {}).

- **DRAG-61** The drag ghost shows a labelled row when the target is a group drawer with member display "name" or "both"; otherwise it shows the native icon image.

- **DRAG-62** If dragging from a labeled menu row (row.labelled && row.showNative), the landing shows the native image, not the label.

## Highlight geometry

- **DRAG-63** A hover highlight (pill) has thickness equal to the bar size minus a small inset (theme-defined); its length follows the widget's visible painted content (icon or text), never shorter than it is thick.

- **DRAG-64** Icon-only widgets get a square highlight (length = thickness); text and multi-element widgets get a pill (length = ink + 2*pad).

- **DRAG-65** The highlight's corner radius is the minimum of (1) requested rounding (theme), (2) half the thickness, and (3) the island's rounding, nested inside the island.

- **DRAG-66** The highlight stays inside its lane (island or bar edge inset) by shifting first, then shrinking if needed.

## Configuration and IPC

- **DRAG-67** Drag motion duration (gap and inset transitions) is calculated by CellModel.dragDuration: 150 * sqrt(gap/icon), clamped to 150–260 ms range. Code: CellModel.dragDuration(gap, icon)

- **DRAG-68** Drag settle duration (image glide to target) is 180 ms (dragSettleDuration); correction glide is 90 ms (dragSettleCorrectionDuration).

- **DRAG-69** Dead zone for gap side changes is 3 px (dragDeadZone = Style.space(3)).

- **DRAG-70** Spring open timer (group drawer and zone reveal on drag rest) is 400 ms (springOpen.interval).

- **DRAG-71** Spring close grace timer (drawer dismiss after leaving) is 450 ms (springClose.interval).

- **DRAG-72** Group spring path extends beyond the drawer: reach = drawer.gap + barExtent + Style.space(8), margin = Style.space(12). Code: Bar.qml onSpringPath()

- **DRAG-73** The drag gesture is not user-configurable; key bindings for drag interaction (if any) are not implemented; drag is always pointer-driven.

## Doc drift

None. CONTEXT.md describes the architecture accurately with correct timing values (180 ms settle, 90 ms correction, 150–260 ms ease range, 400 ms spring, 3 px dead zone). README.md describes Preferences Layout drag as a separate concern.

## Open questions

None at this time. All behaviors are derived from code and tests without ambiguity.
