const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../HighlightModel.js`, 'utf8'), model);
const base = { thickness: 20, pad: 4, rounding: 17, laneStart: -Infinity, laneEnd: Infinity };

test('lone icons all get the same square highlight, never thinner than thick', () => {
  const a = model.pill({ ...base, center: 50, ink: 14 });
  const b = model.pill({ ...base, center: 90, ink: 8 });
  assert.equal(model.pill({ ...base, center: 0, ink: 20 }).length, 20);
  assert.equal(model.pill({ ...base, center: 0, ink: 21 }).length, 29);
  assert.equal(a.length, 20);
  assert.equal(b.length, 20);
  assert.equal(a.start, 40);
  assert.equal(a.radius, 10);
});
test('text gets a pill with equal padding around what it paints', () => {
  const p = model.pill({ ...base, center: 100, ink: 60 });
  assert.equal(p.length, 68);
  assert.equal(p.start, 66);
});
test('a highlight stays inside its lane by shifting, then by shrinking', () => {
  assert.equal(model.pill({ ...base, center: 30, ink: 60, laneStart: 10, laneEnd: 200 }).start, 10);
  assert.equal(model.pill({ ...base, center: 190, ink: 60, laneStart: 10, laneEnd: 200 }).start, 132);
  const tight = model.pill({ ...base, center: 30, ink: 60, laneStart: 10, laneEnd: 50 });
  assert.deepEqual([tight.start, tight.length], [10, 40]);
});
test('corner radius nests inside the island but never exceeds a pill', () => {
  assert.equal(model.pill({ ...base, center: 0, ink: 0, rounding: 4 }).radius, 4);
  assert.equal(model.pill({ ...base, center: 0, ink: 0, rounding: 40 }).radius, 10);
});
test('ink is read from glyph, label and painted hints, then from children', () => {
  assert.equal(model.inkWidth({ glyphPaintedWidth: 14 }), 14);
  assert.equal(model.inkWidth({ labelWidth: 52 }), 52);
  assert.equal(model.inkWidth({ labelWidth: 52, textRotation: 90, children: [] }), 0);
  const child = (x, width) => ({ x, width, height: 10, visible: true, opacity: 1, children: [] });
  assert.equal(model.inkWidth({ children: [child(4, 10), child(20, 12)] }), 28);
  assert.equal(model.inkWidth({ children: [{ ...child(0, 30), paintedWidth: 22 }] }), 22);
});
