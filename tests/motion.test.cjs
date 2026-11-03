const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const load = require('./load.cjs');
const motion = load('MotionModel.js');

test('Preferences motion stays under 300 ms', () => {
  const durations = ['PAGE_TURN_MS', 'GLIDE_MS', 'GLIDE_END_MS', 'PLATE_MS', 'APPEAR_MS',
    'APPEAR_SCALE_MS', 'SNAP_BACK_MS', 'FILL_MS', 'TIP_FADE_MS', 'LANDING_SETTLE_MS'];
  for (const name of durations) {
    assert.ok(motion[name] > 0 && motion[name] < 300, name + ' = ' + motion[name]);
  }
});

test('the page turn uses Omarchy\'s ease out', (t) => {
  const style = path.join(process.env.OMARCHY_PATH || '/usr/share/omarchy', 'shell/Commons/Style.qml');
  if (!fs.existsSync(style)) return t.skip('no Omarchy install');
  const found = fs.readFileSync(style, 'utf8').match(/property var easeOut: \[([^\]]*)\]/);
  assert.ok(found, 'Style.easeOut not found');
  assert.deepEqual(found[1].split(',').map(Number), motion.EASE_OUT);
});

// `hyprctl -j animations`: [leaves, curves]. A leaf not overridden takes its
// parent's values (fadeLayersIn -> fadeLayers -> fade -> global).
const leaf = (name, overridden, speed, bezier, enabled = true) => ({ name, overridden, speed, bezier, enabled, style: '' });
const curves = [{ name: 'almostLinear', X0: 0.5, Y0: 0.5, X1: 0.75, Y1: 1 }, { name: 'quick', X0: 0.15, Y0: 0, X1: 0.1, Y1: 1 },
  { name: 'default', X0: 0, Y0: 0.75, X1: 0.15, Y1: 1 }];
const omarchy = [[leaf('global', true, 8, 'default'), leaf('fade', true, 2.42, 'quick'), leaf('fadeLayers', false, 0, ''),
  leaf('fadeLayersIn', true, 1.43, 'almostLinear'), leaf('fadeLayersOut', true, 1.11, 'almostLinear')], curves];

test('the key legend fades as Hyprland fades layers in and out', () => {
  assert.deepEqual(motion.layerFade(omarchy, true), { ms: 143, curve: [0.5, 0.5, 0.75, 1, 1, 1] });
  assert.deepEqual(motion.layerFade(omarchy, false), { ms: 111, curve: [0.5, 0.5, 0.75, 1, 1, 1] });
});

test('a layer fade left untuned takes its parent\'s', () => {
  const untuned = [[leaf('global', true, 8, 'default'), leaf('fade', true, 2.42, 'quick'), leaf('fadeLayers', false, 0, ''),
    leaf('fadeLayersIn', false, 0, ''), leaf('fadeLayersOut', false, 0, '')], curves];
  assert.deepEqual(motion.layerFade(untuned, true), { ms: 242, curve: [0.15, 0, 0.1, 1, 1, 1] });
  const layersTuned = [[leaf('fade', true, 2.42, 'quick'), leaf('fadeLayers', true, 0.6, 'almostLinear'),
    leaf('fadeLayersIn', false, 0, ''), leaf('fadeLayersOut', true, 0.46, 'almostLinear')], curves];
  assert.equal(motion.layerFade(layersTuned, true).ms, 60);
  assert.equal(motion.layerFade(layersTuned, false).ms, 46);
});

test('a layer fade switched off shows and hides the legend at once', () => {
  const off = [[leaf('fade', true, 2.42, 'quick'), leaf('fadeLayersIn', true, 1.43, 'almostLinear', false)], curves];
  assert.equal(motion.layerFade(off, true).ms, 0);
});

test('without a readable report the legend keeps Omarchy\'s default fade', () => {
  for (const report of [null, '', {}, [[], []], [[leaf('fadeLayersOut', true, 1.11, 'almostLinear')], curves]]) {
    const fade = motion.layerFade(report, true);
    assert.equal(fade.ms, motion.keyStripMs(true), JSON.stringify(report));
  }
  assert.equal(motion.layerFade(null, false).ms, motion.keyStripMs(false));
  assert.deepEqual(motion.layerFade(null, true).curve, motion.KEY_STRIP_CURVE);
});

test('a curve Hyprland does not list keeps the speed and the legend\'s own curve', () => {
  assert.deepEqual(motion.layerFade([[leaf('fadeLayersIn', true, 1.43, 'nope')], curves], true),
    { ms: 143, curve: motion.KEY_STRIP_CURVE });
});
