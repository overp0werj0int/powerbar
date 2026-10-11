const { test } = require('node:test');
const assert = require('node:assert/strict');
const keys = require('../BarKeysModel.js');

test('the along keys follow the edge, the into key points into the screen', () => {
  assert.deepEqual(keys.barIntent('right', 'Down'), { move: 1 });
  assert.deepEqual(keys.barIntent('right', 'k'), { move: -1 });
  assert.deepEqual(keys.barIntent('right', 'Left'), { into: true });
  assert.equal(keys.barIntent('right', 'Right'), null, 'nothing past the screen edge');
  assert.deepEqual(keys.barIntent('left', 'l'), { into: true });
  assert.deepEqual(keys.barIntent('top', 'l'), { move: 1 });
  assert.deepEqual(keys.barIntent('top', 'Down'), { into: true });
  assert.deepEqual(keys.barIntent('bottom', 'Up'), { into: true });
  assert.equal(keys.barIntent('top', 'Up'), null);
});

test('one meaning per key: no edge spends a key on two jobs', () => {
  for (const edge of ['top', 'bottom', 'left', 'right']) {
    const map = keys.keymap(edge);
    for (const k of map.into.concat(map.out)) assert.equal(map.along[k], undefined, `${edge} ${k}`);
  }
});

test('the other keys mean the same on every edge', () => {
  for (const edge of ['top', 'right']) {
    assert.deepEqual(keys.barIntent(edge, 'Tab'), { zone: 1 });
    assert.deepEqual(keys.barIntent(edge, 'Backtab'), { zone: -1 });
    assert.deepEqual(keys.barIntent(edge, 'Enter'), { open: true });
    assert.deepEqual(keys.barIntent(edge, 'Space'), { open: true });
    assert.deepEqual(keys.barIntent(edge, '/'), { find: true });
    assert.deepEqual(keys.barIntent(edge, '?'), { sheet: true });
    assert.deepEqual(keys.barIntent(edge, ','), { prefs: true });
    assert.deepEqual(keys.drawerIntent(edge, ',', 0), { prefs: true });
    assert.deepEqual(keys.drawerIntent(edge, ',', 0, true), { prefs: true });
    assert.deepEqual(keys.barIntent(edge, 'Escape'), { leave: true });
    assert.deepEqual(keys.barIntent(edge, 'Home'), { home: true });
    assert.deepEqual(keys.barIntent(edge, '^'), { home: true }, 'vim: ^ to the start');
    assert.deepEqual(keys.barIntent(edge, 'End'), { end: true });
    assert.deepEqual(keys.barIntent(edge, '$'), { end: true }, 'vim: $ to the end');
    assert.deepEqual(keys.barIntent(edge, 'PageDown'), { zone: 1 });
    assert.deepEqual(keys.barIntent(edge, 'PageUp'), { zone: -1 });
    for (const strip of [false, true]) {
      assert.deepEqual(keys.drawerIntent(edge, 'Home', 2, strip), { first: true });
      assert.deepEqual(keys.drawerIntent(edge, '^', 2, strip), { first: true });
      assert.deepEqual(keys.drawerIntent(edge, 'End', 0, strip), { last: true });
      assert.deepEqual(keys.drawerIntent(edge, '$', 0, strip), { last: true });
      assert.deepEqual(keys.drawerIntent(edge, 'PageDown', 0, strip), { zone: 1 });
      assert.deepEqual(keys.drawerIntent(edge, 'PageUp', 0, strip), { zone: -1 });
    }
  }
});

test('in a drawer on a side bar the along keys walk it and the out key leaves', () => {
  assert.deepEqual(keys.drawerIntent('right', 'Down', 0), { member: 1 });
  assert.deepEqual(keys.drawerIntent('right', 'Up', 2), { member: -1 });
  assert.deepEqual(keys.drawerIntent('right', 'Right', 2), { back: true });
  assert.equal(keys.drawerIntent('right', 'Left', 0), null);
});

test('in a drawer below a top bar the into key goes down and the out key comes back', () => {
  assert.deepEqual(keys.drawerIntent('top', 'Down', 0), { member: 1 });
  assert.deepEqual(keys.drawerIntent('top', 'Up', 2), { member: -1 });
  assert.deepEqual(keys.drawerIntent('top', 'Up', 0), { back: true }, 'from the first row, back to the icon');
  assert.deepEqual(keys.drawerIntent('top', 'Right', 1), { backMove: 1 });
  assert.deepEqual(keys.drawerIntent('bottom', 'Up', 0), { member: 1 });
  assert.deepEqual(keys.drawerIntent('top', 'Escape', 3), { back: true });
  assert.deepEqual(keys.drawerIntent('top', 'Tab', 3), { zone: 1 });
});

test('a strip under a top or bottom bar runs along it: the along keys walk it, the out key leaves', () => {
  assert.deepEqual(keys.drawerIntent('top', 'Right', 0, true), { member: 1 });
  assert.deepEqual(keys.drawerIntent('top', 'l', 0, true), { member: 1 });
  assert.deepEqual(keys.drawerIntent('top', 'Left', 2, true), { member: -1 });
  assert.deepEqual(keys.drawerIntent('top', 'Up', 2, true), { back: true }, 'out from any member, not a step back');
  assert.equal(keys.drawerIntent('top', 'Down', 0, true), null, 'the into key does not walk a strip');
  assert.deepEqual(keys.drawerIntent('bottom', 'Down', 1, true), { back: true });
  assert.equal(keys.drawerIntent('bottom', 'Up', 1, true), null);
  assert.deepEqual(keys.drawerIntent('left', 'Down', 0, true), { member: 1 }, 'a side bar strip as before');
  assert.deepEqual(keys.drawerIntent('left', 'Left', 0, true), { back: true });
  assert.equal(keys.drawerIntent('left', 'Right', 0, true), null);
});

test('the cursor stops at the ends', () => {
  assert.equal(keys.step(5, 0, -1), -1);
  assert.equal(keys.step(5, 4, 1), -1);
  assert.equal(keys.step(5, 2, 1), 3);
});

test('Tab lands on the next zone nearest stop and wraps', () => {
  const zones = ['left', 'left', 'center', 'center', 'center', 'right', 'right'];
  assert.equal(keys.zoneStep(zones, 3, 1), 5, 'centre → first of right');
  assert.equal(keys.zoneStep(zones, 3, -1), 1, 'centre → last of left');
  assert.equal(keys.zoneStep(zones, 6, 1), 0, 'wraps to the first zone');
  assert.equal(keys.zoneStep(zones, 0, -1), 6, 'wraps back to the last zone');
  assert.equal(keys.zoneStep(['left', 'right'], 0, 1), 1, 'skips a zone with no stops');
  assert.equal(keys.zoneStep([], 0, 1), -1);
});

test('search ranks word starts first, then any match, then bar order', () => {
  const names = ['Audio', 'Bluetooth', 'Tailscale', 'Audio output', 'Scratchpad audio'];
  assert.deepEqual(keys.matches(names, 'au'), [0, 3, 4]);
  assert.deepEqual(keys.matches(names, 'ale'), [2], 'inside a word still matches');
  assert.deepEqual(keys.matches(names, 'sc'), [4, 2], 'a word start beats a match inside');
  assert.deepEqual(keys.matches(names, ''), []);
  assert.deepEqual(keys.matches(['Météo'], 'mé'), [0], 'any letters, not only ASCII');
});

test('the letters typed may skip ahead, and the best placement wins', () => {
  // Names from a real bar; members carry their group's name first.
  const names = ['AI', 'AI Agents', 'AI Local Laya', 'Audio', 'Audio Audio', 'Audio microphone', 'Bluetooth',
    'Tailscale', 'Plugin Manager', 'Omarchy Power Manager', 'OmaSettings', 'Omatop'];
  const top = (q) => names[keys.matches(names, q)[0]];
  assert.equal(top('auau'), 'Audio Audio', "the Audio group's Audio");
  assert.equal(top('ail'), 'AI Local Laya', 'word starts beat letters in a row inside a word');
  assert.deepEqual(keys.matches(names, 'ail').map((i) => names[i]), ['AI Local Laya', 'Tailscale']);
  assert.equal(top('top'), 'Omatop');
  assert.equal(top('to'), 'Omatop', 'the shorter name wins a tie');
  assert.equal(top('pm'), 'Plugin Manager', 'initials');
  assert.equal(top('os'), 'OmaSettings', 'a capital inside a word starts a word');
  assert.equal(top('audio'), 'Audio', 'the exact name first');
  assert.deepEqual(keys.matches(names, 'xq'), []);
});

test('a single letter, or a word after a space, starts a word', () => {
  const names = ['Bluetooth', 'Tailscale', 'Audio', 'AI usage dashboard'];
  assert.deepEqual(keys.matches(names, 't'), [1], 'not the t inside Bluetooth');
  assert.deepEqual(keys.matches(names, 'ai u'), [3], 'not the u inside Audio');
  assert.ok(keys.matches(names, 'ud').includes(2), 'one word of two letters may start inside a word');
});

test('the fuzzy placement says where each letter went', () => {
  assert.deepEqual(keys.fuzzy('ail', 'AI Local Laya').at, [0, 1, 3]);
  assert.deepEqual(keys.fuzzy('ail', 'Tailscale').at, [1, 2, 3]);
  assert.equal(keys.fuzzy('ail', 'Tailscale').start, false);
  assert.equal(keys.fuzzy('abc', 'ab'), null);
  assert.deepEqual(keys.fuzzy('a', 'Audio', { 0: true }), null, 'a used letter is skipped');
});

test('each word typed must match, and a member matches by its group name too', () => {
  // In bar order: the AI group, its members (text "ai <name>"), then others.
  const names = ['AI', 'AI Agent Orchestrator', 'AI Agents', 'AI Agent Activity', 'Audio', 'AI usage dashboard'];
  assert.deepEqual(keys.matches(names, 'ai a').sort(), [1, 2, 3], "the group's members with a word starting with a");
  assert.deepEqual(keys.matches(names, 'ai act'), [3]);
  assert.deepEqual(keys.matches(names, 'ai u'), [5]);
  assert.deepEqual(keys.matches(names, 'act ai'), [3], 'any order');
  assert.deepEqual(keys.matches(names, 'ai zz'), [], 'every word must match');
  assert.deepEqual(keys.matches(names, '  au  '), [4, 5], 'spaces around do not count');
  assert.equal(keys.matches(names, 'ai')[0], 0, 'the group first');
});

test('a member reads its group name first', () => {
  assert.equal(keys.searchText('Local Laya', 'AI'), 'AI Local Laya');
  assert.equal(keys.searchText('ScratchPeek', ''), 'ScratchPeek');
});

test('a found widget comes into view the way the pointer would bring it', () => {
  const at = (w) => keys.route(Object.assign({ onBar: false, inline: false, behindDots: false, folded: false, inDrawer: false }, w));
  assert.equal(at({ onBar: true, inline: true }), 'put');
  // In the bar: the zone's dots expand it in place, for on-demand and folded widgets alike.
  assert.equal(at({ inline: true, behindDots: true, inDrawer: true }), 'dots');
  assert.equal(at({ inline: true, folded: true, inDrawer: true }), 'dots', 'folded off for lack of room');
  // In a drawer: the zone's drawer.
  assert.equal(at({ folded: true, inDrawer: true }), 'drawer');
  assert.equal(at({ inDrawer: true }), 'drawer');
  // Out of the way of another zone's expansion, in either mode.
  assert.equal(at({ inline: true }), 'clear');
  assert.equal(at({}), 'clear');
});

test('the key strip names the keys of the edge', () => {
  const right = keys.legend('right', 'bar');
  assert.equal(right[0].keys, '↑ ↓');
  assert.equal(right[1].keys, '←');
  assert.equal(keys.legend('top', 'bar')[1].keys, '↓');
  assert.equal(keys.legend('top', 'bar', true)[1].label, 'Into a group or drawer');
  assert.equal(keys.legend('top', 'drawer')[0].keys, '↓ ↑');
  assert.equal(keys.legend('right', 'drawer')[2].keys, '→ Esc');
  assert.equal(keys.legend('top', 'drawer', true, true)[0].keys, '← →', 'a strip is walked along the bar');
  assert.equal(keys.legend('top', 'drawer', true, true)[2].keys, '↑ Esc');
  assert.equal(keys.legend('bottom', 'drawer', true, true)[2].keys, '↓ Esc');
  assert.deepEqual(keys.legend('top', 'drawer').at(-1), { keys: 'Esc Esc', label: 'Leave' }, 'a quick double Esc leaves from any depth');
  for (const state of ['bar', 'drawer']) {
    assert.deepEqual(keys.legend('top', state).at(-2), { keys: ',', label: 'Preferences' }, `${state}: , opens Preferences`);
  }
  assert.ok(!keys.legend('top', 'search').some(e => e.label === 'Preferences'), 'a comma in a search is typed');
  assert.deepEqual(keys.legend('top', 'search')[3], { keys: 'Esc Esc', label: 'Leave' });
});

test('the keyboard mode starts on the focused monitor, never on another one it can not see', () => {
  assert.equal(keys.startScreen(['DP-1', 'eDP-1'], 'eDP-1'), 1);
  assert.equal(keys.startScreen(['DP-1', 'eDP-1'], 'HDMI-A-1'), -1);
  assert.equal(keys.startScreen(['DP-1', 'eDP-1'], ''), 0);
  assert.equal(keys.startScreen([], 'eDP-1'), -1);
});

test('on a named menu row the name card says what hovering says: the widget\'s own status', () => {
  assert.equal(keys.cardText('Microphone', 'Microphone muted', true), 'Microphone muted');
  assert.equal(keys.cardText('Agents', '', true), 'Agents', 'no tooltip of its own: the name');
  assert.equal(keys.cardText('Clock', 'Clock', true), 'Clock');
  assert.equal(keys.cardText('Clock', 'Tuesday', false), 'Clock', 'on the bar: the name');
});
