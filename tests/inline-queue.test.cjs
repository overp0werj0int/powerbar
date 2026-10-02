const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const c = vm.createContext({});
vm.runInContext(fs.readFileSync(`${__dirname}/../InlineQueue.js`, 'utf8'), c);
const advance = (s, o) => JSON.parse(JSON.stringify(c.advance(s, o)));

// A small driver: the bar's side of the queue, with a fake clock and timer.
function driver(opts = {}) {
  const d = {
    now: 0, request: '', zone: '', readyAt: 0, timerAt: null, holdHeld: !!opts.holdHeld,
    fits: opts.fits || (() => true), log: [], enabled: true,
    settleMs: opts.settleMs === undefined ? 170 : opts.settleMs, intentMs: 90,
    step(due) {
      const r = advance({ request: d.request, zone: d.zone, readyAt: d.readyAt }, {
        now: d.now, due, enabled: d.enabled, intentMs: d.intentMs, settleMs: d.settleMs,
        timerRunning: d.timerAt !== null, holdHeld: d.holdHeld });
      d.readyAt = r.readyAt;
      if (r.collapse) { d.log.push(`${d.now} collapse ${d.zone}`); d.zone = ''; }
      if (r.releaseHold) { d.holdHeld = false; d.log.push(`${d.now} release`); }
      if (r.stop) d.timerAt = null;
      if (r.wait > 0) d.timerAt = d.now + r.wait;
      if (r.expand) {
        if (d.fits(r.expand)) { d.zone = r.expand; d.log.push(`${d.now} expand ${r.expand}`); }
        else { d.request = ''; d.log.push(`${d.now} drawer ${r.expand}`); }
      }
    },
    ask(zone) { if (d.request !== zone) { d.request = zone; d.timerAt = null; } d.step(false); },
    run(until) {
      while (d.timerAt !== null && d.timerAt <= until) { d.now = d.timerAt; d.timerAt = null; d.step(true); }
      d.now = until;
    }
  };
  return d;
}

test('resting on the dots opens the zone after the hover intent', () => {
  const d = driver();
  d.ask('left');
  d.run(89);
  assert.equal(d.zone, '');
  d.run(90);
  assert.equal(d.zone, 'left');
  assert.deepEqual(d.log, ['90 expand left']);
});

test('a swipe across the dots opens nothing', () => {
  const d = driver();
  d.ask('left'); d.run(40);
  d.ask(''); d.run(60);
  d.ask('center'); d.run(100);
  d.ask(''); d.run(500);
  assert.equal(d.zone, '');
  assert.deepEqual(d.log, []);
});

test('switching zones collapses first and opens the next once it has settled', () => {
  const d = driver();
  d.ask('left'); d.run(90);
  d.run(1000);
  d.ask('right');
  assert.equal(d.zone, '', 'the open zone collapses at once');
  d.run(1169);
  assert.equal(d.zone, '');
  d.run(1170);
  assert.equal(d.zone, 'right');
  assert.deepEqual(d.log, ['90 expand left', '1000 collapse left', '1170 expand right']);
});

test('a fast run over several zones opens only where the pointer stops', () => {
  const d = driver();
  d.ask('left'); d.run(90);
  d.run(500);
  d.ask('center'); d.run(550);
  d.ask('right'); d.run(600);
  d.run(2000);
  assert.equal(d.zone, 'right');
  assert.deepEqual(d.log, ['90 expand left', '500 collapse left', '670 expand right']);
});

test('the same zone again holds; leaving it collapses', () => {
  const d = driver();
  d.ask('left'); d.run(90);
  d.ask('left'); d.run(400);
  assert.equal(d.zone, 'left');
  d.ask(''); d.run(401);
  assert.equal(d.zone, '');
  assert.deepEqual(d.log, ['90 expand left', '400 collapse left']);
});

test('opening another zone releases the centre reveal and waits for it', () => {
  const d = driver({ holdHeld: true });
  d.ask('right'); d.run(90);
  assert.equal(d.zone, '');
  assert.equal(d.holdHeld, false);
  d.run(260);
  assert.equal(d.zone, 'right');
  assert.deepEqual(d.log, ['90 release', '260 expand right']);
});

test('the centre itself keeps its reveal', () => {
  const d = driver({ holdHeld: true });
  d.ask('center'); d.run(90);
  assert.equal(d.zone, 'center');
  assert.equal(d.holdHeld, true);
});

test('without animations nothing waits to settle', () => {
  const d = driver({ settleMs: 0, holdHeld: true });
  d.ask('left'); d.run(90);
  assert.equal(d.zone, 'left');
  d.ask('right'); d.run(180);
  assert.deepEqual(d.log, ['90 release', '90 expand left', '90 collapse left', '180 expand right']);
});

test('a zone that does not fit opens its drawer and drops the request', () => {
  const d = driver({ fits: z => z !== 'center' });
  d.ask('center'); d.run(90);
  assert.equal(d.zone, '');
  assert.equal(d.request, '');
  d.run(1000);
  assert.deepEqual(d.log, ['90 drawer center']);
});

test('turning the mode off collapses at once', () => {
  const d = driver();
  d.ask('left'); d.run(90);
  d.enabled = false; d.step(false);
  assert.equal(d.zone, '');
  assert.equal(d.timerAt, null);
});
