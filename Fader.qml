import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SliderModel.js" as SliderModel

// A slider stood up on end, for the strips of the Look page
// (docs/behavior/preferences.md PREFS-127): its value on top (with its unit
// or a word), a 2 px track 150 px tall whose fill rises from the bottom, a
// 16 x 8 knob, and its name under it. It works as Preferences sliders do
// (SliderDraft: steps, snapping, settling, the wheel, Backspace, Enter, Esc;
// PREFS-55 to PREFS-60), with j/k or Down/Up for the value.
//
// Pointer: press the track to jump there and keep dragging, press the knob to
// drag it from where it was grabbed. The wheel changes it only while it has
// focus.
Item {
  id: fader
  property string label: ""
  property string unit: "px"
  property real minimum: 0
  property real maximum: 100
  property real stepSize: 1
  property real value: 0
  // NaN when the setting has no default worth returning to.
  property real defaultValue: NaN
  // What Backspace returns to, for the legend.
  property string defaultLabel: "Back to the default"
  // Words for special values, such as the ends of the range.
  property var formatter: null
  property bool animate: true
  // The name may use the room a strip leaves around the fader.
  readonly property real labelWidth: parent && parent.room !== undefined ? width + parent.room : width
  signal edited(real value)
  signal drafted(real value)

  SliderDraft {
    id: core
    host: fader
    minimum: fader.minimum
    maximum: fader.maximum
    stepSize: fader.stepSize
    value: fader.value
    defaultValue: fader.defaultValue
    onEdited: function(v) { fader.edited(v) }
    onDrafted: function(v) { fader.drafted(v) }
  }
  property alias drafting: core.drafting
  property alias dragging: core.dragging
  property alias lastEdit: core.lastEdit
  property alias wheelRest: core.wheelRest
  readonly property alias shown: core.shown
  readonly property alias hasDefault: core.hasDefault
  function cancel() { return core.cancel() }
  function format(v) {
    var custom = typeof formatter === "function" ? formatter(v) : ""
    if (custom) return custom
    return (stepSize < 1 ? v.toFixed(1) : Math.round(v)) + (unit === "%" ? "%" : unit ? " " + unit : "")
  }

  // On a desk (DeskPage): one stop, with its own keys in the legend.
  readonly property int deskStops: 1
  readonly property int deskHome: 0
  function deskFocus(stop, reason) { forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason) }
  readonly property bool ownsFocusRing: true
  readonly property var keyHints: [{ keys: "backspace", label: fader.defaultLabel }]
    .concat(drafting ? [{ keys: "enter", label: "Apply now" }, { keys: "esc", label: "Drop the change" }] : [])

  readonly property real trackLength: Style.space(150)
  readonly property real knobWidth: Style.space(16)
  readonly property real knobHeight: Style.space(8)
  readonly property real progress: SliderModel.progress(shown, minimum, maximum)
  readonly property int ticks: SliderModel.tickCount(minimum, maximum, stepSize)
  function yFor(v) { return trackLength * (1 - SliderModel.progress(v, minimum, maximum)) }

  implicitWidth: Style.space(60)
  implicitHeight: column.implicitHeight
  opacity: enabled ? 1 : 0.45
  activeFocusOnTab: false
  Accessible.role: Accessible.Slider
  Accessible.name: label
  Accessible.description: format(shown)
  Keys.onPressed: function(event) { if (core.keyPressed(event, true)) event.accepted = true }

  Column {
    id: column
    width: parent.width
    spacing: Style.space(6)
    // An unapplied draft shows in the accent and turns back once the bar has it.
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: fader.format(fader.shown)
      textFormat: Text.PlainText
      color: fader.drafting ? Commons.Color.accent : Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: fader.drafting
    }
    Item {
      id: rail
      objectName: "faderTrack"
      width: parent.width
      // Room for half the knob past each end.
      height: fader.trackLength + fader.knobHeight
      readonly property real inset: fader.knobHeight / 2
      Rectangle {
        id: track
        x: (rail.width - width) / 2
        y: rail.inset
        width: Math.max(2, Style.space(2))
        height: fader.trackLength
        color: Qt.alpha(Commons.Color.popups.text, 0.18)
        antialiasing: true
      }
      Rectangle {
        x: track.x
        width: track.width
        y: rail.inset + fader.trackLength * (1 - fader.progress)
        height: fader.trackLength * fader.progress
        color: Commons.Color.popups.text
        antialiasing: true
        Behavior on y {
          enabled: !fader.dragging && fader.animate
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on height {
          enabled: !fader.dragging && fader.animate
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
      }
      // One tick per step when there are few enough to read (PREFS-60).
      Repeater {
        model: fader.ticks
        Rectangle {
          required property int index
          x: (rail.width - width) / 2
          y: rail.inset + fader.trackLength * index / (fader.ticks - 1) - height / 2
          width: Style.space(6)
          height: 1
          color: Qt.alpha(Commons.Color.popups.text, 0.3)
          Accessible.ignored: true
        }
      }
      // The default, as a faint mark across the track.
      Rectangle {
        visible: fader.hasDefault
        x: (rail.width - width) / 2
        y: rail.inset + fader.yFor(fader.defaultValue) - height / 2
        width: Style.space(12)
        height: 1
        color: Qt.alpha(Commons.Color.popups.text, 0.4)
        Accessible.ignored: true
      }
      // The focus ring: a gap in the page's colour, then the accent.
      Rectangle {
        visible: fader.activeFocus
        anchors.centerIn: knob
        width: knob.width + Style.space(8)
        height: knob.height + Style.space(8)
        radius: Style.space(5)
        color: "transparent"
        border.width: 1
        border.color: Commons.Color.accent
        antialiasing: true
      }
      Rectangle {
        id: knob
        x: (rail.width - width) / 2
        y: rail.inset + fader.trackLength * (1 - fader.progress) - height / 2
        width: fader.knobWidth
        height: fader.knobHeight
        radius: Style.space(2)
        color: Commons.Color.popups.text
        antialiasing: true
        scale: fader.dragging ? 1.15 : pointer.containsMouse ? 1.1 : 1
        Behavior on y {
          enabled: !fader.dragging && fader.animate
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
          enabled: fader.animate
          NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
        }
      }
      MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: fader.enabled
        enabled: fader.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        // The value under a point along the rail, the grab kept.
        function valueAt(y) {
          return SliderModel.fromPosition(fader.trackLength - (y - core.grabOffset - rail.inset), fader.trackLength,
            fader.minimum, fader.maximum, fader.stepSize)
        }
        onPressed: function(mouse) {
          fader.forceActiveFocus(Qt.MouseFocusReason)
          var centre = knob.y + knob.height / 2
          // On the knob, keep the grab point; on the track, jump there.
          core.grabOffset = Math.abs(mouse.y - centre) <= knob.height / 2 + Style.space(3) ? mouse.y - centre : 0
          core.startDrag(valueAt(mouse.y))
        }
        onPositionChanged: function(mouse) { if (fader.dragging) core.setDraft(valueAt(mouse.y)) }
        onReleased: core.endDrag()
        onCanceled: core.endDrag()
        onWheel: function(wheel) {
          wheel.accepted = core.wheel(wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x)
        }
      }
    }
    Text {
      x: (parent.width - width) / 2
      width: fader.labelWidth
      horizontalAlignment: Text.AlignHCenter
      text: fader.label
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }
  }
}
