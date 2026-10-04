// Where the tiles of a bento page sit. A page has 12 columns in a wide
// window, 6 in a medium one and 1 in a narrow one; each tile says how many it
// spans at 12 and at 6. Tiles fill rows in reading order, a tile that does not
// fit what is left of a row starts the next one, and every tile in a row takes
// the row's tallest height so the row reads as one band.

var WIDE = 1100
var MEDIUM = 820

function columnsFor(windowWidth) { return windowWidth >= WIDE ? 12 : windowWidth >= MEDIUM ? 6 : 1 }

function spanFor(tile, columns) {
  var span = columns === 12 ? tile.span12 : columns === 6 ? tile.span6 : 1
  return Math.max(1, Math.min(columns, Math.round(Number(span) || columns)))
}

// tiles: [{ span12, span6, height }]; returns { rects: [{ x, y, width, height, row }], height }.
function place(tiles, columns, width, gap) {
  var cols = Math.max(1, columns)
  var unit = Math.max(0, (width - gap * (cols - 1)) / cols)
  var rows = []
  var row = null
  tiles.forEach(function(tile, index) {
    var span = spanFor(tile, cols)
    if (!row || row.used + span > cols) { row = { used: 0, items: [], height: 0 }; rows.push(row) }
    row.items.push({ index: index, column: row.used, span: span })
    row.used += span
    row.height = Math.max(row.height, Number(tile.height) || 0)
  })
  var rects = []
  var y = 0
  rows.forEach(function(r, n) {
    r.items.forEach(function(item) {
      rects[item.index] = { x: item.column * (unit + gap), y: y, width: unit * item.span + gap * (item.span - 1),
        height: r.height, row: n }
    })
    y += r.height + gap
  })
  return { rects: rects, height: rows.length ? y - gap : 0 }
}

// The tile Tab moves to from `current`, skipping tiles with nothing to focus.
function nextTile(count, current, forward, focusable) {
  for (var step = 1; step <= count; step++) {
    var i = ((current + (forward ? step : -step)) % count + count) % count
    if (focusable(i)) return i
  }
  return -1
}

if (typeof module !== "undefined") module.exports = { WIDE, MEDIUM, columnsFor, spanFor, place, nextTile }
