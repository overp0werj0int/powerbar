// Groups reference existing widget instances; settings and enablement stay in
// bar.layout. Removing a group therefore cannot delete a widget or its service.
var sections = ["left", "center", "right"]
// Representative glyphs from the stock Omarchy bar widgets and indicators.
var icons = [
  { name: "Group", glyph: "󰉋" },
  { name: "Omarchy menu", glyph: "\ue900", font: "omarchy" },
  { name: "Workspaces", glyph: "\uDB85\uDCFB" },
  { name: "Audio", glyph: "" }, { name: "Audio muted", glyph: "" },
  { name: "Headphones", glyph: "󰋋" },
  { name: "Microphone", glyph: "󰍬" }, { name: "Microphone muted", glyph: "󰍭" },
  { name: "Wi-Fi", glyph: "󰤨" }, { name: "Ethernet", glyph: "󰈀" },
  { name: "Network offline", glyph: "󰤮" },
  { name: "Bluetooth", glyph: "󰂯" }, { name: "Bluetooth connected", glyph: "󰂱" },
  { name: "Display", glyph: "󰍹" }, { name: "Multiple displays", glyph: "󰍺" },
  { name: "Battery", glyph: "󰁹" }, { name: "Clock", glyph: "󰥔" },
  { name: "Media play", glyph: "󰐊" }, { name: "Media pause", glyph: "󰏤" },
  { name: "Music", glyph: "󰝚" }, { name: "Keyboard", glyph: "󰌌" },
  { name: "System update", glyph: "\uf021" }, { name: "Weather", glyph: "󰖐" }
]
function iconFont(glyph) {
  var entry = icons.find(function(icon) { return icon.glyph === glyph })
  return entry && entry.font || ""
}

function groups(bar) {
  var ids = [], members = []
  return (bar && Array.isArray(bar.powerbarGroups) ? bar.powerbarGroups : []).filter(function(g) {
    if (!g || typeof g.id !== "string" || !g.id || ids.indexOf(g.id) >= 0) return false
    ids.push(g.id); return true
  }).map(function(g) {
    return { id: g.id, label: String(g.label || "Group"), icon: String(g.icon || icons[0].glyph),
      section: sections.indexOf(g.section) >= 0 ? g.section : "right", before: String(g.before || ""),
      visibility: ["shown", "managed", "hidden"].indexOf(g.visibility) >= 0 ? g.visibility : "shown",
      face: ["glyph", "text", "both"].indexOf(g.face) >= 0 ? g.face : "glyph",
      tooltip: typeof g.tooltip === "boolean" ? g.tooltip : undefined,
      badge: g.badge !== false,
      badgeMode: g.badgeMode === "members" ? "members" : "sum",
      orientation: ["auto", "horizontal", "vertical"].indexOf(g.orientation) >= 0 ? g.orientation : "auto",
      memberDisplay: ["native", "name", "both"].indexOf(g.memberDisplay) >= 0 ? g.memberDisplay : "native",
      items: (Array.isArray(g.items) ? g.items : []).filter(function(key) {
        if (typeof key !== "string" || !key || key.indexOf("group:") === 0 || members.indexOf(key) >= 0) return false
        members.push(key); return true
      }) }
  })
}
function owner(list, key) { return list.find(function(g) { return g.items.indexOf(key) >= 0 }) || null }
function create(config, id, label) {
  if (!config.bar) config.bar = {}
  var list = groups(config.bar)
  if (!id || list.some(function(g) { return g.id === id })) return false
  list.push({ id: id, label: label || "New group", icon: icons[0].glyph, section: "right", before: "", items: [] })
  config.bar.powerbarGroups = list; return true
}
function edit(config, id, patch) {
  var list = groups(config.bar), group = list.find(function(g) { return g.id === id })
  if (!group) return false
  if (typeof patch.label === "string" && patch.label.trim()) group.label = patch.label.trim().slice(0, 80)
  if (typeof patch.icon === "string" && patch.icon) group.icon = patch.icon
  if (sections.indexOf(patch.section) >= 0) { group.section = patch.section; group.before = "" }
  if (typeof patch.before === "string") group.before = patch.before
  if (["shown", "managed", "hidden"].indexOf(patch.visibility) >= 0) group.visibility = patch.visibility
  if (["glyph", "text", "both"].indexOf(patch.face) >= 0) group.face = patch.face
  if (typeof patch.tooltip === "boolean") group.tooltip = patch.tooltip
  if (typeof patch.badge === "boolean") group.badge = patch.badge
  if (["sum", "members"].indexOf(patch.badgeMode) >= 0) group.badgeMode = patch.badgeMode
  if (["auto", "horizontal", "vertical"].indexOf(patch.orientation) >= 0) group.orientation = patch.orientation
  if (["native", "name", "both"].indexOf(patch.memberDisplay) >= 0) group.memberDisplay = patch.memberDisplay
  config.bar.powerbarGroups = list; return true
}
function moveHeader(config, id, section, beforeKey, relativeGroupId, after, visibility) {
  if (!config || !config.bar || sections.indexOf(section) < 0) return false
  if (visibility !== "shown" && visibility !== "managed") return false
  var list = groups(config.bar), source = list.find(function(g) { return g.id === id })
  if (!source || relativeGroupId === id) return false
  var target = relativeGroupId ? list.find(function(g) { return g.id === relativeGroupId }) : null
  if (relativeGroupId && !target) return false
  if (!target && beforeKey && !((config.bar.layout && config.bar.layout[section]) || []).some(function(entry) {
    return entry && entry.powerbarInstance === beforeKey
  })) return false
  list.splice(list.indexOf(source), 1)
  if (target) {
    source.section = target.section
    source.before = target.before
    list.splice(list.indexOf(target) + (after ? 1 : 0), 0, source)
  } else {
    source.section = section
    source.before = beforeKey || ""
    list.push(source)
  }
  source.visibility = visibility
  config.bar.powerbarGroups = list
  return true
}
function remove(config, id) {
  var list = groups(config.bar), next = list.filter(function(g) { return g.id !== id })
  if (next.length === list.length) return false
  config.bar.powerbarGroups = next; return true
}
function assign(config, key, id, before) {
  var list = groups(config.bar), destination = list.find(function(g) { return g.id === id })
  if (id && !destination) return false
  var exists = sections.some(function(section) {
    return (config.bar.layout[section] || []).some(function(e) { return e && e.powerbarInstance === key })
  })
  if (!exists || key.indexOf("group:") === 0) return false
  if (before === key) return false
  list.forEach(function(g) { g.items = g.items.filter(function(item) { return item !== key }) })
  if (destination) {
    var index = destination.items.indexOf(before)
    destination.items.splice(index < 0 ? destination.items.length : index, 0, key)
  }
  config.bar.powerbarGroups = list; return true
}
function render(layout, list) {
  var result = {}
  sections.forEach(function(section) {
    result[section] = (layout[section] || []).slice()
    list.filter(function(g) { return g.section === section && g.visibility !== "hidden" }).forEach(function(g) {
      var at = result[section].findIndex(function(e) { return e.powerbarInstance === g.before })
      result[section].splice(at < 0 ? result[section].length : at, 0, {
        id: "powerbar.group." + g.id, type: "group", powerbarGroupId: g.id,
        powerbarInstance: "group:" + g.id, powerbarVisibility: g.visibility || "shown"
      })
    })
  })
  return result
}
