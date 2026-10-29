import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SliderModel.js" as SliderModel

// A slider laid flat along a strip of the Look page
// (docs/behavior/preferences.md PREFS-127): its name at the left and its
// value at the right (with its unit or a word) on one line, under it a 2 px
// track as wide as the strip whose fill grows from the left, and an 8 x 16
// knob. It works as Preferences sliders do (SliderDraft: steps, snapping,
// settling, the wheel, Backspace, Enter, Esc; PREFS-55 to PREFS-60), with
// h/l or Left/Right for the value; j/k are the desk's, which walks on.
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
  readonly property var keyHints: [{ keys: "h l", label: "Less, more (shift: five steps)" }, { keys: "backspace", label: fader.defaultLabel }]
    .concat(drafting ? [{ keys: "enter", label: "Apply now" }, { keys: "esc", label: "Drop the change" }] : [])

  readonly property real knobWidth: Style.space(8)
  readonly property real knobHeight: Style.space(16)
  // The knob's centre travels between half a knob in from each end.
  readonly property real trackLength: Math.max(1, width - knobWidth)
  readonly property real progress: SliderModel.progress(shown, minimum, maximum)
  readonly property int ticks: SliderModel.tickCount(minimum, maximum, stepSize)
  function xFor(v) { return trackLength * SliderModel.progress(v, minimum, maximum) }

  // With the cursor it lifts as a desk row does (PREFS-104, PREFS-129), on a
  // plate of the strip's colour reaching into the strip's padding; the
  // knob's ring stays its mark.
  readonly property Item strip: {
    for (var p = parent; p; p = p.parent)
      if (p.isDeskStrip)
        return p
    return null
  }
  CursorLift {
    id: lift
    up: fader.activeFocus
    animate: fader.animate
    lightTheme: fader.strip ? fader.strip.lightTheme : false
    radius: Math.max(0, Math.min(Style.space(5), Style.cornerRadius - Style.space(3)))
    plate: fader.strip ? fader.strip.surfaceColor : "transparent"
    padX: Style.space(8)
    padY: Style.space(4)
  }
  transform: Translate { y: -lift.raise }
  scale: lift.grown
  z: lift.raised ? 1 : 0
  Layout.fillWidth: true
  implicitWidth: Style.space(120)
  implicitHeight: column.implicitHeight
  opacity: enabled ? 1 : 0.45
  activeFocusOnTab: false
  Accessible.role: Accessible.Slider
  Accessible.name: label
  Accessible.description: format(shown)
  Keys.onPressed: function(event) { if (core.keyPressed(event)) event.accepted = true }

  Column {
    id: column
    width: parent.width
    spacing: Style.space(4)
    // The name, and the value at the right: an unapplied draft shows in the
    // accent and turns back once the bar has it.
    Item {
      width: parent.width
      implicitHeight: Math.max(name.implicitHeight, valueText.implicitHeight)
      height: implicitHeight
      GrayText {
        id: name
        anchors.left: parent.left
        anchors.right: valueText.left
        anchors.rightMargin: Style.space(8)
        anchors.baseline: valueText.baseline
        text: fader.label
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
      GrayText {
        id: valueText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: fader.format(fader.shown)
        textFormat: Text.PlainText
        color: fader.drafting ? Commons.Color.accent : Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: fader.drafting
      }
    }
    Item {
      id: rail
      objectName: "faderTrack"
      width: parent.width
      height: fader.knobHeight
      // Half the knob in from each end.
      readonly property real inset: fader.knobWidth / 2
      Rectangle {
        id: track
        x: 0
        y: (rail.height - height) / 2
        width: rail.width
        height: Math.max(2, Style.space(2))
        color: Qt.alpha(Commons.Color.popups.text, 0.18)
        antialiasing: true
      }
      Rectangle {
        y: track.y
        height: track.height
        x: 0
        width: rail.inset + fader.trackLength * fader.progress
        color: Commons.Color.popups.text
        antialiasing: true
        Behavior on width {
          enabled: !fader.dragging && fader.animate
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
      }
      // One tick per step when there are few enough to read (PREFS-60).
      Repeater {
        model: fader.ticks
        Rectangle {
          required property int index
          x: rail.inset + fader.trackLength * index / (fader.ticks - 1) - width / 2
          y: (rail.height - height) / 2
          width: 1
          height: Style.space(6)
          color: Qt.alpha(Commons.Color.popups.text, 0.3)
          Accessible.ignored: true
        }
      }
      // The default, as a faint mark across the track.
      Rectangle {
        visible: fader.hasDefault
        x: rail.inset + fader.xFor(fader.defaultValue) - width / 2
        y: (rail.height - height) / 2
        width: 1
        height: Style.space(12)
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
        border.color: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent).color
        antialiasing: true
      }
      Rectangle {
        id: knob
        x: rail.inset + fader.trackLength * fader.progress - width / 2
        y: 0
        width: fader.knobWidth
        height: fader.knobHeight
        radius: Style.space(2)
        color: Commons.Color.popups.text
        antialiasing: true
        scale: fader.dragging ? 1.15 : pointer.containsMouse ? 1.1 : 1
        Behavior on x {
          enabled: !fader.dragging && fader.animate
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
          enabled: fader.animate
          NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
        }
      }
    }
  }
  // Over the whole fader, so the name line takes the cursor too; only a
  // press on the track's line moves the value.
  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: fader.enabled
    enabled: fader.enabled
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    // The value under a point along the rail, the grab kept.
    function valueAt(x) {
      return SliderModel.fromPosition(x - core.grabOffset - rail.inset, fader.trackLength,
        fader.minimum, fader.maximum, fader.stepSize)
    }
    onPressed: function(mouse) {
      fader.forceActiveFocus(Qt.MouseFocusReason)
      if (mouse.y < rail.y - Style.space(2)) return
      var centre = knob.x + knob.width / 2
      // On the knob, keep the grab point; on the track, jump there.
      core.grabOffset = Math.abs(mouse.x - centre) <= knob.width / 2 + Style.space(3) ? mouse.x - centre : 0
      core.startDrag(valueAt(mouse.x))
    }
    onPositionChanged: function(mouse) { if (fader.dragging) core.setDraft(valueAt(mouse.x)) }
    onReleased: core.endDrag()
    onCanceled: core.endDrag()
    onWheel: function(wheel) {
      wheel.accepted = core.wheel(wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x)
    }
  }
}
