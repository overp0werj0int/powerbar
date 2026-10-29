import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A row on a desk strip (docs/behavior/preferences.md PREFS-129): its label
// with an optional one-line caption under it (without one the row is its
// label's line), and a switch at its right, or, for a pick-one row (`pick`),
// a 14 px ring before the label, filled in the accent when chosen, a 6 px dot
// in it (the same parity, so it sits on the ring's centre pixel); an action
// row (`action`) has neither, its label in the accent, like a link. Space,
// Enter or a click toggles the switch, chooses the row or does the action.
// With the cursor it looks and lifts as the Layout page's chip does
// (PREFS-104): the focus fill over the strip's own colour, the focus ring,
// risen 8 px with its shadow band.
BorderSurface {
  id: row
  property string label: ""
  property string caption: ""
  property bool checked: false
  property bool pick: false
  property bool action: false
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
  // The strip it is on, for its colour and theme.
  readonly property Item strip: {
    for (var p = parent; p; p = p.parent)
      if (p.isDeskStrip)
        return p
    return null
  }
  readonly property color base: strip ? strip.surfaceColor : "transparent"
  CursorLift {
    id: lift
    up: row.activeFocus
    animate: row.strip && row.strip.desk ? row.strip.desk.animate : true
    lightTheme: row.strip ? row.strip.lightTheme : false
    radius: row.radius
  }
  transform: Translate { y: -lift.raise }
  scale: lift.grown
  z: lift.raised ? 1 : 0
  Layout.fillWidth: true
  // The surface reaches into the strip's padding; the text stays in line.
  Layout.leftMargin: -Style.space(8)
  Layout.rightMargin: -Style.space(8)
  implicitHeight: content.implicitHeight + 2 * Style.space(6)
  radius: Math.max(0, Math.min(Style.space(5), Style.cornerRadius - Style.space(3)))
  activeFocusOnTab: false
  opacity: enabled ? 1 : 0.45
  // Risen, the strip's own colour under the fill, so the row it rises over
  // does not show through.
  color: activeFocus ? Qt.tint(base, Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent))
    : hot ? Qt.alpha(Commons.Color.popups.text, 0.14) : "transparent"
  borderSpec: activeFocus ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
  Accessible.role: action ? Accessible.Button : pick ? Accessible.RadioButton : Accessible.CheckBox
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
      GrayText {
        id: labelText
        Layout.fillWidth: true
        text: row.label
        textFormat: Text.PlainText
        color: row.action ? Commons.Color.accent : Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      GrayText {
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
      visible: !row.pick && !row.action
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
