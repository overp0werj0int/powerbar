// Pure rules for Preferences sliders: snapping, wheel notches and when an
// edit has settled enough to apply to the bar.
//
// A slider keeps its own draft while the user works it. The bar only changes
// once the draft settles: applying an edit re-renders every bar widget and
// Omarchy re-registers them all on the config write, so applying per pointer
// move or per key repeat makes the bar flicker and stutter.

// Quiet time before a keyboard or wheel edit applies.
var SETTLE = 450
// Longest quiet time, however slowly the user steps.
var SETTLE_MAX = 1000
// Steps closer together than this are one gesture; the wait stretches to
// 1.6 times the gap, so tapping at a steady pace never applies mid-run.
var RHYTHM = 1200
var RHYTHM_FACTOR = 1.6
// After a pointer release: long enough to catch a quick re-grab.
var RELEASE = 120
// One wheel notch, in angle-delta units (a touchpad sends fractions of it).
var NOTCH = 120

function clamp(v, min, max) {
  var n = Number(v)
  if (!isFinite(n)) n = min
  return Math.max(min, Math.min(max, n))
}

// Round to the nearest step counted from `min`, then clamp. Clean decimals
// so 0.5 steps never print as 1.4999999.
function snap(v, min, max, step) {
  var s = step > 0 ? step : 1
  var n = clamp(v, min, max)
  var snapped = min + Math.round((n - min) / s) * s
  return clamp(Math.round(snapped * 1000) / 1000, min, max)
}

// Value under a pointer at `x` along a track `width` wide.
function fromPosition(x, width, min, max, step) {
  var t = width > 0 ? clamp(x / width, 0, 1) : 0
  return snap(min + t * (max - min), min, max, step)
}

// Fraction of the track a value fills.
function progress(v, min, max) {
  return max > min ? clamp((v - min) / (max - min), 0, 1) : 0
}

// How long to wait before applying, given the gap in ms between this edit
// and the previous one (Infinity for the first).
function settleDelay(gap) {
  if (!(gap >= 0 && gap < RHYTHM)) return SETTLE
  return Math.min(SETTLE_MAX, Math.max(SETTLE, Math.round(gap * RHYTHM_FACTOR)))
}

// Whole notches in an accumulated wheel delta, and what is left over.
function wheelSteps(accumulated, delta) {
  var total = (Number(accumulated) || 0) + (Number(delta) || 0)
  var steps = (total > 0 ? Math.floor(total / NOTCH) : Math.ceil(total / NOTCH)) || 0
  return { steps: steps, rest: total - steps * NOTCH }
}

// Notches cut into the track: one per step when there are few enough to
// read as positions, none otherwise.
function tickCount(min, max, step) {
  if (!(step > 0) || !(max > min)) return 0
  var count = Math.round((max - min) / step) + 1
  return count <= 11 ? count : 0
}
