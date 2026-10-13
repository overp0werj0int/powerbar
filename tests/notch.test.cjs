const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const J = v => JSON.parse(JSON.stringify(v));
const notch = load('NotchModel.js');
const cell = load('CellModel.js');
const zfc = load('ZoneFitModel.js');
const fit = i => J(zfc.fit(i));

const omarchyFile = JSON.stringify({ panels: [
  { connector: 'eDP', width: 3024, height: 1964, top: 64 },
  { connector: 'eDP', width: 2560, height: 1664, top: 56 },
  { connector: '', width: 1, height: 1, top: 1 },
  { connector: 'eDP', width: 3024, height: 1964, top: 2000 }
] });
const cutouts = notch.parseCutouts(omarchyFile);
const mbp14 = { width: 3024, height: 1964, transform: 0 };

const panels = notch.parsePanels(fs.readFileSync(`${__dirname}/../notch-panels.json`, 'utf8'));

test("notch-panels.json gives each of Omarchy's notched panels a width", () => {
  const omarchy = [[3024, 1964], [3456, 2234], [2560, 1664], [2880, 1864]];
  for (const [w, h] of omarchy) assert.ok(panels.some(p => p.width === w && p.height === h), `${w}x${h}`);
  assert.deepEqual(J(notch.parsePanels('{"panels":[{"width":10,"height":10,"notchWidth":20},{}]}')), []);
  assert.deepEqual(J(notch.parsePanels('nope')), []);
  assert.deepEqual(J(notch.parsePanels('{"panels":[{"width":100,"height":50,"notchWidth":60},{"width":100,"height":50,"notchWidth":60,"radius":25,"shoulder":5}]}')),
    [{ width: 100, height: 50, notchWidth: 60, radius: 16, shoulder: 8 }], 'no shape: the default; corners wider than the housing: dropped');
});

test("the housing's corners fit the width they are drawn at", () => {
  const n = { width: 185, height: 32, radius: 8, shoulder: 4 };
  assert.deepEqual(J(notch.cornersOf(n, 185)), { radius: 8, shoulder: 4 });
  assert.deepEqual(J(notch.cornersOf(n, 20)), { radius: 20 / 3, shoulder: 10 / 3 }, 'a narrow set width shrinks both');
  assert.deepEqual(J(notch.cornersOf(null, 100)), { radius: 0, shoulder: 0 });
});

test("a panel's housing is its listed width, else the Pro's", () => {
  const air13 = { width: 2560, height: 1664, transform: 0 };
  assert.deepEqual(J(notch.notchOf(cutouts, 'top', 'eDP-1', 1280, 832, 2, air13, 0, 0, panels)), { housing: 157, width: 157, height: 28, radius: 7, shoulder: 3.5 });
  assert.equal(notch.notchOf(cutouts, 'top', 'eDP-1', 1512, 982, 2, mbp14, 0, 0, panels).housing, 185);
  assert.equal(notch.notchOf(cutouts, 'top', 'eDP-1', 1280, 832, 2, air13).housing, 185, 'no table: the default');
});

test('the described panels parse; malformed ones are dropped', () => {
  assert.equal(cutouts.length, 2);
  assert.deepEqual(J(notch.parseCutouts('not json')), []);
  assert.deepEqual(J(notch.parseCutouts('{}')), []);
});

test("a top bar on a described panel meets its notch, in logical px", () => {
  assert.deepEqual(J(notch.notchOf(cutouts, 'top', 'eDP-1', 1512, 982, 2, mbp14)), { housing: 185, width: 185, height: 32, radius: 8, shoulder: 4 });
  // Fractional scale: Hyprland's mode decides, the logical size scales it.
  assert.deepEqual(J(notch.notchOf(cutouts, 'top', 'eDP-1', 1890, 1228, 2, mbp14)), { housing: 232, width: 232, height: 40, radius: 10, shoulder: 5 });
  // Before Hyprland answers, the logical size times a whole ratio stands in.
  assert.deepEqual(J(notch.notchOf(cutouts, 'top', 'eDP-1', 1512, 982, 2, null)), { housing: 185, width: 185, height: 32, radius: 8, shoulder: 4 });
  assert.deepEqual(J(notch.notchOf(cutouts, 'top', 'eDP-1', 1512, 982, 2, mbp14, 200, 34)), { housing: 185, width: 200, height: 34, radius: 8, shoulder: 4 }, 'set width and calibrated height win');
});

test('no notch: another edge, another screen, a turned panel, Asahi hiding the notch row', () => {
  assert.equal(notch.notchOf(cutouts, 'bottom', 'eDP-1', 1512, 982, 2, mbp14), null);
  assert.equal(notch.notchOf(cutouts, 'top', 'DP-1', 1512, 982, 2, mbp14), null);
  assert.equal(notch.notchOf(cutouts, 'top', 'eDP-1', 982, 1512, 2, { width: 3024, height: 1964, transform: 1 }), null);
  assert.equal(notch.notchOf(cutouts, 'top', 'eDP-1', 1512, 945, 2, { width: 3024, height: 1890, transform: 0 }), null);
});

test('a top bar waits for the mode only where a notch may still come', () => {
  assert.equal(notch.pending(cutouts, 'top', 'eDP-1', 1890, 1228, 2, null), true, 'fractional scale, no mode yet');
  assert.equal(notch.pending(cutouts, 'top', 'eDP-1', 1890, 1228, 2, mbp14), false, 'the mode settles it');
  assert.equal(notch.pending(cutouts, 'top', 'eDP-1', 1512, 982, 2, null), false, 'a whole scale rebuilds the mode');
  assert.equal(notch.pending(cutouts, 'top', 'HDMI-A-1', 1890, 1228, 2, null), false, 'no described connector');
  assert.equal(notch.pending(cutouts, 'left', 'eDP-1', 1890, 1228, 2, null), false);
});

// Zone fit inputs from real tokens, as tests/zone-fit.test.cjs builds them.
function make(o) {
  const k = cell.tokens({ bar: 26, mode: 'slots', spacing: 0 });
  const mk = (prefix, inks) => inks.map((ink, i) => {
    const p = cell.place(k, ink, ink <= 16);
    return { key: `${prefix}${i}`, extent: p.extent, spill: p.spill };
  });
  const h = cell.place(k, 12.5, true);
  const z = o.zones;
  return {
    length: o.length, inset: 4, gap: k.cell + k.spacing, gutter: k.gutter,
    pad: s => cell.endPad(k, s),
    handle: { extent: h.extent, spill: h.spill },
    notch: o.notch,
    zones: {
      left: mk('L', z.left || [12]), right: mk('R', z.right || [12]),
      before: mk('B', z.before || []),
      anchor: z.anchor === null ? null : mk('A', [z.anchor === undefined ? 40 : z.anchor])[0],
      after: mk('F', z.after || []), center: mk('C', z.center || [])
    },
    previous: o.previous || null, transient: o.transient || null
  };
}
// Each centre slot's span from a result, handles included.
function centreSpans(input, r) {
  const fold = new Set(r.folded.center);
  const z = input.zones;
  const n = { key: 'notch', extent: input.notch, spill: 0 };
  let slots = (z.anchor ? z.before.concat([n, z.anchor], z.after) : [n].concat(z.center)).filter(s => !fold.has(s.key));
  const h = key => ({ key, extent: input.handle.extent, spill: input.handle.spill });
  if (['start', 'both'].includes(r.handles.center)) slots = [h('handle:center:start')].concat(slots);
  if (['end', 'both'].includes(r.handles.center)) slots = slots.concat([h('handle:center:end')]);
  let x = r.centerStart + input.pad(slots[0].spill);
  const out = {};
  for (const s of slots) { out[s.key] = [x, x + s.extent]; x += s.extent; }
  out.end = x + input.pad(slots[slots.length - 1].spill);
  return out;
}
const NOTCH = 185 + 2 * 4;

test('the notch slot stays on the camera and the anchor starts right of it', () => {
  const input = make({ length: 1512, notch: NOTCH, zones: { before: [12, 12], anchor: 90, after: [12, 12] } });
  const r = fit(input);
  assert.equal(r.fits, true);
  const s = centreSpans(input, r);
  assert.ok(Math.abs((s.notch[0] + s.notch[1]) / 2 - 756) < 1e-6, 'notch centred on the screen');
  assert.ok(Math.abs(s.A0[0] - (756 + NOTCH / 2)) < 1e-6, 'anchor starts at the notch edge');
  assert.ok(s.B1[1] <= 756 - NOTCH / 2 + 1e-6, 'before-run ends left of the notch');
  assert.equal(r.centerShift, 0);
});

test('a long left zone folds on the left; the centre never slides over the camera', () => {
  const input = make({ length: 1512, notch: NOTCH, zones: { left: Array(30).fill(12), before: [12, 12], anchor: 90, after: [12] } });
  const r = fit(input);
  assert.equal(r.fits, true);
  assert.equal(r.centerShift, 0);
  assert.ok(r.folded.left.length + r.folded.center.length > 0);
  assert.ok(!r.folded.center.includes('F0'), 'the right side has room: its widgets stay');
  assert.equal(r.folded.right.length, 0);
  const s = centreSpans(input, r);
  assert.ok(Math.abs((s.notch[0] + s.notch[1]) / 2 - 756) < 1e-6);
});

test('a long right zone folds on the right, the centre after-run included', () => {
  const input = make({ length: 1512, notch: NOTCH, zones: { right: Array(20).fill(12), before: [12], anchor: 90, after: Array(8).fill(12) } });
  const r = fit(input);
  assert.equal(r.fits, true);
  assert.equal(r.folded.left.length, 0);
  assert.ok(!r.folded.center.includes('B0'), 'the left side has room');
  assert.ok(r.folded.right.length + r.folded.center.length > 0);
  assert.ok(!r.folded.center.includes('A0'), 'the anchor never folds');
});

test('without an anchor every centre widget sits right of the notch', () => {
  const input = make({ length: 1512, notch: NOTCH, zones: { anchor: null, center: [12, 30, 12] } });
  const r = fit(input);
  const s = centreSpans(input, r);
  assert.ok(Math.abs((s.notch[0] + s.notch[1]) / 2 - 756) < 1e-6);
  assert.ok(s.C0[0] >= 756 + NOTCH / 2 - 1e-6);
});

test('an empty centre still keeps the side zones off the camera', () => {
  const input = make({ length: 1512, notch: NOTCH, zones: { anchor: null, left: Array(40).fill(12) } });
  const r = fit(input);
  assert.ok(r.folded.left.length > 0, 'the left zone folds before it reaches the notch');
});

test('a centre expansion slides nothing over the camera', () => {
  const base = make({ length: 1512, notch: NOTCH, zones: { left: [12, 12], before: Array(40).fill(12), anchor: 90, after: [12] } });
  const lasting = fit(base);
  assert.ok(lasting.folded.center.length > 0, 'some of the before-run folded');
  const r = fit(Object.assign({}, base, { previous: lasting, transient: { zone: 'center', unfold: 'center', side: 'start' } }));
  const s = centreSpans(Object.assign({}, base), r);
  assert.ok(Math.abs((s.notch[0] + s.notch[1]) / 2 - 756) < 1e-6, 'the notch slot stays put');
});

test('on the notch a zone expansion wraps: nothing yields or hides, and the screen edge is no fallback', () => {
  const base = make({ length: 1512, notch: NOTCH, zones: { anchor: null, left: Array(40).fill(12), right: Array(6).fill(12) } });
  const lasting = fit(base);
  assert.ok(lasting.folded.left.length > 0);
  const moment = Object.assign({}, base, { previous: lasting, transient: { zone: 'left', unfold: 'left' } });
  const plain = fit(moment);
  assert.ok(plain.hidden.center || plain.hidden.right || plain.fallbacks.length, 'two zones: the expansion runs into the notch');
  const r = fit(Object.assign({}, moment, { wrap: true }));
  assert.deepEqual(J(r.folded.left), [], 'its folded widgets come back');
  assert.deepEqual(J(r.yielded), []);
  assert.deepEqual(J(r.hidden), { left: false, center: false, right: false });
  assert.deepEqual(J(r.fallbacks), []);
});

test('a zone springing out of the camera overshoots by the same few pixels at any length', () => {
  const nm = notch;
  const peak = (s) => 4 * s ** 3 / (27 * (s + 1) ** 2);
  for (const d of [40, 300, 1200]) {
    const s = nm.backOvershoot(d, 4);
    assert.ok(Math.abs(peak(s) * d - Math.min(4, d * 0.1)) < 0.01, `distance ${d}`);
  }
  assert.ok(Math.abs(nm.backOvershoot(10, 4) - 1.70158) < 1e-3, 'Qt\'s default overshoot caps a short slide');
  assert.equal(nm.backOvershoot(0, 4), 0);
});

test('a notch zone past the screen edge wraps its outer widgets into a second row from the edge', () => {
  const run = (from, widths) => { let x = from; return widths.map(w => { const s = { start: x, end: x + w }; x += w; return s; }); };
  // Left zone ending at the camera, grown 88 px past the edge at 8.
  const left = run(-80, [30, 30, 40, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50]);
  const l = J(notch.wrapRow(left, 8, 'left'));
  assert.deepEqual([l.from, l.to], [0, 3], 'every widget that starts before the edge wraps');
  assert.equal(l.shift, 88);
  assert.deepEqual(l.row, [8, 108], 'the outermost widget still meets the edge');
  assert.equal(l.rest, 20, 'the first row now starts at the first widget that stayed');
  // Right zone from the camera (870) to past the edge at 1504, the button last.
  const right = run(870, [50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 40, 30]);
  const r = J(notch.wrapRow(right, 1504, 'right'));
  assert.deepEqual([r.from, r.to], [12, 14], 'every widget that ends past the edge wraps, the button too');
  assert.equal(r.shift, -36);
  assert.deepEqual(r.row, [1434, 1504], 'the button still meets the edge');
  assert.equal(r.rest, 1470);
  // The Preferences button pinned at the edge: the first row stops at 1474,
  // where it begins, and the second row still meets the screen edge.
  const modules = run(870, [50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 40]);
  const p = J(notch.wrapRow(modules, 1474, 'right', 1504));
  assert.deepEqual([p.from, p.to], [12, 13], 'only the widget past the button wraps');
  assert.deepEqual(p.row, [1464, 1504]);
  assert.equal(p.rest, 1470);
  assert.equal(notch.wrapRow(run(100, [50, 50]), 8, 'left'), null, 'it fits: no second row');
  assert.equal(notch.wrapRow([], 8, 'left'), null);
});
