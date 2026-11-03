import QtQuick
import QtTest
import "../../"

TestCase {
  name: "FrameLog"
  when: windowShown
  FrameLog { id: frameLog; enabled: true }

  // INTEG-146: a motion arms a run that counts its frames and ends on its own.
  function test_runEndsAfterItsFrames() {
    frameLog.motion("probe", 60)
    verify(frameLog.frames.running)
    tryVerify(function() { return !frameLog.frames.running }, 2000, "the run ends past its nominal time")
    verify(frameLog.stamps.length > 2, "frames were stamped: " + frameLog.stamps.length)
  }

  function test_offMeasuresNothing() {
    frameLog.enabled = false
    frameLog.motion("probe", 60)
    verify(!frameLog.frames.running)
    frameLog.enabled = true
  }
}
