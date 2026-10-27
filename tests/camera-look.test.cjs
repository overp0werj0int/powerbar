const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../CameraLookModel.js`, 'utf8'), model);
const plain = (v) => JSON.parse(JSON.stringify(v));

// PREFS-24, PREFS-132: the torn cap's numbers, kept in the cache file.
const DEFAULTS = {
  gapAbove: 8, tearDepth: 14, grain: 25, octaves: 3, seed: 7, fringeSeed: 19,
  fringeWidth: 2, fringeStrength: 80, shadeBlur: 18, shadeDrop: 10, shadeStrength: 45, shadeSpread: 0,
};

test('the twelve numbers have the demo\'s defaults, in the pane\'s order', () => {
  assert.deepEqual(plain(model.defaults()), DEFAULTS);
  assert.deepEqual(plain(model.PARAMS.map((p) => p.key)), Object.keys(DEFAULTS));
  for (const p of model.PARAMS) assert.ok(p.value >= p.min && p.value <= p.max, p.key);
});

test('values are clamped to their range and made whole', () => {
  assert.equal(model.clamp('gapAbove', -5), 0);
  assert.equal(model.clamp('gapAbove', 41), 40);
  assert.equal(model.clamp('tearDepth', 1), 2);
  assert.equal(model.clamp('octaves', 9), 5);
  assert.equal(model.clamp('grain', 24.6), 25);
  assert.equal(model.clamp('shadeStrength', '60'), 60, 'a numeric string reads as its number');
  assert.equal(model.clamp('seed', 'x'), 7, 'not a number: the default');
  assert.equal(model.clamp('seed', null), 7);
  assert.equal(model.clamp('seed', Infinity), 7);
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
