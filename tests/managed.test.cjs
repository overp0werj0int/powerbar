const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../ManagedModel.js`, 'utf8'), m);
test('explicit modes win; defaults use registry provenance and defer discovery', () => {
  assert.equal(m.mode({}, null), 'pending');
  assert.equal(m.mode({}, { firstParty: true }), 'shown');
  assert.equal(m.mode({}, { firstParty: false }), 'managed');
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
test('combined menu labels sit close to the icon while name-only rows retain an inset', () => {
  assert.equal(m.menuLabelStart(true, 26, 8, 2), 28);
  assert.equal(m.menuLabelStart(false, 26, 8, 2), 8);
});
