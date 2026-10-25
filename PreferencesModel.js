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
// The same column in another row; the tray's one row meets the zone the tray
// usually sits in, the last.
function across(list, column) {
  return list.indexOf(column) >= 0 ? column : list[list.length - 1]
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
// (Layout), and anything past either end opens the nearest page. Earlier
// pages 3 and 4 (General, Appearance) are the Bar page now.
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
// A layer `h` tall tilted back by `angle` degrees about its middle line, as
// Qt's Rotation draws it with `distance` to the plane: how far its top and
// bottom edges land from that line. The top recedes, the bottom comes near.
// A layer `h` tall tilted back about its top edge, seen from `distance`: how
// tall its picture is. The top edge stays as it is and the rest comes near,
// so a layer that changes height only changes below.
function tiltedHeight(h, angle, distance) {
  var a = angle * Math.PI / 180
  return h * Math.cos(a) / (1 - Math.sin(a) * h / Math.max(1, distance))
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
// next or previous layer. An empty well is a resting place. The tray's layer
// has one column, which meets the last zone (across).
function stepLayer(count, cursor, dx, dy, columnsFor, rowList) {
  return layerStep(count, cursor, dx, dy, columnsFor, rowList, 0)
}
// A lifted item: count excludes it, so a well offers count + 1 places.
function stepLayerLift(count, target, dx, dy, columnsFor, rowList) {
  return layerStep(count, target, dx, dy, columnsFor, rowList, 1)
}
function layerStep(count, at, dx, dy, columnsFor, rowList, extra) {
  columnsFor = columnsFor || zonesOnly
  var list = rowList || modes
  var m = Math.max(0, list.indexOf(at.mode)), column = across(columnsFor(list[m]), at.section), pos = at.pos
  function last(c, row) { return Math.max(0, count(c, row) - 1 + extra) }
  if (dx) {
    var cols = columnsFor(list[m])
    column = cols[clamp(cols.indexOf(column) + dx, 0, cols.length - 1)]
    pos = clamp(pos, 0, last(column, list[m]))
  }
  if (dy) {
    pos += dy
    if (pos > last(column, list[m])) {
      if (m < list.length - 1) { m++; column = across(columnsFor(list[m]), column); pos = 0 }
      else pos = last(column, list[m])
    } else if (pos < 0) {
      if (m > 0) { m--; column = across(columnsFor(list[m]), column); pos = last(column, list[m]) }
      else pos = 0
    }
  }
  return { section: column, mode: list[m], pos: pos }
}
