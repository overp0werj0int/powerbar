const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const load = file => { const c = vm.createContext({}); vm.runInContext(fs.readFileSync(`${__dirname}/../${file}`, 'utf8'), c); return c; };
const notice = load('ZoneFitNotice.js');
const lines = r => Array.from(notice.lines(r));

test('one widget, one zone', () => {
  assert.deepEqual(lines({ 'eDP-1': { left: 0, center: 1, right: 0 } }),
    ["1 widget doesn't fit on eDP-1. It's in the Center drawer."]);
});
test('several widgets, one zone', () => {
  assert.deepEqual(lines({ 'eDP-1': { left: 0, center: 3, right: 0 } }),
    ["3 widgets don't fit on eDP-1. They're in the Center drawer."]);
});
test('two and three zones', () => {
  assert.deepEqual(lines({ 'eDP-1': { left: 0, center: 3, right: 1 } }),
    ["4 widgets don't fit on eDP-1. They're in the Center and Right drawers."]);
  assert.deepEqual(lines({ 'eDP-1': { left: 1, center: 3, right: 2 } }),
    ["6 widgets don't fit on eDP-1. They're in the Left, Center and Right drawers."]);
});
test('screens sorted, empty ones skipped, unnamed screen', () => {
  assert.deepEqual(lines({ 'HDMI-A-1': { left: 0, center: 2, right: 0 }, 'DP-2': { left: 0, center: 0, right: 0 }, '': { left: 1, center: 0, right: 0 } }),
    ["1 widget doesn't fit on this screen. It's in the Left drawer.", "2 widgets don't fit on HDMI-A-1. They're in the Center drawer."]);
  assert.deepEqual(lines({}), []);
  assert.deepEqual(lines(null), []);
});
