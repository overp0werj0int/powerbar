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
// A button from Omarchy's widget kit: an icon button or a labelled one.
function isKitButton(item) {
  return !!item && (("glyphPaintedWidth" in item && "glyphFontSize" in item)
    || ("labelWidth" in item && "fontSize" in item && "text" in item))
}
// Badges a widget draws over its one kit button (an unread dot, a count) sit
// inside the button's box. Omarchy's bar centres that box, so the glyph sits
// centred and the badge rides on it: the badge is decoration, not content,
// and measuring it would push the glyph off the bar's centre line.
function withoutBadges(children) {
  var hosts = children.filter(isKitButton)
  if (hosts.length !== 1 || children.length < 2) return children
  var h = hosts[0], slack = 0.5
  return children.filter(function(c) {
    return c === h || !(c.x >= h.x - slack && c.y >= h.y - slack
      && c.x + c.width <= h.x + h.width + slack && c.y + c.height <= h.y + h.height + slack)
  })
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
// A plain fill behind a widget's content (its own tint or pill), spanning
// nearly its whole box, is background, not ink: counting it would make the cell
// jump whenever the widget shows or hides it.
function isBackground(child, item, vertical) {
  if (!("color" in child) || !("radius" in child) || "labelWidth" in child || "glyphPaintedWidth" in child) return false
  if (child.children && child.children.length > 0) return false
  var size = vertical ? item.height : item.width
  var at = vertical ? child.y : child.x, length = vertical ? child.height : child.width
  return at <= 4 && at + length >= size - 4
}
// A child's ink, cut to the child's own box when it clips its painting (the
// tray hides its closed drawer by sliding the icons out of a clipped strip).
function clippedInk(child, vertical, depth) {
  var part = inkRect(child, vertical, depth)
  if (!child.clip) return part
  var size = vertical ? child.height : child.width
  var lo = Math.max(0, part.start), hi = Math.min(size, part.start + part.length)
  return hi > lo ? { start: lo, length: hi - lo, glyph: part.glyph } : { start: 0, length: 0, glyph: false }
}
// The span of the non-empty text an item draws as its own direct children
// (a count beside a drawn icon), or null.
function textBeside(item) {
  var lo = Infinity, hi = -Infinity
  var children = paintedChildren(item)
  for (var i = 0; i < children.length; i++) {
    var c = children[i]
    if (!("paintedWidth" in c) || typeof c.text !== "string" || c.text.trim() === "") continue
    var painted = positive(c, "paintedWidth")
    if (!(painted > 0)) continue
    // Text.AlignRight is 2, Text.AlignHCenter 4.
    var at = c.x + (c.horizontalAlignment === 4 ? (c.width - painted) / 2 : c.horizontalAlignment === 2 ? c.width - painted : 0)
    lo = Math.min(lo, at)
    hi = Math.max(hi, at + painted)
  }
  return hi > lo ? { start: lo, end: hi } : null
}
// Where an item visibly paints along one axis, relative to the item:
// { start, length, glyph }. Kit widgets centre their glyph or label in their
// box, so hints give a centred span; otherwise the span of painted children.
// `glyph` marks what reads as an icon (the kit's glyph hint, or at most 16 px
// of ink across). Falls back to the whole item when nothing can be measured.
function inkRect(item, vertical, depth) {
  depth = depth || 0
  var size = item ? (vertical ? item.height : item.width) : 0
  if (!item || depth > 4) return { start: 0, length: Math.max(0, size), glyph: false }
  var centred = function(length, glyph) {
    length = Math.min(Math.max(0, length), Math.max(0, size))
    return { start: (size - length) / 2, length: length, glyph: glyph }
  }
  var across = inkWidth(item, 0)
  if ("glyphPaintedWidth" in item) {
    // A custom icon (iconComponent, Omapop's drawn mark) with no label is an
    // icon, whatever its canvas: it paints the canvas the kit sizes for icons.
    if (item.iconComponent && String(item.labelText || "") === "") {
      var canvas = positive(item, "componentPaintedWidth") || positive(item, "opticalSize") || size
      var icon = centred(Math.min(canvas, size), true)
      // Text it draws beside the icon as a child of its own (omabox's count)
      // is ink too, so its cell makes room for it; iconStart/iconLength keep
      // the icon's own span for a menu row's icon cell.
      var beside = vertical ? null : textBeside(item)
      if (!beside) return icon
      var from = Math.min(icon.start, beside.start), to = Math.max(icon.start + icon.length, beside.end)
      return { start: from, length: to - from, glyph: true, iconStart: icon.start, iconLength: icon.length }
    }
    // The kit's icon button can carry a whole string ("100% 󰁹"); only a
    // painted width no wider than a large glyph reads as an icon.
    var painted = across > 0 ? across : Math.min(size, positive(item, "opticalSize") || size)
    if (!vertical) return centred(painted, painted <= 16)
    return centred(Math.min(size, positive(item, "opticalSize") || size), painted <= 16)
  }
  if (!vertical) {
    var hint = positive(item, "hoverUnderlineWidth")
    if (hint > 0) return centred(hint, hint <= 16)
    if ("labelWidth" in item && !rotatedLabel(item) && positive(item, "labelWidth") > 0)
      return centred(positive(item, "labelWidth"), false)
    if ("paintedWidth" in item && positive(item, "paintedWidth") > 0)
      return centred(positive(item, "paintedWidth"), positive(item, "paintedWidth") <= 16)
  } else if ("labelWidth" in item && "scaledVerticalPadding" in item && positive(item, "labelWidth") > 0) {
    return centred(size - 2 * positive(item, "scaledVerticalPadding"), across > 0 && across <= 16)
  }
  var children = withoutBadges(paintedChildren(item))
  if (children.length === 1) {
    var inner = clippedInk(children[0], vertical, depth + 1)
    var offset = vertical ? children[0].y : children[0].x
    if (inner.length > 0) return { start: offset + inner.start, length: inner.length, glyph: inner.glyph }
  }
  if (children.length > 1) {
    // The span of what each child paints (a workspace button's digit, not its
    // 20 px box).
    var content = children.filter(function(c) { return !isBackground(c, item, vertical) })
    if (content.length > 0) children = content
    var lo = Infinity, hi = -Infinity
    for (var i = 0; i < children.length; i++) {
      var c = children[i]
      var part = clippedInk(c, vertical, depth + 1)
      if (!(part.length > 0)) continue
      var at = (vertical ? c.y : c.x) + part.start
      lo = Math.min(lo, at)
      hi = Math.max(hi, at + part.length)
    }
    if (hi > lo) return { start: lo, length: hi - lo, glyph: false }
    return { start: 0, length: Math.max(0, size), glyph: false }
  }
  if (depth > 0) return { start: 0, length: Math.max(0, size), glyph: size > 0 && size <= 16 }
  return { start: 0, length: Math.max(0, size), glyph: false }
}
// The kit's drawn-icon loaders that left their icon no size (INTEG-156): a
// kit icon button draws an `iconComponent` in a Loader of no size of its own
// (BarIconContent) and gives the loaded item the canvas only when the item
// has no width; an item that fills its parent (`anchors.fill: parent`, as
// Omapop's mark does) is held at the Loader's zero size and paints nothing,
// on any bar. Returns [{ loader, content }] for each such Loader in the
// widget, content (its BarIconContent) holding the canvas the kit meant to
// give as `sourceSize`.
function unsizedIconLoaders(item) {
  var out = [], stack = [item], seen = 0
  while (stack.length && seen < 400) {
    var node = stack.pop()
    seen++
    if (!node) continue
    var kids = node.children || []
    if ("sourceComponent" in node && "sourceSize" in node && "contentScale" in node) {
      for (var i = 0; i < kids.length; i++) {
        var loader = kids[i]
        if (!loader || !("item" in loader) || !("sourceComponent" in loader)) continue
        var icon = loader.item
        if (!icon || !icon.anchors || icon.anchors.fill !== loader) continue
        if (loader.width > 0 && loader.height > 0) continue
        if (positive(node, "sourceSize") > 0) out.push({ loader: loader, content: node })
      }
      continue
    }
    for (var k = kids.length - 1; k >= 0; k--) stack.push(kids[k])
  }
  return out
}
// Whether an item paints a picture and no text: an image (Reprieve's mark, an
// app icon) with at most shapes beside it (a status dot). Such a widget reads
// as an icon wherever its ink fits an icon cell, even past the 16 px of a
// glyph.
function picture(item, depth) {
  depth = depth || 0
  var seen = { image: false, text: false }
  var walk = function(node, level) {
    if (!node || level > 6 || seen.text) return
    if ("font" in node && String(node.text || "") !== "") { seen.text = true; return }
    if ("sourceSize" in node && "fillMode" in node && String(node.source || "") !== "") seen.image = true
    paintedChildren(node).forEach(function(child) { walk(child, level + 1) })
  }
  walk(item, depth)
  return seen.image && !seen.text
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

if (typeof module !== "undefined") module.exports = { inkWidth: inkWidth, inkRect: inkRect, unsizedIconLoaders: unsizedIconLoaders, picture: picture, pill: pill, withoutBadges: withoutBadges }
