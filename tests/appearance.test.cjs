const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../AppearanceModel.js`, 'utf8'), model);

test('legacy settings preserve the visible main surface, then apply to every surface', () => {
  const legacy = { powerbarMainBlur: false, powerbarMainBackgroundOpacity: 13,
    powerbarMainShadow: true, powerbarExtendedShadow: false };
  assert.equal(model.effects(legacy).backgroundOpacity, 1);
  assert.equal(model.effects(legacy).shadow, true);
  legacy.powerbarMainBlur = true;
  assert.equal(model.effects(legacy).backgroundOpacity, .13);
});
test('unified opacity works independently of blur and overrides legacy settings', () => {
  const settings = { powerbarBackgroundOpacity: 35, powerbarBlur: false,
    powerbarMainBlur: true, powerbarShadow: false, powerbarMainShadow: true };
  assert.equal(model.effects(settings).backgroundOpacity, .35);
  assert.equal(model.effects(settings).blur, false);
  assert.equal(model.effects(settings).shadow, false);
});
test('reset removes legacy fallbacks and preserves unrelated preferences', () => {
  const settings = { powerbarShadow: true, powerbarMainShadow: true,
    powerbarExtendedBlur: true, powerbarIslandRounding: 30, position: 'left' };
  model.reset(settings);
  assert.deepEqual(settings, { position: 'left' });
  assert.equal(model.effects(settings).shadow, false);
  assert.equal(model.effects(settings).backgroundOpacity, 1);
});
