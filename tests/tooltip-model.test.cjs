const { test } = require('node:test');
const assert = require('node:assert/strict');
const tips = require('../TooltipModel.js');

const popup = { width: 100, height: 30 };
const gap = 6;

test('a tooltip sits out from the bar, centred on its target', () => {
  const icon = { x: 1000, y: 500, width: 40, height: 40 };
  assert.deepEqual(tips.place('right', icon, popup, gap, null, false), { x: 894, y: 505 });
  assert.deepEqual(tips.place('left', icon, popup, gap, null, false), { x: 1046, y: 505 });
  assert.deepEqual(tips.place('top', icon, popup, gap, null, false), { x: 970, y: 546 });
  assert.deepEqual(tips.place('bottom', icon, popup, gap, null, false), { x: 970, y: 464 });
});

test('a bar item beside an open drawer puts its tooltip past the drawer', () => {
  // Right bar: the drawer opens to the left of the bar, over the tooltip's spot.
  const icon = { x: 1000, y: 500, width: 40, height: 40 };
  const drawer = { x: 900, y: 450, width: 94, height: 200, vertical: true };
  assert.deepEqual(tips.place('right', icon, popup, gap, drawer, false), { x: 794, y: 505 });
  // An icon clear of the drawer keeps its usual spot.
  const far = { x: 1000, y: 100, width: 40, height: 40 };
  assert.deepEqual(tips.place('right', far, popup, gap, drawer, false), { x: 894, y: 105 });
  // Top bar: the drawer hangs below; the tooltip goes below it.
  const top = { x: 500, y: 0, width: 40, height: 40 };
  const below = { x: 480, y: 46, width: 300, height: 44, vertical: false };
  assert.deepEqual(tips.place('top', top, popup, gap, below, false), { x: 470, y: 96 });
});

test("a drawer's item puts its tooltip outside the drawer", () => {
  // Right bar, a strip running down: left of the strip, level with the item.
  const strip = { x: 900, y: 400, width: 50, height: 300, vertical: true };
  const item = { x: 905, y: 500, width: 40, height: 40 };
  assert.deepEqual(tips.place('right', item, popup, gap, strip, true), { x: 794, y: 505 });
  // Top bar, a strip running along: below the strip.
  const row = { x: 400, y: 46, width: 300, height: 44, vertical: false };
  const cell = { x: 450, y: 48, width: 40, height: 40 };
  assert.deepEqual(tips.place('top', cell, popup, gap, row, true), { x: 420, y: 96 });
  // Top bar, a menu of rows: beside the menu, level with the row.
  const menu = { x: 400, y: 46, width: 220, height: 200, vertical: true };
  const rowItem = { x: 410, y: 100, width: 30, height: 30 };
  assert.deepEqual(tips.place('top', rowItem, popup, gap, menu, true), { x: 626, y: 100 });
  // No room on the right of the menu: on its left, never slid back over it.
  assert.deepEqual(tips.place('top', rowItem, popup, gap, menu, true, { width: 700, height: 1000 }), { x: 294, y: 100 });
});
