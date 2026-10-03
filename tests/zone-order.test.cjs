const { test } = require('node:test');
const assert = require('node:assert/strict');
const order = require('../ZoneOrderModel.js');
const bar = require('../BarModel.js');

// A zone's saved entries: { key, managed }. The centre splits at its anchor.
function drawn(entries, zone, anchorKey) {
  const isManaged = e => e.managed;
  const tag = list => e => ({ key: e.key, list, managed: e.managed, group: false });
  if (zone !== 'center' || !anchorKey) {
    const list = zone === 'center' ? 'center' : zone;
    return order.arrange(entries, isManaged, list).map(tag(list));
  }
  const at = entries.findIndex(e => e.key === anchorKey);
  return order.arrange(entries.slice(0, at), isManaged, 'before').map(tag('before'))
    .concat([tag('anchor')(entries[at])], order.arrange(entries.slice(at + 1), isManaged, 'after').map(tag('after')));
}

test('on-demand widgets draw as one run at the dots end of their list', () => {
  const e = [{ key: 'S1' }, { key: 'M1', managed: true }, { key: 'S2' }, { key: 'M2', managed: true }];
  const keys = list => order.arrange(e, x => !!x.managed, list).map(x => x.key);
  assert.deepEqual(keys('left'), ['S1', 'S2', 'M1', 'M2']);
  assert.deepEqual(keys('after'), ['S1', 'S2', 'M1', 'M2']);
  assert.deepEqual(keys('center'), ['S1', 'S2', 'M1', 'M2']);
  assert.deepEqual(keys('right'), ['M1', 'M2', 'S1', 'S2']);
  assert.deepEqual(keys('before'), ['M1', 'M2', 'S1', 'S2']);
});

test('the centre keeps each on-demand widget on its side of the anchor', () => {
  const e = [{ key: 'M1', managed: true }, { key: 'S1' }, { key: 'M2', managed: true }, { key: 'A' }, { key: 'M3', managed: true }, { key: 'S2' }];
  assert.deepEqual(drawn(e, 'center', 'A').map(x => x.key), ['M1', 'M2', 'S1', 'A', 'S2', 'M3']);
});

// Every drop lands at its gap: after the move, the widget sits in the gap's
// list, and the peers of its run before it are exactly those before the gap.
test('fuzz: 5000 drops land where the gap opened', () => {
  let seed = 7;
  const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
  for (let n = 0; n < 5000; n++) {
    const zone = ['left', 'center', 'right'][Math.floor(rnd() * 3)];
    const count = 1 + Math.floor(rnd() * 7);
    const entries = Array.from({ length: count }, (_, i) => ({ key: 'K' + i, managed: rnd() < 0.5 }));
    const anchored = zone === 'center' && rnd() < 0.7;
    if (anchored) entries.splice(Math.floor(rnd() * (count + 1)), 0, { key: 'A', managed: false });
    const anchorKey = anchored ? 'A' : '';
    // The source comes from this zone or another one.
    const fromHere = rnd() < 0.6 && entries.some(e => e.key !== 'A');
    const movable = entries.filter(e => e.key !== 'A');
    const source = fromHere ? movable[Math.floor(rnd() * movable.length)].key : 'X';
    const managed = rnd() < 0.5;
    const seq = drawn(entries, zone, anchorKey);
    const rest = seq.filter(x => x.key !== source);
    const gap = Math.floor(rnd() * (rest.length + 1));
    const before = order.dropBefore({ sequence: seq, gap, managed, layout: entries.map(e => e.key), source, anchorKey });
    // Apply it to a config.
    const config = { bar: { layout: { left: [], center: [], right: [] } } };
    config.bar.layout[zone] = entries.map(e => ({ id: e.key, powerbarInstance: e.key, powerbarVisibility: e.managed ? 'managed' : 'shown' }));
    let from = zone;
    if (!fromHere) { from = zone === 'left' ? 'right' : 'left'; config.bar.layout[from].push({ id: 'X', powerbarInstance: 'X' }); }
    bar.moveInstanceInConfig(config, from, source, zone, before, managed ? 'managed' : 'shown');
    const after = config.bar.layout[zone].map(e => ({ key: e.powerbarInstance, managed: e.powerbarVisibility === 'managed' }));
    const now = drawn(after, zone, anchorKey);
    const at = now.findIndex(x => x.key === source);
    const label = `case ${n}: ${JSON.stringify({ zone, entries, source, managed, gap, before })}`;
    assert.ok(at >= 0, label);
    // The gap's list.
    const anchorAt = rest.findIndex(x => x.list === 'anchor');
    const near = rest[gap - 1] || rest[gap];
    const list = anchorAt >= 0 ? (gap <= anchorAt ? 'before' : 'after') : near ? near.list : now[at].list;
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
  assert.equal(order.landsOnDemand(left, 4), true, 'between expanded widgets');
  assert.equal(order.landsOnDemand(left, 5), true, 'between the last expanded widget and the dots');
  assert.equal(order.landsOnDemand(left, 0), false, 'at the zone start');
  // Right zone: [dots | m1* m2* | S1 S2].
  const right = [item('m1', 'right', true), item('m2', 'right', true), item('S1', 'right'), item('S2', 'right')];
  assert.equal(order.landsOnDemand(right, 0), true, 'between the dots and the first expanded widget');
  assert.equal(order.landsOnDemand(right, 2), false, 'where the expansion meets the shown run');
  assert.equal(order.landsOnDemand(right, 4), false, 'at the zone end');
  // Centre, start side expanded: [m* | B | anchor | F].
  const centre = [item('m', 'before', true), item('B', 'before'), item('A', 'anchor'), item('F', 'after')];
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
