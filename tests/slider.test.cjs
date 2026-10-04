const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../SliderModel.js`, 'utf8'), model);

test('snaps to steps counted from the minimum, with clean decimals', () => {
  assert.equal(model.snap(1.26, 0.5, 3, 0.5), 1.5);
  assert.equal(model.snap(1.24, 0.5, 3, 0.5), 1);
  assert.equal(model.snap(0.1 + 0.2, 0, 1, 0.1), 0.3);
  assert.equal(model.snap(87, 0, 100, 5), 85);
  assert.equal(model.snap(99, 5, 60, 5), 60);
  assert.equal(model.snap(-4, 2, 24, 1), 2);
  assert.equal(model.snap(NaN, 2, 24, 1), 2);
});

test('maps pointer positions to snapped values, clamped to the track', () => {
  assert.equal(model.fromPosition(0, 200, 0, 16, 1), 0);
  assert.equal(model.fromPosition(200, 200, 0, 16, 1), 16);
  assert.equal(model.fromPosition(-30, 200, 0, 16, 1), 0);
  assert.equal(model.fromPosition(260, 200, 0, 16, 1), 16);
  assert.equal(model.fromPosition(100, 200, 0, 16, 1), 8);
  assert.equal(model.fromPosition(5, 0, 0, 16, 1), 0);
});

test('a single edit settles at the base delay; a steady rhythm stretches it', () => {
  assert.equal(model.settleDelay(Infinity), model.SETTLE);
  assert.equal(model.settleDelay(30), model.SETTLE, 'key repeat keeps the base delay');
  assert.equal(model.settleDelay(400), 640, 'tapping every 400 ms waits 640 ms');
  assert.equal(model.settleDelay(1100), model.SETTLE_MAX, 'never waits longer than the cap');
  assert.equal(model.settleDelay(5000), model.SETTLE, 'a pause starts a new gesture');
});

test('tapping at a steady pace applies once, after the last tap', () => {
  // Taps every 380 ms: each wait outlasts the next tap, so nothing applies mid-run.
  let previous = -Infinity, applied = [], deadline = Infinity;
  for (const t of [0, 380, 760, 1140, 1520]) {
    if (t >= deadline) applied.push(deadline);
    deadline = t + model.settleDelay(t - previous);
    previous = t;
  }
  assert.deepEqual(applied, []);
  assert.equal(deadline, 1520 + 608);
});

test('wheel notches accumulate touchpad fractions and keep direction', () => {
  assert.deepEqual({ ...model.wheelSteps(0, 120) }, { steps: 1, rest: 0 });
  assert.deepEqual({ ...model.wheelSteps(0, 240) }, { steps: 2, rest: 0 });
  assert.deepEqual({ ...model.wheelSteps(0, 40) }, { steps: 0, rest: 40 });
  assert.deepEqual({ ...model.wheelSteps(100, 40) }, { steps: 1, rest: 20 });
  assert.deepEqual({ ...model.wheelSteps(-100, -40) }, { steps: -1, rest: -20 });
  assert.deepEqual({ ...model.wheelSteps(60, -100) }, { steps: 0, rest: -40 });
});

test('cuts notches only when the steps are few enough to read', () => {
  assert.equal(model.tickCount(0.5, 3, 0.5), 6);
  assert.equal(model.tickCount(0, 100, 5), 0);
  assert.equal(model.tickCount(0, 16, 1), 0);
  assert.equal(model.tickCount(0, 0, 1), 0);
});
