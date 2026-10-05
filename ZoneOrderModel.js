// The order a zone draws its widgets in. On-demand widgets wait behind their
// zone's dots, so they draw as one run at the dots' end of their list, in their
// saved order; every other widget keeps its saved order and never moves when
// they appear. The saved layout is not rewritten: only the drawing differs.
//
// Lists: "left", "after" and an anchorless "center" have their dots at the end;
// "right" and "before" (the centre's side before its anchor) at the start.

function dotsAtStart(list) { return list === "right" || list === "before" }

function arrange(items, isManaged, list) {
  if (list === "anchor") return items.slice()
  var shown = [], managed = []
  items.forEach(function (item) { (isManaged(item) ? managed : shown).push(item) })
  return dotsAtStart(list) ? managed.concat(shown) : shown.concat(managed)
}

// Where a drop lands in the saved layout, given the gap it opened in the
// drawn order. The widget joins the run of its visibility in the gap's list,
// so it lands exactly at the gap: before the first widget of that run after
// the gap, else after the last one before it, else (an empty run) beside the
// anchor on the gap's side, or at the zone's end.
//   o.sequence  the zone as drawn: [{ key, list, managed, group }]
//   o.gap       index into the sequence without the source
//   o.managed   the widget lands On demand
//   o.layout    the zone's saved keys, in saved order (no group icons)
//   o.source    the moving widget's key
//   o.anchorKey the centre anchor's key, or ""
// Returns the key to insert before, or "" for the zone's end.
function dropBefore(o) {
  var seq = o.sequence.filter(function (item) { return item.key !== o.source })
  var gap = Math.max(0, Math.min(o.gap, seq.length))
  var anchorAt = -1
  for (var a = 0; a < seq.length; a++) if (seq[a].list === "anchor") { anchorAt = a; break }
  var near = seq[gap - 1] || seq[gap] || null
  var list = anchorAt >= 0 ? (gap <= anchorAt ? "before" : "after") : near ? near.list : ""
  if (list === "anchor") list = "after"
  function peer(item) { return item.list === list && !!item.managed === !!o.managed && !item.group }
  for (var i = gap; i < seq.length; i++) if (peer(seq[i])) return seq[i].key
  for (var j = gap - 1; j >= 0; j--) if (peer(seq[j])) return successor(o.layout, seq[j].key, o.source)
  return list === "before" && o.anchorKey && o.anchorKey !== o.source ? o.anchorKey : ""
}

// Whether a drop into a gap lands On demand. Only inside the expansion's run:
// the gap's neighbours are both widgets the expansion shows, or one of them is
// and the other side is the zone's dots end. Where the shown widgets meet the
// expansion, the gap belongs to the run of the neighbour the pointer is on
// (near: its key); without one it is the end of the shown run, so it lands shown.
// Neighbours are the nearest widgets on screen: hidden ones (group members,
// widgets waiting behind other dots) are skipped.
//   sequence: the zone as drawn, without the moving widget
//             [{ key, list, managed, expanded, hidden }] (expanded: shown by an expansion)
//   gap:      index into the sequence
function neighbours(sequence, gap) {
  var prev = null, next = null
  for (var i = gap - 1; i >= 0 && !prev; i--) if (!sequence[i].hidden) prev = sequence[i]
  for (var j = gap; j < sequence.length && !next; j++) if (!sequence[j].hidden) next = sequence[j]
  return { prev: prev, next: next }
}
function landsOnDemand(sequence, gap, near) {
  var n = neighbours(sequence, gap), prev = n.prev, next = n.next
  var nearItem = near && prev && prev.key === near ? prev : near && next && next.key === near ? next : null
  var list = (prev || next || {}).list
  function side(item, dotsHere) {
    if (item) return item.expanded ? "demand" : "shown"
    return dotsHere ? "demand" : "edge"
  }
  var before = side(prev, dotsAtStart(list)), after = side(next, !dotsAtStart(list) && list !== "anchor")
  if (nearItem && before !== after && (before === "shown" || after === "shown")) return !!nearItem.expanded
  if (before === "shown" || after === "shown") return false
  return before === "demand" || after === "demand"
}

function successor(layout, key, source) {
  var keys = layout.filter(function (k) { return k !== source })
  var at = keys.indexOf(key)
  return at >= 0 && at + 1 < keys.length ? keys[at + 1] : ""
}

if (typeof module !== "undefined") module.exports = { arrange, dropBefore, dotsAtStart, landsOnDemand, neighbours }
