// Zones never overlap: the solver that fits the left, centre and right zones
// along one bar line. A lasting length slides the centre by the least distance
// that keeps one zone gap, then folds widgets into drawers (longest zone first);
// a moment (transient growth) slides nothing and makes neighbours yield.
// In the inline on-demand mode a zone with hidden widgets keeps its handle
// (input.dots; the centre's value says which side), and hovering it is a
// moment that unfolds the zone (unfold). Several moments can run at once
// (input.transient is one or a list, highest priority first): neighbours yield
// to every growing zone, and when two growing zones collide the lower one
// falls back.
// See docs/zone-fit-lab/zone-fit-lab.html for the specification.

function zoneItems(input, name) {
  var z = input.zones
  if (name === "center") return z.anchor ? z.before.concat([z.anchor], z.after) : z.center
  return z[name]
}

function isFolded(st, key) { return st.folded[key] === true }

function foldedKeys(input, name, st) {
  return zoneItems(input, name).filter(function (it) { return isFolded(st, it.key) }).map(function (it) { return it.key })
}

function hasDots(input, name) { return !!(input.dots && input.dots[name]) }

// The centre's handle sits where its folds are, else where its hidden
// widgets are (input.dots.center: "start" or "end"), so it marks the side
// the zone grows on.
function centerSide(input, folds, hc) {
  if (folds) return hc || "end"
  return input.dots && input.dots.center === "start" ? "start" : "end"
}

// The zone's slots in bar order: unfolded items plus the drawer handle slot.
function slotsOf(input, name, st) {
  var items = zoneItems(input, name).filter(function (it) { return !isFolded(st, it.key) })
  if (!foldedKeys(input, name, st).length && !hasDots(input, name)) return items
  var h = { key: "handle:" + name, extent: input.handle.extent, spill: input.handle.spill }
  if (name === "left") return items.concat([h])
  if (name === "right") return [h].concat(items)
  return centerSide(input, foldedKeys(input, name, st).length > 0, st.hc) === "start" ? [h].concat(items) : items.concat([h])
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

function anchorOffsetOf(input, slots, len) {
  var a = input.zones.anchor
  if (!a) return len / 2
  for (var i = 0; i < slots.length; i++) {
    if (slots[i].key === a.key) return input.pad(slots[0].spill) + sumExtent(slots, i) + a.extent / 2
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
  return g
}

function unfoldedOf(input, name, st) {
  return zoneItems(input, name).filter(function (it) { return !isFolded(st, it.key) })
}

function foldOne(input, st, g) {
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
  var key, side = null
  if (pick.name === "left") key = ul[ul.length - 1].key
  else if (pick.name === "right") key = ur[0].key
  else if (anchor) {
    if (before.length >= after.length) { key = before[0].key; side = "start" }
    else { key = after[after.length - 1].key; side = "end" }
  } else if (g.lenL >= g.lenR) { key = uc[0].key; side = "start" }
  else { key = uc[uc.length - 1].key; side = "end" }
  if (side && !st.hc) st.hc = side
  st.folded[key] = true
  st.order.push(key)
  return true
}

function stateOf(input, previous) {
  var st = { folded: {}, order: [], hc: null }
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
  if (foldedKeys(input, "center", st).length) st.hc = previous.handles.center || "end"
  return st
}

function clamp(v, lo, hi) { return Math.min(hi, Math.max(lo, v)) }

// Where each zone draws its handle: at the end away from its anchor, when
// widgets are folded or (inline mode) hidden on demand.
function handlesOf(input, f, hc) {
  return {
    left: f.left.length || hasDots(input, "left") ? "end" : null,
    center: f.center.length || hasDots(input, "center") ? centerSide(input, f.center.length > 0, hc) : null,
    right: f.right.length || hasDots(input, "right") ? "start" : null
  }
}

function resultOf(input, st, g, fits) {
  var cs = fits ? clamp(input.length / 2 - g.off, g.lo, g.hi) : g.lo
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
    handles: handlesOf(input, f, st.hc),
    yielded: [],
    fallback: null
  }
}

function fitLasting(input) {
  var st = stateOf(input, input.previous || null)
  var g
  while (st.order.length) {
    var key = st.order[st.order.length - 1]
    var oldHc = st.hc
    delete st.folded[key]
    st.order.pop()
    if (!foldedKeys(input, "center", st).length) st.hc = null
    g = layout(input, st)
    if (g.lo + input.gutter <= g.hi) continue
    st.folded[key] = true
    st.order.push(key)
    st.hc = oldHc
    break
  }
  g = layout(input, st)
  while (g.lo > g.hi) {
    if (!foldOne(input, st, g)) break
    g = layout(input, st)
  }
  return resultOf(input, st, g, g.lo <= g.hi)
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
  // An inline expansion brings its zone's folded widgets back for the moment.
  var folded = { left: prev.folded.left, center: prev.folded.center, right: prev.folded.right }
  ts.forEach(function (t) { if (t.unfold) folded[t.unfold] = [] })
  var all = folded.left.concat(folded.center, folded.right)
  var st = { folded: {}, order: prev.order.filter(function (key) { return all.indexOf(key) >= 0 }), hc: prev.handles.center }
  all.forEach(function (key) { st.folded[key] = true })
  var g = layout(input, st)
  // A moment keeps a smaller gap: the island edges are enough while it lasts.
  var length = input.length, inset = input.inset, gap = input.momentGap !== undefined ? input.momentGap : input.gap
  var cs = length / 2 + prev.centerShift - g.off
  var res = {
    fits: prev.fits,
    centerStart: cs,
    anchorOffset: g.off,
    centerShift: prev.centerShift,
    folded: folded,
    order: st.order.slice(),
    handles: handlesOf(input, folded, prev.handles.center),
    yielded: [],
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
    else if (span[t.zone][0] < inset - 0.5 || span[t.zone][1] > length - inset + 0.5) reason = "screen"
    if (reason) fallbacks.push({ zone: t.zone, reason: reason })
    return !reason
  })

  var anchorKey = input.zones.anchor ? input.zones.anchor.key : null
  var leftFirst = input.zones.left.length ? input.zones.left[0].key : null
  var rightLast = input.zones.right.length ? input.zones.right[input.zones.right.length - 1].key : null
  // Without an anchor the centre's last widget stands in for it; a centre that
  // is only its handle (every widget hidden on demand) keeps the handle.
  var centerAnchor = function (s, rest) {
    if (anchorKey) return s.key === anchorKey
    var widgets = rest.filter(function (x) { return x.key.indexOf("handle:") !== 0 }).length
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
  function attempt(active) {
    var rank = {}
    active.forEach(function (t, i) { if (rank[t.zone] === undefined) rank[t.zone] = i })
    var pairs = g.center.length ? [["left", "center"], ["center", "right"]] : [["left", "right"]]
    var centerRange = { first: 0, last: g.center.length - 1 }
    var y = []
    for (var p = 0; p < pairs.length; p++) {
      var a = pairs[p][0], b = pairs[p][1]
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
      var ys = ga ? yieldFrom(b, true, span[a][1] + gap, centerRange) : yieldFrom(a, false, span[b][0] - gap, centerRange)
      if (!ys) return { fail: ga ? a : b, reason: "anchor" }
      y = y.concat(ys)
    }
    return { yielded: y }
  }
  var out = attempt(active)
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
  res.fallbacks = fallbacks
  res.fallback = fallbacks.length ? fallbacks[0] : null
  return res
}

// fit(input) -> { fits, centerStart, anchorOffset, centerShift, folded, order,
//                 handles, yielded, fallback, fallbacks (moments) }. See the lab
//                 for the input shape.
function fit(input) {
  return input.transient ? fitMoment(input) : fitLasting(input)
}
