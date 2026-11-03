// The shelf (on-demand-drawers.md DEMAND-120 to DEMAND-125): a strip drawer
// joined to the bar's edge, drawn as one surface with it. Everything here is
// in the shelf's own frame, as if the bar were on top: x runs along the bar
// from the shelf's start, y away from the bar, the join on y = 0.
//
// Each end of the shelf meets the bar surface it hangs from in one of four
// ways (`joinOf`): "inside", the bar runs on past it, so the shelf's side
// curves out into the bar's edge with a fillet; "tight", the same but too
// near the bar's end for the bar's own corner, which goes square, the fillet
// no wider than the room; "flush", the shelf's side continues the bar's end
// straight down (the bar's corner there goes square); "beyond", the shelf runs
// on past the bar's end, so its top corner is round and a fillet curves up
// from its top edge into the bar's end (the bar's corner goes square), the two
// sharing the stretch past the end when it is short.

var EPS = 0.5

// How the end meets the bar: `past` is how far the bar runs on past this end
// of the shelf (negative where the shelf runs on past the bar); `room` what an
// inside end needs to keep the bar's corner round (snapRoom).
function joinOf(past, room) {
  if (Math.abs(past) <= EPS) return "flush"
  if (past < 0) return "beyond"
  return past < (room || 0) ? "tight" : "inside"
}

// The room an end needs for its fillet and the corners beside it: closer to
// the bar's end than this, the shelf snaps flush with it, or runs on to it
// when it cannot move (fit).
function snapRoom(radius, barRadius) {
  return radius + Math.max(radius, barRadius)
}

// How far to move a shelf that starts at `start` and is `length` long so
// that neither end lands too close to the bar's end to curve cleanly, flush
// with it instead: bar = { start, end, radius } along the same axis; the
// shelf stays within [min, max] when given, and an end already flush stays.
// The start wins. An end it cannot move stays "tight" or a short "beyond".
function snapShift(start, length, bar, radius, min, max) {
  if (!bar) return 0
  var room = snapRoom(radius, bar.radius || 0)
  var atStart = start - bar.start, atEnd = bar.end - (start + length)
  var lo = min === undefined ? -Infinity : min, hi = max === undefined ? Infinity : max
  function fits(shift) { return start + shift >= lo - EPS && start + length + shift <= hi + EPS }
  var startNear = Math.abs(atStart) > EPS && Math.abs(atStart) < room
  var endNear = Math.abs(atEnd) > EPS && Math.abs(atEnd) < room
  if (startNear && Math.abs(atEnd) > EPS && fits(-atStart)) return -atStart
  if (endNear && Math.abs(atStart) > EPS && fits(atEnd)) return atEnd
  return 0
}

// Where the shelf goes and how long it is: { start, length }. It moves as
// snapShift does; then, when `grow`, an end the move could not help lengthens.
// With the other end flush there is no moving it, and a step too short for
// two curves reads as a nub: an end short of the bar's end by less than the
// room runs on to it, and one past it by less than two radii runs on until
// the corner and the fillet each have their radius, kept within [min, max].
function fit(start, length, bar, radius, min, max, grow) {
  var s = start + snapShift(start, length, bar, radius, min, max), l = length
  if (!grow) return { start: s, length: l }
  var room = snapRoom(radius, bar.radius || 0), curves = radius * 2
  var atStart = s - bar.start, atEnd = bar.end - (s + l)
  if (Math.abs(atStart) <= EPS) {
    if (atEnd > EPS && atEnd < room) l += atEnd
    else if (atEnd < -EPS && atEnd > -curves) l = Math.max(l, Math.min(bar.end + curves, max) - s)
  } else if (Math.abs(atEnd) <= EPS) {
    if (atStart > EPS && atStart < room) { l += atStart; s = bar.start }
    else if (atStart < -EPS && atStart > -curves) {
      var from = Math.min(s, Math.max(bar.start - curves, min))
      l += s - from
      s = from
    }
  }
  return { start: s, length: l }
}

// Where a shelf `length` long starts when it is edge-aligned with its bar
// surface (bar = { start, end }): flush with the end of the surface nearest
// `source` (the cell it hangs from, { start, end }, or none), running back
// along the surface from there, and kept within [min, max].
function alignStart(bar, length, source, min, max) {
  var mid = source ? (source.start + source.end) / 2 : (bar.start + bar.end) / 2
  var start = mid - bar.start <= bar.end - mid ? bar.start : bar.end - length
  return Math.max(min, Math.min(max - length, start))
}

function n(v) { return Math.round(v * 100) / 100 }
function arc(r, x, y, sweep) { return " A " + n(r) + " " + n(r) + " 0 0 " + sweep + " " + n(x) + " " + n(y) }
function line(x, y) { return " L " + n(x) + " " + n(y) }

// The shelf's shape: o = { length, depth, radius, barStart, barEnd,
// barRadius } with
// the bar's ends in the shelf's frame (barStart <= 0 when the bar runs on
// past the shelf's start). Returns { fill, edge, start, end, ups } where
// fill is the closed SVG path of the shelf with its fillets into the bar's
// edge, edge the open path of its outline away from the bar (for a border),
// start and end each end's join, and ups the fillets that curve up into the
// bar's ends ("beyond"), each its own closed path { fill, edge }, drawn apart
// since they stand above the join while the shelf slides out of it.
function outline(o) {
  var L = Math.max(0, o.length), D = Math.max(0, o.depth)
  var r = Math.max(0, Math.min(o.radius || 0, L / 2, D / 2))
  var room = snapRoom(r, o.barRadius || 0)
  var b0 = o.barStart, b1 = o.barEnd
  var start = joinOf(-b0, room), end = joinOf(b1 - L, room)
  // An inside fillet runs down the side: it stops before the bottom corner,
  // and a tight one is no wider than the bar's edge left beside it.
  function fillet(past) { return Math.max(0, Math.min(r, D - r, past)) }
  // Past the bar's end, the shelf's top corner and the up fillet share the
  // stretch past it.
  function past(beyond) { return Math.max(0, Math.min(r, beyond / 2)) }
  var path = "", ups = []
  // From where the shelf leaves the join at its end, clockwise round to
  // where it comes back to it at its start.
  if (end === "inside" || end === "tight") {
    var fe = fillet(b1 - L)
    path = "M " + n(L + fe) + " 0" + arc(fe, L, fe, 0)
  } else if (end === "flush") path = "M " + n(L) + " 0"
  else {
    var ge = past(L - b1)
    path = "M " + n(b1 + ge) + " 0" + line(L - ge, 0) + arc(ge, L, ge, 1)
    ups.push({ fill: "M " + n(b1) + " " + n(-ge) + arc(ge, b1 + ge, 0, 0) + line(b1, 0) + " Z",
      edge: "M " + n(b1) + " " + n(-ge) + arc(ge, b1 + ge, 0, 0) })
  }
  path += line(L, D - r)
  path += arc(r, L - r, D, 1) + line(r, D) + arc(r, 0, D - r, 1)
  if (start === "inside" || start === "tight") {
    var fs = fillet(-b0)
    path += line(0, fs) + arc(fs, -fs, 0, 0)
  } else if (start === "flush") path += line(0, 0)
  else {
    var gs = past(b0)
    path += line(0, gs) + arc(gs, gs, 0, 1) + line(b0 - gs, 0)
    ups.push({ fill: "M " + n(b0) + " " + n(-gs) + line(b0, 0) + line(b0 - gs, 0) + arc(gs, b0, -gs, 0) + " Z",
      edge: "M " + n(b0 - gs) + " 0" + arc(gs, b0, -gs, 0) })
  }
  // The fill closes along the join; for a shelf past the bar's end, the
  // stretch of its top edge under the up fillet is filled by the fillet.
  var fill = path
  if (end === "beyond") fill = fill.replace(/^M \S+ 0/, "M " + n(b1) + " 0")
  if (start === "beyond") fill += line(b0, 0)
  return { fill: fill + " Z", edge: path, start: start, end: end, ups: ups }
}

// From the shelf's frame to the drawer's own (x, y) for a bar at `position`,
// the drawer `width` x `height`: a 4x4 matrix's 16 values, row by row.
function frameMatrix(position, width, height) {
  if (position === "bottom") return [1, 0, 0, 0, 0, -1, 0, height, 0, 0, 1, 0, 0, 0, 0, 1]
  if (position === "left") return [0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
  if (position === "right") return [0, -1, 0, width, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
  return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
}

// The bar's corners a shelf squares where it joins tight, flush or past it:
// for each end of the shelf, the corner of the bar surface on its join side.
function squaredCorners(position, start, end) {
  var corners = position === "bottom" ? ["tl", "tr"] : position === "left" ? ["tr", "br"]
    : position === "right" ? ["tl", "bl"] : ["bl", "br"]
  var out = []
  if (start !== "inside") out.push(corners[0])
  if (end !== "inside") out.push(corners[1])
  return out
}
