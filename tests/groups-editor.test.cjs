const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../GroupsEditorModel.js`, 'utf8'), m);
const prefs = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../PreferencesModel.js`, 'utf8'), prefs);
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

test('hidden groups keep their face in the list where they would sit on the bar', () => {
  const layout = { left: [{ id: 'clock', powerbarInstance: 'c' }, { id: 'cpu', powerbarInstance: 'p' }], right: [] };
  const list = [
    { id: 'a', section: 'left', before: 'p', visibility: 'hidden' },
    { id: 'b', section: 'left', before: '', visibility: 'managed' },
    { id: 'z', section: 'right', visibility: 'shown' }
  ];
  const faces = m.railFaces(groups.render(layout, m.railGroups(list)), zones);
  assert.deepEqual(plain(faces), { left: ['a', 'b'], centerLeft: [], center: [], centerRight: [], right: ['z'] });
  assert.equal(list[0].visibility, 'hidden', 'the groups themselves are left alone');
  assert.deepEqual(plain(m.faceOrder(faces, zones)), ['a', 'b', 'z']);
});

test('a zone lists each face with its widgets under it, then its +', () => {
  const s = state();
  assert.deepEqual(plain(m.rows(s, 'right')), [
    { area: 'face', id: 'audio' }, { area: 'member', id: 'audio', pos: 0 }, { area: 'member', id: 'audio', pos: 1 },
    { area: 'face', id: 'net' }, { area: 'plus', zone: 'right' }
  ], 'an empty group is its face alone');
  assert.deepEqual(plain(m.rows(s, 'center')), [{ area: 'plus', zone: 'center' }]);
  assert.deepEqual(plain(m.drawnRows(['audio', 'net'], { audio: ['x', 'y'], net: [] })), [
    { kind: 'face', id: 'audio' },
    { kind: 'member', id: 'audio', pos: 0, key: 'x', first: true, last: false },
    { kind: 'member', id: 'audio', pos: 1, key: 'y', first: false, last: true },
    { kind: 'face', id: 'net' }, { kind: 'note', id: 'net' }
  ], 'an empty group has a note row');
  assert.deepEqual(plain(m.drawnRows(['audio', 'net'], { audio: ['x', 'y'], net: [] }, { area: 'gap', id: 'net', pos: 0 })).slice(3), [
    { kind: 'face', id: 'net' }, { kind: 'gap', id: 'net', pos: 0, first: true, last: true }
  ], 'a landing place takes the note\'s row');
  assert.deepEqual(plain(m.drawnRows(['audio'], { audio: ['x', 'y'] }, { area: 'gap', id: 'audio', pos: 1 })).map(r => r.kind + (r.last ? '.' : '')), ['face', 'member', 'gap', 'member.']);
  assert.deepEqual(plain(m.drawnRows(['audio'], { audio: ['x'] }, { area: 'pool' })).length, 2, 'a landing elsewhere draws nothing here');
});

test('j/k walk down a zone\'s list and on to the pool', () => {
  const s = state();
  let at = { area: 'face', id: 'audio' };
  const walk = [];
  for (let i = 0; i < 6; i++) { at = m.step(s, at, 0, 1); walk.push(plain(at)); }
  assert.deepEqual(walk, [
    { area: 'member', id: 'audio', pos: 0 }, { area: 'member', id: 'audio', pos: 1 }, { area: 'face', id: 'net' },
    { area: 'plus', zone: 'right' }, { area: 'pool', pos: 0 }, { area: 'pool', pos: 3 }
  ]);
  assert.deepEqual(plain(m.step(s, { area: 'face', id: 'net' }, 0, -1)), { area: 'member', id: 'audio', pos: 1 }, 'k climbs into the group above');
  assert.deepEqual(plain(m.step(s, { area: 'face', id: 'audio' }, 0, -1)), { area: 'face', id: 'audio' }, 'k from the first row stays');
  assert.deepEqual(plain(m.step(s, { area: 'plus', zone: 'center' }, 0, 1)), { area: 'pool', pos: 0 }, 'a zone without groups: its + then the pool');
  assert.deepEqual(plain(m.step(s, { area: 'plus', zone: 'center' }, 0, -1)), { area: 'plus', zone: 'center' });
  assert.deepEqual(plain(m.step(s, { area: 'member', id: 'ai', pos: 1 }, 0, 0)), { area: 'member', id: 'ai', pos: 1 });
  assert.equal(m.groupAt(s, { area: 'member', id: 'ai', pos: 1 }), 'ai');
  assert.equal(m.groupAt(s, { area: 'face', id: 'net' }), 'net');
  assert.equal(m.groupAt(s, { area: 'plus', zone: 'right' }), '');
  assert.equal(m.groupAt(s, { area: 'pool', pos: 0 }), '');
  assert.equal(m.groupAt(s, { area: 'face', id: 'gone' }), '');
});

test('h/l go to the same row in the next zone, clamped to its +', () => {
  const s = state();
  assert.deepEqual(plain(m.step(s, { area: 'member', id: 'ai', pos: 0 }, 1, 0)), { area: 'plus', zone: 'centerLeft' }, 'clamped to the next zone\'s +');
  assert.deepEqual(plain(m.step(s, { area: 'member', id: 'ai', pos: 2 }, 4, 0)), { area: 'plus', zone: 'centerLeft' }, 'one zone a step');
  assert.deepEqual(plain(m.step(s, { area: 'member', id: 'ai', pos: 1 }, 0, 0)), { area: 'member', id: 'ai', pos: 1 });
  assert.deepEqual(plain(m.step(s, { area: 'plus', zone: 'centerRight' }, 1, 0)), { area: 'face', id: 'audio' }, 'row 0 of the next zone');
  assert.deepEqual(plain(m.step(s, { area: 'member', id: 'audio', pos: 1 }, 1, 0)), { area: 'member', id: 'audio', pos: 1 }, 'clamped at the last zone');
  const two = state({ faces: { left: ['ai'], centerLeft: ['b'], center: [], centerRight: [], right: ['audio', 'net'] }, members: { ai: 3, b: 1, audio: 2, net: 0 } });
  assert.deepEqual(plain(m.step(two, { area: 'member', id: 'ai', pos: 1 }, 1, 0)), { area: 'plus', zone: 'centerLeft' }, 'row 2: b\'s list is face, widget, +');
  assert.deepEqual(plain(m.step(two, { area: 'member', id: 'ai', pos: 0 }, 1, 0)), { area: 'member', id: 'b', pos: 0 });
  assert.deepEqual(plain(m.step(two, { area: 'member', id: 'b', pos: 0 }, -1, 0)), { area: 'member', id: 'ai', pos: 0 }, 'leftward too');
  assert.deepEqual(plain(m.step(two, { area: 'plus', zone: 'right' }, -2, 0)), { area: 'plus', zone: 'centerRight' }, 'row 4 of a bare zone: its +');
});

test('the pool walks by rows and climbs back to the chosen group\'s last row', () => {
  const s = state();
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 1 }, 0, 1)), { area: 'pool', pos: 4 });
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 5 }, 0, 1)), { area: 'pool', pos: 6 }, 'a short last row takes its last chip');
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 6 }, 0, 1)), { area: 'pool', pos: 6 });
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 4 }, 0, -1)), { area: 'pool', pos: 1 });
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 1 }, 0, -1)), { area: 'member', id: 'audio', pos: 1 }, 'its last widget');
  assert.deepEqual(plain(m.step(state({ chosen: 'net' }), { area: 'pool', pos: 1 }, 0, -1)), { area: 'face', id: 'net' }, 'an empty group: its face');
  assert.deepEqual(plain(m.step(state({ chosen: '' }), { area: 'pool', pos: 1 }, 0, -1)), { area: 'face', id: 'ai' }, 'none chosen: the first zone\'s first row');
  assert.deepEqual(plain(m.step(s, { area: 'pool', pos: 6 }, 1, 0)), { area: 'pool', pos: 6 });
  const bare = state({ faces: { left: [], centerLeft: [], center: [], centerRight: [], right: [] }, members: {}, chosen: '' });
  assert.deepEqual(plain(m.step(bare, { area: 'pool', pos: 0 }, 0, -1)), { area: 'plus', zone: 'left' });
  assert.deepEqual(plain(m.firstPlace(bare)), { area: 'plus', zone: 'left' });
  assert.deepEqual(plain(m.firstPlace(state())), { area: 'face', id: 'audio' });
});

test('a place survives the layout changing under it', () => {
  const s = state();
  assert.deepEqual(plain(m.normalize(s, { area: 'member', id: 'gone', pos: 2 })), { area: 'face', id: 'audio' });
  assert.deepEqual(plain(m.normalize(s, { area: 'face', id: 'gone' })), { area: 'face', id: 'audio' });
  assert.deepEqual(plain(m.normalize(s, { area: 'member', id: 'ai', pos: 9 })), { area: 'member', id: 'ai', pos: 2 });
  assert.deepEqual(plain(m.normalize(s, { area: 'member', id: 'net', pos: 0 })), { area: 'face', id: 'net' }, 'a group left empty: its face');
  assert.deepEqual(plain(m.normalize(s, { area: 'plus', zone: 'gone' })), { area: 'face', id: 'audio' });
  assert.deepEqual(plain(m.normalize(s, { area: 'plus', zone: 'center' })), { area: 'plus', zone: 'center' });
  assert.deepEqual(plain(m.normalize(s, { area: 'pool', pos: 30 })), { area: 'pool', pos: 6 });
  assert.deepEqual(plain(m.normalize(state({ pool: 0 }), { area: 'pool', pos: 3 })), { area: 'pool', pos: 0 });
  assert.deepEqual(plain(m.normalize(s, { area: 'rail', zone: 'left', slot: 0 })), { area: 'face', id: 'audio' }, 'an old place: the first place');
  assert.deepEqual(plain(m.step(s, { area: 'member', id: 'ai', pos: 7 }, 0, 1)), { area: 'member', id: 'ai', pos: 2 }, 'a stale row is clamped first');
});

test('a lifted widget lands at any group\'s gaps, on a + or in the pool', () => {
  // members without the lifted widget: audio 2 offers gaps 0..2, net (empty) one
  const s = state();
  assert.deepEqual(plain(m.liftStart({ area: 'member', id: 'ai', pos: 1 })), { area: 'gap', id: 'ai', pos: 1 });
  assert.deepEqual(plain(m.liftStart({ area: 'pool', pos: 4 })), { area: 'pool' });
  assert.deepEqual(plain(m.landings(s, 'right')), [
    { area: 'gap', id: 'audio', pos: 0 }, { area: 'gap', id: 'audio', pos: 1 }, { area: 'gap', id: 'audio', pos: 2 },
    { area: 'gap', id: 'net', pos: 0 }, { area: 'plus', zone: 'right' }
  ]);
  let t = { area: 'gap', id: 'audio', pos: 1 };
  const walk = [];
  for (let i = 0; i < 4; i++) { t = m.stepLift(s, t, 0, 1); walk.push(plain(t)); }
  assert.deepEqual(walk, [{ area: 'gap', id: 'audio', pos: 2 }, { area: 'gap', id: 'net', pos: 0 }, { area: 'plus', zone: 'right' }, { area: 'pool' }], 'on into the next group, the + and the pool');
  assert.deepEqual(plain(m.stepLift(s, { area: 'gap', id: 'net', pos: 0 }, 0, -1)), { area: 'gap', id: 'audio', pos: 2 }, 'k back to the group above, at its end');
  assert.deepEqual(plain(m.stepLift(s, { area: 'gap', id: 'audio', pos: 0 }, 0, -1)), { area: 'gap', id: 'audio', pos: 0 }, 'k from the first gap stays');
  assert.deepEqual(plain(m.stepLift(s, { area: 'gap', id: 'ai', pos: 3 }, 1, 0)), { area: 'plus', zone: 'centerLeft' }, 'the same index across, clamped to the +');
  assert.deepEqual(plain(m.stepLift(s, { area: 'plus', zone: 'centerRight' }, 1, 0)), { area: 'gap', id: 'audio', pos: 0 });
  assert.deepEqual(plain(m.stepLift(s, { area: 'gap', id: 'audio', pos: 2 }, -4, 0)), { area: 'plus', zone: 'centerRight' }, 'one zone a step');
  assert.deepEqual(plain(m.stepLift(s, { area: 'gap', id: 'audio', pos: 2 }, 1, 0)), { area: 'gap', id: 'audio', pos: 2 }, 'clamped at the last zone');
  assert.deepEqual(plain(m.stepLift(s, { area: 'plus', zone: 'center' }, 0, 1)), { area: 'pool' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 0, -1, 'ai')), { area: 'gap', id: 'ai', pos: 3 }, 'home\'s end');
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 0, -1, '')), { area: 'gap', id: 'audio', pos: 2 }, 'else the chosen group\'s');
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 0, -1, 'gone')), { area: 'gap', id: 'audio', pos: 2 });
  assert.deepEqual(plain(m.stepLift(state({ chosen: '' }), { area: 'pool' }, 0, -1)), { area: 'plus', zone: 'right' }, 'else the last zone\'s +');
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 1, 0)), { area: 'pool' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'pool' }, 0, 1)), { area: 'pool' });
});

test('a lifted face steps from zone to zone', () => {
  const s = state();
  assert.deepEqual(plain(m.stepLift(s, { area: 'zone', zone: 'left' }, 1, 0)), { area: 'zone', zone: 'centerLeft' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'zone', zone: 'left' }, -1, 0)), { area: 'zone', zone: 'left' });
  assert.deepEqual(plain(m.stepLift(s, { area: 'zone', zone: 'right' }, 0, 1)), { area: 'zone', zone: 'right' });
});

test('a drop says what changes', () => {
  const member = { key: 'k', group: 'ai' }, loose = { key: 'k', group: '' };
  assert.deepEqual(plain(m.dropAction(member, { area: 'pool' })), { op: 'assign', key: 'k', id: '', before: '' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'pool' })), { op: 'none' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'plus', zone: 'center' })), { op: 'create', key: 'k', zone: 'center' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'gap', id: 'audio', pos: 1 }, ['x', 'y'])), { op: 'assign', key: 'k', id: 'audio', before: 'y' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'gap', id: 'audio', pos: 2 }, ['x', 'y'])), { op: 'assign', key: 'k', id: 'audio', before: '' });
  assert.deepEqual(plain(m.dropAction(loose, { area: 'gap', id: 'net', pos: 0 }, [])), { op: 'assign', key: 'k', id: 'net', before: '' }, 'an empty group\'s one gap');
  assert.deepEqual(plain(m.dropAction(member, { area: 'gap', id: 'ai', pos: 1 }, ['x', 'y'], 1)), { op: 'none' }, 'its own place');
  assert.deepEqual(plain(m.dropAction(member, { area: 'gap', id: 'ai', pos: 0 }, ['x', 'y'], 1)), { op: 'assign', key: 'k', id: 'ai', before: 'x' });
  assert.deepEqual(plain(m.dropAction(member, { area: 'gap', id: 'audio', pos: 1 }, ['x', 'y'], 1)), { op: 'assign', key: 'k', id: 'audio', before: 'y' }, 'the same place in another group is a move');
  assert.deepEqual(plain(m.dropAction(member, { area: 'face', id: 'ai' })), { op: 'none' }, 'a face is no landing place');
  assert.deepEqual(plain(m.dropAction({ face: 'ai', zone: 'left' }, { area: 'zone', zone: 'right' })), { op: 'zone', id: 'ai', zone: 'right' });
  assert.deepEqual(plain(m.dropAction({ face: 'ai', zone: 'left' }, { area: 'zone', zone: 'left' })), { op: 'none' });
  assert.deepEqual(plain(m.dropAction(null, { area: 'pool' })), { op: 'none' });
});

test('a drop carried out by GroupsModel puts the widget where the list showed it', () => {
  const layout = { left: ['x', 'k', 'y'].map(key => ({ id: 'w', powerbarInstance: key })) };
  const config = { bar: { layout, powerbarGroups: [{ id: 'ai', section: 'left', items: ['x', 'k', 'y'] }] } };
  const into = ['x', 'y'];
  const act = m.dropAction({ key: 'k', group: 'ai' }, { area: 'gap', id: 'ai', pos: 2 }, into, 1);
  assert.equal(groups.assign(config, act.key, act.id, act.before), true);
  assert.deepEqual(plain(config.bar.powerbarGroups[0].items), ['x', 'y', 'k']);
});

test('shift j k moves a face past the next group in its zone, shift h l to the next zone', () => {
  const s = state({ faces: { left: ['a', 'b', 'c'], centerLeft: [], center: [], centerRight: [], right: [] }, members: {} });
  assert.equal(m.neighbourFace(s, 'b', 1), 'c');
  assert.equal(m.neighbourFace(s, 'b', -1), 'a');
  assert.equal(m.neighbourFace(s, 'c', 1), '', 'nothing past the end');
  assert.equal(m.neighbourFace(s, 'a', -1), '');
  assert.equal(m.neighbourFace(s, 'gone', 1), '');
  assert.equal(m.nextZone(zones, 'left', 1), 'centerLeft');
  assert.equal(m.nextZone(zones, 'left', -1), '');
  assert.equal(m.nextZone(zones, 'right', 1), '');
  // As the page carries it out: GroupsModel.moveHeader after (j) or before (k)
  // the neighbour; a hidden group moves as shown and is hidden again.
  const layout = { left: [{ id: 'w', powerbarInstance: 'p' }, { id: 'w', powerbarInstance: 'q' }] };
  const config = { bar: { layout, powerbarGroups: [
    { id: 'a', section: 'left', before: 'p' }, { id: 'b', section: 'left', before: 'q', visibility: 'hidden' }, { id: 'c', section: 'left', before: '' }
  ] } };
  const order = () => m.railFaces(groups.render(layout, m.railGroups(groups.groups(config.bar))), zones).left;
  assert.deepEqual(plain(order()), ['a', 'b', 'c']);
  assert.equal(groups.moveHeader(config, 'a', 'left', '', 'b', true, 'shown'), true);
  assert.deepEqual(plain(order()), ['b', 'a', 'c']);
  assert.equal(groups.moveHeader(config, 'b', 'left', '', 'c', true, 'hidden'), false, 'moveHeader refuses a hidden group');
  assert.equal(groups.moveHeader(config, 'b', 'left', '', 'a', true, 'shown'), true);
  assert.equal(groups.edit(config, 'b', { visibility: 'hidden' }), true);
  assert.deepEqual(plain(order()), ['a', 'b', 'c']);
  assert.equal(groups.groups(config.bar).find(g => g.id === 'b').visibility, 'hidden');
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

test('the plates share the room, the list met before the pool', () => {
  const g = { pad: 8, nameRow: 20, chip: 24, gap: 3, zoneRows: [5, 0, 2], poolRows: 6, poolGap: 8, poolLabel: 90 };
  const need = m.plateNeeds(g);
  assert.equal(m.listWindow, 8);
  assert.deepEqual(plain(need.demands), [36 + 6 * 24 + 5 * 3, 16 + 6 * 24 + 5 * 8]);
  assert.deepEqual(plain(need.floors), [36 + 2 * 24 + 3, 90]);
  assert.deepEqual(plain(need.first), [0]);
  assert.equal(m.plateNeeds({ ...g, zoneRows: [12] }).demands[0], 36 + 9 * 24 + 8 * 3, 'eight rows at most, and the +');
  assert.equal(m.plateNeeds({ ...g, zoneRows: [] }).demands[0], need.floors[0], 'no groups: a row and the +');
  assert.equal(m.plateNeeds({ ...g, poolRows: 0, poolLabel: 10 }).demands[1], 16 + 24);
  assert.equal(m.plateNeeds({ ...g, labelRoom: 30 }).floors[1], 60, 'the label may hang into the legend\'s spare room');
  assert.equal(m.plateNeeds({ ...g, labelRoom: 300 }).floors[1], 16 + 24, 'never under a row');
  assert.equal(m.plateNeeds({ ...g, labelRoom: 30 }).demands[1], need.demands[1], 'it asks for its whole label');
  const seen = h => prefs.tiltedHeight(h, 34, 1600);
  const share = room => plain(prefs.shareLayers(need.demands, need.floors, room, 34, 1600, 30, need.first));
  const near = (a, b) => Math.abs(a - b) < 1e-6;
  const roomy = share(2000);
  need.demands.forEach((d, i) => assert.ok(near(roomy[i], d), 'all they ask for while it fits'));
  const tight = share(seen(need.demands[0]) + seen(90) + 30 + 10);
  assert.ok(near(tight[0], need.demands[0]), 'the list gets all it asks for first');
  assert.ok(tight[1] > 90 && tight[1] < need.demands[1], 'the pool takes what is left over its floor');
  const tighter = share(seen(150) + seen(90) + 30);
  assert.ok(near(tighter[1], 90), 'the pool keeps only its floor while the list wants more');
  assert.ok(tighter[0] < need.demands[0] && tighter[0] > need.floors[0], 'the list takes the rest');
  const floor = share(100);
  need.floors.forEach((f, i) => assert.ok(near(floor[i], f), 'floors win over the room'));
});

test('the + row follows the list, the window eight rows at most', () => {
  assert.deepEqual(plain(m.listView(0, 24, 3)), { rows: 0, height: 0 });
  assert.deepEqual(plain(m.listView(1, 24, 3)), { rows: 1, height: 24 });
  assert.deepEqual(plain(m.listView(8, 24, 3)), { rows: 8, height: 8 * 24 + 7 * 3 });
  assert.deepEqual(plain(m.listView(11, 24, 3)), { rows: 8, height: 8 * 24 + 7 * 3 }, 'more scroll in the window');
});

test('zoneMove: a face carried away and back finds its place while the anchor is there', () => {
  const layout = { left: [{ powerbarInstance: 'a' }, { powerbarInstance: 'b' }], right: [{ powerbarInstance: 'c' }] };
  const out = m.zoneMove({}, { id: 'g', section: 'left', before: 'b' }, 'right', layout);
  assert.deepEqual({ ...out.patch }, { section: 'right', before: '' }, 'a new zone: its end');
  const back = m.zoneMove(out.memory, { id: 'g', section: 'right', before: '' }, 'left', layout);
  assert.deepEqual({ ...back.patch }, { section: 'left', before: 'b' }, 'back: before b again');
  const gone = m.zoneMove(out.memory, { id: 'g', section: 'right', before: '' }, 'left', { left: [{ powerbarInstance: 'a' }] });
  assert.equal(gone.patch.before, '', 'the anchor left: the zone end');
  assert.equal(m.zoneMove(out.memory, { id: 'h', section: 'right', before: 'c' }, 'left', layout).patch.before, '', 'memory is per group');
});
