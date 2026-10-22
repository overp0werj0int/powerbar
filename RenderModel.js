// Shared reconciliation keeps visual lifetimes independent of JS-array replacement.
// Same keys in the same order holding the same values serialise identically,
// so the JSON comparison is only needed when something differs.
function shallowSame(a, b) {
  if (!a || !b || typeof a !== "object" || typeof b !== "object" || Array.isArray(a) !== Array.isArray(b)) return false
  var ka = Object.keys(a), kb = Object.keys(b)
  if (ka.length !== kb.length) return false
  for (var i = 0; i < ka.length; i++) if (ka[i] !== kb[i] || a[ka[i]] !== b[ka[i]]) return false
  return true
}
function equal(a, b) { return a === b || shallowSame(a, b) || JSON.stringify(a) === JSON.stringify(b) }
function sameItems(a, b) {
  if (a === b) return true
  if (!a || !b || a.length !== b.length) return false
  for (var i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
  return true
}
function reconcileLists(models, lists, parking) {
  // Release transfers from their old model before inserting into the new one.
  for (var m = 0; m < models.length; m++) {
    for (var i = models[m].count - 1; i >= 0; i--) {
      var item = models[m].get(i)
      if (lists[m].indexOf(item) >= 0) continue
      models[m].remove(i, 1)
      if (item) { item.parent = parking; item.x = 0; item.y = 0 }
    }
  }
  for (var n = 0; n < models.length; n++) {
    var model = models[n], wanted = lists[n]
    for (var at = 0; at < wanted.length; at++) {
      if (at < model.count && model.get(at) === wanted[at]) continue
      var from = -1
      for (var j = at + 1; j < model.count; j++) if (model.get(j) === wanted[at]) { from = j; break }
      if (from >= 0) model.move(from, at, 1)
      else model.insert(at, wanted[at])
    }
  }
}
// The bar's zone lists in order (SectionsModel.lists), and the zone each one
// belongs to: the three center lists share the center zone.
var lists = ["left", "centerBegin", "center", "centerEnd", "right"]
function zoneOf(list) { return list === "centerBegin" || list === "centerEnd" ? "center" : list }
// One record per entry: its zone (region), the list it is drawn in, and the
// list it is saved in (an entry of Omarchy's tray section is drawn beside the
// tray, powerbarList "tray").
function records(layout) {
  var result = []
  for (var list of lists) {
    var entries = layout && Array.isArray(layout[list]) ? layout[list] : []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (typeof entry !== "string" && (!entry || typeof entry !== "object")) continue
      var id = typeof entry === "string" ? entry : entry.id
      if (!id) continue
      var saved = typeof entry === "object" && entry.powerbarList === "tray" ? "tray" : list
      result.push({ key: entry.powerbarInstance || id + ":" + list + ":" + i, region: zoneOf(list), drawn: list, list: saved, entry: entry })
    }
  }
  return result
}
// The record keys of each list, as drawn.
function split(records) {
  var out = {}
  lists.forEach(function(list) { out[list] = [] })
  records.forEach(function(r) { out[r.drawn].push(r.key) })
  return out
}
function groupIndex(groups) {
  var byId = Object.create(null), owner = Object.create(null)
  groups.forEach(function(group) {
    byId[group.id] = group
    group.items.forEach(function(key) { owner[key] = group })
  })
  return { byId: byId, owner: owner }
}
function entryIndex(layout) {
  var index = Object.create(null)
  records(layout).forEach(function(record) { index[record.key] = record.entry })
  return index
}
// null requests all captures; [] means the captured presentation is unchanged.
function captureDelta(previous, next) {
  if (equal(previous, next)) return []
  var oldChrome = Object.assign({}, previous || {}), newChrome = Object.assign({}, next || {})
  delete oldChrome.layout; delete newChrome.layout
  // Surface alpha changes preview chrome, not the widget presentation.
  delete oldChrome.powerbarBackgroundOpacity; delete newChrome.powerbarBackgroundOpacity
  if (!equal(oldChrome, newChrome)) return null
  function indexed(layout) {
    var entries = Object.create(null), positions = Object.create(null)
    records(layout).forEach(function(r) {
      positions[r.drawn] = (positions[r.drawn] || 0) + 1
      entries[r.key] = { record: r, index: positions[r.drawn] - 1 }
    })
    return entries
  }
  var oldEntries = indexed(previous && previous.layout), newEntries = indexed(next && next.layout)
  var keys = []
  for (var key in newEntries) if (!equal(oldEntries[key], newEntries[key])) keys.push(key)
  return keys
}
if (typeof module !== "undefined") module.exports = { lists, zoneOf, equal, shallowSame, sameItems, reconcileLists, records, split, groupIndex, entryIndex, captureDelta }
