// Omarchy's tray icons as bar entries (docs/behavior/layout.md, TRAY-*). An
// icon moved out of the tray becomes an entry of its own,
//   { id: "powerbar.tray.<app>", type: "trayItem", item: "<tray id>", title: "<name>" }
// placed, shown, put on demand, hidden or grouped like any widget. The tray
// stops drawing it: its id joins the tray's own hidden list in the same write.
// Moving it back removes the entry and takes the id off that list again,
// unless the tray hid it before it ever moved (trayHidden). Omarchy's own bar
// draws nothing for a type it does not know, and its tray's Manage popup still
// lists the icon as hidden, so nothing is lost when Powerbar is off.

var type = "trayItem"
var trayId = "omarchy.tray"
var zones = ["left", "center", "right"]

function isObject(value) { return !!value && typeof value === "object" && !Array.isArray(value) }
function idOf(entry) { return typeof entry === "string" ? entry : (entry && entry.id) || "" }
function list(value) { return Array.isArray(value) ? value : [] }
function text(value) { return String(value || "").toLowerCase() }
// The tray's items: a QML list, which is array-like but not an Array.
function itemsOf(value) {
  return value && typeof value === "object" && typeof value.length === "number" ? Array.prototype.slice.call(value) : []
}

function isTrayEntry(entry) { return isObject(entry) && entry.type === type }

// A stable widget id for an icon: its tray id, cut to letters, digits, - and _.
function entryIdFor(itemId) {
  var name = String(itemId || "").replace(/[^A-Za-z0-9_-]+/g, "-").replace(/^-+|-+$/g, "")
  return "powerbar.tray." + (name || "item")
}

// The tray's name for an icon, as its tooltip shows it.
function titleOf(item) {
  return item ? String(item.tooltipTitle || item.title || item.id || "") : ""
}

// Icons the tray never draws (Omarchy's TrayModel.ownedByOmarchy): LocalSend,
// which has its own widget and a fresh tray id every launch, and apps whose
// Omarchy widget is on the bar.
var ownedByWidget = [
  { widget: "omarchy.dropbox", item: "dropbox" },
  { widget: "superwhisper.panel", item: "superwhisper" }
]
function named(item, name) {
  return text(item.id).indexOf(name) >= 0 || text(item.title).indexOf(name) >= 0 || text(item.tooltipTitle).indexOf(name) >= 0
}
function ownedByOmarchy(item, layout) {
  if (named(item, "localsend")) return true
  return ownedByWidget.some(function(owner) {
    return named(item, owner.item) && zones.some(function(zone) {
      return list(layout && layout[zone]).some(function(entry) { return idOf(entry) === owner.widget })
    })
  })
}

// The tray icon an entry stands for: the one with its tray id, or, for an app
// that picks a new id each launch, the one with its name.
function find(items, settings) {
  var values = itemsOf(items)
  var id = String(settings && settings.item || "")
  var title = text(settings && settings.title)
  for (var i = 0; i < values.length; i++) if (values[i] && String(values[i].id || "") === id) return values[i]
  if (!title) return null
  for (var j = 0; j < values.length; j++) if (values[j] && text(titleOf(values[j])) === title) return values[j]
  return null
}

// The entries of a layout that stand for tray icons.
function entries(layout) {
  var result = []
  zones.forEach(function(zone) { list(layout && layout[zone]).forEach(function(e) { if (isTrayEntry(e)) result.push(e) }) })
  return result
}

// The icons still in the tray, as Preferences rows: not passive (the tray does
// not draw those either), not drawn by Omarchy's own widgets, not moved out.
// `passive` is the tray's Status.Passive value.
function trayRows(items, layout, passive) {
  var moved = entries(layout)
  return itemsOf(items).filter(function(item) {
    return item && item.status !== passive && !ownedByOmarchy(item, layout)
      && !moved.some(function(e) { return find([item], e) === item })
  }).map(function(item, index) {
    var id = String(item.id || "")
    return { id: entryIdFor(id), trayItem: id, trayTitle: titleOf(item), instanceKey: "tray:" + id,
      section: "tray", mode: "tray", index: index, fingerprint: "tray:" + id }
  })
}

// Every tray entry in the layout, so one hidden list can be edited for all.
function trayEntries(layout) {
  var result = []
  zones.forEach(function(zone) {
    var values = list(layout && layout[zone])
    for (var i = 0; i < values.length; i++) {
      if (idOf(values[i]) !== trayId) continue
      if (typeof values[i] === "string") values[i] = { id: trayId }
      result.push(values[i])
    }
  })
  return result
}
function hiddenIn(tray) { return list(tray && tray.hidden).map(String) }

// Moves an icon out of the tray into `section` with `visibility`, before the
// entry with instance `beforeKey` (or at the zone's end). `key` is the new
// entry's instance key. Returns the new entry, or null when nothing changed.
function moveOut(config, item, section, visibility, beforeKey, key) {
  var layout = config && config.bar && config.bar.layout
  var id = String(item && item.id || "")
  if (!isObject(layout) || !id || zones.indexOf(section) < 0
      || ["shown", "managed", "hidden"].indexOf(visibility) < 0) return null
  if (entries(layout).some(function(e) { return String(e.item) === id })) return null
  var trays = trayEntries(layout)
  var entry = { id: entryIdFor(id), type: type, item: id, title: titleOf(item), powerbarVisibility: visibility }
  if (trays.some(function(t) { return hiddenIn(t).indexOf(id) >= 0 })) entry.trayHidden = true
  if (key) entry.powerbarInstance = key
  if (!Array.isArray(layout[section])) layout[section] = []
  var to = layout[section]
  var at = beforeKey ? to.findIndex(function(e) { return e && e.powerbarInstance === beforeKey }) : -1
  to.splice(at < 0 ? to.length : at, 0, entry)
  trays.forEach(function(tray) {
    var hidden = hiddenIn(tray)
    if (hidden.indexOf(id) < 0) hidden.push(id)
    tray.hidden = hidden
    // The tray pins and hides exclusively (Tray.qml toggleHide).
    if (Array.isArray(tray.pinned)) tray.pinned = tray.pinned.filter(function(p) { return String(p) !== id })
  })
  return entry
}

// Puts the icon of the entry with instance `key` back in the tray. Returns
// true when it moved.
function moveBack(config, key) {
  var layout = config && config.bar && config.bar.layout
  if (!isObject(layout) || !key) return false
  var entry = null
  zones.forEach(function(zone) {
    var values = list(layout[zone])
    var at = values.findIndex(function(e) { return isTrayEntry(e) && e.powerbarInstance === key })
    if (at >= 0) entry = values.splice(at, 1)[0]
  })
  if (!entry) return false
  var id = String(entry.item || "")
  // Another entry for the same icon keeps it out of the tray.
  var still = entries(layout).some(function(e) { return String(e.item) === id })
  if (!entry.trayHidden && !still) trayEntries(layout).forEach(function(tray) {
    if (Array.isArray(tray.hidden)) tray.hidden = tray.hidden.filter(function(h) { return String(h) !== id })
  })
  return true
}
