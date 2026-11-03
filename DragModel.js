// Shared preview decisions for bar zones and extended islands.
// A slot's part in the drag is one of a few shared objects, so a drag step
// that leaves a slot's part as it was hands its bindings the same object
// and they stay put; only the slots whose part changed re-run.
var ROLES = {
  none: Object.freeze({ hidden: false, holdSpace: false, before: false, after: false, into: false }),
  source: Object.freeze({ hidden: true, holdSpace: false, before: false, after: false, into: false }),
  sourceHolding: Object.freeze({ hidden: true, holdSpace: true, before: false, after: false, into: false }),
  into: Object.freeze({ hidden: false, holdSpace: false, before: false, after: false, into: true }),
  before: Object.freeze({ hidden: false, holdSpace: false, before: true, after: false, into: false }),
  after: Object.freeze({ hidden: false, holdSpace: false, before: false, after: true, into: false })
}
function slot(state, key, surface) {
  if (!state || !state.ready) return ROLES.none
  if (state.sourceKey === key && state.sourceSurface === surface) return state.self === true ? ROLES.sourceHolding : ROLES.source
  if (state.targetKey !== key || state.targetSurface !== surface) return ROLES.none
  // Group icons make way like any other icon; dropping into a group happens
  // in its drawer, which opens while a drag rests on the icon. A widget
  // dragged out of a drawer cannot open another one, so for it a group icon
  // is a container it drops into.
  if (state.into) return ROLES.into
  return state.after ? ROLES.after : ROLES.before
}
function endGap(state, surface) {
  return !!state && state.ready === true && !state.targetKey && state.targetSurface === surface
}
// Where the image hangs from the pointer, along one axis: the pressed spot
// when it is on the image, else the image's middle. A menu row is pressed
// anywhere on its icon or name but carries only its icon, so a press on the
// name carries the icon centred under the pointer, not beside it (DRAG-3).
function grabOffset(offset, size) {
  return offset >= 0 && offset <= size ? offset : size / 2
}

function afterPointer(pointer, origin, contentOffset, contentExtent) {
  return pointer > origin + contentOffset + contentExtent / 2
}
// Whether a drag lands after a cell whose centre is `centre`. The previous
// decision holds until the probe crosses the centre by more than `deadZone`,
// so the landing spot cannot flicker at the boundary.
function afterCentre(probe, centre, previous, deadZone) {
  var dz = Math.max(0, deadZone || 0)
  if (previous === true) return probe >= centre - dz
  if (previous === false) return probe > centre + dz
  return probe > centre
}
// Where a drag over a bar cell flips from a gap before the cell to one after
// it: halfway between the places those two gaps take once the cell's list has
// made room for one, so the gap opens under the dragged widget (DRAG-10). A
// list hanging from its start makes room past the gap, one hanging from its
// end before it, the centre box on both sides; the side of a cell alone would
// put the gap a whole cell off in half of it. The live layout holds the room
// open now (a gap, the dragged widget's own place), so the cell's place
// without it comes first; within one list that room only moves, which makes
// the rule a swap with the cell the widget enters.
//   centre: the cell's centre now      ahead: room open ahead of it
//   room: all the room open in its list
//   startGrowth: the share of a new gap the list makes on its start side
//   gap: the gap's length
function landingPivot(centre, ahead, room, startGrowth, gap) {
  return centre - ahead + startGrowth * room + (0.5 - startGrowth) * gap
}
// Where a released icon settles once the layout has committed: its own drawer
// cell, else its own main-bar slot, else the group icon now containing it.
// Without a visible home it fades where it was released.
function settleTarget(slots, key, groupKey) {
  var i
  for (i = 0; i < slots.length; i++) if (slots[i].key === key && slots[i].drawer) return { index: i, fade: false }
  for (i = 0; i < slots.length; i++) if (slots[i].key === key && slots[i].shown) return { index: i, fade: false }
  if (groupKey)
    for (i = 0; i < slots.length; i++) if (slots[i].key === groupKey && slots[i].shown) return { index: i, fade: true }
  return { index: -1, fade: true }
}
function settleFrame(from, to, progress, fade) {
  var p = Math.max(0, Math.min(1, progress || 0))
  var end = to || from
  var vanish = fade || !to
  return { x: from.x + (end.x - from.x) * p, y: from.y + (end.y - from.y) * p,
    opacity: vanish ? 1 - p : 1, scale: vanish ? 1 - 0.4 * p : 1 }
}
// Resolve a pointer anywhere along the bar to the closest insertion edge.
// Requiring the pointer to sit inside another widget makes the empty space
// around a centered group a dead zone, even though it visually reads as the
// most natural place to drop.
function nearestDropTarget(candidates, point, vertical) {
  var rows = Array.isArray(candidates) ? candidates : []
  var axis = vertical ? Number(point && point.y) : Number(point && point.x)
  if (!isFinite(axis)) return null

  var best = null
  var bestDistance = Infinity
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row || !row.slot) continue

    var start = Number(vertical ? row.y : row.x)
    var size = Number(vertical ? row.height : row.width)
    if (!isFinite(start) || !isFinite(size) || size <= 0) continue

    var beforeDistance = Math.abs(axis - start)
    var afterDistance = Math.abs(axis - (start + size))
    var after = afterDistance < beforeDistance
    var distance = after ? afterDistance : beforeDistance
    if (distance < bestDistance) {
      best = { slot: row.slot, after: after }
      bestDistance = distance
    }
  }
  return best
}

// Where on its window the pointer is, for a drop: on the bar's strip (with a
// little slack off its inner edge, so a release that drifts lands on the bar),
// in the open drawer, or neither (null). p: the pointer in the window's
// content item; size of that item; window size; position, barExtent, barSize;
// drawer { open, x, y, width, height } or null; nested: a group icon over a
// group's drawer (groups don't nest, so that drawer is no drop surface).
function dropSurface(p, size, window, position, barExtent, barSize, drawer, nested) {
  if (p.x < 0 || p.x > size.width || p.y < 0 || p.y > size.height) return null
  var inDrawer = !!drawer && drawer.open && !nested
    && p.x >= drawer.x && p.x <= drawer.x + drawer.width && p.y >= drawer.y && p.y <= drawer.y + drawer.height
  var band = stripBand(window, position, barExtent, inDrawer ? 0 : barSize * 0.6)
  var vertical = position === "left" || position === "right"
  var cross = vertical ? p.x : p.y
  var start = vertical ? band.x : band.y
  var inStrip = cross >= start && cross <= start + (vertical ? band.width : band.height)
  if (!inStrip && !inDrawer) return null
  return { inStrip: inStrip, inDrawer: inDrawer }
}

// The bar's strip with `slack` px more off its inner edge, in window
// coordinates: where a release lands on the bar. While a drag lasts the
// window takes the pointer there too, so a release in the slack is the
// bar's and not another surface's (DRAG-23, DRAG-77).
function stripBand(window, position, barExtent, slack) {
  var depth = barExtent + slack
  if (position === "left") return { x: 0, y: 0, width: depth, height: window.height }
  if (position === "right") return { x: window.width - depth, y: 0, width: depth, height: window.height }
  if (position === "bottom") return { x: 0, y: window.height - depth, width: window.width, height: depth }
  return { x: 0, y: 0, width: window.width, height: depth }
}

// What a drag over the bar or a drawer drops on, from measured candidates
// (rects in scene pixels, each with an opaque `slot`, its `region`, whether it
// is a `groupHeader`, whether it sits in a drawer, `inDrawer`, and the `pivot`
// along the axis where its side flips, landingPivot). In order: the candidate
// under the dragged widget's painted centre (probe), else under the pointer;
// over its own place with nothing under it, nothing changes ({ source }); the
// dots ({ handle }, filled in by the caller); a widget from a drawer onto a bar
// group icon goes into the group; beside a candidate, on the side of its pivot
// with a dead zone around it so the gap does not flicker (previous:
// { slot, after } of the drop shown); off the candidates (the strip's slack
// across the bar) beside the one of the zone (or of the drawer) level with the
// probe along the axis, the same way; else the nearest candidate of the zone,
// else the zone or drawer itself.
function resolveDrop(d) {
  var within = function(p, c) { return p.x >= c.x && p.x <= c.x + c.width && p.y >= c.y && p.y <= c.y + c.height }
  var axis = d.alongColumn ? d.probe.y : d.probe.x
  var beside = function(c) {
    var previous = d.previous && d.previous.slot === c.slot ? d.previous.after : undefined
    return { slot: c.slot, after: afterCentre(axis, c.pivot, previous, d.deadZone) }
  }
  var hit = d.candidates.find(function(c) { return within(d.probe, c) }) || d.candidates.find(function(c) { return within(d.point, c) })
  if (!hit && d.sourceRect && within(d.point, d.sourceRect)) return { source: true }
  if (d.handle) return { handle: true }
  if (hit && hit.groupHeader && !hit.inDrawer && d.sourceInDrawer && !d.sourceGroupHeader) return { slot: hit.slot, into: true }
  if (hit) return beside(hit)
  var nearby = d.inDrawer ? d.candidates : d.candidates.filter(function(c) { return c.region === d.zone })
  var level = nearby.find(function(c) { return d.alongColumn ? axis >= c.y && axis <= c.y + c.height : axis >= c.x && axis <= c.x + c.width })
  if (level) return beside(level)
  return nearestDropTarget(nearby, d.probe, d.alongColumn) || (d.inDrawer ? { drawer: true } : { zone: d.zone })
}
