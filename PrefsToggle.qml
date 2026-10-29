import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A switch row in an inspector (docs/behavior/preferences.md PREFS-133): its
// label at the label size, regular, as every control's name is, and its
// switch at the right. A switch row tall (the switch and xs above and below);
// its surface reaches s past the column on each side so the label stays in
// line with the fields above and below it, and shows only while the pointer
// or focus is on it. Space, Enter or a click flips it.
BorderSurface {
  id: toggle
  // Kept for its callers: every inspector row is compact.
  property bool compact: true
  property string label: ""
  property bool checked: false
  property bool hasCursor: false
  property color foreground: Commons.Color.popups.text
  property color accent: Commons.Color.accent
  signal toggled(bool checked)
  signal clicked()
  onClicked: toggled(!checked)

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
  Keys.onReturnPressed: clicked()
  Keys.onEnterPressed: clicked()
  Keys.onSpacePressed: clicked()

  readonly property bool _hot: hasCursor || mouse.containsMouse
  readonly property bool resting: !activeFocus && !_hot
  color: resting ? "transparent" : Style.controlFill(activeFocus, _hot, foreground, accent)
  borderSpec: resting ? Border.none() : Border.controlSpec(activeFocus ? "focus" : "hover-cursor", foreground, accent)
  Behavior on color {
    ColorAnimation {
      duration: Style.duration(100)
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
    foreground: toggle.foreground
    accent: toggle.accent
    interactive: false
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: toggle.clicked()
  }
}
