// The bar's zone mode (docs/behavior/layout-zones.md, "Zone modes"): three
// zones (left, centre, right), two zones (left and right, a gap one notch wide
// in the middle) or the notch (two zones that grow out of a camera notch).
// Pure rules on a bar config (config.bar); Bar.qml and Preferences write them.
//
// Each mode keeps its own arrangement: where each widget and group sits, in
// which order, and whether it is on the bar, on demand or hidden. Only the
// mode in use lives in bar.layout, so every edit, Omarchy's included, works
// on it unchanged; the others wait in bar.powerbarZoneLayouts. A widget's
// other settings are shared: a switch carries them over from the layout
// being left.
var MODES = ["three", "two", "notch"]
var KEYBOARD_LAYOUT = "omarchy.keyboard-layout"
var CLOCK = "omarchy.clock"

function isObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }
function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)) }

function modeOf(bar) {
  var m = bar && bar.powerbarZones
  return MODES.indexOf(m) >= 0 ? m : "three"
}
function twoZones(mode) { return mode === "two" || mode === "notch" }

function entryOf(e) { return typeof e === "string" ? { id: e } : e }
// A widget's identity across layouts: its instance key, else its id.
function keyOf(e) {
  e = entryOf(e)
  if (!e) return ""
  return e.powerbarInstance || (e.id ? "id:" + e.id : "")
}
function zones(layout) {
  var l = isObject(layout) ? layout : {}
  return {
    left: Array.isArray(l.left) ? l.left.map(entryOf) : [],
    center: Array.isArray(l.center) ? l.center.map(entryOf) : [],
    right: Array.isArray(l.right) ? l.right.map(entryOf) : []
  }
}

// Where each group sits: { id: { section, before, visibility } }.
function groupPlaces(groups) {
  var out = {}
  ;(Array.isArray(groups) ? groups : []).forEach(function(g) {
    if (!g || !g.id) return
    var p = { section: g.section, before: g.before || "" }
    if (g.visibility !== undefined) p.visibility = g.visibility
    out[g.id] = p
  })
  return out
}

// The two-zone arrangement made from a three-zone one, for a mode used the
// first time. The centre splits at its anchor (the clock when none is set):
// what comes before it joins the left zone's end, what comes after it the
// right zone's start; the keyboard layout and then the anchor end the right
// zone, beside the Preferences button. Groups move with the entry they sit
// before.
function derive(layout, groups, anchorId) {
  var z = zones(clone(layout))
  var anchorAt = z.center.findIndex(function(e) { return e && e.id === (anchorId || CLOCK) })
  if (anchorAt < 0) anchorAt = z.center.findIndex(function(e) { return e && e.id === CLOCK })
  var anchor = anchorAt >= 0 ? z.center[anchorAt] : null
  var before = anchorAt >= 0 ? z.center.slice(0, anchorAt) : []
  var after = anchorAt >= 0 ? z.center.slice(anchorAt + 1) : z.center
  // The entry after each one in the three-zone order of its zone, so a group
  // sitting before a widget that moves can follow the widget's old neighbour.
  var next = {}
  ;["left", "center", "right"].forEach(function(name) {
    var list = z[name]
    for (var i = 0; i < list.length; i++) next[keyOf(list[i])] = i + 1 < list.length ? keyOf(list[i + 1]) : ""
  })
  var keyboard = null
  var pick = function(list) {
    return list.filter(function(e) {
      if (!keyboard && e && e.id === KEYBOARD_LAYOUT) { keyboard = e; return false }
      return true
    })
  }
  after = pick(after); var right = pick(z.right); var left = pick(z.left); before = pick(before)
  var tail = (keyboard ? [keyboard] : []).concat(anchor ? [anchor] : [])
  var out = { left: left.concat(before), center: [], right: after.concat(right, tail) }

  var section = {}
  out.left.forEach(function(e) { section[keyOf(e)] = "left" })
  out.right.forEach(function(e) { section[keyOf(e)] = "right" })
  var places = groupPlaces(groups)
  var moved = {}
  var tailKey = tail.length ? keyOf(tail[0]) : ""
  var anchorKey = anchor ? keyOf(anchor) : "", keyboardKey = keyboard ? keyOf(keyboard) : ""
  Object.keys(places).forEach(function(id) {
    var p = places[id], b = p.before, q
    // Before the keyboard layout, which moved: before its old neighbour.
    while (b && b === keyboardKey) b = next[b] || ""
    if (p.section === "center" && b && b === anchorKey) q = { section: "left", before: "" }
    else if (p.section === "center" && !b) q = { section: "right", before: right.length ? keyOf(right[0]) : tailKey }
    else if (p.section === "right" && !b) q = { section: "right", before: tailKey }
    else if (p.section === "left" && !b) q = { section: "left", before: before.length ? keyOf(before[0]) : "" }
    else q = { section: section[b] || "right", before: section[b] ? b : "" }
    if (p.visibility !== undefined) q.visibility = p.visibility
    moved[id] = q
  })
  return { layout: out, groups: moved }
}

// Omarchy's stock three-zone layouts, by widget id (its centre sections read
// as one centre list, SectionsModel), and the two-zone layout made for them
// (two and notch alike) instead of derive's split: what a fresh install gets.
// The first is Omarchy's since its six sections, the second the one before.
var STOCK_THREE = [{
  left: ["omarchy.menu", "omarchy.workspaces"],
  center: ["omarchy.indicators", CLOCK, "omarchy.elsewhen", "omarchy.weather", "omarchy.system-update"],
  right: ["omarchy.tray", KEYBOARD_LAYOUT, "omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.monitor", "omarchy.power"]
}, {
  left: ["omarchy.menu", "omarchy.workspaces"],
  center: ["omarchy.indicators", CLOCK, KEYBOARD_LAYOUT, "omarchy.weather", "omarchy.system-update"],
  right: ["omarchy.tray", "omarchy.agents", "omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.monitor", "omarchy.power"]
}]
var STOCK_TWO = {
  left: ["omarchy.menu", "omarchy.workspaces", "omarchy.indicators",
    { id: "omarchy.system-update", powerbarVisibility: "shown" },
    { id: "omarchy.weather", powerbarVisibility: "shown" },
    { id: "omarchy.elsewhen", powerbarVisibility: "shown" },
    { id: "omarchy.agents", powerbarVisibility: "shown" }],
  right: ["omarchy.bluetooth", "omarchy.network", "omarchy.audio", "omarchy.power",
    { id: "omarchy.monitor", powerbarVisibility: "shown" }, KEYBOARD_LAYOUT, CLOCK,
    { id: "omarchy.tray", powerbarVisibility: "shown" }]
}

// Whether a three-zone layout is still Omarchy's stock one: the same widgets
// in the same zones and order, one of each, and no groups.
function isStock(layout, groups) {
  if (Object.keys(groupPlaces(groups)).length) return false
  var z = zones(layout)
  return STOCK_THREE.some(function(stock) {
    return ["left", "center", "right"].every(function(name) {
      var ids = z[name].map(function(e) { return e && e.id })
      return JSON.stringify(ids) === JSON.stringify(stock[name])
    })
  })
}

// The stock two-zone layout of the widgets `layout` has, carrying each one's
// instance key so the switch finds it.
function stockTwo(layout) {
  var key = {}, z = zones(layout)
  ;["left", "center", "right"].forEach(function(name) {
    z[name].forEach(function(e) { if (e && e.id) key[e.id] = keyOf(e) })
  })
  var make = function(spec) {
    var e = clone(entryOf(spec))
    if (key[e.id] && key[e.id] !== "id:" + e.id) e.powerbarInstance = key[e.id]
    return e
  }
  var has = function(spec) { return entryOf(spec).id in key }
  return { layout: { left: STOCK_TWO.left.filter(has).map(make), center: [], right: STOCK_TWO.right.filter(has).map(make) }, groups: {} }
}

// A widget the layout being entered does not know (added while another mode
// was in use): two zones have no centre, so a centre widget joins the right
// zone; the notch's zones grow outward, so a new widget takes the end
// farthest from the notch (the left zone's start).
// `added` is [{ entry, section }] in bar order; they keep that order.
function placeNew(z, added, mode) {
  var front = []
  added.forEach(function(a) {
    var name = twoZones(mode) && a.section === "center" ? "right" : a.section
    if (mode === "notch" && name === "left") front.push(a.entry)
    else z[name].push(a.entry)
  })
  z.left = front.concat(z.left)
}

// Switch the bar to another mode, in place. Returns false when it is in that
// mode already.
function switchMode(bar, target) {
  if (!isObject(bar) || MODES.indexOf(target) < 0) return false
  var current = modeOf(bar)
  if (current === target) return false
  var store = isObject(bar.powerbarZoneLayouts) ? clone(bar.powerbarZoneLayouts) : {}
  store[current] = { layout: clone(bar.layout) || {}, groups: groupPlaces(bar.powerbarGroups) }

  var saved = isObject(store[target]) ? store[target] : null
  if (!saved && twoZones(target)) {
    var three = current === "three" ? store.three : (isObject(store.three) ? store.three : store[current])
    var threeGroups = three.groups ? Object.keys(three.groups).map(function(id) {
      return Object.assign({ id: id }, three.groups[id])
    }) : []
    saved = isStock(three.layout, threeGroups) ? stockTwo(three.layout)
      : derive(three.layout, threeGroups, bar.centerAnchor || CLOCK)
  }
  if (!saved) saved = { layout: clone(bar.layout), groups: groupPlaces(bar.powerbarGroups) }

  // The widgets as they are now, by identity: their settings travel.
  var live = zones(bar.layout), now = {}
  ;["left", "center", "right"].forEach(function(name) {
    live[name].forEach(function(e) { now[keyOf(e)] = { entry: e, section: name } })
  })
  var incoming = zones(saved.layout), seen = {}
  var z = { left: [], center: [], right: [] }
  ;["left", "center", "right"].forEach(function(name) {
    var dest = twoZones(target) && name === "center" ? "right" : name
    incoming[name].forEach(function(e) {
      var k = keyOf(e), cur = now[k]
      if (!k || !cur || seen[k]) return
      seen[k] = true
      var entry = clone(cur.entry)
      if (e.powerbarVisibility !== undefined) entry.powerbarVisibility = e.powerbarVisibility
      else delete entry.powerbarVisibility
      z[dest].push(entry)
    })
  })
  var added = []
  ;["left", "center", "right"].forEach(function(name) {
    live[name].forEach(function(e) {
      var k = keyOf(e)
      if (k && !seen[k]) { seen[k] = true; added.push({ entry: clone(e), section: name }) }
    })
  })
  placeNew(z, added, target)
  bar.layout = Object.assign(isObject(bar.layout) ? bar.layout : {}, z)

  var places = isObject(saved.groups) ? saved.groups : {}
  if (Array.isArray(bar.powerbarGroups)) {
    bar.powerbarGroups.forEach(function(g) {
      if (!g || !g.id) return
      var p = places[g.id]
      if (p) {
        g.section = p.section; g.before = p.before || ""
        if (p.visibility !== undefined) g.visibility = p.visibility
        else delete g.visibility
      } else if (twoZones(target) && g.section === "center") {
        g.section = "right"; g.before = ""
      }
    })
  }

  delete store[target]
  if (Object.keys(store).length) bar.powerbarZoneLayouts = store
  else delete bar.powerbarZoneLayouts
  if (target === "three") delete bar.powerbarZones
  else bar.powerbarZones = target
  return true
}

// Entries added to bar.layout by another writer (Omarchy adds a newly
// installed widget, without an instance key, at its zone's end): in two-zone
// modes a centre one moves to the right zone, and on the notch a new left one
// takes the far end. `isNew(entry)` names them. Returns whether any moved.
function settleNew(bar, isNew) {
  var mode = modeOf(bar)
  if (!twoZones(mode) || !isObject(bar.layout)) return false
  var z = zones(bar.layout), moved = false
  var keep = { left: [], center: [], right: z.right.slice() }
  var fresh = []
  ;["left", "center"].forEach(function(name) {
    z[name].forEach(function(e) {
      if (name === "center" || (mode === "notch" && isNew(e))) { fresh.push({ entry: e, section: name }); moved = true }
      else keep[name].push(e)
    })
  })
  if (!moved) return false
  placeNew(keep, fresh, mode)
  var order = function(l) { return JSON.stringify(l.left.concat(["|"], l.center, ["|"], l.right)) }
  if (order(keep) === order(z)) return false
  bar.layout.left = keep.left; bar.layout.center = []; bar.layout.right = keep.right
  return true
}
