const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../PreferencesModel.js`, 'utf8'), model);
const barModel = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../BarModel.js`, 'utf8'), barModel);
const fixture = () => ({ bar: { layout: {
  left: [{ id: 'a', format: 'HH:mm', nested: { keep: true } }, { id: 'a', size: 20 }],
  center: ['clock'], right: []
}}, unrelated: { retained: true } });
test('moves a specific duplicate, retains all settings and unrelated config', () => {
  const config = fixture();
  const source = model.records(config.bar.layout)[1];
  assert.equal(model.move(config, source, 'right', 'hidden', -1), true);
  assert.equal(config.bar.layout.left.length, 1);
  assert.deepEqual(config.bar.layout.right[0], { id: 'a', size: 20, powerbarVisibility: 'hidden' });
  assert.equal(config.bar.layout.left[0].nested.keep, true);
  assert.equal(config.unrelated.retained, true);
});
test('bar dragging moves only the chosen duplicate instance', () => {
  const config = { bar: { layout: {
    left: [
      { id: 'clock', powerbarInstance: 'first', format: 'HH:mm' },
      { id: 'clock', powerbarInstance: 'second', format: 'HH:mm:ss' },
      { id: 'tray', powerbarInstance: 'tray' }
    ], center: [], right: [{ id: 'audio', powerbarInstance: 'audio' }]
  } } };
  assert.equal(barModel.moveInstanceInConfig(config, 'left', 'second', 'right', 'audio'), true);
  assert.deepEqual(config.bar.layout.left.map(e => e.powerbarInstance), ['first', 'tray']);
  assert.deepEqual(config.bar.layout.right.map(e => e.powerbarInstance), ['second', 'audio']);
  assert.equal(config.bar.layout.right[0].format, 'HH:mm:ss');
  assert.equal(barModel.moveInstanceInConfig(config, 'left', 'first', 'left', 'tray'), false);
  assert.equal(barModel.moveInstanceInConfig(config, 'right', 'second', 'right', ''), true);
  assert.deepEqual(config.bar.layout.right.map(e => e.powerbarInstance), ['audio', 'second']);
  assert.equal(barModel.moveInstanceInConfig(config, 'left', 'tray', 'left', 'first'), true);
  assert.deepEqual(config.bar.layout.left.map(e => e.powerbarInstance), ['tray', 'first']);
  assert.equal(barModel.moveInstanceInConfig(config, 'right', 'missing', 'left', 'first'), false);
  assert.equal(barModel.moveInstanceInConfig(config, 'right', 'second', 'left', 'missing'), false);
});
test('dropping on an extended island changes only that instance to Managed', () => {
  const config = { bar: { layout: {
    left: [{ id: 'clock', powerbarInstance: 'first', powerbarVisibility: 'shown' },
      { id: 'clock', powerbarInstance: 'second', powerbarVisibility: 'shown', format: 'ddd' }],
    center: [], right: [{ id: 'audio', powerbarInstance: 'audio', powerbarVisibility: 'managed' }]
  } } };
  assert.equal(barModel.moveInstanceInConfig(config, 'left', 'second', 'right', 'audio', 'managed'), true);
  assert.deepEqual(config.bar.layout.right.map(e => e.powerbarInstance), ['second', 'audio']);
  assert.equal(config.bar.layout.right[0].powerbarVisibility, 'managed');
  assert.equal(config.bar.layout.right[0].format, 'ddd');
  assert.equal(config.bar.layout.left[0].powerbarVisibility, 'shown');
  assert.equal(barModel.moveInstanceInConfig(config, 'right', 'second', 'right', 'audio', 'shown'), true);
  assert.equal(config.bar.layout.right[0].powerbarVisibility, 'shown');
  assert.equal(barModel.moveInstanceInConfig(config, 'right', 'second', 'right', 'audio', 'shown'), false);
});
test('supports every zone and visibility as a destination and preserves settings through repeated moves', () => {
  const config = fixture();
  for (const section of model.sections) for (const mode of model.modes) {
    const source = model.records(config.bar.layout).find(e => e.fingerprint.includes('HH:mm'));
    assert.equal(model.move(config, source, section, mode, -1), true);
    const moved = model.records(config.bar.layout).find(e => e.fingerprint.includes('HH:mm'));
    assert.equal(moved.section, section);
    assert.equal(moved.mode, mode);
    assert.equal(JSON.parse(moved.fingerprint).nested.keep, true);
  }
});
test('reorders within a section without losing entries', () => {
  const config = { bar: { layout: { left: ['a', 'b', 'c'] } } };
  model.move(config, model.records(config.bar.layout)[0], 'left', 'managed', 2);
  assert.deepEqual(config.bar.layout.left.map(model.id), ['b', 'a', 'c']);
  model.move(config, model.records(config.bar.layout)[2], 'left', 'shown', 0);
  assert.deepEqual(config.bar.layout.left.map(model.id), ['c', 'b', 'a']);
});
test('rejects stale drags and invalid zones without mutating config', () => {
  const config = fixture(), source = model.records(config.bar.layout)[0];
  config.bar.layout.left[0].format = 'changed';
  const before = JSON.stringify(config);
  assert.equal(model.move(config, source, 'right', 'shown', -1), false);
  assert.equal(model.move(config, source, 'invalid', 'shown', -1), false);
  assert.equal(JSON.stringify(config), before);
});
test('visibility changes rebuild slots while ordinary settings remain incremental', () => {
  const before = { left: [{ id: 'a' }], center: [], right: [] };
  const after = { left: [{ id: 'a', powerbarVisibility: 'shown' }], center: [], right: [] };
  assert.equal(barModel.inlineSettingsDelta(before, after), null);
  after.left[0] = { id: 'a', format: 'HH:mm' };
  assert.equal(barModel.inlineSettingsDelta(before, after).length, 1);
});
const layoutEntries = [
  { instanceKey: 'a', section: 'left', mode: 'shown', index: 0 },
  { instanceKey: 'b', section: 'left', mode: 'shown', index: 2 },
  { instanceKey: 'c', section: 'left', mode: 'managed', index: 1 },
  { instanceKey: 'd', section: 'right', mode: 'shown', index: 0 }
];
const counter = (exclude) => (section, mode) => model.cell(layoutEntries, section, mode, exclude).length;
test('cells list one zone and visibility in bar order', () => {
  assert.deepEqual(model.cell(layoutEntries, 'left', 'shown').map(e => e.instanceKey), ['a', 'b']);
  assert.deepEqual(model.cell(layoutEntries, 'left', 'shown', 'a').map(e => e.instanceKey), ['b']);
});
test('cursor walks across zone edges and rests on empty cells', () => {
  const count = counter('');
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'shown', pos: 1 }, 1, 0) }, { section: 'centerBegin', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'center', mode: 'shown', pos: 0 }, 1, 0) }, { section: 'centerEnd', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'centerBegin', mode: 'shown', pos: 0 }, -1, 0) }, { section: 'left', mode: 'shown', pos: 1 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'shown', pos: 1 }, 0, 1) }, { section: 'left', mode: 'managed', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'shown', pos: 0 }, -1, -1) }, { section: 'left', mode: 'shown', pos: 0 });
});
test('a lifted item offers every gap and hands over between zones', () => {
  const count = counter('a');
  assert.deepEqual({ ...model.stepLift(count, { section: 'left', mode: 'shown', pos: 0 }, 1, 0) }, { section: 'left', mode: 'shown', pos: 1 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'left', mode: 'shown', pos: 1 }, 1, 0) }, { section: 'centerBegin', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'right', mode: 'shown', pos: 0 }, -1, 0) }, { section: 'centerEnd', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'centerBegin', mode: 'shown', pos: 0 }, -1, 0) }, { section: 'left', mode: 'shown', pos: 1 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'left', mode: 'shown', pos: 1 }, 0, 2) }, { section: 'left', mode: 'hidden', pos: 0 });
});
test('drops insert before the item at the gap or at the end of the zone', () => {
  const items = model.cell(layoutEntries, 'left', 'shown');
  assert.equal(model.dropBefore(items, 0), 0);
  assert.equal(model.dropBefore(items, 1), 2);
  assert.equal(model.dropBefore(items, 2), -1);
});
test('bar style reads the style, falls back to the old islands switch, and replaces it', () => {
  assert.equal(barModel.barStyle({}), 'flat');
  assert.equal(barModel.barStyle({ powerbarIslands: true }), 'islands');
  assert.equal(barModel.barStyle({ powerbarIslands: true, powerbarStyle: 'floating' }), 'floating');
  assert.equal(barModel.barStyle({ powerbarStyle: 'bogus' }), 'flat');
  const config = { bar: { powerbarIslands: true, keep: 1 } };
  assert.equal(barModel.setBarStyle(config, 'floating'), true);
  assert.deepEqual({ ...config.bar }, { keep: 1, powerbarStyle: 'floating' });
  assert.equal(barModel.setBarStyle(config, 'rounded'), false);
});
test('showing a hidden widget again returns it to the row it left', () => {
  assert.equal(model.toggledHidden('shown'), 'hidden');
  assert.equal(model.toggledHidden('managed'), 'hidden');
  assert.equal(model.toggledHidden('hidden', 'managed'), 'managed');
  assert.equal(model.toggledHidden('hidden', 'shown'), 'shown');
  assert.equal(model.toggledHidden('hidden'), 'shown');
  assert.equal(model.toggledHidden('hidden', 'hidden'), 'shown');
});
test('the five zones are five columns on every row, the tray meets the last', () => {
  const empty = () => 0;
  let at = { section: 'left', mode: 'managed', pos: 0 };
  const walked = [];
  for (let i = 0; i < 5; i++) { walked.push(at.section); at = model.stepCursor(empty, at, 1, 0); }
  assert.deepEqual(walked, ['left', 'centerBegin', 'center', 'centerEnd', 'right']);
  const rows = model.rows, columnsFor = mode => mode === 'tray' ? ['tray'] : model.sections;
  assert.deepEqual({ ...model.stepCursor(empty, { section: 'tray', mode: 'tray', pos: 0 }, 0, -1, columnsFor, rows) }, { section: 'right', mode: 'hidden', pos: 0 });
  // A move lands in the list it names.
  const config = { bar: { layout: { left: [], centerBegin: [], center: [{ id: 'clock' }], centerEnd: [{ id: 'a' }], right: [] } } };
  const recs = model.records(config.bar.layout);
  assert.deepEqual([...recs.map(r => r.section)], ['center', 'centerEnd']);
  assert.equal(model.move(config, recs[1], 'centerBegin', 'managed', -1), true);
  assert.deepEqual([...config.bar.layout.centerBegin.map(model.id)], ['a']);
  assert.equal(config.bar.layout.centerEnd.length, 0);
});

test('preferencesPage counts from 1 and clamps to the pages there are', () => {
  assert.equal(model.pageIndex(1, 3), 0);
  assert.equal(model.pageIndex(2, 3), 1);
  assert.equal(model.pageIndex(3, 3), 2);
  assert.equal(model.pageIndex(4, 3), 2);
  assert.equal(model.pageIndex(0, 3), 0);
  assert.equal(model.pageIndex(-2, 3), 0);
});

test('a panel hotkey by position opens the copy it counted when a widget is on the bar twice', () => {
  const a = { name: 'a', width: 20, height: 20, visible: true }, b = { name: 'b', width: 20, height: 20, visible: true };
  const rows = [{ slot: a, instance: 'pw-a', screenName: 'eDP-1', opened: false }, { slot: b, instance: 'pw-b', screenName: 'eDP-1', opened: false }];
  assert.equal(barModel.pickPanelSlot(rows, 'eDP-1', 'pw-b').name, 'b');
  assert.equal(barModel.pickPanelSlot(rows, 'eDP-1', 'pw-a').name, 'a');
  assert.equal(barModel.pickPanelSlot(rows, 'eDP-1', 'gone').name, barModel.pickPanelSlot(rows, 'eDP-1').name);
});

test('a widget is called by its display name, else its manifest name, else its id', () => {
  assert.equal(barModel.widgetName({ displayName: 'Clock', name: 'clock-plugin' }, 'omarchy.clock'), 'Clock');
  assert.equal(barModel.widgetName({ name: 'Postcard' }, 'tahayvr.postcard'), 'Postcard');
  assert.equal(barModel.widgetName(null, 'tahayvr.postcard'), 'postcard');
  assert.equal(barModel.widgetName({}, ''), '');
});

test('powerbar writes only a bar config that names it as the bar', () => {
  assert.equal(barModel.ownsBarConfig({ id: 'p0werj0int.powerbar', layout: {} }, 'p0werj0int.powerbar'), true);
  assert.equal(barModel.ownsBarConfig({ layout: { left: [] } }, 'p0werj0int.powerbar'), false, "Omarchy's defaults name no bar");
  assert.equal(barModel.ownsBarConfig({ id: 'omarchy.bar' }, 'p0werj0int.powerbar'), false, 'another bar');
  assert.equal(barModel.ownsBarConfig({}, 'p0werj0int.powerbar'), false, 'nothing delivered yet');
  assert.equal(barModel.ownsBarConfig(null, 'p0werj0int.powerbar'), false);
  assert.equal(barModel.ownsBarConfig({ id: 'p0werj0int.powerbar' }, ''), false);
});

test('stale widgets are the registry entries without a component', () => {
  const live = {};
  const ids = barModel.staleWidgetIds({ b: { component: null, metadata: {} }, a: { metadata: {} }, c: { component: live } });
  assert.deepEqual([...ids], ['a', 'b']);
  assert.deepEqual([...barModel.staleWidgetIds(null)], []);
});

test('a stale widget is found through its manifest, inside its own folder', () => {
  const manifest = (extra) => JSON.stringify(Object.assign({ id: 'x.clock', entryPoints: { barWidget: 'BarWidget.qml' } }, extra));
  assert.equal(barModel.widgetEntryPath('x.clock', '/p/x.clock/', manifest()).path, '/p/x.clock/BarWidget.qml');
  assert.equal(barModel.widgetEntryPath('x.clock', '/p/x', manifest({ entryPoints: { barWidget: 'ui/W.qml' } })).path, '/p/x/ui/W.qml');
  assert.equal(barModel.widgetEntryPath('x.clock', '', manifest()).error, 'no plugin folder');
  assert.equal(barModel.widgetEntryPath('x.clock', 'rel/dir', manifest()).error, 'no plugin folder');
  assert.equal(barModel.widgetEntryPath('x.clock', '/p', '{not json').error, 'manifest unreadable');
  assert.equal(barModel.widgetEntryPath('x.clock', '/p', '').error, 'manifest unreadable');
  assert.equal(barModel.widgetEntryPath('x.clock', '/p', manifest({ id: 'other' })).error, 'manifest is for other');
  for (const bad of ['../evil.qml', '/abs.qml', '', 7])
    assert.equal(barModel.widgetEntryPath('x.clock', '/p', manifest({ entryPoints: { barWidget: bad } })).error, 'no barWidget entry point', String(bad));
  assert.equal(barModel.widgetEntryPath('x.clock', '/p', manifest({ entryPoints: { overlay: 'O.qml' } })).error, 'no barWidget entry point');
});

test('a first-party widget can be described by a sibling manifest', () => {
  assert.deepEqual([...barModel.manifestCandidates('omarchy.keyboard-layout', true)], ['manifest.json', 'KeyboardLayout.manifest.json']);
  assert.deepEqual([...barModel.manifestCandidates('omarchy.tray', true)], ['manifest.json', 'Tray.manifest.json']);
  assert.deepEqual([...barModel.manifestCandidates('x.clock', false)], ['manifest.json'], 'third-party plugins have one manifest');
});

test('a repaired widget stays while the registry lists it from the same folder', () => {
  const repaired = { sourceDir: '/p/x' };
  assert.equal(barModel.keepRepaired(repaired, { component: {}, metadata: { sourceDir: '/p/x' } }), true, 'the shell loaded it again');
  assert.equal(barModel.keepRepaired(repaired, { component: null, metadata: { sourceDir: '/p/x' } }), true, 'still stale');
  assert.equal(barModel.keepRepaired(repaired, undefined), false, 'unregistered');
  assert.equal(barModel.keepRepaired(repaired, { component: {}, metadata: { sourceDir: '/p/x/' } }), true, 'a trailing slash');
  assert.equal(barModel.keepRepaired(repaired, { component: {}, metadata: { sourceDir: '/q/x' } }), false, 'moved');
  assert.equal(barModel.keepRepaired({ sourceDir: '' }, { metadata: { sourceDir: '' } }), false);
});

test('a move names its new neighbour by instance key, so a replay after an outside change lands beside it', () => {
  const layout = () => ({ left: [{ id: 'a', powerbarInstance: 'A' }, { id: 'b', powerbarInstance: 'B' }, { id: 'c', powerbarInstance: 'C' }],
    center: [], right: [{ id: 'r', powerbarInstance: 'R' }] });
  const shown = layout();
  assert.equal(model.anchorKey(shown, 'left', 2, 'A'), 'C');
  assert.equal(model.anchorKey(shown, 'left', 1.5, 'A'), 'C');
  assert.equal(model.anchorKey(shown, 'left', 3, 'A'), '');
  assert.equal(model.anchorKey(shown, 'left', -1, 'A'), '');
  assert.equal(model.anchorKey(shown, 'right', 0, 'A'), 'R');
  // Just before itself is its own place: the entry after it names that.
  assert.equal(model.anchorKey(shown, 'left', 0, 'A'), 'B');
  assert.equal(model.anchorKey(shown, 'left', 2, 'C'), '');
  // Replayed on a layout where another widget was added at the front.
  const config = { bar: { layout: layout() } };
  config.bar.layout.left.unshift({ id: 'n', powerbarInstance: 'N' });
  assert.equal(barModel.moveInstanceInConfig(config, 'left', 'A', 'left', model.anchorKey(shown, 'left', 2, 'A'), 'shown'), true);
  assert.deepEqual(config.bar.layout.left.map((e) => e.powerbarInstance), ['N', 'B', 'A', 'C']);
});
test("the tray's row sits under Hidden, one column wide, and leads back to the last zone", () => {
  const count = counter('');
  const columnsFor = mode => mode === 'tray' ? ['tray'] : ['left', 'center', 'right'];
  const rows = [...model.rows];
  assert.deepEqual(rows, ['shown', 'managed', 'hidden', 'tray']);
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'hidden', pos: 0 }, 0, 1, columnsFor, rows) }, { section: 'tray', mode: 'tray', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'tray', mode: 'tray', pos: 0 }, 0, -1, columnsFor, rows) }, { section: 'right', mode: 'hidden', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'hidden', pos: 0 }, 0, 1, columnsFor) }, { section: 'left', mode: 'hidden', pos: 0 }, 'without the tray row the cursor stops at Hidden');
  assert.deepEqual({ ...model.stepLift(count, { section: 'tray', mode: 'tray', pos: 0 }, 0, -3, columnsFor, rows) }, { section: 'right', mode: 'shown', pos: 0 });
});
