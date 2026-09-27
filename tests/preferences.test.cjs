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
test('supports all nine destinations and preserves settings through repeated moves', () => {
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
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'shown', pos: 1 }, 1, 0) }, { section: 'center', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'center', mode: 'shown', pos: 0 }, 1, 0) }, { section: 'right', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'center', mode: 'shown', pos: 0 }, -1, 0) }, { section: 'left', mode: 'shown', pos: 1 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'shown', pos: 1 }, 0, 1) }, { section: 'left', mode: 'managed', pos: 0 });
  assert.deepEqual({ ...model.stepCursor(count, { section: 'left', mode: 'shown', pos: 0 }, -1, -1) }, { section: 'left', mode: 'shown', pos: 0 });
});
test('a lifted item offers every gap and hands over between zones', () => {
  const count = counter('a');
  assert.deepEqual({ ...model.stepLift(count, { section: 'left', mode: 'shown', pos: 0 }, 1, 0) }, { section: 'left', mode: 'shown', pos: 1 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'left', mode: 'shown', pos: 1 }, 1, 0) }, { section: 'center', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'right', mode: 'shown', pos: 0 }, -1, 0) }, { section: 'center', mode: 'shown', pos: 0 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'center', mode: 'shown', pos: 0 }, -1, 0) }, { section: 'left', mode: 'shown', pos: 1 });
  assert.deepEqual({ ...model.stepLift(count, { section: 'left', mode: 'shown', pos: 1 }, 0, 2) }, { section: 'left', mode: 'hidden', pos: 0 });
});
test('drops insert before the item at the gap or at the end of the zone', () => {
  const items = model.cell(layoutEntries, 'left', 'shown');
  assert.equal(model.dropBefore(items, 0), 0);
  assert.equal(model.dropBefore(items, 1), 2);
  assert.equal(model.dropBefore(items, 2), -1);
});
