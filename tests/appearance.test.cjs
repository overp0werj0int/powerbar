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
test('surfaces over windows keep a readable opacity unless blurred or opted out', () => {
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.5 }), 0.88);
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.95 }), 0.95);
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.5, blur: true }), 0.5);
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.5, readableOverlay: false }), 0.5);
  assert.equal(model.effects({ powerbarReadableOverlay: false }).readableOverlay, false);
  assert.equal(model.effects({}).readableOverlay, true);
  const bar = { powerbarReadableOverlay: false, keep: 1 };
  model.reset(bar);
  assert.deepEqual({ ...bar }, { keep: 1 });
});
test('stored values clamp to the ranges the sliders offer', () => {
  const e = model.effects({ powerbarShadow: true, powerbarShadowSize: 0, powerbarShadowOpacity: 0,
    powerbarBackgroundOpacity: 140 });
  assert.equal(e.shadowSize, 2);
  assert.equal(e.shadowOpacity, 0.05);
  assert.equal(e.backgroundOpacity, 1);
  assert.equal(model.effects({}).shadowSize, 16);
  assert.equal(model.effects({}).shadowOpacity, 0.3);
  assert.equal(model.clampTo(model.ranges.spacing, 24), 16);
  assert.equal(model.clampTo(model.ranges.borderWidth, 0), 0.5);
  assert.equal(model.clampTo(model.ranges.borderWidth, undefined), 1);
  assert.equal(model.clampTo(model.ranges.rounding, 400), 400, 'rounding has no fixed top');
});
test('rounding tops out at a full pill for the bar thickness', () => {
  assert.equal(model.roundingMax(38, 1), 19);
  assert.equal(model.roundingMax(26, 1), 13);
  assert.equal(model.roundingMax(27, 1), 14, 'odd sizes round up so the pill is reachable');
  assert.equal(model.roundingMax(42, 1.25), 17);
  assert.equal(model.roundingMax(0, 1), 1);
});

test('each tile resets only its own settings, and knows when it differs from the theme', () => {
  const bar = { powerbarIslandRounding: 6, powerbarIslandBorders: false, powerbarBlur: true,
    powerbarMainBackgroundOpacity: 40, powerbarShadow: true, powerbarExtendedShadowSize: 9, powerbarSpacing: 4 };
  assert.equal(model.customized(bar, 'shape'), true);
  assert.equal(model.customized(bar, 'surface'), true);
  assert.equal(model.customized(bar, 'shadow'), true);
  model.reset(bar, 'shadow');
  assert.equal(model.customized(bar, 'shadow'), false);
  assert.equal(bar.powerbarBlur, true);
  model.reset(bar, 'surface');
  assert.equal(model.customized(bar, 'surface'), false);
  assert.equal(bar.powerbarIslandRounding, 6);
  model.reset(bar, 'shape');
  assert.deepEqual(JSON.parse(JSON.stringify(bar)), { powerbarSpacing: 4 });
  assert.equal(model.customized({}, 'shape'), false);
  assert.equal(model.customized(undefined, 'surface'), false);
});

test('text and icons: the theme by default, or the theme\'s own light or dark colour', () => {
  assert.equal(model.foreground({}), 'theme');
  assert.equal(model.foreground({ powerbarForeground: 'dark' }), 'dark');
  assert.equal(model.foreground({ powerbarForeground: 'purple' }), 'theme');
  const text = { r: 0.9, g: 0.9, b: 0.85 }, bg = { r: 0.1, g: 0.1, b: 0.12 };
  assert.deepEqual(JSON.parse(JSON.stringify(model.textPair(text, bg))), { light: text, dark: bg });
  // A light theme's pair sorts the other way round.
  assert.deepEqual(JSON.parse(JSON.stringify(model.textPair(bg, text))), { light: text, dark: bg });
  // Surface reset clears the choice.
  const bar = { powerbarForeground: 'light' };
  assert.equal(model.customized(bar, 'surface'), true);
  model.reset(bar, 'surface');
  assert.equal(bar.powerbarForeground, undefined);
});
