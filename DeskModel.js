// The desk of the Look and Behavior pages (docs/behavior/preferences.md
// PREFS-124 to PREFS-131): strips side by side on one tilted plate, each a
// column of controls, and the cursor's walk through them. j/k move the
// cursor, h/l move a value (PREFS-126); between them the desk reads as one
// grid: h/l walk a row of chips and go on to the next strip's row.
//
// A desk is strips left to right, each a list of its controls top to bottom
// as { stops, home }: a row of chips has a stop per chip, everything else one;
// `home` is the stop a step from above or below, or a jump to the strip,
// lands on (a chip row's chosen chip). A place is { strip, control, stop }.
// Controls that cannot be used now (dimmed or given way) are left out of the
// lists by the page.

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

// The next or previous strip that has controls, wrapping; -1 when none does.
function nextStrip(strips, s, dir) {
  var n = strips.length
  for (var step = 1; step <= n; step++) {
    var i = ((s + (dir < 0 ? -step : step)) % n + n) % n
    if (controlsOf(strips, i).length) return i
  }
  return -1
}

// j/k, on every control: the control below or above in the strip; past the
// strip's end the next strip's first control (j) or the previous strip's
// last (k), wrapping round the desk.
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

// h/l on a row (a switch, a pick row, a shortcut) or at a chip row's end:
// the same row of the next or previous strip, clamped to that strip's last
// row, wrapping. A row of chips is entered at the chip nearest the way in
// (l lands on its first chip, h on its last), so the walk reads as one grid.
function across(strips, at, dir) {
  var from = valid(strips, at)
  if (!from) return null
  var s = nextStrip(strips, from.strip, dir)
  if (s < 0) return from
  var next = controlsOf(strips, s)
  var c = Math.min(next.length - 1, from.control)
  return place(s, c, dir < 0 ? stopsOf(next[c]) - 1 : 0)
}

// h/l as the desk takes them (a fader keeps them for its value): on a row of
// chips the next or previous chip, and past the row's ends the same row of
// the next or previous strip, as on any other control (across).
function sideways(strips, at, dir) {
  var from = valid(strips, at)
  if (!from) return null
  var control = controlsOf(strips, from.strip)[from.control]
  var k = from.stop + (dir < 0 ? -1 : 1)
  if (k >= 0 && k < stopsOf(control)) return place(from.strip, from.control, k)
  return across(strips, from, dir)
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

if (typeof module !== "undefined") module.exports = { stripBoxes, valid, first, nextStrip, vertical, tab, across, sideways, legend }
