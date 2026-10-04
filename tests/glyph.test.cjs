const { test } = require('node:test');
const assert = require('node:assert/strict');
const model = require('../GlyphModel.js');

test('reads a Nerd Font glyph, including ones outside the basic plane', () => {
  assert.equal(model.glyphFrom(''), '');
  assert.equal(model.glyphFrom('󰕾'), '󰕾');
  assert.equal(model.glyphFrom('  󰕾  Audio'), '󰕾');
});

test('takes a short text label but not values or long text', () => {
  assert.equal(model.glyphFrom('EN'), 'EN');
  assert.equal(model.glyphFrom(' AI '), 'AI');
  assert.equal(model.glyphFrom('3'), '');
  assert.equal(model.glyphFrom('17'), '');
  assert.equal(model.glyphFrom('100%'), '');
  assert.equal(model.glyphFrom('Sunday 17:38'), '');
  assert.equal(model.glyphFrom(''), '');
  assert.equal(model.glyphFrom(undefined), '');
});

test('prefers the first visible button with a glyph', () => {
  const buttons = [
    { text: '', font: 'A', visible: true },
    { text: '', font: 'Hidden', visible: false },
    { text: '17:38', font: 'B', visible: true },
    { text: '󰂯', font: 'Nerd', visible: true },
  ];
  assert.deepEqual(model.pick(buttons), { glyph: '󰂯', font: 'Nerd', size: 0, parts: 2 });
  assert.equal(model.pick([{ text: '󰂯', font: 'Nerd', size: 15, visible: true }]).size, 15);
});

test('counts the visible parts, so a compound is known', () => {
  const workspaces = [1, 2, 3].map(n => ({ text: String(n), visible: true })).concat([{ text: '\uf111', visible: true }]);
  assert.equal(model.pick(workspaces).parts, 4);
  assert.equal(model.pick([{ text: '\uf111', visible: true }, { text: '', visible: true }, { text: 'x', visible: false }]).parts, 1);
});

test('falls back to a hidden button, then to nothing', () => {
  assert.deepEqual(model.pick([{ text: '', font: 'F', visible: false }]), { glyph: '', font: 'F', size: 0, parts: 0 });
  assert.equal(model.pick([{ text: '42', visible: true }]), null);
  assert.equal(model.pick([]), null);
  assert.equal(model.pick(undefined), null);
});

test('merge returns the same store when nothing changed', () => {
  const store = { a: { glyph: 'x', font: 'F' } };
  assert.equal(model.merge(store, 'a', { glyph: 'x', font: 'F' }), store);
  const next = model.merge(store, 'b', { glyph: 'y', font: '' });
  assert.notEqual(next, store);
  assert.deepEqual(next, { a: { glyph: 'x', font: 'F' }, b: { glyph: 'y', font: '', size: 0, parts: 1 } });
  assert.notEqual(model.merge(next, 'b', { glyph: 'y', font: '', size: 13 }), next);
  assert.deepEqual(store, { a: { glyph: 'x', font: 'F' } });
  assert.equal(model.merge(store, '', { glyph: 'z' }), store);
  assert.equal(model.merge(store, 'a', null), store);
});

test('forget drops one entry and leaves the store alone otherwise', () => {
  const store = { a: { glyph: 'x', font: '' }, b: { glyph: 'y', font: '' } };
  assert.equal(model.forget(store, 'c'), store);
  assert.deepEqual(JSON.parse(JSON.stringify(model.forget(store, 'a'))), { b: { glyph: 'y', font: '' } });
});

test('prune keeps layout instances and drops the rest', () => {
  const store = { a: { glyph: 'x', font: '' }, b: { glyph: 'y', font: '' } };
  assert.equal(model.prune(store, ['a', 'b', 'c']), store);
  assert.deepEqual(model.prune(store, ['b']), { b: { glyph: 'y', font: '' } });
});

test('parse ignores broken files and entries', () => {
  assert.deepEqual(model.parse(''), {});
  assert.deepEqual(model.parse('not json'), {});
  assert.deepEqual(model.parse('[1,2]'), {});
  assert.deepEqual(model.parse('{"a":{"glyph":"x","font":"F"},"b":{"glyph":""},"c":3,"d":{"glyph":"y"}}'),
    { a: { glyph: 'x', font: 'F', size: 0, parts: 1 }, d: { glyph: 'y', font: '', size: 0, parts: 1 } });
});
