const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const J = v => JSON.parse(JSON.stringify(v));
const zm = load('ZoneModeModel.js');

const w = (id, extra) => Object.assign({ id, powerbarInstance: `k-${id}` }, extra || {});
const ids = list => J(list.map(e => e.id));
function stock() {
  return {
    centerAnchor: 'omarchy.clock',
    layout: {
      left: [w('omarchy.workspaces'), w('omarchy.ai')],
      center: [w('omarchy.microphone'), w('omarchy.indicators'), w('omarchy.clock', { format: 'HH:mm' }),
        w('omarchy.keyboard-layout'), w('omarchy.weather')],
      right: [w('omarchy.tray'), w('omarchy.audio'), w('omarchy.power')]
    }
  };
}

test('three zones unless a known mode is set', () => {
  assert.equal(zm.modeOf({}), 'three');
  assert.equal(zm.modeOf({ powerbarZones: 'two' }), 'two');
  assert.equal(zm.modeOf({ powerbarZones: 'sideways' }), 'three');
});

test('the first two-zone layout splits the centre at the clock; keyboard layout and clock end the right zone', () => {
  const bar = stock();
  assert.equal(zm.switchMode(bar, 'two'), true);
  assert.equal(bar.powerbarZones, 'two');
  assert.deepEqual(ids(bar.layout.left), ['omarchy.workspaces', 'omarchy.ai', 'omarchy.microphone', 'omarchy.indicators']);
  assert.deepEqual(ids(bar.layout.center), []);
  assert.deepEqual(ids(bar.layout.right), ['omarchy.weather', 'omarchy.tray', 'omarchy.audio', 'omarchy.power', 'omarchy.keyboard-layout', 'omarchy.clock']);
  assert.equal(bar.layout.right[5].format, 'HH:mm', 'settings travel with the widget');
  assert.deepEqual(ids(bar.powerbarZoneLayouts.three.layout.center), ids(stock().layout.center), 'the three-zone layout waits');
  assert.equal(bar.centerAnchor, 'omarchy.clock', 'kept for three zones');
});

test('each mode keeps its own arrangement and visibility; settings are shared', () => {
  const bar = stock();
  zm.switchMode(bar, 'two');
  // Rearranged in two zones: the clock to the left, weather hidden.
  const clock = bar.layout.right.pop();
  bar.layout.left.unshift(clock);
  bar.layout.right[0].powerbarVisibility = 'hidden';
  zm.switchMode(bar, 'three');
  assert.equal(bar.powerbarZones, undefined);
  assert.deepEqual(J(bar.layout), J(stock().layout), 'three zones as it was');
  // A setting changed in three zones reaches two zones.
  bar.layout.center[2].format = 'HH:mm:ss';
  zm.switchMode(bar, 'two');
  assert.equal(bar.layout.left[0].id, 'omarchy.clock');
  assert.equal(bar.layout.left[0].format, 'HH:mm:ss');
  assert.equal(bar.layout.right[0].powerbarVisibility, 'hidden');
  zm.switchMode(bar, 'three');
  assert.equal(bar.layout.center[4].powerbarVisibility, undefined, 'hidden only in two zones');
});

test('notch and two zones are separate layouts', () => {
  const bar = stock();
  zm.switchMode(bar, 'two');
  bar.layout.left.reverse();
  zm.switchMode(bar, 'notch');
  assert.equal(bar.powerbarZones, 'notch');
  assert.deepEqual(ids(bar.layout.left), ['omarchy.workspaces', 'omarchy.ai', 'omarchy.microphone', 'omarchy.indicators'], 'made from three zones, not two');
  assert.ok(bar.powerbarZoneLayouts.two && bar.powerbarZoneLayouts.three);
  assert.equal(zm.switchMode(bar, 'notch'), false);
});

test('a widget added while another mode was in use joins at the far end', () => {
  const bar = stock();
  zm.switchMode(bar, 'notch');
  zm.switchMode(bar, 'three');
  bar.layout.left.push(w('x.new-left'));
  bar.layout.center.push(w('x.new-centre'));
  zm.switchMode(bar, 'notch');
  assert.equal(bar.layout.left[0].id, 'x.new-left', 'the notch grows outward: the left zone starts at the screen edge');
  assert.equal(bar.layout.right[bar.layout.right.length - 1].id, 'x.new-centre');
  zm.switchMode(bar, 'two');
  assert.deepEqual(ids(bar.layout.left), ['omarchy.workspaces', 'omarchy.ai', 'x.new-left', 'omarchy.microphone', 'omarchy.indicators'],
    'a first two-zone layout is made from three zones, where it already sits');
});

test('a widget removed meanwhile is gone from every layout it returns to', () => {
  const bar = stock();
  zm.switchMode(bar, 'two');
  zm.switchMode(bar, 'three');
  bar.layout.right = bar.layout.right.filter(e => e.id !== 'omarchy.audio');
  zm.switchMode(bar, 'two');
  assert.ok(!bar.layout.right.some(e => e.id === 'omarchy.audio'));
});

test('groups keep a place per mode and follow their widget into two zones', () => {
  const bar = stock();
  bar.powerbarGroups = [
    { id: 'g1', label: 'Before clock', section: 'center', before: 'k-omarchy.clock', items: [] },
    { id: 'g2', label: 'Centre end', section: 'center', before: '', items: [] },
    { id: 'g3', label: 'Right end', section: 'right', before: '', items: [], visibility: 'managed' },
    { id: 'g4', label: 'Before mic', section: 'center', before: 'k-omarchy.microphone', items: [] }
  ];
  zm.switchMode(bar, 'two');
  const g = id => J(bar.powerbarGroups.find(x => x.id === id));
  assert.deepEqual([g('g1').section, g('g1').before], ['left', '']);
  assert.deepEqual([g('g2').section, g('g2').before], ['right', 'k-omarchy.tray']);
  assert.deepEqual([g('g3').section, g('g3').before, g('g3').visibility], ['right', 'k-omarchy.keyboard-layout', 'managed']);
  assert.deepEqual([g('g4').section, g('g4').before], ['left', 'k-omarchy.microphone']);
  bar.powerbarGroups[0].label = 'Renamed';
  bar.powerbarGroups[0].visibility = 'hidden';
  zm.switchMode(bar, 'three');
  assert.deepEqual([g('g1').section, g('g1').before, g('g1').label, g('g1').visibility], ['center', 'k-omarchy.clock', 'Renamed', undefined]);
});

test('Omarchy adding a widget in a two-zone mode: a centre one joins the right, a new left one the far end on the notch', () => {
  const bar = stock();
  zm.switchMode(bar, 'notch');
  bar.layout.center.push({ id: 'x.c' });
  bar.layout.left.push({ id: 'x.l' });
  assert.equal(zm.settleNew(bar, e => !e.powerbarInstance), true);
  assert.equal(bar.layout.left[0].id, 'x.l');
  assert.equal(bar.layout.right[bar.layout.right.length - 1].id, 'x.c');
  assert.deepEqual(J(bar.layout.center), []);
  assert.equal(zm.settleNew(bar, e => !e.powerbarInstance), false, 'nothing left to move');
  const three = stock();
  three.layout.center.push({ id: 'x.c' });
  assert.equal(zm.settleNew(three, () => true), false, 'three zones keep Omarchy\'s place');
});
