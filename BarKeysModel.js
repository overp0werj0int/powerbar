// Keyboard navigation of the bar (docs/behavior/keyboard.md): which key means what on
// each edge, how the cursor steps through the bar's stops, and how a search
// ranks names. Pure decisions; Bar.qml carries them out.
//
// Keys are named by direction relative to the bar, so one table serves every
// edge: "along" keys move along it, "into" points into the screen (where a
// drawer opens) and enters a group, "out" comes back. On a side bar Up and
// Down run along it, so ← or → enter and leave.
//
// A key name is "Left", "Right", "Up", "Down", "Home", "End", "PageUp",
// "PageDown", "Tab", "Backtab", "Enter", "Space", "Escape", "Backspace", or the
// character typed. As in vim, ^ and $ go to the ends, like Home and End; Page
// Up and Page Down jump zone to zone, like Shift+Tab and Tab.

var ZONES = ["left", "center", "right"]
// Opens Preferences from the mode, and in Preferences comes back to it
// (the comma, as for an app's settings).
var PREFS_KEY = ","

function keymap(position) {
  var vertical = position === "left" || position === "right"
  var along = vertical ? { Up: -1, k: -1, Down: 1, j: 1 } : { Left: -1, h: -1, Right: 1, l: 1 }
  var into = position === "top" ? ["Down", "j"] : position === "bottom" ? ["Up", "k"]
    : position === "right" ? ["Left", "h"] : ["Right", "l"]
  var out = position === "top" ? ["Up", "k"] : position === "bottom" ? ["Down", "j"]
    : position === "right" ? ["Right", "l"] : ["Left", "h"]
  return { vertical: vertical, along: along, into: into, out: out }
}

// What a key asks for on the bar: { move: ±1 } along, { zone: ±1 } (Tab),
// { home }, { end }, { into }, { out } (back up from a notch zone's second
// row), { open }, { find }, { sheet }, { prefs } (Preferences), { leave }, or
// null for a key the bar does not use.
function barIntent(position, key) {
  var map = keymap(position)
  if (map.along[key] !== undefined) return { move: map.along[key] }
  if (map.into.indexOf(key) >= 0) return { into: true }
  if (map.out.indexOf(key) >= 0) return { out: true }
  if (key === "Tab" || key === "PageDown") return { zone: 1 }
  if (key === "Backtab" || key === "PageUp") return { zone: -1 }
  if (key === "Home" || key === "^") return { home: true }
  if (key === "End" || key === "$") return { end: true }
  if (key === "Enter" || key === "Space") return { open: true }
  if (key === "/") return { find: true }
  if (key === "?") return { sheet: true }
  if (key === PREFS_KEY) return { prefs: true }
  if (key === "Escape") return { leave: true }
  return null
}

// What a key asks for inside a drawer opened from the cursor. A strip (strip:
// true) runs along the bar, and so does a menu's column on a side bar: the
// along keys walk it and the out key leaves. A menu under a top or bottom bar
// runs away from it, so the into key goes on down the rows and the out key
// comes back up (to the icon from the first row), and the along keys leave
// and move on.
// Home and ^ go to the first member, End and $ to the last.
// Returns { member: ±1 }, { first }, { last }, { back }, { backMove: ±1 },
// { zone: ±1 }, { open }, { find }, { sheet }, { prefs }, or null.
function drawerIntent(position, key, member, strip) {
  var map = keymap(position)
  if (key === "Escape") return { back: true }
  if (key === PREFS_KEY) return { prefs: true }
  if (key === "Enter" || key === "Space") return { open: true }
  if (key === "Tab" || key === "PageDown") return { zone: 1 }
  if (key === "Backtab" || key === "PageUp") return { zone: -1 }
  if (key === "Home" || key === "^") return { first: true }
  if (key === "End" || key === "$") return { last: true }
  if (key === "/") return { find: true }
  if (key === "?") return { sheet: true }
  if (map.vertical || strip) {
    if (map.along[key] !== undefined) return { member: map.along[key] }
    if (map.out.indexOf(key) >= 0) return { back: true }
    return null
  }
  if (map.into.indexOf(key) >= 0) return { member: 1 }
  if (map.out.indexOf(key) >= 0) return member > 0 ? { member: -1 } : { back: true }
  if (map.along[key] !== undefined) return { backMove: map.along[key] }
  return null
}

// Shift with a key that moves the cursor drags the widget or group icon
// under it instead, to where the cursor would go (docs/behavior/keyboard.md
// KEYS-86). Shift+h j k l arrive as capitals and count as their letters.
// → the key to read the move from, or "" when this is no drag.
function dragKey(key, shift) {
  if (!shift) return ""
  if (["Left", "Right", "Up", "Down"].indexOf(key) >= 0) return key
  if (["H", "J", "K", "L"].indexOf(key) >= 0) return key.toLowerCase()
  return ""
}

// Where a stop dragged one step along the bar lands, beside the stop the
// cursor would move to (to: { kind, zone }): past it in its own zone, at the
// near end of another zone, or on the dots (it goes On demand, as a drop on
// them does). Nothing passes the Preferences button.
// → { after } (beside to), { dots: true }, or null.
function dragDrop(fromZone, to, dir) {
  if (!to || to.kind === "prefs") return null
  if (to.kind === "dots") return { dots: true }
  return { after: to.zone === fromZone ? dir > 0 : dir < 0 }
}

// The next stop along the row, or -1 at either end: the cursor stops there
// (no wrap), so the ends stay a landmark.
function step(count, index, dir) {
  var to = index + dir
  return to < 0 || to >= count ? -1 : to
}

// On a bar with rows (a notch zone's second row, docs/behavior/keyboard.md)
// the cursor moves as on a grid. stops: [{ at, row, zone }] (at: the centre
// along the bar; row: 0 on the bar's own row, 1 on the second).
// Along (dir ±1): the nearest stop past the cursor in its own row, or -1 at
// the row's end. Across (rows ±1, +1 away from the screen edge): the stop of
// the cursor's zone in the next row nearest along the bar, or -1 when that
// row has none.
function gridStep(stops, index, dir, rows) {
  var from = stops[index]
  if (!from) return -1
  var best = -1, gap = Infinity
  for (var i = 0; i < stops.length; i++) {
    var s = stops[i]
    if (i === index) continue
    var d
    if (rows) {
      if ((s.row || 0) !== (from.row || 0) + rows || s.zone !== from.zone) continue
      d = Math.abs(s.at - from.at)
    } else {
      if ((s.row || 0) !== (from.row || 0)) continue
      d = (s.at - from.at) * dir
      if (!(d > 0)) continue
    }
    if (d < gap) { gap = d; best = i }
  }
  return best
}

// Tab: the next zone with stops, wrapping; it lands on the zone's first stop
// going forward and its last going back, the nearest either way.
//   zones: each stop's zone, in bar order
function zoneStep(zones, index, dir) {
  if (!zones.length) return -1
  var from = ZONES.indexOf(zones[index])
  if (from < 0) from = 1
  for (var n = 1; n <= ZONES.length; n++) {
    var zone = ZONES[(from + dir * n + ZONES.length * 3) % ZONES.length]
    if (dir > 0) { var first = zones.indexOf(zone); if (first >= 0) return first }
    else { var last = zones.lastIndexOf(zone); if (last >= 0) return last }
  }
  return -1
}

// Fuzzy search, after fzy (github.com/jhawthorn/fzy, ALGORITHM.md): the
// letters typed appear in order anywhere in the text, and the best way to
// place them wins. A letter scores most when it continues the previous one,
// then at a word's start (or a capital inside a word); gaps cost a little,
// so "ail" finds "AI Local Laya" before "Tailscale" and "auau" finds the
// Audio group's Audio. Same constants as fzy.
var GAP_OUTER = -0.005, GAP_INNER = -0.01, CONSECUTIVE = 1, AT_START = 0.9, AT_WORD = 0.8, AT_CAPITAL = 0.7
// A letter of a word (any script), not a space or punctuation.
function isLetter(c) { return c.toLowerCase() !== c.toUpperCase() || (c >= "0" && c <= "9") }

// The best placement of needle (lower case) in text, skipping the letters
// marked in used: { score, at: [index per letter], start: the first letter
// begins a word }, or null when the letters are not all there in order.
function fuzzy(needle, text, used) {
  var n = needle.length, m = text.length, hay = text.toLowerCase()
  if (!n || n > m) return null
  var bonus = []
  for (var j = 0; j < m; j++) {
    var c = text[j], prev = j ? text[j - 1] : ""
    bonus.push(!isLetter(c) ? 0 : !j ? AT_START : !isLetter(prev) ? AT_WORD
      : c !== c.toLowerCase() && prev === prev.toLowerCase() ? AT_CAPITAL : 0)
  }
  // M[i][j]: best score with letter i placed at j; D[i][j]: placed at j or before.
  var M = [], D = []
  for (var i = 0; i < n; i++) {
    var mi = [], di = [], best = -Infinity, gap = i === n - 1 ? GAP_OUTER : GAP_INNER
    for (j = 0; j < m; j++) {
      var s = -Infinity
      if (needle[i] === hay[j] && !(used && used[j])) {
        if (!i) s = j * GAP_OUTER + bonus[j]
        else if (j) s = Math.max(D[i - 1][j - 1] + bonus[j], M[i - 1][j - 1] + CONSECUTIVE)
      }
      mi.push(s)
      di.push(best = Math.max(s, best + gap))
    }
    M.push(mi); D.push(di)
  }
  if (D[n - 1][m - 1] === -Infinity) return null
  // Walk back to where each letter went.
  var at = [], must = false
  for (i = n - 1, j = m - 1; i >= 0; i--) {
    for (; j >= 0; j--) {
      if (M[i][j] !== -Infinity && (must || M[i][j] === D[i][j])) {
        must = i > 0 && j > 0 && M[i][j] === M[i - 1][j - 1] + CONSECUTIVE
        at[i] = j--
        break
      }
    }
  }
  return { score: D[n - 1][m - 1], at: at, start: bonus[at[0]] > 0 }
}

// Search: the matches for a query, best first, ties in bar order. Each word
// typed must match on its own letters (longest word first), in any order,
// so "ai a" finds the AI group's members (their text starts with the
// group's name) but not the group itself. A space means "a new word", so a
// word after one starts a word of the text, and so does a single letter.
//   names: one text per item, in bar order. Returns item indices.
function matches(names, query) {
  var words = String(query || "").toLowerCase().trim().split(/\s+/).filter(function(w) { return w })
    .map(function(w, k) { return { w: w, anchored: k > 0 || w.length === 1 } })
  if (!words.length) return []
  words.sort(function(a, b) { return b.w.length - a.w.length })
  var scored = []
  names.forEach(function(name, i) {
    var text = String(name || ""), used = {}, total = 0
    for (var word of words) {
      var hit = fuzzy(word.w, text, used)
      if (!hit || (word.anchored && !hit.start)) return
      total += hit.score
      // Letters a word used are spent.
      hit.at.forEach(function(j) { used[j] = true })
    }
    scored.push({ i: i, score: total })
  })
  scored.sort(function(a, b) { return b.score - a.score || a.i - b.i })
  return scored.map(function(x) { return x.i })
}

// What a search reads for one widget: its name, after its group's for a member.
function searchText(name, groupName) { return groupName ? groupName + " " + name : String(name || "") }

// How a search brings a found widget into view, the way the pointer would:
// "put" (on the bar), "dots" (in "In the bar" mode, anything waiting behind
// its zone's dots or folded off for lack of room: the zone expands in place),
// "drawer" (in its zone's drawer: drawer mode), or "clear" (it gave way to
// another zone's expansion: that closes and the widget comes back).
//   where: { onBar, inline, behindDots, folded, inDrawer }
function route(where) {
  if (where.onBar) return "put"
  if (where.inline && (where.behindDots || where.folded)) return "dots"
  if (where.inDrawer) return "drawer"
  return "clear"
}

// Arrow keys drawn as one keycap ("←→↓"), always in the order ← ↑ → ↓, as
// Atlas draws them; their vim letters likewise ("hjkl"). A thin space (not a
// keycap break) parts the arrows: side by side, the font joins ← → into ↔.
var ARROWS = [["Left", "←"], ["Up", "↑"], ["Right", "→"], ["Down", "↓"]]
var THIN = "\u2009"
function arrowCap(names) {
  return ARROWS.filter(function(a) { return names.indexOf(a[0]) >= 0 }).map(function(a) { return a[1] }).join(THIN)
}

// The key strip's entries for an edge: [{ keys, label }]. At bar level the
// arrows that move the cursor (along and into) share one "Move", and Tab and
// Shift+Tab one "Zones".
// strip: the open drawer is a strip, walked with the along keys.
function legend(position, state, strip) {
  var map = keymap(position)
  var arrows = { Up: "↑", Down: "↓", Left: "←", Right: "→" }
  var along = map.vertical ? ["Up", "Down"] : ["Left", "Right"]
  var alongKeys = arrowCap(along)
  if (state === "search") return [
    { keys: "Tab", label: "Next match" }, { keys: "Enter", label: "Open" }, { keys: "Esc", label: "Stop finding" },
    { keys: "Esc Esc", label: "Leave" }
  ]
  var rows = map.vertical || strip ? alongKeys : arrowCap([map.into[0], map.out[0]])
  if (state === "drawer") return [
    { keys: rows, label: "Move" }, { keys: "Shift+" + rows, label: "Drag" },
    { keys: "Enter", label: "Open" }, { keys: map.vertical || strip ? arrows[map.out[0]] + " Esc" : "Esc", label: "Back" },
    { keys: PREFS_KEY, label: "Preferences" }, { keys: "Esc Esc", label: "Leave" }
  ]
  return [
    { keys: arrowCap(along.concat([map.into[0]])), label: "Move" }, { keys: "Shift+" + alongKeys, label: "Drag" },
    { keys: "Tab Shift+Tab", label: "Zones" },
    { keys: "Enter", label: "Open" }, { keys: "/", label: "Find" },
    { keys: "?", label: "Shortcuts" }, { keys: PREFS_KEY, label: "Preferences" }, { keys: "Esc", label: "Leave" }
  ]
}

// The ? sheet's left column: every key of the mode for an edge, in the
// legend's form ({ keys, label }, keys split on spaces into keycaps). The
// arrows (along, into, out) share one keycap and their vim letters another,
// in one "Movement" row: every edge uses all four ("←↑→↓ hjkl").
function sheetKeys(position) {
  var map = keymap(position)
  var keys = Object.keys(map.along).concat(map.into, map.out)
  var vim = ["h", "j", "k", "l"].filter(function(k) { return keys.indexOf(k) >= 0 })
  return [
    { keys: arrowCap(keys) + " " + vim.join(""), label: "Movement" },
    { keys: "Shift+" + arrowCap(keys) + " " + vim.join("").toUpperCase(), label: "Drag the widget" },
    { keys: "Home ^", label: "First stop" },
    { keys: "End $", label: "Last stop" },
    { keys: "Tab PgDn", label: "Next zone" },
    { keys: "Shift+Tab PgUp", label: "Previous zone" },
    { keys: "Enter Space", label: "Open" },
    { keys: "/", label: "Find" },
    { keys: PREFS_KEY, label: "Preferences" },
    { keys: "?", label: "This sheet" },
    { keys: "Esc", label: "Back, or leave" },
    { keys: "Esc Esc", label: "Leave from anywhere" }
  ]
}

// Which bar the keyboard mode starts on: the focused monitor's (screens: each
// bar window's screen name, in order). Another monitor's bar is used only while
// no monitor is known to be focused; a focused monitor without a bar gets
// none, so the mode never starts out of sight. → an index, or -1.
function startScreen(screens, focused) {
  if (!screens || !screens.length) return -1
  if (!focused) return 0
  return screens.indexOf(focused)
}

// The name card's text. On a row of a named menu the row already shows the
// name, so the card says what hovering the row says: the widget's own
// tooltip (a status, a level), when it has one that is not just its name.
// Elsewhere it names the stop. Shortcuts are on the ? sheet, not the card.
function cardText(name, own, namedMenu) {
  return namedMenu && own && own !== name ? own : name
}

if (typeof module !== "undefined") module.exports = { ZONES, PREFS_KEY, keymap, barIntent, drawerIntent, dragKey, dragDrop, step, gridStep, zoneStep, fuzzy, matches, searchText, route, legend, sheetKeys, startScreen, cardText }
