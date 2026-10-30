// The frame log's numbers (FrameLog.qml, docs/behavior/integration.md
// INTEG-146). A run's stamps are the time its first motion started, then one
// per frame. The first interval holds the synchronous work the event set off
// and the first paint of what it changed (a surface mapping, a drawer
// building): start-up latency, reported apart. Frame-time stats count only
// the frames after it, during the motion, so a long frame is a stutter the
// user could see. A motion joining a run already moving adds no start-up: a
// stall there holds up the motion on screen and counts as a long frame.

var LONG_MS = 25

// How long frames are watched after a change that has no animation of its
// own: a card appearing (its surface maps), the bar-move ghost following
// the pointer.
var WATCH_MS = { card: 160, barmove: 200 }

// What the timeline notes for a frame `dt` ms after the last stamp, when the
// run already holds `count` stamps: "startup" for a slow first frame,
// "longframe" for a slow one during the motion, "" otherwise.
function frameNote(count, dt) {
  if (!(dt > LONG_MS)) return ""
  return count <= 1 ? "startup" : "longframe"
}

// A finished run's numbers, or null when no frame came.
function summary(stamps) {
  if (!stamps || stamps.length < 2) return null
  var iv = []
  for (var i = 2; i < stamps.length; i++) iv.push(stamps[i] - stamps[i - 1])
  var sorted = iv.slice().sort(function(a, b) { return a - b })
  var sum = 0, long = 0
  for (var j = 0; j < iv.length; j++) { sum += iv[j]; if (iv[j] > LONG_MS) long++ }
  var n = iv.length
  return {
    startup: stamps[1] - stamps[0],
    frames: n,
    wall: stamps[n + 1] - stamps[0],
    mean: n ? sum / n : 0,
    p95: n ? sorted[Math.min(n - 1, Math.floor(n * 0.95))] : 0,
    max: n ? sorted[n - 1] : 0,
    long: long
  }
}

function line(labels, nominal, s) {
  return "PB-FT anim=" + labels.join("+") + " startup=" + s.startup
    + " frames=" + s.frames + " nominal=" + Math.round(nominal) + " wall=" + s.wall
    + " mean=" + s.mean.toFixed(1) + " p95=" + s.p95 + " max=" + s.max + " long=" + s.long
}
