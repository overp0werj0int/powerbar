import QtQuick
import QtTest
import "../../"

// The Look page's fader: drafts stay in the window while it is worked and
// reach the config (edited) once, after the gesture settles; h/l and the
// pointer run along its width, j/k are left to the desk.
// Needs Omarchy's kit: -import <dir> where <dir>/qs/{Commons,Ui} link to the
// shell's Commons and Ui folders.
// The window's root is a plain Item: a TestCase root receives no mouse events.
Item {
  id: testCase
  width: 600; height: 300
  property var edits: []
  property var drafts: []
  property bool escapeReachedPage: false

  Item {
    id: page
    anchors.fill: parent
    Keys.onEscapePressed: testCase.escapeReachedPage = true
    Fader {
      id: slider
      x: 40; y: 20
      width: 240
      label: "Space between widgets"
      minimum: 0; maximum: 16; stepSize: 1
      defaultValue: 0
      value: 4
      animate: false
      onEdited: function(v) { testCase.edits.push(v); value = v }
      onDrafted: function(v) { testCase.drafts.push(v) }
    }
    Rectangle { id: elsewhere; x: 300; y: 200; width: 50; height: 50; activeFocusOnTab: true }
  }

  TestCase {
  name: "Fader"
  when: windowShown

  function init() {
    slider.cancel()
    slider.value = 4
    slider.enabled = true
    slider.lastEdit = -Infinity
    slider.wheelRest = 0
    testCase.edits = []; testCase.drafts = []
    testCase.escapeReachedPage = false
    slider.forceActiveFocus()
  }
  // Where the knob's centre sits for value v, in the slider's coordinates.
  function knobPoint(v) {
    var rail = findChild(slider, "faderTrack")
    verify(rail)
    return rail.mapToItem(slider, rail.inset + slider.xFor(v), rail.height / 2)
  }

  function test_keysDraftThenApplyOnce() {
    keyClick(Qt.Key_L); keyClick(Qt.Key_L); keyClick(Qt.Key_L)
    compare(slider.shown, 7)
    compare(slider.drafting, true)
    compare(testCase.edits.length, 0, "nothing reaches the bar while keys are moving")
    wait(250)
    compare(testCase.edits.length, 0)
    tryCompare(slider, "drafting", false, 1200)
    compare(testCase.edits, [7])
    compare(testCase.drafts[testCase.drafts.length - 1], NaN)
  }
  function test_shiftStepsFiveAndClamps() {
    keyClick(Qt.Key_L, Qt.ShiftModifier)
    compare(slider.shown, 9)
    keyClick(Qt.Key_L, Qt.ShiftModifier); keyClick(Qt.Key_L, Qt.ShiftModifier)
    compare(slider.shown, 16)
    keyClick(Qt.Key_Home)
    compare(slider.shown, 0)
  }
  function test_enterAppliesAtOnce() {
    keyClick(Qt.Key_Right)
    keyClick(Qt.Key_Return)
    compare(testCase.edits, [5])
    compare(slider.drafting, false)
  }
  function test_escapeUndoesDraftThenReachesPage() {
    keyClick(Qt.Key_L)
    keyClick(Qt.Key_Escape)
    compare(slider.drafting, false)
    compare(slider.shown, 4)
    compare(testCase.escapeReachedPage, false, "first Esc only drops the draft")
    wait(600)
    compare(testCase.edits.length, 0)
    keyClick(Qt.Key_Escape)
    compare(testCase.escapeReachedPage, true, "with nothing pending, Esc closes as usual")
  }
  function test_backspaceReturnsToDefault() {
    keyClick(Qt.Key_Backspace)
    compare(slider.shown, 0)
    keyClick(Qt.Key_Return)
    compare(testCase.edits, [0])
  }
  function test_leavingAppliesImmediately() {
    keyClick(Qt.Key_L)
    elsewhere.forceActiveFocus()
    compare(testCase.edits, [5])
  }
  function test_hidingAppliesImmediately() {
    keyClick(Qt.Key_L)
    slider.visible = false
    compare(testCase.edits, [5])
    slider.visible = true
  }
  function test_disablingDropsTheDraft() {
    keyClick(Qt.Key_L)
    slider.enabled = false
    wait(600)
    compare(testCase.edits.length, 0)
    compare(slider.shown, 4)
  }
  function test_noEditWhenTheDraftReturnsHome() {
    keyClick(Qt.Key_L); keyClick(Qt.Key_H)
    tryCompare(slider, "drafting", false, 1200)
    compare(testCase.edits.length, 0)
  }
  function test_dragAppliesOnlyAfterRelease() {
    var from = knobPoint(4), to = knobPoint(12)
    mousePress(slider, from.x, from.y)
    for (var i = 1; i <= 8; i++) mouseMove(slider, from.x + (to.x - from.x) * i / 8, from.y)
    compare(slider.shown, 12)
    wait(600)
    compare(testCase.edits.length, 0, "a held knob never applies")
    mouseRelease(slider, to.x, to.y)
    compare(testCase.edits.length, 0)
    tryCompare(slider, "drafting", false, 400)
    compare(testCase.edits, [12])
  }
  function test_grabbingTheKnobOffCentreDoesNotJump() {
    var p = knobPoint(4)
    mousePress(slider, p.x + 2, p.y)
    compare(slider.shown, 4)
    mouseRelease(slider, p.x + 2, p.y)
    wait(300)
    compare(testCase.edits.length, 0)
  }
  function test_pressingTheTrackJumpsThere() {
    var p = knobPoint(14)
    mouseClick(slider, p.x, p.y)
    compare(slider.shown, 14)
    tryCompare(slider, "drafting", false, 400)
    compare(testCase.edits, [14])
  }
  function test_regrabbingBeforeTheReleaseSettleKeepsOneEdit() {
    var a = knobPoint(4), b = knobPoint(8), c = knobPoint(10)
    mousePress(slider, a.x, a.y); mouseMove(slider, b.x, b.y); mouseRelease(slider, b.x, b.y)
    mousePress(slider, b.x, b.y); mouseMove(slider, c.x, c.y); mouseRelease(slider, c.x, c.y)
    tryCompare(slider, "drafting", false, 400)
    compare(testCase.edits, [10])
  }
  function test_wheelScrollsPastAnUnfocusedSlider() {
    elsewhere.forceActiveFocus()
    var p = knobPoint(4)
    mouseWheel(slider, p.x, p.y, 0, 120)
    compare(slider.shown, 4)
    compare(slider.drafting, false)
  }
  function test_wheelStepsAFocusedSliderByNotches() {
    var p = knobPoint(4)
    mouseWheel(slider, p.x, p.y, 0, 40)
    mouseWheel(slider, p.x, p.y, 0, 40)
    compare(slider.shown, 4, "touchpad fractions wait for a whole notch")
    mouseWheel(slider, p.x, p.y, 0, 40)
    compare(slider.shown, 5)
    mouseWheel(slider, p.x, p.y, 0, -240)
    compare(slider.shown, 3)
    compare(testCase.edits.length, 0)
    tryCompare(slider, "drafting", false, 1200)
    compare(testCase.edits, [3])
  }
  function test_verticalKeysAreLeftToThePage() {
    keyClick(Qt.Key_J)
    keyClick(Qt.Key_K)
    keyClick(Qt.Key_Down)
    keyClick(Qt.Key_Up)
    compare(slider.shown, 4, "j and k walk the desk, not the value")
    compare(slider.drafting, false)
  }
  function test_leftAndRightStep() {
    keyClick(Qt.Key_Left)
    compare(slider.shown, 3)
    keyClick(Qt.Key_H, Qt.ShiftModifier)
    compare(slider.shown, 0)
    keyClick(Qt.Key_End)
    compare(slider.shown, 16)
  }
  function test_pressingTheNameLineOnlyFocuses() {
    elsewhere.forceActiveFocus()
    mouseClick(slider, slider.width - 4, 4)
    verify(slider.activeFocus)
    compare(slider.drafting, false)
  }
  function test_valueOutsideRangeShowsClamped() {
    slider.value = 28
    compare(slider.shown, 16)
    keyClick(Qt.Key_L)
    compare(slider.drafting, false, "already at the top: nothing to apply")
  }
  function test_halfSteps() {
    slider.minimum = 0.5; slider.maximum = 3; slider.stepSize = 0.5; slider.value = 1
    keyClick(Qt.Key_L)
    compare(slider.shown, 1.5)
    compare(slider.format(slider.shown), "1.5 px")
    keyClick(Qt.Key_Return)
    compare(testCase.edits, [1.5])
    slider.minimum = 0; slider.maximum = 16; slider.stepSize = 1
  }
}
}
