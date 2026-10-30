// How long the bar's motions run, in ms: the animations take their durations
// from here, and the frame log (FrameLog.qml, INTEG-146) times each motion's
// frames by the same numbers.

// The autohidden strip slides out over 180 ms, answering the pointer, and
// away over 130 (LOOK-104, 105). On the notch a zone springs out of the
// camera over 220 and slips back in over 140.
function stripMs(out, notch) {
  return notch ? (out ? 220 : 140) : out ? 180 : 130
}

// Drawers open a few dozen times a day: quick, closing faster than opening.
// From the notch they slide out of the camera as its zones do.
function drawerMs(opening, notch) {
  return notch ? stripMs(opening, true) : opening ? 160 : 110
}

// A widget growing into or out of its zone (an inline expansion, an activity
// reveal, the zone dots).
var SLOT_MS = 120
// Neighbours making room fade out at once over GIVE_WAY_MS, and widgets
// coming in wait as long (on-demand-drawers.md DEMAND-90). A fold fades out
// over FOLD_OUT_MS. Either comes back after YIELD_PAUSE_MS, once the zone
// has shrunk, over YIELD_BACK_MS.
var GIVE_WAY_MS = 80
var FOLD_OUT_MS = 110
var YIELD_PAUSE_MS = 120
var YIELD_BACK_MS = 160

// An inline expansion: its widgets grow, after the neighbours have made way
// when some must; closing, the neighbours coming back outlast the widgets
// shrinking.
function inlineMs(opening, giveWay) {
  return opening ? (giveWay ? GIVE_WAY_MS : 0) + SLOT_MS : YIELD_PAUSE_MS + YIELD_BACK_MS
}
