// The Groups page (docs/behavior/preferences.md PREFS-109 on): a rail of the
// bar's five zones holding every group's face, a drawer hanging under each
// face, and the pool of widgets in no group. Pure decisions only; the page
// (GroupsEditor.qml) carries them out.
//
// A place the cursor can rest on:
//   { area: "rail", zone, slot }   slot indexes the zone's faces; the slot
//                                  after the last is the zone's "+"
//   { area: "drawer", id, pos }    a member of group `id` (pos 0 of an
//                                  empty drawer is a resting place too)
//   { area: "pool", pos }          a chip of the pool
// A place a lifted widget can land on:
//   { area: "drawer", id, pos }    before member `pos` (pos = count: the end)
//   { area: "pool" }               out of every group
//   { area: "plus", zone }         a new group in that zone
//   { area: "face", id }           (pointer only) the end of that group
// The layout state the steps read, `s`:
//   zones: the zone lists in bar order; faces: { zone: [group ids in bar
//   order] }; members: { id: count } (without a lifted widget while one is
//   lifted); pool: the pool's chip count; perRow: chips in a pool row;
//   chosen: the chosen group's id.

var visibilities = ["shown", "managed", "hidden"]

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

// Groups as GroupsModel.render should place them on the rail: a hidden
// group is not on the bar, but its face keeps the place it would have.
function railGroups(groups) {
  return (groups || []).map(function(g) {
    return g.visibility === "hidden" ? Object.assign({}, g, { visibility: "shown" }) : g
  })
}
// Each zone's group ids in bar order, from GroupsModel.render(layout,
// railGroups(groups)).
function railFaces(rendered, zones) {
  var out = {}
  zones.forEach(function(zone) {
    out[zone] = ((rendered && rendered[zone]) || []).filter(function(e) {
      return e && e.type === "group" && e.powerbarGroupId
    }).map(function(e) { return e.powerbarGroupId })
  })
  return out
}
// The drawers in rail order, left to right.
function drawerOrder(faces, zones) {
  var out = []
  zones.forEach(function(zone) { out = out.concat(faces[zone] || []) })
  return out
}
// Where each group's drawer hangs: its zone, its place among the zone's
// groups and how many share the zone's column.
function drawerSlots(faces, zones) {
  var out = {}
  zones.forEach(function(zone) {
    var list = faces[zone] || []
    list.forEach(function(id, i) { out[id] = { zone: zone, index: i, count: list.length } })
  })
  return out
}
// The rail's columns among the Layout page's seven (PreferencesModel.
// layerColumns): the label first, then the zones. With a camera its column
// (the middle one) stays empty so the cap shows through, and Center takes the
// column on the side powerbarCenterSide names; with Center left of the
// camera the label moves to the last column to make room.
function railColumns(camera, centerSide) {
  if (!camera) return { label: 0, left: 1, centerBegin: 2, center: 3, centerEnd: 4, right: 5 }
  if (centerSide === "left") return { label: 6, left: 0, centerBegin: 1, center: 2, centerEnd: 4, right: 5 }
  return { label: 0, left: 1, centerBegin: 2, center: 4, centerEnd: 5, right: 6 }
}
// Every stop of the rail, left to right: each zone's faces, then its "+".
function railStops(faces, zones) {
  var out = []
  zones.forEach(function(zone) {
    var list = faces[zone] || []
    for (var i = 0; i <= list.length; i++) out.push({ area: "rail", zone: zone, slot: i, id: i < list.length ? list[i] : "" })
  })
  return out
}
// A group's face on the rail, or null.
function facePlace(s, id) {
  for (var z = 0; z < s.zones.length; z++) {
    var i = (s.faces[s.zones[z]] || []).indexOf(id)
    if (i >= 0) return { area: "rail", zone: s.zones[z], slot: i }
  }
  return null
}
// The group a place belongs to: a face's or a member's; "" elsewhere.
function groupAt(s, at) {
  if (!at) return ""
  if (at.area === "drawer") return at.id
  if (at.area === "rail") return (s.faces[at.zone] || [])[at.slot] || ""
  return ""
}
function lastPos(s, id) { return Math.max(0, (s.members[id] || 0) - 1) }
function zoneOfGroup(s, id) {
  var at = facePlace(s, id)
  return at ? at.zone : ""
}

// The cursor's step (no lift): h/l (dx) and j/k (dy).
// Rail: h/l walk every face and "+" across the zones; j goes into the face's
// drawer, or from a "+" to the pool. Drawer: j/k walk the members, k from
// the first back to the face, j past the last to the pool; h/l the same row
// in the drawer before or after. Pool: h/l along, j/k by rows (perRow); k
// from the first row goes up to the chosen group's drawer, at its last member.
function step(s, at, dx, dy) {
  if (!at) return firstPlace(s)
  if (at.area === "rail") {
    if (dx) {
      var stops = railStops(s.faces, s.zones)
      var i = stops.findIndex(function(p) { return p.zone === at.zone && p.slot === at.slot })
      var next = stops[clamp((i < 0 ? 0 : i) + dx, 0, stops.length - 1)]
      return { area: "rail", zone: next.zone, slot: next.slot }
    }
    if (dy > 0) {
      var id = groupAt(s, at)
      return id ? { area: "drawer", id: id, pos: 0 } : { area: "pool", pos: 0 }
    }
    return at
  }
  if (at.area === "drawer") {
    if (dx) {
      var order = drawerOrder(s.faces, s.zones), k = order.indexOf(at.id)
      var to = order[clamp(k + dx, 0, order.length - 1)]
      return to ? { area: "drawer", id: to, pos: clamp(at.pos, 0, lastPos(s, to)) } : at
    }
    if (dy > 0) return at.pos < (s.members[at.id] || 0) - 1 ? { area: "drawer", id: at.id, pos: at.pos + 1 } : { area: "pool", pos: 0 }
    if (dy < 0) return at.pos > 0 ? { area: "drawer", id: at.id, pos: at.pos - 1 } : facePlace(s, at.id) || at
    return at
  }
  // The pool.
  var n = s.pool || 0, per = Math.max(1, s.perRow || 1), pos = clamp(at.pos, 0, Math.max(0, n - 1))
  if (dx) return { area: "pool", pos: clamp(pos + dx, 0, Math.max(0, n - 1)) }
  if (dy > 0) {
    if (pos + per <= n - 1) return { area: "pool", pos: pos + per }
    if (Math.floor(pos / per) < Math.floor((n - 1) / per)) return { area: "pool", pos: n - 1 }
    return { area: "pool", pos: pos }
  }
  if (dy < 0) {
    if (pos - per >= 0) return { area: "pool", pos: pos - per }
    var up = s.chosen && facePlace(s, s.chosen) ? s.chosen : drawerOrder(s.faces, s.zones)[0]
    return up ? { area: "drawer", id: up, pos: lastPos(s, up) } : railStops(s.faces, s.zones).map(strip)[0]
  }
  return { area: "pool", pos: pos }
}
function strip(p) { return { area: "rail", zone: p.zone, slot: p.slot } }
// Where the cursor starts: the chosen group's face, else the rail's first stop.
function firstPlace(s) {
  return (s.chosen && facePlace(s, s.chosen)) || strip(railStops(s.faces, s.zones)[0])
}
// A place kept valid after the layout changed under it: a gone group's
// drawer gives way to the chosen face, positions are clamped.
function normalize(s, at) {
  if (!at) return firstPlace(s)
  if (at.area === "drawer") {
    if (!facePlace(s, at.id)) return firstPlace(s)
    return { area: "drawer", id: at.id, pos: clamp(at.pos, 0, lastPos(s, at.id)) }
  }
  if (at.area === "rail") {
    if (s.zones.indexOf(at.zone) < 0) return firstPlace(s)
    return { area: "rail", zone: at.zone, slot: clamp(at.slot, 0, (s.faces[at.zone] || []).length) }
  }
  return { area: "pool", pos: clamp(at.pos, 0, Math.max(0, (s.pool || 0) - 1)) }
}

// A lifted widget's landing place, stepped with h/l and j/k through the
// drawers, the pool and the rail's "+" slots (s.members without the lifted
// widget, so a drawer offers count + 1 places). Drawer: j/k along it, past
// its end to the pool, before its first up to its zone's "+"; h/l the same
// place in the next drawer. Pool: k up to `home` (the drawer it came from or
// last went through, else the chosen group's), at its end. "+": h/l the next
// zone's, j down into the zone's first drawer, else the pool.
function stepLift(s, t, dx, dy, home) {
  if (!t) return { area: "pool" }
  var order = drawerOrder(s.faces, s.zones)
  if (t.area === "drawer") {
    var n = s.members[t.id] || 0
    if (dx) {
      var to = order[clamp(order.indexOf(t.id) + dx, 0, order.length - 1)]
      return to ? { area: "drawer", id: to, pos: clamp(t.pos, 0, s.members[to] || 0) } : t
    }
    if (dy > 0) return t.pos < n ? { area: "drawer", id: t.id, pos: t.pos + 1 } : { area: "pool" }
    if (dy < 0) return t.pos > 0 ? { area: "drawer", id: t.id, pos: t.pos - 1 } : { area: "plus", zone: zoneOfGroup(s, t.id) || s.zones[0] }
    return t
  }
  if (t.area === "plus") {
    if (dx) return { area: "plus", zone: s.zones[clamp(s.zones.indexOf(t.zone) + dx, 0, s.zones.length - 1)] }
    if (dy > 0) {
      var first = (s.faces[t.zone] || [])[0]
      return first ? { area: "drawer", id: first, pos: 0 } : { area: "pool" }
    }
    return t
  }
  if (t.area === "pool" && dy < 0) {
    var up = home && order.indexOf(home) >= 0 ? home : s.chosen && order.indexOf(s.chosen) >= 0 ? s.chosen : order[0]
    return up ? { area: "drawer", id: up, pos: s.members[up] || 0 } : { area: "plus", zone: s.zones[s.zones.length - 1] }
  }
  return t
}
// Where a lift starts: a member at its own place, a pool chip in the pool.
function liftStart(at) {
  return at && at.area === "drawer" ? { area: "drawer", id: at.id, pos: at.pos } : { area: "pool" }
}
// What a drop does. lifted: { key, group } (the group it is in, "" in the
// pool) or { face: id, zone } for a face dragged along the rail; target: a
// landing place, or for a face { area: "zone", zone }. into: the target
// drawer's member keys without the lifted widget.
//   { op: "assign", key, id, before }  into group id ("" takes it out), before
//                                      member key `before` ("" at the end)
//   { op: "create", key, zone }        a new group in zone, the widget its first member
//   { op: "zone", id, zone }           the group's face to another zone (its end)
//   { op: "none" }
function dropAction(lifted, target, into, ownPos) {
  if (!lifted || !target) return { op: "none" }
  if (lifted.face) {
    if (target.area !== "zone" || !target.zone || target.zone === lifted.zone) return { op: "none" }
    return { op: "zone", id: lifted.face, zone: target.zone }
  }
  if (target.area === "pool") return lifted.group ? { op: "assign", key: lifted.key, id: "", before: "" } : { op: "none" }
  if (target.area === "plus") return { op: "create", key: lifted.key, zone: target.zone }
  if (target.area === "face") return target.id === lifted.group ? { op: "none" } : { op: "assign", key: lifted.key, id: target.id, before: "" }
  if (target.area === "drawer") {
    if (target.id === lifted.group && target.pos === ownPos) return { op: "none" }
    var list = into || []
    return { op: "assign", key: lifted.key, id: target.id, before: target.pos < list.length ? list[target.pos] : "" }
  }
  return { op: "none" }
}

// Shift with j or k on a face: its visibility one step down (j) or up (k)
// in On the bar, On demand, Hidden; "" at either end.
function nextVisibility(v, dy) {
  var i = visibilities.indexOf(v)
  if (i < 0 || !dy) return ""
  var n = i + (dy > 0 ? 1 : -1)
  return n >= 0 && n < visibilities.length ? visibilities[n] : ""
}
// Shift with h or l on a face: the next zone, "" past either end.
function nextZone(zones, zone, dx) {
  var i = zones.indexOf(zone)
  if (i < 0 || !dx) return ""
  var n = i + (dx > 0 ? 1 : -1)
  return n >= 0 && n < zones.length ? zones[n] : ""
}

// The pool: the widgets in no group, filtered by `query` (a part of the
// title or the id, any case), in bar order zone by zone. grouped(key) tells
// a member; title(record) its name.
function poolItems(entries, zones, grouped, query, title) {
  var q = String(query || "").trim().toLowerCase()
  return (entries || []).filter(function(e) {
    if (!e || zones.indexOf(e.section) < 0 || grouped(e.instanceKey)) return false
    return !q || String(title(e)).toLowerCase().indexOf(q) >= 0 || String(e.id).toLowerCase().indexOf(q) >= 0
  }).sort(function(a, b) {
    return zones.indexOf(a.section) - zones.indexOf(b.section) || a.index - b.index
  })
}
// How many chips of `chip` width fit a row `width` wide, `gap` apart.
function perRow(width, chip, gap) {
  return Math.max(1, Math.floor((width + gap) / Math.max(1, chip + gap)))
}

// The page's bands below the rail (PREFS-106 rules, PREFS-113): room is the
// page under the header's band down to the bottom band; fixed is what the
// rail and the gaps take; the pool asks for poolSeen (its label and rows, as
// seen on its tilted plate) and needs poolFloorSeen (its label and one row).
// The pool gets what it asks for up to a third of what is left, never less
// than its floor; the drawers' band gets the rest, never less than
// drawerFloor (a header and one row). Returns { poolSeen, drawers }.
function shareBands(room, fixed, poolSeen, poolFloorSeen, drawerFloor) {
  var avail = Math.max(0, room - fixed)
  var pool = Math.max(poolFloorSeen, Math.min(poolSeen, avail / 3))
  return { poolSeen: pool, drawers: Math.max(drawerFloor, avail - pool) }
}
