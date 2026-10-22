// The bar's zones are Omarchy's sections (Util.barSections): left,
// centerBegin, center, centerEnd and right run along the bar in that order;
// tray holds widgets drawn inside the tray's drawer. The center box sits in
// the middle of the bar, with centerBegin and centerEnd hanging off its two
// edges (docs/behavior/layout-zones.md). Powerbar edits the five lists as
// they are, so the stock bar and Powerbar read one config the same way.
//
// Older configs come in other shapes, read here into the five lists (read):
// Powerbar's three zones with a centre anchor, an Omarchy that has only
// left, center and right, and the retired zone modes (two zones, the notch,
// and the arrangements each mode kept). An Omarchy without the new sections
// gets three lists back on every write (write), with the split kept beside
// them so the next read finds the same five.

var lists = ["left", "centerBegin", "center", "centerEnd", "right"]
var centerLists = ["centerBegin", "center", "centerEnd"]
// Keys only older configs have: their presence means the config must be read.
var legacyKeys = ["centerAnchor", "powerbarFiveZones", "powerbarZones", "powerbarZoneLayouts"]

function isObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

function idOf(entry) {
  return typeof entry === "string" ? entry : (entry && entry.id) || ""
}

function list(value) {
  return Array.isArray(value) ? value : []
}

function isList(name) { return lists.indexOf(name) >= 0 }

// The fit zone a list belongs to: the three center lists share one.
function zoneOf(name) {
  return centerLists.indexOf(name) >= 0 ? "center" : name
}

// Which side of the center a center list's widgets fold and show their dots
// on: before the box, or after it (the box's own widgets count with after).
function sideOf(name) {
  if (name === "centerBegin") return "start"
  return name === "center" || name === "centerEnd" ? "end" : ""
}

// Whether this Omarchy keeps the center's sections (Util.barSections).
function sixSections(barSections) {
  return list(barSections).indexOf("centerBegin") >= 0
}

// True when the config is not yet in the five lists and must be read first.
function needsRead(bar) {
  if (!isObject(bar) || !isObject(bar.layout)) return false
  if (legacyKeys.some(function(key) { return key in bar })) return true
  return lists.some(function(name) { return !Array.isArray(bar.layout[name]) })
}

// Where a three-list center splits: how many widgets come before the box and
// how many the box holds. The split saved beside it wins while it still fits
// its anchor; otherwise the box is the anchor alone, and without an anchor the
// whole list.
function splitOf(bar, center) {
  var anchor = typeof bar.centerAnchor === "string" ? bar.centerAnchor : ""
  var saved = bar.powerbarFiveZones
  if (isObject(saved) && Number.isInteger(saved.begin) && Number.isInteger(saved.center) &&
      saved.begin >= 0 && saved.center >= 0 && saved.begin + saved.center <= center.length &&
      (saved.center === 0 || idOf(center[saved.begin]) === anchor))
    return { begin: saved.begin, box: saved.center }
  var at = anchor ? center.findIndex(function(entry) { return idOf(entry) === anchor }) : -1
  return at < 0 ? { begin: 0, box: center.length } : { begin: at, box: 1 }
}

function holds(layout, name, key) {
  return list(layout[name]).some(function(entry) { return entry && entry.powerbarInstance === key })
}

// Groups saved against the anchored center sat in one `center` list, before
// an entry of it. Each takes the list its entry is in now; one drawn just
// before the anchor ends Left of center, one at the center's end Right of it.
function centerGroups(bar, anchored) {
  if (!anchored) return
  var layout = bar.layout, box = list(layout.center)
  var first = box.length && box[0] && box[0].powerbarInstance || ""
  list(bar.powerbarGroups).forEach(function(group) {
    if (!isObject(group) || group.section !== "center") return
    var before = typeof group.before === "string" ? group.before : ""
    if (!before) group.section = "centerEnd"
    else if (holds(layout, "centerBegin", before)) group.section = "centerBegin"
    else if (holds(layout, "centerEnd", before)) group.section = "centerEnd"
    else if (before === first) { group.section = "centerBegin"; group.before = "" }
  })
}

// The notch mode's two zones grew out of the camera: its left zone is Left of
// center now and its right zone Right of center, drawn in the Notch style.
function notchZones(bar) {
  var layout = bar.layout
  layout.centerBegin = list(layout.left).concat(layout.centerBegin)
  layout.centerEnd = list(layout.centerEnd).concat(list(layout.right))
  layout.left = []
  layout.right = []
  list(bar.powerbarGroups).forEach(function(group) {
    if (!isObject(group)) return
    if (group.section === "left") group.section = "centerBegin"
    else if (group.section === "right") group.section = "centerEnd"
  })
  bar.powerbarStyle = "notch"
}

// Any older shape into the five lists, in place. The arrangements the retired
// zone modes kept are dropped: the caller saves a copy first (zoneLayouts).
function read(bar) {
  if (!isObject(bar)) return bar
  if (!isObject(bar.layout)) bar.layout = {}
  var layout = bar.layout
  var anchored = false
  if (!("centerBegin" in layout) && !("centerEnd" in layout)) {
    var center = list(layout.center), split = splitOf(bar, center)
    layout.centerBegin = center.slice(0, split.begin)
    layout.center = center.slice(split.begin, split.begin + split.box)
    layout.centerEnd = center.slice(split.begin + split.box)
    anchored = split.box > 0 && split.box < center.length
  } else {
    anchored = !!bar.centerAnchor && list(layout.center).length > 0
  }
  lists.forEach(function(name) { if (!Array.isArray(layout[name])) layout[name] = [] })
  // A config Powerbar wrote for an Omarchy without the new sections already
  // has its groups in the five lists.
  if ("centerAnchor" in bar && !("powerbarFiveZones" in bar)) centerGroups(bar, anchored)
  if (bar.powerbarZones === "notch") notchZones(bar)
  legacyKeys.forEach(function(key) { delete bar[key] })
  return bar
}

// The arrangements of the retired zone modes, for a one-time copy, or null.
function zoneLayouts(bar) {
  return isObject(bar) && isObject(bar.powerbarZoneLayouts) ? bar.powerbarZoneLayouts : null
}

// An Omarchy without the center's sections centres one widget, its anchor:
// the box keeps its first widget and the rest lead Right of center, with the
// groups drawn among them.
function oneInBox(bar) {
  var layout = bar.layout, box = layout.center
  if (box.length < 2) return
  var moved = box.slice(1), keys = moved.map(function(entry) { return entry && entry.powerbarInstance })
  var after = layout.centerEnd.length && layout.centerEnd[0] && layout.centerEnd[0].powerbarInstance || ""
  layout.center = box.slice(0, 1)
  layout.centerEnd = moved.concat(layout.centerEnd)
  list(bar.powerbarGroups).forEach(function(group) {
    if (!isObject(group) || group.section !== "center") return
    if (keys.indexOf(group.before) >= 0) group.section = "centerEnd"
    else if (!group.before) { group.section = "centerEnd"; group.before = after }
  })
}

// The five lists back into the config, in place. An Omarchy with the center's
// sections takes them as they are. One without gets one center list, its box
// named as the anchor, and the split kept beside it for the next read.
function write(bar, six) {
  if (!isObject(bar) || !isObject(bar.layout)) return bar
  var layout = bar.layout
  lists.forEach(function(name) { if (!Array.isArray(layout[name])) layout[name] = [] })
  delete bar.centerAnchor
  delete bar.powerbarFiveZones
  if (six) return bar
  oneInBox(bar)
  var begin = layout.centerBegin, box = layout.center
  layout.center = begin.concat(box, layout.centerEnd)
  delete layout.centerBegin
  delete layout.centerEnd
  bar.centerAnchor = box.length ? idOf(box[0]) : ""
  bar.powerbarFiveZones = { begin: begin.length, center: box.length }
  return bar
}
