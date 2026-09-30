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
if (typeof module !== "undefined") module.exports = { slot: slot, endGap: endGap, afterPointer: afterPointer, afterCentre: afterCentre,
  settleTarget: settleTarget, settleFrame: settleFrame }
