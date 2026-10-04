const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../IconSearch.js`, 'utf8'), model);
const omarchy = require('../OmarchyIcons.js');

const sources = {
  bar: [{ glyph: '\u{f036c}', font: '', name: 'Microphone' }, { glyph: 'EN', font: '', name: 'Keyboard Layout' },
    { glyph: '', font: 'omarchy', name: 'Keystroke' }],
  logos: [[0xe900, 'omarchy', []], [0xe905, 'codex', ['ai']]],
  glyphs: [[0xf036c, 'md-microphone', 7], [0xf036d, 'md-microphone_off', 4], [0xf06a9, 'md-robot', 1],
    [0xf1aa4, 'md-robot_excited', 1], [0xf028, 'fa-volume_up', 5], [0xe900, 'dev-cobol', 1]],
  emoji: [{ e: '🤖', k: 'robot face bot' }, { e: '🎤', k: 'sing microphone karaoke' }],
};
const list = model.index(sources);
const J = v => JSON.parse(JSON.stringify(v));
const names = r => J(r.map(i => i.name));

test('index keeps each glyph once per font, your bar first, and skips labels', () => {
  assert.equal(list.filter(i => i.glyph === '\u{f036c}').length, 1);
  assert.equal(list.find(i => i.glyph === '\u{f036c}').source, model.BAR);
  assert.ok(!list.some(i => i.glyph === 'EN'));
  // U+E900 is the Omarchy logo in its font and dev-cobol in the Nerd Font: two icons.
  assert.equal(list.filter(i => i.glyph === '').length, 2);
  assert.equal(list.find(i => i.glyph === '' && i.source === model.BAR).font, 'omarchy');
});
test('every query word must start a word; exact and short names first', () => {
  assert.deepEqual(names(model.search(list, 'robot')), ['robot', 'robot excited', 'robot face bot']);
  assert.deepEqual(names(model.search(list, 'mic off')), ['microphone off']);
  assert.deepEqual(names(model.search(list, 'volume-up')), ['volume up']);
  assert.deepEqual(names(model.search(list, 'volume_up')), ['volume up']);
  assert.equal(model.search(list, 'zzz').length, 0);
});
test('words inside a name match from three letters, ranked after starts', () => {
  assert.deepEqual(names(model.search(list, 'phone')), ['Microphone', 'microphone off', 'sing microphone karaoke']);
  assert.equal(model.search(list, 'ph').length, 0);
});
test('tags find AI logos', () => {
  assert.deepEqual(names(model.search(list, 'ai')), ['codex']);
});
test('a pasted glyph or emoji is offered, text is not', () => {
  assert.equal(model.pastedGlyph(' 🤖 '), '🤖');
  assert.equal(model.pastedGlyph('\u{f06a9}'), '\u{f06a9}');
  assert.equal(model.pastedGlyph('👩‍💻'), '👩‍💻');
  assert.equal(model.pastedGlyph('👍🏽'), '👍🏽');
  assert.equal(model.pastedGlyph('🇳🇴'), '🇳🇴');
  assert.equal(model.pastedGlyph('❤️'), '❤️');
  assert.equal(model.pastedGlyph('robot'), '');
  assert.equal(model.pastedGlyph('🤖🤖'), '');
  assert.equal(model.pastedGlyph('a'), '');
});
test('rows: headers per source when browsing, one run when searching', () => {
  const r = model.rows(list, 3, true);
  assert.deepEqual(J(r.filter(x => x.header).map(x => x.header)), ['On your bar', 'Omarchy logos', 'Omarchy', 'Emoji']);
  const ats = J(r.flatMap(x => x.items.map(i => i.at)));
  assert.deepEqual(ats, ats.map((_, i) => i));
  assert.ok(model.rows(list, 3, false).every(x => !x.header));
});
test('vertical keeps the column, skips headers and clamps to short rows', () => {
  const r = model.rows(list, 3, true);
  // On your bar [0, 1]; logos [2] (the Omarchy logo is already on your bar); Omarchy [3, 4, 5], [6, 7].
  assert.equal(model.vertical(r, 1, 1), 2);
  assert.equal(model.vertical(r, 2, 1), 3);
  assert.equal(model.vertical(r, 5, -1), 2);
  assert.equal(model.vertical(r, 0, -1), 0);
  const last = r[r.length - 1].items.at(-1).at;
  assert.equal(model.vertical(r, last, 1), last);
});
test('the generated Omarchy list has its logos and named glyphs', () => {
  assert.ok(omarchy.logos.some(l => l[1] === 'omarchy' && l[0] === 0xe900));
  assert.ok(omarchy.logos.filter(l => l[2].includes('ai')).length >= 10);
  assert.ok(omarchy.glyphs.length > 200);
  assert.ok(omarchy.glyphs.every(g => /^[a-z]+-/.test(g[1]) && g[2] > 0));
  const full = model.index({ logos: omarchy.logos, glyphs: omarchy.glyphs });
  assert.ok(model.search(full, 'monitor').length > 0);
});
