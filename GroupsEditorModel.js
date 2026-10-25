// The Groups page (docs/behavior/preferences.md PREFS-109 on): the Layout
// page's plates, stacked. The first ("Groups") holds every group's face in
// its zone's tile, a row each, with the zone's "+" under them (PREFS-121);
// the second ("In the group") is one drawer per zone showing its open group
// (PREFS-120, PREFS-122); the pool of widgets in no group lies under both.
// Pure decisions only; the page (GroupsEditor.qml) carries them out.
//
// A place the cursor can rest on:
//   { area: "rail", zone, slot }   a row of the zone's tile on the first
//                                  plate: slot indexes its faces, the slot
//                                  after the last is its "+"
//   { area: "drawer", id, pos }    a row of group `id`'s drawer: pos -1 its
//                                  header, 0 on its members
//   { area: "pool", pos }          a chip of the pool
// A place a lifted widget can land on:
//   { area: "drawer", id, pos }    before member `pos` (pos = count: the end)
//   { area: "pool" }               out of every group
//   { area: "plus", zone }         a new group in that zone
//   { area: "face", id }           the end of that group
//   { area: "zone", zone }         a lifted face: its group to that zone
// The layout state the steps read, `s`:
//   zones: the zone lists in bar order; faces: { zone: [group ids in bar
//   order] }; members: { id: count } (without a lifted widget while one is
//   lifted); pool: the pool's chip count; perRow: chips in a pool row;
//   chosen: the chosen group's id; opened: { zone: id } groups a drag
//   opened by resting on their face (optional).

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
// Every group in plate order, zone by zone, left to right.
function drawerOrder(faces, zones) {
  var out = []
  zones.forEach(function(zone) { out = out.concat(faces[zone] || []) })
  return out
}
// Each group's zone, its place among the zone's groups and how many the
// zone holds.
function drawerSlots(faces, zones) {
  var out = {}
  zones.forEach(function(zone) {
    var list = faces[zone] || []
    list.forEach(function(id, i) { out[id] = { zone: zone, index: i, count: list.length } })
  })
  return out
}
// A zone's open group, the one its drawer shows (PREFS-120): a group a drag
// opened there by resting on its face, else the chosen group when it is in
// the zone, else the zone's first in bar order; "" for a zone with none.
function openGroup(faces, zone, chosen, opened) {
  var list = faces[zone] || []
  var o = opened && opened[zone]
  if (o && list.indexOf(o) >= 0) return o
  if (chosen && list.indexOf(chosen) >= 0) return chosen
  return list[0] || ""
}
// The open drawers left to right, one per zone that has groups.
function openDrawers(faces, zones, chosen, opened) {
  var out = []
  zones.forEach(function(zone) {
    var id = openGroup(faces, zone, chosen, opened)
    if (id) out.push(id)
  })
  return out
}
function openOrder(s) { return openDrawers(s.faces, s.zones, s.chosen, s.opened) }
// Face rows a zone's tile shows before it scrolls (PREFS-121).
var faceWindow = 4

// The three plates' heights on their own planes, for PreferencesModel.
// shareLayers (PREFS-115): what each asks for, the least it needs and which
// is served first. `g` carries the Layout page's tile padding, name row,
// chip height and gap; `header` is a drawer's header row with its hairline,
// `drawers` the open drawers ({note: its note's height, rows: its widgets,
// text: the height of what it says with none}), `slack` the room under a
// drawer's last row, `poolRows` the pool's rows (`poolGap` apart) and
// `poolLabel` its label column with the filter, `labelRoom` how far that
// column may hang below the slab into the bottom band where the legend
// leaves it free. The faces' plate is fixed: faceWindow rows and the "+",
// whatever the zones hold. The drawers' plate asks for its tallest drawer,
// counting at most faceWindow rows, and is met before the pool gets more
// than its floor (a row, and its label but what may hang below); a drawer
// needs its header and a row.
function drawerBody(d, g) {
  var rows = Math.min(faceWindow, d.rows || 0)
  return (d.note || 0) + (rows ? rows * g.chip + (rows - 1) * g.gap : d.text || 0) + (g.slack || 0)
}
function plateNeeds(g) {
  var top = 2 * g.pad + g.nameRow
  var faces = top + (faceWindow + 1) * g.chip + faceWindow * g.gap
  var drawerFloor = top + g.header + g.chip
  var tallest = 0
  ;(g.drawers || []).forEach(function(d) { tallest = Math.max(tallest, drawerBody(d, g)) })
  var rows = Math.max(1, g.poolRows || 0)
  var pool = Math.max(g.poolLabel, 2 * g.pad + rows * g.chip + (rows - 1) * g.poolGap)
  var poolFloor = Math.max(g.poolLabel - Math.max(0, g.labelRoom || 0), 2 * g.pad + g.chip)
  return {
    demands: [faces, Math.max(drawerFloor, top + g.header + tallest), pool],
    floors: [faces, drawerFloor, poolFloor],
    first: [1]
  }
}
// The face rows a zone's tile shows in its window and how tall that is: the
// "+" row follows it (PREFS-112, PREFS-121).
function faceView(count, chip, gap) {
  var rows = Math.min(faceWindow, Math.max(0, count || 0))
  return { rows: rows, height: rows ? rows * chip + (rows - 1) * gap : 0 }
}

// A group's face on the first plate, or null.
function facePlace(s, id) {
  for (var z = 0; z < s.zones.length; z++) {
    var i = (s.faces[s.zones[z]] || []).indexOf(id)
    if (i >= 0) return { area: "rail", zone: s.zones[z], slot: i }
  }
  return null
}
// The group a place belongs to: a face's, a drawer header's or a member's;
// "" elsewhere.
function groupAt(s, at) {
  if (!at) return ""
  if (at.area === "drawer") return at.id
  if (at.area === "rail") return (s.faces[at.zone] || [])[at.slot] || ""
  return ""
}
// A drawer's last row: its last member, its header (-1) when empty.
function lastPos(s, id) { return Math.max(-1, (s.members[id] || 0) - 1) }
function zoneOfGroup(s, id) {
  var at = facePlace(s, id)
  return at ? at.zone : ""
}
// The next zone the way dx points, one a step, clamped at the ends.
function zoneAlong(zones, zone, dx) {
  return zones[clamp(zones.indexOf(zone) + (dx > 0 ? 1 : dx < 0 ? -1 : 0), 0, zones.length - 1)]
}
// A zone's "+" on the first plate.
function plusPlace(s, zone) {
  return { area: "rail", zone: zone, slot: (s.faces[zone] || []).length }
}

// The cursor's step (no lift): h/l (dx) and j/k (dy), over the plates as
// over the Layout page's layers.
// Faces: h/l the same row in the next zone (clamped to its last row, the
// "+" counted as one); j/k down and up a zone's faces and its "+", j from
// the "+" on to the zone's drawer (its header), or the pool for a zone with
// none. Drawer: j/k its header and members, k from the header back to the
// zone's "+", j past the last member on to the pool; h/l the same row in
// the next zone's drawer. Pool: h/l along, j/k by rows (perRow); k from the
// first row up to the chosen group's drawer, at its last row.
function step(s, at, dx, dy) {
  if (!at) return firstPlace(s)
  if (at.area === "rail") {
    var n = (s.faces[at.zone] || []).length
    if (dx) {
      var zone = zoneAlong(s.zones, at.zone, dx)
      return { area: "rail", zone: zone, slot: Math.min(at.slot, (s.faces[zone] || []).length) }
    }
    if (dy > 0) {
      if (at.slot < n) return { area: "rail", zone: at.zone, slot: at.slot + 1 }
      var open = openGroup(s.faces, at.zone, s.chosen, s.opened)
      return open ? { area: "drawer", id: open, pos: -1 } : { area: "pool", pos: 0 }
    }
    if (dy < 0) return at.slot > 0 ? { area: "rail", zone: at.zone, slot: at.slot - 1 } : at
    return at
  }
  if (at.area === "drawer") {
    if (dx) {
      var order = openOrder(s), k = order.indexOf(at.id)
      var to = order[clamp(k + dx, 0, order.length - 1)]
      return to ? { area: "drawer", id: to, pos: clamp(at.pos, -1, lastPos(s, to)) } : at
    }
    if (dy > 0) return at.pos < lastPos(s, at.id) ? { area: "drawer", id: at.id, pos: at.pos + 1 } : { area: "pool", pos: 0 }
    if (dy < 0) {
      if (at.pos > -1) return { area: "drawer", id: at.id, pos: at.pos - 1 }
      var home = zoneOfGroup(s, at.id)
      return home ? plusPlace(s, home) : at
    }
    return at
  }
  // The pool.
  var count = s.pool || 0, per = Math.max(1, s.perRow || 1), pos = clamp(at.pos, 0, Math.max(0, count - 1))
  if (dx) return { area: "pool", pos: clamp(pos + dx, 0, Math.max(0, count - 1)) }
  if (dy > 0) {
    if (pos + per <= count - 1) return { area: "pool", pos: pos + per }
    if (Math.floor(pos / per) < Math.floor((count - 1) / per)) return { area: "pool", pos: count - 1 }
    return { area: "pool", pos: pos }
  }
  if (dy < 0) {
    if (pos - per >= 0) return { area: "pool", pos: pos - per }
    var up = s.chosen && facePlace(s, s.chosen) ? s.chosen : openOrder(s)[0]
    return up ? { area: "drawer", id: up, pos: lastPos(s, up) } : { area: "rail", zone: s.zones[0], slot: 0 }
  }
  return { area: "pool", pos: pos }
}
// Where the cursor starts: the chosen group's face, else the first zone's
// first row.
function firstPlace(s) {
  return (s.chosen && facePlace(s, s.chosen)) || { area: "rail", zone: s.zones[0], slot: 0 }
}
// A place kept valid after the layout changed under it: a gone group's
// drawer gives way to the chosen face, positions are clamped.
function normalize(s, at) {
  if (!at) return firstPlace(s)
  if (at.area === "drawer") {
    if (!facePlace(s, at.id)) return firstPlace(s)
    return { area: "drawer", id: at.id, pos: clamp(at.pos, -1, lastPos(s, at.id)) }
  }
  if (at.area === "rail") {
    if (s.zones.indexOf(at.zone) < 0) return firstPlace(s)
    return { area: "rail", zone: at.zone, slot: clamp(at.slot, 0, (s.faces[at.zone] || []).length) }
  }
  return { area: "pool", pos: clamp(at.pos, 0, Math.max(0, (s.pool || 0) - 1)) }
}

// A lifted widget's landing place, stepped with h/l and j/k as the cursor
// steps (s.members without the lifted widget, so a drawer offers count + 1
// places). Faces: h/l the same row in the next zone, j/k down and up the
// zone's faces (a face: that group, at its end) and its "+" (a new group),
// j from the "+" into the zone's open drawer, before its first member, else
// the pool. Drawer: j/k along it, past its end to the pool, before its first
// up to the zone's "+"; h/l the same place in the next zone's open drawer.
// Pool: k up to `home` (the drawer it came from or last went through, else
// the chosen group's), at its end. A closed group's drawer is never a
// landing place. A lifted face (`zone`) steps h/l from zone to zone.
function railLanding(s, zone, slot) {
  var id = (s.faces[zone] || [])[slot]
  return id ? { area: "face", id: id } : { area: "plus", zone: zone }
}
function stepLift(s, t, dx, dy, home) {
  if (!t) return { area: "pool" }
  var order = openOrder(s)
  if (t.area === "zone") return dx ? { area: "zone", zone: zoneAlong(s.zones, t.zone, dx) } : t
  if (t.area === "drawer") {
    var n = s.members[t.id] || 0
    if (dx) {
      var to = order[clamp(order.indexOf(t.id) + dx, 0, order.length - 1)]
      return to ? { area: "drawer", id: to, pos: clamp(t.pos, 0, s.members[to] || 0) } : t
    }
    if (dy > 0) return t.pos < n ? { area: "drawer", id: t.id, pos: t.pos + 1 } : { area: "pool" }
    if (dy < 0) {
      if (t.pos > 0) return { area: "drawer", id: t.id, pos: t.pos - 1 }
      return { area: "plus", zone: zoneOfGroup(s, t.id) || s.zones[0] }
    }
    return t
  }
  if (t.area === "plus" || t.area === "face") {
    var at = t.area === "face" ? facePlace(s, t.id) : plusPlace(s, t.zone)
    if (!at) return { area: "pool" }
    var rows = (s.faces[at.zone] || []).length
    if (dx) {
      var zone = zoneAlong(s.zones, at.zone, dx)
      return railLanding(s, zone, Math.min(at.slot, (s.faces[zone] || []).length))
    }
    if (dy > 0) {
      if (at.slot < rows) return railLanding(s, at.zone, at.slot + 1)
      var open = openGroup(s.faces, at.zone, s.chosen, s.opened)
      return open ? { area: "drawer", id: open, pos: 0 } : { area: "pool" }
    }
    if (dy < 0) return at.slot > 0 ? railLanding(s, at.zone, at.slot - 1) : t
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
  return at && at.area === "drawer" ? { area: "drawer", id: at.id, pos: Math.max(0, at.pos) } : { area: "pool" }
}
// What a drop does. lifted: { key, group } (the group it is in, "" in the
// pool) or { face: id, zone } for a lifted face; target: a landing place,
// or for a face { area: "zone", zone }. into: the target drawer's member
// keys without the lifted widget.
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
