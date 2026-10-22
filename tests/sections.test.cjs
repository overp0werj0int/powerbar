const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const J = v => JSON.parse(JSON.stringify(v));
const m = load('SectionsModel.js');
const ids = l => J(l).map(e => typeof e === "string" ? e : e.id);
const five = bar => J(m.lists).map(k => ids(bar.layout[k]));

// Omarchy's stock layout since its six sections.
const stock = () => ({ layout: {
  left: [{ id: 'omarchy.menu' }, { id: 'omarchy.workspaces' }],
  centerBegin: [{ id: 'omarchy.indicators' }],
  center: [{ id: 'omarchy.clock' }],
  centerEnd: [{ id: 'omarchy.elsewhen' }, { id: 'omarchy.weather' }],
  right: [{ id: 'omarchy.tray' }, { id: 'omarchy.audio' }],
  tray: [{ id: 'x.drawer' }]
} });

test("Omarchy's six sections are read as they are", () => {
  const bar = stock();
  assert.equal(m.needsRead(bar), false);
  assert.deepEqual(J(m.read(bar)), J(stock()));
});

test('zones: the three center lists share the center zone, each on its side', () => {
  assert.deepEqual(J(m.lists.map(k => m.zoneOf(k))), ['left', 'center', 'center', 'center', 'right']);
  assert.deepEqual(J(m.lists.map(k => m.sideOf(k))), ['', 'start', 'end', 'end', '']);
  assert.equal(m.sixSections(['left', 'centerBegin', 'center', 'centerEnd', 'right', 'tray']), true);
  assert.equal(m.sixSections(['left', 'center', 'right']), false);
  assert.equal(m.sixSections(undefined), false);
});

test("Powerbar's anchored center splits at its anchor", () => {
  const bar = { centerAnchor: 'omarchy.clock', layout: { left: [], center: [{ id: 'a' }, { id: 'omarchy.clock' }, { id: 'b' }], right: [] } };
  assert.equal(m.needsRead(bar), true);
  m.read(bar);
  assert.deepEqual(five(bar), [[], ['a'], ['omarchy.clock'], ['b'], []]);
  assert.ok(!('centerAnchor' in bar));
  assert.equal(m.needsRead(bar), false);
});

test('without an anchor the whole center is the box', () => {
  for (const anchor of ['', undefined, 'gone']) {
    const bar = { layout: { left: [], center: [{ id: 'a' }, { id: 'b' }], right: [] } };
    if (anchor !== undefined) bar.centerAnchor = anchor;
    m.read(bar);
    assert.deepEqual(five(bar), [[], [], ['a', 'b'], [], []], String(anchor));
  }
});

test('the anchor key of an already split config is dropped', () => {
  const bar = stock(); bar.centerAnchor = 'omarchy.clock';
  m.read(bar);
  assert.deepEqual(J(bar), J(stock()));
});

test('a missing list reads as empty; the tray list is left alone', () => {
  const bar = { layout: { left: [{ id: 'a' }], centerBegin: [] } };
  assert.equal(m.needsRead(bar), true);
  m.read(bar);
  assert.deepEqual(five(bar), [['a'], [], [], [], []]);
  assert.ok(!('tray' in bar.layout));
  assert.equal(m.needsRead({}), false, 'no layout: the fallback config');
});

test('groups of the anchored center take the list their entry is in', () => {
  const e = k => ({ id: 'w.' + k, powerbarInstance: k });
  const groups = () => [
    { id: 'b', section: 'center', before: 'a1' },
    { id: 'n', section: 'center', before: 'anc' },
    { id: 'e', section: 'center', before: 'z1' },
    { id: 'end', section: 'center', before: '' },
    { id: 'l', section: 'left', before: '' }
  ];
  const threeList = { centerAnchor: 'w.anc', powerbarGroups: groups(),
    layout: { left: [], center: [e('a1'), e('anc'), e('z1')], right: [] } };
  const sixList = { centerAnchor: 'w.anc', powerbarGroups: groups(),
    layout: { left: [], centerBegin: [e('a1')], center: [e('anc')], centerEnd: [e('z1')], right: [] } };
  for (const bar of [threeList, sixList]) {
    m.read(bar);
    assert.deepEqual(J(bar.powerbarGroups).map(g => [g.id, g.section, g.before]), [
      ['b', 'centerBegin', 'a1'], ['n', 'centerBegin', ''], ['e', 'centerEnd', 'z1'],
      ['end', 'centerEnd', ''], ['l', 'left', '']
    ]);
  }
  const unanchored = { centerAnchor: '', powerbarGroups: groups(), layout: { left: [], center: [e('a1'), e('anc')], right: [] } };
  m.read(unanchored);
  assert.deepEqual(J(unanchored.powerbarGroups).map(g => g.section), ['center', 'center', 'center', 'center', 'left'], 'no anchor: the box keeps them');
});

test('the two-zone mode keeps its lists; the mode and its arrangements go', () => {
  const bar = { powerbarZones: 'two', powerbarZoneLayouts: { three: { layout: {} } },
    layout: { left: [{ id: 'a' }], center: [], right: [{ id: 'b' }] } };
  assert.ok(m.zoneLayouts(bar));
  m.read(bar);
  assert.deepEqual(five(bar), [['a'], [], [], [], ['b']]);
  assert.ok(!('powerbarZones' in bar) && !('powerbarZoneLayouts' in bar));
  assert.equal(m.zoneLayouts(bar), null);
});

test("the notch mode's zones become the two sides of the center, in the Notch style", () => {
  const bar = { powerbarZones: 'notch', powerbarStyle: 'islands',
    powerbarGroups: [{ id: 'g', section: 'left', before: 'x' }, { id: 'h', section: 'right', before: '' }],
    layout: { left: [{ id: 'l1' }, { id: 'l2' }], center: [], right: [{ id: 'r1' }, { id: 'r2' }] } };
  m.read(bar);
  assert.deepEqual(five(bar), [[], ['l1', 'l2'], [], ['r1', 'r2'], []]);
  assert.equal(bar.powerbarStyle, 'notch');
  assert.deepEqual(J(bar.powerbarGroups).map(g => g.section), ['centerBegin', 'centerEnd']);
});

test('an Omarchy with the six sections gets the five lists back, without an anchor', () => {
  const bar = m.read(stock());
  bar.powerbarFiveZones = { begin: 1, center: 1 };
  m.write(bar, true);
  assert.deepEqual(J(bar), J(stock()));
});

test('an Omarchy without them gets one center list, its box as the anchor, and the same five on the next read', () => {
  const bar = m.read(stock());
  const before = J(bar);
  m.write(bar, false);
  assert.deepEqual(ids(bar.layout.center), ['omarchy.indicators', 'omarchy.clock', 'omarchy.elsewhen', 'omarchy.weather']);
  assert.ok(!('centerBegin' in bar.layout) && !('centerEnd' in bar.layout));
  assert.equal(bar.centerAnchor, 'omarchy.clock');
  assert.deepEqual(J(bar.powerbarFiveZones), { begin: 1, center: 1 });
  assert.equal(m.needsRead(bar), true);
  assert.deepEqual(J(m.read(bar)), before);
});

test('the saved split survives an empty box and a duplicated anchor id', () => {
  const empty = { layout: { left: [], centerBegin: [{ id: 'a' }], center: [], centerEnd: [{ id: 'b' }], right: [] } };
  const want = J(empty);
  assert.deepEqual(J(m.read(m.write(empty, false))), want);
  const dup = { layout: { left: [], centerBegin: [{ id: 'clock' }], center: [{ id: 'clock' }], centerEnd: [], right: [] } };
  const wantDup = J(dup);
  assert.deepEqual(J(m.read(m.write(dup, false))), wantDup);
});

test('a saved split that no longer fits falls back to the anchor', () => {
  // Another writer added a widget in front: the counts are off, the anchor still names the box.
  const bar = { centerAnchor: 'clock', powerbarFiveZones: { begin: 1, center: 1 },
    layout: { left: [], center: [{ id: 'new' }, { id: 'a' }, { id: 'clock' }, { id: 'b' }], right: [] } };
  m.read(bar);
  assert.deepEqual(five(bar), [[], ['new', 'a'], ['clock'], ['b'], []]);
});

test("groups Powerbar wrote for the older Omarchy are already in the five lists", () => {
  const bar = { centerAnchor: 'w', powerbarFiveZones: { begin: 0, center: 1 },
    powerbarGroups: [{ id: 'g', section: 'center', before: '' }],
    layout: { left: [], center: [{ id: 'w', powerbarInstance: 'k' }], right: [] } };
  m.read(bar);
  assert.equal(bar.powerbarGroups[0].section, 'center');
});
