const { test } = require('node:test');
const assert = require('node:assert/strict');
const cells = require('../CellModel.js');
const shelf = require('../ShelfModel.js');

const large = mode => cells.tokens({ bar: 38, spacing: 0, mode });
const icon = { inkStart: 7, inkLength: 13, glyph: true, cap: true };
const clock = { inkStart: 8.5, inkLength: 87, glyph: false, cap: true };

test('slots follow each other as on the bar, with the island end padding', () => {
  for (const mode of ['slots', 'gaps']) {
    const k = large(mode);
    const layout = shelf.zone(cells, k, [icon, clock, icon], 1000);
    assert.equal(layout.lines.length, 1);
    const [a, b, c] = layout.lines[0].slots;
    const pa = cells.place(k, 13, true), pb = cells.place(k, 87, false, true);
    assert.equal(a.x, cells.endPad(k, pa.spill));
    assert.equal(b.x, a.x + pa.extent);
    assert.equal(c.x, b.x + pb.extent);
    assert.equal(layout.width, c.x + pa.extent + cells.endPad(k, pa.spill));
    // The picture is shifted so its ink lands where the bar puts ink.
    assert.equal(a.offset, pa.inkStart - icon.inkStart);
    assert.equal(b.offset, pb.inkStart - clock.inkStart);
  }
});

test('a zone wraps onto another island instead of shrinking', () => {
  const k = large('slots');
  const one = shelf.zone(cells, k, [icon], 1000).width;
  const layout = shelf.zone(cells, k, [icon, icon, icon], one * 2);
  assert.ok(layout.lines.length >= 2);
  for (const line of layout.lines) assert.ok(line.width <= one * 2 + 1e-9);
  assert.deepEqual(layout.lines.flatMap(l => l.slots.map(s => s.index)), [0, 1, 2]);
  // An item wider than the room still gets a line of its own.
  const tight = shelf.zone(cells, k, [clock, icon], 10);
  assert.equal(tight.lines.length, 2);
});

test('an empty zone has no islands, and slotOf finds an item', () => {
  const k = large('gaps');
  assert.deepEqual(JSON.parse(JSON.stringify(shelf.zone(cells, k, [], 100))), { lines: [], width: 0 });
  const layout = shelf.zone(cells, k, [icon, clock], 1000);
  assert.equal(shelf.slotOf(layout, 1).slot.index, 1);
  assert.equal(shelf.slotOf(layout, 5), null);
});
