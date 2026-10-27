import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A row on a desk strip (docs/behavior/preferences.md PREFS-129): its label
// with an optional one-line caption under it (without one the row is its
// label's line), and a switch at its right, or, for a pick-one row (`pick`),
// a 14 px ring before the label, filled in the accent when chosen, a 6 px dot
// in it (the same parity, so it sits on the ring's centre pixel). Space,
// Enter or a click toggles the switch or chooses the row. With the cursor it
// takes the chosen fill and the accent ring.
BorderSurface {
  id: row
  property string label: ""
  property string caption: ""
  property bool checked: false
  property bool pick: false
  // The legend's line for Space while the cursor is here, if the page's
  // does not say it (a Look pick row's "Choose it").
  property string spaceHint: ""
  signal activated()

  // On a desk (DeskPage): one stop that draws its own cursor.
  readonly property int deskStops: 1
  readonly property int deskHome: 0
  function deskFocus(stop, reason) { forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason) }
  readonly property bool ownsFocusRing: true
  readonly property var keyHints: [{ keys: "h l", label: "Same row, next strip" }]
    .concat(spaceHint ? [{ keys: "space", label: spaceHint }] : [])

  readonly property bool hot: mouse.containsMouse && enabled
  Layout.fillWidth: true
  // The surface reaches into the strip's padding; the text stays in line.
  Layout.leftMargin: -Style.space(8)
  Layout.rightMargin: -Style.space(8)
  implicitHeight: content.implicitHeight + 2 * Style.space(6)
  radius: Math.max(0, Math.min(Style.space(8), Style.cornerRadius))
  activeFocusOnTab: false
  opacity: enabled ? 1 : 0.45
  color: activeFocus ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent)
    : hot ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
  borderSpec: activeFocus ? Border.flat(Commons.Color.accent, 1) : Border.none()
  Accessible.role: pick ? Accessible.RadioButton : Accessible.CheckBox
  Accessible.name: label
  Accessible.description: caption
  Accessible.checked: checked

  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      row.activated()
      event.accepted = true
    }
  }

  RowLayout {
    id: content
    x: Style.space(8)
    y: Style.space(6)
    width: row.width - 2 * Style.space(8)
    spacing: Style.space(10)
    // The pick mark.
    Rectangle {
      visible: row.pick
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: Math.max(0, (labelText.implicitHeight - height) / 2)
      implicitWidth: Style.space(14)
      implicitHeight: Style.space(14)
      radius: width / 2
      color: row.checked ? Commons.Color.accent : "transparent"
      border.width: row.checked ? 0 : 1
      border.color: Qt.alpha(Commons.Color.popups.text, 0.45)
      antialiasing: true
      Rectangle {
        visible: row.checked
        anchors.centerIn: parent
        width: Style.space(6)
        height: width
        radius: width / 2
        color: Commons.Color.popups.background
        antialiasing: true
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(2)
      Text {
        id: labelText
        Layout.fillWidth: true
        text: row.label
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        visible: row.caption !== ""
        Layout.fillWidth: true
        text: row.caption
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
    ToggleSwitch {
      visible: !row.pick
      Layout.alignment: Qt.AlignTop
      checked: row.checked
      interactive: false
      foreground: Commons.Color.popups.text
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: row.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      row.forceActiveFocus(Qt.MouseFocusReason)
      row.activated()
    }
  }
}
