// Zones never overlap: the solver that fits the left, centre and right zones
// along one bar line. A lasting length slides the centre by the least distance
// that keeps one zone gap, then folds widgets into drawers (longest zone first);
// a moment (transient growth) slides nothing and makes neighbours yield.
// A zone with hidden on-demand widgets keeps its handle at the end they wait
// behind (input.dots): the left zone's end, the right zone's start, and each
// side of the centre on its own ({ start, end }). Widgets folded for lack of
// room wait behind the same dots on their side. Hovering the dots is a moment
// that unfolds the zone (unfold; the centre one side at a time). Several moments can run at once
// (input.transient is one or a list, highest priority first): neighbours yield
// to every growing zone, and when two growing zones collide the lower one
// falls back. An inline expansion that would need a neighbour's anchor to
// yield hides that whole neighbour instead (result.hidden), then the zone past
// it if it still collides; it falls back only when it can't fit the bar line.
// A screen with a camera notch (input.notch, the keep-out's extent) puts an
// empty slot in the centre, just before the anchor (before every centre
// widget without one), that stays at the middle of the bar line: the centre
// never slides there, and the widgets on either side fold towards their own
// neighbour instead (the left zone or the centre's before-run on the left,
// the right zone or its after-run on the right). The camera is a hard stop:
// an inline expansion that could only fit by hiding the centre, and with it
// the notch slot, falls back to its drawer instead (reason "notch").
// On the notch (input.wrap) each zone grows away from the camera and wraps
// onto a second row at the screen edge, so a moment never makes another zone
// yield or hide, and running past the screen edge is no reason to fall back.
// See docs/behavior/layout-zones.md for the specification.

var NOTCH = "notch"
function hasNotch(input) { return input.notch > 0 }

function zoneItems(input, name) {
  var z = input.zones
  if (name !== "center") return z[name]
  var next = z.anchor || z.center[0], prev = z.anchor ? z.before[z.before.length - 1] : null
  // With notchPads (three zones) the centre's own cells meet the slot, so it
  // also holds the island end pads on either side of the keep-out.
  var extent = input.notchPads
    ? input.notch + input.pad(prev ? prev.spill : 0) + input.pad(next ? next.spill : 0) : input.notch
  var n = hasNotch(input) ? [{ key: NOTCH, extent: extent, spill: 0 }] : []
  return z.anchor ? z.before.concat(n, [z.anchor], z.after) : n.concat(z.center)
}

function isFolded(st, key) { return st.folded[key] === true }

function foldedKeys(input, name, st) {
  return zoneItems(input, name).filter(function (it) { return isFolded(st, it.key) }).map(function (it) { return it.key })
}

function hasDots(input, name) { return !!(input.dots && input.dots[name]) }

// The centre's dots, side by side: { start, end }. true (or "end") is the end.
function centerDots(input) {
  var d = input.dots ? input.dots.center : false
  if (d && typeof d === "object") return { start: !!d.start, end: !!d.end }
  return { start: d === "start" || d === "both", end: d === true || d === "end" || d === "both" }
}

// The centre's folded widgets by the side they wait on. With an anchor that is
// their side of it; without one, folds are taken from the ends, so those
// before the first widget still showing wait at the start.
function centerFoldSides(input, st) {
  var z = input.zones, out = { start: [], end: [] }
  if (z.anchor) {
    z.before.forEach(function (it) { if (isFolded(st, it.key)) out.start.push(it.key) })
    z.after.forEach(function (it) { if (isFolded(st, it.key)) out.end.push(it.key) })
    return out
  }
  var seen = false
  z.center.forEach(function (it) {
    if (!isFolded(st, it.key)) seen = true
    else out[seen ? "end" : "start"].push(it.key)
  })
  return out
}

// Which sides of the centre draw dots: folds or hidden widgets on that side.
function centerHandles(input, st) {
  var sides = centerFoldSides(input, st), dots = centerDots(input)
  return { start: sides.start.length > 0 || dots.start, end: sides.end.length > 0 || dots.end }
}

// The zone's slots in bar order: unfolded items plus the drawer handle slots.
function slotsOf(input, name, st) {
  var items = zoneItems(input, name).filter(function (it) { return !isFolded(st, it.key) })
  var mk = function (key) { return { key: key, extent: input.handle.extent, spill: input.handle.spill } }
  if (name === "center") {
    var c = centerHandles(input, st)
    return (c.start ? [mk("handle:center:start")] : []).concat(items, c.end ? [mk("handle:center:end")] : [])
  }
  if (!foldedKeys(input, name, st).length && !hasDots(input, name)) return items
  // On the notch the dots sit at the far ends (handlesOf).
  if (name === "left") return input.wrap ? [mk("handle:left")].concat(items) : items.concat([mk("handle:left")])
  return input.wrap ? items.concat([mk("handle:right")]) : [mk("handle:right")].concat(items)
}

function sumExtent(slots, n) {
  var s = 0
  for (var i = 0; i < n; i++) s += slots[i].extent
  return s
}

function zoneLength(pad, slots) {
  if (!slots.length) return 0
  return pad(slots[0].spill) + sumExtent(slots, slots.length) + pad(slots[slots.length - 1].spill)
}

// Where along the centre its fixed point sits: the notch's middle, else the
// anchor's, else the centre's own.
function anchorOffsetOf(input, slots, len) {
  var a = input.zones.anchor
  var key = hasNotch(input) ? NOTCH : a ? a.key : null
  if (!key) return len / 2
  for (var i = 0; i < slots.length; i++) {
    if (slots[i].key === key) return input.pad(slots[0].spill) + sumExtent(slots, i) + slots[i].extent / 2
  }
  return len / 2
}

function layout(input, st) {
  var inset = input.inset
  var g = {
    left: slotsOf(input, "left", st),
    center: slotsOf(input, "center", st),
    right: slotsOf(input, "right", st)
  }
  g.lenL = zoneLength(input.pad, g.left)
  g.lenC = zoneLength(input.pad, g.center)
  g.lenR = zoneLength(input.pad, g.right)
  g.off = anchorOffsetOf(input, g.center, g.lenC)
  g.lo = inset + g.lenL + (g.lenL > 0 ? input.gap : 0)
  g.hi = input.length - inset - g.lenR - (g.lenR > 0 ? input.gap : 0) - g.lenC
  // With a notch the centre starts where its notch slot meets the middle.
  g.target = hasNotch(input) ? input.length / 2 - g.off : null
  return g
}

// Whether the zones keep their gap with `slack` to spare. Without a notch the
// centre may slide anywhere between lo and hi; with one it stays at target.
function roomy(input, g, slack) {
  if (g.target === null) return g.lo + slack <= g.hi
  return g.lo + slack <= g.target + 1e-6 && g.target + slack <= g.hi + 1e-6
}

function unfoldedOf(input, name, st) {
  return zoneItems(input, name).filter(function (it) { return !isFolded(st, it.key) })
}

// Beside a notch: fold on the side that collides, from the longer of the
// side zone and the centre's run on that side. The anchor never folds.
function foldBeside(input, st, g) {
  var z = input.zones, anchor = z.anchor
  var leftSide = g.lo > g.target + 1e-6
  var cand = []
  if (leftSide) {
    var ul = unfoldedOf(input, "left", st)
    var before = anchor ? z.before.filter(function (it) { return !isFolded(st, it.key) }) : []
    if (ul.length > 1) cand.push({ len: g.lenL, key: ul[ul.length - 1].key })
    if (before.length) cand.push({ len: g.off - input.notch / 2, key: before[0].key })
  } else {
    var ur = unfoldedOf(input, "right", st)
    var after = anchor ? z.after.filter(function (it) { return !isFolded(st, it.key) })
      : z.center.filter(function (it) { return !isFolded(st, it.key) })
    if (ur.length > 1) cand.push({ len: g.lenR, key: ur[0].key })
    if (after.length > (anchor ? 0 : 1)) cand.push({ len: g.lenC - g.off - input.notch / 2, key: after[after.length - 1].key })
  }
  if (!cand.length) return false
  var pick = cand[0]
  for (var i = 1; i < cand.length; i++) if (cand[i].len > pick.len) pick = cand[i]
  st.folded[pick.key] = true
  st.order.push(pick.key)
  return true
}

function foldOne(input, st, g) {
  if (hasNotch(input)) return foldBeside(input, st, g)
  var z = input.zones, anchor = z.anchor
  var ul = unfoldedOf(input, "left", st)
  var ur = unfoldedOf(input, "right", st)
  var cand = []
  if (ul.length > 1) cand.push({ name: "left", len: g.lenL })
  if (ur.length > 1) cand.push({ name: "right", len: g.lenR })
  var before = [], after = [], uc = []
  if (anchor) {
    before = z.before.filter(function (it) { return !isFolded(st, it.key) })
    after = z.after.filter(function (it) { return !isFolded(st, it.key) })
    if (before.length + after.length > 0) cand.push({ name: "center", len: g.lenC })
  } else {
    uc = unfoldedOf(input, "center", st)
    if (uc.length >= 2) cand.push({ name: "center", len: g.lenC })
  }
  if (!cand.length) return false
  var pick = cand[0]
  for (var i = 1; i < cand.length; i++) if (cand[i].len > pick.len) pick = cand[i]
  var key
  if (pick.name === "left") key = ul[ul.length - 1].key
  else if (pick.name === "right") key = ur[0].key
  else if (anchor) key = before.length >= after.length ? before[0].key : after[after.length - 1].key
  else key = g.lenL >= g.lenR ? uc[0].key : uc[uc.length - 1].key
  st.folded[key] = true
  st.order.push(key)
  return true
}

function stateOf(input, previous) {
  var st = { folded: {}, order: [] }
  if (!previous) return st
  var zoneOf = {}
  var names = ["left", "center", "right"]
  names.forEach(function (n) {
    zoneItems(input, n).forEach(function (it) { zoneOf[it.key] = n })
  })
  var anchorKey = input.zones.anchor ? input.zones.anchor.key : null
  var left = input.zones.left, right = input.zones.right
  var keep = {}
  names.forEach(function (n) {
    previous.folded[n].forEach(function (key) {
      if (zoneOf[key] !== n || key === anchorKey) return
      if (n === "left" && left[0] && left[0].key === key) return
      if (n === "right" && right.length && right[right.length - 1].key === key) return
      keep[key] = true
    })
  })
  previous.order.forEach(function (key) {
    if (keep[key]) { st.folded[key] = true; st.order.push(key) }
  })
  return st
}

function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)) }

// Where each zone draws its handle: at the end away from its anchor, when
// widgets are folded or hidden on demand; the centre at either end or "both".
// On the notch (input.wrap) the side zones grow away from the camera and the
// dots sit at their far ends, by the screen edges.
function handlesOf(input, st) {
  var c = centerHandles(input, st)
  return {
    left: foldedKeys(input, "left", st).length || hasDots(input, "left") ? (input.wrap ? "start" : "end") : null,
    center: c.start && c.end ? "both" : c.start ? "start" : c.end ? "end" : null,
    right: foldedKeys(input, "right", st).length || hasDots(input, "right") ? (input.wrap ? "end" : "start") : null
  }
}

function resultOf(input, st, g, fits) {
  var cs = g.target !== null ? g.target : fits ? clamp(input.length / 2 - g.off, g.lo, g.hi) : g.lo
  var f = {
    left: foldedKeys(input, "left", st),
    center: foldedKeys(input, "center", st),
    right: foldedKeys(input, "right", st)
  }
  return {
    fits: fits,
    centerStart: cs,
    anchorOffset: g.off,
    centerShift: cs + g.off - input.length / 2,
    folded: f,
    order: st.order.slice(),
    handles: handlesOf(input, st),
    centerFolded: centerFoldSides(input, st),
    yielded: [],
    fallback: null
  }
}

function fitLasting(input) {
  var st = stateOf(input, input.previous || null)
  var g
  while (st.order.length) {
    var key = st.order[st.order.length - 1]
    delete st.folded[key]
    st.order.pop()
    g = layout(input, st)
    if (roomy(input, g, input.gutter)) continue
    st.folded[key] = true
    st.order.push(key)
    break
  }
  g = layout(input, st)
  while (!roomy(input, g, 0)) {
    if (!foldOne(input, st, g)) break
    g = layout(input, st)
  }
  return resultOf(input, st, g, roomy(input, g, 0))
}

function withTransient(input, t) {
  var o = {}
  for (var k in input) o[k] = input[k]
  o.transient = t
  return o
}

function slotStarts(pad, slots, zoneStart) {
  var out = [], x = zoneStart + (slots.length ? pad(slots[0].spill) : 0)
  for (var i = 0; i < slots.length; i++) { out.push(x); x += slots[i].extent }
  return out
}

// Drop slots from the end facing the focus until the island keeps the gap clear.
// Yielded slots keep their space, so the others stay where they are. Once
// anything yields, a marker cell (dots with a count) takes the freed space next
// to the remaining slots, and the island ends past it.
// Returns the yielded keys, or null when an anchor would have to yield.
// range ({ first, last }) limits the slots that may yield and is narrowed by
// what yields, so a centre can yield at both ends without counting twice.
function yieldSlots(input, slots, zoneStart, fromStart, isAnchor, clear, range) {
  var out = []
  var starts = slotStarts(input.pad, slots, zoneStart)
  var r = range || { first: 0, last: slots.length - 1 }
  var first = r.first, last = r.last
  var m = input.marker || input.handle
  while (first <= last) {
    var edge
    if (!out.length) edge = fromStart ? starts[first] - input.pad(slots[first].spill)
      : starts[last] + slots[last].extent + input.pad(slots[last].spill)
    else edge = fromStart ? starts[first] - m.extent - input.pad(m.spill)
      : starts[last] + slots[last].extent + m.extent + input.pad(m.spill)
    if (clear(edge)) break
    var k = fromStart ? first : last
    if (isAnchor(slots[k], slots.slice(first, last + 1))) return null
    out.push(slots[k].key)
    if (fromStart) first++
    else last--
  }
  r.first = first
  r.last = last
  return out
}

function transientsOf(input) {
  var t = input.transient
  if (!t) return []
  return t.length !== undefined ? Array.prototype.slice.call(t) : [t]
}

function fitMoment(input) {
  var ts = transientsOf(input)
  var prev = input.previous || fitLasting(withTransient(input, null))
  // An inline expansion brings its zone's folded widgets back for the moment
  // (the centre's from the side it expands on).
  var folded = { left: prev.folded.left, center: prev.folded.center, right: prev.folded.right }
  var was = { folded: {} }
  folded.center.forEach(function (key) { was.folded[key] = true })
  var sides = centerFoldSides(input, was)
  ts.forEach(function (t) {
    if (!t.unfold) return
    folded[t.unfold] = t.unfold === "center" && t.side ? sides[t.side === "start" ? "end" : "start"] : []
  })
  var all = folded.left.concat(folded.center, folded.right)
  var st = { folded: {}, order: prev.order.filter(function (key) { return all.indexOf(key) >= 0 }) }
  all.forEach(function (key) { st.folded[key] = true })
  var g = layout(input, st)
  // A moment keeps a smaller gap: the island edges are enough while it lasts.
  var length = input.length, inset = input.inset, gap = input.momentGap !== undefined ? input.momentGap : input.gap
  var cs = length / 2 + prev.centerShift - g.off, restingStart = cs
  // An inline expansion of the centre that would run off the bar slides back
  // onto it by the least distance; the zones it then meets hide. Only a centre
  // longer than the bar line falls back.
  // Over a notch the centre never slides.
  if (!hasNotch(input) && ts.some(function(t) { return t.unfold === "center" && t.zone === "center" }) && g.lenC <= length - 2 * inset + 1e-6)
    cs = clamp(cs, inset, length - inset - g.lenC)
  var res = {
    fits: prev.fits,
    centerStart: cs,
    anchorOffset: g.off,
    centerShift: cs === restingStart ? prev.centerShift : cs + g.off - length / 2,
    folded: folded,
    order: st.order.slice(),
    handles: handlesOf(input, st),
    centerFolded: centerFoldSides(input, st),
    yielded: [],
    hidden: { left: false, center: false, right: false },
    fallback: null,
    fallbacks: []
  }
  // Nothing slides: every zone keeps its lasting place, at its current length.
  var span = {
    left: [inset, inset + g.lenL],
    center: [cs, cs + g.lenC],
    right: [length - inset - g.lenR, length - inset]
  }
  var fallbacks = []
  var active = ts.filter(function (t) {
    var reason = null
    if (t.sourceKey && all.indexOf(t.sourceKey) >= 0) reason = "folded"
    else if (!input.wrap && (span[t.zone][0] < inset - 0.5 || span[t.zone][1] > length - inset + 0.5)) reason = "screen"
    if (reason) fallbacks.push({ zone: t.zone, reason: reason })
    return !reason
  })

  var anchorKey = input.zones.anchor ? input.zones.anchor.key : null
  var leftFirst = input.zones.left.length ? input.zones.left[0].key : null
  var rightLast = input.zones.right.length ? input.zones.right[input.zones.right.length - 1].key : null
  // Without an anchor the centre's last widget stands in for it; a centre that
  // is only its handle (every widget hidden on demand) keeps the handle.
  // The notch slot never yields either.
  var centerAnchor = function (s, rest) {
    if (s.key === NOTCH) return true
    if (anchorKey) return s.key === anchorKey
    var widgets = rest.filter(function (x) { return x.key.indexOf("handle:") !== 0 && x.key !== NOTCH }).length
    if (s.key.indexOf("handle:") === 0) return widgets === 0
    return widgets <= 1
  }
  // One zone yields towards a growing neighbour: the left zone from its end,
  // the right zone from its start, the centre from the side facing it. The
  // widgets that are growing never yield.
  var sources = {}
  ts.forEach(function (t) { if (t.sourceKey) sources[t.sourceKey] = true })
  function yieldFrom(zone, fromStart, limit, centerRange) {
    var clear = fromStart ? function (edge) { return edge >= limit - 1e-6 } : function (edge) { return edge <= limit + 1e-6 }
    if (zone === "left") return yieldSlots(input, g.left, inset, false, function (s) { return sources[s.key] || s.key === leftFirst }, clear)
    if (zone === "right") return yieldSlots(input, g.right, span.right[0], true, function (s) { return sources[s.key] || s.key === rightLast }, clear)
    return yieldSlots(input, g.center, cs, fromStart, function (s, rest) { return sources[s.key] || centerAnchor(s, rest) }, clear, centerRange)
  }
  // The yields for a set of growing zones, or the zone that can't be served.
  // An inline expansion (unfold) that meets an anchor hides the whole zone in
  // its way, and then makes the zone past it give way in turn.
  function attempt(active) {
    var rank = {}, unfolding = {}
    active.forEach(function(t, i) {
      if (rank[t.zone] === undefined) rank[t.zone] = i
      if (t.unfold) unfolding[t.zone] = true
    })
    var names = g.center.length ? ["left", "center", "right"] : ["left", "right"]
    var centerRange = { first: 0, last: g.center.length - 1 }
    var y = [], hidden = {}
    function hide(zone) {
      hidden[zone] = true
      y = y.concat(g[zone].map(function(s) { return s.key }))
    }
    for (var p = 0; p + 1 < names.length; p++) {
      var a = names[p], b = names[p + 1]
      var ga = rank[a] !== undefined, gb = rank[b] !== undefined
      if (!ga && !gb) continue
      if (ga && gb) {
        if (span[a][1] + gap <= span[b][0] + 1e-6) continue
        // Both grow and meet: the higher priority zone keeps its growing widget
        // and yields the rest towards the other; if it can't, the other falls back.
        var aFirst = rank[a] < rank[b]
        var yb = aFirst ? yieldFrom(a, false, span[b][0] - gap, centerRange) : yieldFrom(b, true, span[a][1] + gap, centerRange)
        if (!yb) return { fail: aFirst ? b : a, reason: "neighbour" }
        y = y.concat(yb)
        continue
      }
      var grower = ga ? a : b, other = ga ? b : a
      if (hidden[other]) continue
      var limit = ga ? span[a][1] + gap : span[b][0] - gap
      var ys = yieldFrom(other, ga, limit, centerRange)
      if (ys) { y = y.concat(ys); continue }
      if (!unfolding[grower]) return { fail: grower, reason: "anchor" }
      // Nothing runs over the camera: the expansion opens as a drawer.
      if (other === "center" && hasNotch(input)) return { fail: grower, reason: "notch" }
      hide(other)
      // Past the hidden zone, the next one gives way to the expansion too.
      var beyond = names[ga ? p + 2 : p - 1]
      if (!beyond || hidden[beyond]) continue
      if (rank[beyond] !== undefined) {
        var apart = ga ? span[a][1] + gap <= span[beyond][0] + 1e-6 : span[beyond][1] + gap <= span[b][0] + 1e-6
        if (!apart) return { fail: rank[grower] < rank[beyond] ? beyond : grower, reason: "neighbour" }
        continue
      }
      var yf = yieldFrom(beyond, ga, limit, null)
      if (yf) y = y.concat(yf)
      else hide(beyond)
    }
    var seen = {}
    y = y.filter(function(key) { if (seen[key]) return false; seen[key] = true; return true })
    return { yielded: y, hidden: hidden }
  }
  var out = input.wrap ? { yielded: [], hidden: {} } : attempt(active)
  while (out.fail) {
    var failed = out.fail, reason = out.reason
    active = active.filter(function (t) {
      if (t.zone !== failed) return true
      fallbacks.push({ zone: t.zone, reason: reason })
      return false
    })
    out = attempt(active)
  }
  res.yielded = out.yielded
  for (var zone in out.hidden) res.hidden[zone] = true
  res.fallbacks = fallbacks
  res.fallback = fallbacks.length ? fallbacks[0] : null
  return res
}

// fit(input) -> { fits, centerStart, anchorOffset, centerShift, folded, order,
//                 handles, centerFolded, yielded, fallback, fallbacks (moments) }.
//                 See the lab for the input shape.
function fit(input) {
  return input.transient ? fitMoment(input) : fitLasting(input)
}
