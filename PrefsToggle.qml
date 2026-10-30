import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "MotionModel.js" as MotionModel

// A switch row in an inspector (docs/behavior/preferences.md PREFS-133): its
// label at the label size, regular, as every control's name is, and its
// switch at the right. A switch row tall (the switch and xs above and below);
// its surface reaches s past the column on each side so the label stays in
// line with the fields above and below it, and shows only while the pointer
// or focus is on it. Space, Enter or a click flips it.
BorderSurface {
  id: toggle
  property string label: ""
  property bool checked: false
  signal toggled(bool checked)
  readonly property var keyHints: [{ keys: "space", label: "Toggle" }]

  Layout.fillWidth: true
  Layout.leftMargin: -Gap.s
  Layout.rightMargin: -Gap.s
  implicitWidth: Style.space(240)
  implicitHeight: Gap.switchRow
  radius: Round.control
  activeFocusOnTab: true
  Accessible.role: Accessible.CheckBox
  Accessible.name: label
  Accessible.checked: checked
  Keys.onReturnPressed: toggled(!checked)
  Keys.onEnterPressed: toggled(!checked)
  Keys.onSpacePressed: toggled(!checked)

  readonly property bool resting: !activeFocus && !mouse.containsMouse
  color: resting ? "transparent" : Style.controlFill(activeFocus, mouse.containsMouse, Commons.Color.popups.text, Commons.Color.accent)
  borderSpec: resting ? Border.none() : Border.controlSpec(activeFocus ? "focus" : "hover-cursor", Commons.Color.popups.text, Commons.Color.accent)
  Behavior on color {
    ColorAnimation {
      duration: Style.duration(MotionModel.FILL_MS)
    }
  }

  InkText {
    x: Gap.s
    width: parent.width - 2 * Gap.s - track.width - Gap.m
    anchors.verticalCenter: parent.verticalCenter
    text: toggle.label
    elide: Text.ElideRight
  }
  // The row owns the click, so the switch only shows.
  ToggleSwitch {
    id: track
    x: parent.width - Gap.s - width
    anchors.verticalCenter: parent.verticalCenter
    checked: toggle.checked
    rounded: Style.cornerRadius > 0
    foreground: Commons.Color.popups.text
    accent: Commons.Color.accent
    interactive: false
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: toggle.toggled(!toggle.checked)
  }
}
