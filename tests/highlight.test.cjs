const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../HighlightModel.js`, 'utf8'), model);
const base = { thickness: 20, pad: 4, rounding: 17, laneStart: -Infinity, laneEnd: Infinity };

test('lone icons all get the same square highlight, never thinner than thick', () => {
  const a = model.pill({ ...base, center: 50, ink: 14 });
  const b = model.pill({ ...base, center: 90, ink: 8 });
  assert.equal(model.pill({ ...base, center: 0, ink: 20 }).length, 20);
  assert.equal(model.pill({ ...base, center: 0, ink: 21 }).length, 29);
  assert.equal(a.length, 20);
  assert.equal(b.length, 20);
  assert.equal(a.start, 40);
  assert.equal(a.radius, 10);
});
test('text gets a pill with equal padding around what it paints', () => {
  const p = model.pill({ ...base, center: 100, ink: 60 });
  assert.equal(p.length, 68);
  assert.equal(p.start, 66);
});
test('a highlight stays inside its lane by shifting, then by shrinking', () => {
  assert.equal(model.pill({ ...base, center: 30, ink: 60, laneStart: 10, laneEnd: 200 }).start, 10);
  assert.equal(model.pill({ ...base, center: 190, ink: 60, laneStart: 10, laneEnd: 200 }).start, 132);
  const tight = model.pill({ ...base, center: 30, ink: 60, laneStart: 10, laneEnd: 50 });
  assert.deepEqual([tight.start, tight.length], [10, 40]);
});
test('corner radius nests inside the island but never exceeds a pill', () => {
  assert.equal(model.pill({ ...base, center: 0, ink: 0, rounding: 4 }).radius, 4);
  assert.equal(model.pill({ ...base, center: 0, ink: 0, rounding: 40 }).radius, 10);
});
test('ink is read from glyph, label and painted hints, then from children', () => {
  assert.equal(model.inkWidth({ glyphPaintedWidth: 14 }), 14);
  assert.equal(model.inkWidth({ labelWidth: 52 }), 52);
  assert.equal(model.inkWidth({ labelWidth: 52, textRotation: 90, children: [] }), 0);
  const child = (x, width) => ({ x, width, height: 10, visible: true, opacity: 1, children: [] });
  assert.equal(model.inkWidth({ children: [child(4, 10), child(20, 12)] }), 28);
  assert.equal(model.inkWidth({ children: [{ ...child(0, 30), paintedWidth: 22 }] }), 22);
});
test('a badge drawn inside its button is decoration: the button alone is measured', () => {
  const node = (x, y, width, height, extra) => ({ x, y, width, height, visible: true, opacity: 1, children: [], ...extra });
  // The notification bell: a 40 px kit button with an unread dot in its top-right corner.
  const bell = node(0, 0, 40, 27, { glyphPaintedWidth: 14, glyphFontSize: 13 });
  const dot = node(31, 5, 6, 6, { color: 'x', radius: 3 });
  assert.deepEqual(Array.from(model.withoutBadges([bell, dot])), [bell]);
  // Across a vertical bar, the ink centres on the bell, not on bell plus dot.
  const widget = node(0, 0, 40, 27, { children: [bell, dot] });
  const ink = model.inkRect(widget, false);
  assert.equal(ink.start + ink.length / 2, 20);
  // Something beside the button, outside its box, is still content.
  const label = node(42, 4, 30, 18, { paintedWidth: 30 });
  assert.equal(model.withoutBadges([bell, label]).length, 2);
  // Two kit buttons (a compound widget) are both content.
  const other = node(10, 2, 12, 12, { glyphPaintedWidth: 10, glyphFontSize: 13 });
  assert.equal(model.withoutBadges([bell, other]).length, 2);
});

test('unsizedIconLoaders: a drawn icon that fills the kit loader at zero size is found once', () => {
  const loader = { width: 0, height: 0, item: null, sourceComponent: {}, children: [] };
  loader.item = { anchors: { fill: loader }, width: 0, height: 0, children: [] };
  const content = { sourceComponent: {}, sourceSize: 16, contentScale: 1, children: [loader] };
  const button = { children: [{ children: [content] }] };
  const widget = { children: [button] };
  const found = model.unsizedIconLoaders(widget);
  assert.equal(found.length, 1);
  assert.equal(found[0].loader, loader);
  assert.equal(found[0].content, content);
  // Once sized, or when the icon keeps its own size, nothing to do.
  assert.equal(model.unsizedIconLoaders({ children: [{ ...content, children: [{ ...loader, width: 16, height: 16 }] }] }).length, 0);
  const own = { width: 0, height: 0, item: { anchors: { fill: null }, width: 16, height: 16 }, sourceComponent: {}, children: [] };
  assert.equal(model.unsizedIconLoaders({ children: [{ ...content, children: [own] }] }).length, 0);
});
