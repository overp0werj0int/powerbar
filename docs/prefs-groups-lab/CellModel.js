// One cell, one inset: the geometry every bar item, island and drawer shares.
// See docs/spacing-lab/spacing-lab.html for the specification.
//
// Along the bar every item gets a cell: square for glyphs, the ink plus the
// same side air a glyph has for text and compounds. The cell is also the
// highlight. Equal slots puts cells one gutter apart; Equal gaps puts the same
// air between every pair of glyphs and lets the cell spill into the gaps.

var TYPICAL_GLYPH = 12
var MAX_INK = 160
var GLYPH_INK = 16

// Tokens for a bar `bar` px thick.
//   o.bar       thickness across the bar
//   o.spacing   Space between widgets (widens gutters and gaps, never cells)
//   o.mode      "slots" (default) or "gaps"
function tokens(o) {
  var bar = Math.max(0, Number(o && o.bar) || 0)
  var inset = Math.min(3, Math.max(0, (bar - 16) / 2))
  var thickness = bar - 2 * inset
  var spacing = Math.max(0, Number(o && o.spacing) || 0)
  var cell = thickness
  return {
    bar: bar,
    inset: inset,
    thickness: thickness,
    cell: cell,
    air: Math.max(0, (cell - TYPICAL_GLYPH) / 2),
    gutter: inset + spacing,
    gap: cell / 2 + 2 + spacing,
    spacing: spacing,
    mode: o && o.mode === "gaps" ? "gaps" : "slots"
  }
}

// Highlight radius nested one inset inside an island of radius `rounding`.
function radius(k, rounding) {
  return Math.max(0, Math.min(k.thickness / 2, (Number(rounding) || 0) - k.inset))
}

// A glyph is what reads as an icon: the kit says so, or it paints no wider
// than a large icon glyph in one piece.
function isGlyph(ink, glyphHint) {
  return !!glyphHint || (ink > 0 && ink <= GLYPH_INK)
}

// The cell's length along the bar. Only free text (window titles, media) is
// capped at MAX_INK; compounds and vertical stacks keep their full length.
// A glyph's cell is square, but only while its ink fits in it: a narrow stack
// that is long along the bar (ScratchPeek's mark over its count on a side bar
// reads as a glyph across) gets the room text gets, so its slot and highlight
// never cut what it paints.
function cellLength(k, ink, glyph, cap) {
  if (glyph && ink <= k.cell) return k.cell
  var shown = cap === false ? Math.max(0, ink) : Math.min(Math.max(0, ink), MAX_INK)
  return Math.max(k.cell, shown + 2 * k.air)
}

// Where an item sits along the bar.
//   ink     painted length along the bar
//   glyph   whether it reads as an icon
// Returns { extent, cell, inkStart, shown, spill }:
//   extent    the slot's length (hit area included); slots follow each other with no spacing
//   cell      the highlight's length, centred on the slot
//   inkStart  where the painted content starts inside the slot
//   shown     painted length after the free-text cap
//   spill     how far the cell reaches past the ink on each side (Equal gaps)
function place(k, ink, glyph, cap) {
  ink = Math.max(0, ink)
  var shown = glyph || cap === false ? ink : Math.min(ink, MAX_INK)
  var cell = cellLength(k, ink, glyph, cap)
  if (k.mode === "gaps") {
    return { extent: shown + k.gap, cell: cell, inkStart: k.gap / 2, shown: shown, spill: (cell - shown) / 2 }
  }
  return { extent: cell + k.gutter, cell: cell, inkStart: k.gutter / 2 + (cell - shown) / 2, shown: shown, spill: (cell - shown) / 2 }
}

// Island end padding beyond the first or last slot, so the end cell sits one
// inset from the island's end and its curve runs parallel to the island's.
function endPad(k, spill) {
  if (k.mode === "gaps") return k.inset + Math.max(0, spill) - k.gap / 2
  return k.inset - k.gutter / 2
}

// The highlight for a placed slot, in slot coordinates along the bar.
function highlight(k, p, rounding) {
  return { start: (p.extent - p.cell) / 2, length: p.cell, thickness: k.thickness, radius: radius(k, rounding) }
}

// The gap a drag opens is the dragged item's own landing size, and the
// timing grows with it so wide items don't sweep their neighbours.
function dragGap(k, p) { return p.extent }
function iconGap(k) { return k.mode === "gaps" ? TYPICAL_GLYPH + k.gap : k.cell + k.gutter }
function dragDuration(gap, icon) {
  var ratio = icon > 0 ? Math.max(0, gap) / icon : 1
  return Math.round(Math.max(150, Math.min(260, 150 * Math.sqrt(ratio))))
}

// Width hold: a cell grows at once and shrinks only after it has been
// narrower for `holdMs`, so a value that flickers (9% ↔ 100%) never makes the
// bar breathe. Losing at least `snap` (one icon cell) means something went
// away, a reveal closing or an item leaving, so the cell shrinks at once.
// Returns { value, shrinkAt } for the new target.
function hold(held, target, now, holdMs, shrinkAt, snap) {
  if (!(held > 0) || target >= held) return { value: target, shrinkAt: 0 }
  if (snap > 0 && held - target >= snap) return { value: target, shrinkAt: 0 }
  if (shrinkAt > 0 && now >= shrinkAt) return { value: target, shrinkAt: 0 }
  return { value: held, shrinkAt: shrinkAt > 0 ? shrinkAt : now + holdMs }
}

// Compound thumbs: one per click target, nested at the track's curve.
function thumb(k, pitch, rounding) {
  var side = Math.min(k.thickness, Math.max(1, pitch - 1))
  return { side: side, radius: Math.max(0, radius(k, rounding) - (k.thickness - side) / 2) }
}

// A badge on a highlight's top-right corner (outer-top on a vertical bar),
// at 45° on its curve, kept 1 px inside the island on both axes.
//   hl        { x, y, width, height, radius } in island coordinates
//   island    { width, height }
//   size      { width, height } of the badge
function badge(hl, island, size) {
  var k45 = hl.radius * (1 - Math.SQRT1_2)
  var x = hl.x + hl.width - k45 - size.width / 2
  var y = hl.y + k45 - size.height / 2
  x = Math.max(1, Math.min(island.width - 1 - size.width, x))
  y = Math.max(1, Math.min(island.height - 1 - size.height, y))
  return { x: x, y: y }
}

if (typeof module !== "undefined") module.exports = {
  tokens: tokens, radius: radius, isGlyph: isGlyph, cellLength: cellLength, place: place,
  endPad: endPad, highlight: highlight, dragGap: dragGap, iconGap: iconGap,
  dragDuration: dragDuration, hold: hold, thumb: thumb, badge: badge,
  MAX_INK: MAX_INK, GLYPH_INK: GLYPH_INK
}
