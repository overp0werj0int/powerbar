// A camera notch at the top of a laptop panel (docs/behavior/layout-zones.md,
// "Notch"). Pure rules; Bar.qml reads the file and Hyprland's modes.
//
// Omarchy's platform package describes the panels that have one, in
// /usr/share/omarchy-platform/display-cutouts.json:
//
//   { "panels": [ { "connector": "eDP", "width": 3024, "height": 1964, "top": 64 } ] }
//
// A panel matches a screen whose connector name starts with `connector` and
// whose mode is width x height physical pixels; `top` is how many physical
// rows the notch covers. Omarchy's bar reads the same file (BarModel.js
// parseCutouts, cutoutTop, cutoutPending), and these follow it so both bars
// agree on which screens have a notch and how tall it is.
//
// The file has no width or shape. notch-panels.json, next to this file, gives
// each panel's camera housing in panel pixels, measured on Apple's bezel
// artwork (its sources are in it): its width along the screen's top edge, the
// radius of its bottom corners and that of its shoulders, the inside curves
// where the screen's top edge turns down into it, and the radius of the
// screen's own top corners. Below the shoulders the housing is width - 2 x
// shoulder wide. A panel it lacks takes the 14-inch MacBook Pro's, and
// powerbarNotchWidth and powerbarNotchHeight (logical px) set the size for a
// panel that differs.
var DEFAULT_WIDTH = 382
var DEFAULT_RADIUS = 20
var DEFAULT_SHOULDER = 6
var DEFAULT_SCREEN_RADIUS = 40

// The described panels; anything malformed is dropped.
function parseCutouts(text) {
  var parsed
  try {
    parsed = JSON.parse(String(text || ""))
  } catch (error) {
    return []
  }
  var panels = parsed && Array.isArray(parsed.panels) ? parsed.panels : []
  var cutouts = []
  for (var i = 0; i < panels.length; i++) {
    var panel = panels[i] || {}
    var width = Number(panel.width), height = Number(panel.height), top = Number(panel.top)
    if (typeof panel.connector !== "string" || panel.connector === "") continue
    if (!(width > 0) || !(height > 0) || !(top > 0) || top >= height) continue
    cutouts.push({ connector: panel.connector, width: width, height: height, top: top })
  }
  return cutouts
}

// notch-panels.json's housings: [{ width, height, notchWidth, radius,
// shoulder, screenRadius }] (panel px); a row without a shape takes the
// default one, one without screenRadius square corners, and anything
// malformed is dropped.
function parsePanels(text) {
  var parsed
  try {
    parsed = JSON.parse(String(text || ""))
  } catch (error) {
    return []
  }
  var panels = parsed && Array.isArray(parsed.panels) ? parsed.panels : []
  var out = []
  for (var i = 0; i < panels.length; i++) {
    var p = panels[i] || {}
    var width = Number(p.width), height = Number(p.height), notch = Number(p.notchWidth)
    if (!(width > 0) || !(height > 0) || !(notch > 0) || notch >= width) continue
    var radius = p.radius === undefined ? DEFAULT_RADIUS : Number(p.radius)
    var shoulder = p.shoulder === undefined ? DEFAULT_SHOULDER : Number(p.shoulder)
    var screenRadius = p.screenRadius === undefined ? 0 : Number(p.screenRadius)
    if (!(radius >= 0) || !(shoulder >= 0) || (radius + shoulder) * 2 >= notch) continue
    if (!(screenRadius >= 0) || screenRadius * 2 >= height) continue
    out.push({ width: width, height: height, notchWidth: notch, radius: radius, shoulder: shoulder, screenRadius: screenRadius })
  }
  return out
}

// A panel's camera housing in panel pixels, { notchWidth, radius, shoulder,
// screenRadius }: its notch-panels.json row, matched by mode as panelOf
// matches, else the default.
function housingOf(panels, panel) {
  var list = Array.isArray(panels) ? panels : []
  for (var i = 0; i < list.length; i++) {
    if (Math.abs(list[i].width - panel.width) <= 4 && Math.abs(list[i].height - panel.height) <= 4) return list[i]
  }
  return { notchWidth: DEFAULT_WIDTH, radius: DEFAULT_RADIUS, shoulder: DEFAULT_SHOULDER, screenRadius: DEFAULT_SCREEN_RADIUS }
}

// The described panel this screen is, or null. `mode` is the output's
// physical mode as Hyprland reports it ({ width, height, transform }); until it
// arrives the logical size times Qt's (whole-number) ratio stands in, which
// rebuilds the mode only at whole scales. Turned a quarter or upside down, the
// notch is on another edge: no panel.
function panelOf(cutouts, screenName, logicalWidth, logicalHeight, devicePixelRatio, mode) {
  var name = String(screenName || "")
  var logical = Number(logicalWidth), logicalTall = Number(logicalHeight)
  if (!(logical > 0) || !(logicalTall > 0)) return null
  var width = Number(mode && mode.width), height = Number(mode && mode.height)
  if (width > 0 && height > 0) {
    var transform = Number(mode.transform) || 0
    if (transform !== 0 && transform !== 4) return null
    if ((width > height) !== (logical > logicalTall)) return null
  } else {
    var scale = Number(devicePixelRatio) > 0 ? Number(devicePixelRatio) : 1
    width = Math.round(logical * scale)
    height = Math.round(logicalTall * scale)
  }
  var list = Array.isArray(cutouts) ? cutouts : []
  for (var i = 0; i < list.length; i++) {
    var panel = list[i]
    if (name.indexOf(panel.connector) !== 0) continue
    // Logical sizes are rounded, so a rebuilt mode can be a couple of pixels off.
    if (Math.abs(width - panel.width) <= 4 && Math.abs(height - panel.height) <= 4)
      return { panel: panel, physicalWidth: width }
  }
  return null
}

// The notch a top bar on this screen meets, in logical px: { housing, width,
// height, radius, shoulder, screenRadius }, or null (no notch, or a bar on
// another edge).
// width: a positive powerbarNotchWidth, else the panel's housing (`panels`,
// from parsePanels); height: a positive powerbarNotchHeight, else a positive
// calibrated height (Omarchy's [bar] notch-height), else the described rows;
// radius and shoulder: the housing's corners, kept within its height;
// screenRadius: the screen's top corners.
function notchOf(cutouts, position, screenName, logicalWidth, logicalHeight, devicePixelRatio, mode, width, calibratedHeight, panels, setHeight) {
  if (position !== "top") return null
  var found = panelOf(cutouts, screenName, logicalWidth, logicalHeight, devicePixelRatio, mode)
  if (!found) return null
  var ratio = Number(logicalWidth) / found.physicalWidth
  var shape = housingOf(panels, found.panel)
  var housing = Math.ceil(shape.notchWidth * ratio)
  var detected = Number(calibratedHeight) > 0 ? Math.round(Number(calibratedHeight)) : Math.ceil(found.panel.top * ratio)
  var height = Number(setHeight) > 0 ? Math.round(Number(setHeight)) : detected
  var shoulder = Math.min(shape.shoulder * ratio, height / 2)
  return {
    // housing: the default width, what an unset width falls back to.
    housing: housing,
    width: Number(width) > 0 ? Math.round(Number(width)) : housing,
    // detectedHeight: the default height, what an unset height falls back to.
    detectedHeight: detected,
    height: height,
    radius: Math.min(shape.radius * ratio, height - shoulder),
    shoulder: shoulder,
    screenRadius: shape.screenRadius * ratio
  }
}

// The housing's corners on a notch `width` wide (a set width can be narrower
// than the panel's): { radius, shoulder }, shrunk together to fit. Below the
// shoulders the housing is width - 2 x shoulder wide (NotchShape.qml).
function cornersOf(notch, width) {
  var r = Math.max(0, Number(notch && notch.radius) || 0), s = Math.max(0, Number(notch && notch.shoulder) || 0)
  var fit = Math.max(0, Number(width) / 2)
  var k = r + s > fit ? fit / (r + s) : 1
  return { radius: r * k, shoulder: s * k }
}

// A floating bar or the islands beside a notch, on the notched screen
// (docs/behavior/appearance.md LOOK-147, LOOK-148), in logical px.
//
// The thickness a floating bar needs there: its own, or the camera's depth
// plus one gap when that is more, so a band one gap thick runs under the
// cutout.
function wrapThickness(notch, barSize, gap) {
  return notch ? Math.max(barSize, notch.height + gap) : barSize
}
// The outer corners of a surface held `gap` off the screen's rounded top
// corners: the top ones concentric with the screen's (its radius less the
// gap, or the rounding when that is more, as for a screen whose corners are
// unknown), within the height the bottom ones leave; the bottom ones the
// rounding. null without a notch.
function outerCorners(notch, gap, rounding, height) {
  if (!notch) return null
  var bottom = Math.max(0, Number(rounding) || 0)
  var top = Math.max(bottom, (Number(notch.screenRadius) || 0) - gap)
  return { top: Math.max(0, Math.min(top, height - bottom)), bottom: bottom }
}
// The cutout a floating bar makes round the camera, in the bar's own
// coordinates (it sits at barX, barY in a window `windowWidth` wide with the
// camera centred): its sides `gap` off the housing below the shoulders, its
// floor `gap` below the camera with the camera's bottom corners grown by the
// gap (concentric), and where the bar's top edge turns down into it a fillet
// of that same radius, so the cut's four corners match. null without a notch.
function wrapCut(notch, windowWidth, barX, barY, gap) {
  if (!notch) return null
  var c = cornersOf(notch, notch.width)
  var left = (windowWidth - notch.width) / 2
  return {
    start: left + c.shoulder - gap - barX,
    end: left + notch.width - c.shoulder + gap - barX,
    depth: notch.height + gap - barY,
    radius: c.radius + gap,
    fillet: Math.max(0, Math.min(c.radius + gap, (notch.height + gap - barY) / 2))
  }
}
// The outline of a surface o.width x o.height at o.x, o.y (default 0) as an
// SVG path, clockwise: corners o.tl, o.tr, o.br, o.bl and, when o.cut is
// given (wrapCut), a dip round the camera from its top edge. o.inset draws the
// same outline that much inside (a border's inner edge): the box shrinks, its
// corners and the fillets tighten, the cut widens and deepens.
function wrapOutline(o) {
  var d = Math.max(0, Number(o.inset) || 0), ox = Number(o.x) || 0, oy = Number(o.y) || 0
  var w = o.width, h = o.height
  var r = function(v) { return Math.max(0, (Number(v) || 0) - d) }
  var room = Math.max(0, (h - 2 * d) / 2)
  var tl = Math.min(r(o.tl), room), tr = Math.min(r(o.tr), room)
  var bl = Math.min(r(o.bl), room), br = Math.min(r(o.br), room)
  var n = function(v) { return String(Math.round(v * 1000) / 1000) }
  var parts = []
  var move = function(x, y) { parts.push("M " + n(x + ox) + " " + n(y + oy)) }
  var line = function(x, y) { parts.push("L " + n(x + ox) + " " + n(y + oy)) }
  var arc = function(rad, x, y, convex) {
    if (rad <= 0) return line(x, y)
    parts.push("A " + n(rad) + " " + n(rad) + " 0 0 " + (convex ? 1 : 0) + " " + n(x + ox) + " " + n(y + oy))
  }
  move(d, d + tl)
  arc(tl, d + tl, d, true)
  var cut = o.cut
  if (cut) {
    var cs = cut.start - d, ce = cut.end + d, depth = cut.depth + d
    var f = Math.max(0, Math.min(cut.fillet - d, (depth - d) / 2))
    var rc = Math.max(0, Math.min(cut.radius + d, (ce - cs) / 2, depth - d - f))
    line(cs - f, d)
    arc(f, cs, d + f, true)
    line(cs, depth - rc)
    arc(rc, cs + rc, depth, false)
    line(ce - rc, depth)
    arc(rc, ce, depth - rc, false)
    line(ce, d + f)
    arc(f, ce + f, d, true)
  }
  line(w - d - tr, d)
  arc(tr, w - d, d + tr, true)
  line(w - d, h - d - br)
  arc(br, w - d - br, h - d, true)
  line(d + bl, h - d)
  arc(bl, d, h - d - bl, true)
  parts.push("Z")
  return parts.join(" ")
}

// The corners the notch mode's zones take from the camera, in logical px
// ({ radius, shoulder }): the notch's own, else (no notched screen) the
// default housing's at a MacBook's scale 2.
function zoneCorners(notch) {
  if (notch && notch.radius >= 0 && notch.shoulder >= 0) return { radius: notch.radius, shoulder: notch.shoulder }
  return { radius: DEFAULT_RADIUS / 2, shoulder: DEFAULT_SHOULDER / 2 }
}

// Whether a top bar can't tell its notch yet: Hyprland hasn't reported the
// screen's mode, the rebuilt one matched no panel (as at a fractional scale),
// and a described connector matches the screen, so the mode may still bring a
// notch. The bar waits for the mode (a while at most) rather than guess.
function pending(cutouts, position, screenName, logicalWidth, logicalHeight, devicePixelRatio, mode) {
  if (position !== "top") return false
  if (Number(mode && mode.width) > 0 && Number(mode && mode.height) > 0) return false
  var name = String(screenName || "")
  var list = Array.isArray(cutouts) ? cutouts : []
  var described = list.some(function(c) { return name.indexOf(c.connector) === 0 })
  return described && !panelOf(cutouts, screenName, logicalWidth, logicalHeight, devicePixelRatio, mode)
}

// The overshoot setting for Qt's OutBack easing that carries a slide of
// `distance` px at most `px` past its end, so a zone springing out of the
// camera overshoots by the same few pixels however long it is. OutBack's
// peak, as a fraction of the distance, is 4s³ / (27(s+1)²) for overshoot s;
// it rises with s, so a bisection finds it.
function backOvershoot(distance, px) {
  var d = Number(distance), p = Number(px)
  if (!(d > 0) || !(p > 0)) return 0
  var want = Math.min(p / d, 0.1)
  var peak = function(s) { return 4 * s * s * s / (27 * (s + 1) * (s + 1)) }
  var lo = 0, hi = 1.70158
  for (var i = 0; i < 40; i++) {
    var mid = (lo + hi) / 2
    if (peak(mid) < want) lo = mid; else hi = mid
  }
  return lo
}

// A notch zone that runs past the screen edge wraps: the items past `edge`
// (the left zone's first ones, the right zone's last) hang in a second row
// under the first, moved along the bar as one so the outermost still meets
// the edge, and the row reads from there toward the camera. spans: the
// zone's items in bar order, [{ start, end }] along the bar; side: "left" or
// "right"; align: where the second row's outermost item ends, when that is
// not `edge` (the right zone's first row stops short of the Preferences
// button, which keeps its place at the screen edge). Null when it fits; else
// { from, to } (the wrapped items, `to` exclusive), shift (how far they move
// along the bar), row ([start, end] of the second row) and rest (where the
// first row's items now begin on the left, or end on the right).
function wrapRow(spans, edge, side, align) {
  var list = Array.isArray(spans) ? spans : [], n = list.length
  if (!n) return null
  if (side === "left") {
    var cut = 0
    while (cut < n && list[cut].start < edge - 0.5) cut++
    if (cut === 0) return null
    var shift = edge - list[0].start
    return { from: 0, to: cut, shift: shift, row: [edge, list[cut - 1].end + shift], rest: cut < n ? list[cut].start : edge }
  }
  var first = n
  while (first > 0 && list[first - 1].end > edge + 0.5) first--
  if (first === n) return null
  var end = align === undefined ? edge : align
  var back = end - list[n - 1].end
  return { from: first, to: n, shift: back, row: [list[first].start + back, end], rest: first > 0 ? list[first - 1].end : edge }
}
