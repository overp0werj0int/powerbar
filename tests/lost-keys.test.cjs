// An entry rewritten by another writer (Omarchy's updateEntryInline, the tray's
// pin) comes back without Powerbar's keys: lostKeys finds them in the layout
// the bar showed before, applyLostKeys puts them back.
const test = require('node:test');
const assert = require('node:assert/strict');
const bar = require('../BarModel.js');
const J = (v) => JSON.parse(JSON.stringify(v));

const before = () => ({
  left: [{ id: 'omarchy.menu', powerbarInstance: 'pw-menu' }],
  center: [{ id: 'omarchy.clock', format: 'HH:mm', powerbarInstance: 'pw-clock', powerbarVisibility: 'shown' }],
  right: [
    { id: 'omarchy.tray', pinned: [], hidden: [], powerbarInstance: 'pw-tray', powerbarVisibility: 'managed' },
    { id: 'omarchy.power', powerbarInstance: 'pw-power' },
  ],
});

test('a clock rewritten as {id, settings} gets its instance back', () => {
  const next = before();
  next.center[0] = { id: 'omarchy.clock', format: 'h:mm AP', powerbarVisibility: 'shown' };
  const plan = bar.lostKeys(before(), next);
  assert.deepEqual(J(plan), [{ zone: 'center', index: 0, id: 'omarchy.clock', keys: { powerbarInstance: 'pw-clock' } }]);
  const config = { layout: next };
  assert.equal(bar.applyLostKeys(config, plan), 1);
  assert.deepEqual(J(config.layout.center[0]), { id: 'omarchy.clock', format: 'h:mm AP', powerbarVisibility: 'shown', powerbarInstance: 'pw-clock' });
});

test('the tray pinning an icon keeps its On demand setting too', () => {
  const next = before();
  next.right[0] = { id: 'omarchy.tray', pinned: ['x'], hidden: [] };
  const config = { layout: next };
  bar.applyLostKeys(config, bar.lostKeys(before(), next));
  assert.deepEqual(J(config.layout.right[0]), { id: 'omarchy.tray', pinned: ['x'], hidden: [], powerbarInstance: 'pw-tray', powerbarVisibility: 'managed' });
});

test('a key the writer set itself wins over the old one', () => {
  const next = before();
  next.right[0] = { id: 'omarchy.tray', powerbarVisibility: 'shown' };
  assert.deepEqual(J(bar.lostKeys(before(), next)[0].keys), { powerbarInstance: 'pw-tray' });
});

test('two of one widget each get their own instance back, by place', () => {
  const prev = { left: [], center: [], right: [
    { id: 'omarchy.clock', powerbarInstance: 'pw-a' }, { id: 'omarchy.power' , powerbarInstance: 'pw-p' }, { id: 'omarchy.clock', powerbarInstance: 'pw-b' }] };
  const next = { left: [], center: [], right: [{ id: 'omarchy.clock', x: 1 }, { id: 'omarchy.power', powerbarInstance: 'pw-p' }, { id: 'omarchy.clock', x: 1 }] };
  const config = { layout: next };
  bar.applyLostKeys(config, bar.lostKeys(prev, next));
  assert.deepEqual(config.layout.right.map((e) => e.powerbarInstance), ['pw-a', 'pw-p', 'pw-b']);
});

test('a moved widget is still matched by id', () => {
  const next = before();
  next.right.unshift({ id: 'omarchy.clock' });
  next.center = [];
  assert.deepEqual(J(bar.lostKeys(before(), next)), [{ zone: 'right', index: 0, id: 'omarchy.clock', keys: { powerbarInstance: 'pw-clock', powerbarVisibility: 'shown' } }]);
});

test('nothing to do: instances present, a new widget, an instance already in use, no previous layout', () => {
  assert.deepEqual(J(bar.lostKeys(before(), before())), []);
  const added = before();
  added.left.push({ id: 'omarchy.audio' });
  assert.deepEqual(J(bar.lostKeys(before(), added)), []);
  const reused = before();
  reused.left.push({ id: 'omarchy.clock' });
  assert.deepEqual(J(bar.lostKeys(before(), reused)), []);
  assert.deepEqual(J(bar.lostKeys(null, added)), []);
  assert.deepEqual(J(bar.lostKeys(before(), null)), []);
});

test('string entries are read as {id} and become objects when restored', () => {
  const next = before();
  next.left[0] = 'omarchy.menu';
  const config = { layout: next };
  bar.applyLostKeys(config, bar.lostKeys(before(), next));
  assert.deepEqual(J(config.layout.left[0]), { id: 'omarchy.menu', powerbarInstance: 'pw-menu' });
});

test('applying a plan to a config that changed again only touches matching entries', () => {
  const next = before();
  next.center[0] = { id: 'omarchy.clock' };
  const plan = bar.lostKeys(before(), next);
  const moved = { layout: { left: [], center: [{ id: 'omarchy.audio' }], right: [] } };
  assert.equal(bar.applyLostKeys(moved, plan), 0);
  assert.deepEqual(J(moved.layout.center[0]), { id: 'omarchy.audio' });
});
