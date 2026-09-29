// Pure layout operations. Address entries by section + index so duplicates remain distinct.
var sections = ["left", "center", "right"]
var modes = ["shown", "managed", "hidden"]

function id(entry) { return typeof entry === "string" ? entry : String(entry.id || "") }
function mode(entry, metadata) {
  var value = entry && entry.powerbarVisibility
  return modes.indexOf(value) >= 0 ? value : metadata && metadata.firstParty === true ? "shown" : "managed"
}
function records(layout, metadataFor) {
  var result = []
  sections.forEach(function(section) {
    var entries = layout && Array.isArray(layout[section]) ? layout[section] : []
    entries.forEach(function(entry, index) {
      result.push({ section: section, index: index, id: id(entry), instanceKey: entry && entry.powerbarInstance || "", badgeProperty: entry && entry.powerbarBadgeProperty || "", urgentProperty: entry && entry.powerbarUrgentProperty || "", mode: mode(entry, metadataFor ? metadataFor(id(entry)) : null), fingerprint: JSON.stringify(entry) })
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
function icon(idValue) {
  var name = idValue.split('.').pop()
  var icons = { clock: "󰥔", audio: "󰕾", network: "󰤨", bluetooth: "󰂯", power: "󰁹", monitor: "󰍹", workspaces: "󰙀", indicators: "󰍉", tray: "󰀱", media: "󰎆", weather: "󰖐", microphone: "󰍬", "keyboard-layout": "󰌌", "system-update": "󰚰", spacer: "↔", agents: "󰚩" }
  return icons[name] || "󰕰"
}

// Layout editor geometry. A cell is one zone × visibility pair; positions are
// indexes into its items ordered as the bar shows them.
function cell(entries, section, visibility, excludeKey) {
  return (entries || []).filter(function(e) {
    return e.section === section && e.mode === visibility && (!excludeKey || e.instanceKey !== excludeKey)
  }).sort(function(a, b) { return a.index - b.index })
}
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }
// Cursor over existing items. Walking past a cell's edge continues into the
// neighbouring zone on the same row; empty cells are valid resting places.
function stepCursor(count, cursor, dx, dy) {
  var s = sections.indexOf(cursor.section), m = modes.indexOf(cursor.mode), pos = cursor.pos
  if (dy) {
    m = clamp(m + dy, 0, modes.length - 1)
    pos = clamp(pos, 0, Math.max(0, count(sections[s], modes[m]) - 1))
  }
  if (dx) {
    pos += dx
    if (pos < 0) {
      if (s > 0) { s--; pos = Math.max(0, count(sections[s], modes[m]) - 1) } else pos = 0
    } else if (pos > Math.max(0, count(sections[s], modes[m]) - 1)) {
      if (s < sections.length - 1) { s++; pos = 0 } else pos = Math.max(0, count(sections[s], modes[m]) - 1)
    }
  }
  return { section: sections[s], mode: modes[m], pos: pos }
}
// Insertion point for a lifted item; count excludes the lifted item, so every
// cell offers count + 1 slots and the far edge of a zone hands over to the next.
function stepLift(count, target, dx, dy) {
  var s = sections.indexOf(target.section), m = modes.indexOf(target.mode), pos = target.pos
  if (dy) {
    m = clamp(m + dy, 0, modes.length - 1)
    pos = clamp(pos, 0, count(sections[s], modes[m]))
  }
  if (dx) {
    pos += dx
    if (pos < 0) {
      if (s > 0) { s--; pos = count(sections[s], modes[m]) } else pos = 0
    } else if (pos > count(sections[s], modes[m])) {
      if (s < sections.length - 1) { s++; pos = 0 } else pos = count(sections[s], modes[m])
    }
  }
  return { section: sections[s], mode: modes[m], pos: pos }
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
