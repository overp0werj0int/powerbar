// ShortcutApply.sh against a temporary Hyprland folder, with a stub hyprctl:
// the user's binds are never lost, whatever goes wrong.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const S = require('../ShortcutModel.js');

const script = path.join(__dirname, '..', 'ShortcutApply.sh');
const BLOCK = [S.BEGIN, 'o.bind("SUPER + B", "Powerbar keyboard", "omarchy-shell powerbar keys")', S.END].join('\n');
const USER = 'o.bind("SUPER + Q", "Close", "close")\no.bind("SUPER + W", "Web", "web")';

// A hypr folder and a stub hyprctl: `reload` turns the text in refuse (if
// any) into a config error, as Hyprland would for a block it can't load.
function box() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'powerbar-apply-'));
  const hypr = path.join(root, 'hypr'), bin = path.join(root, 'bin');
  fs.mkdirSync(hypr); fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'hyprctl'), `#!/bin/sh
case "$1" in
  configerrors) cat "${root}/errors" 2>/dev/null ;;
  reload) [ -f "${root}/refuse" ] && cp "${root}/refuse" "${root}/errors" ;;
esac
exit 0
`, { mode: 0o755 });
  const run = (block, env = {}) => spawnSync('bash', [script, block, S.BEGIN, S.END, S.OLD_START, S.OLD_END], {
    encoding: 'utf8', env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, POWERBAR_HYPR_DIR: hypr, ...env } });
  const file = path.join(hypr, 'bindings.lua');
  return { root, hypr, file, run, read: () => fs.readFileSync(file, 'utf8') };
}
const answer = r => r.stdout.trim().split('\n').pop();

test('the block goes at the end the first time and replaces itself after, the user\'s lines kept', () => {
  const b = box();
  fs.writeFileSync(b.file, USER + '\n');
  let r = b.run(BLOCK);
  assert.equal(answer(r), 'ok'); assert.equal(r.status, 0);
  assert.equal(b.read(), USER + '\n\n' + BLOCK + '\n');
  fs.appendFileSync(b.file, 'o.bind("SUPER + E", "Files", "files")\n');
  const next = BLOCK.replace('SUPER + B', 'SUPER + K');
  r = b.run(next);
  assert.equal(answer(r), 'ok');
  assert.equal(b.read(), USER + '\n\n' + next + '\no.bind("SUPER + E", "Files", "files")\n');
  r = b.run('');
  assert.equal(answer(r), 'ok');
  assert.equal(b.read(), USER + '\n\no.bind("SUPER + E", "Files", "files")\n');
});

test('a damaged block (a marker without its pair) is refused and nothing is written', () => {
  for (const damaged of [`${USER}\n${S.BEGIN}\nold\n`, `${USER}\n${S.END}\n`, `${S.END}\n${S.BEGIN}\n${USER}\n`,
    `${S.BEGIN}\n${S.END}\n${S.BEGIN}\n${S.END}\n${USER}\n`]) {
    const b = box();
    fs.writeFileSync(b.file, damaged);
    const r = b.run(BLOCK);
    assert.equal(r.status, 2);
    assert.match(answer(r), /^fail .*damaged Powerbar block/);
    assert.equal(b.read(), damaged);
    assert.deepEqual(fs.readdirSync(b.hypr).sort(), ['bindings.lua']);
  }
});

test('a file it may not write is refused, not reported done', () => {
  const b = box();
  fs.writeFileSync(b.file, USER + '\n'); fs.chmodSync(b.file, 0o444);
  const r = b.run(BLOCK);
  assert.equal(r.status, 2); assert.match(answer(r), /^fail .*not writable/);
  assert.equal(b.read(), USER + '\n');
});

test('no temporary folder is needed, so a broken TMPDIR can not empty the file', () => {
  const b = box();
  fs.writeFileSync(b.file, USER + '\n');
  const r = b.run(BLOCK, { TMPDIR: '/nonexistent/powerbar' });
  assert.equal(answer(r), 'ok');
  assert.equal(b.read(), USER + '\n\n' + BLOCK + '\n');
});

test('a block Hyprland refuses is taken back and the file is as it was', () => {
  const b = box();
  fs.writeFileSync(b.file, USER + '\n');
  fs.writeFileSync(path.join(b.root, 'refuse'), 'bindings.lua:4: bad key\n');
  const r = b.run(BLOCK);
  assert.equal(r.status, 1); assert.equal(answer(r), 'error bindings.lua:4: bad key');
  assert.equal(b.read(), USER + '\n');
  assert.deepEqual(fs.readdirSync(b.hypr).sort(), ['bindings.lua']);
});

test('a linked bindings.lua stays a link, its target gets the block', () => {
  const b = box();
  const target = path.join(b.root, 'dotfiles-bindings.lua');
  fs.writeFileSync(target, USER + '\n'); fs.symlinkSync(target, b.file);
  assert.equal(answer(b.run(BLOCK)), 'ok');
  assert.ok(fs.lstatSync(b.file).isSymbolicLink());
  assert.equal(fs.readFileSync(target, 'utf8'), USER + '\n\n' + BLOCK + '\n');
});

test('the old loader in hyprland.lua goes only when it is whole', () => {
  const b = box(), main = path.join(b.hypr, 'hyprland.lua');
  fs.writeFileSync(b.file, '');
  fs.writeFileSync(main, `a\n${S.OLD_START}\ndofile("powerbar.lua")\n${S.OLD_END}\nb\n`);
  assert.equal(answer(b.run(BLOCK)), 'ok');
  assert.equal(fs.readFileSync(main, 'utf8'), 'a\nb\n');
  fs.writeFileSync(main, `a\n${S.OLD_START}\nb\n`);
  assert.equal(answer(b.run(BLOCK)), 'ok');
  assert.equal(fs.readFileSync(main, 'utf8'), `a\n${S.OLD_START}\nb\n`);
});
