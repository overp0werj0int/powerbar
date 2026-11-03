// A dashed frame's dashes (DashedFrame.qml), placed rather than left to a
// dash pattern running round the outline: a pattern's phase lands anywhere
// at a corner, so each corner looked different. Here every corner is one
// solid piece (its arc, or on a square corner two short legs) and each side
// between two corners gets whole dashes with the gaps stretched so the side
// starts and ends with a gap of the same width: every corner and every side
// reads the same, whatever the size.
//
// width, height: the frame's box; the stroke runs half a pixel inside it.
// top, bottom: the corners' radii (the top two, the bottom two).
// dash, gap: the dash's length and the gap aimed for.
// Returns polylines, [[{ x, y }, ...], ...], for a ShapePath's PathMultiline.
function frame(width, height, top, bottom, dash, gap) {
  var x0 = 0.5, y0 = 0.5, x1 = width - 0.5, y1 = height - 0.5
  if (!(x1 > x0) || !(y1 > y0) || !(dash > 0)) return []
  var w = x1 - x0, h = y1 - y0
  var rt = clamp(top, w / 2, h / 2), rb = clamp(bottom, w / 2, h / 2)
  var lt = leg(rt, dash), lb = leg(rb, dash)
  var out = []
  // Corners, clockwise from the top left: a quarter arc each, legs on.
  out.push(corner(x0 + rt, y0 + rt, rt, lt, 180))
  out.push(corner(x1 - rt, y0 + rt, rt, lt, 270))
  out.push(corner(x1 - rb, y1 - rb, rb, lb, 0))
  out.push(corner(x0 + rb, y1 - rb, rb, lb, 90))
  // Sides, between the corners' legs.
  side(out, x0 + rt + lt, y0, x1 - rt - lt, y0, dash, gap)
  side(out, x1, y0 + rt + lt, x1, y1 - rb - lb, dash, gap)
  side(out, x1 - rb - lb, y1, x0 + rb + lb, y1, dash, gap)
  side(out, x0, y1 - rb - lb, x0, y0 + rt + lt, dash, gap)
  return out
}

function clamp(r, a, b) {
  return Math.max(0, Math.min(r || 0, a, b))
}

// How far a corner's piece runs on along each side: a square corner is two
// legs a dash long; a round one tops its arc up to a dash, no more.
function leg(r, dash) {
  if (r <= 0) return dash
  return Math.max(0, (dash - Math.PI * r / 2) / 2)
}

// A corner's piece round (cx, cy): a quarter turn clockwise (screen y
// down) from `from` degrees, a leg before and after it along the way the
// outline runs there.
function corner(cx, cy, r, l, from) {
  var a0 = from * Math.PI / 180, a1 = a0 + Math.PI / 2
  var steps = r > 0 ? Math.max(2, Math.ceil(r)) : 0
  var pts = []
  if (l > 0) pts.push({ x: cx + r * Math.cos(a0) + l * Math.sin(a0), y: cy + r * Math.sin(a0) - l * Math.cos(a0) })
  for (var i = 0; i <= steps; i++) {
    var a = a0 + (a1 - a0) * (steps ? i / steps : 0)
    pts.push({ x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) })
  }
  if (l > 0) pts.push({ x: cx + r * Math.cos(a1) - l * Math.sin(a1), y: cy + r * Math.sin(a1) + l * Math.cos(a1) })
  return pts
}

// Whole dashes from (ax, ay) to (bx, by), a gap at each end as wide as the
// gaps between.
function side(out, ax, ay, bx, by, dash, gap) {
  var len = Math.hypot(bx - ax, by - ay)
  if (len <= 0) return
  var n = Math.max(0, Math.round((len - gap) / (dash + gap)))
  if (!n) return
  var g = (len - n * dash) / (n + 1)
  var ux = (bx - ax) / len, uy = (by - ay) / len
  for (var i = 0; i < n; i++) {
    var s = g + i * (dash + g)
    out.push([{ x: ax + ux * s, y: ay + uy * s }, { x: ax + ux * (s + dash), y: ay + uy * (s + dash) }])
  }
}
