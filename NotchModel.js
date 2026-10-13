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
// each panel's camera housing in panel pixels from macOS readings (its sources
// are in it): its width along the screen's top edge, the radius of its bottom
// corners and that of its shoulders, the inside curves where the screen's top
// edge turns down into it. Below the shoulders the housing is width - 2 x
// shoulder wide. A panel it lacks takes the MacBook Pro's, and
// powerbarNotchWidth (logical px) sets the width for a panel that differs.
var DEFAULT_WIDTH = 370
var DEFAULT_RADIUS = 16
var DEFAULT_SHOULDER = 8
// The same housing in logical px at the MacBook's scale 2: the gap two-zone
// modes keep on a screen without a notch.
var DEFAULT_LOGICAL_WIDTH = 185

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
// shoulder }] (panel px); a row without a shape takes the default one, and
// anything malformed is dropped.
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
    if (!(radius >= 0) || !(shoulder >= 0) || (radius + shoulder) * 2 >= notch) continue
    out.push({ width: width, height: height, notchWidth: notch, radius: radius, shoulder: shoulder })
  }
  return out
}

// A panel's camera housing in panel pixels, { notchWidth, radius, shoulder }:
// its notch-panels.json row, matched by mode as panelOf matches, else the
// default.
function housingOf(panels, panel) {
  var list = Array.isArray(panels) ? panels : []
  for (var i = 0; i < list.length; i++) {
    if (Math.abs(list[i].width - panel.width) <= 4 && Math.abs(list[i].height - panel.height) <= 4) return list[i]
  }
  return { notchWidth: DEFAULT_WIDTH, radius: DEFAULT_RADIUS, shoulder: DEFAULT_SHOULDER }
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
// height, radius, shoulder }, or null (no notch, or a bar on another edge).
// width: a positive powerbarNotchWidth, else the panel's housing (`panels`,
// from parsePanels); height: a positive calibrated height (Omarchy's [bar]
// notch-height), else the described rows; radius and shoulder: the housing's
// corners, kept within its height.
function notchOf(cutouts, position, screenName, logicalWidth, logicalHeight, devicePixelRatio, mode, width, calibratedHeight, panels) {
  if (position !== "top") return null
  var found = panelOf(cutouts, screenName, logicalWidth, logicalHeight, devicePixelRatio, mode)
  if (!found) return null
  var ratio = Number(logicalWidth) / found.physicalWidth
  var shape = housingOf(panels, found.panel)
  var housing = Math.ceil(shape.notchWidth * ratio)
  var height = Number(calibratedHeight) > 0 ? Math.round(Number(calibratedHeight)) : Math.ceil(found.panel.top * ratio)
  var shoulder = Math.min(shape.shoulder * ratio, height / 2)
  return {
    // housing: the default width, what an unset width falls back to.
    housing: housing,
    width: Number(width) > 0 ? Math.round(Number(width)) : housing,
    height: height,
    radius: Math.min(shape.radius * ratio, height - shoulder),
    shoulder: shoulder
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
