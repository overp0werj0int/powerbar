// Where a bar slot is, decided once (docs/design/zone-fit.md, "Presence").
// Bar.qml hands over the slot itself: each function reads only the facts it
// needs, in the order below, so a binding that calls one depends on what it
// read and no more (an always-shown slot never depends on its hover).
//
// s: { memberGroup, alwaysShown, managed, blank, drawerHost, inlineShown,
//      activityVisible, panelOpen, hovered, claim, fitFolded, fitYielded }

// What the slot asks of its zone before the zone fit: "shown" (always
// shown), "expanded" (its zone's inline expansion shows it), "revealed"
// (activity, an open panel or hover), or "" (nothing: a group member, a
// pending or hidden widget, an on-demand one at rest or drawn by a drawer
// row). The fit reads it; it never reads the fit's answer.
function claim(s) {
  if (s.memberGroup) return ""
  if (s.alwaysShown) return "shown"
  if (!s.managed || s.drawerHost) return ""
  if (s.inlineShown) return "expanded"
  return s.activityVisible || s.panelOpen || s.hovered ? "revealed" : ""
}

// Where the slot is after the fit: "bar" (drawn and taking input),
// "yielded" (keeps its room, unseen, while a moment grows), "folded" (no
// room, or drawn by a drawer row), "waiting" (on demand, behind its zone's
// dots or drawer button), "group" (in its group's drawer), or "none"
// (pending, hidden, or an absent tray item).
function presence(s) {
  if (s.claim === "") return s.memberGroup ? "group" : s.managed && !s.blank ? "waiting" : "none"
  if (s.drawerHost || s.fitFolded) return "folded"
  return s.fitYielded ? "yielded" : "bar"
}
