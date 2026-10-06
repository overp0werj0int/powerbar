const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../GroupsModel.js`, 'utf8'), m);
const fixture = () => ({ bar: { layout: { left: [
  { id: 'clock', powerbarInstance: 'one', format: 'HH:mm', powerbarVisibility: 'managed' },
  { id: 'clock', powerbarInstance: 'two', format: 'ddd' },
  { id: 'network', powerbarInstance: 'three', nested: { preserved: true } }
], center: [], right: [] } }, plugins: [{ id: 'service', settings: { keep: true } }] });
const plain = value => JSON.parse(JSON.stringify(value));
test('group visibility and placement change without changing member settings', () => {
  const c = fixture(), original = JSON.stringify(c.bar.layout);
  m.create(c, 'a', 'A'); m.assign(c, 'one', 'a');
  m.edit(c, 'a', { section: 'center', visibility: 'hidden', icon: '󰤨', label: 'Network' });
  assert.equal(m.render(c.bar.layout, m.groups(c.bar)).center.length, 0);
  m.edit(c, 'a', { visibility: 'managed' });
  const header = m.render(c.bar.layout, m.groups(c.bar)).center[0];
  assert.equal(header.powerbarVisibility, 'managed');
  assert.equal(header.powerbarInstance, 'group:a');
  assert.equal(JSON.stringify(c.bar.layout), original);
  assert.deepEqual(plain(m.groups(c.bar)[0].items), ['one']);
});
test('group membership preserves widget instances, settings, visibility and service config', () => {
  const c = fixture(), before = JSON.stringify(c.bar.layout), plugins = JSON.stringify(c.plugins);
  assert.equal(m.create(c, 'tools', 'Tools'), true);
  assert.equal(m.assign(c, 'two', 'tools'), true);
  assert.equal(m.owner(m.groups(c.bar), 'one'), null);
  assert.equal(m.owner(m.groups(c.bar), 'two').id, 'tools');
  assert.equal(JSON.stringify(c.bar.layout), before);
  assert.equal(JSON.stringify(c.plugins), plugins);
  assert.equal(m.remove(c, 'tools'), true);
  assert.equal(m.owner(m.groups(c.bar), 'two'), null);
  assert.equal(JSON.stringify(c.bar.layout), before);
});
test('transfer and reorder are exclusive, stable and reversible', () => {
  const c = fixture(); m.create(c, 'a', 'A'); m.create(c, 'b', 'B');
  m.assign(c, 'one', 'a'); m.assign(c, 'two', 'a'); m.assign(c, 'three', 'a', 'two');
  assert.deepEqual(plain(m.groups(c.bar)[0].items), ['one', 'three', 'two']);
  m.assign(c, 'two', 'a', 'one');
  assert.deepEqual(plain(m.groups(c.bar)[0].items), ['two', 'one', 'three']);
  m.assign(c, 'one', 'b');
  assert.deepEqual(plain(m.groups(c.bar)[0].items), ['two', 'three']);
  assert.deepEqual(plain(m.groups(c.bar)[1].items), ['one']);
  m.assign(c, 'one', ''); assert.equal(m.owner(m.groups(c.bar), 'one'), null);
});
test('stale destinations, unknown widgets and duplicate IDs do not lose membership', () => {
  const c = fixture(); m.create(c, 'a', 'A'); m.assign(c, 'one', 'a');
  const before = JSON.stringify(c);
  assert.equal(m.assign(c, 'one', 'missing'), false);
  assert.equal(m.assign(c, 'unknown', 'a'), false);
  assert.equal(m.assign(c, 'group:a', 'a'), false);
  assert.equal(m.create(c, 'a', 'duplicate'), false);
  assert.equal(JSON.stringify(c), before);
});
test('group header placement is a runtime projection, not a duplicated widget', () => {
  const c = fixture(); m.create(c, 'a', 'A'); m.edit(c, 'a', { section: 'left', before: 'two' });
  const before = JSON.stringify(c.bar.layout), rendered = m.render(c.bar.layout, m.groups(c.bar));
  assert.deepEqual(plain(rendered.left.map(e => e.powerbarInstance)), ['one', 'group:a', 'two', 'three']);
  assert.equal(JSON.stringify(c.bar.layout), before);
});
test('group icons reorder around other groups without nesting', () => {
  const c = fixture(); m.create(c, 'a', 'A'); m.create(c, 'b', 'B');
  m.edit(c, 'a', { section: 'left', before: 'two' });
  m.edit(c, 'b', { section: 'left', before: 'two' });
  assert.equal(m.moveHeader(c, 'a', 'left', '', 'b', true, 'shown'), true);
  assert.deepEqual(plain(m.render(c.bar.layout, m.groups(c.bar)).left.map(e => e.powerbarInstance)),
    ['one', 'group:b', 'group:a', 'two', 'three']);
  assert.equal(m.moveHeader(c, 'a', 'right', '', '', false, 'managed'), true);
  assert.equal(m.groups(c.bar).find(g => g.id === 'a').visibility, 'managed');
  assert.equal(m.render(c.bar.layout, m.groups(c.bar)).right[0].powerbarInstance, 'group:a');
});
test('malformed manual config does not nest groups or assign one instance twice', () => {
  const list = m.groups({ powerbarGroups: [null, { id: 'a', items: ['one', 'one', 'group:b'] }, { id: 'a' }, { id: 'b', items: ['one', 'two'] }] });
  assert.deepEqual(plain(list.map(g => g.items)), [['one'], ['two']]);
});

test('group display options preserve membership and reject unknown values', () => {
  const c = fixture(); m.create(c, 'a', 'Tools'); m.assign(c, 'one', 'a');
  m.edit(c, 'a', { face: 'both', tooltip: false, badge: false,
    badgeMode: 'members', memberDisplay: 'name' });
  const group = m.groups(c.bar)[0];
  assert.equal(group.face, 'both'); assert.equal(group.tooltip, false);
  assert.equal(group.badge, false); assert.equal(group.badgeMode, 'members');
  assert.equal(group.memberDisplay, 'name');
  assert.deepEqual(plain(group.items), ['one']);
  m.edit(c, 'a', { face: 'bad', memberDisplay: 'bad' });
  assert.equal(m.groups(c.bar)[0].face, 'both');
});

test('a group has no orientation: its strip follows the bar, an old saved value is dropped', () => {
  const c = fixture(); m.create(c, 'a', 'Tools');
  c.bar.powerbarGroups[0].orientation = 'vertical';
  assert.equal('orientation' in m.groups(c.bar)[0], false);
  m.edit(c, 'a', { orientation: 'horizontal', face: 'both' });
  assert.equal('orientation' in c.bar.powerbarGroups[0], false);
});

test('a group keeps its place when its anchor widget moves away', () => {
  const c = fixture();
  m.create(c, 'a', 'A');
  m.edit(c, 'a', { section: 'left', before: 'two' });
  const at = () => m.render(c.bar.layout, m.groups(c.bar)).left.map(e => e.powerbarInstance);
  assert.deepEqual(at(), ['one', 'group:a', 'two', 'three']);
  // 'two' moves to the zone's start (as a drop on the zone's dots does).
  const next = m.nextAnchor(c, 'left', 'two');
  const moved = c.bar.layout.left.splice(1, 1)[0];
  c.bar.layout.left.unshift(moved);
  assert.equal(m.reanchor(c, 'left', 'two', next), true);
  assert.deepEqual(at(), ['two', 'one', 'group:a', 'three']);
});

test('a group anchored on the last widget keeps the zone end when it leaves', () => {
  const c = fixture();
  m.create(c, 'a', 'A');
  m.edit(c, 'a', { section: 'left', before: 'three' });
  const next = m.nextAnchor(c, 'left', 'three');
  assert.equal(next, '');
  const moved = c.bar.layout.left.pop();
  c.bar.layout.right.push(moved);
  assert.equal(m.reanchor(c, 'left', 'three', next), true);
  assert.deepEqual(m.render(c.bar.layout, m.groups(c.bar)).left.map(e => e.powerbarInstance), ['one', 'two', 'group:a']);
});

test('a visibility change in place leaves the group anchored', () => {
  const c = fixture();
  m.create(c, 'a', 'A');
  m.edit(c, 'a', { section: 'left', before: 'two' });
  const next = m.nextAnchor(c, 'left', 'two');
  c.bar.layout.left[1].powerbarVisibility = 'managed';
  assert.equal(m.reanchor(c, 'left', 'two', next), false);
  assert.equal(m.groups(c.bar)[0].before, 'two');
});

test('icons keep their font, your own image and its colour; old groups save unchanged', () => {
  const groupsModel = vm.createContext({});
  vm.runInContext(fs.readFileSync(`${__dirname}/../GroupsModel.js`, 'utf8'), groupsModel);
  const config = { bar: { layout: { left: [], center: [], right: [] },
    powerbarGroups: [{ id: 'g', label: 'AI', icon: '\u{f024b}', section: 'left', items: [] }] } };
  groupsModel.edit(config, 'g', { label: 'AI' });
  assert.deepEqual(Object.keys(JSON.parse(JSON.stringify(config.bar.powerbarGroups[0]))).filter(k => k.startsWith('iconF') || k === 'iconImage' || k === 'iconTint'), []);
  groupsModel.edit(config, 'g', { icon: '', iconFont: 'omarchy' });
  let g = groupsModel.groups(config.bar)[0];
  assert.equal(g.iconFont, 'omarchy');
  assert.equal(groupsModel.groupIconFont(g), 'omarchy');
  groupsModel.edit(config, 'g', { iconImage: '/home/u/.local/share/powerbar/icons/a.svg', iconTint: 'own' });
  g = groupsModel.groups(config.bar)[0];
  assert.equal(g.iconImage, '/home/u/.local/share/powerbar/icons/a.svg');
  assert.equal(g.iconTint, 'own');
  assert.equal(groupsModel.needsRuns(g, 'glyph'), true);
  assert.equal(groupsModel.faceRuns(g, 'glyph')[0].kind, 'image');
  assert.equal(groupsModel.faceRuns(g, 'glyph')[0].tint, false);
  // Choosing a glyph again drops the image and the old font.
  groupsModel.edit(config, 'g', { icon: '\u{f06a9}' });
  g = groupsModel.groups(config.bar)[0];
  assert.equal(g.iconImage, undefined);
  assert.equal(g.iconFont, undefined);
  assert.equal(groupsModel.needsRuns(g, 'glyph'), false);
  assert.equal(groupsModel.needsRuns(g, 'both'), true);
  // A group saved before icons kept their font: the logo still finds its font.
  assert.equal(groupsModel.groupIconFont({ icon: '' }), 'omarchy');
  assert.equal(groupsModel.needsRuns({ icon: '', face: 'both', label: 'AI' }), true);
  assert.deepEqual(JSON.parse(JSON.stringify(groupsModel.faceRuns({ icon: '', face: 'both', label: 'AI' }).map(r => r.font))), ['omarchy', '', '']);
});

test('members whose widget was uninstalled leave the group; nothing is pruned without a layout', () => {
  const groupsModel = vm.createContext({});
  vm.runInContext(fs.readFileSync(`${__dirname}/../GroupsModel.js`, 'utf8'), groupsModel);
  const bar = { layout: { left: [{ id: 'a', powerbarInstance: 'pw-a' }], center: [], right: [{ id: 'b', powerbarInstance: 'pw-b' }] },
    powerbarGroups: [{ id: 'g', label: 'AI', items: ['pw-a', 'pw-gone', 'pw-b', 'pw-also-gone'] }, { id: 'h', label: 'H', items: ['pw-gone2'] }] };
  assert.equal(groupsModel.danglingMembers(bar), 3);
  assert.deepEqual(JSON.parse(JSON.stringify(groupsModel.groups(bar).map(g => g.items))), [['pw-a', 'pw-b'], []]);
  // The group itself stays, even when every member is gone.
  assert.equal(groupsModel.groups(bar).length, 2);
  // Written back once: nothing left to prune.
  bar.powerbarGroups = groupsModel.groups(bar);
  assert.equal(groupsModel.danglingMembers(bar), 0);
  // No layout keys to check against (a config still loading): keep every member.
  const bare = { layout: { left: [], center: [], right: [] }, powerbarGroups: [{ id: 'g', label: 'AI', items: ['pw-x'] }] };
  assert.equal(groupsModel.danglingMembers(bare), 0);
  assert.deepEqual(JSON.parse(JSON.stringify(groupsModel.groups(bare)[0].items)), ['pw-x']);
});
