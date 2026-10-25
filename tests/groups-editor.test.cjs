const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../GroupsEditorModel.js`, 'utf8'), m);
const groups = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../GroupsModel.js`, 'utf8'), groups);
const plain = v => JSON.parse(JSON.stringify(v));
const zones = ['left', 'centerLeft', 'center', 'centerRight', 'right'];
const state = (extra = {}) => ({
  zones,
  faces: { left: ['ai'], centerLeft: [], center: [], centerRight: [], right: ['audio', 'net'] },
  members: { ai: 3, audio: 2, net: 0 },
  pool: 7, perRow: 3, chosen: 'audio', ...extra
});

test('hidden groups keep their face on the rail where they would sit on the bar', () => {
  const layout = { left: [{ id: 'clock', powerbarInstance: 'c' }, { id: 'cpu', powerbarInstance: 'p' }], right: [] };
  const list = [
    { id: 'a', section: 'left', before: 'p', visibility: 'hidden' },
    { id: 'b', section: 'left', before: '', visibility: 'managed' },
    { id: 'z', section: 'right', visibility: 'shown' }
  ];
  const faces = m.railFaces(groups.render(layout, m.railGroups(list)), zones);
  assert.deepEqual(plain(faces), { left: ['a', 'b'], centerLeft: [], center: [], centerRight: [], right: ['z'] });
  assert.equal(list[0].visibility, 'hidden', 'the groups themselves are left alone');
  assert.deepEqual(plain(m.drawerOrder(faces, zones)), ['a', 'b', 'z']);
  assert.deepEqual(plain(m.drawerSlots(faces, zones).b), { zone: 'left', index: 1, count: 2 });
});

test('rail columns leave the camera column empty and follow the centre side', () => {
  assert.deepEqual(plain(m.railColumns(false, 'right')), { label: 0, left: 1, centerBegin: 2, center: 3, centerEnd: 4, right: 5 });
  const right = m.railColumns(true, 'right'), left = m.railColumns(true, 'left');
  assert.ok(Object.values(right).indexOf(3) < 0 && Object.values(left).indexOf(3) < 0);
  assert.equal(right.center, 4); assert.equal(left.center, 2); assert.equal(left.label, 6);
});

test('the rail walks every face and plus across the zones', () => {
  const s = state();
  const stops = plain(m.railStops(s.faces, zones)).map(p => `${p.zone}:${p.slot}`);
  assert.deepEqual(stops, ['left:0', 'left:1', 'centerLeft:0', 'center:0', 'centerRight:0', 'right:0', 'right:1', 'right:2']);
  let at = { area: 'rail', zone: 'left', slot: 1 };
  at = m.step(s, at, 1, 0); assert.deepEqual(plain(at), { area: 'rail', zone: 'centerLeft', slot: 0 });
  at = m.step(s, { area: 'rail', zone: 'left', slot: 0 }, -1, 0); assert.deepEqual(plain(at), { area: 'rail', zone: 'left', slot: 0 });
  at = m.step(s, { area: 'rail', zone: 'right', slot: 2 }, 1, 0); assert.equal(at.slot, 2);
  assert.deepEqual(plain(m.step(s, { area: 'rail', zone: 'right', slot: 0 }, 0, 1)), { area: 'drawer', id: 'audio', pos: 0 });
  assert.deepEqual(plain(m.step(s, { area: 'rail', zone: 'center', slot: 0 }, 0, 1)), { area: 'pool', pos: 0 });
  assert.equal(m.groupAt(s, { area: 'rail', zone: 'right', slot: 1 }), 'net');
  assert.equal(m.groupAt(s, { area: 'rail', zone: 'right', slot: 2 }), '');
});

test('drawers walk down to the pool, up to the face and across at the same row', () => {
  const s = state();
  assert.deepEqual(plain(m.step(s, { area: 'drawer', id: 'ai', pos: 0 }, 0, 1)), { area: 'drawer', id: 'ai', pos: 1 });
  assert.deepEqual(plain(m.step(s, { area: 'drawer', id: 'ai', pos: 2 }, 0, 1)), { area: 'pool', pos: 0 });
  assert.deepEqual(plain(m.step(s, { area: 'drawer', id: 'ai', pos: 0 }, 0, -1)), { area: 'rail', zone: 'left', slot: 0 });
  assert.deepEqual(plain(m.step(s, { area: 'drawer', id: 'ai', pos: 2 }, 1, 0)), { area: 'drawer', id: 'audio', pos: 1 });
  assert.deepEqual(plain(m.step(s, { area: 'drawer', id: 'audio', pos: 1 }, 1, 0)), { area: 'drawer', id: 'net', pos: 0 });
  assert.deepEqual(plain(m.step(s, { area: 'drawer', id: 'net', pos: 0 }, 0, 1)), { area: 'pool', pos: 0 }, 'an empty drawer is one stop');
});

test('the pool walks by rows and climbs back to the chosen drawer', () => {
  const s = state();
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 1 }, 0, 1)), { area: 'pool', pos: 4 });
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 5 }, 0, 1)), { area: 'pool', pos: 6 }, 'a short last row takes its last chip');
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 6 }, 0, 1)), { area: 'pool', pos: 6 });
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 4 }, 0, -1)), { area: 'pool', pos: 1 });
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 1 }, 0, -1)), { area: 'drawer', id: 'audio', pos: 1 });
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 6 }, 1, 0)), { area: 'pool', pos: 6 });
  const bare = state({ faces: { left: [], centerLeft: [], center: [], centerRight: [], right: [] }, members: {}, chosen: '' });
  assert.deepEqual(plain(m.step(bare, { area: 'pool', pos: 0 }, 0, -1)), { area: 'rail', zone: 'left', slot: 0 });
  assert.deepEqual(plain(m.firstPlace(bare)), { area: 'rail', zone: 'left', slot: 0 });
  assert.deepEqual(plain(m.firstPlace(state())), { area: 'rail', zone: 'right', slot: 0 });
});

test('a place survives the layout changing under it', () => {
  const s = state();
  assert.deepEqual(plain(m.normalize(s, { area: 'drawer', id: 'gone', pos: 2 })), { area: 'rail', zone: 'right', slot: 0 });
  assert.deepEqual(plain(m.normalize(s, { area: 'drawer', id: 'ai', pos: 9 })), { area: 'drawer', id: 'ai', pos: 2 });
  assert.deepEqual(plain(m.normalize(s, { area: 'rail', zone: 'right', slot: 9 })), { area: 'rail', zone: 'right', slot: 2 });
  assert.deepEqual(plain(m.normalize(s, { area: 'pool', pos: 30 })), { area: 'pool', pos: 6 });
  assert.deepEqual(plain(m.normalize(state({ pool: 0 }), { area: 'pool', pos: 3 })), { area: 'pool', pos: 0 });
});

test('a lifted widget lands between members, in the pool or on a plus', () => {
  // members without the lifted widget: ai 3 offers places 0..3
  const s = state();
  assert.deepEqual(plain(m.liftStart({ area: 'drawer', id: 'ai', pos: 1 })), { area: 'drawer', id: 'ai', pos: 1 });
  assert.deepEqual(plain(m.liftStart({ area: 'pool', pos: 4 })), { area: 'pool' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'drawer', id: 'ai', pos: 2 }, 0, 1)), { area: 'drawer', id: 'ai', pos: 3 });
  assert.deepEqual(plain(m.stepLift(s, { area: 'drawer', id: 'ai', pos: 3 }, 0, 1)), { area: 'pool' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'drawer', id: 'ai', pos: 0 }, 0, -1)), { area: 'plus', zone: 'left' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'drawer', id: 'ai', pos: 3 }, 1, 0)), { area: 'drawer', id: 'audio', pos: 2 });
  assert.deepEqual(plain(m.stepLift(s, { area: 'plus', zone: 'left' }, 1, 0)), { area: 'plus', zone: 'centerLeft' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'plus', zone: 'right' }, 0, 1)), { area: 'drawer', id: 'audio', pos: 0 });
  assert.deepEqual(plain(m.stepLift(s, { area: 'plus', zone: 'center' }, 0, 1)), { area: 'pool' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 0, -1, 'ai')), { area: 'drawer', id: 'ai', pos: 3 });
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 0, -1, '')), { area: 'drawer', id: 'audio', pos: 2 });
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 1, 0)), { area: 'pool' });
});

test('a drop says what changes', () => {
  const member = { key: 'k', group: 'ai' }, loose = { key: 'k', group: '' };
  assert.deepEqual(plain(m.dropAction(member, { area: 'pool' })), { op: 'assign', key: 'k', id: '', before: '' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'pool' })), { op: 'none' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'plus', zone: 'center' })), { op: 'create', key: 'k', zone: 'center' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'drawer', id: 'audio', pos: 1 }, ['x', 'y'])), { op: 'assign', key: 'k', id: 'audio', before: 'y' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'drawer', id: 'audio', pos: 2 }, ['x', 'y'])), { op: 'assign', key: 'k', id: 'audio', before: '' });
  assert.deepEqual(plain(m.dropAction(member, { area: 'drawer', id: 'ai', pos: 1 }, ['x', 'y'], 1)), { op: 'none' });
  assert.deepEqual(plain(m.dropAction(member, { area: 'drawer', id: 'ai', pos: 0 }, ['x', 'y'], 1)), { op: 'assign', key: 'k', id: 'ai', before: 'x' });
  assert.deepEqual(plain(m.dropAction(member, { area: 'face', id: 'ai' })), { op: 'none' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'face', id: 'ai' })), { op: 'assign', key: 'k', id: 'ai', before: '' });
  assert.deepEqual(plain(m.dropAction({ face: 'ai', zone: 'left' }, { area: 'zone', zone: 'right' })), { op: 'zone', id: 'ai', zone: 'right' });
  assert.deepEqual(plain(m.dropAction({ face: 'ai', zone: 'left' }, { area: 'zone', zone: 'left' })), { op: 'none' });
  assert.deepEqual(plain(m.dropAction(null, { area: 'pool' })), { op: 'none' });
});

test('a drop carried out by GroupsModel puts the widget where the drawer showed it', () => {
  const layout = { left: ['x', 'k', 'y'].map(key => ({ id: 'w', powerbarInstance: key })) };
  const config = { bar: { layout, powerbarGroups: [{ id: 'ai', section: 'left', items: ['x', 'k', 'y'] }] } };
  const into = ['x', 'y'];
  const act = m.dropAction({ key: 'k', group: 'ai' }, { area: 'drawer', id: 'ai', pos: 2 }, into, 1);
  assert.equal(groups.assign(config, act.key, act.id, act.before), true);
  assert.deepEqual(plain(config.bar.powerbarGroups[0].items), ['x', 'y', 'k']);
});

test('shift steps visibility and zone without wrapping', () => {
  assert.equal(m.nextVisibility('shown', 1), 'managed');
  assert.equal(m.nextVisibility('managed', 1), 'hidden');
  assert.equal(m.nextVisibility('hidden', 1), '');
  assert.equal(m.nextVisibility('managed', -1), 'shown');
  assert.equal(m.nextVisibility('shown', -1), '');
  assert.equal(m.nextZone(zones, 'left', 1), 'centerLeft');
  assert.equal(m.nextZone(zones, 'left', -1), '');
  assert.equal(m.nextZone(zones, 'right', 1), '');
});

test('the pool holds the ungrouped widgets in bar order and filters by name or id', () => {
  const entries = [
    { id: 'clock', instanceKey: 'c', section: 'right', index: 1 },
    { id: 'cpu', instanceKey: 'p', section: 'left', index: 2 },
    { id: 'wifi', instanceKey: 'w', section: 'left', index: 0 },
    { id: 'tray', instanceKey: 't', section: 'tray', index: 0 },
    { id: 'mem', instanceKey: 'm', section: 'right', index: 0 }
  ];
  const title = e => ({ clock: 'Clock', cpu: 'Processor', wifi: 'Network', mem: 'Memory' })[e.id] || e.id;
  const grouped = key => key === 'm';
  assert.deepEqual(plain(m.poolItems(entries, zones.concat(['hidden']), grouped, '', title)).map(e => e.id), ['wifi', 'cpu', 'clock']);
  assert.deepEqual(plain(m.poolItems(entries, zones, grouped, ' PROC ', title)).map(e => e.id), ['cpu']);
  assert.deepEqual(plain(m.poolItems(entries, zones, grouped, 'wif', title)).map(e => e.id), ['wifi']);
  assert.equal(m.perRow(300, 90, 6), 3);
  assert.equal(m.perRow(40, 90, 6), 1);
});

test('the pool asks for its rows up to a third of the room and keeps a floor', () => {
  assert.deepEqual(plain(m.shareBands(700, 100, 120, 60, 80)), { poolSeen: 120, drawers: 480 });
  assert.deepEqual(plain(m.shareBands(400, 100, 200, 60, 80)), { poolSeen: 100, drawers: 200 });
  assert.deepEqual(plain(m.shareBands(200, 100, 200, 60, 80)), { poolSeen: 60, drawers: 80 });
});
