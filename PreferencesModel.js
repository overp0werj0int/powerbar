// Pure layout operations. Address entries by section + index so duplicates remain distinct.
var sections = ["left", "center", "right"]
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

// Layout editor geometry. A cell is one column × visibility pair; positions
// are indexes into its items ordered as the bar shows them. A column is a
// zone, except that with a centre anchor the centre's On demand cell splits
// in two: "center:start" and "center:end", the widgets that wait behind the
// dots before and after the anchor.
function columns(mode, split) {
  return split && mode === "managed" ? ["left", "center:start", "center:end", "right"] : sections
}
function sectionOf(column) { return String(column).split(":")[0] }
// A group icon anchored on the centre anchor sits just before it.
function centerSide(entry, anchorIndex) {
  return entry.index < anchorIndex || (entry.index === anchorIndex && !!entry.groupId) ? "start" : "end"
}
function cell(entries, column, visibility, excludeKey, anchorIndex) {
  var section = sectionOf(column), side = String(column).split(":")[1] || ""
  var anchor = anchorIndex === undefined ? -1 : anchorIndex
  return (entries || []).filter(function(e) {
    return e.section === section && e.mode === visibility && (!excludeKey || e.instanceKey !== excludeKey)
      && (!side || centerSide(e, anchor) === side)
  }).sort(function(a, b) { return a.index - b.index })
}
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }
function zonesOnly() { return sections }
// The same column in another row: a split centre column meets the whole
// centre, and the whole centre enters a split row at the side with items.
function across(list, column, count, mode) {
  if (list.indexOf(column) >= 0) return column
  var section = sectionOf(column)
  if (list.indexOf(section) >= 0) return section
  var start = section + ":start", end = section + ":end"
  // The tray's one row meets the zone the tray usually sits in, the last.
  if (list.indexOf(start) < 0) return list[list.length - 1]
  return count(start, mode) === 0 && count(end, mode) > 0 ? end : start
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
    column = across(columnsFor(list[m]), column, count, list[m])
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
    column = across(columnsFor(list[m]), column, count, list[m])
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
// The layout index to insert before, or -1 for the end of the zone. Past the
// last item before the centre anchor, that is the anchor.
function dropBefore(items, pos, column, anchorIndex) {
  if (pos >= 0 && pos < items.length) return items[pos].index
  return column === "center:start" && anchorIndex >= 0 ? anchorIndex : -1
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
