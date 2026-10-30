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
