// What Powerbar writes back into a bar config the host hands it: the instance
// ids and the first-start flags (INTEG-113, INTEG-114, KEYS-84), keys another
// writer dropped (INTEG-148), group members whose widget is gone (INTEG-40),
// earlier versions' appearance keys (LOOK-48), themes no longer installed
// (LOOK-55) and the retired zone modes' arrangements (ZONE-92). Each case is a
// config as delivered and the bar config shell.json ends with.
const test = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');
const barModel = load('BarModel.js');
const managed = load('ManagedModel.js');
const groupsModel = load('GroupsModel.js');
const appearance = load('AppearanceModel.js');
const sections = load('SectionsModel.js');
const J = (v) => JSON.parse(JSON.stringify(v));

// Bar.qml's self-writes for a delivered config, in the order they land:
// restoreLostKeys, ensureInstanceIds, pruneGroupMembers, healAppearance, then
// pruneAppearanceThemes after a theme listing and the zone modes' retirement
// after their copy. → { bar: what shell.json holds, written }
function heal(delivered, ctx) {
  const bar = J(delivered);
  let written = false;
  const plan = barModel.lostKeys(ctx.previous, bar.layout);
  if (plan.length) { barModel.applyLostKeys(bar, plan); written = true; }
  if (bar.layout) {
    let missing = bar.powerbarVisibilityDefault !== 'shown';
    const seen = {};
    for (const zone of sections.sections) {
      for (const entry of bar.layout[zone] || []) {
        const key = entry && entry.powerbarInstance;
        if (!key || seen[key]) missing = true;
        seen[key] = true;
      }
    }
    if (missing) {
      if (!managed.powerbarHasRun(bar)) bar.powerbarShortcutOffer = true;
      managed.healVisibility(bar, ctx.thirdParty);
      const used = {};
      for (const zone of sections.sections) {
        const entries = bar.layout[zone] || [];
        for (let i = 0; i < entries.length; i++) {
          const entry = typeof entries[i] === 'string' ? { id: entries[i] } : entries[i];
          if (!entry.powerbarInstance || used[entry.powerbarInstance]) entry.powerbarInstance = ctx.newInstance();
          used[entry.powerbarInstance] = true;
          entries[i] = entry;
        }
      }
      written = true;
    }
  }
  if (groupsModel.danglingMembers(bar)) { bar.powerbarGroups = groupsModel.groups(bar); written = true; }
  if (ctx.theme && appearance.legacyPresent(bar)) { appearance.migrate(bar, ctx.theme); written = true; }
  const keep = (ctx.installedThemes || []).concat(ctx.theme ? [ctx.theme] : []);
  if (ctx.installedThemes && ctx.installedThemes.length && appearance.hasStaleThemes(bar, keep)) {
    appearance.pruneThemes(bar, keep); written = true;
  }
  if (ctx.zoneModesSaved) { delete bar.powerbarZoneLayouts; written = true; }
  return { bar: J(bar), written };
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
