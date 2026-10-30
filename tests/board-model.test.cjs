const { test } = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');
const Board = load('BoardModel.js');

const K = Board.KEY;

test('Ctrl or Alt turns every key into no command', () => {
  assert.equal(Board.keyCommand(K.left, '', K.control), null);
  assert.equal(Board.keyCommand(0x48, 'h', K.alt), null);
  assert.equal(Board.keyCommand(0x48, 'h', K.alt | K.shift), null);
});

test('h j k l and the arrows step, Shift carries', () => {
  const step = (key, text, mods = 0) => {
    const k = Board.keyCommand(key, text, mods);
    return [k.dx, k.dy, k.carry];
  };
  assert.deepEqual(step(0, 'h'), [-1, 0, false]);
  assert.deepEqual(step(0, 'l'), [1, 0, false]);
  assert.deepEqual(step(0, 'k'), [0, -1, false]);
  assert.deepEqual(step(0, 'j'), [0, 1, false]);
  assert.deepEqual(step(K.left, ''), [-1, 0, false]);
  assert.deepEqual(step(K.right, ''), [1, 0, false]);
  assert.deepEqual(step(K.up, ''), [0, -1, false]);
  assert.deepEqual(step(K.down, ''), [0, 1, false]);
  assert.deepEqual(step(0x4a, 'J', K.shift), [0, 1, true]);
  assert.deepEqual(step(K.left, '', K.shift), [-1, 0, true]);
});

test('Space, Return and Enter, Escape and Delete name their act', () => {
  const act = (key, text = '') => Board.keyCommand(key, text, 0).act;
  assert.equal(act(K.space, ' '), 'space');
  assert.equal(act(K.ret), 'enter');
  assert.equal(act(K.enter), 'enter');
  assert.equal(act(K.escape), 'escape');
  assert.equal(act(K.del), 'delete');
  assert.equal(act(0x58, 'x'), '');
});

test('a letter reaches the pages as typed and lower-cased', () => {
  const k = Board.keyCommand(0x58, 'X', K.shift);
  assert.equal(k.t, 'X');
  assert.equal(k.c, 'x');
  assert.deepEqual([k.dx, k.dy, k.act], [0, 0, '']);
  const h = Board.keyCommand(0x48, 'H', K.shift);
  assert.deepEqual([h.dx, h.dy, h.carry, h.c], [-1, 0, true, 'h']);
});

test('a press lifts once the pointer is more than the limit away', () => {
  const from = { x: 10, y: 10 };
  assert.equal(Board.pastThreshold(from, { x: 16, y: 10 }, 6), false);
  assert.equal(Board.pastThreshold(from, { x: 17, y: 10 }, 6), true);
  assert.equal(Board.pastThreshold(from, { x: 13, y: 13 }, 6), false);
  assert.equal(Board.pastThreshold(from, { x: 14, y: 13 }, 6), true);
  assert.equal(Board.pastThreshold(from, { x: 4, y: 10 }, 6), false);
  assert.equal(Board.pastThreshold(from, { x: 3, y: 10 }, 6), true);
});

test('within is the root and what is under it', () => {
  const root = { parent: null };
  const mid = { parent: root };
  const leaf = { parent: mid };
  const other = { parent: { parent: null } };
  assert.equal(Board.within(leaf, root), true);
  assert.equal(Board.within(root, root), true);
  assert.equal(Board.within(other, root), false);
  assert.equal(Board.within(null, root), false);
});

test('covers maps the point into the item and keeps the box half open', () => {
  const from = {};
  const item = { width: 10, height: 20, mapFromItem: (f, x, y) => ({ x: x - 5, y: y - 5 }) };
  assert.equal(Board.covers(item, from, { x: 5, y: 5 }), true);
  assert.equal(Board.covers(item, from, { x: 14.9, y: 24.9 }), true);
  assert.equal(Board.covers(item, from, { x: 15, y: 10 }), false);
  assert.equal(Board.covers(item, from, { x: 10, y: 25 }), false);
  assert.equal(Board.covers(item, from, { x: 4.9, y: 10 }), false);
});
