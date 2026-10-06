// A clean Omarchy install switching to Powerbar: shell.json holds Omarchy's
// default bar and no powerbar* key. Powerbar must then look and behave like
// Omarchy's bar, plus its Preferences button, until the user changes something.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const plain = value => JSON.parse(JSON.stringify(value)); // vm objects differ in realm
const bar = load('BarModel.js');
const managed = load('ManagedModel.js');
const prefs = load('PreferencesModel.js');
const appearance = load('AppearanceModel.js');
const cell = load('CellModel.js');
const groups = load('GroupsModel.js');
const shortcuts = load('ShortcutModel.js');
const zoneFit = load('ZoneFitModel.js');

// Omarchy's config/omarchy/shell.json bar, as a clean install has it.
const stock = () => ({
  position: 'top', transparent: false, centerAnchor: 'omarchy.clock',
  layout: {
    left: [{ id: 'omarchy.menu' }, { id: 'omarchy.workspaces' }],
    center: [{ id: 'omarchy.indicators' },
      { id: 'omarchy.clock', format: 'dddd HH:mm', formatAlt: "d MMMM 'W'ww yyyy", verticalFormat: 'HH\n—\nmm' },
      { id: 'omarchy.keyboard-layout' }, { id: 'omarchy.weather' }, { id: 'omarchy.system-update' }],
    right: [{ id: 'omarchy.tray' }, { id: 'omarchy.agents' }, { id: 'omarchy.bluetooth' }, { id: 'omarchy.network' },
      { id: 'omarchy.audio' }, { id: 'omarchy.monitor' }, { id: 'omarchy.power' }]
  }
});
// The size Omarchy's Style gives a horizontal bar without a theme override
// (Style.bar.sizeHorizontal), and its icon slot (Style.bar.iconSlot).
const OMARCHY_BAR = 26, OMARCHY_ICON_SLOT = 27;
const firstParty = { firstParty: true };

test('clean config gives a stock-like bar: flat, top, always out, theme size', () => {
  assert.deepEqual(plain(bar.options(stock())), {
    style: 'flat', autoHide: false, autoHideActivity: true, largeBar: false,
    spacingMode: 'slots', onDemand: 'drawer', animations: true, keyLegend: true, dotsBadge: true
  });
  assert.deepEqual(plain(bar.options(undefined)), plain(bar.options({})));
  assert.equal(bar.normalizePosition(stock().position), 'top');
  assert.equal(bar.normalizePosition(undefined), 'top');
});

test('clean config keeps every option the user set', () => {
  const set = Object.assign(stock(), {
    powerbarStyle: 'islands', powerbarAutoHide: true, powerbarAutoHideActivity: false, powerbarLargeBar: true,
    powerbarSpacingMode: 'gaps', powerbarOnDemand: 'inline', powerbarAnimations: false,
    powerbarKeyLegend: false, powerbarDotsBadge: false
  });
  assert.deepEqual(plain(bar.options(set)), {
    style: 'islands', autoHide: true, autoHideActivity: false, largeBar: true,
    spacingMode: 'gaps', onDemand: 'inline', animations: false, keyLegend: false, dotsBadge: false
  });
  assert.equal(bar.options({ powerbarIslands: true }).style, 'islands');
});

test('clean config spaces icons as Omarchy does: one 27 px icon slot apart', () => {
  const spacing = appearance.clampTo(appearance.ranges.spacing, stock().powerbarSpacing);
  assert.equal(spacing, 4);
  const k = cell.tokens({ bar: OMARCHY_BAR, spacing, mode: bar.options(stock()).spacingMode });
  assert.equal(cell.place(k, 13, true).extent, OMARCHY_ICON_SLOT);
  // A spacing the user chose stays theirs, None included.
  assert.equal(appearance.clampTo(appearance.ranges.spacing, 0), 0);
});

test('a flat bar keeps its end glyphs where Omarchy has them: section margin plus half an icon slot', () => {
  // Omarchy: the left section starts Style.space(8) in, its first icon slot is 27 wide.
  const stockCentre = 8 + OMARCHY_ICON_SLOT / 2;
  for (const size of [OMARCHY_BAR, 28, OMARCHY_BAR + 12]) // horizontal, vertical, large
    for (const mode of ['slots', 'gaps']) {
      const k = cell.tokens({ bar: size, spacing: 4, mode });
      const p = cell.place(k, 12, true);
      const inset = cell.flatEdge(k, 8, OMARCHY_ICON_SLOT);
      // The left zone starts at inset + endPad; its first glyph's ink is centred in its slot.
      const centre = inset + cell.endPad(k, p.spill) + p.inkStart + p.shown / 2;
      assert.equal(centre, stockCentre, `${size} ${mode}`);
    }
  assert.equal(cell.flatEdge(cell.tokens({ bar: OMARCHY_BAR, spacing: 4 }), 8, OMARCHY_ICON_SLOT), 8.5);
});

test('clean config looks like the theme: no Powerbar-only blur, shadow or surface', () => {
  const look = plain(appearance.resolve(undefined, 'tokyo-night', {}));
  assert.deepEqual(look.scopes, { shape: 'theme', surface: 'theme', shadow: 'theme' });
  assert.equal(look.text, 'theme');
  const effects = appearance.effects(stock(), 1);
  assert.equal(effects.blur, false);
  assert.equal(effects.shadow, false);
  assert.equal(effects.backgroundOpacity, 1);
  assert.equal(appearance.foreground(stock(), 'tokyo-night'), 'theme');
});

test('clean config shows every stock widget on the bar, in stock order, with nothing on demand', () => {
  const config = stock();
  for (const section of ['left', 'center', 'right']) {
    for (const entry of config.layout[section]) {
      assert.equal(managed.mode(entry, firstParty), 'shown', entry.id);
      assert.equal(prefs.mode(entry, firstParty), 'shown', entry.id);
    }
  }
  assert.deepEqual(plain(groups.groups(config)), []);
  const rendered = plain(groups.render(config.layout, groups.groups(config)));
  for (const section of ['left', 'center', 'right']) {
    const pinned = plain(bar.pinTrayToInner(rendered[section], section));
    assert.deepEqual(pinned.map(e => e.id), config.layout[section].map(e => e.id), section);
  }
});

test('clean config: a widget with nothing to show hides itself, as on Omarchy\'s bar', () => {
  for (const entry of [].concat(...Object.values(stock().layout)))
    assert.equal(managed.placeholder(entry, managed.mode(entry, firstParty)), false, entry.id);
  // Placed by the user: kept with a fallback icon.
  assert.equal(managed.placeholder({ id: 'omarchy.system-update', powerbarVisibility: 'shown' }, 'shown'), true);
  // On demand: the drawer needs something to show.
  assert.equal(managed.placeholder({ id: 'omarchy.bluetooth', powerbarVisibility: 'managed' }, 'managed'), true);
  assert.equal(managed.placeholder({ id: 'local.widget' }, managed.mode({ id: 'local.widget' }, { firstParty: false })), true);
  assert.equal(managed.placeholder({ id: 'omarchy.power', powerbarVisibility: 'hidden' }, 'hidden'), false);
});

test('clean config writes no keybindings', () => {
  assert.equal(shortcuts.render(stock().powerbarShortcuts || {}, { widgets: [] }, {}), '');
});

test('clean config folds nothing on a 1920 px screen', () => {
  const k = cell.tokens({ bar: OMARCHY_BAR, spacing: appearance.ranges.spacing.fallback, mode: 'slots' });
  // What the stock widgets paint on a box with no updates, tray items or
  // battery: the menu glyph, five workspaces, "Tuesday 16:15", the weather,
  // network, audio and display glyphs, then Preferences' nine dots.
  const mk = (prefix, inks) => inks.map((ink, i) => {
    const p = cell.place(k, ink, ink <= 16);
    return { key: `${prefix}${i}`, extent: p.extent, spill: p.spill };
  });
  const h = cell.place(k, 12.5, true);
  const r = plain(zoneFit.fit({
    length: 1920, inset: cell.flatEdge(k, 8, OMARCHY_ICON_SLOT), gap: k.cell + k.spacing, gutter: k.gutter,
    pad: s => cell.endPad(k, s), handle: { extent: h.extent, spill: h.spill },
    zones: { left: mk('L', [13, 100]), right: mk('R', [14, 14, 13, 13]), before: [],
      anchor: mk('A', [92])[0], after: mk('F', [14]), center: [] },
    previous: null, transient: null
  }));
  assert.deepEqual(r.folded, { left: [], center: [], right: [] });
  assert.equal(r.fits, true);
});
