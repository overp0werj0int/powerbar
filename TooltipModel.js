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
//             room on its side to the other side (sliding back would cover)
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

function place(position, target, popup, gap, drawer, inDrawer, bounds) {
  var barVertical = position === "left" || position === "right"
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
  var spot = away(position, target, popup, gap)
  var at = barVertical ? { x: spot.x, y: centreOn(target, popup, false) } : { x: centreOn(target, popup, true), y: spot.y }
  // On the bar beside an open drawer: past the drawer, not over it.
  if (drawer && overlaps({ x: at.x, y: at.y, width: popup.width, height: popup.height }, drawer)) {
    var past = away(position, drawer, popup, gap)
    if (barVertical) at.x = past.x
    else at.y = past.y
  }
  return at
}

if (typeof module !== "undefined") module.exports = { place, overlaps }
