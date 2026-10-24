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
  // A submenu opened on its menu's left: its card stays on the left, off the menu.
  const sub = Object.assign({}, menu, { before: true });
  assert.deepEqual(tips.place('top', rowItem, popup, gap, sub, true, { width: 1920, height: 1000 }), { x: 294, y: 100 });
  // Unless there is no room there.
  assert.deepEqual(tips.place('top', rowItem, popup, gap, Object.assign({}, sub, { x: 50 }), true, { width: 1920, height: 1000 }), { x: 276, y: 100 });
});

const m = tips;
test('a tooltip on the bar clears the bar strip, not just its target cell (islands, large bar)', () => {
  const popup = { width: 100, height: 20 }, cell = { x: 200, y: 7, width: 32, height: 32 };
  // Top: the strip reaches 46 px, past the cell's 39: the tooltip starts 6 px below the strip.
  assert.equal(m.place('top', cell, popup, 6, null, false, null, { x: 0, y: 0, width: 1920, height: 46 }).y, 52);
  assert.equal(m.place('top', cell, popup, 6).y, 45, 'without a strip: from the cell, as before');
  // Bottom: strip from 954, cell from 961: the tooltip ends 6 px above the strip.
  assert.equal(m.place('bottom', { x: 200, y: 961, width: 32, height: 32 }, popup, 6, null, false, null, { x: 0, y: 954, width: 1920, height: 46 }).y, 954 - 20 - 6);
  // Sides.
  assert.equal(m.place('left', { x: 7, y: 300, width: 32, height: 32 }, popup, 6, null, false, null, { x: 0, y: 0, width: 46, height: 1080 }).x, 52);
  assert.equal(m.place('right', { x: 1881, y: 300, width: 32, height: 32 }, popup, 6, null, false, null, { x: 1874, y: 0, width: 46, height: 1080 }).x, 1874 - 100 - 6);
  // A strip nearer than the target never pulls the tooltip in.
  assert.equal(m.place('top', cell, popup, 6, null, false, null, { x: 0, y: 0, width: 1920, height: 30 }).y, 45);
});

test("a widget at the screen's end slides its tooltip back onto the window, along the bar only", () => {
  const popup = { width: 100, height: 20 }, screen = { width: 1512, height: 945 };
  // Top bar, the last widget: centred it would run 30 px past the end.
  assert.deepEqual(m.place('top', { x: 1482, y: 7, width: 20, height: 32 }, popup, 6, null, false, screen, null, 4), { x: 1408, y: 45 });
  // The first one: held 4 px in from the start.
  assert.deepEqual(m.place('top', { x: 8, y: 7, width: 20, height: 32 }, popup, 6, null, false, screen, null, 4), { x: 4, y: 45 });
  // A side bar slides it along the screen's height.
  assert.deepEqual(m.place('left', { x: 7, y: 935, width: 32, height: 20 }, popup, 6, null, false, screen, null, 4), { x: 45, y: 921 });
  // A strip's end member, the same.
  const strip = { x: 1200, y: 46, width: 312, height: 44, vertical: false };
  assert.equal(m.place('top', { x: 1480, y: 48, width: 30, height: 40 }, popup, 6, strip, true, screen, null, 4).x, 1408);
  // No bounds: as before, centred wherever that falls.
  assert.equal(m.place('top', { x: 8, y: 7, width: 20, height: 32 }, popup, 6).x, -32);
});

test('a slid tooltip beside an open drawer still clears the drawer', () => {
  const popup = { width: 100, height: 20 }, screen = { width: 1512, height: 945 };
  // The last widget's tooltip slides left, onto the drawer hanging below the bar.
  const drawer = { x: 1380, y: 46, width: 132, height: 44, vertical: false };
  assert.deepEqual(m.place('top', { x: 1482, y: 7, width: 20, height: 32 }, popup, 6, drawer, false, screen, null, 4), { x: 1408, y: 96 });
});
