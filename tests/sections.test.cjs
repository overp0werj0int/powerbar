const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const J = v => JSON.parse(JSON.stringify(v));
const m = load('SectionsModel.js');
const ids = l => J(l).map(e => typeof e === "string" ? e : e.id);

// Omarchy's stock layout since its six sections.
const stock = () => ({ layout: {
  left: [{ id: 'omarchy.menu' }, { id: 'omarchy.workspaces' }],
  centerBegin: [{ id: 'omarchy.indicators' }],
  center: [{ id: 'omarchy.clock' }],
  centerEnd: [{ id: 'omarchy.elsewhen' }, { id: 'omarchy.weather' }],
  right: [{ id: 'omarchy.tray' }, { id: 'omarchy.audio' }],
  tray: [{ id: 'x.drawer' }]
} });

test("Omarchy's centre sections fold into one centre list around its anchor", () => {
  const bar = m.fold(stock());
  assert.deepEqual(ids(bar.layout.center), ['omarchy.indicators', 'omarchy.clock', 'omarchy.elsewhen', 'omarchy.weather']);
  assert.equal(bar.centerAnchor, 'omarchy.clock');
  assert.equal(m.needsFold(bar), false);
  for (const k of ['centerBegin', 'centerEnd', 'tray']) assert.ok(!(k in bar.layout), k);
});

test('a centre anchor Powerbar already has is kept', () => {
  const bar = stock(); bar.centerAnchor = '';
  assert.equal(m.fold(bar).centerAnchor, '');
  const named = stock(); named.centerAnchor = 'omarchy.weather';
  assert.equal(m.fold(named).centerAnchor, 'omarchy.weather');
});

test("widgets in Omarchy's tray drawer become on-demand widgets beside the tray", () => {
  const bar = m.fold(stock());
  assert.deepEqual(ids(bar.layout.right), ['omarchy.tray', 'x.drawer', 'omarchy.audio']);
  assert.equal(bar.layout.right[1].powerbarVisibility, 'managed');
  const kept = stock(); kept.layout.tray = [{ id: 'y', powerbarVisibility: 'shown' }, 'z'];
  kept.layout.right = [{ id: 'omarchy.audio' }];
  const out = m.fold(kept).layout.right;
  assert.deepEqual(J(out.slice(1)), [{ id: 'y', powerbarVisibility: 'shown' }, { id: 'z', powerbarVisibility: 'managed' }], 'no tray: the end of the right zone');
});

test('a write unfolds the centre at its anchor, and folding again gives the same layout', () => {
  const bar = m.fold(stock());
  const folded = J(bar);
  m.unfold(bar);
  assert.deepEqual(ids(bar.layout.centerBegin), ['omarchy.indicators']);
  assert.deepEqual(ids(bar.layout.center), ['omarchy.clock']);
  assert.deepEqual(ids(bar.layout.centerEnd), ['omarchy.elsewhen', 'omarchy.weather']);
  assert.deepEqual(J(bar.layout.tray), []);
  assert.deepEqual(J(m.fold(bar)), folded);
});

test('without an anchor the whole centre list is the centre box', () => {
  const bar = { centerAnchor: '', layout: { left: [], center: [{ id: 'a' }, { id: 'b' }], right: [] } };
  m.unfold(bar);
  assert.deepEqual(ids(bar.layout.center), ['a', 'b']);
  assert.deepEqual(J([bar.layout.centerBegin, bar.layout.centerEnd]), [[], []]);
  const old = { layout: { left: [], center: [{ id: 'a' }, { id: 'omarchy.clock' }, { id: 'b' }], right: [] }, centerAnchor: 'omarchy.clock' };
  m.unfold(old);
  assert.deepEqual([ids(old.layout.centerBegin), ids(old.layout.center), ids(old.layout.centerEnd)], [['a'], ['omarchy.clock'], ['b']], "Powerbar's own older config");
});

test("a layout already in Omarchy's shape is not unfolded twice", () => {
  const bar = stock();
  assert.deepEqual(J(m.unfold(bar)), J(stock()));
});
