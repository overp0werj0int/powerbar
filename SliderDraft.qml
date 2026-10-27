import QtQuick
import "SliderModel.js" as SliderModel

// What a Preferences slider does with its value, apart from how it is drawn
// (docs/behavior/preferences.md PREFS-55 to PREFS-60): the draft it keeps
// while it is worked, applied to the bar only once it settles (SliderModel),
// and its keys. A slider or fader puts one inside itself as `host` and draws
// `shown`; leaving the host, hiding it or its window applies what is
// pending, disabling it drops it.
//
// `drafted` reports the draft as it moves (NaN once it is applied or
// dropped), so a preview can follow it at no cost to the bar.
Item {
  id: core
  required property Item host
  property real minimum: 0
  property real maximum: 100
  property real stepSize: 1
  property real value: 0
  // NaN when the setting has no default worth returning to.
  property real defaultValue: NaN
  signal edited(real value)
  signal drafted(real value)

  property bool drafting: false
  property real draft: 0
  property bool dragging: false
  property real lastEdit: -Infinity
  property real wheelRest: 0
  // Where the knob was grabbed, from its centre along the track.
  property real grabOffset: 0

  readonly property real committed: SliderModel.snap(value, minimum, maximum, stepSize)
  readonly property real shown: drafting ? draft : committed
  readonly property bool hasDefault: isFinite(defaultValue) && defaultValue >= minimum && defaultValue <= maximum

  // Moves the draft and, unless the pointer still holds the knob, schedules
  // it to apply once the user goes quiet.
  function setDraft(v) {
    var next = SliderModel.snap(v, minimum, maximum, stepSize)
    var now = Date.now()
    var gap = now - lastEdit
    lastEdit = now
    if (!drafting && next === committed) return
    draft = next
    drafting = true
    drafted(next)
    settle.interval = SliderModel.settleDelay(gap)
    if (!dragging) settle.restart()
  }
  function step(count) { setDraft(shown + count * stepSize) }
  function flush() {
    settle.stop()
    if (!drafting) return
    var v = draft
    drafting = false
    if (v !== committed) edited(v)
    drafted(NaN)
  }
  function cancel() {
    settle.stop()
    dragging = false
    if (!drafting) return false
    drafting = false
    drafted(NaN)
    return true
  }
  // A press on the track or the knob: the draft follows the pointer and
  // waits for the release.
  function startDrag(v) {
    settle.stop()
    dragging = true
    setDraft(v)
  }
  function endDrag() {
    if (!dragging) return
    dragging = false
    if (!drafting) return
    settle.interval = SliderModel.RELEASE
    settle.restart()
  }
  // A wheel event over the focused host; false when it is not the host's
  // (unfocused, or held by the pointer) so the page scrolls.
  function wheel(delta) {
    if (!host.activeFocus || dragging) return false
    var notches = SliderModel.wheelSteps(wheelRest, delta)
    wheelRest = notches.rest
    if (notches.steps !== 0) step(notches.steps)
    return true
  }
  // The keys (PREFS-57). A slider takes h/l or Left/Right, a fader j/k or
  // Down/Up (`vertical`), less first; returns whether the key was used.
  function keyPressed(event, vertical) {
    var big = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
    var t = event.text.toLowerCase()
    var less = vertical ? event.key === Qt.Key_Down || t === "j" : event.key === Qt.Key_Left || t === "h"
    var more = vertical ? event.key === Qt.Key_Up || t === "k" : event.key === Qt.Key_Right || t === "l"
    if (less) step(-big)
    else if (more) step(big)
    else if (event.key === Qt.Key_PageDown) step(-5)
    else if (event.key === Qt.Key_PageUp) step(5)
    else if (event.key === Qt.Key_Home) setDraft(minimum)
    else if (event.key === Qt.Key_End) setDraft(maximum)
    else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && hasDefault) setDraft(defaultValue)
    else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && drafting) flush()
    else if (event.key === Qt.Key_Escape && cancel()) {}
    else return false
    return true
  }

  // Leaving the host, its page or the window applies what is pending.
  Connections {
    target: core.host
    function onActiveFocusChanged() { if (!core.host.activeFocus && core.host.enabled) { core.endDrag(); core.flush() } }
    function onVisibleChanged() { if (!core.host.visible) { core.endDrag(); core.flush() } }
    function onEnabledChanged() { if (!core.host.enabled) core.cancel() }
  }
  Connections {
    target: core.Window.window
    ignoreUnknownSignals: true
    function onVisibleChanged() { if (core.Window.window && !core.Window.window.visible) { core.endDrag(); core.flush() } }
  }
  Component.onDestruction: flush()
  Timer { id: settle; onTriggered: core.flush() }
}
