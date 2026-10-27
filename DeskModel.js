// The desk of the Look and Behavior pages (docs/behavior/preferences.md
// PREFS-124 to PREFS-131): strips side by side on one tilted plate, each a
// column of controls, and the cursor's walk through them.
//
// A desk is strips left to right, each a list of its controls top to bottom
// as { stops, home }: a row of chips has a stop per chip, everything else one
// (a vertical choice keeps its own cursor, the Screen edge grid is one
// control); `home` is the stop a step from above or below, or a jump to the
// strip, lands on (a chip row's chosen chip). A place is
// { strip, control, stop }. Controls that cannot be used now (dimmed or
// given way) are left out of the lists by the page.

// The strips' boxes: equal widths across the plate, `gap` apart.
function stripBoxes(width, count, gap) {
  var n = Math.max(0, Math.floor(count))
  if (!n) return []
  var w = Math.max(0, (width - gap * (n - 1)) / n)
  var out = []
  for (var i = 0; i < n; i++) out.push({ x: i * (w + gap), width: w })
  return out
}

function controlsOf(strips, s) {
  return strips[s] || []
}
function stopsOf(control) {
  return Math.max(1, Math.floor(Number(control && control.stops) || 1))
}
function homeOf(control) {
  var n = stopsOf(control)
  var h = Math.floor(Number(control && control.home) || 0)
  return Math.max(0, Math.min(n - 1, h))
}
function place(strip, control, stop) {
  return { strip: strip, control: control, stop: stop }
}

// Every stop in reading order: down a strip, then on to the next.
function readingOrder(strips) {
  var out = []
  for (var s = 0; s < strips.length; s++) {
    var list = controlsOf(strips, s)
    for (var c = 0; c < list.length; c++)
      for (var k = 0; k < stopsOf(list[c]); k++) out.push(place(s, c, k))
  }
  return out
}

function same(a, b) {
  return !!a && !!b && a.strip === b.strip && a.control === b.control && a.stop === b.stop
}

// A place that may have gone stale (a control left the list) made valid:
// the nearest control left in its strip, else the desk's first stop.
function valid(strips, at) {
  if (at && strips[at.strip] && controlsOf(strips, at.strip).length) {
    var list = controlsOf(strips, at.strip)
    var c = Math.max(0, Math.min(list.length - 1, at.control))
    var k = c === at.control ? Math.max(0, Math.min(stopsOf(list[c]) - 1, at.stop)) : homeOf(list[c])
    return place(at.strip, c, k)
  }
  return first(strips)
}

// The first stop of the first strip that has one (null on an empty desk).
function first(strips) {
  for (var s = 0; s < strips.length; s++)
    if (controlsOf(strips, s).length) return place(s, 0, homeOf(controlsOf(strips, s)[0]))
  return null
}

// h/l on the Look page: the previous or next stop in reading order,
// wrapping round the desk.
function reading(strips, at, dir) {
  var order = readingOrder(strips)
  if (!order.length) return null
  var from = valid(strips, at)
  var i = order.findIndex(function(p) { return same(p, from) })
  if (i < 0) return order[0]
  return order[((i + (dir < 0 ? -1 : 1)) % order.length + order.length) % order.length]
}

// The next or previous strip that has controls, wrapping; -1 when none does.
function nextStrip(strips, s, dir) {
  var n = strips.length
  for (var step = 1; step <= n; step++) {
    var i = ((s + (dir < 0 ? -step : step)) % n + n) % n
    if (controlsOf(strips, i).length) return i
  }
  return -1
}

// j/k on a control with nothing vertical of its own: the control below or
// above in the strip; past the strip's end the next strip's first control
// (j) or the previous strip's last (k), wrapping round the desk.
function vertical(strips, at, dir) {
  var from = valid(strips, at)
  if (!from) return null
  var list = controlsOf(strips, from.strip)
  var c = from.control + (dir < 0 ? -1 : 1)
  if (c >= 0 && c < list.length) return place(from.strip, c, homeOf(list[c]))
  var s = nextStrip(strips, from.strip, dir)
  if (s < 0) return from
  var next = controlsOf(strips, s)
  var to = dir < 0 ? next.length - 1 : 0
  return place(s, to, homeOf(next[to]))
}

// Tab and Shift+Tab: the next or previous strip's first control.
function tab(strips, at, dir) {
  var from = valid(strips, at)
  if (!from) return null
  var s = nextStrip(strips, from.strip, dir)
  if (s < 0) return from
  return place(s, 0, homeOf(controlsOf(strips, s)[0]))
}

// h/l on the Behavior page, whose controls are all rows: the same row of the
// next or previous strip, clamped to that strip's last row, wrapping.
function across(strips, at, dir) {
  var from = valid(strips, at)
  if (!from) return null
  var s = nextStrip(strips, from.strip, dir)
  if (s < 0) return from
  var next = controlsOf(strips, s)
  var c = Math.min(next.length - 1, from.control)
  return place(s, c, homeOf(next[c]))
}

// The Screen edge grid: h j k l choose an edge directly ("" for any other key).
function gridEdge(key) {
  return ({ h: "left", j: "bottom", k: "top", l: "right" })[String(key || "").toLowerCase()] || ""
}

// A vertical choice's cursor moved by j (dir 1) or k (-1); -1 past its ends,
// where the step goes on to the control below or above.
function choiceStep(count, cursor, dir) {
  var next = cursor + (dir < 0 ? -1 : 1)
  return next >= 0 && next < count ? next : -1
}

// The legend: the page's lines, a line the focused control has for the same
// keys in its place, and the control's other lines first.
function legend(pageLines, controlLines) {
  var out = (pageLines || []).slice()
  var extra = []
  ;(controlLines || []).forEach(function(line) {
    var i = out.findIndex(function(p) { return p.keys === line.keys })
    if (i >= 0) out[i] = line
    else extra.push(line)
  })
  return extra.concat(out)
}

if (typeof module !== "undefined") module.exports = { stripBoxes, readingOrder, valid, first, reading, nextStrip, vertical, tab, across, gridEdge, choiceStep, legend }
