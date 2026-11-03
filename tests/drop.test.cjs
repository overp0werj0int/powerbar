const { test } = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');
const drag = load('DragModel.js');

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

test('while a drag lasts the window takes the pointer over the whole strip and its slack: every release there lands on the bar', () => {
  const band = (position, w = win) => drag.stripBand(w, position, 38, 38 * 0.6);
  assert.deepEqual(band('top'), { x: 0, y: 0, width: 1512, height: 38 + 22.8 });
  assert.deepEqual(band('bottom'), { x: 0, y: 448 - 60.8, width: 1512, height: 60.8 });
  const side = { width: 448, height: 945 };
  assert.deepEqual(band('left', side), { x: 0, y: 0, width: 60.8, height: 945 });
  assert.deepEqual(band('right', side), { x: 448 - 60.8, y: 0, width: 60.8, height: 945 });
  for (const position of ['top', 'bottom', 'left', 'right']) {
    const w = position === 'left' || position === 'right' ? side : win, b = band(position, w);
    for (let cross = -2; cross <= 450; cross += 0.4) {
      const p = position === 'top' || position === 'bottom' ? { x: 100, y: cross } : { x: cross, y: 100 };
      const inBand = p.x >= b.x && p.x <= b.x + b.width && p.y >= b.y && p.y <= b.y + b.height;
      const s = drag.dropSurface(p, w, w, position, 38, 38, null, false);
      assert.equal(inBand, !!(s && s.inStrip), `${position} at ${cross}`);
    }
  }
});

const cell = (slot, x, extra = {}) => ({ slot, region: extra.region || 'left', groupHeader: !!extra.groupHeader, inDrawer: !!extra.inDrawer,
  x, y: 0, width: 30, height: 38, pivot: x + 15 });
const base = (over) => Object.assign({ candidates: [cell('a', 0), cell('b', 30), cell('c', 60)], probe: { x: 40, y: 10 }, point: { x: 40, y: 10 },
  sourceRect: null, handle: false, sourceInDrawer: false, sourceGroupHeader: false, alongColumn: false, previous: null, deadZone: 3,
  inDrawer: false, zone: 'left' }, over);

test('beside the widget under the dragged centre, on the side of its centre', () => {
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 40, y: 10 } })), { slot: 'b', after: false });
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 50, y: 10 } })), { slot: 'b', after: true });
  assert.deepEqual(drag.resolveDrop(base({ probe: { x: 500, y: 10 }, point: { x: 40, y: 10 } })), { slot: 'b', after: true }, 'the pointer when the centre is over nothing');
});

// One list of the bar: cells of `sizes` hung from the list's start
// (startGrowth 0), its end (1) or its middle (0.5), with a gap of `gap` before
// cell `at` (or none), the room the gap takes shared as the list grows.
function list(sizes, startGrowth, gap, at) {
  const total = sizes.reduce((a, b) => a + b, 0), room = at === null ? 0 : gap;
  let x = 1000 - startGrowth * (total + room);
  const cells = [], gaps = [];
  sizes.forEach((w, i) => {
    const lead = i === at ? room : 0;
    if (lead) gaps.push(x);
    cells.push({ slot: i, region: 'left', groupHeader: false, inDrawer: false, x, y: 0, width: lead + w, height: 38,
      pivot: drag.landingPivot(x + lead + w / 2, lead + (at !== null && at < i ? room : 0), room, startGrowth, gap) });
    x += lead + w;
  });
  if (at === sizes.length) gaps.push(x);
  return { cells, end: x, gapAt: gaps[0] };
}
const boundary = (r) => r.slot + (r.after ? 1 : 0);

test('the gap opens under the dragged widget whichever end its list hangs from, and holds there', () => {
  let seed = 11;
  const rnd = (n) => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n; };
  for (let n = 0; n < 4000; n++) {
    const sizes = Array.from({ length: 1 + rnd(6) }, () => 20 + rnd(90)), gap = 30 + rnd(30), startGrowth = [0, 0.5, 1][rnd(3)];
    const closed = list(sizes, startGrowth, gap, null);
    const probe = { x: closed.cells[0].x + rnd(Math.round(closed.end - closed.cells[0].x)), y: 10 };
    const first = drag.resolveDrop(base({ candidates: closed.cells, probe, point: probe }));
    // Of the two places beside the cell under it, the gap takes the nearer.
    const gapCentre = (at) => list(sizes, startGrowth, gap, at).gapAt + gap / 2;
    const near = Math.abs(gapCentre(boundary(first)) - probe.x), other = Math.abs(gapCentre(boundary({ slot: first.slot, after: !first.after })) - probe.x);
    assert.ok(near <= other + 1e-9, `${JSON.stringify({ sizes, gap, startGrowth, probe: probe.x, first })}`);
    // With the gap open the same probe keeps it, or (a cell shorter than the
    // gap past it) moves it once to a nearer place, never back and forth.
    let shown = first;
    const seen = [boundary(first)];
    for (let step = 0; step < 4; step++) {
      const next = drag.resolveDrop(base({ candidates: list(sizes, startGrowth, gap, boundary(shown)).cells, probe, point: probe, previous: shown }));
      if (next.slot === undefined || boundary(next) === boundary(shown)) break;
      assert.ok(!seen.includes(boundary(next)), `cycles: ${JSON.stringify({ sizes, gap, startGrowth, probe: probe.x, seen, next })}`);
      seen.push(boundary(next));
      shown = next;
    }
    assert.ok(seen.length <= 2, `${JSON.stringify({ sizes, gap, startGrowth, probe: probe.x, seen })}`);
  }
});

test('a list hanging from its end opens the gap on the cell the widget comes onto, not a cell before it', () => {
  // Weather (778..819) on a left bar's bottom list, the widget from a menu at 797.
  const right = list([41, 41], 1, 41, null);
  const weather = right.cells[0];
  assert.equal(weather.x, 1000 - 82);
  const probe = { x: weather.x + 15, y: 10 };
  const drop = drag.resolveDrop(base({ candidates: right.cells, probe, point: probe }));
  assert.deepEqual(drop, { slot: 0, after: true }, 'the cell moves on and the gap takes its place');
  assert.equal(list([41, 41], 1, 41, 1).gapAt, weather.x);
  assert.equal(drag.landingPivot(50, 0, 0, 0, 40), 70, 'from its start: before the cell anywhere on it');
  assert.equal(drag.landingPivot(50, 0, 0, 0.5, 40), 50, 'centred: its middle');
});

test('in the slack off the strip, the widget level with the dragged one along the bar takes it the same way', () => {
  const right = list([41, 41], 1, 41, null);
  const probe = { x: right.cells[0].x + 15, y: 50 };
  assert.deepEqual(drag.resolveDrop(base({ candidates: right.cells, probe, point: probe })), { slot: 0, after: true });
  assert.deepEqual(drag.resolveDrop(base({ candidates: right.cells, probe, point: probe, previous: { slot: 0, after: false } })), { slot: 0, after: true });
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
