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

const row = (x, y, width = 100, height = 20) => ({ x, y, width, height });

test('in a column the pointer passes a row below its middle', () => {
  assert.equal(Board.gapIndex([], false), 0);
  assert.equal(Board.gapIndex([row(50, -5), row(50, -30)], false), 0, 'above the first row');
  assert.equal(Board.gapIndex([row(50, 9.9), row(50, -10)], false), 0, 'in its top half');
  assert.equal(Board.gapIndex([row(50, 10), row(50, -10)], false), 1, 'on its middle');
  assert.equal(Board.gapIndex([row(50, 30), row(50, 10)], false), 2, 'on the second row');
  assert.equal(Board.gapIndex([row(50, 50), row(50, 30)], false), 2, 'past the last row');
});

test('in a flow the pointer passes a row below it, or right of its middle on it', () => {
  assert.equal(Board.gapIndex([row(20, 5), row(-80, 5)], true), 0, 'left half of the first');
  assert.equal(Board.gapIndex([row(50, 5), row(-50, 5)], true), 1, 'right half of the first');
  assert.equal(Board.gapIndex([row(150, -30), row(50, -30)], true), 0, 'above a row: not passed');
  assert.equal(Board.gapIndex([row(20, 25), row(-80, 25)], true), 2, 'below both rows');
  assert.equal(Board.gapIndex([row(-10, 5), row(-110, 5)], true), 0, 'left of a row, on its height');
});
