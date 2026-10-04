// The On the bar shelf of Preferences > Layout draws each zone the way the bar
// does (docs/prefs-layout-lab): every widget gets the slot the bar would give
// it (CellModel.place), its ink at the slot's ink start, with the island's end
// padding (CellModel.endPad). A zone longer than the room it has wraps onto
// another line rather than shrinking; each line is an island of its own.
//
// `cells` is CellModel (passed in, since models do not import each other).
// items: [{ inkStart, inkLength, glyph, cap }], where inkStart is where the
// ink begins inside the widget's own picture.
// Returns { lines: [{ width, slots: [{ index, x, extent, cell, inkStart, offset }] }], width }:
//   x        the slot's start inside its line's island
//   offset   where the widget's picture starts inside the slot
function zone(cells, k, items, room) {
  var placed = (items || []).map(function(item, index) {
    var p = cells.place(k, Math.max(0, Number(item.inkLength) || 0), !!item.glyph, item.cap)
    return { index: index, extent: p.extent, cell: p.cell, inkStart: p.inkStart, spill: p.spill,
      offset: p.inkStart - (Number(item.inkStart) || 0) }
  })
  var lines = [], line = null
  function close() {
    if (!line) return
    var last = line.slots[line.slots.length - 1]
    line.width = line.x + cells.endPad(k, last ? last.spill : 0)
    lines.push(line)
    line = null
  }
  placed.forEach(function(p) {
    var start = cells.endPad(k, p.spill)
    var fits = !line || line.x + p.extent + cells.endPad(k, p.spill) <= room
    if (!fits) close()
    if (!line) line = { x: start, slots: [], width: 0 }
    line.slots.push({ index: p.index, x: line.x, extent: p.extent, cell: p.cell, inkStart: p.inkStart, offset: p.offset, spill: p.spill })
    line.x += p.extent
  })
  close()
  return { lines: lines, width: lines.reduce(function(w, l) { return Math.max(w, l.width) }, 0) }
}

// The line and slot of item `index`, or null.
function slotOf(layout, index) {
  for (var n = 0; n < layout.lines.length; n++) {
    var slots = layout.lines[n].slots
    for (var i = 0; i < slots.length; i++) if (slots[i].index === index) return { line: n, slot: slots[i] }
  }
  return null
}

if (typeof module !== "undefined") module.exports = { zone, slotOf }
