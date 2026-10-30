// What Powerbar writes back into a bar config the host hands it: the instance
// ids and the first-start flags (INTEG-113, INTEG-114, KEYS-84), keys another
// writer dropped (INTEG-148), group members whose widget is gone (INTEG-40),
// earlier versions' appearance keys (LOOK-48), themes no longer installed
// (LOOK-55) and the retired zone modes' arrangements (ZONE-92). Each case is a
// config as delivered and the bar config shell.json ends with.
const test = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');
const model = load('HealModel.js');
const J = (v) => JSON.parse(JSON.stringify(v));

// The heal decided on the delivered config and applied to it, as the store
// queues it. → { bar: what shell.json holds, written }
function heal(delivered, ctx) {
  const before = J(delivered);
  const plan = model.heal(delivered, ctx);
  assert.deepEqual(delivered, before, 'deciding changes nothing');
  const bar = J(delivered);
  if (plan) model.apply(bar, J(plan));
  return { bar: J(bar), written: !!plan };
}

// Bar.qml's thirdPartyEntry while the registry is loading: by id.
const thirdParty = (entry) => !String(typeof entry === 'string' ? entry : entry.id).startsWith('omarchy.');
function context(previous, extra) {
  let n = 0;
  return Object.assign({ previous, theme: 'nord', thirdParty, newInstance: () => `pw-new${++n}` }, extra);
}
// The host delivers what was written: healing it again finds nothing to do.
function settles(result, extra) {
  const again = heal(result.bar, context(J(result.bar.layout), extra));
  assert.equal(again.written, false, 'a healed config heals to itself');
  assert.deepEqual(again.bar, result.bar);
}

const stock = () => ({
  id: 'p0werj0int.powerbar', position: 'top',
  layout: {
    left: ['omarchy.menu', { id: 'omarchy.workspaces' }], centerBegin: [],
    center: [{ id: 'omarchy.clock', format: 'HH:mm' }], centerEnd: [],
    right: [{ id: 'omarchy.tray', pinned: [], hidden: [] }, 'omarchy.network'], tray: [],
  },
});
const healthy = () => ({
  id: 'p0werj0int.powerbar', position: 'top', powerbarVisibilityDefault: 'shown',
  layout: {
    left: [{ id: 'omarchy.menu', powerbarInstance: 'pw-menu' }], centerBegin: [],
    center: [{ id: 'omarchy.clock', format: 'HH:mm', powerbarInstance: 'pw-clock' }], centerEnd: [],
    right: [
      { id: 'omarchy.tray', pinned: [], hidden: [], powerbarInstance: 'pw-tray', powerbarVisibility: 'managed' },
      { id: 'omarchy.power', powerbarInstance: 'pw-power' },
    ],
    tray: [],
  },
  powerbarGroups: [{ id: 'g', label: 'System', icon: 'x', section: 'right', before: '', visibility: 'shown',
    face: 'glyph', badge: true, badgeMode: 'sum', memberDisplay: 'native', items: ['pw-clock', 'pw-power'] }],
});

test('omarchy bar put on a stock config: ids for every entry, the visibility marker and the shortcut offer', () => {
  const result = heal(stock(), context(null));
  assert.equal(result.written, true);
  assert.deepEqual(result.bar, {
    id: 'p0werj0int.powerbar', position: 'top', powerbarShortcutOffer: true, powerbarVisibilityDefault: 'shown',
    layout: {
      left: [{ id: 'omarchy.menu', powerbarInstance: 'pw-new1' }, { id: 'omarchy.workspaces', powerbarInstance: 'pw-new2' }],
      centerBegin: [], center: [{ id: 'omarchy.clock', format: 'HH:mm', powerbarInstance: 'pw-new3' }], centerEnd: [],
      right: [{ id: 'omarchy.tray', pinned: [], hidden: [], powerbarInstance: 'pw-new4' },
        { id: 'omarchy.network', powerbarInstance: 'pw-new5' }],
      tray: [],
    },
  });
  settles(result);
});

test('an upgrade from the old visibility default: third-party widgets stay On demand, a duplicate id is re-keyed', () => {
  const bar = healthy();
  delete bar.powerbarVisibilityDefault;
  bar.layout.centerEnd = [{ id: 'acme.weather', powerbarInstance: 'pw-acme' }, { id: 'acme.placed', powerbarInstance: 'pw-placed', powerbarVisibility: 'shown' }];
  bar.layout.tray = [{ id: 'omarchy.bluetooth', powerbarInstance: 'pw-menu' }];
  const result = heal(bar, context(J(bar.layout)));
  const expected = healthy();
  expected.layout.centerEnd = [{ id: 'acme.weather', powerbarInstance: 'pw-acme', powerbarVisibility: 'managed' },
    { id: 'acme.placed', powerbarInstance: 'pw-placed', powerbarVisibility: 'shown' }];
  expected.layout.tray = [{ id: 'omarchy.bluetooth', powerbarInstance: 'pw-new1' }];
  assert.deepEqual(result.bar, expected, 'no shortcut offer on a config Powerbar ran on');
  settles(result);
});

test('a widget Omarchy adds gets an id and nothing else', () => {
  const bar = healthy();
  bar.layout.centerEnd.push({ id: 'acme.new' });
  const result = heal(bar, context(healthy().layout));
  const expected = healthy();
  expected.layout.centerEnd.push({ id: 'acme.new', powerbarInstance: 'pw-new1' });
  assert.deepEqual(result.bar, expected);
  settles(result);
});

test("a clock rewritten by its format cycle keeps its instance and its group", () => {
  const bar = healthy();
  bar.layout.center[0] = { id: 'omarchy.clock', format: 'h:mm AP' };
  const result = heal(bar, context(healthy().layout));
  const expected = healthy();
  expected.layout.center[0] = { id: 'omarchy.clock', format: 'h:mm AP', powerbarInstance: 'pw-clock' };
  assert.deepEqual(result.bar, expected);
  settles(result);
});

test('the tray pinning an icon keeps its On demand setting', () => {
  const bar = healthy();
  bar.layout.right[0] = { id: 'omarchy.tray', pinned: ['steam'], hidden: [] };
  const result = heal(bar, context(healthy().layout));
  const expected = healthy();
  expected.layout.right[0] = { id: 'omarchy.tray', pinned: ['steam'], hidden: [], powerbarInstance: 'pw-tray', powerbarVisibility: 'managed' };
  assert.deepEqual(result.bar, expected);
  settles(result);
});

test("an uninstalled widget leaves its group, written as groups() reads it", () => {
  const bar = healthy();
  bar.powerbarGroups.push({ id: 'h', label: 'Apps', icon: 'y', items: ['pw-gone', 'pw-menu'] });
  bar.powerbarGroups[0].items.push('pw-gone2');
  const result = heal(bar, context(J(bar.layout)));
  const expected = healthy();
  expected.powerbarGroups.push({ id: 'h', label: 'Apps', icon: 'y', section: 'right', before: '', visibility: 'shown',
    face: 'glyph', badge: true, badgeMode: 'sum', memberDisplay: 'native', items: ['pw-menu'] });
  assert.deepEqual(result.bar, expected);
  settles(result);
});

test("earlier versions' appearance keys become the current theme's own, once the theme is known", () => {
  const bar = Object.assign(healthy(), { powerbarBlur: false, powerbarIslandRounding: 8 });
  const waiting = heal(bar, context(J(bar.layout), { theme: '' }));
  assert.equal(waiting.written, false, 'waits for the theme');
  const result = heal(bar, context(J(bar.layout)));
  assert.deepEqual(result.bar, Object.assign(healthy(), { powerbarAppearance: { themes: { nord: {
    shape: { use: 'this', rounding: 8 }, surface: { use: 'this', blur: false } } } } }));
  settles(result);
});

test('themes no longer installed lose their values, only from a theme listing', () => {
  const bar = Object.assign(healthy(), { powerbarAppearance: { themes: { gone: { text: 'dark' }, nord: { text: 'light' } } } });
  assert.equal(heal(bar, context(J(bar.layout))).written, false, 'a config alone prunes nothing');
  const result = heal(bar, context(J(bar.layout), { installedThemes: ['lumon'] }));
  assert.deepEqual(result.bar, Object.assign(healthy(), { powerbarAppearance: { themes: { nord: { text: 'light' } } } }),
    'the current theme is kept');
  settles(result, { installedThemes: ['lumon'] });
});

test("the zone modes' arrangements leave shell.json once their copy is saved", () => {
  const bar = Object.assign(healthy(), { powerbarZoneLayouts: { two: { left: [] } } });
  assert.equal(heal(bar, context(J(bar.layout))).written, false, 'kept until the copy is saved');
  const result = heal(bar, context(J(bar.layout), { zoneModesSaved: true }));
  assert.deepEqual(result.bar, healthy());
});

test('a healthy config writes nothing', () => {
  assert.equal(heal(healthy(), context(healthy().layout)).written, false);
  assert.equal(heal(healthy(), context(null)).written, false);
});

// The store runs a queued heal again on every config the host delivers before
// it is written, and at the write.
test('run again, on the same config or a newer one, the heal writes the ids it decided', () => {
  const plan = model.heal(stock(), context(null));
  const once = J(stock());
  model.apply(once, plan);
  const twice = J(once);
  model.apply(twice, plan);
  assert.deepEqual(twice, once, 'a second run changes nothing');
  const newer = stock();
  newer.layout.center[0].format = 'h:mm AP';
  model.apply(newer, plan);
  assert.equal(newer.layout.center[0].powerbarInstance, once.layout.center[0].powerbarInstance);
  assert.equal(newer.layout.center[0].format, 'h:mm AP', "the host's change stays");
  assert.deepEqual(J(newer.layout.right), once.layout.right);
});

test('an entry that is no longer where the heal found it is left for the next heal', () => {
  const bar = healthy();
  bar.layout.centerEnd = [{ id: 'acme.new' }];
  const plan = model.heal(bar, context(healthy().layout));
  const newer = J(bar);
  newer.layout.centerEnd.unshift({ id: 'acme.other' });
  model.apply(newer, plan);
  assert.deepEqual(newer.layout.centerEnd, [{ id: 'acme.other' }, { id: 'acme.new' }], 'no id lands on the wrong widget');
});

test('a key another writer set after the heal was decided stays', () => {
  const bar = healthy();
  bar.layout.right[0] = { id: 'omarchy.tray', pinned: ['steam'], hidden: [] };
  const plan = model.heal(bar, context(healthy().layout));
  const newer = J(bar);
  newer.layout.right[0].powerbarVisibility = 'hidden';
  model.apply(newer, plan);
  assert.deepEqual(newer.layout.right[0], { id: 'omarchy.tray', pinned: ['steam'], hidden: [], powerbarVisibility: 'hidden', powerbarInstance: 'pw-tray' });
});

test("an earlier queued heal does not take a member out of its group before a later one restores its key", () => {
  const delivered = healthy();
  delivered.powerbarGroups[0].items.push('pw-gone');
  const first = model.heal(delivered, context(healthy().layout));
  assert.deepEqual(J(first.members), ['pw-gone']);
  // Shown: the delivered config with the first heal. The clock's format cycle
  // then delivers it without its instance; the store shows the queued heal on
  // top, and the bar heals what it would show.
  const shown = J(delivered);
  model.apply(shown, first);
  const host = J(delivered);
  host.layout.center[0] = { id: 'omarchy.clock', format: 'h:mm AP' };
  const preview = J(host);
  model.apply(preview, first);
  const second = model.heal(preview, context(J(shown.layout)));
  // The write: both heals, in queue order, on the host's config.
  const written = J(host);
  model.apply(written, first);
  model.apply(written, second);
  const expected = healthy();
  expected.layout.center[0] = { id: 'omarchy.clock', format: 'h:mm AP', powerbarInstance: 'pw-clock' };
  assert.deepEqual(J(written), expected);
});
