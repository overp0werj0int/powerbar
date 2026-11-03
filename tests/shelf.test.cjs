const { test } = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');
const shelf = load('ShelfModel.js');

test('each end joins the bar inside, flush or beyond it', () => {
  const o = shelf.outline({ length: 200, depth: 30, radius: 8, barStart: -40, barEnd: 200, barRadius: 8 });
  assert.equal(o.start, 'inside');
  assert.equal(o.end, 'flush');
  assert.equal(o.ups.length, 0);
  // Inside: the fillet curves out into the bar's edge, 8 px past the side.
  assert.match(o.fill, /^M 200 0 /);
  assert.match(o.fill, /L 0 8 A 8 8 0 0 0 -8 0 Z$/);
  const past = shelf.outline({ length: 200, depth: 30, radius: 8, barStart: 0, barEnd: 120 });
  assert.equal(past.end, 'beyond');
  assert.equal(past.ups.length, 1);
  assert.match(past.ups[0].fill, /^M 120 -8 A 8 8 0 0 0 128 0 L 120 0 Z$/);
  // Its top edge's border starts where the up fillet ends.
  assert.match(past.edge, /^M 128 0 L 192 0 A 8 8 0 0 1 200 8/);
});

test('a fillet never runs into the bottom corner of a shallow shelf', () => {
  const o = shelf.outline({ length: 100, depth: 12, radius: 8, barStart: -50, barEnd: 150 });
  // Radius held to half the depth, the side fillet to what is left of it.
  assert.match(o.fill, /A 6 6 0 0 0 100 6 /);
});

test('an end too close to the bar end to curve snaps flush with it', () => {
  const bar = { start: 4, end: 1508, radius: 8 };
  assert.equal(shelf.snapShift(10, 300, bar, 8), -6);       // 6 px in: flush
  assert.equal(shelf.snapShift(40, 300, bar, 8), 0);        // room for the fillet
  assert.equal(shelf.snapShift(1200, 300, bar, 8), 8);      // 8 px short of the end
  assert.equal(shelf.snapShift(4, 300, bar, 8), 0);         // already flush
  assert.equal(shelf.snapShift(-2, 300, { start: 4, end: 100, radius: 0 }, 6), 6);
  // An end already flush stays, and the shelf stays on the screen: a shelf
  // flush with its island's end and 10 px past its start does not move.
  assert.equal(shelf.snapShift(1308, 200, { start: 1318, end: 1508, radius: 10 }, 10, 4, 1508), 0);
  assert.equal(shelf.snapShift(1200, 300, { start: 4, end: 1508, radius: 8 }, 8, 4, 1500), 0);
});

test('an end it cannot snap curves in the room it has', () => {
  // Flush at the end, 10 px past the island's start: corner and up fillet 5 px each.
  const past = shelf.outline({ length: 200, depth: 30, radius: 10, barStart: 10, barEnd: 200, barRadius: 10 });
  assert.equal(past.start, 'beyond');
  assert.equal(past.end, 'flush');
  assert.match(past.ups[0].fill, /^M 10 -5 L 10 0 L 5 0 A 5 5 0 0 0 10 -5 Z$/);
  assert.match(past.edge, /L 0 5 A 5 5 0 0 1 5 0 L 5 0$/);
  // 6 px inside the bar's end: tight, a 6 px fillet, the bar's corner square.
  const tight = shelf.outline({ length: 200, depth: 30, radius: 10, barStart: -6, barEnd: 300, barRadius: 10 });
  assert.equal(tight.start, 'tight');
  assert.match(tight.fill, /L 0 6 A 6 6 0 0 0 -6 0 Z$/);
  assert.deepEqual(shelf.squaredCorners('top', tight.start, tight.end), ['bl']);
});

test('the bar corners a shelf squares, per bar edge', () => {
  assert.deepEqual(shelf.squaredCorners('top', 'flush', 'inside'), ['bl']);
  assert.deepEqual(shelf.squaredCorners('top', 'inside', 'beyond'), ['br']);
  assert.deepEqual(shelf.squaredCorners('bottom', 'flush', 'flush'), ['tl', 'tr']);
  assert.deepEqual(shelf.squaredCorners('left', 'flush', 'inside'), ['tr']);
  assert.deepEqual(shelf.squaredCorners('right', 'inside', 'flush'), ['bl']);
});

test("alignStart: flush with the surface's end nearest the source, kept on screen", () => {
  const bar = { start: 100, end: 400 }
  assert.equal(shelf.alignStart(bar, 150, { start: 110, end: 140 }, 4, 1508), 100)
  assert.equal(shelf.alignStart(bar, 150, { start: 350, end: 380 }, 4, 1508), 250)
  assert.equal(shelf.alignStart(bar, 500, { start: 350, end: 380 }, 4, 1508), 4)
  assert.equal(shelf.alignStart({ start: 1300, end: 1508 }, 300, { start: 1310, end: 1340 }, 4, 1508), 1208)
})

test('fit: an end that cannot move lengthens until both can curve cleanly', () => {
  const bar = { start: 100, end: 400, radius: 12 };
  const fit = (start, length, grow = true) => {
    const { start: s, length: l } = shelf.fit(start, length, bar, 12, 4, 1500, grow);
    return [s, l];
  };
  assert.deepEqual(fit(150, 100), [150, 100]);    // well inside: as it is
  assert.deepEqual(fit(105, 295), [100, 300]);    // flush at the end, 5 px short of the start
  assert.deepEqual(fit(100, 295), [100, 300]);    // the same at the other end
  assert.deepEqual(fit(90, 310), [76, 324]);      // flush at the end, 10 px past: two radii past
  assert.deepEqual(fit(100, 310), [100, 324]);
  assert.deepEqual(fit(60, 340), [60, 340]);      // past by more than two radii: as it is
  // Past a surface at the screen's edge: only as far as the screen.
  assert.deepEqual(shelf.fit(90, 310, bar, 12, 80, 1500, true), { start: 80, length: 320 });
  // A menu's rows have their own width: it moves but never lengthens.
  assert.deepEqual(fit(105, 295, false), [105, 295]);
});

test('fit: a lengthened shelf joins flush, with no nub', () => {
  const bar = { start: 100, end: 400, radius: 12 };
  const { start, length } = shelf.fit(105, 295, bar, 12, 4, 1500, true);
  const o = shelf.outline({ length, depth: 40, radius: 12, barStart: bar.start - start, barEnd: bar.end - start, barRadius: 12 });
  assert.deepEqual([o.start, o.end], ['flush', 'flush']);
  const past = shelf.fit(90, 310, bar, 12, 4, 1500, true);
  const p = shelf.outline({ length: past.length, depth: 40, radius: 12, barStart: bar.start - past.start, barEnd: bar.end - past.start, barRadius: 12 });
  assert.equal(p.start, 'beyond');
  assert.match(p.ups[0].fill, /A 12 12/);
});
