const { test } = require('node:test');
const assert = require('node:assert/strict');
const order = require('../ZoneOrderModel.js');
const bar = require('../BarModel.js');

// A zone as drawn, from its lists' saved entries ({ key, managed }).
const zoneLists = { left: ['left'], center: ['centerBegin', 'center', 'centerEnd'], right: ['right'] };
function drawn(byList) {
  const isManaged = e => e.managed;
  return Object.keys(byList).flatMap(list => order.arrange(byList[list], isManaged, list)
    .map(e => ({ key: e.key, list, managed: e.managed, group: false })));
}

test('on-demand widgets draw as one run at the dots end of their list', () => {
  const e = [{ key: 'S1' }, { key: 'M1', managed: true }, { key: 'S2' }, { key: 'M2', managed: true }];
  const keys = list => order.arrange(e, x => !!x.managed, list).map(x => x.key);
  assert.deepEqual(keys('left'), ['S1', 'S2', 'M1', 'M2']);
  assert.deepEqual(keys('centerEnd'), ['S1', 'S2', 'M1', 'M2']);
  assert.deepEqual(keys('center'), ['S1', 'S2', 'M1', 'M2']);
  assert.deepEqual(keys('right'), ['M1', 'M2', 'S1', 'S2']);
  assert.deepEqual(keys('centerBegin'), ['M1', 'M2', 'S1', 'S2']);
});

test('the centre keeps each on-demand widget in its own list', () => {
  const lists = { centerBegin: [{ key: 'M1', managed: true }, { key: 'S1' }, { key: 'M2', managed: true }],
    center: [{ key: 'A' }], centerEnd: [{ key: 'M3', managed: true }, { key: 'S2' }] };
  assert.deepEqual(drawn(lists).map(x => x.key), ['M1', 'M2', 'S1', 'A', 'S2', 'M3']);
});

// Every drop lands at its gap: after the move, the widget sits in the list of
// the widget it was dropped beside, and the peers of its run before it are
// exactly those before the gap.
test('fuzz: 5000 drops land where the gap opened', () => {
  let seed = 7;
  const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
  let k = 0;
  for (let n = 0; n < 5000; n++) {
    const zone = ['left', 'center', 'right'][Math.floor(rnd() * 3)];
    const byList = {};
    zoneLists[zone].forEach(list => { byList[list] = Array.from({ length: Math.floor(rnd() * 4) }, () => ({ key: 'K' + k++, managed: rnd() < 0.5 })); });
    const all = Object.values(byList).flat();
    // The source comes from this zone or another one.
    const fromHere = rnd() < 0.6 && all.length > 1;
    const source = fromHere ? all[Math.floor(rnd() * all.length)].key : 'X';
    const managed = rnd() < 0.5;
    const seq = drawn(byList);
    const rest = seq.filter(x => x.key !== source);
    if (!rest.length) continue;
    const target = rest[Math.floor(rnd() * rest.length)], after = rnd() < 0.5;
    const gap = rest.indexOf(target) + (after ? 1 : 0);
    const list = target.list;
    const before = order.dropBefore({ sequence: seq, gap, list, managed, layout: byList[list].map(e => e.key), source });
    // Apply it to a config.
    const layout = { left: [], centerBegin: [], center: [], centerEnd: [], right: [] };
    const config = { bar: { layout } };
    for (const l in byList) layout[l] = byList[l].map(e => ({ id: e.key, powerbarInstance: e.key, powerbarVisibility: e.managed ? 'managed' : 'shown' }));
    let from = fromHere ? Object.keys(byList).find(l => byList[l].some(e => e.key === source)) : zone === 'left' ? 'right' : 'left';
    if (!fromHere) layout[from].push({ id: 'X', powerbarInstance: 'X' });
    bar.moveInstanceInConfig(config, from, source, list, before, managed ? 'managed' : 'shown');
    const nowLists = {};
    for (const l in byList) nowLists[l] = layout[l].map(e => ({ key: e.powerbarInstance, managed: e.powerbarVisibility === 'managed' }));
    const now = drawn(nowLists);
    const at = now.findIndex(x => x.key === source);
    const label = `case ${n}: ${JSON.stringify({ zone, byList, source, managed, gap, list, before })}`;
    assert.ok(at >= 0, label);
    assert.equal(now[at].list, list, label);
    const peers = xs => xs.filter(x => x.list === list && x.managed === managed && x.key !== source).map(x => x.key);
    assert.deepEqual(peers(now.slice(0, at)), peers(rest.slice(0, gap)), label);
  }
});

test('a gap lands On demand only inside the expansion run', () => {
  const item = (key, list, expanded) => ({ key, list, managed: expanded, expanded });
  // Left zone, expanded: [K W A | e* s*] dots at the end.
  const left = [item('K', 'left'), item('W', 'left'), item('A', 'left'), item('e', 'left', true), item('s', 'left', true)];
  assert.equal(order.landsOnDemand(left, 2), false, 'between shown widgets');
  assert.equal(order.landsOnDemand(left, 3), false, 'where the shown run meets the expansion');
  assert.equal(order.landsOnDemand(left, 3, 'A'), false, 'at the meeting, on the last shown widget');
  assert.equal(order.landsOnDemand(left, 3, 'e'), true, 'at the meeting, on the first expanded widget');
  assert.equal(order.landsOnDemand(left, 2, 'A'), false, 'between shown widgets, whichever is under the pointer');
  assert.equal(order.landsOnDemand(left, 4, 's'), true, 'between expanded widgets, whichever is under the pointer');
  assert.equal(order.landsOnDemand(left, 4), true, 'between expanded widgets');
  assert.equal(order.landsOnDemand(left, 5), true, 'between the last expanded widget and the dots');
  assert.equal(order.landsOnDemand(left, 0), false, 'at the zone start');
  // Right zone: [dots | m1* m2* | S1 S2].
  const right = [item('m1', 'right', true), item('m2', 'right', true), item('S1', 'right'), item('S2', 'right')];
  assert.equal(order.landsOnDemand(right, 0), true, 'between the dots and the first expanded widget');
  assert.equal(order.landsOnDemand(right, 2), false, 'where the expansion meets the shown run');
  assert.equal(order.landsOnDemand(right, 2, 'm2'), true, 'at the meeting, on the last expanded widget');
  assert.equal(order.landsOnDemand(right, 2, 'S1'), false, 'at the meeting, on the first shown widget');
  assert.equal(order.landsOnDemand(right, 4), false, 'at the zone end');
  // Centre, start side expanded: [m* | B | box | F].
  const centre = [item('m', 'centerBegin', true), item('B', 'centerBegin'), item('A', 'center'), item('F', 'centerEnd')];
  assert.equal(order.landsOnDemand(centre, 0), true, 'before the first expanded widget, at the start dots');
  assert.equal(order.landsOnDemand(centre, 1), false, 'where the expansion meets the shown run');
  assert.equal(order.landsOnDemand(centre, 4), false, 'at the end with nothing expanded');
  // Hidden widgets (group members waiting in the run) are not neighbours.
  const withHidden = [item('K', 'left'), item('A', 'left'), item('e', 'left', true), { key: 'h1', list: 'left', managed: true, hidden: true }, { key: 'h2', list: 'left', managed: true, hidden: true }];
  assert.equal(order.landsOnDemand(withHidden, 3), true, 'after the last expanded widget, past hidden members');
  assert.equal(order.landsOnDemand(withHidden, 5), true, 'at the dots end past hidden members');
  assert.equal(order.landsOnDemand(withHidden, 2), false, 'where the shown run meets the expansion');
  // Nothing expanded: never On demand.
  assert.equal(order.landsOnDemand([item('K', 'left'), item('W', 'left')], 2), false);
});

test('on the notch the dots and their run sit at the far ends: the left zone starts with them, the right ends with them', () => {
  const items = [{ k: 'a' }, { k: 'm', managed: true }, { k: 'b' }];
  const keysOf = list => list.map(i => i.k);
  const managed = i => !!i.managed;
  assert.deepEqual(keysOf(order.arrange(items, managed, 'left', true)), ['m', 'a', 'b']);
  assert.deepEqual(keysOf(order.arrange(items, managed, 'right', true)), ['a', 'b', 'm']);
  assert.deepEqual(keysOf(order.arrange(items, managed, 'left')), ['a', 'b', 'm'], 'elsewhere: the end');
  assert.equal(order.dotsAtStart('left', true), true);
  assert.equal(order.dotsAtStart('right', true), false);
  // A gap at the left zone's start, before an expanded widget: on demand.
  const seq = [{ key: 'm', list: 'left', managed: true, expanded: true }, { key: 'a', list: 'left' }];
  assert.equal(order.landsOnDemand(seq, 0, null, true), true);
});
