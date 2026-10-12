const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../ShortcutModel.js`, 'utf8'), m);
const plain = value => JSON.parse(JSON.stringify(value));

// As Omarchy writes them (default/hypr/bindings/utilities.lua).
const omarchyLua = `
o.bind_toggle("SUPER + SHIFT + SPACE", "Toggle top bar", "bar")
o.bind("SUPER + CTRL + A", "Audio", "omarchy-shell shell toggle omarchy.audio")
o.bind("SUPER + CTRL + ALT + D", "Calendar", "omarchy-shell shell toggle omarchy.clock")
o.bind("SUPER + CTRL + E", "Emojis", "omarchy-shell shell toggle omarchy.emojis")
for panel = 1, 9 do
  o.bind(
    "SUPER + CTRL + code:" .. tostring(panel + 9),
    "Bar panel " .. panel,
    "omarchy-shell -q shell togglePanelAt right " .. panel
  )
end
`;
// As \`hyprctl binds\` prints them: plain keys, and code: keys with their modifiers.
const hyprctl = `bindd
	modmask: 68
	submap: 
	key: A
	keycode: 0
	catchall: false
	description: Audio
	dispatcher: __lua
	arg: 228

bindd
	modmask: 76
	submap: 
	key: D
	keycode: 0
	catchall: false
	description: Calendar
	dispatcher: __lua
	arg: 230

bindd
	modmask: 68
	submap: 
	key: SUPER + CTRL + code:12
	keycode: 0
	catchall: false
	description: Bar panel 3
	dispatcher: __lua
	arg: 251

bindd
	modmask: 68
	submap: 
	key: T
	keycode: 0
	catchall: false
	description: Activity
	dispatcher: __lua
	arg: 240

bind
	modmask: 0
	submap: powerbar-record
	key: ESCAPE
	keycode: 0
	catchall: false
	description: 
	dispatcher: submap
	arg: reset
`;

test('key strings normalize to one spelling and compare by modifiers and key', () => {
  assert.equal(m.normalize('ctrl+super + a'), 'SUPER + CTRL + A');
  assert.equal(m.normalize('SUPER + CTRL + ALT + d'), 'SUPER + CTRL + ALT + D');
  assert.equal(m.normalize('SUPER + CTRL + code:10'), 'SUPER + CTRL + code:10');
  assert.equal(m.normalize('SUPER + CTRL'), '');
  assert.equal(m.normalize('HYPER + A'), '');
  assert.ok(m.same('SUPER + SHIFT + CTRL + A', 'super + ctrl + shift + a'));
  assert.deepEqual(plain(m.caps('SUPER + CTRL + code:12')), ['Super', 'Ctrl', '3']);
  assert.deepEqual(plain(m.caps('SUPER + SHIFT + SPACE')), ['Super', 'Shift', 'Space']);
  assert.equal(m.label('CTRL + ALT + F5'), 'Ctrl Alt F5');
});

test('hyprctl binds parse into comparable records, code: keys included', () => {
  const binds = m.parseBinds(hyprctl);
  assert.deepEqual(plain(binds.map(b => b.keys)), ['SUPER + CTRL + A', 'SUPER + CTRL + ALT + D', 'SUPER + CTRL + code:12', 'SUPER + CTRL + T', 'ESCAPE']);
  assert.equal(binds[4].submap, 'powerbar-record');
});

test("Omarchy's widget shortcuts are read by id and by position", () => {
  const d = m.parseDefaults(omarchyLua);
  assert.deepEqual(plain(d.widgets), [
    { keys: 'SUPER + CTRL + A', description: 'Audio', id: 'omarchy.audio', origin: 'omarchy' },
    { keys: 'SUPER + CTRL + ALT + D', description: 'Calendar', id: 'omarchy.clock', origin: 'omarchy' },
    { keys: 'SUPER + CTRL + E', description: 'Emojis', id: 'omarchy.emojis', origin: 'omarchy' }
  ]);
  assert.equal(d.positions.length, 9);
  assert.deepEqual(plain(d.positions[2]), { section: 'right', n: 3, keys: 'SUPER + CTRL + code:12' });
  assert.equal(m.positional(d, 'right', 3, m.parseBinds(hyprctl)), 'SUPER + CTRL + code:12');
  // Bound by the file but not live (the user unbound it): no shortcut.
  assert.equal(m.positional(d, 'right', 4, m.parseBinds(hyprctl)), '');
});

test("a widget shows Omarchy's shortcut, yours, or none", () => {
  const d = m.parseDefaults(omarchyLua), binds = m.parseBinds(hyprctl);
  assert.deepEqual(plain(m.effective('widget:omarchy.audio', {}, d, binds)), { keys: 'SUPER + CTRL + A', source: 'omarchy', fallback: '' });
  assert.deepEqual(plain(m.effective('widget:omarchy.audio', { 'widget:omarchy.audio': 'SUPER + CTRL + M' }, d, binds)),
    { keys: 'SUPER + CTRL + M', source: 'yours', fallback: 'SUPER + CTRL + A', live: false });
  assert.deepEqual(plain(m.effective('widget:omarchy.audio', { 'widget:omarchy.audio': '' }, d, binds)),
    { keys: '', source: 'removed', fallback: 'SUPER + CTRL + A' });
  // Omarchy's file binds Emojis, but the user's config unbound it.
  assert.deepEqual(plain(m.effective('widget:omarchy.emojis', {}, d, binds)), { keys: '', source: 'none', fallback: '' });
  assert.deepEqual(plain(m.effective('group:ai', { 'group:ai': 'SUPER + CTRL + I' }, d, binds)), { keys: 'SUPER + CTRL + I', source: 'yours', fallback: '', live: false });
  assert.deepEqual(plain(m.effective('group:ai', {}, d, binds)), { keys: '', source: 'none', fallback: '' });
});

test("conflicts name Hyprland's binds and Powerbar's other shortcuts, never its own", () => {
  const binds = m.parseBinds(hyprctl).concat([{ keys: 'SUPER + CTRL + I', mask: 68, key: 'I', description: 'AI group', submap: '' }]);
  const config = { 'group:ai': 'SUPER + CTRL + I' }, own = ['SUPER + CTRL + I'];
  assert.deepEqual(plain(m.conflicts('SUPER + CTRL + T', 'group:tools', config, binds, {}, own)), [{ description: 'Activity', target: '' }]);
  assert.deepEqual(plain(m.conflicts('SUPER + CTRL + I', 'group:tools', config, binds, { 'group:ai': 'the AI group' }, own)),
    [{ description: 'the AI group', target: 'group:ai' }]);
  assert.deepEqual(plain(m.conflicts('SUPER + CTRL + I', 'group:ai', config, binds, {}, own)), []);
  // Without Powerbar's block holding them, the same keys are someone else's.
  assert.deepEqual(plain(m.conflicts('SUPER + CTRL + I', 'group:ai', config, binds, {}, [])), [{ description: 'AI group', target: '' }]);
  // A bind in another submap is not a conflict.
  assert.deepEqual(plain(m.conflicts('ESCAPE', 'group:ai', config, binds)), []);
});

test('assigning keys takes them from another Powerbar shortcut; restore drops the entry', () => {
  const config = { 'group:ai': 'SUPER + CTRL + I', 'widget:omarchy.audio': 'SUPER + CTRL + M' };
  assert.deepEqual(plain(m.assign(config, 'group:tools', 'super+ctrl+i')), { 'widget:omarchy.audio': 'SUPER + CTRL + M', 'group:tools': 'SUPER + CTRL + I' });
  assert.deepEqual(plain(m.assign(config, 'widget:omarchy.audio', '')), { 'group:ai': 'SUPER + CTRL + I', 'widget:omarchy.audio': '' });
  assert.deepEqual(plain(m.restore(config, 'widget:omarchy.audio')), { 'group:ai': 'SUPER + CTRL + I' });
});

test('key presses become shortcuts that need Super, Ctrl or Alt (F-keys alone are fine)', () => {
  const Meta = 0x10000000, Ctrl = 0x04000000, Shift = 0x02000000, Alt = 0x08000000;
  assert.deepEqual(plain(m.fromKeyEvent(0x41, Meta | Ctrl, 38)), { keys: 'SUPER + CTRL + A' });
  // Shifted digits arrive as symbols; the scan code keeps the key.
  assert.deepEqual(plain(m.fromKeyEvent(0x21, Meta | Shift, 10)), { keys: 'SUPER + SHIFT + code:10' });
  assert.deepEqual(plain(m.fromKeyEvent(0x31, Meta, 0)), { keys: 'SUPER + code:10' });
  assert.deepEqual(plain(m.fromKeyEvent(0x01000030 + 4, 0, 71)), { keys: 'F5' });
  assert.deepEqual(plain(m.fromKeyEvent(0x20, Alt, 65)), { keys: 'ALT + SPACE' });
  assert.equal(m.fromKeyEvent(0x41, Shift, 38).error, 'Add Super, Ctrl or Alt');
  // Modifiers alone wait for the key.
  assert.equal(m.fromKeyEvent(0x01000022, Meta, 133).error, '');
  assert.equal(m.fromKeyEvent(0x01000020, Shift | Meta, 50).error, '');
});

test('the block in bindings.lua takes keys over, moves or removes Omarchy shortcuts, with o.bind', () => {
  const d = m.parseDefaults(omarchyLua);
  const lua = m.render({ 'widget:omarchy.audio': 'SUPER + CTRL + M', 'widget:omarchy.clock': '', 'group:ai': 'SUPER + CTRL + I' }, d,
    { 'widget:omarchy.audio': 'Audio', 'widget:omarchy.clock': 'Clock', 'group:ai': 'AI group' });
  assert.equal(lua, [m.BEGIN,
    'hl.unbind("SUPER + CTRL + I")',
    'o.bind("SUPER + CTRL + I", "AI group", "omarchy-shell powerbar toggleGroup ai")',
    'hl.unbind("SUPER + CTRL + A")',
    'hl.unbind("SUPER + CTRL + M")',
    'o.bind("SUPER + CTRL + M", "Audio", "omarchy-shell shell toggle omarchy.audio")',
    'hl.unbind("SUPER + CTRL + ALT + D")',
    m.END].join('\n'));
  assert.equal(m.render({}, d, {}), '', 'nothing to bind: no block');
  // An id that is not plain never reaches Lua or the shell at all.
  assert.equal(m.render({ 'group:a"b': 'SUPER + B' }, d, {}), '');
});

test("Powerbar's block is cut out before reading the user's bindings, and its keys are known", () => {
  const block = m.render({ 'bar:keys': 'SUPER + B', 'widget:b.everything': 'SUPER + CTRL + SLASH' }, { widgets: [], positions: [] },
    { 'bar:keys': 'Powerbar keyboard', 'widget:b.everything': 'Everything' });
  const file = 'o.bind("SUPER + RETURN", "Terminal", "uwsm-app -- xdg-terminal-exec")\n\n' + block + '\n';
  assert.equal(m.strip(file), 'o.bind("SUPER + RETURN", "Terminal", "uwsm-app -- xdg-terminal-exec")\n\n');
  assert.deepEqual(plain(m.blockKeys(file)), ['SUPER + B', 'SUPER + CTRL + SLASH']);
  assert.equal(m.readDefaults([{ text: m.strip(file), origin: 'config' }]).widgets.length, 0, 'its own binds never read as the user\'s');
});

test('recording enters an empty submap (registering it when Hyprland has not), with a watchdog, and leaves only that submap', () => {
  const lua = m.recordLua(true);
  assert.match(lua, /^local function enter\(\) pcall\(function\(\) hl\.dispatch\(hl\.dsp\.submap\("powerbar-record"\)\) end\) end enter\(\) /);
  assert.match(lua, /if hl\.get_current_submap\(\) ~= "powerbar-record" then hl\.define_submap\("powerbar-record", function\(\) hl\.bind\("SUPER \+ CTRL \+ SHIFT \+ ALT \+ ESCAPE", hl\.dsp\.submap\("reset"\)\) end\) enter\(\) end /);
  assert.match(lua, /hl\.timer\(function\(\) if hl\.get_current_submap\(\) == "powerbar-record"/);
  assert.match(lua, /timeout = 15000, type = "oneshot"/);
  assert.equal(m.recordLua(false), 'if hl.get_current_submap() == "powerbar-record" then hl.dispatch(hl.dsp.submap("reset")) end');
});
test("the user's own files add shortcuts and win over Omarchy's for the same widget", () => {
  const mine = 'o.bind("SUPER + SLASH", "Everything", "omarchy-shell shell toggle b.everything")\n'
    + 'hl.bind("SUPER + CTRL + M", hl.dsp.exec_cmd("omarchy-shell shell toggle omarchy.audio"), { description = "Audio" })';
  const d = m.readDefaults([{ text: omarchyLua, origin: 'omarchy' }, { text: mine, origin: 'config' }]);
  assert.deepEqual(plain(d.widgets.map(w => w.id + '=' + w.keys + '/' + w.origin)), [
    'omarchy.clock=SUPER + CTRL + ALT + D/omarchy', 'omarchy.emojis=SUPER + CTRL + E/omarchy',
    'b.everything=SUPER + SLASH/config', 'omarchy.audio=SUPER + CTRL + M/config']);
  const binds = m.parseBinds(hyprctl).concat([{ keys: 'SUPER + SLASH', mask: 64, key: 'SLASH', description: 'Everything', submap: '' }]);
  assert.equal(m.effective('widget:b.everything', {}, d, binds).source, 'config');
});

test('the bar keyboard target binds the keys IPC', () => {
  const sm = require('../ShortcutModel.js');
  assert.equal(sm.command('bar:keys'), 'omarchy-shell powerbar keys');
  assert.equal(sm.command('bar:search'), 'omarchy-shell powerbar keysSearch');
  const lua = sm.render({ 'bar:keys': 'SUPER + B' }, { widgets: [], positions: [] }, { 'bar:keys': 'Powerbar keyboard' });
  assert.match(lua, /o\.bind\("SUPER \+ B", "Powerbar keyboard", "omarchy-shell powerbar keys"\)/);
  assert.deepEqual(sm.effective('bar:keys', {}, { widgets: [], positions: [] }, []), { keys: '', source: 'none', fallback: '' });
});

test('typed keys follow the recorder: a modifier unless a function key, one spelling', () => {
  assert.deepEqual(plain(m.bindable('super+b')), { keys: 'SUPER + B' });
  assert.deepEqual(plain(m.bindable('ctrl + alt + code:10')), { keys: 'CTRL + ALT + code:10' });
  assert.deepEqual(plain(m.bindable('F5')), { keys: 'F5' });
  assert.match(m.bindable('SHIFT + B').error, /Super, Ctrl or Alt/);
  assert.match(m.bindable('B').error, /Super, Ctrl or Alt/);
  assert.match(m.bindable('SUPER +').error, /not a key combination/);
  assert.match(m.bindable('HYPER + B').error, /not a key combination/);
});


test('a target that is not a plain id never becomes shell code in a bind', () => {
  assert.equal(m.command('widget:omarchy.audio; touch /tmp/x #'), '');
  assert.equal(m.command('group:g-1$(id)'), '');
  assert.equal(m.command('widget:io.github.x_y-z'), 'omarchy-shell shell toggle io.github.x_y-z');
  const block = m.render({ 'widget:omarchy.audio; touch /tmp/x #': 'SUPER + A', 'widget:omarchy.audio': 'SUPER + V' }, {}, {});
  assert.doesNotMatch(block, /touch/);
  assert.match(block, /SUPER \+ V/);
});

test('a damaged block (a marker without its pair) reads as the user\'s own text', () => {
  const text = `a\n${m.BEGIN}\no.bind("SUPER + B", "x", "y")\nb\nc`;
  assert.equal(m.paired(text), false);
  assert.equal(m.strip(text), text);
  assert.deepEqual(Array.from(m.blockKeys(text)), []);
  const whole = `a\n${m.BEGIN}\no.bind("SUPER + B", "x", "y")\n${m.END}\nb`;
  assert.equal(m.paired(whole), true);
  assert.equal(m.strip(whole), 'a\nb');
  assert.equal(m.paired(`${m.END}\n${m.BEGIN}`), false);
});

test('a shortcut set in Powerbar says whether Hyprland has it bound', () => {
  const config = { 'bar:keys': 'SUPER + B' };
  assert.equal(m.effective('bar:keys', config, {}, []).live, false);
  assert.equal(m.effective('bar:keys', config, {}, [{ keys: m.normalize('SUPER + B'), description: 'Powerbar keyboard' }]).live, true);
});

// First start (KEYS-84): the suggested bar shortcuts are bound where free.
test('a first start binds each suggested bar shortcut that is free', () => {
  const r = m.offer({}, [], {}, []);
  assert.deepEqual(plain(r.next), { 'bar:keys': 'SUPER + B', 'bar:search': 'SUPER + CTRL + SLASH' });
  assert.deepEqual(plain(r.bound.map(s => s.target)), ['bar:keys', 'bar:search']);
  assert.deepEqual(plain(r.taken), []);
  assert.equal(m.offerMessage(r),
    'Super + B starts the keyboard mode, Super + Ctrl + / starts it with its search open. Change them in Preferences → Bar → Keyboard.');
});

test('a suggested key something else holds is left alone and named', () => {
  const binds = [{ keys: 'SUPER + B', description: 'Browser', submap: '' }];
  const r = m.offer({ 'widget:omarchy.audio': 'SUPER + CTRL + SLASH' }, binds, { 'widget:omarchy.audio': 'Audio' }, []);
  assert.deepEqual(plain(r.next), { 'widget:omarchy.audio': 'SUPER + CTRL + SLASH' }, 'nothing bound, nothing taken over');
  assert.deepEqual(plain(r.bound), []);
  assert.deepEqual(plain(r.taken.map(s => [s.target, s.by])), [['bar:keys', 'Browser'], ['bar:search', 'Audio']]);
  assert.equal(m.offerMessage(r),
    'Super + B (the keyboard mode) is taken by Browser; Super + Ctrl + / (its search) is taken by Audio. Choose keys in Preferences → Bar → Keyboard.');
});

test('one free and one taken: the free one is bound, the other named', () => {
  const r = m.offer({}, [{ keys: 'SUPER + B', description: 'Browser', submap: '' }], {}, []);
  assert.deepEqual(plain(r.next), { 'bar:search': 'SUPER + CTRL + SLASH' });
  assert.equal(m.offerMessage(r),
    'Super + Ctrl + / starts the keyboard mode with its search open. Super + B (the keyboard mode) is taken by Browser. Choose keys in Preferences → Bar → Keyboard.');
});

test('a bar shortcut already decided is not offered again, removed ones included', () => {
  const r = m.offer({ 'bar:keys': '', 'bar:search': 'SUPER + F1' }, [], {}, []);
  assert.deepEqual(plain(r.next), { 'bar:keys': '', 'bar:search': 'SUPER + F1' });
  assert.deepEqual(plain(r.bound), []);
  assert.deepEqual(plain(r.taken), []);
  assert.equal(m.offerMessage(r), '');
});

test('keys only a submap or Powerbar\'s own block holds are free', () => {
  const binds = [{ keys: 'SUPER + B', description: 'record', submap: 'powerbar-record' },
    { keys: 'SUPER + CTRL + SLASH', description: 'Powerbar search', submap: '' }];
  const r = m.offer({}, binds, {}, ['SUPER + CTRL + SLASH']);
  assert.deepEqual(plain(r.bound.map(s => s.target)), ['bar:keys', 'bar:search']);
});
