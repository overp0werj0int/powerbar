// Omarchy's bar layout has six sections: left, centerBegin, center, centerEnd,
// right, and tray (widgets drawn inside the tray's drawer). Its center box sits
// in the middle of the bar, with centerBegin and centerEnd hanging off its two
// edges; a new widget lands in centerEnd. Powerbar keeps three zones and a
// centre anchor instead: one `center` list, centred on the `centerAnchor`
// widget, with what comes before it on one side and what comes after on the
// other. The two say the same thing, so the config is read in Omarchy's shape
// and folded into Powerbar's (fold), and every write unfolds it back (unfold):
// the stock bar reads Powerbar's config correctly, and widgets Omarchy places
// in its new sections are never lost.

var omarchySections = ["centerBegin", "centerEnd", "tray"]

function isObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

function idOf(entry) {
  return typeof entry === "string" ? entry : (entry && entry.id) || ""
}

function list(value) {
  return Array.isArray(value) ? value : []
}

// True when the layout is in Omarchy's shape and must be folded first.
function needsFold(bar) {
  var layout = isObject(bar) && bar.layout
  return isObject(layout) && omarchySections.some(function(s) { return s in layout })
}

// Omarchy's shape into Powerbar's, in place: centerBegin, center and centerEnd
// become one centre list. Its anchor is the centre widget, kept as Powerbar's
// centerAnchor unless one is set already. Widgets in Omarchy's tray drawer
// become on-demand widgets beside the tray, which is what the drawer was.
function fold(bar) {
  if (!needsFold(bar)) return bar
  var layout = bar.layout
  var begin = list(layout.centerBegin), middle = list(layout.center), end = list(layout.centerEnd)
  if (!("centerAnchor" in bar) && middle.length === 1 && (begin.length || end.length)) bar.centerAnchor = idOf(middle[0])
  layout.center = begin.concat(middle, end)
  var tray = list(layout.tray).map(function(entry) {
    var copy = typeof entry === "string" ? { id: entry } : Object.assign({}, entry)
    if (!copy.powerbarVisibility) copy.powerbarVisibility = "managed"
    return copy
  })
  delete layout.centerBegin
  delete layout.centerEnd
  delete layout.tray
  if (tray.length) {
    var zones = ["left", "center", "right"], placed = false
    for (var z = 0; z < zones.length && !placed; z++) {
      var entries = list(layout[zones[z]])
      for (var i = 0; i < entries.length; i++) {
        if (idOf(entries[i]) !== "omarchy.tray") continue
        layout[zones[z]] = entries.slice(0, i + 1).concat(tray, entries.slice(i + 1))
        placed = true
        break
      }
    }
    if (!placed) layout.right = list(layout.right).concat(tray)
  }
  return bar
}

// Powerbar's shape back into Omarchy's, in place: the centre list splits at its
// anchor (before it, the anchor, after it); without one the whole list is the
// centre box. The tray drawer holds nothing: Powerbar's on-demand widgets are
// its drawers.
function unfold(bar) {
  if (!isObject(bar) || !isObject(bar.layout)) return bar
  // Already Omarchy's shape (a write that did not fold first): leave it.
  if (needsFold(bar)) return bar
  var layout = bar.layout
  var center = list(layout.center)
  var anchor = typeof bar.centerAnchor === "string" ? bar.centerAnchor : ""
  var at = -1
  for (var i = 0; anchor && i < center.length; i++) if (idOf(center[i]) === anchor) { at = i; break }
  layout.centerBegin = at < 0 ? [] : center.slice(0, at)
  layout.center = at < 0 ? center.slice() : [center[at]]
  layout.centerEnd = at < 0 ? [] : center.slice(at + 1)
  layout.tray = []
  return bar
}
