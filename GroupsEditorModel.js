// The Groups page (docs/behavior/preferences.md PREFS-109 on): two of the
// Layout page's plates, stacked. The first ("Groups") lists in each zone's
// tile its groups in bar order, every group's widgets right under its face,
// then the zone's "+" (PREFS-110, PREFS-121); the pool of widgets in no group
// lies under it (PREFS-114). j/k walk one list per zone and on to the pool,
// h/l go to the same row in the next zone's list. Pure decisions only; the
// page (GroupsEditor.qml) carries them out.
//
// A place the cursor can rest on:
//   { area: "face", id }          a group's face row
//   { area: "member", id, pos }   a widget row of group `id` (pos 0-based in
//                                 the drawn list, without a lifted widget)
//   { area: "plus", zone }        a zone's "+" row
//   { area: "pool", pos }         a chip of the pool
// A place a lifted widget can land on:
//   { area: "gap", id, pos }      group `id`, before member `pos` (pos =
//                                 count: its end; an empty group's one gap 0)
//   { area: "plus", zone }        a new group in that zone
//   { area: "pool" }              out of every group
//   { area: "zone", zone }        a lifted face: its group to that zone
// The layout state the steps read, `s`:
//   zones: the zone lists in bar order; faces: { zone: [group ids in bar
//   order] }; members: { id: count } (without a lifted widget while one is
//   lifted); pool: the pool's chip count; perRow: chips in a pool row;
//   chosen: the chosen group's id.

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

// Groups as GroupsModel.render should place them in the lists: a hidden
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
// Every group in page order, zone by zone, left to right.
function faceOrder(faces, zones) {
  var out = []
  zones.forEach(function(zone) { out = out.concat(faces[zone] || []) })
  return out
}

// Rows a zone's tile shows before it scrolls (PREFS-121): faces, widgets
// and notes together.
var listWindow = 8
// A zone's list as drawn (PREFS-111): each group's face, then its widgets in
// member order, or for an empty group one note row; a lifted widget's landing
// place (`target`, a gap) shows as a placeholder row among them, in place of
// an empty group's note. ids: the zone's groups in bar order; lists: { id:
// [member keys without the lifted widget] }. Rows:
//   { kind: "face", id }
//   { kind: "member", id, pos, key, first, last }   first, last: the ends of
//   { kind: "gap", id, pos, first, last }           the group's branch
//   { kind: "note", id }
function drawnRows(ids, lists, target) {
  var out = []
  ;(ids || []).forEach(function(id) {
    out.push({ kind: "face", id: id })
    var keys = (lists && lists[id]) || []
    var rows = keys.map(function(key, pos) { return { kind: "member", id: id, pos: pos, key: key } })
    if (target && target.area === "gap" && target.id === id)
      rows.splice(clamp(target.pos, 0, rows.length), 0, { kind: "gap", id: id, pos: clamp(target.pos, 0, rows.length) })
    if (!rows.length) { out.push({ kind: "note", id: id }); return }
    rows.forEach(function(r, i) { r.first = i === 0; r.last = i === rows.length - 1; out.push(r) })
  })
  return out
}
// The rows a zone's tile shows in its window and how tall that is: the "+"
// row follows it (PREFS-112, PREFS-121).
function listView(count, chip, gap) {
  var rows = Math.min(listWindow, Math.max(0, count || 0))
  return { rows: rows, height: rows ? rows * chip + (rows - 1) * gap : 0 }
}

// The two plates' heights on their own planes, for PreferencesModel.
// shareLayers (PREFS-115): what each asks for, the least it needs and which
// is served first. `g` carries the Layout page's tile padding, name row,
// chip height and gap; `zoneRows` each zone's drawn rows (drawnRows), the
// pool's rows (`poolRows`, `poolGap` apart) and `poolLabel` its label column
// with the filter, `labelRoom` how far that column may hang below the slab
// into the bottom band where the legend leaves it free. The list plate asks
// for its tallest zone, at most listWindow rows, and the "+"; its floor is a
// row and the "+". It is met before the pool gets more than its floor (a
// row, and its label but what may hang below).
function plateNeeds(g) {
  var top = 2 * g.pad + g.nameRow
  var tallest = 0
  ;(g.zoneRows || []).forEach(function(n) { tallest = Math.max(tallest, n || 0) })
  var rows = clamp(tallest, 1, listWindow)
  var list = top + (rows + 1) * g.chip + rows * g.gap
  var listFloor = top + 2 * g.chip + g.gap
  var poolRows = Math.max(1, g.poolRows || 0)
  var pool = Math.max(g.poolLabel, 2 * g.pad + poolRows * g.chip + (poolRows - 1) * g.poolGap)
  var poolFloor = Math.max(g.poolLabel - Math.max(0, g.labelRoom || 0), 2 * g.pad + g.chip)
  return {
    demands: [list, pool],
    floors: [listFloor, poolFloor],
    first: [0]
  }
}

// A group's face, or null.
function facePlace(s, id) {
  for (var z = 0; z < s.zones.length; z++)
    if ((s.faces[s.zones[z]] || []).indexOf(id) >= 0) return { area: "face", id: id }
  return null
}
function zoneOfGroup(s, id) {
  for (var z = 0; z < s.zones.length; z++)
    if ((s.faces[s.zones[z]] || []).indexOf(id) >= 0) return s.zones[z]
  return ""
}
// The group a place belongs to: a face's or a widget row's; "" on a "+" or
// in the pool.
function groupAt(s, at) {
  if (!at || (at.area !== "face" && at.area !== "member")) return ""
  return facePlace(s, at.id) ? at.id : ""
}
// The zone a place in the lists is in, "" in the pool.
function zoneAt(s, at) {
  if (!at) return ""
  if (at.area === "plus" || at.area === "zone") return s.zones.indexOf(at.zone) >= 0 ? at.zone : ""
  if (at.area === "face" || at.area === "member" || at.area === "gap") return zoneOfGroup(s, at.id)
  return ""
}
// The next zone the way dx points, one a step, clamped at the ends.
function zoneAlong(zones, zone, dx) {
  return zones[clamp(zones.indexOf(zone) + (dx > 0 ? 1 : dx < 0 ? -1 : 0), 0, zones.length - 1)]
}
// A zone's "+".
function plusPlace(s, zone) { return { area: "plus", zone: zone } }
// A zone's cursor rows in order: each group's face and its widget rows, then
// the "+" (an empty group's note is no stop).
function rows(s, zone) {
  var out = []
  ;(s.faces[zone] || []).forEach(function(id) {
    out.push({ area: "face", id: id })
    for (var p = 0; p < (s.members[id] || 0); p++) out.push({ area: "member", id: id, pos: p })
  })
  out.push(plusPlace(s, zone))
  return out
}
// A lifted widget's landing places in a zone, in list order: every group's
// gaps (count + 1 of them, an empty group's one), then the "+".
function landings(s, zone) {
  var out = []
  ;(s.faces[zone] || []).forEach(function(id) {
    for (var p = 0; p <= (s.members[id] || 0); p++) out.push({ area: "gap", id: id, pos: p })
  })
  out.push(plusPlace(s, zone))
  return out
}
function same(a, b) {
  return !!a && !!b && a.area === b.area && a.id === b.id && a.pos === b.pos && a.zone === b.zone
}
function indexIn(list, at) {
  for (var i = 0; i < list.length; i++) if (same(list[i], at)) return i
  return -1
}
// A group's last row: its last widget, its face when empty.
function lastRow(s, id) {
  var n = s.members[id] || 0
  return n ? { area: "member", id: id, pos: n - 1 } : { area: "face", id: id }
}

// The cursor's step (no lift): h/l (dx) and j/k (dy).
// In the lists: j/k the next or previous row of the zone's list, j past its
// "+" on to the pool (its first chip), k from the first row stays; h/l the
// same row index in the next zone's list, clamped to its last (the "+").
// Pool: h/l along, j/k by rows (perRow); k from the first row up to the
// chosen group's last row, else the first zone's first row.
function step(s, at, dx, dy) {
  if (!at) return firstPlace(s)
  if (at.area !== "pool") {
    var zone = zoneAt(s, at)
    if (!zone) return firstPlace(s)
    var list = rows(s, zone), i = indexIn(list, at)
    if (i < 0) return normalize(s, at)
    if (dx) {
      var next = rows(s, zoneAlong(s.zones, zone, dx))
      return next[Math.min(i, next.length - 1)]
    }
    if (dy > 0) return i < list.length - 1 ? list[i + 1] : { area: "pool", pos: 0 }
    if (dy < 0) return i > 0 ? list[i - 1] : at
    return at
  }
  var count = s.pool || 0, per = Math.max(1, s.perRow || 1), pos = clamp(at.pos, 0, Math.max(0, count - 1))
  if (dx) return { area: "pool", pos: clamp(pos + dx, 0, Math.max(0, count - 1)) }
  if (dy > 0) {
    if (pos + per <= count - 1) return { area: "pool", pos: pos + per }
    if (Math.floor(pos / per) < Math.floor((count - 1) / per)) return { area: "pool", pos: count - 1 }
    return { area: "pool", pos: pos }
  }
  if (dy < 0) {
    if (pos - per >= 0) return { area: "pool", pos: pos - per }
    return s.chosen && facePlace(s, s.chosen) ? lastRow(s, s.chosen) : rows(s, s.zones[0])[0]
  }
  return { area: "pool", pos: pos }
}
// Where the cursor starts: the chosen group's face, else the first zone's
// first row.
function firstPlace(s) {
  return (s.chosen && facePlace(s, s.chosen)) || rows(s, s.zones[0])[0]
}
// A place kept valid after the layout changed under it: a gone group or
// zone gives way to the first place, positions are clamped (a group left
// without widgets: its face).
function normalize(s, at) {
  if (!at) return firstPlace(s)
  if (at.area === "face") return facePlace(s, at.id) || firstPlace(s)
  if (at.area === "member") {
    if (!facePlace(s, at.id)) return firstPlace(s)
    var n = s.members[at.id] || 0
    return n ? { area: "member", id: at.id, pos: clamp(at.pos, 0, n - 1) } : { area: "face", id: at.id }
  }
  if (at.area === "plus") return s.zones.indexOf(at.zone) >= 0 ? plusPlace(s, at.zone) : firstPlace(s)
  if (at.area === "pool") return { area: "pool", pos: clamp(at.pos, 0, Math.max(0, (s.pool || 0) - 1)) }
  return firstPlace(s)
}

// A lifted widget's landing place, stepped with h/l and j/k as the cursor
// steps (s.members without the lifted widget): j/k along the zone's
// landings (landings()) and on to the pool, k from the first stays; h/l the
// same index in the next zone's, clamped to its "+". From the pool k goes to
// `home`'s end (the group it came from or last went through, else the chosen
// group's), else the last zone's "+". A lifted face (`zone`) steps h/l from
// zone to zone.
function stepLift(s, t, dx, dy, home) {
  if (!t) return { area: "pool" }
  if (t.area === "zone") return dx ? { area: "zone", zone: zoneAlong(s.zones, t.zone, dx) } : t
  if (t.area === "pool") {
    if (dy >= 0) return t
    var up = home && facePlace(s, home) ? home : s.chosen && facePlace(s, s.chosen) ? s.chosen : ""
    return up ? { area: "gap", id: up, pos: s.members[up] || 0 } : plusPlace(s, s.zones[s.zones.length - 1])
  }
  var zone = zoneAt(s, t)
  if (!zone) return { area: "pool" }
  var list = landings(s, zone), i = indexIn(list, t)
  if (i < 0) return list[0]
  if (dx) {
    var next = landings(s, zoneAlong(s.zones, zone, dx))
    return next[Math.min(i, next.length - 1)]
  }
  if (dy > 0) return i < list.length - 1 ? list[i + 1] : { area: "pool" }
  if (dy < 0) return i > 0 ? list[i - 1] : t
  return t
}
// Where a lift starts: a widget row at its own gap, a pool chip in the pool.
function liftStart(at) {
  return at && at.area === "member" ? { area: "gap", id: at.id, pos: Math.max(0, at.pos) } : { area: "pool" }
}
// What a drop does. lifted: { key, group } (the group it is in, "" in the
// pool) or { face: id, zone } for a lifted face; target: a landing place,
// or for a face { area: "zone", zone }. into: the target group's member
// keys without the lifted widget; ownPos: the lifted widget's own place in
// its group.
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
  if (target.area === "gap") {
    if (target.id === lifted.group && target.pos === ownPos) return { op: "none" }
    var list = into || []
    return { op: "assign", key: lifted.key, id: target.id, before: target.pos < list.length ? list[target.pos] : "" }
  }
  return { op: "none" }
}

// Shift with j or k on a face: the group it moves past, the next (j) or
// previous (k) in its zone in bar order; "" at either end.
function neighbourFace(s, id, dy) {
  var list = s.faces[zoneOfGroup(s, id)] || [], i = list.indexOf(id)
  if (i < 0 || !dy) return ""
  return list[i + (dy > 0 ? 1 : -1)] || ""
}
// Shift with h or l on a face: the next zone, "" past either end.
function nextZone(zones, zone, dx) {
  var i = zones.indexOf(zone)
  if (i < 0 || !dx) return ""
  var n = i + (dx > 0 ? 1 : -1)
  return n >= 0 && n < zones.length ? zones[n] : ""
}

// A face carried to another zone (Shift with h or l, the inspector's Zone):
// a new zone clears a group's anchor (`before`), so the place it had in each
// zone it leaves is remembered, and coming back to a zone finds that place
// again while its anchor is still in that zone, else the zone's end.
// Returns { patch, memory }: the Groups.edit patch and the memory to keep
// ({ groupId: { zone: before } }, for the session).
function zoneMove(memory, group, zone, layout) {
  var kept = Object.assign({}, memory || {})
  var mine = Object.assign({}, kept[group.id] || {})
  if (group.section) mine[group.section] = String(group.before || "")
  kept[group.id] = mine
  var before = mine[zone] || ""
  var list = layout && Array.isArray(layout[zone]) ? layout[zone] : []
  if (before && !list.some(function(e) { return e && e.powerbarInstance === before })) before = ""
  return { patch: { section: zone, before: before }, memory: kept }
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
