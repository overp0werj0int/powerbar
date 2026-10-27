const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../DeskModel.js`, 'utf8'), model);
const plain = (v) => JSON.parse(JSON.stringify(v));
const at = (strip, control, stop) => ({ strip, control, stop });

// The Look page as the walk sees it: Style (two pick rows, the edge chips
// with Bottom chosen), Size (switch, pick row, fader), Shape (three scope
// chips with Everywhere chosen, switch, two faders).
const look = [
  [{ stops: 1 }, { stops: 1 }, { stops: 4, home: 1 }],
  [{ stops: 1 }, { stops: 1 }, { stops: 1 }],
  [{ stops: 3, home: 1 }, { stops: 1 }, { stops: 1 }, { stops: 1 }],
];

test('strips share the plate equally, 12 px apart', () => {
  assert.deepEqual(plain(model.stripBoxes(1380, 6, 12)), [0, 1, 2, 3, 4, 5].map((i) => ({ x: i * 232, width: 220 })));
  assert.deepEqual(plain(model.stripBoxes(1380, 3, 12)).map((b) => b.width), [452, 452, 452]);
  assert.deepEqual(plain(model.stripBoxes(1380, 0, 12)), []);
});

test('j and k go to the control below or above, then on to the next strip', () => {
  assert.deepEqual(plain(model.vertical(look, at(1, 0, 0), 1)), at(1, 1, 0));
  assert.deepEqual(plain(model.vertical(look, at(1, 1, 0), 1)), at(1, 2, 0), 'onto a fader: j/k are never the control\'s');
  assert.deepEqual(plain(model.vertical(look, at(1, 2, 0), 1)), at(2, 0, 1), 'onto a chip row at its chosen chip');
  assert.deepEqual(plain(model.vertical(look, at(2, 0, 2), 1)), at(2, 1, 0), 'off a chip row from any chip');
  assert.deepEqual(plain(model.vertical(look, at(1, 0, 0), -1)), at(0, 2, 1), 'past the top: the previous strip\'s last');
  assert.deepEqual(plain(model.vertical(look, at(2, 3, 0), 1)), at(0, 0, 0), 'past the desk\'s end: the first strip');
  assert.deepEqual(plain(model.vertical(look, at(0, 0, 0), -1)), at(2, 3, 0));
});

test('Tab and Shift+Tab go to the next or previous strip\'s first control', () => {
  assert.deepEqual(plain(model.tab(look, at(0, 2, 3), 1)), at(1, 0, 0));
  assert.deepEqual(plain(model.tab(look, at(1, 2, 0), 1)), at(2, 0, 1));
  assert.deepEqual(plain(model.tab(look, at(2, 2, 0), 1)), at(0, 0, 0), 'wrapping');
  assert.deepEqual(plain(model.tab(look, at(1, 1, 0), -1)), at(0, 0, 0));
  assert.deepEqual(plain(model.tab(look, at(0, 0, 0), -1)), at(2, 0, 1));
});

test('a strip with nothing to use is skipped', () => {
  const desk = [[{ stops: 1 }], [], [{ stops: 1 }, { stops: 1 }]];
  assert.deepEqual(plain(model.tab(desk, at(0, 0, 0), 1)), at(2, 0, 0));
  assert.deepEqual(plain(model.vertical(desk, at(0, 0, 0), 1)), at(2, 0, 0));
  assert.deepEqual(plain(model.sideways(desk, at(2, 1, 0), 1)), at(0, 0, 0));
  assert.deepEqual(plain(model.first([[], [{ stops: 2, home: 1 }]])), at(1, 0, 1));
  assert.equal(model.first([[], []]), null);
});

test('h and l on a row keep the row, clamped to the next strip\'s last', () => {
  const behavior = [new Array(4).fill({ stops: 1 }), new Array(4).fill({ stops: 1 }), new Array(3).fill({ stops: 1 })];
  assert.deepEqual(plain(model.across(behavior, at(0, 2, 0), 1)), at(1, 2, 0));
  assert.deepEqual(plain(model.across(behavior, at(1, 3, 0), 1)), at(2, 2, 0));
  assert.deepEqual(plain(model.across(behavior, at(2, 1, 0), 1)), at(0, 1, 0), 'wrapping');
  assert.deepEqual(plain(model.across(behavior, at(0, 3, 0), -1)), at(2, 2, 0));
  assert.deepEqual(plain(model.sideways(behavior, at(1, 3, 0), 1)), at(2, 2, 0), 'the same on the Behavior page');
});

test('h and l on the Look page: chip to chip on a chip row, else the same row of the next strip', () => {
  assert.deepEqual(plain(model.sideways(look, at(0, 0, 0), 1)), at(1, 0, 0), 'a pick row to the next strip\'s row');
  assert.deepEqual(plain(model.sideways(look, at(1, 1, 0), 1)), at(2, 1, 0), 'a switch to the next strip\'s row');
  assert.deepEqual(plain(model.sideways(look, at(2, 3, 0), 1)), at(0, 2, 1), 'clamped, wrapping round the desk, onto a chip row at its chosen chip');
  assert.deepEqual(plain(model.sideways(look, at(0, 1, 0), -1)), at(2, 1, 0), 'wrapping back');
  assert.deepEqual(plain(model.sideways(look, at(0, 2, 1), 1)), at(0, 2, 2), 'chip to chip');
  assert.deepEqual(plain(model.sideways(look, at(0, 2, 1), -1)), at(0, 2, 0));
  assert.deepEqual(plain(model.sideways(look, at(0, 2, 3), 1)), at(0, 2, 3), 'the row\'s end: nothing happens');
  assert.deepEqual(plain(model.sideways(look, at(2, 0, 0), -1)), at(2, 0, 0), 'nor at its start');
});

test('a place whose control has gone lands on the nearest one left', () => {
  assert.deepEqual(plain(model.valid(look, at(1, 7, 0))), at(1, 2, 0));
  assert.deepEqual(plain(model.valid(look, at(2, 0, 5))), at(2, 0, 2));
  assert.deepEqual(plain(model.valid(look, at(9, 0, 0))), at(0, 0, 0));
  assert.deepEqual(plain(model.valid(look, null)), at(0, 0, 0));
});

test('the legend: the control\'s own line for a key replaces the page\'s, the rest lead', () => {
  const page = [{ keys: 'h l', label: 'Same row, next strip' }, { keys: 'backspace', label: 'Back to the theme\'s value' }];
  assert.deepEqual(plain(model.legend(page, [])), page);
  assert.deepEqual(plain(model.legend(page, [{ keys: 'backspace', label: 'Back to the default' }, { keys: 'enter', label: 'Apply now' }])), [
    { keys: 'enter', label: 'Apply now' }, { keys: 'h l', label: 'Same row, next strip' }, { keys: 'backspace', label: 'Back to the default' },
  ]);
});
