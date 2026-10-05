// Shortcuts for widgets and groups (README, "Shortcuts"). Pure rules; the
// Preferences' ShortcutStore reads Hyprland and writes the files.
//
// A shortcut is a Hyprland key string, "SUPER + CTRL + A". Widgets keep
// Omarchy's own way of opening a panel, `omarchy-shell shell toggle <id>`, so
// Omarchy's shortcuts (Super+Ctrl+A for Audio) and Powerbar's are the same
// kind of bind. Groups open their drawer: `omarchy-shell powerbar toggleGroup
// <id>`. Changes live in the bar config (`powerbarShortcuts`, keyed
// "widget:<id>" or "group:<id>"; "" removes Omarchy's) and become
// ~/.config/hypr/powerbar.lua, which takes each key over before binding it.

var MODS = ["SUPER", "CTRL", "ALT", "SHIFT"]
var MASK = { SHIFT: 1, CAPS: 2, CTRL: 4, CONTROL: 4, ALT: 8, MOD2: 16, MOD3: 32, SUPER: 64, WIN: 64, LOGO: 64, MOD4: 64, MOD5: 128 }
var DESCRIPTION = "Powerbar: "
var SUBMAP = "powerbar-record"

// Keys whose names read differently from Hyprland's spelling.
var LABELS = { SPACE: "Space", RETURN: "Enter", TAB: "Tab", ESCAPE: "Esc", BACKSPACE: "Backspace", DELETE: "Del",
  HOME: "Home", END: "End", PRIOR: "PgUp", NEXT: "PgDn", LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓", INSERT: "Ins",
  PRINT: "Print", COMMA: ",", PERIOD: ".", SLASH: "/", SEMICOLON: ";", APOSTROPHE: "'", BRACKETLEFT: "[",
  BRACKETRIGHT: "]", MINUS: "-", EQUAL: "=", GRAVE: "`", BACKSLASH: "\\" }
// Hardware keycodes (evdev + 8) Omarchy binds by position, as the US layout
// prints them.
var CODES = { 10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0",
  20: "-", 21: "=", 34: "[", 35: "]", 47: ";", 48: "'", 49: "`", 51: "\\", 59: ",", 60: ".", 61: "/" }

// "super+ctrl + a" → { mask: 68, key: "A" }; null without a key.
function parse(keys) {
  var parts = String(keys || "").split("+").map(function(p) { return p.trim() }).filter(function(p) { return p !== "" })
  if (!parts.length) return null
  var mask = 0
  for (var i = 0; i < parts.length - 1; i++) {
    var m = MASK[parts[i].toUpperCase()]
    if (m === undefined) return null
    mask |= m
  }
  var key = parts[parts.length - 1]
  if (MASK[key.toUpperCase()] !== undefined) return null
  return { mask: mask, key: /^code:/i.test(key) ? "code:" + key.slice(5) : key.toUpperCase() }
}

// The one spelling Powerbar writes and compares: modifiers in Omarchy's usual
// order, then the key.
function format(sig) {
  if (!sig) return ""
  var out = []
  if (sig.mask & 64) out.push("SUPER")
  if (sig.mask & 4) out.push("CTRL")
  if (sig.mask & 8) out.push("ALT")
  if (sig.mask & 1) out.push("SHIFT")
  if (sig.mask & 128) out.push("MOD5")
  out.push(sig.key)
  return out.join(" + ")
}
function normalize(keys) { return format(parse(keys)) }
function same(a, b) { var x = normalize(a); return x !== "" && x === normalize(b) }

// The keycaps a shortcut shows: ["Super", "Ctrl", "A"].
function caps(keys) {
  var sig = parse(keys)
  if (!sig) return []
  var out = []
  if (sig.mask & 64) out.push("Super")
  if (sig.mask & 4) out.push("Ctrl")
  if (sig.mask & 8) out.push("Alt")
  if (sig.mask & 1) out.push("Shift")
  if (sig.mask & 128) out.push("AltGr")
  var k = sig.key
  if (/^code:/.test(k)) out.push(CODES[Number(k.slice(5))] || k)
  else if (LABELS[k]) out.push(LABELS[k])
  else if (/^F\d+$/.test(k) || k.length === 1) out.push(k)
  else if (/^XF86/i.test(k)) out.push(k.replace(/^XF86/i, ""))
  else out.push(k.charAt(0) + k.slice(1).toLowerCase())
  return out
}
function label(keys) { return caps(keys).join(" ") }

// hyprctl binds (plain text: its JSON drops `code:` keys) → [{ keys, mask,
// key, description, submap }]. Records are blocks of "name: value" lines.
function parseBinds(text) {
  var out = []
  String(text || "").split(/\n\s*\n/).forEach(function(block) {
    var rec = {}
    block.split("\n").forEach(function(line) {
      var m = line.match(/^\s*(\w+):\s?(.*)$/)
      if (m) rec[m[1]] = m[2]
    })
    if (rec.key === undefined || rec.modmask === undefined) return
    var parts = rec.key.split("+")
    var key = parts[parts.length - 1].trim()
    if (!key) return
    var sig = { mask: Number(rec.modmask) || 0, key: /^code:/i.test(key) ? "code:" + key.slice(5) : key.toUpperCase() }
    out.push({ keys: format(sig), mask: sig.mask, key: sig.key, description: rec.description || "", submap: rec.submap || "" })
  })
  return out
}

// Shortcuts to widgets already in Hyprland's config files: binds that run
// `omarchy-shell shell toggle <id>` (by id), and the ranges that run
// `togglePanelAt <section> N` (by position). origin: "omarchy" for Omarchy's
// defaults, "config" for the user's own files. → { widgets: [{ keys,
// description, id, origin }], positions: [{ section, n, keys }] }.
function parseDefaults(lua, origin) {
  var text = String(lua || ""), widgets = [], positions = []
  var byId = /(?:o\.bind|hl\.bind)\(\s*"([^"]+)"\s*,\s*(?:"([^"]*)"\s*,\s*)?(?:hl\.dsp\.exec_cmd\(\s*)?"omarchy-shell(?:\s+-q)?\s+shell\s+toggle\s+([\w.\-]+)/g
  var m
  while ((m = byId.exec(text))) {
    var keys = normalize(m[1])
    if (keys) widgets.push({ keys: keys, description: m[2] || "", id: m[3], origin: origin || "omarchy" })
  }
  // for panel = 1, 9 do o.bind("SUPER + CTRL + code:" .. tostring(panel + 9), ..., "... togglePanelAt right " .. panel)
  var range = /for\s+(\w+)\s*=\s*(\d+)\s*,\s*(\d+)\s+do[\s\S]*?"([^"]*?)code:"\s*\.\.\s*tostring\(\s*\1\s*\+\s*(\d+)\s*\)[\s\S]*?togglePanelAt\s+(\w+)\s+"\s*\.\.\s*\1/g
  while ((m = range.exec(text))) {
    for (var n = Number(m[2]); n <= Number(m[3]); n++)
      positions.push({ section: m[6], n: n, keys: normalize(m[4] + "code:" + (n + Number(m[5]))) })
  }
  return { widgets: widgets, positions: positions }
}
// Files in load order: a later file's shortcut for a widget wins.
// files: [{ text, origin }].
function readDefaults(files) {
  var out = { widgets: [], positions: [] }
  ;(files || []).forEach(function(f) {
    var d = parseDefaults(f.text, f.origin)
    out.widgets = out.widgets.filter(function(w) { return !d.widgets.some(function(n) { return n.id === w.id }) }).concat(d.widgets)
    out.positions = out.positions.concat(d.positions)
  })
  return out
}

// Whether a bind with these keys (and, when given, this description) is live.
function live(binds, keys, description) {
  var k = normalize(keys)
  return (binds || []).some(function(b) { return !b.submap && b.keys === k && (description === undefined || b.description === description) })
}

// A target's shortcut: { keys, source } where source is "omarchy" (Omarchy's,
// still bound), "config" (from the user's own Hyprland files), "yours" (set
// in Powerbar), "removed" (one of those, taken away) or "none"; `fallback`
// is the one from the files when it differs.
// target: "widget:<id>" or "group:<id>"; config: powerbarShortcuts.
function effective(target, config, defaults, binds) {
  var mine = config && Object.prototype.hasOwnProperty.call(config, target) ? normalize(config[target]) : null
  var id = target.indexOf("widget:") === 0 ? target.slice(7) : ""
  var omarchy = id ? ((defaults && defaults.widgets) || []).find(function(d) { return d.id === id }) || null : null
  var omarchyLive = !!omarchy && live(binds, omarchy.keys, omarchy.description)
  if (mine !== null && config[target] !== "" && mine !== "")
    return { keys: mine, source: "yours", fallback: omarchy && !same(omarchy.keys, mine) ? omarchy.keys : "" }
  if (mine !== null) return { keys: "", source: omarchy ? "removed" : "none", fallback: omarchy ? omarchy.keys : "" }
  if (omarchyLive) return { keys: omarchy.keys, source: omarchy.origin === "config" ? "config" : "omarchy", fallback: "" }
  return { keys: "", source: "none", fallback: "" }
}

// The Nth-panel shortcut a widget answers to by its place, if any:
// panelIndex is its one-based position among the section's panels.
function positional(defaults, section, panelIndex, binds) {
  var p = ((defaults && defaults.positions) || []).find(function(x) { return x.section === section && x.n === panelIndex })
  return p && live(binds, p.keys) ? p.keys : ""
}

// What else answers these keys: Hyprland's binds (Powerbar's own aside), and
// Powerbar's other shortcuts. → [{ description, target }] (target set for
// Powerbar's).
function conflicts(keys, target, config, binds, names) {
  var k = normalize(keys)
  if (!k) return []
  var out = []
  ;(binds || []).forEach(function(b) {
    if (b.submap || b.keys !== k || b.description.indexOf(DESCRIPTION) === 0) return
    out.push({ description: b.description || "another shortcut", target: "" })
  })
  Object.keys(config || {}).forEach(function(t) {
    if (t === target || normalize(config[t]) !== k) return
    out.push({ description: (names && names[t]) || t, target: t })
  })
  return out
}

// The config after giving `keys` to `target` ("" removes it), taking the keys
// from any other Powerbar shortcut that held them.
function assign(config, target, keys) {
  var next = {}, k = normalize(keys)
  Object.keys(config || {}).forEach(function(t) {
    if (t !== target && k && normalize(config[t]) === k) return
    next[t] = config[t]
  })
  next[target] = k
  return next
}
// Back to Omarchy's own (or none): the entry goes.
function restore(config, target) {
  var next = {}
  Object.keys(config || {}).forEach(function(t) { if (t !== target) next[t] = config[t] })
  return next
}

// A key press while recording → { keys } or { error }. key: Qt key code;
// mods: Qt modifier bits; code: the native scan code (0 when unknown).
var QT = { Shift: 0x02000000, Control: 0x04000000, Alt: 0x08000000, Meta: 0x10000000 }
var QT_KEYS = { 0x20: "SPACE", 0x01000004: "RETURN", 0x01000005: "RETURN", 0x01000001: "TAB", 0x01000002: "TAB",
  0x01000003: "BACKSPACE", 0x01000007: "DELETE", 0x01000010: "HOME", 0x01000011: "END", 0x01000016: "PRIOR",
  0x01000017: "NEXT", 0x01000012: "LEFT", 0x01000014: "RIGHT", 0x01000013: "UP", 0x01000015: "DOWN",
  0x01000006: "INSERT", 0x01000009: "PRINT", 0x01000000: "ESCAPE" }
var QT_MODIFIER_KEYS = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000053, 0x01000054, 0x01001103, 0x01000024, 0x01000025]
function fromKeyEvent(key, mods, code) {
  if (QT_MODIFIER_KEYS.indexOf(key) >= 0) return { error: "" }
  var mask = (mods & QT.Meta ? 64 : 0) | (mods & QT.Control ? 4 : 0) | (mods & QT.Alt ? 8 : 0) | (mods & QT.Shift ? 1 : 0)
  var name = ""
  if (key >= 0x41 && key <= 0x5a) name = String.fromCharCode(key)
  else if (key >= 0x01000030 && key <= 0x01000047) name = "F" + (key - 0x01000030 + 1)
  else if (QT_KEYS[key]) name = QT_KEYS[key]
  else if (code > 8) name = "code:" + code
  else if (key >= 0x30 && key <= 0x39) name = "code:" + (key === 0x30 ? 19 : key - 0x31 + 10)
  if (!name) return { error: "Powerbar can't bind that key" }
  var fKey = /^F\d+$/.test(name)
  if (!(mask & (64 | 4 | 8)) && !fKey) return { error: "Add Super, Ctrl or Alt" }
  return { keys: format({ mask: mask, key: name }) }
}

function luaString(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"' }
function command(target) {
  if (target.indexOf("widget:") === 0) return "omarchy-shell shell toggle " + target.slice(7)
  if (target.indexOf("group:") === 0) return "omarchy-shell powerbar toggleGroup " + target.slice(6)
  // The keyboard mode: a cursor on the focused monitor's bar.
  if (target === "bar:keys") return "omarchy-shell powerbar keys"
  return ""
}

// ~/.config/hypr/powerbar.lua for this config. names: target → what the bind
// is called in Hyprland's list ("Audio", "AI group").
function render(config, defaults, names) {
  var lines = [
    "-- Generated by Powerbar from shell.json (bar.powerbarShortcuts). Don't edit",
    "-- by hand: change shortcuts in Powerbar Preferences (a widget's or a group's",
    "-- settings). Loaded from ~/.config/hypr/hyprland.lua.",
    ""
  ]
  Object.keys(config || {}).sort().forEach(function(target) {
    var keys = normalize(config[target]), cmd = command(target)
    if (!cmd) return
    var id = target.indexOf("widget:") === 0 ? target.slice(7) : ""
    var omarchy = id ? ((defaults && defaults.widgets) || []).find(function(d) { return d.id === id }) : null
    var name = (names && names[target]) || target
    lines.push("-- " + name)
    if (omarchy && !same(omarchy.keys, keys)) lines.push("pcall(hl.unbind, " + luaString(omarchy.keys) + ")")
    if (keys) {
      lines.push("pcall(hl.unbind, " + luaString(keys) + ")")
      lines.push("hl.bind(" + luaString(keys) + ", hl.dsp.exec_cmd(" + luaString(cmd) + "), { description = " + luaString(DESCRIPTION + name) + " })")
    }
    lines.push("")
  })
  lines.push(
    "-- While Preferences records a shortcut, Hyprland sits in this empty submap so",
    "-- every key reaches it. Powerbar leaves it when the recording ends, and it",
    "-- resets itself after 15 seconds; SUPER + CTRL + SHIFT + ALT + ESCAPE is a",
    "-- manual way out.",
    "hl.define_submap(" + luaString(SUBMAP) + ", function()",
    "  hl.bind(\"SUPER + CTRL + SHIFT + ALT + ESCAPE\", hl.dsp.submap(\"reset\"))",
    "end)",
    "")
  return lines.join("\n")
}

// The block hyprland.lua gets once, so the file above loads after Omarchy's
// defaults and the user's own bindings.
var BLOCK_START = "-- >>> powerbar >>>"
var BLOCK = [
  BLOCK_START,
  "-- Powerbar widget and group shortcuts (managed by Powerbar Preferences).",
  "-- The binds live in hypr/powerbar.lua.",
  "do",
  "  local powerbar_binds = (os.getenv(\"HOME\") or \"\") .. \"/.config/hypr/powerbar.lua\"",
  "  local f = io.open(powerbar_binds, \"r\")",
  "  if f then",
  "    f:close()",
  "    dofile(powerbar_binds)",
  "  end",
  "end",
  "-- <<< powerbar <<<"
].join("\n")

// Lua for `hyprctl eval`: enter the recording submap with a watchdog, or leave
// it. Hyprland only enters a registered submap, and powerbar.lua (which
// registers it) does not exist before the first change, so a submap that did
// not take is registered on the spot and entered again. A failed entry is
// reported, not raised: the check is the current submap.
function recordLua(start) {
  var leave = "if hl.get_current_submap() == " + luaString(SUBMAP) + " then hl.dispatch(hl.dsp.submap(\"reset\")) end"
  if (!start) return leave
  return "local function enter() pcall(function() hl.dispatch(hl.dsp.submap(" + luaString(SUBMAP) + ")) end) end enter() "
    + "if hl.get_current_submap() ~= " + luaString(SUBMAP) + " then hl.define_submap(" + luaString(SUBMAP)
    + ", function() hl.bind(\"SUPER + CTRL + SHIFT + ALT + ESCAPE\", hl.dsp.submap(\"reset\")) end) enter() end "
    + "hl.timer(function() " + leave + " end, { timeout = 15000, type = \"oneshot\" })"
}

if (typeof module !== "undefined") module.exports = { MODS, MASK, DESCRIPTION, SUBMAP, BLOCK, BLOCK_START, parse, format, normalize, same, caps, label,
  parseBinds, parseDefaults, readDefaults, live, effective, positional, conflicts, assign, restore, fromKeyEvent, command, render, recordLua }
