const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const J = v => JSON.parse(JSON.stringify(v));
const m = load('TrayItemsModel.js');
const PASSIVE = 0;

const slack = { id: 'chrome_status_icon_1', title: 'Slack', tooltipTitle: '', status: 1 };
const nm = { id: 'nm-applet', title: 'Network', tooltipTitle: 'Wired', status: 1 };
const config = () => ({ bar: { layout: {
  left: [{ id: 'omarchy.menu', powerbarInstance: 'a' }],
  center: [],
  right: ['omarchy.tray', { id: 'omarchy.audio', powerbarInstance: 'b' }]
} } });

test('moving an icon out adds its entry and hides it in the tray, in one write', () => {
  const c = config();
  const entry = m.moveOut(c, slack, 'right', 'managed', 'b', 'k1');
  assert.deepEqual(J(entry), { id: 'powerbar.tray.chrome_status_icon_1', type: 'trayItem', item: 'chrome_status_icon_1',
    title: 'Slack', powerbarVisibility: 'managed', powerbarInstance: 'k1' });
  assert.deepEqual(J(c.bar.layout.right).map(e => e.id), ['omarchy.tray', 'powerbar.tray.chrome_status_icon_1', 'omarchy.audio']);
  assert.deepEqual(J(c.bar.layout.right[0]), { id: 'omarchy.tray', hidden: ['chrome_status_icon_1'] });
  assert.equal(m.moveOut(c, slack, 'left', 'shown', '', 'k2'), null, 'an icon moves out once');
});

test('moving it back removes the entry and shows it in the tray again', () => {
  const c = config();
  m.moveOut(c, slack, 'left', 'shown', '', 'k1');
  assert.equal(m.moveBack(c, 'k1'), true);
  assert.deepEqual(J(c.bar.layout.left).map(e => e.id), ['omarchy.menu']);
  assert.deepEqual(J(c.bar.layout.right[0]).hidden, []);
  assert.equal(m.moveBack(c, 'k1'), false);
});

test('an icon the tray already hid stays hidden there when it comes back', () => {
  const c = config();
  c.bar.layout.right[0] = { id: 'omarchy.tray', hidden: ['nm-applet'], pinned: [] };
  const entry = m.moveOut(c, nm, 'left', 'managed', '', 'k1');
  assert.equal(entry.trayHidden, true);
  m.moveBack(c, 'k1');
  assert.deepEqual(J(c.bar.layout.right[0].hidden), ['nm-applet']);
});

test('a pinned icon is unpinned as it leaves', () => {
  const c = config();
  c.bar.layout.right[0] = { id: 'omarchy.tray', pinned: ['nm-applet', 'x'] };
  m.moveOut(c, nm, 'left', 'shown', '', 'k1');
  assert.deepEqual(J(c.bar.layout.right[0]), { id: 'omarchy.tray', pinned: ['x'], hidden: ['nm-applet'] });
});

test('the tray rows leave out moved, passive and Omarchy-owned icons', () => {
  const c = config();
  m.moveOut(c, slack, 'left', 'shown', '', 'k1');
  const passive = { id: 'idle', title: 'Idle', status: PASSIVE };
  const localsend = { id: 'ls-123', title: 'LocalSend', status: 1 };
  const rows = m.trayRows([slack, nm, passive, localsend], c.bar.layout, PASSIVE);
  assert.deepEqual(J(rows), [{ id: 'powerbar.tray.nm-applet', trayItem: 'nm-applet', trayTitle: 'Wired',
    instanceKey: 'tray:nm-applet', section: 'tray', mode: 'tray', index: 0, fingerprint: 'tray:nm-applet' }]);
});

test('an app with a new tray id each launch is found by its name', () => {
  const settings = { item: 'chrome_status_icon_1', title: 'Slack' };
  const relaunched = { id: 'chrome_status_icon_7', title: 'Slack', status: 1 };
  assert.equal(m.find([nm, relaunched], settings), relaunched);
  assert.equal(m.find([nm], settings), null);
  assert.equal(m.find([relaunched, slack], settings), slack, 'the id wins over the name');
});

test('entry ids keep only safe characters', () => {
  assert.equal(m.entryIdFor('Telegram Desktop'), 'powerbar.tray.Telegram-Desktop');
  assert.equal(m.entryIdFor('../x'), 'powerbar.tray.x');
  assert.equal(m.entryIdFor(''), 'powerbar.tray.item');
});

test('a layout without the tray still takes the icon', () => {
  const c = config();
  c.bar.layout.right = [];
  assert.ok(m.moveOut(c, slack, 'right', 'managed', '', 'k1'));
  assert.equal(m.moveBack(c, 'k1'), true);
});

test("the tray's QML list is read like an array", () => {
  const qmlList = { length: 2, 0: slack, 1: nm };
  assert.equal(m.find(qmlList, { item: 'nm-applet' }), nm);
  assert.equal(m.trayRows(qmlList, config().bar.layout, PASSIVE).length, 2);
});
