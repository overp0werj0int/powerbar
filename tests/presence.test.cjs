const { test } = require('node:test');
const assert = require('node:assert/strict');
const load = require('./load.cjs');
const p = load('PresenceModel.js');

const FACTS = ['member', 'blank', 'drawerHost', 'inlineShown', 'activityVisible', 'panelOpen', 'hovered', 'fitFolded', 'fitYielded'];
const MODES = ['shown', 'managed', 'hidden', 'pending'];

// Every slot the facts can describe, with claim and presence filled in the
// way Bar.qml's bindings do.
function* slots() {
  for (const mode of MODES) {
    for (let bits = 0; bits < 1 << FACTS.length; bits++) {
      const f = Object.fromEntries(FACTS.map((name, i) => [name, !!(bits & (1 << i))]));
      const s = {
        mode, memberGroup: f.member ? { id: 'g' } : null, alwaysShown: mode === 'shown', managed: mode === 'managed',
        blank: f.blank, drawerHost: f.drawerHost ? {} : null, inlineShown: f.inlineShown && mode === 'managed',
        activityVisible: f.activityVisible, panelOpen: f.panelOpen, hovered: f.hovered,
        fitFolded: f.fitFolded, fitYielded: f.fitYielded,
      };
      s.claim = p.claim(s);
      s.presence = p.presence(s);
      yield s;
    }
  }
}

test('claim and presence answer what the slot bindings answered before them', () => {
  for (const s of slots()) {
    // ModuleSlot before PresenceModel (Bar.qml), member moments left out.
    const baseVisible = !s.memberGroup && (s.alwaysShown || (s.managed && !s.drawerHost
      && (s.activityVisible || s.panelOpen || s.hovered || s.inlineShown)));
    const dotsCandidate = s.managed && !s.memberGroup && !baseVisible && !s.blank;
    const mainVisible = baseVisible && !s.drawerHost && !s.fitFolded && !s.fitYielded;
    const moment = s.managed && !s.memberGroup && !s.drawerHost && !s.inlineShown && (s.activityVisible || s.panelOpen || s.hovered);
    const label = JSON.stringify(s);
    assert.equal(s.claim !== '', baseVisible, label);
    assert.equal(s.claim === 'revealed', moment, label);
    assert.equal(s.presence === 'bar', mainVisible, label);
    assert.equal(s.presence === 'waiting', dotsCandidate, label);
  }
});

test('a presence names one place', () => {
  const seen = new Set();
  for (const s of slots()) {
    seen.add(s.presence);
    if (s.presence === 'group') assert.ok(s.memberGroup);
    if (s.presence === 'yielded') assert.ok(s.fitYielded && !s.fitFolded && !s.drawerHost);
    if (s.presence === 'folded') assert.ok(s.claim === 'shown' || s.fitFolded);
  }
  assert.deepEqual([...seen].sort(), ['bar', 'folded', 'group', 'none', 'waiting', 'yielded']);
});

// A binding depends on every property the call read: an always-shown slot
// must not wake on hover, nor a member on anything but its group.
function reads(fn, facts) {
  const read = [];
  const s = new Proxy(facts, { get(t, k) { read.push(k); return t[k]; } });
  fn(s);
  return read;
}

test('claim reads no reveal fact for an always-shown slot or a member', () => {
  assert.deepEqual(reads(p.claim, { memberGroup: null, alwaysShown: true }), ['memberGroup', 'alwaysShown']);
  assert.deepEqual(reads(p.claim, { memberGroup: { id: 'g' } }), ['memberGroup']);
  assert.deepEqual(reads(p.claim, { memberGroup: null, alwaysShown: false, managed: true, drawerHost: {} }),
    ['memberGroup', 'alwaysShown', 'managed', 'drawerHost']);
});

test('presence reads the fit only for a slot that claims room', () => {
  assert.deepEqual(reads(p.presence, { claim: '', memberGroup: null, managed: true, blank: false }),
    ['claim', 'memberGroup', 'managed', 'blank']);
  assert.deepEqual(reads(p.presence, { claim: 'shown', drawerHost: null, fitFolded: false, fitYielded: false }),
    ['claim', 'drawerHost', 'fitFolded', 'fitYielded']);
});
