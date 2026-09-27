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
