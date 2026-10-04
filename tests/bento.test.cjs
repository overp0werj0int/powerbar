const { test } = require('node:test');
const assert = require('node:assert/strict');
const bento = require('../BentoModel.js');

// The Bar page's tiles, in reading order: Style, Position, Size, Shape,
// Surface, Shadow, Behavior, On demand.
const bar = [[6, 6], [3, 3], [3, 3], [4, 3], [4, 3], [4, 6], [6, 3], [6, 3]]
  .map(([span12, span6], i) => ({ span12, span6, height: 100 + i }));

test('columns follow the window width', () => {
  assert.equal(bento.columnsFor(1180), 12);
  assert.equal(bento.columnsFor(1100), 12);
  assert.equal(bento.columnsFor(1099), 6);
  assert.equal(bento.columnsFor(820), 6);
  assert.equal(bento.columnsFor(819), 1);
});

test('every row of the Bar page is full at 12 and at 6 columns', () => {
  for (const columns of [12, 6]) {
    const rows = {};
    const { rects } = bento.place(bar, columns, 1000, 8);
    rects.forEach((r, i) => { rows[r.row] = (rows[r.row] || 0) + bento.spanFor(bar[i], columns); });
    Object.values(rows).forEach(used => assert.equal(used, columns, `${columns} columns: ${JSON.stringify(rows)}`));
  }
});

test('tiles in a row share its tallest height and touch both edges', () => {
  const width = 1124, gap = 8;
  const { rects, height } = bento.place(bar, 12, width, gap);
  assert.deepEqual(rects.map(r => r.row), [0, 0, 0, 1, 1, 1, 2, 2]);
  assert.deepEqual(rects.slice(0, 3).map(r => r.height), [102, 102, 102]);
  for (const row of [0, 1, 2]) {
    const inRow = rects.filter(r => r.row === row);
    assert.equal(inRow[0].x, 0);
    const last = inRow[inRow.length - 1];
    assert.ok(Math.abs(last.x + last.width - width) < 1e-9);
    // Neighbours sit exactly one gap apart.
    inRow.slice(1).forEach((r, i) => assert.ok(Math.abs(r.x - (inRow[i].x + inRow[i].width) - gap) < 1e-9));
  }
  assert.equal(height, 102 + 105 + 107 + 2 * gap);
});

test('one column stacks every tile at full width', () => {
  const { rects, height } = bento.place(bar, 1, 500, 8);
  rects.forEach((r, i) => { assert.equal(r.x, 0); assert.equal(r.width, 500); assert.equal(r.row, i); });
  assert.equal(height, bar.reduce((s, t) => s + t.height, 0) + 7 * 8);
});

test('a span wider than the grid is clamped, and an empty page has no height', () => {
  assert.equal(bento.spanFor({ span12: 20, span6: 9 }, 6), 6);
  assert.equal(bento.place([], 12, 900, 8).height, 0);
});

test('Tab walks tiles round, skipping ones with nothing to focus', () => {
  const ok = i => i !== 2;
  assert.equal(bento.nextTile(4, 1, true, ok), 3);
  assert.equal(bento.nextTile(4, 3, true, ok), 0);
  assert.equal(bento.nextTile(4, 0, false, ok), 3);
  assert.equal(bento.nextTile(4, 3, false, ok), 1);
  assert.equal(bento.nextTile(3, 0, true, () => false), -1);
  // From outside every tile: Tab lands on the first, Shift+Tab on the last.
  assert.equal(bento.nextTile(4, -1, true, () => true), 0);
  assert.equal(bento.nextTile(4, 4, false, () => true), 3);
});
