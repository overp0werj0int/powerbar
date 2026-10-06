const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const cell = load('CellModel.js');
const hl = load('HighlightModel.js');

test('tokens follow the bar: square icon cells on every bar size', () => {
  for (const [bar, T, air, gap] of [[26, 20, 4, 12], [38, 32, 10, 18], [28, 22, 5, 13], [40, 34, 11, 19]]) {
    const k = cell.tokens({ bar });
    assert.equal(k.inset, 3);
    assert.equal(k.thickness, T);
    assert.equal(k.cell, T);
    assert.equal(k.air, air);
    assert.equal(k.gap, gap);
    assert.equal(k.gutter, 3);
  }
});
test('spacing widens gutters and gaps, never cells', () => {
  const k = cell.tokens({ bar: 26, spacing: 4 });
  assert.equal(k.cell, 20);
  assert.equal(k.gutter, 7);
  assert.equal(k.gap, 16);
  assert.equal(cell.place(k, 12, true).extent, 27); // Omarchy's 27 px icon pitch
});
test('cell length: glyphs square, text gets the icon air, free text capped at 160', () => {
  const k = cell.tokens({ bar: 26 });
  assert.equal(cell.cellLength(k, 7, true), 20);
  assert.equal(cell.cellLength(k, 14.4, false), 22.4);     // EN
  assert.equal(cell.cellLength(k, 10, false), 20);         // short text reads as an icon cell
  assert.equal(cell.cellLength(k, 400, false), 168);
  assert.equal(cell.isGlyph(16, false), true);
  assert.equal(cell.isGlyph(16.5, false), false);
  assert.equal(cell.isGlyph(40, true), true);
});
test('a glyph longer than its cell gets room for all of its ink', () => {
  // ScratchPeek on a side bar: "●" over its count, 32 px of ink along the bar,
  // read as a glyph across it.
  for (const mode of ['slots', 'gaps']) {
    const k = cell.tokens({ bar: 28, mode });
    const p = cell.place(k, 32, true, false);
    assert.ok(p.cell >= 32, mode + ': the highlight covers the ink');
    assert.equal(p.cell, 32 + 2 * k.air);
    assert.ok(p.spill >= 0, mode + ': the cell reaches past the ink on both sides');
    assert.ok(p.inkStart >= 0 && p.inkStart + 32 <= p.extent, mode + ': the ink sits inside the slot');
    // A glyph that fits keeps its square cell.
    assert.equal(cell.place(k, 11, true).cell, k.cell);
  }
});
test('only free text is capped; compounds and vertical stacks keep their length', () => {
  const k = cell.tokens({ bar: 40 });
  assert.equal(cell.place(k, 196, false).shown, 160);
  assert.equal(cell.place(k, 196, false, false).shown, 196);
  assert.equal(cell.cellLength(k, 196, false, false), 196 + 2 * k.air);
});
test('equal slots: cells one gutter apart, ends one inset from the island', () => {
  const k = cell.tokens({ bar: 38 });
  const icon = cell.place(k, 12, true);
  assert.deepEqual([icon.extent, icon.cell, icon.inkStart], [35, 32, 11.5]);
  const clock = cell.place(k, 107, false);
  assert.equal(clock.cell, 127);
  assert.equal(clock.inkStart, 1.5 + 10);
  // The first cell starts at endPad + gutter / 2 = the inset.
  assert.equal(cell.endPad(k, icon.spill) + k.gutter / 2, k.inset);
  const h = cell.highlight(k, icon, 20);
  assert.deepEqual([h.start, h.length, h.radius], [1.5, 32, 16]);
});
test('equal gaps: the same air between glyphs, symmetric cells spill, ends concentric', () => {
  const k = cell.tokens({ bar: 26, mode: 'gaps' });
  const a = cell.place(k, 7, true), b = cell.place(k, 14, true);
  // Glyph to glyph: a's trailing half gap plus b's leading half gap.
  assert.equal(a.extent - a.inkStart - a.shown + b.inkStart, k.gap);
  assert.equal(a.spill, 6.5);
  // The cell starts at inset from the island's end.
  const h = cell.highlight(k, a, 13);
  assert.equal(cell.endPad(k, a.spill) + h.start, k.inset);
  // A highlight stops at least 2 px short of the next glyph.
  assert.ok(k.gap - a.spill >= 2);
});
test('drag gap is the landing size; timing grows with it and is capped', () => {
  const k = cell.tokens({ bar: 38 });
  const icon = cell.place(k, 12, true), clock = cell.place(k, 107, false);
  assert.equal(cell.dragGap(k, icon), 35);
  assert.equal(cell.dragDuration(35, cell.iconGap(k)), 150);
  assert.equal(cell.dragDuration(cell.dragGap(k, clock), cell.iconGap(k)), 250);
  assert.equal(cell.dragDuration(10, 35), 150);
});
test('widths grow at once and shrink only after the hold', () => {
  let h = cell.hold(40, 60, 0, 8000, 0);
  assert.deepEqual([h.value, h.shrinkAt], [60, 0]);
  h = cell.hold(60, 30, 1000, 8000, 0);
  assert.deepEqual([h.value, h.shrinkAt], [60, 9000]);
  h = cell.hold(60, 30, 5000, 8000, 9000);
  assert.equal(h.value, 60);
  h = cell.hold(60, 30, 9000, 8000, 9000);
  assert.deepEqual([h.value, h.shrinkAt], [30, 0]);
  h = cell.hold(60, 70, 5000, 8000, 9000);
  assert.deepEqual([h.value, h.shrinkAt], [70, 0]);
  // Losing a whole icon cell or more (a reveal closing) shrinks at once;
  // a smaller change (a value losing a digit) is still held.
  h = cell.hold(160, 40, 1000, 8000, 0, 32);
  assert.deepEqual([h.value, h.shrinkAt], [40, 0]);
  h = cell.hold(60, 46, 1000, 8000, 0, 32);
  assert.deepEqual([h.value, h.shrinkAt], [60, 9000]);
});
test('badges ride the corner and stay inside the island', () => {
  const b = cell.badge({ x: 3, y: 3, width: 20, height: 20, radius: 10 }, { width: 26, height: 26 }, { width: 12, height: 12 });
  assert.ok(b.x + 12 <= 25 && b.y >= 1);
  const inside = cell.badge({ x: 40, y: 3, width: 20, height: 20, radius: 10 }, { width: 200, height: 26 }, { width: 12, height: 12 });
  assert.ok(Math.abs(inside.x - (60 - 10 * (1 - Math.SQRT1_2) - 6)) < 1e-9);
});
test('compound thumbs nest at the track curve', () => {
  const k = cell.tokens({ bar: 38 });
  const t = cell.thumb(k, 21, 20);
  assert.deepEqual([t.side, t.radius], [20, 10]);
});
test('inkRect: kit glyphs and labels are centred; children give the painted span', () => {
  const glyph = { width: 27, height: 26, glyphPaintedWidth: 9, opticalSize: 16, children: [] };
  assert.deepEqual({ ...hl.inkRect(glyph, false) }, { start: 9, length: 9, glyph: true });
  const battery = { width: 54, height: 26, glyphPaintedWidth: 41, opticalSize: 16, children: [] };
  assert.deepEqual({ ...hl.inkRect(battery, false) }, { start: 6.5, length: 41, glyph: false });
  const label = { width: 60, height: 26, labelWidth: 43, children: [] };
  assert.deepEqual({ ...hl.inkRect(label, false) }, { start: 8.5, length: 43, glyph: false });
  const child = (x, w) => ({ x, y: 0, width: w, height: 26, visible: true, opacity: 1, children: [] });
  const tray = { width: 54, height: 26, children: [child(38.5, 6)] };
  assert.deepEqual({ ...hl.inkRect(tray, false) }, { start: 38.5, length: 6, glyph: true });
  const digit = x => ({ x, y: 0, width: 20, height: 26, visible: true, opacity: 1, labelWidth: 5, children: [] });
  const workspaces = { width: 110, height: 26, children: [digit(0), digit(21), digit(42)] };
  assert.deepEqual({ ...hl.inkRect(workspaces, false) }, { start: 7.5, length: 47, glyph: false });
  // The tray keeps room for its whole drawer and slides the icons out of a
  // clipped strip when closed: only what the clip shows counts.
  const box = (x, w, extra) => ({ x, y: 0, width: w, height: 26, visible: true, opacity: 1, children: [], ...extra });
  const trayIcon = x => box(x, 27, { glyphPaintedWidth: 12, opticalSize: 16 });
  const revealTray = reveal => {
    const drawer = 81, shown = drawer * reveal;
    const strip = box(27, drawer, { clip: true, children: [box(drawer - shown, drawer, { children: [trayIcon(0), trayIcon(27), trayIcon(54)] })] });
    const chevron = box(drawer - shown, 27, { glyphPaintedWidth: 6, opticalSize: 16 });
    return box(0, 135, { children: [box(0, 108, { children: [chevron, strip] }), box(108, 27, { children: [trayIcon(0)] })] });
  };
  assert.deepEqual({ ...hl.inkRect(revealTray(0), false) }, { start: 91.5, length: 36, glyph: false });
  assert.deepEqual({ ...hl.inkRect(revealTray(1), false) }, { start: 10.5, length: 117, glyph: false });
  // Scratchpeek paints its own accent pill behind its label while its window
  // is shown here; the pill is background, so the ink stays the label.
  const pill = box(2, 142, { color: '#fff', radius: 4 });
  const button = box(0, 146, { labelWidth: 129 });
  assert.deepEqual({ ...hl.inkRect(box(0, 146, { children: [pill, button] }), false) }, { start: 8.5, length: 129, glyph: false });
  assert.deepEqual({ ...hl.inkRect(box(0, 146, { children: [button] }), false) }, { start: 8.5, length: 129, glyph: false });
  const vlabel = { width: 28, height: 40, labelWidth: 14, scaledVerticalPadding: 6, children: [] };
  assert.deepEqual({ ...hl.inkRect(vlabel, true) }, { start: 6, length: 28, glyph: true });
});
