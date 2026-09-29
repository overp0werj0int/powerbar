// Geometry for bar item highlights. Every highlight has the same thickness
// and corner radius; its length follows what the widget visibly paints, never
// shorter than it is thick, so lone icons all get the same circle or rounded
// square and text gets a pill with the same side padding.

function positive(item, key) {
  if (!item || !(key in item)) return 0
  var value = Number(item[key])
  return isFinite(value) && value > 0 ? value : 0
}
function rotatedLabel(item) {
  return "textRotation" in item && Math.abs(Number(item.textRotation) % 180) === 90
}
// Children that paint something: pointer areas and hidden or empty items do
// not count.
function paintedChildren(item) {
  var result = []
  var children = item && item.children || []
  for (var i = 0; i < children.length; i++) {
    var child = children[i]
    if (!child || !child.visible || child.opacity <= 0 || child.width <= 0 || child.height <= 0) continue
    if ("acceptedButtons" in child) continue
    result.push(child)
  }
  return result
}
// The width of what an item visibly paints, from the hints Omarchy's widget
// kit exposes (glyph width, label width, painted width), falling back to the
// span of its painted children. 0 when nothing can be measured.
function inkWidth(item, depth) {
  depth = depth || 0
  if (!item || depth > 4) return 0
  var hint = positive(item, "hoverUnderlineWidth")
  if (hint > 0) return hint
  if ("glyphPaintedWidth" in item) {
    var glyph = positive(item, "glyphPaintedWidth")
    return glyph > 0 ? glyph : positive(item, "opticalSize")
  }
  if ("labelWidth" in item && !rotatedLabel(item)) {
    var label = positive(item, "labelWidth")
    if (label > 0) return label
  }
  if ("paintedWidth" in item) return positive(item, "paintedWidth")
  var children = paintedChildren(item)
  if (children.length === 1) {
    var inner = inkWidth(children[0], depth + 1)
    if (inner > 0) return inner
  }
  if (children.length > 1) {
    var left = Infinity, right = -Infinity
    for (var i = 0; i < children.length; i++) {
      left = Math.min(left, children[i].x)
      right = Math.max(right, children[i].x + children[i].width)
    }
    return Math.max(0, right - left)
  }
  return depth > 0 ? Math.max(0, item.width) : 0
}
// One highlight along the bar.
//   center     content centre along the bar
//   ink        visible content length along the bar
//   thickness  highlight size across the bar
//   pad        space between the content and the highlight's ends
//   laneStart, laneEnd  the range it must stay inside (the island or bar,
//              less the same inset it keeps from the bar's edges)
//   rounding   preferred corner radius
// Returns { start, length, radius }.
function pill(o) {
  var thickness = Math.max(0, o.thickness)
  // Anything no wider than the highlight is thick reads as an icon and gets
  // the standard square; only wider content, such as text, is padded.
  var ink = Math.max(0, o.ink)
  var length = ink <= thickness ? thickness : ink + 2 * Math.max(0, o.pad)
  var laneStart = o.laneStart, laneEnd = o.laneEnd
  var start = o.center - length / 2
  if (isFinite(laneStart) && isFinite(laneEnd) && laneEnd > laneStart) {
    if (length > laneEnd - laneStart) {
      length = laneEnd - laneStart
      start = laneStart
    } else {
      start = Math.max(laneStart, Math.min(laneEnd - length, start))
    }
  }
  return { start: start, length: length, radius: Math.max(0, Math.min(thickness / 2, o.rounding)) }
}

if (typeof module !== "undefined") module.exports = { inkWidth: inkWidth, pill: pill }
