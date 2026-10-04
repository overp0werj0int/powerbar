// The group icon picker's list and search (docs/prefs-groups-lab).
//
// Sources, in this order: the glyphs your widgets draw (source 0), Omarchy's
// own font and the Nerd Font glyphs Omarchy uses (source 1), Omarchy's emoji
// (source 2). Every query word must start a word of an icon's name, or sit
// inside one (three letters or more, ranked lower). Names split on spaces,
// hyphens and underscores, so "volume up", volume_up and volume-up match the
// same icons. Exact words beat prefixes, short names beat long ones, and ties
// keep the source order.

var BAR = 0, OMARCHY = 1, EMOJI = 2

function words(s) { return String(s || "").toLowerCase().split(/[^a-z0-9]+/).filter(function(w) { return w !== "" }) }

// bar: [{ glyph, font, name }]; logos: [[codePoint, name, tags]];
// glyphs: [[codePoint, nerdName, uses]]; emoji: [{ e, k }].
// Returns [{ glyph, font, name, source, logo, words }], one per glyph and font.
function index(sources) {
  var src = sources || {}, out = []
  ;(src.bar || []).forEach(function(b) {
    if (!b || !isIconGlyph(b.glyph)) return
    out.push({ glyph: b.glyph, font: b.font === "omarchy" ? "omarchy" : "", name: String(b.name || ""), source: BAR, logo: false,
      words: words(b.name).concat(["bar"]) })
  })
  ;(src.logos || []).forEach(function(l) {
    out.push({ glyph: String.fromCodePoint(l[0]), font: "omarchy", name: l[1], source: OMARCHY, logo: true,
      words: words(l[1]).concat(["omarchy", "logo"], l[2] || []) })
  })
  ;(src.glyphs || []).forEach(function(r) {
    var name = String(r[1]).replace(/^[a-z]+-/, "").replace(/_/g, " ")
    out.push({ glyph: String.fromCodePoint(r[0]), font: "", name: name, source: OMARCHY, logo: false, words: words(name) })
  })
  ;(src.emoji || []).forEach(function(e) {
    if (!e || !e.e) return
    var w = words(e.k)
    out.push({ glyph: e.e, font: "", name: w.slice(0, 3).join(" "), source: EMOJI, logo: false, words: w })
  })
  // The same glyph in the same font from two sources keeps the first.
  var seen = {}
  return out.filter(function(i) {
    var key = i.font + "|" + i.glyph
    if (seen[key]) return false
    seen[key] = true
    return true
  })
}

// A widget's glyph counts as an icon when it is a private-use character (a
// Nerd Font or Omarchy glyph), not a label such as "EN".
function isIconGlyph(glyph) {
  var c = String(glyph || "").codePointAt(0)
  return c >= 0xE000 && c <= 0xF8FF || c >= 0xF0000
}

function score(item, terms) {
  var total = 0
  for (var t = 0; t < terms.length; t++) {
    var term = terms[t], best = 0
    for (var i = 0; i < item.words.length; i++) {
      var w = item.words[i]
      var s = w === term ? 4 : w.indexOf(term) === 0 ? 3 : term.length >= 3 && w.indexOf(term) > 0 ? 1 : 0
      if (s && i === 0) s += 0.5
      if (s > best) best = s
    }
    if (!best) return 0
    total += best
  }
  return total - Math.min(item.words.length, 12) * 0.05
}

// The icons matching `query`, best first; every icon for an empty query.
function search(list, query) {
  var terms = words(query)
  if (!terms.length) return list.slice()
  var hits = []
  for (var i = 0; i < list.length; i++) {
    var s = score(list[i], terms)
    if (s > 0) hits.push({ item: list[i], s: s, n: i })
  }
  hits.sort(function(a, b) { return b.s - a.s || a.item.source - b.item.source || a.n - b.n })
  return hits.map(function(h) { return h.item })
}

// A search that is a single pasted glyph or emoji (an emoji sequence joined
// by ZWJ or with a skin tone counts as one) is offered as the icon itself.
function pastedGlyph(query) {
  var t = String(query || "").trim()
  if (!t || t.length > 16 || /[A-Za-z0-9\s]/.test(t)) return ""
  var first = t.codePointAt(0)
  if (first < 0x2000) return ""
  // Every code point after the first must be a joiner, a selector, a skin
  // tone, a keycap or a tag, or follow a joiner.
  var i = first > 0xFFFF ? 2 : 1, afterJoiner = false
  while (i < t.length) {
    var c = t.codePointAt(i)
    var joiner = c === 0x200D
    var modifier = c === 0xFE0F || c === 0xFE0E || c === 0x20E3 || (c >= 0x1F3FB && c <= 0x1F3FF) || (c >= 0xE0020 && c <= 0xE007F)
    if (!joiner && !modifier && !afterJoiner && !(c >= 0x1F1E6 && c <= 0x1F1FF && first >= 0x1F1E6 && first <= 0x1F1FF && i <= 2)) return ""
    afterJoiner = joiner
    i += c > 0xFFFF ? 2 : 1
  }
  return t
}

// The picker's rows: a header row per source while nothing is searched, then
// the icons cut into rows of `columns`. A search is one run without headers.
// Returns [{ header, items: [{ item, at }] }] where `at` is the flat index.
function rows(list, columns, sectioned) {
  var cols = Math.max(1, columns), out = [], at = 0
  function cut(items) {
    for (var i = 0; i < items.length; i += cols) {
      out.push({ header: "", items: items.slice(i, i + cols).map(function(item) { return { item: item, at: at++ } }) })
    }
  }
  if (!sectioned) { cut(list); return out }
  var groups = [
    ["On your bar", list.filter(function(i) { return i.source === BAR })],
    ["Omarchy logos", list.filter(function(i) { return i.logo })],
    ["Omarchy", list.filter(function(i) { return i.source === OMARCHY && !i.logo })],
    ["Emoji", list.filter(function(i) { return i.source === EMOJI })]
  ]
  groups.forEach(function(g) {
    if (!g[1].length) return
    out.push({ header: g[0], items: [] })
    cut(g[1])
  })
  return out
}

// The flat index straight above or below `at` (dir -1 or 1), skipping
// header rows; the column is kept, or the row's last icon when it is shorter.
function vertical(rowList, at, dir) {
  var r = -1, c = 0
  for (var i = 0; i < rowList.length && r < 0; i++) {
    for (var j = 0; j < rowList[i].items.length; j++) if (rowList[i].items[j].at === at) { r = i; c = j; break }
  }
  if (r < 0) return at
  for (var n = r + dir; n >= 0 && n < rowList.length; n += dir) {
    var items = rowList[n].items
    if (items.length) return items[Math.min(c, items.length - 1)].at
  }
  return at
}

if (typeof module !== "undefined") module.exports = { BAR, OMARCHY, EMOJI, words, index, isIconGlyph, score, search, pastedGlyph, rows, vertical }
