const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const m = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../GroupBadgeModel.js`, 'utf8'), m);
const plain = value => JSON.parse(JSON.stringify(value));

test('auto-detects notification counts and urgency without polling', () => {
  assert.deepEqual(plain(m.sample({ unseenCount: 4, count: 9, hasUnseenPerson: true }, '', '')), { count: 4, urgent: true });
  assert.deepEqual(plain(m.sample({ downCount: 2 }, '', '')), { count: 2, urgent: true });
  assert.deepEqual(plain(m.sample({ updateCount: 3 }, '', '')), { count: 3, urgent: false });
});
test('manual property overrides and none are respected', () => {
  const widget = { unreadCount: 12, newItems: 5, alarming: true };
  assert.deepEqual(plain(m.sample(widget, 'newItems', 'alarming')), { count: 5, urgent: true });
  assert.deepEqual(plain(m.sample(widget, 'none', 'alarming')), { count: 0, urgent: false });
  assert.equal(m.propertyName('nested.path', false), '');
});
test('sum and member-count aggregation differ and ignore inactive widgets', () => {
  const samples = [{ count: 3, urgent: false }, { count: 6, urgent: true }, { count: 0, urgent: true }];
  assert.deepEqual(plain(m.aggregate(samples, 'sum')), { count: 9, urgent: true });
  assert.deepEqual(plain(m.aggregate(samples, 'members')), { count: 2, urgent: true });
});
