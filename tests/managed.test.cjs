const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../ManagedModel.js`, 'utf8'), m);
const J = v => JSON.parse(JSON.stringify(v));
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
  // Hovering the rest of the bar keeps no hover drawer.
  assert.equal(m.dismissDelay(false, false, false, false, 5, 7, false, true), 5000);
});
test('a drawer pinned by a click stays while the pointer is on the bar and goes after the exit grace once it has left', () => {
  // The pointer anywhere on the bar, the source or the drawer: no timer.
  assert.equal(m.dismissDelay(false, false, false, false, 5, 7, true, true), 0);
  assert.equal(m.dismissDelay(true, false, false, false, 5, 7, true, false), 0);
  assert.equal(m.dismissDelay(false, true, false, true, 5, 7, true, false), 0);
  // Left the bar and the drawer: the exit grace, whether it was entered or not.
  assert.equal(m.dismissDelay(false, false, false, false, 5, 7, true, false), 7000);
  assert.equal(m.dismissDelay(false, false, false, true, 5, 7, true, false), 7000);
  // Held (driven by keys, a panel open, a drag): no timer.
  assert.equal(m.dismissDelay(false, false, true, true, 5, 7, true, false), 0);
  assert.equal(m.dismissDelay(false, false, true, true, 5, 7, false, false), 0);
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
  const name = { memberDisplay: 'name' };
  const both = { memberDisplay: 'both' };
  const icons = { memberDisplay: 'native' };
  assert.equal(m.groupMenu(name), true);
  assert.equal(m.groupMenu(both), true);
  assert.equal(m.drawerVertical(name, false), true);
  assert.equal(m.drawerVertical(both, false), true);
  assert.equal(m.drawerSurface(name), 'menu');
  assert.equal(m.drawerSurface(both), 'menu');
  assert.equal(m.groupMenu(icons), false);
  assert.equal(m.drawerVertical(icons, false), false);
  assert.equal(m.drawerVertical(icons, true), true);
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

test('a hover-opened drawer gives way when the pointer lands on another stop along the bar', () => {
  // A group's drawer: any stop but its own icon closes it.
  assert.equal(m.closesForStop(true, false, false, 'g1', 'right', { groupId: '', region: 'right' }), true);
  assert.equal(m.closesForStop(true, false, false, 'g1', 'right', { groupId: 'g2', region: 'right' }), true);
  assert.equal(m.closesForStop(true, false, false, 'g1', 'right', { groupId: 'g1', region: 'right' }), false);
  // A zone's drawer: its own zone is its source.
  assert.equal(m.closesForStop(true, false, false, '', 'right', { groupId: '', region: 'right' }), false);
  assert.equal(m.closesForStop(true, false, false, '', 'right', { groupId: '', region: 'left' }), true);
  // A zone's menu: its dots are its source, so any stop closes it.
  assert.equal(m.closesForStop(true, false, false, '', 'right', { groupId: '', region: 'right' }, true), true);
  assert.equal(m.closesForStop(true, true, false, '', 'right', { groupId: '', region: 'right' }, true), false);
  // Pinned or keyboard drawers, a panel open or a drag: they stay.
  assert.equal(m.closesForStop(true, true, false, 'g1', 'right', { groupId: '', region: 'right' }), false);
  assert.equal(m.closesForStop(true, false, true, 'g1', 'right', { groupId: '', region: 'right' }), false);
  assert.equal(m.closesForStop(false, false, false, 'g1', 'right', { groupId: '', region: 'right' }), false);
});

test('a menu row shows a glyph, or a picture that fits the icon cell, in its icon cell', () => {
  assert.equal(m.menuIcon(true, false, 12, 30), true, 'a glyph');
  // Reprieve's mark: an 18 px image, past a glyph's 16 px.
  assert.equal(m.menuIcon(false, true, 18, 30), true, 'a picture that fits');
  assert.equal(m.menuIcon(false, true, 48, 30), false, 'a row of pictures is a value');
  assert.equal(m.menuIcon(false, false, 18, 30), false, 'text is a value');
  assert.equal(m.menuIcon(false, true, 0, 30), false, 'nothing painted');
});

test("a kit button's text that leads with an icon splits into the icon and the rest", () => {
  assert.deepEqual(J(m.iconLead('\u{f0238} 14')), { icon: '\u{f0238}', rest: '14' }, "Crash Desk's count");
  assert.deepEqual(J(m.iconLead('\ue0b0  3 new ')), { icon: '\ue0b0', rest: '3 new' });
  assert.equal(m.iconLead('\u{f0238}'), null, 'a bare icon');
  assert.equal(m.iconLead('\u{f0238}14'), null, 'no space after the icon');
  assert.equal(m.iconLead('100% \u{f0079}'), null, 'a value that ends in an icon');
  assert.equal(m.iconLead('\u{f0238} 1\n2'), null, 'several lines');
  assert.equal(m.iconLead(''), null);
  assert.equal(m.countText(['3']), '3', "omabox's box count");
  assert.equal(m.countText([' 12 ', 'omabox']), '12', 'the one number among texts');
  assert.equal(m.countText(['99+']), '99+');
  assert.equal(m.countText(['1234']), '', 'too long for a count');
  assert.equal(m.countText(['3', '4']), '', 'two counts: neither');
  assert.equal(m.countText(['3 new', '']), '', 'not a bare number');
  assert.equal(m.countText([]), '');
  assert.equal(m.countText(undefined), '');
  assert.equal(m.countIconShift(48 / 2 + 8 + 4, 4, 16, 48), 0, 'icon centred alone, count after it');
  assert.equal(m.countIconShift(48 / 2 + 8 - 6 + 4, 4, 16, 48), -6, 'icon and count centred together');
});

test('a menu row: text widgets show a value at its end; the widest row sets the width', () => {
  assert.equal(m.menuValueWidth(true, false, 50, 40), 40, 'text, capped');
  assert.equal(m.menuValueWidth(true, true, 50, 40), 0, 'a glyph has no value');
  assert.equal(m.menuValueWidth(false, false, 50, 40), 0, 'without icons');
  const tokens = { air: 4, inset: 6, cell: 30 };
  // Rows of 30+60+4 = 94 and 4+40+(4+20)+4 = 72: the widest is 94, which
  // menuWidth raises to four cells (120); less the insets, 108.
  assert.equal(m.menuRowWidth([{ labelStart: 30, title: 60, value: 0 }, { labelStart: 4, title: 40, value: 20 }], tokens), 108);
  assert.equal(m.menuRowWidth([{ labelStart: 30, title: 300, value: 0 }], tokens), 320 - 12, 'at most 320 with the insets');
  assert.equal(m.menuRowWidth([], tokens), 120 - 12, 'an empty menu is four cells wide');
});

test('a submenu opens beside its row, on the side with room', () => {
  const base = { menu: { x: 100, y: 40, width: 200, height: 300 }, row: { y: 120, height: 30 }, width: 180, height: 90,
    screen: { width: 1500, height: 400 }, edge: 6, inset: 4 };
  // Below a top bar: after the menu, its first row level with the group's.
  assert.deepEqual(JSON.parse(JSON.stringify(m.placeSubmenu({ ...base, position: 'top' }))), { x: 304, y: 116, before: false });
  // No room after it (a right zone's menu): before it.
  const right = { ...base, menu: { x: 1300, y: 40, width: 194, height: 300 }, position: 'top' };
  assert.deepEqual(JSON.parse(JSON.stringify(m.placeSubmenu(right))), { x: 1116, y: 116, before: true });
  // Above a bottom bar: its last row level with the group's.
  assert.equal(m.placeSubmenu({ ...base, position: 'bottom' }).y, 64);
  // Beside a side bar: away from the bar, whatever the room.
  assert.equal(m.placeSubmenu({ ...base, position: 'left' }).x, 304);
  assert.equal(m.placeSubmenu({ ...base, menu: { x: 400, y: 40, width: 200, height: 300 }, position: 'right' }).x, 216);
  // Kept on screen: a row near the bottom pulls it up.
  assert.equal(m.placeSubmenu({ ...base, row: { y: 350, height: 30 }, position: 'top' }).y, 304);
});
