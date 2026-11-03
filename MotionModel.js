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

// The keyboard's key strip stays mapped (keyboard.md KEYS-32), so it fades
// itself as Hyprland fades layers (layerFade). Until Hyprland's report is
// read it fades in over 180 ms and out over 120, ease out.
function keyStripMs(showing) {
  return showing ? 180 : 120
}
var KEY_STRIP_CURVE = [0.23, 1, 0.32, 1, 1, 1]

// The strip's fade as Hyprland fades layers today, read from
// `hyprctl -j animations` ([leaves, curves]): fadeLayersIn or fadeLayersOut,
// or the nearest tuned leaf above it (fadeLayers, fade, global), its speed in
// tenths of a second and its curve. Unread, the times above and the strip's
// own curve.
var LAYER_FADE_PARENT = { fadeLayersIn: "fadeLayers", fadeLayersOut: "fadeLayers", fadeLayers: "fade", fade: "global" }
function layerFade(report, showing) {
  var leaves = Array.isArray(report) && Array.isArray(report[0]) ? report[0] : []
  var curves = Array.isArray(report) && Array.isArray(report[1]) ? report[1] : []
  var named = function(list, name) { return list.find(function(item) { return item && item.name === name }) }
  var name = showing ? "fadeLayersIn" : "fadeLayersOut"
  var leaf = named(leaves, name)
  while (leaf && leaf.overridden !== true && LAYER_FADE_PARENT[name]) {
    name = LAYER_FADE_PARENT[name]
    leaf = named(leaves, name)
  }
  if (!leaf || leaf.overridden !== true || !isFinite(leaf.speed)) return { ms: keyStripMs(showing), curve: KEY_STRIP_CURVE }
  var curve = named(curves, leaf.bezier)
  return { ms: leaf.enabled === false ? 0 : Math.round(leaf.speed * 100),
    curve: curve ? [curve.X0, curve.Y0, curve.X1, curve.Y1, 1, 1] : KEY_STRIP_CURVE }
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

// Preferences (docs/design/preferences-design-system.md, section 14). The
// pages run these while the bar's animationsEnabled is on (Powerbar's
// Animations switch and Omarchy's), and nothing moves otherwise.
// Omarchy's ease out (its Style.easeOut), for the page turn.
var EASE_OUT = [0.23, 1, 0.32, 1, 1, 1]
// A page turn: the page slides under the camera and the tab's underline
// glides, on one clock.
var PAGE_TURN_MS = 240
// Something following the cursor: a rise, the focus ring, the pulled chip,
// a tile scrolling to the cursor, a fader's knob.
var GLIDE_MS = 120
// The focus ring stops gliding once its glide has had time to end.
var GLIDE_END_MS = GLIDE_MS + 50
// A plate taking its new height or place.
var PLATE_MS = 140
// The card, the inspector and the icon picker fading in or out; the
// inspector and the icon picker grow from 97 % over APPEAR_SCALE_MS.
var APPEAR_MS = 140
var APPEAR_SCALE_MS = 160
// The centre dot going back to its side.
var SNAP_BACK_MS = 160
// A row's fill under the cursor.
var FILL_MS = 100
// A widget's name tip: shown once the pointer rests TIP_REST_MS on a chip,
// at once on the next chip within TIP_WARM_MS of leaving one, fading over
// TIP_FADE_MS.
var TIP_REST_MS = 450
var TIP_WARM_MS = 600
var TIP_FADE_MS = 110
// A keyboard lift's flying copy waits this long for rows to make room
// (outlasting PLATE_MS and GLIDE_MS) before it measures where it lands.
var LANDING_SETTLE_MS = 160
