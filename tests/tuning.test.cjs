const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../TuningModel.js`, 'utf8'), model);
const plain = (v) => JSON.parse(JSON.stringify(v));

// PREFS-132, PREFS-24: the Tuning page's numbers, the shipped look as the
// defaults, kept in the cache file while the page is on.
const DEFAULTS = {
  areaRing: 1, controlLift: 0,
  gapAbove: 35, tearDepth: 8, grain: 31, octaves: 3, seed: 24,
  fringeWidth: 12, fringeStrength: 13, fringeSeed: 12,
  shadeBlur: 4, shadeDrop: 7, shadeStrength: 16, shadeSpread: 0,
};

test('the sections hold the cursor switches and the camera tear\'s twelve numbers, the shipped look as defaults', () => {
  assert.deepEqual(plain(model.SECTIONS.map((s) => s.id)), ['cursor', 'tear', 'fringe', 'shade']);
  assert.deepEqual(plain(model.defaults()), DEFAULTS);
  assert.deepEqual(plain(model.PARAMS.map((p) => p.key)), Object.keys(DEFAULTS));
  for (const p of model.PARAMS) {
    assert.ok(p.value >= p.min && p.value <= p.max, p.key);
    assert.ok(p.label && typeof p.unit === 'string', p.key);
  }
  for (const s of model.SECTIONS) assert.ok(s.title && s.caption, s.id);
});

test('a toggle is 1 on and 0 off; the whole control is marked and controls stay down by default', () => {
  const toggles = model.PARAMS.filter((p) => p.toggle);
  assert.deepEqual(plain(toggles.map((p) => [p.key, p.min, p.max, p.value])), [['areaRing', 0, 1, 1], ['controlLift', 0, 1, 0]]);
  assert.equal(model.clamp('controlLift', 0), 0);
  assert.equal(model.clamp('controlLift', 7), 1);
  assert.equal(model.parse(JSON.stringify({ controlLift: 1 })).controlLift, 1);
});

test('keys are unique across sections', () => {
  const keys = model.PARAMS.map((p) => p.key);
  assert.equal(new Set(keys).size, keys.length);
});

test('values are clamped to their range and made whole', () => {
  assert.equal(model.clamp('gapAbove', -5), 0);
  assert.equal(model.clamp('gapAbove', 41), 40);
  assert.equal(model.clamp('tearDepth', 1), 2);
  assert.equal(model.clamp('octaves', 9), 5);
  assert.equal(model.clamp('grain', 24.6), 25);
  assert.equal(model.clamp('shadeStrength', '60'), 60, 'a numeric string reads as its number');
  assert.equal(model.clamp('seed', 'x'), 24, 'not a number: the default');
  assert.equal(model.clamp('seed', null), 24);
  assert.equal(model.clamp('seed', Infinity), 24);
  assert.equal(model.clamp('nope', 3), undefined);
});

test('a missing or bad file is the defaults', () => {
  for (const text of ['', undefined, null, '{', 'null', '[]', '"text"', '42', 'true'])
    assert.deepEqual(plain(model.parse(text)), DEFAULTS, String(text));
});

test('a file keeps its good values, defaults the rest and drops unknown keys', () => {
  const v = plain(model.parse(JSON.stringify({ gapAbove: 20, tearDepth: 400, seed: 'a', shadeSpread: 12.4, beam: 1 })));
  assert.deepEqual(v, { ...DEFAULTS, gapAbove: 20, tearDepth: 40, shadeSpread: 12 });
});

test('what is written reads back the same', () => {
  const v = { ...DEFAULTS, gapAbove: 3, fringeWidth: 0, shadeSpread: 80 };
  const text = model.serialize(v);
  assert.deepEqual(plain(model.parse(text)), v);
  assert.deepEqual(Object.keys(JSON.parse(text)), Object.keys(DEFAULTS));
  assert.deepEqual(plain(model.parse(model.serialize({ grain: 999 }))), { ...DEFAULTS, grain: 80 });
});
