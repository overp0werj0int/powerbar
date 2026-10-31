import QtQuick
import QtTest
import "../../"

// A drag's release waits one turn of the event loop; the window losing the
// pointer in that turn makes it a release outside (DRAG-77). Bar.qml calls
// pointerLeft when the hover on its window's content ends; offscreen tests
// get no hover, so it is called here as that leave would.
TestCase {
  id: test
  name: "DragRelease"

  property var outcomes: []
  property int afters: 0

  DragRelease {
    id: gate
    onLanded: function(point, slot) { test.outcomes.push("landed " + slot + " " + point.x + "," + point.y) }
    onLeft: function(point, slot) { test.outcomes.push("left " + slot) }
  }

  function after() { afters++ }
  function init() { outcomes = []; afters = 0 }

  function test_releaseOnTheBarLandsOnTheNextTurn() {
    gate.release({ x: 40, y: 10 }, "weather", after)
    compare(outcomes, [], "nothing decided inside the release itself")
    tryCompare(test, "afters", 1)
    compare(outcomes, ["landed weather 40,10"])
  }

  function test_pointerLostInTheSameTurnIsAReleaseOutside() {
    gate.release({ x: 40, y: 10 }, "weather", after)
    gate.pointerLeft()
    compare(outcomes, ["left weather"], "the leave after the release cancels the drop")
    wait(20)
    compare(outcomes, ["left weather"], "the release does not land afterwards")
    compare(afters, 1, "the caller's own clean-up runs once")
  }

  function test_aLeaveWithNoReleaseWaitingDoesNothing() {
    gate.pointerLeft()
    wait(20)
    compare(outcomes, [])
    compare(gate.pending, null)
  }

  function test_aLeaveAfterTheReleaseLandedChangesNothing() {
    gate.release({ x: 40, y: 10 }, "weather", after)
    tryCompare(test, "afters", 1)
    gate.pointerLeft()
    compare(outcomes, ["landed weather 40,10"])
  }

  function test_aSecondReleaseLandsTheFirstAtOnce() {
    gate.release({ x: 40, y: 10 }, "weather", after)
    gate.release({ x: 90, y: 10 }, "audio", after)
    compare(outcomes, ["landed weather 40,10"])
    gate.pointerLeft()
    compare(outcomes, ["landed weather 40,10", "left audio"])
    compare(afters, 2)
  }
}
