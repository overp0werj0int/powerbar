// Powerbar from the command line (README, "Command line"): what each setting
// is called, which shell.json key it lives in, what values it takes and which
// of Preferences' writers changes it. Pure rules; BarCli.qml reads the live
// values and writes through Preferences and the bar, the way the pages do.
//
// Writers: "option"  Preferences.setOption(key, value) (bar.<key>)
//          "style"   Preferences.setBarStyle(value)
//          "scope"   Preferences.setScope(tile, value)
//          "look"    Preferences.setLook(tile, look, value)
//          "text"    Preferences.setText(value)
// Ranges are the sliders' (AppearanceModel.ranges); "roundingMax" is the
// bar's own (it depends on the bar's thickness) and comes in as ctx.
var settings = [
  { name: "position", key: "position", type: "choice", choices: ["top", "bottom", "left", "right"], writer: "option" },
  { name: "background", key: "background", type: "choice", choices: ["opaque", "glassy", "none"], writer: "option" },
  // The older on/off form of background: none or opaque.
  { name: "transparent", key: "transparent", type: "bool", writer: "option" },
  { name: "style", key: "powerbarStyle", type: "choice", choices: ["flat", "floating", "islands", "notch"], writer: "style" },
  { name: "largeBar", key: "powerbarLargeBar", type: "bool", writer: "option" },
  { name: "spacingMode", key: "powerbarSpacingMode", type: "choice", choices: ["slots", "gaps"], writer: "option" },
  { name: "spacing", key: "powerbarSpacing", type: "number", min: 0, max: 16, step: 1, writer: "option" },
  { name: "autoHide", key: "powerbarAutoHide", type: "bool", writer: "option" },
  { name: "autoHideActivity", key: "powerbarAutoHideActivity", type: "bool", writer: "option" },
  { name: "readableOverlay", key: "powerbarReadableOverlay", type: "bool", writer: "option" },
  { name: "animations", key: "powerbarAnimations", type: "bool", writer: "option" },
  { name: "onDemand", key: "powerbarOnDemand", type: "choice", choices: ["drawer", "inline", "menu"], writer: "option" },
  { name: "dotsBadge", key: "powerbarDotsBadge", type: "bool", writer: "option" },
  { name: "keyLegend", key: "powerbarKeyLegend", type: "bool", writer: "option" },
  // Not in Preferences; shell.json keys kept for anyone who sets them by hand.
  { name: "revealSeconds", key: "powerbarManagedRevealSeconds", type: "number", min: 1, max: 60, writer: "option" },
  { name: "entryGraceSeconds", key: "powerbarManagedEntryGraceSeconds", type: "number", min: 1, max: 15, writer: "option" },
  { name: "exitGraceSeconds", key: "powerbarManagedExitGraceSeconds", type: "number", min: 1, max: 15, writer: "option" },
  { name: "frameLog", key: "powerbarFrameLog", type: "bool", writer: "option" },
  // A camera notch's width in logical px.
  { name: "notchWidth", key: "powerbarNotchWidth", type: "number", min: 40, max: 600, step: 1, writer: "option" },
  // Its height in logical px, on a notched screen.
  { name: "notchHeight", key: "powerbarNotchHeight", type: "number", min: 16, max: 96, step: 1, writer: "option" },
  // Which side of the camera the Center zone sits on, on a notched screen.
  { name: "centerSide", key: "powerbarCenterSide", type: "choice", choices: ["right", "left"], writer: "option" },
  // Appearance (bar.powerbarAppearance), in the scope each tile follows now.
  { name: "shape.scope", tile: "shape", type: "choice", choices: ["theme", "all", "this"], writer: "scope" },
  { name: "shape.rounding", tile: "shape", look: "rounding", type: "number", min: 0, max: "roundingMax", step: 1, writer: "look" },
  { name: "shape.borders", tile: "shape", look: "borders", type: "bool", writer: "look" },
  { name: "shape.borderWidth", tile: "shape", look: "borderWidth", type: "number", min: 0.5, max: 3, step: 0.5, writer: "look" },
  { name: "surface.scope", tile: "surface", type: "choice", choices: ["theme", "all", "this"], writer: "scope" },
  { name: "surface.opacity", tile: "surface", look: "opacity", type: "number", min: 0, max: 100, step: 5, writer: "look" },
  { name: "surface.blur", tile: "surface", look: "blur", type: "bool", writer: "look" },
  { name: "surface.text", tile: "surface", type: "choice", choices: ["theme", "light", "dark"], writer: "text" },
  { name: "shadow.scope", tile: "shadow", type: "choice", choices: ["theme", "all", "this"], writer: "scope" },
  { name: "shadow.enabled", tile: "shadow", look: "enabled", type: "bool", writer: "look" },
  { name: "shadow.softness", tile: "shadow", look: "softness", type: "number", min: 2, max: 24, step: 1, writer: "look" },
  { name: "shadow.strength", tile: "shadow", look: "strength", type: "number", min: 5, max: 60, step: 5, writer: "look" }
]
// Shortcuts: "shortcut.bar:keys", "shortcut.bar:search", "shortcut.group:<id>", "shortcut.widget:<id>".
var shortcutPrefix = "shortcut."

// Settings earlier versions had, and what took their place.
var retired = {
  zones: "zones are always five; see set style notch",
  powerbarZones: "zones are always five; see set style notch",
  centerAnchor: "the center box is the Center zone; move a widget there with setWidget <widget> {\"zone\":\"center\"}"
}
function retiredNote(name) { return retired[String(name || "").trim()] || "" }
// A setting by its name or its shell.json key (powerbarAutoHide), or a
// shortcut setting; null when there is none.
function find(name) {
  var n = String(name || "").trim()
  if (n.indexOf(shortcutPrefix) === 0 && n.length > shortcutPrefix.length)
    return { name: n, target: n.slice(shortcutPrefix.length), type: "shortcut", writer: "shortcut" }
  return settings.find(function(s) { return s.name === n || (s.key && s.key === n) }) || null
}
function names() { return settings.map(function(s) { return s.name }) }

// What a value on the command line means: JSON when it parses (true, 12,
// "text", {…}), else the text itself (inline, SUPER + B).
function parseValue(text) {
  var t = String(text === undefined || text === null ? "" : text)
  try { return JSON.parse(t) } catch (e) { return t }
}

function decimals(n) { var s = String(n), dot = s.indexOf("."); return dot < 0 ? 0 : s.length - dot - 1 }
function onStep(value, min, step) {
  var scale = Math.pow(10, Math.max(decimals(step), decimals(min), decimals(value)))
  return Math.round((value - min) * scale) % Math.round(step * scale) === 0
}
// { value } a setting may take, or { error }. ctx: { roundingMax }.
function check(setting, value, ctx) {
  if (!setting) return { error: "unknown setting" }
  var s = setting
  if (s.type === "bool") {
    if (value === "on") value = true
    if (value === "off") value = false
    return typeof value === "boolean" ? { value: value } : { error: s.name + " is true or false" }
  }
  if (s.type === "choice") {
    return s.choices.indexOf(value) >= 0 ? { value: value } : { error: s.name + " is one of " + s.choices.join(", ") }
  }
  if (s.type === "string") {
    return typeof value === "string" ? { value: value } : { error: s.name + " is a text value" }
  }
  if (s.type === "number") {
    var max = s.max === "roundingMax" ? (ctx && ctx.roundingMax) : s.max
    if (typeof value !== "number" || !isFinite(value)) return { error: s.name + " is a number" }
    if (value < s.min || (max !== undefined && value > max))
      return { error: s.name + " is from " + s.min + " to " + max }
    if (s.step && !onStep(value, s.min, s.step)) return { error: s.name + " moves in steps of " + s.step }
    return { value: value }
  }
  if (s.type === "shortcut") return shortcutValue(value)
  return { error: "unknown setting" }
}

// A shortcut's value: "SUPER + B", "" (no shortcut: Omarchy's own goes too),
// or { keys, replace: true } to take keys another bind holds, as Preferences'
// confirmation does. → { keys, replace } or { error }.
function shortcutValue(value) {
  if (typeof value === "string") return { value: { keys: value.trim(), replace: false } }
  if (value && typeof value === "object" && !Array.isArray(value) && typeof value.keys === "string")
    return { value: { keys: value.keys.trim(), replace: value.replace === true } }
  return { error: "a shortcut is keys such as \"SUPER + B\", \"\" for none, or {\"keys\": \"…\", \"replace\": true}" }
}
// Whether a shortcut target names something that can have one. ctx: { groups:
// [ids] }. Widgets are named by plugin id, as Omarchy's own binds name them.
function shortcutTarget(target, ctx) {
  var t = String(target || "")
  if (t === "bar:keys" || t === "bar:search") return ""
  if (t.indexOf("group:") === 0) {
    return (ctx && ctx.groups || []).indexOf(t.slice(6)) >= 0 ? "" : "no group " + t.slice(6)
  }
  if (t.indexOf("widget:") === 0 && t.length > 7)
    return /^[A-Za-z0-9_.\-]+$/.test(t.slice(7)) ? "" : "a widget id is letters, digits, dots, dashes and underscores"
  return "a shortcut target is bar:keys, bar:search, group:<id> or widget:<plugin id>"
}

// Boolean settings flip with `toggle`.
function toggled(setting, current) {
  if (!setting || setting.type !== "bool") return { error: (setting ? setting.name : "that") + " is not a switch" }
  return { value: current !== true }
}

// ---- widgets ---------------------------------------------------------------
// A layout record (PreferencesModel.records) named by its powerbarInstance key,
// or by its plugin id when only one instance is on the bar.
function widgetRecord(records, selector) {
  var sel = String(selector || "").trim(), list = records || []
  if (!sel) return { error: "name a widget by its id or instance" }
  var byKey = list.find(function(r) { return r.instanceKey && r.instanceKey === sel })
  if (byKey) return { record: byKey }
  var byId = list.filter(function(r) { return r.id === sel })
  if (byId.length === 1) return { record: byId[0] }
  if (byId.length > 1) return { error: sel + " is on the bar " + byId.length + " times; name one instance: "
    + byId.map(function(r) { return r.instanceKey }).join(", ") }
  return { error: "no widget " + sel + " in the layout" }
}
// The five zones (SectionsModel.lists).
var sections = ["left", "centerBegin", "center", "centerEnd", "right"]
var visibilities = ["shown", "managed", "hidden"]
var widgetFields = ["zone", "visibility", "before", "group", "activityPeek", "badgeProperty", "urgentProperty"]
// A widget change from the command line, checked whole before anything is
// written. → { patch } or { error }. ctx: { groups: [ids] }.
function widgetPatch(patch, ctx) {
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) return { error: "a widget change is a JSON object such as {\"visibility\":\"managed\"}" }
  var unknown = Object.keys(patch).filter(function(k) { return widgetFields.indexOf(k) < 0 })
  if (unknown.length) return { error: "unknown field " + unknown[0] + "; fields are " + widgetFields.join(", ") }
  if (patch.zone !== undefined && sections.indexOf(patch.zone) < 0) return { error: "zone is one of " + sections.join(", ") }
  if (patch.visibility !== undefined && visibilities.indexOf(patch.visibility) < 0) return { error: "visibility is one of " + visibilities.join(", ") }
  if (patch.before !== undefined && typeof patch.before !== "string") return { error: "before names a widget, or \"\" for the zone's end" }
  if (patch.group !== undefined && (typeof patch.group !== "string" || (patch.group && (ctx && ctx.groups || []).indexOf(patch.group) < 0)))
    return { error: "group is a group's id, or \"\" for none" }
  var flags = ["activityPeek"], props = ["badgeProperty", "urgentProperty"]
  for (var i = 0; i < flags.length; i++)
    if (patch[flags[i]] !== undefined && typeof patch[flags[i]] !== "boolean") return { error: flags[i] + " is true or false" }
  for (var j = 0; j < props.length; j++)
    if (patch[props[j]] !== undefined && typeof patch[props[j]] !== "string") return { error: props[j] + " is a property name, or \"\" for the default" }
  return { patch: patch }
}
// Where a moved widget lands, as Preferences.move takes it: the layout index
// to insert before (-1: the zone's end). A widget that only changes
// visibility keeps its place, as the settings tile keeps it.
// A neighbour named by `before` brings the widget to its zone. → { section,
// mode, before, changed } or { error }.
function placement(record, patch, beforeRecord) {
  if (beforeRecord && beforeRecord.instanceKey === record.instanceKey) return { error: "a widget can't go before itself" }
  if (beforeRecord && patch.zone && beforeRecord.section !== patch.zone)
    return { error: "before names a widget in the " + beforeRecord.section + " zone, not " + patch.zone }
  var section = beforeRecord ? beforeRecord.section : patch.zone || record.section
  var mode = patch.visibility || record.mode
  var before = beforeRecord ? beforeRecord.index
    : patch.before === "" || section !== record.section ? -1 : record.index + 1
  return { section: section, mode: mode, before: before,
    changed: section !== record.section || mode !== record.mode || patch.before !== undefined }
}

// ---- groups ----------------------------------------------------------------
// A group (GroupsModel.groups) by its id, or by its name when it is unique.
// A widget change names its group by id or, when unique, by name: the name
// becomes the id before the change is checked. → { value } or { error }.
function widgetGroupById(value, groups) {
  if (!value || typeof value !== "object" || typeof value.group !== "string" || !value.group) return { value: value }
  var found = groupRecord(groups, value.group)
  if (found.error) return { error: found.error }
  return { value: Object.assign({}, value, { group: found.group.id }) }
}
function groupRecord(groups, selector) {
  var sel = String(selector || "").trim(), list = groups || []
  var byId = list.find(function(g) { return g.id === sel })
  if (byId) return { group: byId }
  var byLabel = list.filter(function(g) { return g.label === sel })
  if (byLabel.length === 1) return { group: byLabel[0] }
  if (byLabel.length > 1) return { error: byLabel.length + " groups are called " + sel + "; name one by id: "
    + byLabel.map(function(g) { return g.id }).join(", ") }
  return { error: "no group " + sel }
}
var groupChoices = {
  visibility: visibilities, face: ["glyph", "text", "both"], badgeMode: ["sum", "members"],
  memberDisplay: ["native", "name", "both"],
  iconTint: ["text", "own"], iconFont: ["", "omarchy"]
}
var groupFields = ["label", "icon", "iconFont", "iconImage", "iconTint", "zone", "before", "visibility",
  "face", "tooltip", "badge", "badgeMode", "memberDisplay", "members"]
// A group change, checked whole. → { patch } in GroupsModel.edit's terms
// (zone becomes section) plus `members` (selectors) and `before` (a widget
// selector, resolved by the caller), or { error }.
function groupPatch(patch) {
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) return { error: "a group change is a JSON object such as {\"label\":\"Media\"}" }
  var out = {}
  for (var k in patch) {
    var v = patch[k]
    if (groupFields.indexOf(k) < 0) return { error: "unknown field " + k + "; fields are " + groupFields.join(", ") }
    if (groupChoices[k] && groupChoices[k].indexOf(v) < 0) return { error: k + " is one of " + groupChoices[k].filter(Boolean).join(", ") }
    if ((k === "tooltip" || k === "badge") && typeof v !== "boolean") return { error: k + " is true or false" }
    if (k === "label" && (typeof v !== "string" || !v.trim())) return { error: "label is a name" }
    if ((k === "icon" || k === "iconImage") && (typeof v !== "string" || !v)) return { error: k + " is a glyph or an image path" }
    // Refused rather than cut, so the answer never says ok for a value that
    // was not kept whole (Groups keeps labels to 80 characters).
    if (k === "label" && v.trim().length > 80) return { error: "label is at most 80 characters" }
    if (k === "icon" && Array.from(v).length > 8) return { error: "icon is one glyph or emoji" }
    // GroupsModel.imagePath()'s rule: a local file, never a URL.
    if (k === "iconImage" && (v.length > 1024 || !/^\/[^\x00-\x1f\x7f]*\.(svg|png)$/i.test(v) || /(^|\/)\.\.(\/|$)/.test(v)))
      return { error: "iconImage is an absolute path to an SVG or PNG" }
    if (k === "before" && typeof v !== "string") return { error: "before names a widget, or \"\" for the zone's end" }
    if (k === "zone") {
      if (sections.indexOf(v) < 0) return { error: "zone is one of " + sections.join(", ") }
      out.section = v
      continue
    }
    if (k === "members" && (!Array.isArray(v) || v.some(function(m) { return typeof m !== "string" || !m })))
      return { error: "members is a list of widgets, by id or instance" }
    out[k] = v
  }
  if (out.iconFont !== undefined && out.icon === undefined) return { error: "iconFont goes with icon" }
  return { patch: out }
}
// The membership edits that turn `current` (instance keys, in order) into
// `next`: who leaves, then who joins or moves, appended in order. Each step is
// a GroupsModel.assign(config, key, id, before).
function memberSteps(current, next) {
  var steps = []
  ;(current || []).forEach(function(key) { if (next.indexOf(key) < 0) steps.push({ key: key, group: false }) })
  next.forEach(function(key) { steps.push({ key: key, group: true }) })
  return steps
}

// ---- the IPC surface -------------------------------------------------------
// What `omarchy-shell powerbar help` lists.
var functions = [
  ["status", "", "every setting, widget, group and shortcut, and what the bar is doing, as JSON"],
  ["get", "<setting>", "one setting's value, as JSON"],
  ["set", "<setting> <value>", "change a setting (JSON, or plain text); \"ok\" or why not"],
  ["reset", "<setting>", "return a setting to its default"],
  ["toggle", "<setting>", "flip a true/false setting"],
  ["settings", "", "every setting with its type, values and shell.json key"],
  ["widgets", "", "the layout: each widget's zone, visibility, group and settings"],
  ["setWidget", "<widget> <json>", "move or change a widget: zone, visibility, before, group, activityPeek, badgeProperty, urgentProperty"],
  ["groups", "", "every group, with its members"],
  ["newGroup", "<name>", "make a group; answers its id"],
  ["setGroup", "<group> <json>", "change a group: label, icon, zone, visibility, face, badge, members…"],
  ["removeGroup", "<group>", "dissolve a group (its widgets stay)"],
  ["shortcuts", "", "every Powerbar shortcut and what holds its keys"],
  ["clearShortcuts", "", "remove every shortcut Powerbar set and its block in bindings.lua (Omarchy's own come back); do this before removing Powerbar"],
  ["show", "", "bring the bar out: an autohidden bar stays out until hide; a bar switched off comes back"],
  ["hide", "", "let an autohidden bar slide away, or switch the bar off (omarchy toggle bar)"],
  ["keys", "", "toggle the keyboard mode on the focused monitor's bar"],
  ["keysOn", "", "start the keyboard mode"],
  ["keysOff", "", "end the keyboard mode"],
  ["keysSearch", "", "start the keyboard mode with its search (/) open, or end it while a search is open"],
  ["keysStatus", "", "the keyboard mode's state, as JSON"],
  ["managed", "<zone>", "open a zone's On demand drawer for the keyboard (left, centerBegin, center, centerEnd, right)"],
  ["closeManaged", "", "close the open drawer or group menu"],
  ["group", "<id>", "open a group's drawer"],
  ["toggleGroup", "<id>", "open or close a group's drawer"],
  ["drawerStatus", "", "the open drawer, as JSON"],
  ["managedStatus", "", "On demand widgets: where they are and whether they show, as JSON"],
  ["popupStatus", "", "the open widget panel, as JSON"],
  ["preferences", "", "open Preferences on the focused monitor"],
  ["preferencesPage", "<1-4>", "open Preferences at Layout (1), Groups (2), Look (3) or Behavior (4)"],
  ["preferencesKeyboard", "", "open Preferences at the keyboard mode's shortcuts (Behavior → Keyboard)"],
  ["groupsPreferences", "", "open Preferences at Groups"],
  ["closePreferences", "", "close Preferences"],
  ["build", "", "the code this shell is running: version, digest of the loaded files, git commit, when it loaded (tools/build-check.sh compares it with a checkout)"],
  ["help", "", "this list"]
]
function help() {
  return functions.map(function(f) { return { call: "omarchy-shell powerbar " + f[0] + (f[1] ? " " + f[1] : ""), does: f[2] } })
}
// Every setting as `settings` describes it.
function describe(ctx) {
  return settings.map(function(s) {
    var d = { name: s.name, type: s.type }
    if (s.key) d.key = "bar." + s.key
    else d.key = "bar.powerbarAppearance"
    if (s.choices) d.values = s.choices
    if (s.type === "number") { d.min = s.min; d.max = s.max === "roundingMax" ? (ctx && ctx.roundingMax) : s.max; if (s.step) d.step = s.step }
    return d
  }).concat([{ name: "shortcut.<target>", type: "shortcut", key: "bar.powerbarShortcuts",
    targets: ["bar:keys", "bar:search", "group:<id>", "widget:<plugin id>"] }])
}
