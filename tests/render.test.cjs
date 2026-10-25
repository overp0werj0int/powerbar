const { test } = require('node:test');
const assert = require('node:assert/strict');
const model = require('../RenderModel.js');
const entry = (key, extra = {}) => ({ id: 'duplicate', powerbarInstance: key, ...extra });
const config = () => ({ transparent: false, layout: { left: [entry('a'), entry('b')], center: [], right: [] } });
test('records keep duplicate ids apart and carry their zone and list', () => {
  const layout = { left: [entry('a')], centerBegin: [entry('b')], center: [entry('c')], centerEnd: [entry('d'), entry('t', { powerbarList: 'tray' })], right: [] };
  const records = model.records(layout);
  assert.deepEqual(records.map(r => [r.key, r.region, r.drawn, r.list]), [
    ['a', 'left', 'left', 'left'], ['b', 'center', 'centerBegin', 'centerBegin'], ['c', 'center', 'center', 'center'],
    ['d', 'center', 'centerEnd', 'centerEnd'], ['t', 'center', 'centerEnd', 'tray']]);
  assert.deepEqual(model.split(records), { left: ['a'], centerBegin: ['b'], center: ['c'], centerEnd: ['d', 't'], right: [] });
});
test('capture invalidation distinguishes identical reloads, surface alpha, settings, moves and unknown changes', () => {
  const original = config(), next = config();
  assert.deepEqual(model.captureDelta(original, next), []);
  next.powerbarBackgroundOpacity = 80;
  assert.deepEqual(model.captureDelta(original, next), []);
  next.layout.left[1].format = 'HH:mm';
  assert.deepEqual(model.captureDelta(original, next), ['b']);
  next.layout.left.reverse();
  assert.deepEqual(model.captureDelta(original, next), ['b', 'a']);
  next.theme = 'new';
  assert.equal(model.captureDelta(original, next), null);
});
test('group index preserves group identity and member routing', () => {
  const group = { id: 'g', items: ['a', 'b'] };
  const index = model.groupIndex([group]);
  assert.equal(index.owner.a, group); assert.equal(index.byId.g, group);
  assert.equal(index.owner.absent, undefined);
});

test('raw layout indexes tolerate invalid entries without disturbing unrelated zones', () => {
  assert.deepEqual(model.records({left: [null, 42, 'clock', entry('a')]}).map(r => r.key), ['clock:left:2', 'a']);
  const original = config(), next = config();
  original.layout.center = [entry('center')]; next.layout.center = [entry('center')];
  next.layout.left.push(entry('new'));
  assert.deepEqual(model.captureDelta(original, next), ['new']);
});
test('equality matches serialised equality, with or without shared members', () => {
  const shared = { id: 'x', settings: { a: 1 } };
  assert.equal(model.equal({ key: 'a', entry: shared }, { key: 'a', entry: shared }), true);
  assert.equal(model.equal({ key: 'a', entry: shared }, { key: 'a', entry: { id: 'x', settings: { a: 1 } } }), true);
  assert.equal(model.equal({ key: 'a', entry: shared }, { key: 'a', entry: { id: 'x', settings: { a: 2 } } }), false);
  // Key order counts, as it does in JSON.
  assert.equal(model.equal({ a: 1, b: 2 }, { b: 2, a: 1 }), false);
  assert.equal(model.equal([shared, 1], [shared, 1]), true);
  assert.equal(model.equal([shared], { 0: shared }), false);
  assert.equal(model.equal({ a: undefined }, {}), true);
  assert.equal(model.equal({ n: NaN }, { n: null }), true);
  assert.equal(model.equal(null, {}), false);
});

test('shallowSame: the same keys in the same order with the same values', () => {
  assert.equal(model.shallowSame({ start: 1, length: 2 }, { start: 1, length: 2 }), true);
  assert.equal(model.shallowSame({ start: 1, length: 2 }, { start: 1, length: 3 }), false);
  assert.equal(model.shallowSame({ start: 1 }, null), false);
  assert.equal(model.shallowSame(null, null), false, 'not objects');
});

test('under the camera the box joins the side it sits on', () => {
  assert.deepEqual(model.lists.map(l => model.zoneOf(l, true)), ['left', 'left', 'right', 'right', 'right']);
  assert.deepEqual(model.lists.map(l => model.zoneOf(l, true, 'left')), ['left', 'left', 'left', 'right', 'right']);
  assert.deepEqual(model.lists.map(l => model.zoneOf(l, false, 'left')), ['left', 'center', 'center', 'center', 'right'], 'no camera: the three center lists share the center');
  const layout = { left: [], centerBegin: [], center: [entry('c')], centerEnd: [], right: [] };
  assert.equal(model.records(layout, true, 'left')[0].region, 'left');
  assert.equal(model.records(layout, true)[0].region, 'right');
});
