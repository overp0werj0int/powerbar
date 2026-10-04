// The picker's search: every query word must start a word of the icon's name
// (or appear inside one, ranked lower). Exact words beat prefixes, short names
// beat long ones, and sources keep their order: your bar, Omarchy, emoji.
function words(s) { return String(s || "").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean) }
function index(src) {
  var out = []
  src.bar.forEach(function(b) {
    var c = b.g.codePointAt(0)
    if (!(c >= 0xE000 && c <= 0xF8FF) && c < 0xF0000) return
    out.push({ g: b.g, font: b.font === "omarchy" ? "omarchy" : "", name: b.n.replace(/-/g, " "), source: 0, words: words(b.n).concat(["bar"]) })
  })
  src.logos.forEach(function(l) { out.push({ g: String.fromCodePoint(l[0]), font: "omarchy", name: l[1], source: 1, logo: true, words: words(l[1]).concat(["omarchy", "logo"], l[2] || []) }) })
  src.glyphs.forEach(function(r) {
    var name = r.n.replace(/^[a-z]+-/, "").replace(/_/g, " ")
    out.push({ g: String.fromCodePoint(r.c), font: "", name: name, source: 1, use: r.u, words: words(name) })
  })
  src.emoji.forEach(function(e) { var w = words(e.k); out.push({ g: e.e, font: "", name: w.slice(0, 4).join(" "), source: 2, words: w }) })
  // Same glyph from two sources: keep the first (your bar wins).
  var seen = {}
  return out.filter(function(i) { var k = i.font + i.g; if (seen[k]) return false; seen[k] = true; return true })
}
function score(item, terms) {
  var total = 0
  for (var t of terms) {
    var best = 0
    for (var i = 0; i < item.words.length; i++) {
      var w = item.words[i]
      var s = w === t ? 4 : w.indexOf(t) === 0 ? 3 : t.length >= 3 && w.indexOf(t) > 0 ? 1 : 0
      if (s && i === 0) s += 0.5
      if (s > best) best = s
    }
    if (!best) return 0
    total += best
  }
  return total - Math.min(item.words.length, 12) * 0.05
}
function search(idx, query) {
  var terms = words(query)
  if (!terms.length) return idx
  var hits = []
  for (var item of idx) { var s = score(item, terms); if (s > 0) hits.push({ item: item, s: s }) }
  hits.sort(function(a, b) { return b.s - a.s || a.item.source - b.item.source })
  return hits.map(function(h) { return h.item })
}
if (typeof module !== "undefined") module.exports = { index, search, words }
