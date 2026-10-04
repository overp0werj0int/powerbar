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
// The font a group's icon is drawn in: the one saved with it, or for a group
// saved before icons kept their font, the stock list's. U+E900 is the Omarchy
// logo in Omarchy's font and another glyph in the bar's Nerd Font.
function groupIconFont(group) {
  return group ? group.iconFont || iconFont(group.icon) : ""
}
// What a group's face draws, as runs: its icon (a glyph in its font, or your
// own image), then for "both" two spaces and its name in the bar's font.
// face: "glyph" | "text" | "both" (defaults to the group's own).
function faceRuns(group, face) {
  if (!group) return []
  var f = face || group.face
  var icon = group.iconImage ? { kind: "image", source: group.iconImage, tint: group.iconTint !== "own" }
    : { kind: "text", text: group.icon, font: groupIconFont(group) }
  if (f === "text") return [{ kind: "text", text: group.label, font: "" }]
  if (f === "glyph") return [icon]
  return [icon, { kind: "gap", text: "  ", font: "" }, { kind: "text", text: group.label, font: "" }]
}
// The bar's text button draws a face as one string in one font. A face that
// shows your own image, or an icon in another font next to the name, is
// drawn as runs instead.
function needsRuns(group, face) {
  var f = face || (group && group.face)
  if (!group || f === "text") return false
  return !!group.iconImage || (f === "both" && groupIconFont(group) !== "")
}

// The instance keys in the layout, or null when there is no layout to check
// against (no entry has a key yet).
function layoutKeys(bar) {
  var layout = bar && bar.layout, keys = {}, any = false
  if (!layout || typeof layout !== "object") return null
  sections.forEach(function(section) {
    (Array.isArray(layout[section]) ? layout[section] : []).forEach(function(entry) {
      if (entry && typeof entry.powerbarInstance === "string" && entry.powerbarInstance) { keys[entry.powerbarInstance] = true; any = true }
    })
  })
  return any ? keys : null
}
// Saved members whose widget is no longer in the layout (uninstalled since it
// was grouped). groups() leaves them out; Bar writes the cleaned list once.
function danglingMembers(bar) {
  var known = layoutKeys(bar), count = 0
  if (!known) return 0
  ;(bar && Array.isArray(bar.powerbarGroups) ? bar.powerbarGroups : []).forEach(function(g) {
    ;(g && Array.isArray(g.items) ? g.items : []).forEach(function(key) {
      if (typeof key === "string" && key && key.indexOf("group:") !== 0 && !known[key]) count++
    })
  })
  return count
}
function groups(bar) {
  var ids = [], members = [], known = layoutKeys(bar)
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
      // Absent unless set, so groups that don't use them save as before.
      iconFont: g.iconFont === "omarchy" ? "omarchy" : undefined,
      iconImage: typeof g.iconImage === "string" && g.iconImage ? g.iconImage : undefined,
      iconTint: g.iconTint === "own" ? "own" : undefined,
      items: (Array.isArray(g.items) ? g.items : []).filter(function(key) {
        if (typeof key !== "string" || !key || key.indexOf("group:") === 0 || members.indexOf(key) >= 0) return false
        // A widget uninstalled since it was grouped is no longer a member.
        if (known && !known[key]) return false
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
  // A new icon replaces the old one whole: a glyph clears your own image,
  // and each icon keeps the font it was chosen in.
  if (typeof patch.icon === "string" && patch.icon) {
    group.icon = patch.icon
    group.iconFont = patch.iconFont === "omarchy" ? "omarchy" : undefined
    group.iconImage = undefined
  }
  if (typeof patch.iconImage === "string" && patch.iconImage) group.iconImage = patch.iconImage
  if (patch.iconTint === "text" || patch.iconTint === "own") group.iconTint = patch.iconTint === "own" ? "own" : undefined
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
// A group sits before its anchor entry. When that entry moves away, the group
// keeps its place: it re-anchors on the entry that followed (or the zone's end).
// Call nextAnchor before the move and reanchor after it.
function nextAnchor(config, section, key) {
  var entries = (config && config.bar && config.bar.layout && config.bar.layout[section]) || []
  var at = entries.findIndex(function(entry) { return entry && entry.powerbarInstance === key })
  var next = at >= 0 ? entries[at + 1] : null
  return next && next.powerbarInstance || ""
}
function reanchor(config, section, key, next) {
  if (!config || !config.bar || !key) return false
  // Still right before the same entry (a visibility change in place): the
  // group is already where it was.
  if (nextAnchor(config, section, key) === next && ((config.bar.layout || {})[section] || []).some(function(entry) {
    return entry && entry.powerbarInstance === key
  })) return false
  var list = groups(config.bar), changed = false
  list.forEach(function(g) {
    if (g.section === section && g.before === key && next !== key) { g.before = next; changed = true }
  })
  if (changed) config.bar.powerbarGroups = list
  return changed
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
