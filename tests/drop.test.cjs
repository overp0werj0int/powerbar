const { test } = require('node:test');
const assert = require('node:assert/strict');
const drag = require('../DragModel.js');

const size = { width: 1512, height: 448 }, win = { width: 1512, height: 448 };
const surface = (p, extra = {}) => drag.dropSurface(p, size, win, extra.position || 'top', 38, 38, extra.drawer || null, !!extra.nested);

test('the strip takes drops with slack off its inner edge, and nothing past it', () => {
  assert.deepEqual(surface({ x: 100, y: 10 }), { inStrip: true, inDrawer: false });
  assert.deepEqual(surface({ x: 100, y: 38 + 22 }), { inStrip: true, inDrawer: false }, 'within 0.6 bar of the inner edge');
  assert.equal(surface({ x: 100, y: 38 + 23 }), null, 'past the slack');
  assert.equal(surface({ x: -1, y: 10 }), null, 'outside the window');
});

test('a bottom or right bar measures its strip from the far edge', () => {
  assert.deepEqual(surface({ x: 100, y: 448 - 10 }, { position: 'bottom' }), { inStrip: true, inDrawer: false });
  assert.equal(surface({ x: 100, y: 10 }, { position: 'bottom' }), null);
  assert.deepEqual(surface({ x: 1512 - 5, y: 200 }, { position: 'right' }), { inStrip: true, inDrawer: false });
});

test('an open drawer is its own surface, and no slack reaches past the strip into it', () => {
  const drawer = { open: true, x: 50, y: 40, width: 200, height: 120 };
  assert.deepEqual(surface({ x: 100, y: 50 }, { drawer }), { inStrip: false, inDrawer: true });
  assert.deepEqual(surface({ x: 100, y: 39 }, { drawer: { ...drawer, y: 30 } }), { inStrip: false, inDrawer: true }, 'over the drawer the strip has no slack');
  assert.equal(surface({ x: 100, y: 80 }, { drawer: { ...drawer, open: false } }), null, 'a closed drawer is no surface');
  assert.deepEqual(surface({ x: 100, y: 50 }, { drawer: { ...drawer, open: false } }), { inStrip: true, inDrawer: false }, 'and the slack applies again');
  assert.equal(surface({ x: 100, y: 80 }, { drawer, nested: true }), null, 'groups do not nest');
});

const cell = (slot, x, extra = {}) => ({ slot, region: extra.region || 'left', groupHeader: !!extra.groupHeader, inDrawer: !!extra.inDrawer,
  x, y: 0, width: 30, height: 38, contentX: 0, contentY: 0, contentWidth: 30, contentHeight: 38 });
const base = (over) => Object.assign({ candidates: [cell('a', 0), cell('b', 30), cell('c', 60)], probe: { x: 40, y: 10 }, point: { x: 40, y: 10 },
  sourceRect: null, handle: false, sourceInDrawer: false, sourceGroupHeader: false, alongColumn: false, previous: null, deadZone: 3,
  inDrawer: false, zone: 'left' }, over);

test('beside the widget under the dragged centre, on the side of its centre', () => {
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 40, y: 10 } })), { slot: 'b', after: false });
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 50, y: 10 } })), { slot: 'b', after: true });
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 500, y: 10 }, point: { x: 40, y: 10 } })), { slot: 'b', after: true }, 'the pointer when the centre is over nothing');
});

test('a dead zone around the centre keeps the side shown', () => {
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 46, y: 10 }, previous: { slot: 'b', after: false } })), { slot: 'b', after: false });
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 44, y: 10 }, previous: { slot: 'b', after: true } })), { slot: 'b', after: true });
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 46, y: 10 }, previous: { slot: 'a', after: false } })), { slot: 'b', after: true }, 'only for the same widget');
});

test('own place, the dots, a group from a drawer, then the nearest, then the zone', () => {
  const empty = { probe: { x: 500, y: 10 }, point: { x: 500, y: 10 } };
  assert.deepEqual(drag.resolveDrop(base({ ...empty, sourceRect: { x: 490, y: 0, width: 30, height: 38 } })), { source: true });
  assert.deepEqual(drag.resolveDrop(base({ handle: true })), { handle: true });
  assert.deepEqual(drag.resolveDrop(base({ candidates: [cell('g', 30, { groupHeader: true })], sourceInDrawer: true })), { slot: 'g', into: true });
  assert.deepEqual(drag.resolveDrop(base({ candidates: [cell('g', 30, { groupHeader: true })], sourceInDrawer: true, sourceGroupHeader: true })), { slot: 'g', after: false });
  assert.deepEqual(drag.resolveDrop(base(empty)), { slot: 'c', after: true }, 'nearest edge in the zone');
  assert.deepEqual(drag.resolveDrop(base({ ...empty, zone: 'right' })), { zone: 'right' });
  assert.deepEqual(drag.resolveDrop(base({ ...empty, candidates: [], inDrawer: true })), { drawer: true });
});

test('fuzz: resolveDrop agrees with a plain reading of the rules', () => {
  let seed = 7;
  const rnd = (n) => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n; };
  for (let n = 0; n < 5000; n++) {
    const cands = [];
    let x = 0;
    for (let i = 0; i < 1 + rnd(6); i++) { x += rnd(20); cands.push(cell('s' + i, x, { region: ['left', 'center'][rnd(2)], groupHeader: rnd(5) === 0, inDrawer: rnd(4) === 0 })); x += 30; }
    const d = base({ candidates: cands, probe: { x: rnd(x + 40) - 20, y: rnd(60) - 10 }, point: { x: rnd(x + 40) - 20, y: rnd(60) - 10 },
      sourceRect: rnd(3) ? null : { x: rnd(x), y: 0, width: 30, height: 38 }, handle: rnd(8) === 0, sourceInDrawer: rnd(2) === 0,
      previous: rnd(2) ? { slot: 's' + rnd(6), after: rnd(2) === 0 } : null, inDrawer: rnd(4) === 0, zone: ['left', 'center', 'right'][rnd(3)] });
    const r = drag.resolveDrop(d);
    const inside = (p, c) => p.x >= c.x && p.x <= c.x + c.width && p.y >= c.y && p.y <= c.y + c.height;
    const hit = cands.find((c) => inside(d.probe, c)) || cands.find((c) => inside(d.point, c));
    if (!hit && d.sourceRect && inside(d.point, d.sourceRect)) { assert.deepEqual(r, { source: true }); continue; }
    if (d.handle) { assert.deepEqual(r, { handle: true }); continue; }
    if (hit) { assert.equal(r.slot, hit.slot); continue; }
    const pool = d.inDrawer ? cands : cands.filter((c) => c.region === d.zone);
    if (pool.length) assert.ok(pool.some((c) => c.slot === r.slot), 'the nearest is one of the zone\'s');
    else assert.deepEqual(r, d.inDrawer ? { drawer: true } : { zone: d.zone });
  }
});
