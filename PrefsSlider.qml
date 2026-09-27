import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A labelled slider row. Focus it with Tab or j/k, then h/l or Left/Right
// step the value (Shift for bigger steps). Keyboard edits settle briefly
// before they are saved so holding a key does not rewrite the config per tick.
BorderSurface {
  id: row
  property string label: ""
  property string unit: "px"
  property real minimum: 0
  property real maximum: 100
  property real stepSize: 1
  property real value: 0
  property real pending: value
  property bool keyboardEditing: false
  signal edited(real value)

  readonly property real shown: keyboardEditing ? pending : slider.dragging ? slider.liveValue : value
  readonly property bool hot: hover.hovered
  function format(v) { return (stepSize < 1 ? v.toFixed(1) : Math.round(v)) + (unit ? " " + unit : "") }
  function nudge(steps) {
    var next = Math.max(minimum, Math.min(maximum, Math.round(((keyboardEditing ? pending : value) + steps * stepSize) / stepSize) * stepSize))
    pending = next
    keyboardEditing = true
    commit.restart()
  }

  Layout.fillWidth: true
  implicitHeight: content.implicitHeight + Style.space(20)
  radius: Style.cornerRadius
  activeFocusOnTab: enabled
  opacity: enabled ? 1 : 0.45
  color: Style.controlFill(activeFocus, hot, Color.popups.text, Color.accent)
  borderSpec: Border.controlSpec(activeFocus ? "focus" : hot ? "hover-cursor" : "normal", Color.popups.text, Color.accent)
  Accessible.role: Accessible.Slider
  Accessible.name: label
  Keys.onPressed: function(event) {
    var big = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
    if (event.key === Qt.Key_Left || event.text === "h" || event.text === "H") { nudge(-big); event.accepted = true }
    else if (event.key === Qt.Key_Right || event.text === "l" || event.text === "L") { nudge(big); event.accepted = true }
    else if (event.key === Qt.Key_Home) { pending = minimum; keyboardEditing = true; commit.restart(); event.accepted = true }
    else if (event.key === Qt.Key_End) { pending = maximum; keyboardEditing = true; commit.restart(); event.accepted = true }
  }
  onValueChanged: if (!keyboardEditing) pending = value

  Timer {
    id: commit
    interval: 260
    onTriggered: { row.edited(row.pending); row.keyboardEditing = false }
  }
  HoverHandler { id: hover }

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.spacing.rowPaddingX
    anchors.rightMargin: Style.spacing.rowPaddingX
    spacing: Style.space(6)
    RowLayout {
      Layout.fillWidth: true
      Text {
        text: row.label
        textFormat: Text.PlainText
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
      Text {
        text: row.format(row.shown)
        textFormat: Text.PlainText
        color: row.activeFocus ? Color.accent : Qt.alpha(Color.popups.text, 0.75)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }
    PanelSlider {
      id: slider
      Layout.fillWidth: true
      value: row.shown
      minimum: row.minimum
      maximum: row.maximum
      step: row.stepSize
      integer: row.stepSize >= 1
      trackColor: Qt.alpha(Color.popups.text, 0.14)
      fillColor: Color.accent
      knobColor: Color.popups.text
      tickColor: Color.popups.background
      onReleased: function(value) {
        var snapped = Math.round(value / row.stepSize) * row.stepSize
        row.forceActiveFocus()
        row.edited(snapped)
      }
    }
  }
}
