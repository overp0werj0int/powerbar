// The inline expansion's queue: which zone to show, and when. Pure decisions;
// Bar.qml carries them out (docs/zone-fit-implementation.md, "Inline").
//
// state: { request, zone, readyAt }   what the pointer asks for, what is shown,
//                                     and the earliest time a zone may open
// o:     { now, due, enabled, intentMs, settleMs, timerRunning, holdHeld }
//        due: the queue's timer fired; holdHeld: the centre's hover reveal is
//        held with the pointer elsewhere
//
// Rules: the pointer rests intentMs on the dots before a zone opens (a swipe
// across them opens nothing); a shown zone collapses at once when the request
// changes, and the next opens only settleMs later, so two zones never move
// together; opening another zone releases the centre's held reveal and waits
// for it to settle too.
//
// Returns { collapse, releaseHold, expand, readyAt, wait, stop, hold }:
// collapse the shown zone; release the held reveal; try to open expand (the
// bar checks that it fits, else opens the drawer); restart the timer for wait
// ms; stop the timer; or hold the zone that is shown.
function advance(state, o) {
  var want = o.enabled ? state.request : ""
  var r = { collapse: false, releaseHold: false, expand: "", readyAt: state.readyAt, wait: 0, stop: false, hold: false }
  if (want === state.zone) {
    r.stop = true
    r.hold = !!want
    return r
  }
  if (state.zone) {
    r.collapse = true
    r.readyAt = Math.max(r.readyAt, o.now + o.settleMs)
  }
  if (!want) {
    r.stop = true
    return r
  }
  if (!o.due) {
    if (!o.timerRunning || r.collapse) r.wait = Math.max(1, Math.max(o.now + o.intentMs, r.readyAt) - o.now)
    return r
  }
  if (want !== "center" && o.holdHeld) {
    r.releaseHold = true
    r.readyAt = Math.max(r.readyAt, o.now + o.settleMs)
  }
  if (o.now < r.readyAt) {
    r.wait = Math.max(1, r.readyAt - o.now)
    return r
  }
  r.expand = want
  return r
}
