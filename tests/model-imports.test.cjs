const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Node resolves a model's `.import` lines through tests/load.cjs; only Qt's
// engine shows that the real shell resolves them too.
test('every model that imports another is loaded by the QML import test', () => {
  const root = path.join(__dirname, '..');
  const qml = fs.readFileSync(path.join(__dirname, 'qml', 'tst_ModelImports.qml'), 'utf8');
  const importing = fs.readdirSync(root).filter(f => f.endsWith('.js') && /^\.import /m.test(fs.readFileSync(path.join(root, f), 'utf8')));
  assert.ok(importing.length > 0);
  assert.deepEqual(importing.filter(f => !qml.includes(`import "../../${f}"`)), []);
});
