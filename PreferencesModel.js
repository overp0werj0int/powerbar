// Pure layout operations. Address entries by section + index so duplicates remain distinct.
// The five zone lists (SectionsModel.lists), in order along the bar.
var sections = ["left", "centerBegin", "center", "centerEnd", "right"]
var modes = ["shown", "managed", "hidden"]
// The rows of the Layout page: the visibilities, then Omarchy's tray, whose
// icons can be moved out onto the bar (TrayItemsModel.js).
var rows = modes.concat(["tray"])

function id(entry) { return typeof entry === "string" ? entry : String(entry.id || "") }
// As ManagedModel.mode, without its pending state: a widget with no saved
// visibility is On the bar, or, on a config still following the old default
// (legacy), On demand unless it comes from Omarchy.
function mode(entry, metadata, legacy) {
  var value = entry && entry.powerbarVisibility
  if (modes.indexOf(value) >= 0) return value
  return legacy && !(metadata && metadata.firstParty === true) ? "managed" : "shown"
}
function records(layout, metadataFor, legacy) {
  var result = []
  sections.forEach(function(section) {
    var entries = layout && Array.isArray(layout[section]) ? layout[section] : []
    entries.forEach(function(entry, index) {
      result.push({ section: section, index: index, id: id(entry), instanceKey: entry && entry.powerbarInstance || "", badgeProperty: entry && entry.powerbarBadgeProperty || "", urgentProperty: entry && entry.powerbarUrgentProperty || "", mode: mode(entry, metadataFor ? metadataFor(id(entry)) : null, legacy), fingerprint: JSON.stringify(entry),
        trayItem: entry && entry.type === "trayItem" ? String(entry.item || "") : "", trayTitle: entry && entry.type === "trayItem" ? String(entry.title || "") : "" })
    })
  })
  return result
}
function move(config, source, section, visibility, beforeIndex) {
  if (!source || sections.indexOf(section) < 0 || modes.indexOf(visibility) < 0) return false
  var layout = config.bar && config.bar.layout
  if (!layout || !Array.isArray(layout[source.section])) return false
  var from = layout[source.section]
  if (JSON.stringify(from[source.index]) !== source.fingerprint) return false
  if (!Array.isArray(layout[section])) layout[section] = []
  var to = layout[section]
  var at = Number.isInteger(beforeIndex) && beforeIndex >= 0 ? Math.min(beforeIndex, to.length) : to.length
  var entry = from.splice(source.index, 1)[0]
  if (from === to && source.index < at) at--
  if (typeof entry === "string") entry = { id: entry }
  entry.powerbarVisibility = visibility
  to.splice(at, 0, entry)
  return true
}
// The instance key a `before` index names in `section` (the index counts the
// source when it is in that section; past the end, or none, is ""), so a move
// replayed on a layout that changed meanwhile still finds its place. Just
// before the source itself is its own place: the entry after it names that.
function anchorKey(layout, section, beforeIndex, sourceKey) {
  var list = layout && Array.isArray(layout[section]) ? layout[section] : []
  var at = Math.ceil(beforeIndex)
  if (!Number.isInteger(at) || at < 0) return ""
  var entry = list[at]
  if (entry && sourceKey && entry.powerbarInstance === sourceKey) entry = list[at + 1]
  return entry && entry.powerbarInstance || ""
}
function icon(idValue) {
  var name = idValue.split('.').pop()
  var icons = { clock: "󰥔", audio: "󰕾", network: "󰤨", bluetooth: "󰂯", power: "󰁹", monitor: "󰍹", workspaces: "󰙀", indicators: "󰍉", tray: "󰀱", media: "󰎆", weather: "󰖐", microphone: "󰍬", "keyboard-layout": "󰌌", "system-update": "󰚰", spacer: "↔", agents: "󰚩" }
  return icons[name] || "󰕰"
}

// Layout editor geometry. A cell is one zone × visibility pair; positions
// are indexes into its items ordered as the bar shows them.
function cell(entries, column, visibility, excludeKey) {
  return (entries || []).filter(function(e) {
    return e.section === column && e.mode === visibility && (!excludeKey || e.instanceKey !== excludeKey)
  }).sort(function(a, b) { return a.index - b.index })
}
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }
function zonesOnly() { return sections }
// The same column in another row; a slab's one column (the tray's, the
// hidden layer's) meets `home`, the zone the cursor last had or its widget's
// own, else the last zone.
function across(list, column, home) {
  if (list.indexOf(column) >= 0) return column
  return home && list.indexOf(home) >= 0 ? home : list[list.length - 1]
}
// The hidden layer is one slab like the tray's (PREFS-107): a hidden widget
// keeps its zone in the config, and the slab lists the layer's widgets in bar
// order, zone by zone.
function slab(entries, visibility, excludeKey) {
  return (entries || []).filter(function(e) {
    return e.mode === visibility && sections.indexOf(e.section) >= 0 && (!excludeKey || e.instanceKey !== excludeKey)
  }).sort(function(a, b) {
    return sections.indexOf(a.section) - sections.indexOf(b.section) || a.index - b.index
  })
}
// Where a widget of `section` at layout `index` comes in a slab's `items`.
function slabPos(items, section, index) {
  var s = sections.indexOf(section)
  return (items || []).filter(function(r) {
    var t = sections.indexOf(r.section)
    return t < s || (t === s && r.index < index)
  }).length
}
// Dropped at `pos` among a slab's `items` (without the dropped one), a widget
// of `section` goes before the first chip of its own zone from there on (its
// layout index), else to its zone's end (-1): it keeps its zone, so only its
// order within the zone can change.
function slabBefore(items, pos, section) {
  for (var i = Math.max(0, pos); i < (items || []).length; i++)
    if (items[i].section === section) return items[i].index
  return -1
}
// Cursor over existing items. Walking past a cell's edge continues into the
// neighbouring column on the same row; empty cells are valid resting places.
// columnsFor(mode) lists a row's columns (zones by default); rowList the rows
// (the visibilities by default).
function stepCursor(count, cursor, dx, dy, columnsFor, rowList) {
  columnsFor = columnsFor || zonesOnly
  var list = rowList || modes
  var m = list.indexOf(cursor.mode), column = cursor.section, pos = cursor.pos
  if (dy) {
    m = clamp(m + dy, 0, list.length - 1)
    column = across(columnsFor(list[m]), column)
    pos = clamp(pos, 0, Math.max(0, count(column, list[m]) - 1))
  }
  var cols = columnsFor(list[m]), s = Math.max(0, cols.indexOf(column))
  if (dx) {
    pos += dx
    if (pos < 0) {
      if (s > 0) { s--; pos = Math.max(0, count(cols[s], list[m]) - 1) } else pos = 0
    } else if (pos > Math.max(0, count(cols[s], list[m]) - 1)) {
      if (s < cols.length - 1) { s++; pos = 0 } else pos = Math.max(0, count(cols[s], list[m]) - 1)
    }
  }
  return { section: cols[s], mode: list[m], pos: pos }
}
// Insertion point for a lifted item; count excludes the lifted item, so every
// cell offers count + 1 slots and the far edge of a cell hands over to the next.
function stepLift(count, target, dx, dy, columnsFor, rowList) {
  columnsFor = columnsFor || zonesOnly
  var list = rowList || modes
  var m = list.indexOf(target.mode), column = target.section, pos = target.pos
  if (dy) {
    m = clamp(m + dy, 0, list.length - 1)
    column = across(columnsFor(list[m]), column)
    pos = clamp(pos, 0, count(column, list[m]))
  }
  var cols = columnsFor(list[m]), s = Math.max(0, cols.indexOf(column))
  if (dx) {
    pos += dx
    if (pos < 0) {
      if (s > 0) { s--; pos = count(cols[s], list[m]) } else pos = 0
    } else if (pos > count(cols[s], list[m])) {
      if (s < cols.length - 1) { s++; pos = 0 } else pos = count(cols[s], list[m])
    }
  }
  return { section: cols[s], mode: list[m], pos: pos }
}
// The layout index to insert before, or -1 for the end of the zone.
function dropBefore(items, pos) {
  return pos >= 0 && pos < items.length ? items[pos].index : -1
}

// Hiding with x and showing again returns a widget to the row it left.
function toggledHidden(currentMode, rememberedMode) {
  if (currentMode !== "hidden") return "hidden"
  return rememberedMode === "shown" || rememberedMode === "managed" ? rememberedMode : "shown"
}
// The page `omarchy-shell powerbar preferencesPage <n>` opens: n counts from 1
// (Layout), and anything past either end opens the nearest page: above the
// last, the last (Behavior, or Tuning when that page is there; PREFS-87).
function pageIndex(page, count) {
  var n = Math.round(Number(page))
  if (!isFinite(n)) n = 1
  return Math.max(0, Math.min(n, count) - 1)
}

// The Layout page's layers (docs/behavior/preferences.md PREFS-99).
// Five zone columns of one width, mirrored about the axis (the screen's
// middle, where a camera sits), Center on it: each column's x in a row
// `width` wide, and their shared width.
// The columns of a layer: `count` of them mirrored about `axis` inside
// `width`, `gap` apart, the middle one `centerWidth` wide when given (the
// camera's width, so Center sits under it) and the others sharing the rest.
// Returns each column's x and width; `width` is the shared one.
function layerColumns(width, gap, axis, count, centerWidth) {
  count = count || sections.length
  var half = Math.max(0, Math.min(axis, width - axis))
  var inner = Math.max(1, 2 * half - gap * (count - 1))
  var mid = (count - 1) / 2
  var centre = count % 2 === 1 && centerWidth > 0 ? Math.min(centerWidth, inner / count * 1.5) : 0
  var w = Math.max(1, centre ? (inner - centre) / (count - 1) : inner / count)
  var xs = [], widths = [], x = axis - half
  for (var i = 0; i < count; i++) {
    var cw = centre && i === mid ? centre : w
    xs.push(x)
    widths.push(cw)
    x += cw + gap
  }
  return { width: w, xs: xs, widths: widths }
}
// A layer `h` tall tilted back about its top edge, seen from `distance`: how
// tall its picture is. The top edge stays as it is and the rest comes near,
// so a layer that changes height only changes below.
function tiltedHeight(h, angle, distance) {
  var a = angle * Math.PI / 180
  return h * Math.cos(a) / (1 - Math.sin(a) * h / Math.max(1, distance))
}
// A seen height back to the plane's own: tiltedHeight inverted.
function tiltedPlaneHeight(seen, angle, distance) {
  var a = angle * Math.PI / 180
  return seen / (Math.cos(a) + Math.sin(a) * seen / Math.max(1, distance))
}
// Heights for layers that ask for `demands` and need at least `floors` (both
// on the plane), so that their pictures and the gaps between them fit `room`:
// what they ask for while it fits; else each starts at its floor and the rest
// is shared out, every layer taking what it asks for up to an equal share of
// what is left, so the modest ones leave the rest to the others and layers
// that all want more get the same (PREFS-106). Floors win over the room.
// The layers `first` names (indexes) get what they ask for before the rest
// is shared (the Groups page's drawers, PREFS-115).
function shareLayers(demands, floors, room, angle, distance, gap, first) {
  var n = demands.length
  if (!n) return []
  var seen = demands.map(function(h) { return tiltedHeight(h, angle, distance) })
  var low = floors.map(function(h, i) { return Math.min(seen[i], tiltedHeight(h, angle, distance)) })
  var avail = room - gap * (n - 1)
  var out = seen.slice()
  if (seen.reduce(function(a, b) { return a + b }, 0) > avail) {
    var left = avail
    for (var i = 0; i < n; i++) { out[i] = low[i]; left -= low[i] }
    ;(first || []).forEach(function(f) {
      if (left <= 0) return
      var more = Math.min(seen[f] - out[f], left)
      out[f] += more
      left -= more
    })
    var order = []
    for (var j = 0; j < n; j++) order.push(j)
    order.sort(function(a, b) { return (seen[a] - out[a]) - (seen[b] - out[b]) })
    for (var k = 0; k < n && left > 0; k++) {
      var at = order[k], give = Math.min(seen[at] - out[at], left / (n - k))
      out[at] += give
      left -= give
    }
  }
  return out.map(function(s) { return tiltedPlaneHeight(s, angle, distance) })
}
// Layers `heights` tall, each tilted the same way about its top edge and
// stacked with `gap` between what they show: where each one's box starts
// and how tall its picture is, and the whole.
function stackLayers(heights, angle, distance, gap) {
  var y = 0, layers = []
  heights.forEach(function(h) {
    var seen = tiltedHeight(h, angle, distance)
    layers.push({ top: y, height: seen })
    y += seen + gap
  })
  return { layers: layers, height: Math.max(0, y - gap) }
}
// Lines on a tilted plane. A point `v` down the plane from the line it turns
// about (a layer's top edge) is seen `v cos / (1 - v sin / d)` below it, and
// a line `u` from the axis is seen `u / (1 - v sin / d)` from it: both scale
// alike, so a line down the plane is seen as a straight line that spreads as
// it comes near.
// tiltedDepth: the plane's own `v` for a seen `y` (so a shape drawn on the
// plane can start and end at seen heights); tiltedSpread: how far from the
// axis a line `u` out is seen at seen height `y`.
function tiltedDepth(y, angle, distance) {
  var a = angle * Math.PI / 180
  return y * distance / (Math.cos(a) * distance + y * Math.sin(a))
}
function tiltedSpread(u, y, angle, distance) {
  var a = angle * Math.PI / 180
  return u * (1 + Math.sin(a) * y / (Math.cos(a) * distance))
}
// Cursor and lift steps on the layers, where a zone's items run down its
// well: dx changes zone on the same layer (keeping the row where it can), dy
// walks the zone's list and, past its ends, goes on into the same zone on the
// next or previous layer. An empty well is a resting place. A layer of one
// column is a slab (the hidden layer's, the tray's) whose chips flow
// `perRow` (5) to a row: dx walks along them, dy goes a row down or up and,
// past the first or last row, on to the next layer. Leaving a slab for a
// layer of zones meets `at.home` (across), the zone the cursor last had or
// the caller's choice; the step returns the home it keeps.
function stepLayer(count, cursor, dx, dy, columnsFor, rowList, perRow) {
  return layerStep(count, cursor, dx, dy, columnsFor, rowList, 0, perRow)
}
// A lifted item: count excludes it, so a well offers count + 1 places.
function stepLayerLift(count, target, dx, dy, columnsFor, rowList, perRow) {
  return layerStep(count, target, dx, dy, columnsFor, rowList, 1, perRow)
}
function layerStep(count, at, dx, dy, columnsFor, rowList, extra, perRow) {
  columnsFor = columnsFor || zonesOnly
  var list = rowList || modes, per = perRow || 5
  var m = Math.max(0, list.indexOf(at.mode)), home = at.home || ""
  var column = across(columnsFor(list[m]), at.section, home), pos = at.pos
  function last(c, row) { return Math.max(0, count(c, row) - 1 + extra) }
  function isSlab(row) { return columnsFor(row).length === 1 }
  function enter(next, down) {
    m = next
    column = across(columnsFor(list[m]), column, home)
    pos = down ? 0 : last(column, list[m])
  }
  if (!isSlab(list[m])) home = column
  if (dx) {
    if (isSlab(list[m])) pos = clamp(pos + dx, 0, last(column, list[m]))
    else {
      var cols = columnsFor(list[m])
      column = cols[clamp(cols.indexOf(column) + dx, 0, cols.length - 1)]
      home = column
      pos = clamp(pos, 0, last(column, list[m]))
    }
  }
  if (dy) {
    var end = last(column, list[m])
    if (isSlab(list[m])) {
      var next = pos + dy * per
      if (next > end) {
        if (Math.floor(pos / per) < Math.floor(end / per)) pos = end
        else if (m < list.length - 1) enter(m + 1, true)
      } else if (next < 0) {
        if (m > 0) enter(m - 1, false)
      } else pos = next
    } else {
      pos += dy
      if (pos > end) {
        if (m < list.length - 1) enter(m + 1, true)
        else pos = end
      } else if (pos < 0) {
        if (m > 0) enter(m - 1, false)
        else pos = 0
      }
    }
  }
  if (!isSlab(list[m])) home = column
  return { section: column, mode: list[m], pos: pos, home: home }
}
// Shift with j or k moves a widget to the next layer at once (PREFS-27):
// the layer `dy` from `mode` in `rowList`, or "" past the first or last.
function nextLayer(rowList, mode, dy) {
  var list = rowList || modes, i = list.indexOf(mode)
  if (i < 0 || !dy) return ""
  var next = i + (dy > 0 ? 1 : -1)
  return next >= 0 && next < list.length ? list[next] : ""
}
// Where a widget lands in its zone on a layer when only its layer changes:
// it keeps its place in the zone, so it comes after the layer's chips of
// that zone that come before it on the bar.
function layerPos(items, index) {
  return (items || []).filter(function(r) { return r.index < index }).length
}
