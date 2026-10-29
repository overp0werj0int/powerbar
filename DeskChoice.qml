import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A row of chips on a desk strip (docs/behavior/preferences.md PREFS-128):
// the chips share the strip by their labels, the chosen one in the selected
// look, the cursor's chip with the focus fill and ring (the Layout chip's). Every chip is a stop of its
// own: the desk's h/l walk them and go on past the row's ends to the same
// row of the next strip, Space or Enter chooses, a click chooses.
RowLayout {
  id: choice
  // [{ value, label }]
  property var options: []
  property string value: ""
  signal chosen(string value)

  readonly property int chosenIndex: options.findIndex(function (o) {
    return o.value === value;
  })
  // The chip the cursor is on, -1 while it is elsewhere.
  property int cursor: -1
  readonly property int deskStops: Math.max(1, options.length)
  readonly property int deskHome: Math.max(0, chosenIndex)
  readonly property int deskStop: Math.max(0, cursor)
  function deskFocus(stop, reason) {
    cursor = stop;
    forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
  }
  readonly property var keyHints: [
    {
      keys: "h l",
      label: "Chip to chip, then the next strip"
    },
    {
      keys: "space",
      label: "Choose it"
    }
  ]
  onActiveFocusChanged: if (!activeFocus)
    cursor = -1
  else if (cursor < 0)
    cursor = Math.max(0, chosenIndex)

  spacing: Style.space(2)
  Layout.fillWidth: true
  opacity: enabled ? 1 : 0.45
  activeFocusOnTab: false
  Accessible.role: Accessible.RadioButton

  function choose(i) {
    if (i >= 0 && i < options.length)
      chosen(options[i].value);
  }
  Keys.onPressed: function (event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      return;
    if (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
      return;
    choose(cursor);
    event.accepted = true;
  }

  Repeater {
    model: choice.options
    Button {
      id: chip
      required property var modelData
      required property int index
      readonly property bool cursorHere: choice.activeFocus && index === choice.cursor
      Layout.fillWidth: true
      // The chips share the strip by their labels, so "Everywhere" fits.
      Layout.preferredWidth: implicitWidth
      text: modelData.label
      selected: index === choice.chosenIndex
      bordered: true
      foreground: Commons.Color.popups.text
      background: "transparent"
      fontSize: Style.font.caption
      verticalPadding: Style.space(4)
      horizontalPadding: Style.space(3)
      onClicked: {
        choice.cursor = index;
        choice.forceActiveFocus(Qt.MouseFocusReason);
        choice.chosen(modelData.value);
      }
      // The cursor's focus fill and ring.
      Rectangle {
        anchors.fill: parent
        visible: chip.cursorHere
        color: Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)
        radius: chip.radius
        border.width: 1
        border.color: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent).color
        antialiasing: true
      }
    }
  }
}
