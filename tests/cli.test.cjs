const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const J = v => JSON.parse(JSON.stringify(v));
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../CliModel.js`, 'utf8'), m);
const a = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../AppearanceModel.js`, 'utf8'), a);

test('settings are found by name or by their shell.json key; shortcuts by target', () => {
  assert.equal(m.find('autoHide').key, 'powerbarAutoHide');
  assert.equal(m.find('powerbarAutoHide').name, 'autoHide');
  assert.equal(m.find('position').key, 'position');
  assert.equal(m.find('shape.rounding').look, 'rounding');
  assert.equal(m.find('nope'), null);
  assert.deepEqual(J(m.find('shortcut.bar:keys')), { name: 'shortcut.bar:keys', target: 'bar:keys', type: 'shortcut', writer: 'shortcut' });
  assert.equal(m.find('shortcut.'), null);
  assert.ok(m.names().indexOf('surface.text') >= 0);
});

test('values parse as JSON, else stay text', () => {
  assert.equal(m.parseValue('true'), true);
  assert.equal(m.parseValue('12'), 12);
  assert.equal(m.parseValue('"inline"'), 'inline');
  assert.equal(m.parseValue('inline'), 'inline');
  assert.equal(m.parseValue('SUPER + B'), 'SUPER + B');
  assert.deepEqual(J(m.parseValue('{"keys":"SUPER + B"}')), { keys: 'SUPER + B' });
  assert.equal(m.parseValue(''), '');
});

test('values are checked as Preferences offers them', () => {
  const ctx = { roundingMax: 13 };
  assert.deepEqual(J(m.check(m.find('autoHide'), true)), { value: true });
  assert.deepEqual(J(m.check(m.find('autoHide'), 'on')), { value: true });
  assert.deepEqual(J(m.check(m.find('autoHide'), 'off')), { value: false });
  assert.ok(m.check(m.find('autoHide'), 'yes').error);
  assert.deepEqual(J(m.check(m.find('onDemand'), 'inline')), { value: 'inline' });
  assert.match(m.check(m.find('onDemand'), 'menu').error, /drawer, inline/);
  assert.deepEqual(J(m.check(m.find('spacing'), 4)), { value: 4 });
  assert.match(m.check(m.find('spacing'), 17).error, /from 0 to 16/);
  assert.match(m.check(m.find('spacing'), 2.5).error, /steps of 1/);
  assert.deepEqual(J(m.check(m.find('shape.borderWidth'), 1.5)), { value: 1.5 });
  assert.match(m.check(m.find('shape.borderWidth'), 1.2).error, /steps of 0.5/);
  assert.match(m.check(m.find('surface.opacity'), 42).error, /steps of 5/);
  assert.deepEqual(J(m.check(m.find('surface.opacity'), 45)), { value: 45 });
  assert.deepEqual(J(m.check(m.find('shape.rounding'), 13, ctx)), { value: 13 });
  assert.match(m.check(m.find('shape.rounding'), 14, ctx).error, /from 0 to 13/);
  assert.deepEqual(J(m.check(m.find('revealSeconds'), 2.5)), { value: 2.5 });
  assert.match(m.check(m.find('revealSeconds'), 0).error, /from 1 to 60/);
  assert.match(m.check(m.find('spacing'), '4').error, /is a number/);
  assert.deepEqual(J(m.check(m.find('centerAnchor'), '')), { value: '' });
  assert.ok(m.check(m.find('centerAnchor'), 3).error);
});

test('shortcut values: keys, none, or a confirmed replacement', () => {
  const s = m.find('shortcut.bar:keys');
  assert.deepEqual(J(m.check(s, ' SUPER + B ')), { value: { keys: 'SUPER + B', replace: false } });
  assert.deepEqual(J(m.check(s, '')), { value: { keys: '', replace: false } });
  assert.deepEqual(J(m.check(s, { keys: 'SUPER + B', replace: true })), { value: { keys: 'SUPER + B', replace: true } });
  assert.ok(m.check(s, 3).error);
  assert.equal(m.shortcutTarget('bar:keys'), '');
  assert.equal(m.shortcutTarget('widget:omarchy.audio'), '');
  assert.equal(m.shortcutTarget('group:g-1', { groups: ['g-1'] }), '');
  assert.match(m.shortcutTarget('group:g-2', { groups: ['g-1'] }), /no group g-2/);
  assert.match(m.shortcutTarget('bar'), /bar:keys/);
});

test('toggle flips switches only', () => {
  assert.deepEqual(J(m.toggled(m.find('autoHide'), true)), { value: false });
  assert.deepEqual(J(m.toggled(m.find('autoHide'), false)), { value: true });
  assert.ok(m.toggled(m.find('position'), 'top').error);
});

const records = [
  { section: 'left', index: 0, id: 'omarchy.menu', instanceKey: 'k-menu', mode: 'shown' },
  { section: 'center', index: 0, id: 'omarchy.clock', instanceKey: 'k-clock', mode: 'shown' },
  { section: 'center', index: 1, id: 'omarchy.weather', instanceKey: 'k-weather', mode: 'managed' },
  { section: 'right', index: 0, id: 'omarchy.indicators', instanceKey: 'k-ind1', mode: 'shown' },
  { section: 'right', index: 1, id: 'omarchy.indicators', instanceKey: 'k-ind2', mode: 'shown' }
];

test('widgets are named by instance, or by id when there is one', () => {
  assert.equal(m.widgetRecord(records, 'omarchy.clock').record.instanceKey, 'k-clock');
  assert.equal(m.widgetRecord(records, 'k-ind2').record.index, 1);
  assert.match(m.widgetRecord(records, 'omarchy.indicators').error, /2 times.*k-ind1, k-ind2/);
  assert.match(m.widgetRecord(records, 'omarchy.nope').error, /no widget/);
  assert.ok(m.widgetRecord(records, '').error);
});

test('a widget change is checked whole', () => {
  const ctx = { groups: ['g-1'] };
  assert.deepEqual(J(m.widgetPatch({ visibility: 'managed' }, ctx)), { patch: { visibility: 'managed' } });
  assert.match(m.widgetPatch({ visibility: 'gone' }, ctx).error, /shown, managed, hidden/);
  assert.match(m.widgetPatch({ zone: 'top' }, ctx).error, /left, center, right/);
  assert.match(m.widgetPatch({ colour: 'red' }, ctx).error, /unknown field colour/);
  assert.match(m.widgetPatch({ group: 'g-2' }, ctx).error, /group/);
  assert.deepEqual(J(m.widgetPatch({ group: '' }, ctx)), { patch: { group: '' } });
  assert.match(m.widgetPatch({ activityPeek: 'no' }, ctx).error, /activityPeek is true or false/);
  assert.match(m.widgetPatch({ badgeProperty: 1 }, ctx).error, /badgeProperty/);
  assert.ok(m.widgetPatch('managed', ctx).error);
  assert.ok(m.widgetPatch([], ctx).error);
});

test('placement keeps a widget in place unless it moves zone or names a neighbour', () => {
  const clock = records[1];
  assert.deepEqual(J(m.placement(clock, { visibility: 'managed' })), { section: 'center', mode: 'managed', before: 1, changed: true });
  assert.deepEqual(J(m.placement(clock, { zone: 'left' })), { section: 'left', mode: 'shown', before: -1, changed: true });
  assert.deepEqual(J(m.placement(clock, { before: '' })), { section: 'center', mode: 'shown', before: -1, changed: true });
  assert.deepEqual(J(m.placement(clock, { zone: 'left' }, records[0])), { section: 'left', mode: 'shown', before: 0, changed: true });
  assert.deepEqual(J(m.placement(clock, { before: 'omarchy.menu' }, records[0])), { section: 'left', mode: 'shown', before: 0, changed: true });
  assert.match(m.placement(clock, { zone: 'right', before: 'omarchy.menu' }, records[0]).error, /left zone, not right/);
  assert.match(m.placement(clock, { before: 'k-clock' }, clock).error, /before itself/);
  assert.equal(m.placement(clock, { group: 'g-1' }).changed, false);
  assert.equal(m.placement(clock, { zone: 'center', visibility: 'shown' }).changed, false);
});

test('groups by id or unique name; a change in GroupsModel terms', () => {
  const groups = [{ id: 'g-1', label: 'Media' }, { id: 'g-2', label: 'Net' }, { id: 'g-3', label: 'Net' }];
  assert.equal(m.groupRecord(groups, 'g-2').group.label, 'Net');
  assert.equal(m.groupRecord(groups, 'Media').group.id, 'g-1');
  assert.match(m.groupRecord(groups, 'Net').error, /g-2, g-3/);
  assert.match(m.groupRecord(groups, 'x').error, /no group/);
  assert.deepEqual(J(m.groupPatch({ zone: 'left', face: 'both', badge: false })), { patch: { section: 'left', face: 'both', badge: false } });
  assert.match(m.groupPatch({ face: 'icon' }).error, /glyph, text, both/);
  assert.match(m.groupPatch({ label: ' ' }).error, /label/);
  assert.match(m.groupPatch({ size: 3 }).error, /unknown field size/);
  assert.match(m.groupPatch({ members: 'a' }).error, /members/);
  assert.deepEqual(J(m.groupPatch({ members: ['a', 'b'] })), { patch: { members: ['a', 'b'] } });
  assert.match(m.groupPatch({ iconFont: 'omarchy' }).error, /goes with icon/);
  assert.deepEqual(J(m.groupPatch({ icon: '', iconFont: 'omarchy' })), { patch: { icon: '', iconFont: 'omarchy' } });
  assert.match(m.groupPatch({ tooltip: 'yes' }).error, /tooltip/);
});

test('members: who leaves first, then everyone in the new order', () => {
  assert.deepEqual(J(m.memberSteps(['a', 'b', 'c'], ['c', 'a'])),
    [{ key: 'b', group: false }, { key: 'c', group: true }, { key: 'a', group: true }]);
  assert.deepEqual(J(m.memberSteps([], ['a'])), [{ key: 'a', group: true }]);
});

test('help lists every IPC function once; settings describes every setting', () => {
  const calls = m.help().map(f => f.call.split(' ')[2]);
  assert.equal(new Set(calls).size, calls.length);
  for (const fn of ['status', 'get', 'set', 'reset', 'toggle', 'widgets', 'setWidget', 'groups', 'newGroup',
    'setGroup', 'removeGroup', 'shortcuts', 'show', 'hide', 'keysOn', 'keysOff', 'help'])
    assert.ok(calls.includes(fn), fn);
  const d = m.describe({ roundingMax: 13 });
  assert.equal(d.find(s => s.name === 'shape.rounding').max, 13);
  assert.equal(d.find(s => s.name === 'autoHide').key, 'bar.powerbarAutoHide');
  assert.equal(d.find(s => s.name === 'surface.text').key, 'bar.powerbarAppearance');
  assert.equal(d.length, m.settings.length + 1);
});

test('every IPC function the help lists exists in Bar.qml, and no other', () => {
  const bar = fs.readFileSync(`${__dirname}/../Bar.qml`, 'utf8');
  const start = bar.indexOf('target: "powerbar"');
  const block = bar.slice(start, bar.indexOf('\n  }\n', start));
  const defined = [...block.matchAll(/^    function (\w+)\(/gm)].map(x => x[1]).sort();
  const listed = J(m.help().map(f => f.call.split(' ')[2])).sort();
  assert.deepEqual(defined, listed);
});

test('a tile\'s default scope: Everywhere while shared values exist, else Theme', () => {
  assert.equal(a.defaultScope({}, 'shape'), 'theme');
  assert.equal(a.defaultScope({ all: { shape: { rounding: 4 } } }, 'shape'), 'all');
  assert.equal(a.defaultScope({ all: { shape: { use: 'all' } } }, 'shape'), 'theme');
});
