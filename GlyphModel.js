// A widget's own glyph, read from the button it draws on the bar, so
// Preferences can show something truer than a stock icon for widgets it has
// no image of. Manifests carry no icon, and a widget's base type declares
// none, but almost every widget draws Omarchy's WidgetButton or
// BarIconButton, whose `text` holds its glyph. The glyph string is the same
// on a horizontal and a vertical bar, so this works at either orientation.

// Nerd Font glyphs live in Unicode's private use areas.
function privateUse(code) {
  return (code >= 0xe000 && code <= 0xf8ff) || (code >= 0xf0000 && code <= 0x10fffd)
}

// The glyph in a button's text: its first private-use character, or a short
// text label with a letter in it ("EN", "AI"). Longer text is a label or a
// value (the clock, "100%"), and bare numbers are values (workspaces).
function glyphFrom(text) {
  var chars = characters(String(text || ""))
  for (var i = 0; i < chars.length; i++) if (privateUse(chars[i].code)) return chars[i].text
  var trimmed = chars.filter(function(c) { return !/\s/.test(c.text) }).map(function(c) { return c.text })
  if (trimmed.length >= 1 && trimmed.length <= 3 && /[A-Za-zÀ-ɏ]/.test(trimmed.join(""))) return trimmed.join("")
  return ""
}

// Characters by code point. Qt's engine splits Array.from(string) by UTF-16
// unit, which would cut the Material glyphs (U+F0000 and up) in half.
function characters(text) {
  var out = []
  for (var i = 0; i < text.length; i++) {
    var hi = text.charCodeAt(i)
    var lo = i + 1 < text.length ? text.charCodeAt(i + 1) : 0
    if (hi >= 0xd800 && hi <= 0xdbff && lo >= 0xdc00 && lo <= 0xdfff) {
      out.push({ text: text.slice(i, i + 2), code: (hi - 0xd800) * 0x400 + (lo - 0xdc00) + 0x10000 })
      i++
    } else out.push({ text: text.charAt(i), code: hi })
  }
  return out
}

// buttons: [{ text, font, visible }] in the widget's tree order. The first
// visible button with a glyph wins; a hidden one only when none is visible.
function pick(buttons) {
  var list = buttons || []
  for (var pass = 0; pass < 2; pass++) {
    for (var i = 0; i < list.length; i++) {
      var b = list[i]
      if (!b || (pass === 0 && b.visible === false)) continue
      var glyph = glyphFrom(b.text)
      if (glyph) return { glyph: glyph, font: String(b.font || "") }
    }
  }
  return null
}

// The store keeps the last glyph seen per instance, so a widget that is
// later hidden (and never loaded) keeps it. Returns the same object when
// nothing changed, so callers can skip writes.
function merge(store, key, entry) {
  var current = store && store[key]
  if (!key || !entry || (current && current.glyph === entry.glyph && current.font === entry.font)) return store
  var next = {}
  for (var k in store) next[k] = store[k]
  next[key] = { glyph: entry.glyph, font: entry.font }
  return next
}

// Drops entries for instances no longer in the layout.
function prune(store, keys) {
  var keep = {}, changed = false
  ;(keys || []).forEach(function(k) { keep[k] = true })
  var next = {}
  for (var k in store) { if (keep[k]) next[k] = store[k]; else changed = true }
  return changed ? next : store
}

function parse(text) {
  try {
    var data = JSON.parse(String(text || "{}"))
    if (!data || typeof data !== "object" || Array.isArray(data)) return {}
    var out = {}
    for (var k in data) {
      var e = data[k]
      if (e && typeof e.glyph === "string" && e.glyph) out[k] = { glyph: e.glyph, font: typeof e.font === "string" ? e.font : "" }
    }
    return out
  } catch (e) { return {} }
}

if (typeof module !== "undefined") module.exports = { privateUse, characters, glyphFrom, pick, merge, prune, parse }
