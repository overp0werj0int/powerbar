// Where the bar's tooltip goes: away from the bar, beside its target, and
// never over an open drawer or menu. Pure; Bar.qml reads the rectangles.
//
// Rectangles are { x, y, width, height } in the bar window's coordinates.
//   position: the bar's edge ("top", "bottom", "left", "right")
//   target:   the hovered item
//   popup:    { width, height } of the tooltip
//   gap:      space between the tooltip and what it sits beside
//   drawer:   the open drawer (or null), with vertical: its items run down
//             the screen (a side bar's strip, or a menu of rows)
//   inDrawer: the target is one of the drawer's items
//   bounds:   { width, height } of the window, to flip a tooltip that has no
//             room on its side to the other side (sliding back would cover),
//             and to keep it on the window along the bar: one for a widget
//             at the screen's end slides back in, `inset` short of the edge
//   bar:      the bar's strip (optional). A target on the bar is measured
//             from the strip's far edge when that is farther out: an island
//             (and a large bar's lip) reaches past the target's cell, and a
//             tooltip measured from the cell would sit on the island's edge.
//   inset:    room kept clear at the window's ends (the tooltip's shadow)
// Returns { x, y }, the tooltip's top left corner.

function centreOn(target, popup, alongX) {
  return alongX ? target.x + target.width / 2 - popup.width / 2 : target.y + target.height / 2 - popup.height / 2
}

// Out from the bar, past `edge` (the target's far side, or the drawer's).
function away(position, edge, popup, gap) {
  if (position === "top") return { y: edge.y + edge.height + gap }
  if (position === "bottom") return { y: edge.y - popup.height - gap }
  if (position === "left") return { x: edge.x + edge.width + gap }
  return { x: edge.x - popup.width - gap }
}

function overlaps(a, b) {
  return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
}

// The farther of two rectangles' sides away from the bar.
function outer(position, a, b) {
  if (!b) return a
  if (position === "top") return a.y + a.height >= b.y + b.height ? a : { x: a.x, y: b.y, width: a.width, height: b.y + b.height - b.y }
  if (position === "bottom") return a.y <= b.y ? a : { x: a.x, y: b.y, width: a.width, height: a.height }
  if (position === "left") return a.x + a.width >= b.x + b.width ? a : { x: b.x, y: a.y, width: b.width, height: a.height }
  return a.x <= b.x ? a : { x: b.x, y: a.y, width: a.width, height: a.height }
}

// Along the bar, inside the window.
function within(barVertical, at, popup, bounds, inset) {
  if (!bounds) return at
  var pad = inset || 0
  if (barVertical) at.y = Math.max(pad, Math.min(at.y, bounds.height - popup.height - pad))
  else at.x = Math.max(pad, Math.min(at.x, bounds.width - popup.width - pad))
  return at
}

function place(position, target, popup, gap, drawer, inDrawer, bounds, bar, inset) {
  var barVertical = position === "left" || position === "right"
  return within(barVertical, spot(position, barVertical, target, popup, gap, drawer, inDrawer, bounds, bar, inset), popup, bounds, inset)
}

function spot(position, barVertical, target, popup, gap, drawer, inDrawer, bounds, bar, inset) {
  if (drawer && inDrawer) {
    if (drawer.vertical && !barVertical) {
      // A menu of rows under a top or bottom bar: beside the menu, level with
      // the row, not over the rows below it.
      var right = drawer.x + drawer.width + gap
      var fits = !bounds || right + popup.width <= bounds.width
      return { x: fits ? right : drawer.x - popup.width - gap, y: centreOn(target, popup, false) }
    }
    // A strip: out from the bar past the strip, level with the item.
    var out = away(position, drawer, popup, gap)
    return barVertical ? { x: out.x, y: centreOn(target, popup, false) } : { x: centreOn(target, popup, true), y: out.y }
  }
  var beside = away(position, outer(position, target, bar), popup, gap)
  var at = within(barVertical, barVertical ? { x: beside.x, y: centreOn(target, popup, false) } : { x: centreOn(target, popup, true), y: beside.y }, popup, bounds, inset)
  // On the bar beside an open drawer: past the drawer, not over it (where
  // it stands after sliding in from the screen's end).
  if (drawer && overlaps({ x: at.x, y: at.y, width: popup.width, height: popup.height }, drawer)) {
    var past = away(position, drawer, popup, gap)
    if (barVertical) at.x = past.x
    else at.y = past.y
  }
  return at
}

if (typeof module !== "undefined") module.exports = { place, overlaps }
