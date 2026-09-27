const { test } = require('node:test');
const assert = require('node:assert/strict');
const drag = require('../DragModel.js');

const state = (targetKey, targetSurface, after = false) => ({
  ready: true, sourceKey: 'clock:two', sourceSurface: 'bar:left',
  targetKey, targetSurface, after
});

test('the dragged icon leaves its source and opens a gap beside the target', () => {
  const preview = state('audio', 'bar:right');
  assert.equal(drag.slot(preview, 'clock:two', 'bar:left').hidden, true);
  assert.equal(drag.slot(preview, 'audio', 'bar:right').before, true);
  assert.equal(drag.slot(preview, 'network', 'bar:right').before, false);
  assert.equal(drag.slot({ ...preview, after: true }, 'audio', 'bar:right').after, true);
});

test('the same preview policy works in drawers and empty islands', () => {
  const preview = { ...state('member', 'group:tools'), sourceSurface: 'managed:left' };
  assert.equal(drag.slot(preview, 'clock:two', 'managed:left').hidden, true);
  assert.equal(drag.slot(preview, 'member', 'group:tools').before, true);
  assert.equal(drag.endGap({ ...preview, targetKey: '', targetSurface: 'group:tools' }, 'group:tools'), true);
  assert.equal(drag.endGap({ ...preview, targetKey: '', targetSurface: 'bar:center' }, 'bar:center'), true);
});

test('a group icon highlights as a container and no preview appears before capture', () => {
  const preview = state('group:tools', 'bar:right');
  assert.equal(drag.slot(preview, 'group:tools', 'bar:right').groupTarget, true);
  assert.equal(drag.slot(preview, 'group:tools', 'bar:right').before, false);
  assert.equal(drag.slot({ ...preview, ready: false }, 'clock:two', 'bar:left').hidden, false);
  assert.equal(drag.slot({ ...preview, ready: false }, 'group:tools', 'bar:right').groupTarget, false);
});

test('pickup keeps the source space until the pointer leaves it', () => {
  const pickup = { ...state('clock:two', 'bar:left'), self: true };
  const source = drag.slot(pickup, 'clock:two', 'bar:left');
  assert.equal(source.hidden, true);
  assert.equal(source.holdSpace, true);
  assert.equal(source.before, false);
});

test('an open gap does not flip sides until the pointer crosses the icon', () => {
  assert.equal(drag.afterPointer(120, 100, 24, 20), false);
  assert.equal(drag.afterPointer(138, 100, 24, 20), true);
  assert.equal(drag.afterPointer(130, 100, 0, 20), true);
});

test('a released icon settles into its own slot, preferring an open drawer', () => {
  const slots = [
    { key: 'audio', drawer: false, shown: true },
    { key: 'clock:two', drawer: false, shown: true },
    { key: 'clock:two', drawer: true, shown: false }
  ];
  assert.deepEqual(drag.settleTarget(slots, 'clock:two', ''), { index: 2, fade: false });
  assert.deepEqual(drag.settleTarget(slots.slice(0, 2), 'clock:two', ''), { index: 1, fade: false });
});

test('a released icon hidden by its destination fades into its group icon or in place', () => {
  const slots = [
    { key: 'clock:two', drawer: false, shown: false },
    { key: 'group:tools', drawer: false, shown: true }
  ];
  assert.deepEqual(drag.settleTarget(slots, 'clock:two', 'group:tools'), { index: 1, fade: true });
  assert.deepEqual(drag.settleTarget(slots, 'clock:two', ''), { index: -1, fade: true });
  assert.deepEqual(drag.settleTarget([], 'clock:two', 'group:tools'), { index: -1, fade: true });
});

test('the settle frame glides from the release point without jumping', () => {
  const from = { x: 100, y: 40 }, to = { x: 20, y: 0 };
  assert.deepEqual(drag.settleFrame(from, to, 0, false), { x: 100, y: 40, opacity: 1, scale: 1 });
  assert.deepEqual(drag.settleFrame(from, to, 0.5, false), { x: 60, y: 20, opacity: 1, scale: 1 });
  assert.deepEqual(drag.settleFrame(from, to, 1, false), { x: 20, y: 0, opacity: 1, scale: 1 });
  assert.deepEqual(drag.settleFrame(from, to, 2, false), { x: 20, y: 0, opacity: 1, scale: 1 });
  const fading = drag.settleFrame(from, to, 1, true);
  assert.equal(fading.opacity, 0);
  assert.ok(fading.scale < 1 && fading.scale > 0);
  assert.deepEqual(drag.settleFrame(from, null, 0.5, false), { x: 100, y: 40, opacity: 0.5, scale: 0.8 });
});
