const { test } = require('node:test');
const assert = require('node:assert/strict');
const keys = require('../BarKeysModel.js');

test('the along keys follow the edge, the into key points into the screen', () => {
  assert.deepEqual(keys.barIntent('right', 'Down'), { move: 1 });
  assert.deepEqual(keys.barIntent('right', 'k'), { move: -1 });
  assert.deepEqual(keys.barIntent('right', 'Left'), { into: true });
  assert.equal(keys.barIntent('right', 'Right'), null, 'nothing past the screen edge');
  assert.deepEqual(keys.barIntent('left', 'l'), { into: true });
  assert.deepEqual(keys.barIntent('top', 'l'), { move: 1 });
  assert.deepEqual(keys.barIntent('top', 'Down'), { into: true });
  assert.deepEqual(keys.barIntent('bottom', 'Up'), { into: true });
  assert.equal(keys.barIntent('top', 'Up'), null);
});

test('one meaning per key: no edge spends a key on two jobs', () => {
  for (const edge of ['top', 'bottom', 'left', 'right']) {
    const map = keys.keymap(edge);
    for (const k of map.into.concat(map.out)) assert.equal(map.along[k], undefined, `${edge} ${k}`);
  }
});

test('the other keys mean the same on every edge', () => {
  for (const edge of ['top', 'right']) {
    assert.deepEqual(keys.barIntent(edge, 'Tab'), { zone: 1 });
    assert.deepEqual(keys.barIntent(edge, 'Backtab'), { zone: -1 });
    assert.deepEqual(keys.barIntent(edge, 'Enter'), { open: true });
    assert.deepEqual(keys.barIntent(edge, 'Space'), { open: true });
    assert.deepEqual(keys.barIntent(edge, '/'), { find: true });
    assert.deepEqual(keys.barIntent(edge, '?'), { sheet: true });
    assert.deepEqual(keys.barIntent(edge, 'Escape'), { leave: true });
    assert.deepEqual(keys.barIntent(edge, 'Home'), { home: true });
  }
});

test('in a drawer on a side bar the along keys walk it and the out key leaves', () => {
  assert.deepEqual(keys.drawerIntent('right', 'Down', 0), { member: 1 });
  assert.deepEqual(keys.drawerIntent('right', 'Up', 2), { member: -1 });
  assert.deepEqual(keys.drawerIntent('right', 'Right', 2), { back: true });
  assert.equal(keys.drawerIntent('right', 'Left', 0), null);
});

test('in a drawer below a top bar the into key goes down and the out key comes back', () => {
  assert.deepEqual(keys.drawerIntent('top', 'Down', 0), { member: 1 });
  assert.deepEqual(keys.drawerIntent('top', 'Up', 2), { member: -1 });
  assert.deepEqual(keys.drawerIntent('top', 'Up', 0), { back: true }, 'from the first row, back to the icon');
  assert.deepEqual(keys.drawerIntent('top', 'Right', 1), { backMove: 1 });
  assert.deepEqual(keys.drawerIntent('bottom', 'Up', 0), { member: 1 });
  assert.deepEqual(keys.drawerIntent('top', 'Escape', 3), { back: true });
  assert.deepEqual(keys.drawerIntent('top', 'Tab', 3), { zone: 1 });
});

test('the cursor stops at the ends', () => {
  assert.equal(keys.step(5, 0, -1), -1);
  assert.equal(keys.step(5, 4, 1), -1);
  assert.equal(keys.step(5, 2, 1), 3);
});

test('Tab lands on the next zone nearest stop and wraps', () => {
  const zones = ['left', 'left', 'center', 'center', 'center', 'right', 'right'];
  assert.equal(keys.zoneStep(zones, 3, 1), 5, 'centre → first of right');
  assert.equal(keys.zoneStep(zones, 3, -1), 1, 'centre → last of left');
  assert.equal(keys.zoneStep(zones, 6, 1), 0, 'wraps to the first zone');
  assert.equal(keys.zoneStep(zones, 0, -1), 6, 'wraps back to the last zone');
  assert.equal(keys.zoneStep(['left', 'right'], 0, 1), 1, 'skips a zone with no stops');
  assert.equal(keys.zoneStep([], 0, 1), -1);
});

test('search ranks word starts first, then any match, then bar order', () => {
  const names = ['Audio', 'Bluetooth', 'Tailscale', 'Audio output', 'Scratchpad audio'];
  assert.deepEqual(keys.matches(names, 'au'), [0, 3, 4]);
  assert.deepEqual(keys.matches(names, 'ale'), [2], 'inside a word still matches');
  assert.deepEqual(keys.matches(names, 'sc'), [4, 2], 'a word start beats a match inside');
  assert.deepEqual(keys.matches(names, ''), []);
  assert.deepEqual(keys.matches(['Météo'], 'mé'), [0], 'any letters, not only ASCII');
});

test('the key strip names the keys of the edge', () => {
  const right = keys.legend('right', 'bar');
  assert.equal(right[0].keys, '↑ ↓');
  assert.equal(right[1].keys, '←');
  assert.equal(keys.legend('top', 'bar')[1].keys, '↓');
  assert.equal(keys.legend('top', 'bar', true)[1].label, 'Into a group or drawer');
  assert.equal(keys.legend('top', 'drawer')[0].keys, '↓ ↑');
  assert.equal(keys.legend('right', 'drawer')[2].keys, '→ Esc');
});
