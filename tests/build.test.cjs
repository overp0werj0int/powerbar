const { test } = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');

const v1 = { digest: 'aaa', commit: '1111111', dirty: false, version: '1.0.0' };
const v2 = { digest: 'bbb', commit: '2222222', dirty: false, version: '2.0.0' };

test('the first stamp of a process is the running code', () => {
  const { running, behind, notify } = load('BuildModel.js').observe(v1, 'first');
  assert.deepEqual(running, { ...v1, loadedAt: 'first' });
  assert.equal(behind, false);
  assert.equal(notify, false);
});

test('a bar rebuilt on the same files changes nothing', () => {
  const model = load('BuildModel.js');
  model.observe(v1, 'first');
  const { running, behind, notify } = model.observe(v1, 'second');
  assert.equal(running.loadedAt, 'first');
  assert.equal(behind, false);
  assert.equal(notify, false);
});

test('a bar rebuilt on newer files still answers the old code and asks for a restart once', () => {
  const model = load('BuildModel.js');
  model.observe(v1, 'first');
  const update = model.observe(v2, 'second');
  assert.equal(update.running.digest, 'aaa');
  assert.equal(update.running.version, '1.0.0');
  assert.equal(update.running.loadedAt, 'first');
  assert.equal(update.behind, true);
  assert.equal(update.notify, true);
  const again = model.observe(v2, 'third');
  assert.equal(again.behind, true);
  assert.equal(again.notify, false);
});

test('each new set of files asks again', () => {
  const model = load('BuildModel.js');
  model.observe(v1, 'first');
  model.observe(v2, 'second');
  assert.equal(model.observe({ ...v2, digest: 'ccc' }, 'third').notify, true);
});

test('files put back to the running code need no restart', () => {
  const model = load('BuildModel.js');
  model.observe(v1, 'first');
  model.observe(v2, 'second');
  assert.equal(model.observe(v1, 'third').behind, false);
});

test('a stamp that failed neither sets the running code nor asks for a restart', () => {
  const model = load('BuildModel.js');
  const failed = { digest: '', commit: '', dirty: false, version: '' };
  assert.equal(model.observe(failed, 'first').running.digest, '');
  assert.equal(model.observe(v1, 'second').running.loadedAt, 'second');
  const { behind, notify } = model.observe(failed, 'third');
  assert.equal(behind, false);
  assert.equal(notify, false);
});
