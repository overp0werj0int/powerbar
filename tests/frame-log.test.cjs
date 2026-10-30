const { test } = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');
const log = load('FrameLogModel.js');
const motion = load('MotionModel.js');

test('INTEG-146: the wait for the first frame is start-up, not a long frame', () => {
  const s = log.summary([1000, 1090, 1106, 1123, 1139]);
  assert.equal(s.startup, 90);
  assert.equal(s.frames, 3);
  assert.equal(s.long, 0);
  assert.equal(s.max, 17);
  assert.equal(s.wall, 139);
});

test('INTEG-146: a stall during the motion is a long frame', () => {
  const s = log.summary([0, 10, 26, 66, 82]);
  assert.equal(s.startup, 10);
  assert.equal(s.long, 1);
  assert.equal(s.max, 40);
  assert.equal(s.p95, 40);
  assert.equal(s.mean.toFixed(1), '24.0');
});

test('INTEG-146: a run whose only frame is the first reports start-up and no frames', () => {
  assert.deepEqual({ ...log.summary([0, 50]) }, { startup: 50, frames: 0, wall: 50, mean: 0, p95: 0, max: 0, long: 0 });
  assert.equal(log.summary([0]), null);
});

test('INTEG-146: the timeline notes a slow first frame as startup, later ones as longframe', () => {
  assert.equal(log.frameNote(1, 80), 'startup');
  assert.equal(log.frameNote(2, 80), 'longframe');
  assert.equal(log.frameNote(1, 25), '');
  assert.equal(log.frameNote(5, 16), '');
});

test('INTEG-146: the PB-FT line carries startup beside the frame stats', () => {
  const s = log.summary([0, 90, 106, 123]);
  assert.equal(log.line(['strip:out', 'card:show'], 180.4, s),
    'PB-FT anim=strip:out+card:show startup=90 frames=2 nominal=180 wall=123 mean=16.5 p95=17 max=17 long=0');
});

test('motion timings: the strip and drawers, on a bar and from the notch', () => {
  assert.deepEqual([motion.stripMs(true, false), motion.stripMs(false, false)], [180, 130]);
  assert.deepEqual([motion.stripMs(true, true), motion.stripMs(false, true)], [220, 140]);
  assert.deepEqual([motion.drawerMs(true, false), motion.drawerMs(false, false)], [160, 110]);
  assert.deepEqual([motion.drawerMs(true, true), motion.drawerMs(false, true)], [220, 140]);
});

test('motion timings: an inline expansion waits for its neighbours only when they give way', () => {
  assert.equal(motion.inlineMs(true, false), motion.SLOT_MS);
  assert.equal(motion.inlineMs(true, true), motion.GIVE_WAY_MS + motion.SLOT_MS);
  assert.equal(motion.inlineMs(false, true), motion.YIELD_PAUSE_MS + motion.YIELD_BACK_MS);
});
