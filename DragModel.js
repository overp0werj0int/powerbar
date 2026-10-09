// Shared preview decisions for bar zones and extended islands.
function slot(state, key, surface) {
  var result = { hidden: false, holdSpace: false, before: false, after: false, into: false }
  if (!state || !state.ready) return result
  result.hidden = state.sourceKey === key && state.sourceSurface === surface
  result.holdSpace = result.hidden && state.self === true
  if (state.targetKey !== key || state.targetSurface !== surface || result.hidden) return result
  // Group icons make way like any other icon; dropping into a group happens
  // in its drawer, which opens while a drag rests on the icon. A widget
  // dragged out of a drawer cannot open another one, so for it a group icon
  // is a container it drops into.
  if (state.into) { result.into = true; return result }
  result.before = !state.after
  result.after = !!state.after
  return result
}
function endGap(state, surface) {
  return !!state && state.ready === true && !state.targetKey && state.targetSurface === surface
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
  var vertical = position === "left" || position === "right"
  var stripX = position === "right" ? window.width - barExtent : 0
  var stripY = position === "bottom" ? window.height - barExtent : 0
  var inDrawer = !!drawer && drawer.open && !nested
    && p.x >= drawer.x && p.x <= drawer.x + drawer.width && p.y >= drawer.y && p.y <= drawer.y + drawer.height
  var slack = inDrawer ? 0 : barSize * 0.6
  var cross = vertical ? p.x : p.y
  var stripStart = vertical ? stripX : stripY
  var inStrip = position === "top" || position === "left"
    ? cross >= stripStart && cross <= stripStart + barExtent + slack
    : cross >= stripStart - slack && cross <= stripStart + barExtent
  if (!inStrip && !inDrawer) return null
  return { inStrip: inStrip, inDrawer: inDrawer }
}

// What a drag over the bar or a drawer drops on, from measured candidates
// (rects in scene pixels, each with an opaque `slot`, its `region`, whether it
// is a `groupHeader` and whether it sits in a drawer, `inDrawer`). In order:
// the candidate under the dragged widget's painted centre (probe), else under
// the pointer; over its own place with nothing under it, nothing changes
// ({ source }); the dots ({ handle }, filled in by the caller); a widget from a
// drawer onto a bar group icon goes into the group; beside a candidate, on the
// side of its cell's centre with a dead zone around it so the gap does not
// flicker (previous: { slot, after } of the drop shown); else the nearest
// candidate of the zone (or of the drawer), else the zone or drawer itself.
function resolveDrop(d) {
  var within = function(p, c) { return p.x >= c.x && p.x <= c.x + c.width && p.y >= c.y && p.y <= c.y + c.height }
  var hit = d.candidates.find(function(c) { return within(d.probe, c) }) || d.candidates.find(function(c) { return within(d.point, c) })
  if (!hit && d.sourceRect && within(d.point, d.sourceRect)) return { source: true }
  if (d.handle) return { handle: true }
  if (hit && hit.groupHeader && !hit.inDrawer && d.sourceInDrawer && !d.sourceGroupHeader) return { slot: hit.slot, into: true }
  if (hit) {
    var previous = d.previous && d.previous.slot === hit.slot ? d.previous.after : undefined
    return { slot: hit.slot, after: d.alongColumn
      ? afterCentre(d.probe.y, hit.y + hit.contentY + hit.contentHeight / 2, previous, d.deadZone)
      : afterCentre(d.probe.x, hit.x + hit.contentX + hit.contentWidth / 2, previous, d.deadZone) }
  }
  var nearby = d.inDrawer ? d.candidates : d.candidates.filter(function(c) { return c.region === d.zone })
  return nearestDropTarget(nearby, d.probe, d.alongColumn) || (d.inDrawer ? { drawer: true } : { zone: d.zone })
}
if (typeof module !== "undefined") module.exports = { slot: slot, endGap: endGap, afterPointer: afterPointer, afterCentre: afterCentre,
  settleTarget: settleTarget, settleFrame: settleFrame, nearestDropTarget: nearestDropTarget, dropSurface: dropSurface, resolveDrop: resolveDrop }
