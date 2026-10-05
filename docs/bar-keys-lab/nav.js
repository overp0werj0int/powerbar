// Keyboard navigation of the bar: the rules the lab's demo runs and its
// measurements count (node: require it; the page: a plain script).
//
// The bar is a row of stops along its edge: widgets, group icons, and each
// zone's dots (on-demand widgets wait behind them). Keys are named by what
// they mean, so one table serves every edge:
//   along -1/+1  move along the bar          Tab / Shift+Tab  next / previous zone
//   into / out   into a group's drawer, back  Enter / Space   open
//   "/"          find by name                 Esc             back out, one layer at a time
// scheme "along" (recommended): the across keys point where the drawer opens.
// scheme "updown" (as first proposed): Up/Down always enter and leave a
// group, whatever edge the bar is on.

(function(root) {
  var ZONES = ["left", "center", "right"]

  // bar: window.BAR (zones of items). Returns stops per zone: { kind, item,
  // zone, side } where kind is "widget", "group" or "dots" (dots carry the
  // on-demand widgets they hold, `hidden`).
  function stops(bar) {
    var out = {}
    ZONES.forEach(function(zone) {
      var list = bar.zones[zone] || [], shown = [], before = [], after = [], seenAnchor = false
      list.forEach(function(item) {
        if (item.kind === "widget" && item.id === bar.anchor) seenAnchor = true
        if (item.kind === "widget" && item.mode === "managed") (seenAnchor ? after : before).push(item)
        else shown.push(item)
      })
      var row = shown.map(function(item) { return { kind: item.kind, item: item, zone: zone } })
      var hiddenAll = before.concat(after)
      // Dots sit on the zone's inner end; the centre has one per side of its anchor.
      if (zone === "left" && hiddenAll.length) row.push({ kind: "dots", zone: zone, hidden: hiddenAll, side: "end" })
      if (zone === "right" && hiddenAll.length) row.unshift({ kind: "dots", zone: zone, hidden: hiddenAll, side: "start" })
      if (zone === "center") {
        if (before.length) row.unshift({ kind: "dots", zone: zone, hidden: before, side: "start" })
        if (after.length) row.push({ kind: "dots", zone: zone, hidden: after, side: "end" })
      }
      out[zone] = row
    })
    return out
  }

  // The row as it stands: a zone whose dots are open shows their widgets in
  // their place (the inline expansion), the dots gone.
  function row(st, open) {
    var flat = []
    ZONES.forEach(function(zone) {
      st[zone].forEach(function(s) {
        if (s.kind === "dots" && open && open.zone === zone && open.side === s.side)
          s.hidden.forEach(function(h) { flat.push({ kind: "widget", item: h, zone: zone, behind: s.side }) })
        else flat.push(s)
      })
    })
    return flat
  }

  // Which key means what on this edge. Returns { along: {key: -1|1}, into, out }.
  function keymap(position, scheme) {
    var vertical = position === "left" || position === "right"
    var along = vertical ? { ArrowUp: -1, k: -1, ArrowDown: 1, j: 1 } : { ArrowLeft: -1, h: -1, ArrowRight: 1, l: 1 }
    var into, out
    if (scheme === "updown") { into = ["ArrowDown", "j"]; out = ["ArrowUp", "k"] }
    else if (position === "top") { into = ["ArrowDown", "j"]; out = ["ArrowUp", "k"] }
    else if (position === "bottom") { into = ["ArrowUp", "k"]; out = ["ArrowDown", "j"] }
    else if (position === "right") { into = ["ArrowLeft", "h"]; out = ["ArrowRight", "l"] }
    else { into = ["ArrowRight", "l"]; out = ["ArrowLeft", "h"] }
    // A key the edge already spends on moving along can't also enter a group:
    // on a side bar, "updown" loses its group keys.
    var clash = into.concat(out).filter(function(k) { return along[k] !== undefined })
    return { along: along, into: into, out: out, clash: clash }
  }

  // Start: on the anchor (the clock), or the widget whose panel is open.
  function start(bar, st) {
    var r = row(st, null)
    var i = r.findIndex(function(s) { return s.kind === "widget" && s.item.id === bar.anchor })
    return { cursor: Math.max(0, i), open: null, drawer: null, member: 0, query: "", searching: false, panel: null, sheet: false }
  }

  function zoneStart(r, zone) { return r.findIndex(function(s) { return s.zone === zone }) }
  function zoneEnd(r, zone) { for (var i = r.length - 1; i >= 0; i--) if (r[i].zone === zone) return i; return -1 }

  // Moving onto dots opens them (as the pointer does) and lands on the first
  // widget behind them in the direction of travel; leaving the zone closes them.
  function land(st, s, index, dir) {
    var r = row(st, s.open)
    var target = r[index]
    if (!target) return s
    if (target.kind === "dots") {
      var open = { zone: target.zone, side: target.side }
      var r2 = row(st, open)
      var first = r2.findIndex(function(x) { return x.behind === target.side && x.zone === target.zone })
      var count = target.hidden.length
      return Object.assign({}, s, { open: open, cursor: dir < 0 ? first + count - 1 : first, drawer: null })
    }
    var next = Object.assign({}, s, { cursor: index, drawer: null })
    if (s.open && target.zone !== s.open.zone) {
      // The expansion closes behind us; re-find the stop in the closed row.
      var closed = row(st, null), id = target.item ? target.item.instance || target.item.id : null
      next.open = null
      next.cursor = closed.findIndex(function(x) { return x.item && (x.item.instance || x.item.id) === id })
    }
    return next
  }

  // One key. Returns the next state; `effect` names what the bar would do
  // ("open-panel", "open-drawer", "close-drawer", "bump", "leave").
  function press(bar, st, s, key, position, scheme) {
    var map = keymap(position, scheme)
    var r = row(st, s.open)
    var cur = r[s.cursor]
    var n = Object.assign({}, s, { effect: "" })
    if (s.searching) {
      if (key === "Escape") return Object.assign(n, { searching: false, query: "", effect: "clear" })
      if (key === "Enter") return Object.assign(n, { searching: false, effect: "open-panel" })
      if (key === "Backspace") return reveal(bar, st, Object.assign(n, { query: s.query.slice(0, -1) }))
      if (key.length === 1) return reveal(bar, st, Object.assign(n, { query: s.query + key }))
      if (key === "Tab" || key === "ArrowDown" || key === "ArrowUp") return cycle(bar, st, n, key === "ArrowUp" ? -1 : 1)
      return n
    }
    if (s.sheet && key !== "?") return key === "Escape" ? Object.assign(n, { sheet: false }) : n
    if (s.drawer) {
      // A drawer is a menu: its rows run down the screen. On a top or bottom
      // bar they run away from it, so the into key goes on down the rows and
      // the out key comes back (to the icon from the first row). On a side
      // bar they run along it: the along keys walk them, the out key leaves.
      var members = s.drawer.members, step = 0, back = false
      if (scheme === "updown") { step = { ArrowDown: 1, j: 1, ArrowUp: -1, k: -1 }[key] || 0 }
      else if (map.along[key] !== undefined && (position === "left" || position === "right")) step = map.along[key]
      else if (map.into.indexOf(key) >= 0 && (position === "top" || position === "bottom")) step = 1
      else if (map.out.indexOf(key) >= 0) { if (position === "left" || position === "right" || s.member === 0) back = true; else step = -1 }
      if (step < 0 && s.member === 0) back = true
      if (key === "Escape" || back) return Object.assign(n, { drawer: null, member: 0, effect: "close-drawer" })
      if (step) return Object.assign(n, { member: Math.max(0, Math.min(members.length - 1, s.member + step)) })
      if (key === "Enter" || key === " ") return Object.assign(n, { effect: "open-panel" })
      if (key === "Tab" || key === "Shift+Tab") n = Object.assign(n, { drawer: null, member: 0 })
      else return n
    }
    if (key === "/") return Object.assign(n, { searching: true, query: "" })
    if (key === "?") return Object.assign(n, { sheet: !s.sheet })
    if (key === "Escape") return Object.assign(n, { effect: "leave" })
    // Moving along wins a key both meanings want (Up/Down on a side bar).
    if (map.along[key] !== undefined) {
      var dir = map.along[key], to = s.cursor + dir
      if (to < 0 || to >= r.length) return Object.assign(n, { effect: "bump" })
      return land(st, n, to, dir)
    }
    if (map.into.indexOf(key) >= 0 && cur && cur.kind === "group") return Object.assign(n, { drawer: cur.item, member: 0, effect: "open-drawer" })
    if (key === "Enter" || key === " ") {
      if (cur && cur.kind === "group") return Object.assign(n, { drawer: cur.item, member: 0, effect: "open-drawer" })
      return Object.assign(n, { effect: "open-panel" })
    }
    if (key === "Tab" || key === "Shift+Tab") {
      var dirz = key === "Tab" ? 1 : -1, zi = ZONES.indexOf(cur ? cur.zone : "center")
      for (var step = 1; step <= 3; step++) {
        var z = ZONES[(zi + dirz * step + 30) % 3]
        var closed = row(st, null), i = dirz > 0 ? zoneStart(closed, z) : zoneEnd(closed, z)
        if (i >= 0) return land(st, Object.assign(n, { open: null }), i, dirz)
      }
      return n
    }
    if (key === "Home" || key === "End") return land(st, Object.assign(n, { open: null }), key === "Home" ? 0 : row(st, null).length - 1, key === "Home" ? 1 : -1)
    return n
  }

  // Everything search can find: widgets on the bar, behind dots and in groups.
  function catalogue(st) {
    var out = []
    ZONES.forEach(function(zone) {
      st[zone].forEach(function(s) {
        if (s.kind === "widget") out.push({ item: s.item, zone: zone })
        else if (s.kind === "group") {
          out.push({ item: s.item, zone: zone })
          s.item.members.forEach(function(m) { out.push({ item: m, zone: zone, group: s.item }) })
        } else s.hidden.forEach(function(h) { out.push({ item: h, zone: zone, dots: s.side }) })
      })
    })
    return out
  }
  // Matches for a query, best first: a word that starts with it beats one
  // that contains it; ties keep bar order.
  function matches(st, query) {
    var q = String(query || "").toLowerCase()
    if (!q) return []
    var list = catalogue(st), scored = []
    list.forEach(function(c, i) {
      var name = c.item.name.toLowerCase(), words = name.split(/[^a-z0-9]+/)
      var score = words.some(function(w) { return w.indexOf(q) === 0 }) ? 2 : name.indexOf(q) >= 0 ? 1 : 0
      if (score) scored.push({ c: c, score: score, i: i })
    })
    scored.sort(function(a, b) { return b.score - a.score || a.i - b.i })
    return scored.map(function(x) { return x.c })
  }
  // Put the cursor on the best match, opening its dots or its group's drawer.
  function reveal(bar, st, s, which) {
    var found = matches(st, s.query)
    var pick = found[Math.max(0, Math.min(found.length - 1, which || 0))]
    var n = Object.assign({}, s, { matchIndex: which || 0, matchCount: found.length })
    if (!pick) return n
    if (pick.group) {
      var r = row(st, null), gi = r.findIndex(function(x) { return x.kind === "group" && x.item.id === pick.group.id })
      return Object.assign(n, { open: null, cursor: gi, drawer: pick.group, member: pick.group.members.indexOf(pick.item) })
    }
    if (pick.dots) {
      var open = { zone: pick.zone, side: pick.dots }, r2 = row(st, open)
      return Object.assign(n, { open: open, drawer: null, cursor: r2.findIndex(function(x) { return x.item === pick.item }) })
    }
    var r3 = row(st, null)
    return Object.assign(n, { open: null, drawer: null, cursor: r3.findIndex(function(x) { return x.item === pick.item }) })
  }
  function cycle(bar, st, s, dir) {
    var count = matches(st, s.query).length
    if (!count) return s
    return reveal(bar, st, s, ((s.matchIndex || 0) + dir + count) % count)
  }

  // ---- measurements ------------------------------------------------------
  function sameTarget(st, s, target) {
    var r = row(st, s.open), cur = r[s.cursor]
    if (target.group) return !!s.drawer && s.drawer.id === target.group.id && s.drawer.members[s.member] === target.item
    return !s.drawer && !!cur && cur.item === target.item
  }
  // Fewest key presses from the start to put the cursor on every item, by
  // breadth-first search over the keys a scheme allows.
  function reach(bar, position, scheme, keys) {
    var st = stops(bar), s0 = start(bar, st), seen = {}, queue = [{ s: s0, d: 0 }], dist = new Map()
    var targets = catalogue(st)
    function id(s) { return [s.cursor, s.open ? s.open.zone + s.open.side : "", s.drawer ? s.drawer.id : "", s.member].join("|") }
    seen[id(s0)] = true
    while (queue.length) {
      var q = queue.shift()
      targets.forEach(function(t) { if (!dist.has(t) && sameTarget(st, q.s, t)) dist.set(t, q.d) })
      keys.forEach(function(k) {
        var n = press(bar, st, q.s, k, position, scheme)
        if (n.effect === "leave" || n.effect === "bump" || n.searching || n.sheet) return
        var key = id(n)
        if (seen[key]) return
        seen[key] = true
        queue.push({ s: n, d: q.d + 1 })
      })
    }
    return targets.map(function(t) { return { name: t.item.name, group: t.group ? t.group.name : "", behind: !!t.dots, keys: dist.has(t) ? dist.get(t) : Infinity } })
  }
  // Keys to find each item by name: "/", the start of one of its words (as
  // people type), and a press of the down arrow for each better match ahead.
  function findCost(bar) {
    var st = stops(bar)
    return catalogue(st).map(function(t) {
      var best = { keys: Infinity, typed: "", rank: 0 }
      t.item.name.toLowerCase().split(/[^a-z0-9]+/).forEach(function(word) {
        for (var len = 1; len <= word.length; len++) {
          var q = word.slice(0, len), rank = matches(st, q).findIndex(function(m) { return m.item === t.item })
          if (rank < 0) continue
          var keys = 1 + len + rank
          if (keys < best.keys) best = { keys: keys, typed: q, rank: rank }
        }
      })
      return { name: t.item.name, keys: best.keys, typed: best.typed, rank: best.rank }
    })
  }

  var api = { ZONES: ZONES, stops: stops, row: row, keymap: keymap, start: start, press: press, matches: matches, reveal: reveal,
    catalogue: catalogue, reach: reach, findCost: findCost }
  if (typeof module !== "undefined") module.exports = api
  else root.Nav = api
})(this)
