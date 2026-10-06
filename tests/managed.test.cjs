const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../ManagedModel.js`, 'utf8'), m);
test('explicit modes win; every discovered widget defaults to shown, old configs keep provenance; discovery defers', () => {
  assert.equal(m.mode({}, null), 'pending');
  assert.equal(m.mode({}, { firstParty: true }), 'shown');
  assert.equal(m.mode({}, { firstParty: false }), 'shown');
  assert.equal(m.mode({}, { firstParty: true }, true), 'shown');
  assert.equal(m.mode({}, { firstParty: false }, true), 'managed');
  assert.equal(m.mode({ powerbarVisibility: 'shown' }, { firstParty: false }, true), 'shown');
  assert.equal(m.mode({ powerbarVisibility: 'hidden' }, { firstParty: true }), 'hidden');
  assert.equal(m.mode({ powerbarVisibility: 'shown' }, { firstParty: false }), 'shown');
});
test('timing defaults, invalid values, and bounds', () => {
  assert.equal(m.seconds(undefined, 10, 60), 10);
  assert.equal(m.seconds(null, 5, 15), 5);
  assert.equal(m.seconds('invalid', 5, 15), 5);
  assert.equal(m.seconds(Infinity, 10, 60), 10);
  assert.equal(m.seconds(-10, 10, 60), 1);
  assert.equal(m.seconds(1000, 10, 60), 60);
});
test('activity extends from the most recent event, never queues intervals', () => {
  let until = m.deadline(0, 10);
  assert.equal(m.remaining(until, 7000), 3000);
  until = m.deadline(7000, 10);
  assert.equal(m.remaining(until, 10000), 7000);
  assert.equal(m.remaining(until, 17000), 0);
  assert.equal(m.remaining(until, 18000), 0);
});
test('hover and interaction suspend dismissal; entry and exit remain distinct', () => {
  assert.equal(m.dismissDelay(true, false, false, false, 5, 7), 0);
  assert.equal(m.dismissDelay(false, true, false, true, 5, 7), 0);
  assert.equal(m.dismissDelay(false, false, true, true, 5, 7), 0);
  assert.equal(m.dismissDelay(false, false, false, false, 5, 7), 5000);
  assert.equal(m.dismissDelay(false, false, false, true, 5, 7), 7000);
});
test('only public presentation values enter the activity snapshot', () => {
  const widget = { text: '4', icon: 'bell', value: 4, width: 20, visible: false, opacity: 0 };
  const first = m.snapshot(widget);
  widget.width = 40; widget.visible = true; widget.opacity = 1;
  assert.equal(m.snapshot(widget), first);
  widget.value = 5;
  assert.notEqual(m.snapshot(widget), first);
  const second = m.snapshot(widget);
  widget.icon = 'alert';
  assert.notEqual(m.snapshot(widget), second);
});
test('groups with member names use a vertical menu surface on every bar edge', () => {
  const name = { memberDisplay: 'name', orientation: 'horizontal' };
  const both = { memberDisplay: 'both', orientation: 'auto' };
  const icons = { memberDisplay: 'native', orientation: 'auto' };
  assert.equal(m.groupMenu(name), true);
  assert.equal(m.groupMenu(both), true);
  assert.equal(m.drawerVertical(name, false), true);
  assert.equal(m.drawerVertical(both, false), true);
  assert.equal(m.drawerSurface(name), 'menu');
  assert.equal(m.drawerSurface(both), 'menu');
  assert.equal(m.groupMenu(icons), false);
  assert.equal(m.drawerVertical(icons, false), false);
  assert.equal(m.drawerVertical(icons, true), true);
  assert.equal(m.drawerVertical({ memberDisplay: 'native', orientation: 'vertical' }, false), false);
  assert.equal(m.drawerVertical({ memberDisplay: 'native', orientation: 'horizontal' }, true), true);
  assert.equal(m.drawerSurface(icons), 'island');
  assert.equal(m.drawerSurface(null), 'island');
});
test('opening a keyboard drawer does not select its first member until navigation', () => {
  assert.equal(m.cursorVisible(true, false, 3), false);
  assert.equal(m.cursorVisible(true, true, 3), true);
  assert.equal(m.cursorVisible(false, true, 3), false);
  assert.equal(m.cursorVisible(true, true, 0), false);
});
test('menu names start after the icon cell, or at the icon edge in rows without an icon', () => {
  assert.equal(m.menuLabelStart(true, 32, 10), 32);
  assert.equal(m.menuLabelStart(false, 32, 10), 10);
});
test('menu width fits its content, at least four cells and at most 320 px', () => {
  assert.equal(m.menuWidth(60, 3, 32), 128);
  assert.equal(m.menuWidth(200, 3, 32), 206);
  assert.equal(m.menuWidth(600, 3, 32), 320);
});
const strip = o => m.placeStrip({ screen: 1512, edge: 4, snap: 16, zone: 'left', ...o }).start;
test('strips centre on the group icon, stay a bar gap from the screen, and snap to the island end', () => {
  assert.equal(strip({ length: 100, source: { start: 300, end: 332 }, island: { start: 4, end: 700 } }), 266);
  // Near the screen's start: clamped to the bar gap, which here is the island's start.
  assert.equal(strip({ length: 100, source: { start: 10, end: 42 }, island: { start: 4, end: 300 } }), 4);
  // Within half a highlight of the island's end: the ends meet.
  assert.equal(strip({ length: 100, source: { start: 230, end: 262 }, island: { start: 4, end: 300 } }), 200);
  // The managed drawer has no source icon: it lines up with the island's outer end.
  assert.equal(strip({ length: 100, source: null, zone: 'right', island: { start: 1200, end: 1508 } }), 1408);
  assert.equal(strip({ length: 100, source: null, zone: 'left', island: { start: 4, end: 400 } }), 4);
});
const menu = o => m.placeMenu({ screen: 1512, edge: 4, snap: 16, zone: 'left', inset: 3, row: 32, ...o });
test('menus start where the group icon starts, flip near the screen end, and sit level beside a vertical bar', () => {
  assert.deepEqual({ ...menu({ length: 150, source: { start: 300, end: 332 } }) }, { start: 297, flipped: false });
  assert.deepEqual({ ...menu({ length: 150, source: { start: 1450, end: 1482 } }) }, { start: 1335, flipped: true });
  // Vertical: the first row's centre is level with the source's centre.
  assert.deepEqual({ ...menu({ vertical: true, length: 110, source: { start: 200, end: 234 } }) }, { start: 198, flipped: false });
  // Near the bottom: the last row is level with it.
  assert.deepEqual({ ...menu({ vertical: true, screen: 300, length: 110, source: { start: 250, end: 284 } }) }, { start: 176, flipped: true });
});
test('clock-driven widgets never count as activity for an autohidden bar', () => {
  assert.equal(m.quietActivity('omarchy.clock'), true);
  assert.equal(m.quietActivity('omarchy.audio'), false);
  assert.equal(m.quietActivity(undefined), false);
});
test('widgets peek an autohidden bar unless clock-driven or opted out', () => {
  assert.equal(m.peeksOnActivity({ id: 'omarchy.audio' }, 'omarchy.audio'), true);
  assert.equal(m.peeksOnActivity({ id: 'omarchy.audio', powerbarActivityPeek: false }, 'omarchy.audio'), false);
  assert.equal(m.peeksOnActivity({ id: 'omarchy.clock' }, 'omarchy.clock'), false);
  assert.equal(m.peeksOnActivity(null, 'omarchy.audio'), true);
});

test('Enter in a drawer opened without a cursor shows the cursor before it presses anything', () => {
  assert.equal(m.pressAction(true, false, 3), 'select');
  assert.equal(m.pressAction(true, true, 3), 'activate');
  assert.equal(m.pressAction(true, false, 0), 'none');
});
