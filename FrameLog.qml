import QtQuick

// `powerbarFrameLog` (shell.json, no Preferences): the bar's event timeline
// and the frame timing of its motions in the shell log, for debugging live
// (docs/behavior/integration.md INTEG-146):
//   PB-EV t=<ms> <kind> <detail>
//   PB-FT anim=<labels> frames=N nominal=MS wall=MS mean=MS p95=MS max=MS long=N
// A motion arms a run for its nominal time; motions starting while one runs
// join it (their labels joined with +), so a run is everything that moved
// together. `wall` counts from the first motion to the run's last frame,
// 100 ms past the latest one's end. Long frames are intervals over 25 ms,
// each also logged on the timeline as it happens. Nothing runs while
// `enabled` is false.
QtObject {
  id: log
  property bool enabled: false

  property var stamps: []
  property var labels: []
  property real nominal: 0
  property real until: 0
  readonly property int tailMs: 100

  function ev(kind, detail, ms) {
    if (!enabled) return
    console.log("PB-EV t=" + Date.now() + " " + kind + (detail ? " " + detail : ""))
    if (ms > 0) motion(kind + (detail ? ":" + String(detail).split(" ")[0] : ""), ms)
  }
  function motion(label, ms) {
    if (!enabled) return
    var now = Date.now()
    if (!frames.running) {
      stamps = [now]
      labels = []
      nominal = 0
    }
    if (labels.indexOf(label) < 0) labels.push(label)
    nominal = Math.max(nominal, now - stamps[0] + ms)
    until = Math.max(until, now + ms + tailMs)
    frames.running = true
  }
  function finish() {
    frames.running = false
    var st = stamps, iv = []
    for (var i = 1; i < st.length; i++) iv.push(st[i] - st[i - 1])
    if (!iv.length) return
    var sorted = iv.slice().sort(function(a, b) { return a - b })
    var sum = 0, long = 0
    for (var j = 0; j < iv.length; j++) { sum += iv[j]; if (iv[j] > 25) long++ }
    console.log("PB-FT anim=" + labels.join("+")
      + " frames=" + iv.length + " nominal=" + Math.round(nominal) + " wall=" + (st[st.length - 1] - st[0])
      + " mean=" + (sum / iv.length).toFixed(1) + " p95=" + sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95))]
      + " max=" + sorted[sorted.length - 1] + " long=" + long)
  }
  onEnabledChanged: {
    if (enabled) ev("framelog", "on")
    else frames.running = false
  }
  Component.onCompleted: ev("framelog", "on")

  property FrameAnimation frames: FrameAnimation {
    running: false
    onTriggered: {
      var now = Date.now(), last = log.stamps[log.stamps.length - 1]
      log.stamps.push(now)
      if (now - last > 25) console.log("PB-EV t=" + now + " longframe dt=" + (now - last) + " in=" + log.labels.join("+"))
      if (now >= log.until) log.finish()
    }
  }
}
