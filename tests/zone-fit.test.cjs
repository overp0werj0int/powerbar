const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const cell = load('CellModel.js');
const zfc = load('ZoneFitModel.js');
const zf = { fit: i => JSON.parse(JSON.stringify(zfc.fit(i))) }; // plain objects: vm arrays differ in realm

// Inputs from real tokens. Ink widths <= 16 are glyphs.
function make(o) {
  const k = cell.tokens({ bar: o.bar || 26, mode: o.mode || 'slots', spacing: o.spacing || 0 });
  const mk = (prefix, inks) => inks.map((ink, i) => {
    const p = cell.place(k, ink, ink <= 16);
    return { key: `${prefix}${i}`, extent: p.extent, spill: p.spill };
  });
  const h = cell.place(k, 12.5, true);
  const z = o.zones;
  return {
    length: o.length, inset: o.inset === undefined ? 4 : o.inset,
    gap: k.cell + k.spacing, gutter: k.gutter,
    pad: s => cell.endPad(k, s),
    handle: { extent: h.extent, spill: h.spill },
    zones: {
      left: mk('L', z.left || [12]),
      right: mk('R', z.right || [12]),
      before: mk('B', z.before || []),
      anchor: z.anchor === null ? null : mk('A', [z.anchor === undefined ? 40 : z.anchor])[0],
      after: mk('F', z.after || []),
      center: mk('C', z.center || [])
    },
    previous: o.previous || null, transient: o.transient || null
  };
}
const withIn = (input, over) => Object.assign({}, input, over);

// Independent geometry: visible islands of each zone from a result.
function islands(input, r) {
  const hs = { left: 'handle:left', center: 'handle:center', right: 'handle:right' };
  const fold = new Set([].concat(r.folded.left, r.folded.center, r.folded.right));
  const yielded = new Set(r.yielded);
  const zl = n => input.zones[n];
  const centre = input.zones.anchor ? input.zones.before.concat([input.zones.anchor], input.zones.after) : input.zones.center;
  const items = { left: zl('left'), right: zl('right'), center: centre };
  const out = {};
  for (const n of ['left', 'center', 'right']) {
    let slots = items[n].filter(s => !fold.has(s.key));
    if (r.handles[n]) {
      const h = { key: hs[n], extent: input.handle.extent, spill: input.handle.spill };
      if (n === 'left') slots = slots.concat([h]);
      else if (n === 'right') slots = [h].concat(slots);
      else slots = r.handles.center === 'start' ? [h].concat(slots) : slots.concat([h]);
    }
    const len = slots.length ? input.pad(slots[0].spill) + slots.reduce((a, s) => a + s.extent, 0) + input.pad(slots[slots.length - 1].spill) : 0;
    const start = n === 'left' ? input.inset : n === 'right' ? input.length - input.inset - len : r.centerStart;
    let x = start + (slots.length ? input.pad(slots[0].spill) : 0);
    const vis = [];
    slots.forEach(s => { if (!yielded.has(s.key)) vis.push([x - 0, x + s.extent, s]); x += s.extent; });
    // A zone that yielded shows a marker cell next to its remaining slots, on the yielded side.
    const m = input.marker || input.handle;
    if (vis.length && yielded.has(slots[0].key)) vis.unshift([vis[0][0] - m.extent, vis[0][0], m]);
    if (vis.length && yielded.has(slots[slots.length - 1].key)) vis.push([vis[vis.length - 1][1], vis[vis.length - 1][1] + m.extent, m]);
    out[n] = vis.length ? [vis[0][0] - input.pad(vis[0][2].spill), vis[vis.length - 1][1] + input.pad(vis[vis.length - 1][2].spill)] : null;
  }
  return out;
}
function assertClear(input, r, tol = 1e-6) {
  const i = islands(input, r);
  const vis = ['left', 'center', 'right'].filter(n => i[n]);
  vis.forEach(n => {
    assert.ok(i[n][0] >= input.inset - tol, `${n} starts in screen`);
    assert.ok(i[n][1] <= input.length - input.inset + tol, `${n} ends in screen`);
  });
  for (let a = 0; a + 1 < vis.length; a++) {
    const gap = i[vis[a + 1]][0] - i[vis[a]][1];
    assert.ok(gap >= input.gap - tol, `${vis[a]}-${vis[a + 1]} gap ${gap} >= ${input.gap}`);
  }
}
const lens = (input, r) => { const i = islands(input, r); return { L: i.left ? i.left[1] - i.left[0] : 0, C: i.center ? i.center[1] - i.center[0] : 0, R: i.right ? i.right[1] - i.right[0] : 0 }; };
const allFolded = r => [].concat(r.folded.left, r.folded.center, r.folded.right);

test('everything fits on a long bar: nothing folds, anchor exactly centred', () => {
  const input = make({ length: 1920, zones: { left: [12, 40, 12], right: [12, 12, 30], before: [12, 12], anchor: 60, after: [12] } });
  const r = zf.fit(input);
  assert.equal(r.fits, true);
  assert.deepEqual(allFolded(r), []);
  assert.equal(r.centerShift, 0);
  assert.equal(r.fallback, null);
  assert.deepEqual(r.yielded, []);
  assertClear(input, r);
});

test('a long left zone slides the centre by exactly what it needs', () => {
  const input = make({ length: 900, zones: { left: [12, 100, 120, 120, 100, 60], right: [12], before: [12, 12], anchor: 60, after: [12, 12] } });
  const r = zf.fit(input);
  assert.equal(r.fits, true);
  assert.deepEqual(allFolded(r), []);
  const l = lens(input, r);
  const lo = input.inset + l.L + input.gap;
  assert.equal(r.centerStart, lo);
  assert.ok(r.centerShift > 0);
  assert.ok(Math.abs(islands(input, r).center[0] - (input.inset + l.L) - input.gap) < 1e-9);
});

test('too short: folds happen and the result is clear of overlap', () => {
  const input = make({ length: 560, zones: { left: [12, 80, 80, 12, 12], right: [12, 60, 60, 12], before: [12, 60, 12], anchor: 60, after: [12, 12, 60] } });
  const r = zf.fit(input);
  assert.ok(allFolded(r).length > 0);
  assert.equal(r.fits, true);
  assertClear(input, r);
});

test('anchors never fold, even when nothing fits', () => {
  const input = make({ length: 200, zones: { left: [12, 80, 12], right: [12, 60, 12], before: [12, 60], anchor: 60, after: [12] } });
  const r = zf.fit(input);
  assert.equal(r.fits, false);
  const f = allFolded(r);
  assert.ok(!f.includes('L0'));
  assert.ok(!f.includes('R2'));
  assert.ok(!f.includes('A0'));
  assert.ok(f.length > 0);
});

test('fold order: longest zone first, from the far end', () => {
  // left is the longest zone.
  let input = make({ length: 600, zones: { left: [100, 100, 100, 100], right: [12, 12], before: [12], anchor: 20, after: [12] } });
  let r = zf.fit(input);
  assert.deepEqual(r.order.slice(0, 1), ['L3']);
  // right is the longest.
  input = make({ length: 600, zones: { left: [12, 12], right: [100, 100, 100, 100, 12], before: [12], anchor: 20, after: [12] } });
  r = zf.fit(input);
  assert.deepEqual(r.order.slice(0, 1), ['R0']);
  // centre is the longest, before at least as long as after.
  input = make({ length: 600, zones: { left: [12, 12], right: [12, 12], before: [100, 100, 100], anchor: 100, after: [100, 100] } });
  r = zf.fit(input);
  assert.deepEqual(r.order.slice(0, 1), ['B0']);
  assert.equal(r.handles.center, 'start');
  // more after than before: folds from the end of after.
  input = make({ length: 600, zones: { left: [12, 12], right: [12, 12], before: [100], anchor: 100, after: [100, 100, 100] } });
  r = zf.fit(input);
  assert.deepEqual(r.order.slice(0, 1), ['F2']);
  assert.equal(r.handles.center, 'end');
});

test('hysteresis: small growth does not unfold, large growth does, no flicker at the threshold', () => {
  const zones = { left: [12, 60, 60, 12], right: [12, 60, 12], before: [12, 40], anchor: 60, after: [12, 12] };
  // Find the longest length at which something still folds.
  let tight = null;
  for (let L = 300; L < 1500; L++) {
    const r = zf.fit(make({ length: L, zones }));
    if (allFolded(r).length === 0) { tight = L; break; }
  }
  assert.ok(tight > 300);
  const input = make({ length: tight - 1, zones });
  const prev = zf.fit(input);
  assert.ok(allFolded(prev).length > 0);
  const small = zf.fit(make({ length: tight - 1 + 1, zones, previous: prev }));
  assert.deepEqual(small.folded, prev.folded);
  const grown = zf.fit(make({ length: tight + 400, zones, previous: prev }));
  assert.equal(allFolded(grown).length, 0);
  // Alternate an extent by +-1 around the threshold.
  const base = make({ length: tight, zones });
  let previous = prev, changes = 0, last = JSON.stringify(prev.folded);
  for (let n = 0; n < 20; n++) {
    const inp = withIn(base, { previous });
    inp.zones = Object.assign({}, base.zones, { anchor: Object.assign({}, base.zones.anchor, { extent: base.zones.anchor.extent + (n % 2 ? 1 : -1) }) });
    previous = zf.fit(inp);
    const now = JSON.stringify(previous.folded);
    if (now !== last) changes++;
    last = now;
  }
  assert.ok(changes <= 1, `changes ${changes}`);
});

test('moment, centre focus: the left zone yields from its end, nothing slides', () => {
  const zones = { left: [12, 40, 40, 12, 12], right: [12], before: [12], anchor: 60, after: [12] };
  const base = make({ length: 700, zones });
  const prev = zf.fit(base);
  assert.deepEqual(allFolded(prev), []);
  const grown = make({ length: 700, zones: Object.assign({}, zones, { before: [12, 300] }), previous: null });
  // Keep keys stable: the grown input reuses before keys B0, B1 (B1 is new).
  const input = withIn(grown, { previous: prev, transient: { zone: 'center', sourceKey: null } });
  const r = zf.fit(input);
  assert.equal(r.fallback, null);
  assert.equal(r.centerShift, prev.centerShift);
  assert.ok(r.yielded.length > 0);
  assert.ok(r.yielded.includes('L4'));
  assert.ok(!r.yielded.includes('L0'));
  assertClear(input, r);
});

test('moment, left focus: the centre yields from its start and its other widgets stay put', () => {
  const zones = { left: [12, 40], right: [12], before: [12, 12, 12, 12], anchor: 60, after: [12] };
  const base = make({ length: 600, zones });
  const prev = zf.fit(base);
  assert.deepEqual(allFolded(prev), []);
  const grown = make({ length: 600, zones: Object.assign({}, zones, { left: [12, 40, 110] }) });
  const input = withIn(grown, { previous: prev, transient: { zone: 'left', sourceKey: null } });
  const r = zf.fit(input);
  assert.equal(r.fallback, null);
  assert.equal(r.centerStart, prev.centerStart);
  assert.ok(r.yielded.length >= 2, 'needs at least two yields: ' + r.yielded);
  assert.deepEqual(r.yielded, ['B0', 'B1', 'B2', 'B3'].slice(0, r.yielded.length));
  assertClear(input, r);
});

test('moment fallbacks: folded, screen, anchor', () => {
  const zones = { left: [12, 40, 40, 12, 12], right: [12], before: [12], anchor: 60, after: [12] };
  // folded
  const tight = make({ length: 330, zones });
  const prevF = zf.fit(tight);
  assert.ok(allFolded(prevF).length > 0);
  const key = allFolded(prevF)[0];
  let r = zf.fit(withIn(tight, { previous: prevF, transient: { zone: 'left', sourceKey: key } }));
  assert.deepEqual(r.fallback, { zone: 'left', reason: 'folded' });
  assert.deepEqual(r.yielded, []);
  // screen
  const base = make({ length: 700, zones });
  const prev = zf.fit(base);
  const huge = make({ length: 700, zones: Object.assign({}, zones, { before: [12, 160, 160, 160, 160, 160, 160, 160] }) });
  r = zf.fit(withIn(huge, { previous: prev, transient: { zone: 'center', sourceKey: 'B1' } }));
  assert.deepEqual(r.fallback, { zone: 'center', reason: 'screen' });
  assert.deepEqual(r.yielded, []);
  // anchor: growth that would make left[0] yield but still fits the screen
  const wide = make({ length: 700, zones: Object.assign({}, zones, { before: [12, 160, 100] }) });
  r = zf.fit(withIn(wide, { previous: prev, transient: { zone: 'center', sourceKey: 'B1' } }));
  assert.deepEqual(r.fallback, { zone: 'center', reason: 'anchor' });
  assert.deepEqual(r.yielded, []);
});

function mulberry32(a) {
  return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
}

test('fuzz: 2000 random configurations', () => {
  const rnd = mulberry32(0xC0FFEE);
  const int = (a, b) => a + Math.floor(rnd() * (b - a + 1));
  const pick = a => a[int(0, a.length - 1)];
  const inks = n => Array.from({ length: n }, () => int(6, 120));
  let fitted = 0;
  for (let n = 0; n < 2000; n++) {
    const hasAnchor = rnd() < 0.7;
    const input = make({
      length: int(300, 2500), inset: pick([0, 4]), bar: pick([26, 38]), spacing: pick([0, 4, 8]), mode: pick(['slots', 'gaps']),
      zones: {
        left: inks(int(1, 8)), right: inks(int(1, 8)),
        before: hasAnchor ? inks(int(0, 6)) : [], after: hasAnchor ? inks(int(0, 6)) : [],
        anchor: hasAnchor ? int(6, 120) : null, center: hasAnchor ? [] : inks(int(0, 8))
      }
    });
    const r = zf.fit(input);
    const f = allFolded(r);
    assert.ok(!f.includes('L0'), `case ${n}`);
    assert.ok(!f.includes(`R${input.zones.right.length - 1}`), `case ${n}`);
    if (hasAnchor) assert.ok(!f.includes('A0'), `case ${n}`);
    if (r.fits) { fitted++; assertClear(input, r); }
  }
  assert.ok(fitted > 1000);
});

test('a moment keeps the smaller moment gap, so fewer widgets yield', () => {
  const zones = { left: [12, 40, 40, 12, 12], right: [12], before: [12], anchor: 60, after: [12] };
  const prev = zf.fit(make({ length: 700, zones }));
  const grown = make({ length: 700, zones: Object.assign({}, zones, { before: [12, 300] }) });
  const wide = zf.fit(withIn(grown, { previous: prev, transient: { zone: 'center', sourceKey: null } }));
  const narrow = zf.fit(withIn(grown, { previous: prev, momentGap: 4, transient: { zone: 'center', sourceKey: null } }));
  assert.equal(narrow.fallback, null);
  assert.ok(narrow.yielded.length < wide.yielded.length, `${narrow.yielded} vs ${wide.yielded}`);
  assertClear(withIn(grown, { gap: 4 }), narrow);
});
test('a yielding zone keeps room for its marker cell', () => {
  const zones = { left: [12, 12, 12, 12, 12, 12], right: [12], before: [12], anchor: 60, after: [12] };
  const prev = zf.fit(make({ length: 600, zones }));
  const grown = make({ length: 600, zones: Object.assign({}, zones, { before: [12, 120] }) });
  const r = zf.fit(withIn(grown, { previous: prev, momentGap: 4, transient: { zone: 'center', sourceKey: null } }));
  assert.equal(r.fallback, null);
  assert.ok(r.yielded.length > 0);
  assertClear(withIn(grown, { gap: 4 }), r);
});

test('inline mode: a zone with hidden widgets keeps its handle without folding', () => {
  const zones = { left: [12, 40], right: [12, 30], before: [12], anchor: 60, after: [12] };
  const input = withIn(make({ length: 1200, zones }), { dots: { left: true, center: true, right: true } });
  const r = zf.fit(input);
  assert.deepEqual(allFolded(r), []);
  assert.deepEqual(r.handles, { left: 'end', center: 'end', right: 'start' });
  assertClear(input, r);
  // The handle counts towards the lasting length: a bar that just fits without it folds with it.
  let L = 200;
  while (allFolded(zf.fit(make({ length: L, zones }))).length) L++;
  const tight = zf.fit(withIn(make({ length: L, zones }), { dots: { left: true, center: false, right: false } }));
  assert.ok(allFolded(tight).length > 0 || tight.centerShift !== zf.fit(make({ length: L, zones })).centerShift);
});

test('inline mode: a zone with only hidden widgets is just its handle', () => {
  const input = withIn(make({ length: 800, zones: { left: [12], right: [12], before: [], anchor: 60, after: [] } }), { dots: { left: false, center: false, right: false } });
  input.zones.right = [];
  input.dots.right = true;
  const r = zf.fit(input);
  assert.equal(r.handles.right, 'start');
  assert.ok(islands(input, r).right, 'the handle draws an island');
  assertClear(input, r);
});

test('inline expansion unfolds its zone for the moment and drops its handle', () => {
  const zones = { left: [12, 40, 40, 12, 12], right: [12], before: [12], anchor: 60, after: [12] };
  const tight = make({ length: 330, zones });
  const prev = zf.fit(withIn(tight, { dots: { left: true } }));
  assert.ok(prev.folded.left.length > 0);
  assert.equal(prev.handles.left, 'end');
  // Expanded: the hidden widget X0 shows, the dots are gone, folded widgets come back.
  const grown = make({ length: 330, zones: Object.assign({}, zones, { left: zones.left.concat([12]) }) });
  grown.zones.left[grown.zones.left.length - 1].key = 'X0';
  const input = withIn(grown, { previous: prev, momentGap: 4, dots: { left: false }, transient: { zone: 'left', sourceKey: null, unfold: 'left' } });
  const r = zf.fit(input);
  if (r.fallback) assert.equal(r.fallback.reason, 'anchor');
  else {
    assert.deepEqual(r.folded.left, []);
    assert.equal(r.handles.left, null);
    assert.equal(r.centerShift, prev.centerShift);
    assertClear(withIn(input, { gap: 4 }), r);
  }
  // On a roomy bar it never falls back, and the folds elsewhere stay.
  const roomyPrev = zf.fit(withIn(make({ length: 520, zones }), { dots: { left: true } }));
  const roomy = withIn(make({ length: 520, zones: Object.assign({}, zones, { left: zones.left.concat([12]) }) }),
    { previous: roomyPrev, momentGap: 4, dots: { left: false }, transient: { zone: 'left', sourceKey: null, unfold: 'left' } });
  const rr = zf.fit(roomy);
  assert.equal(rr.fallback, null);
  assert.deepEqual(rr.folded.left, []);
  assertClear(withIn(roomy, { gap: 4 }), rr);
});

test('with no centre, a side moment makes the other side yield', () => {
  const zones = { left: [12, 12], right: [12, 12, 12, 12, 12, 12], before: [], anchor: null, after: [], center: [] };
  const prev = zf.fit(make({ length: 400, zones }));
  assert.deepEqual(allFolded(prev), []);
  const grown = make({ length: 400, zones: Object.assign({}, zones, { left: [12, 12, 120, 120] }) });
  const input = withIn(grown, { previous: prev, momentGap: 4, transient: { zone: 'left', sourceKey: null } });
  const r = zf.fit(input);
  assert.equal(r.fallback, null);
  assert.ok(r.yielded.length > 0 && r.yielded.every(k => k[0] === 'R'), String(r.yielded));
  assert.ok(!r.yielded.includes('R5'));
  assertClear(withIn(input, { gap: 4 }), r);
  // And the mirror.
  const grownR = make({ length: 400, zones: { left: [12, 12, 12, 12, 12, 12], right: [120, 120, 12, 12], before: [], anchor: null, after: [], center: [] } });
  const prevR = zf.fit(make({ length: 400, zones: { left: [12, 12, 12, 12, 12, 12], right: [12, 12], before: [], anchor: null, after: [], center: [] } }));
  const rr = zf.fit(withIn(grownR, { previous: prevR, momentGap: 4, transient: { zone: 'right', sourceKey: null } }));
  assert.equal(rr.fallback, null);
  assert.ok(rr.yielded.length > 0 && rr.yielded.every(k => k[0] === 'L') && !rr.yielded.includes('L0'), String(rr.yielded));
  assertClear(withIn(grownR, { gap: 4 }), rr);
});

test('fuzz: 2000 inline expansions stay clear or fall back', () => {
  const rnd = mulberry32(0xD07);
  const int = (a, b) => a + Math.floor(rnd() * (b - a + 1));
  const pick = a => a[int(0, a.length - 1)];
  const inks = n => Array.from({ length: n }, () => int(6, 120));
  let expanded = 0;
  for (let n = 0; n < 2000; n++) {
    const hasAnchor = rnd() < 0.7;
    const o = {
      length: int(300, 2500), inset: pick([0, 4]), bar: pick([26, 38]), spacing: pick([0, 4, 8]), mode: pick(['slots', 'gaps']),
      zones: {
        left: inks(int(1, 6)), right: inks(int(1, 6)),
        before: hasAnchor ? inks(int(0, 4)) : [], after: hasAnchor ? inks(int(0, 4)) : [],
        anchor: hasAnchor ? int(6, 120) : null, center: hasAnchor ? [] : inks(int(0, 6))
      }
    };
    const zone = pick(['left', 'center', 'right']);
    const dots = { left: rnd() < 0.5, center: rnd() < 0.5, right: rnd() < 0.5 };
    dots[zone] = true;
    const prev = zf.fit(withIn(make(o), { dots }));
    if (!prev.fits) continue;
    // The hidden widgets join the zone at its handle's end.
    const extra = inks(int(1, 4));
    const zo = Object.assign({}, o.zones);
    const list = zone === 'center' ? (hasAnchor ? 'after' : 'center') : zone;
    zo[list] = zone === 'right' ? extra.concat(zo[list]) : zo[list].concat(extra);
    const input = withIn(make(Object.assign({}, o, { zones: zo })), {
      previous: prev, momentGap: 4, dots: Object.assign({}, dots, { [zone]: false }),
      transient: { zone, sourceKey: null, unfold: zone }
    });
    // Keep the old keys: rename the new widgets.
    const grownList = input.zones[list];
    const at = zone === 'right' ? 0 : grownList.length - extra.length;
    for (let k = 0; k < extra.length; k++) grownList[at + k] = Object.assign({}, grownList[at + k], { key: 'X' + k });
    const base = make(o);
    if (zone === 'right') for (let k = extra.length; k < grownList.length; k++) grownList[k].key = base.zones[list][k - extra.length].key;
    const r = zf.fit(input);
    if (r.fallback) continue;
    expanded++;
    assert.deepEqual(r.folded[zone], [], `case ${n}`);
    assert.equal(r.handles[zone], null, `case ${n}`);
    assert.ok(!r.yielded.includes('L0') && !r.yielded.includes('A0') && !r.yielded.includes(`R${o.zones.right.length - 1}`), `case ${n}`);
    assertClear(withIn(input, { gap: 4 }), r);
  }
  assert.ok(expanded > 500, `expanded ${expanded}`);
});

test('fuzz: 2000 lasting fits with handles reserved for hidden widgets', () => {
  const rnd = mulberry32(0xB0B);
  const int = (a, b) => a + Math.floor(rnd() * (b - a + 1));
  const pick = a => a[int(0, a.length - 1)];
  const inks = n => Array.from({ length: n }, () => int(6, 120));
  let fitted = 0;
  for (let n = 0; n < 2000; n++) {
    const hasAnchor = rnd() < 0.7;
    const input = withIn(make({
      length: int(300, 2500), inset: pick([0, 4]), bar: pick([26, 38]), spacing: pick([0, 4, 8]), mode: pick(['slots', 'gaps']),
      zones: {
        left: inks(int(1, 8)), right: inks(int(1, 8)),
        before: hasAnchor ? inks(int(0, 6)) : [], after: hasAnchor ? inks(int(0, 6)) : [],
        anchor: hasAnchor ? int(6, 120) : null, center: hasAnchor ? [] : inks(int(0, 8))
      }
    }), { dots: { left: rnd() < 0.5, center: rnd() < 0.5, right: rnd() < 0.5 } });
    const r = zf.fit(input);
    for (const z of ['left', 'center', 'right']) if (input.dots[z]) assert.ok(r.handles[z], `case ${n} ${z}`);
    if (r.fits) { fitted++; assertClear(input, r); }
  }
  assert.ok(fitted > 1000);
});

test('the centre handle sits on the side its hidden widgets grow', () => {
  const zones = { left: [12], right: [12], before: [12], anchor: 60, after: [12] };
  const start = zf.fit(withIn(make({ length: 1200, zones }), { dots: { center: 'start' } }));
  assert.equal(start.handles.center, 'start');
  const end = zf.fit(withIn(make({ length: 1200, zones }), { dots: { center: 'end' } }));
  assert.equal(end.handles.center, 'end');
  // The anchor stays centred either way: the handle shifts the zone, not the anchor.
  assert.equal(start.centerShift, 0);
  assert.equal(end.centerShift, 0);
});

const moment = (zones, length, over) => {
  const prev = zf.fit(make({ length, zones }));
  return { prev, run: (grown, transient, extra) => {
    const input = withIn(make({ length, zones: Object.assign({}, zones, grown) }), Object.assign({ previous: prev, momentGap: 4, transient }, extra || {}));
    return { input, r: zf.fit(input) };
  } };
};

test('two moments at once: each neighbour yields to every growing zone', () => {
  // The centre grows (indicators) and the right zone expands inline: the left
  // zone yields to the centre, and the centre's free end yields to the right.
  const zones = { left: [12, 12, 12, 12, 12, 12, 12], right: [12, 12], before: [12, 12], anchor: 60, after: [12, 12, 12, 12] };
  const m = moment(zones, 520);
  const { input, r } = m.run({ before: [12, 12, 90], right: [40, 40, 12, 12] }, [
    { zone: 'center', sourceKey: 'B2' }, { zone: 'right', sourceKey: null, unfold: 'right' }]);
  assert.deepEqual(r.fallbacks, []);
  assert.ok(r.yielded.some(k => k[0] === 'L'), 'left yields: ' + r.yielded);
  assert.ok(r.yielded.some(k => k[0] === 'F'), 'centre end yields: ' + r.yielded);
  assert.ok(!r.yielded.includes('B2') && !r.yielded.includes('A0'), 'the growing widget and the anchor stay');
  assertClear(withIn(input, { gap: 4 }), r);
});

test('colliding moments: the lower priority one falls back', () => {
  const zones = { left: [12, 12], right: [12, 12], before: [12], anchor: 60, after: [12] };
  const m = moment(zones, 520);
  // Both centre and right grow into each other; the inline right expansion is listed last.
  const { r } = m.run({ after: [12, 120], right: [160, 160, 12, 12] }, [
    { zone: 'center', sourceKey: 'F1' }, { zone: 'right', sourceKey: null, unfold: 'right' }]);
  // The inline expansion falls back first (its growth is still in this input,
  // so the centre can't clear it yet; the bar withdraws it and fits again).
  assert.deepEqual(r.fallback, { zone: 'right', reason: 'neighbour' });
  // Without the inline growth the centre's moment is served cleanly.
  const again = m.run({ after: [12, 120] }, [{ zone: 'center', sourceKey: 'F1' }]);
  assert.deepEqual(again.r.fallbacks, []);
  assertClear(withIn(again.input, { gap: 4 }), again.r);
});

test('the centre yields at both ends without double counting', () => {
  const zones = { left: [12, 12], right: [12, 12], before: [12, 12, 12], anchor: 60, after: [12, 12, 12] };
  const m = moment(zones, 460);
  const { input, r } = m.run({ left: [12, 12, 100], right: [100, 12, 12] }, [
    { zone: 'left', sourceKey: null }, { zone: 'right', sourceKey: null }]);
  assert.deepEqual(r.fallbacks, []);
  assert.ok(r.yielded.includes('B0') && r.yielded.includes('F2'), String(r.yielded));
  assert.ok(!r.yielded.includes('A0'));
  assertClear(withIn(input, { gap: 4 }), r);
});

test('fuzz: 3000 concurrent moments never overlap once fallbacks are withdrawn', () => {
  const rnd = mulberry32(0xFACE);
  const int = (a, b) => a + Math.floor(rnd() * (b - a + 1));
  const pick = a => a[int(0, a.length - 1)];
  const inks = n => Array.from({ length: n }, () => int(6, 90));
  let served = 0;
  for (let n = 0; n < 3000; n++) {
    const hasAnchor = rnd() < 0.7;
    const o = {
      length: int(300, 2000), inset: pick([0, 4]), bar: pick([26, 38]), spacing: pick([0, 4]), mode: pick(['slots', 'gaps']),
      zones: {
        left: inks(int(1, 6)), right: inks(int(1, 6)),
        before: hasAnchor ? inks(int(0, 4)) : [], after: hasAnchor ? inks(int(0, 4)) : [],
        anchor: hasAnchor ? int(6, 90) : null, center: hasAnchor ? [] : inks(int(0, 5))
      }
    };
    const prev = zf.fit(make(o));
    if (!prev.fits) continue;
    // Up to three zones grow at once, each by appending widgets on its free side.
    let ts = ['left', 'center', 'right'].filter(() => rnd() < 0.5).map(zone => ({ zone, sourceKey: null }));
    if (!ts.length) continue;
    const grow = {};
    ts.forEach(t => { grow[t.zone] = inks(int(1, 3)); });
    const build = active => {
      const zo = JSON.parse(JSON.stringify(o.zones));
      const extra = {};
      active.forEach(t => {
        const list = t.zone === 'center' ? (hasAnchor ? 'after' : 'center') : t.zone;
        zo[list] = t.zone === 'right' ? grow[t.zone].concat(zo[list]) : zo[list].concat(grow[t.zone]);
        extra[list] = { at: t.zone === 'right' ? 0 : zo[list].length - grow[t.zone].length, n: grow[t.zone].length, zone: t.zone };
      });
      const input = withIn(make(Object.assign({}, o, { zones: zo })), { previous: prev, momentGap: 4, transient: active });
      // New widgets get new keys; old ones keep theirs.
      const base = make(o).zones;
      for (const list in extra) {
        const e = extra[list];
        input.zones[list] = input.zones[list].map((it, k) => k >= e.at && k < e.at + e.n
          ? Object.assign({}, it, { key: 'X' + e.zone + (k - e.at) })
          : Object.assign({}, it, { key: base[list][k < e.at ? k : k - e.n].key }));
      }
      return input;
    };
    let input = build(ts), r = zf.fit(input);
    // The bar withdraws what fell back (an inline expansion collapses), then fits again.
    for (let guard = 0; r.fallbacks.length && guard < 3; guard++) {
      const out = new Set(r.fallbacks.map(f => f.zone));
      ts = ts.filter(t => !out.has(t.zone));
      input = build(ts);
      r = zf.fit(input);
    }
    if (r.fallbacks.length || !ts.length) continue;
    served++;
    assert.ok(!r.yielded.includes('L0') && !r.yielded.includes('A0') && !r.yielded.includes(`R${o.zones.right.length - 1}`), `case ${n}`);
    assertClear(withIn(input, { gap: 4 }), r);
  }
  assert.ok(served > 800, `served ${served}`);
});
