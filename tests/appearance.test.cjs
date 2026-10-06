const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const J = v => JSON.parse(JSON.stringify(v));
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
test('surfaces over windows keep a readable opacity unless blurred or opted out', () => {
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.5 }), 0.88);
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.95 }), 0.95);
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.5, blur: true }), 0.5);
  assert.equal(model.overlayOpacity({ backgroundOpacity: 0.5, readableOverlay: false }), 0.5);
  assert.equal(model.effects({ powerbarReadableOverlay: false }).readableOverlay, false);
  assert.equal(model.effects({}).readableOverlay, true);
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

test('text and icons: the theme by default, or the theme\'s own light or dark colour', () => {
  assert.equal(model.foreground({}, 'osaka-jade'), 'theme');
  assert.equal(model.foreground({ powerbarForeground: { 'osaka-jade': 'dark' } }, 'osaka-jade'), 'dark');
  assert.equal(model.foreground({ powerbarForeground: { 'osaka-jade': 'purple' } }, 'osaka-jade'), 'theme');
  const text = { r: 0.9, g: 0.9, b: 0.85 }, bg = { r: 0.1, g: 0.1, b: 0.12 };
  assert.deepEqual(JSON.parse(JSON.stringify(model.textPair(text, bg))), { light: text, dark: bg });
  // A light theme's pair sorts the other way round.
  assert.deepEqual(JSON.parse(JSON.stringify(model.textPair(bg, text))), { light: text, dark: bg });
});

test('text and icons: a choice from before per-theme choices applies nowhere', () => {
  const legacy = { powerbarForeground: 'dark' };
  assert.equal(model.foreground(legacy, 'osaka-jade'), 'theme');
  assert.equal(model.foreground(legacy, ''), 'theme');
  // Migration drops it rather than guess a theme for it.
  assert.deepEqual(J(model.fromLegacy(legacy)), {});
  // An unknown theme cannot hold a choice.
  const none = {};
  model.setText(none, '', 'dark');
  assert.equal(none.powerbarAppearance, undefined);
});

// ---- Appearance scopes -------------------------------------------------------
const user = { powerbarBackgroundOpacity: 100, powerbarBlur: false, powerbarExtendedBackgroundOpacity: 95,
  powerbarExtendedShadow: true, powerbarIslandBorderWidth: 0.5, powerbarIslandBorders: false, powerbarIslandRounding: 8,
  powerbarMainBackgroundOpacity: 13, powerbarMainShadow: true, powerbarReadableOverlay: true, powerbarShadowOpacity: 25,
  powerbarShadowSize: 4, powerbarForeground: { 'quattrocento-light': 'dark' }, position: 'right' };

test('migration moves flat keys into the shared set, so the bar looks the same', () => {
  const bar = J(user);
  const before = J(model.effects(bar));
  assert.equal(model.migrate(bar), true);
  assert.deepEqual(J(bar), { powerbarReadableOverlay: true, position: 'right', powerbarAppearance: {
    all: { shape: { rounding: 8, borders: false, borderWidth: 0.5 }, surface: { opacity: 100, blur: false },
      shadow: { enabled: true, softness: 4, strength: 25 } },
    themes: { 'quattrocento-light': { text: 'dark' } } } });
  assert.deepEqual(J(model.effects(model.flatten(bar, 'waffle-cat', {}))), before, 'same effects before and after');
  assert.equal(model.migrate(bar), false, 'once');
  // Before migrate() writes it, the bar reads the same values from the flat keys.
  assert.deepEqual(J(model.appearanceOf(J(user))), J(bar.powerbarAppearance));
});

test('a tile follows the theme by default, the shared set once it has values, and a theme its own choice', () => {
  assert.equal(model.scopeOf({}, 'nord', 'shape'), 'theme');
  const a = { all: { shape: { rounding: 8 } }, themes: { nord: { shape: { use: 'theme' } }, rose: { surface: { use: 'this' } } } };
  assert.equal(model.scopeOf(a, 'lumon', 'shape'), 'all');
  assert.equal(model.scopeOf(a, 'lumon', 'surface'), 'theme');
  assert.equal(model.scopeOf(a, 'nord', 'shape'), 'theme', 'opted out');
  assert.equal(model.scopeOf(a, 'rose', 'surface'), 'this');
});

test('values fall through this theme, the shared set and the theme file, key by key', () => {
  const a = { all: { shape: { rounding: 8, borders: false } }, themes: { rose: { shape: { use: 'this', rounding: 12 } } } };
  const look = { shape: { rounding: 4, borderWidth: 2 } };
  const r = model.resolve(a, 'rose', look);
  assert.deepEqual(J(r.values), { rounding: 12, borders: false, borderWidth: 2 });
  assert.deepEqual([r.from.rounding, r.from.borders, r.from.borderWidth, r.from.opacity], ['this', 'all', 'file', '']);
  const t = model.resolve({ themes: { rose: { shape: { use: 'theme' } } }, all: { shape: { rounding: 8 } } }, 'rose', look);
  assert.deepEqual(J(t.values), { rounding: 4, borderWidth: 2 }, 'theme: only the file, then Omarchy');
  assert.equal(t.look.shape, true);
  assert.equal(t.look.shadow, false);
});

test('changes go to the scope the tile follows; on the theme they go nowhere', () => {
  const bar = {};
  model.setValue(bar, 'nord', 'shape', 'rounding', 9);
  assert.equal(bar.powerbarAppearance, undefined, 'theme: controls are off');
  model.setScope(bar, 'nord', 'shape', 'all');
  model.setValue(bar, 'nord', 'shape', 'rounding', 9);
  assert.deepEqual(J(bar.powerbarAppearance), { all: { shape: { rounding: 9 } } }, 'the default needs no record');
  assert.equal(model.scopeOf(bar.powerbarAppearance, 'lumon', 'shape'), 'all', 'other themes share it');
  model.setScope(bar, 'nord', 'shape', 'this');
  model.setValue(bar, 'nord', 'shape', 'rounding', 3);
  assert.deepEqual(J(bar.powerbarAppearance.themes), { nord: { shape: { use: 'this', rounding: 3 } } });
  assert.equal(model.resolve(bar.powerbarAppearance, 'lumon', {}).values.rounding, 9);
  assert.equal(model.resolve(bar.powerbarAppearance, 'nord', {}).values.rounding, 3);
});

test('switching scope keeps every stored value, and switching back brings it back', () => {
  const bar = { powerbarAppearance: { all: { surface: { opacity: 70 } }, themes: { nord: { surface: { use: 'this', opacity: 40 } } } } };
  model.setScope(bar, 'nord', 'surface', 'theme');
  assert.equal(model.resolve(bar.powerbarAppearance, 'nord', {}).values.opacity, undefined);
  model.setScope(bar, 'nord', 'surface', 'all');
  assert.equal(model.resolve(bar.powerbarAppearance, 'nord', {}).values.opacity, 70);
  model.setScope(bar, 'nord', 'surface', 'this');
  assert.equal(model.resolve(bar.powerbarAppearance, 'nord', {}).values.opacity, 40);
});

test('text and icons stay per theme, even when Surface is shared', () => {
  const bar = { powerbarAppearance: { all: { surface: { opacity: 80 } } } };
  model.setText(bar, 'latte', 'dark');
  assert.equal(model.resolve(bar.powerbarAppearance, 'latte', {}).text, 'dark');
  assert.equal(model.resolve(bar.powerbarAppearance, 'nord', {}).text, 'theme');
  assert.equal(model.resolve(bar.powerbarAppearance, 'nord', { surface: { text: 'light' } }).text, 'light', "the theme file's suggestion");
  assert.equal(model.foreground(model.flatten(bar, 'latte', {}), 'latte'), 'dark');
  model.setText(bar, 'latte', 'theme');
  assert.deepEqual(J(bar.powerbarAppearance), { all: { surface: { opacity: 80 } } });
});

test("a theme's powerbar.toml: known keys, typed values, comments", () => {
  const look = model.parseLook(`# Powerbar for waffle-cat
[shape]
rounding = 12   # stored units
border-width = 1.5
borders = true
[surface]
opacity = 85
text = "dark"
blur = maybe
[shadow]
enabled = false
colour = "red"
[launcher]
rounding = 3`);
  assert.deepEqual(J(look), { shape: { rounding: 12, borderWidth: 1.5, borders: true }, surface: { opacity: 85, text: 'dark' }, shadow: { enabled: false } });
  assert.deepEqual(J(model.parseLook('')), {});
});

test("with no opacity set, the bar takes the theme's own background alpha", () => {
  assert.equal(model.effects({}, 0.86).backgroundOpacity, 0.86);
  assert.equal(model.effects({ powerbarBackgroundOpacity: 40 }, 0.86).backgroundOpacity, 0.4);
  assert.equal(model.effects({}).backgroundOpacity, 1);
});

test('themes no longer installed lose what was kept for them', () => {
  const bar = { powerbarAppearance: { all: { shape: { rounding: 8 } }, themes: { gone: { text: 'dark' }, nord: { text: 'light' } } } };
  assert.equal(model.hasStaleThemes(bar, ['nord', 'lumon']), true);
  assert.equal(model.pruneThemes(bar, ['nord', 'lumon']), true);
  assert.equal(model.hasStaleThemes(bar, ['nord', 'lumon']), false);
  assert.deepEqual(J(bar.powerbarAppearance.themes), { nord: { text: 'light' } });
  assert.equal(model.pruneThemes(bar, []), false, 'an empty list proves nothing');
});
