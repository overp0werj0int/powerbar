import QtQuick

// Starts a motion on the second frame after begin(): the frame that first
// shows a change (a window mapped, a page built) can take a few frames' time,
// and a motion started before it is mostly done when it is first seen
// (on-demand-drawers.md DEMAND-91). The caller holds the motion's start
// until ready(); cancel() drops a wait that no longer applies.
FrameAnimation {
  id: wait
  property int ticks: 0
  signal ready()
  function begin() { ticks = 0; restart() }
  function cancel() { stop() }
  onTriggered: {
    if (++ticks < 2) return
    stop()
    wait.ready()
  }
}
