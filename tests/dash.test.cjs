const { test } = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');

const model = load('DashModel.js');
const near = (a, b) => Math.abs(a - b) < 1e-6;

// The four corners are one piece turned: the same length and point count.
for (const [w, h, r] of [[120, 30, 0], [120, 30, 5], [37, 23, 4], [300, 42, 1]]) {
  test(`every corner the same (${w}x${h}, radius ${r})`, () => {
    const lines = model.frame(w, h, r, r, 3, 3);
    const length = line => line.slice(1).reduce((s, p, i) => s + Math.hypot(p.x - line[i].x, p.y - line[i].y), 0);
    const corners = lines.slice(0, 4);
    for (const c of corners) {
      assert.equal(c.length, corners[0].length);
      assert.ok(near(length(c), length(corners[0])));
    }
  });
}

// Each side: whole dashes, the gaps between and at both ends equal, so the
// side is mirrored about its middle and nothing overlaps a corner.
test('a side starts and ends with the same gap', () => {
  const lines = model.frame(101, 27, 0, 0, 3, 3);
  const top = lines.slice(4).filter(l => near(l[0].y, 0.5) && near(l[1].y, 0.5));
  assert.ok(top.length > 3);
  const cornerEnd = 0.5 + 3, cornerStart = 100.5 - 3;
  const gaps = [top[0][0].x - cornerEnd];
  for (let i = 1; i < top.length; i++) gaps.push(top[i][0].x - top[i - 1][1].x);
  gaps.push(cornerStart - top[top.length - 1][1].x);
  for (const g of gaps) {
    assert.ok(near(g, gaps[0]), `even gaps: ${gaps}`);
    assert.ok(g > 0, 'no dash touches its neighbour or a corner');
  }
  for (const d of top) assert.ok(near(d[1].x - d[0].x, 3), 'whole dashes');
});

test('a frame too small for a stroke draws nothing', () => {
  assert.deepEqual(model.frame(0.5, 10, 0, 0, 3, 3), []);
});
