import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DeskModel.js" as DeskModel

// A pick-one control on a desk strip (docs/behavior/preferences.md
// PREFS-128): chips filling the strip (a row's by their labels), the chosen one in the
// selected look. As a row every chip is a stop of its own (h/l walk them,
// Space or Enter chooses); as a column it is one stop whose cursor j/k move
// (past its ends the step goes on to the control below or above); as the
// Screen edge grid (2 x 2, values top, bottom, left, right) h j k l choose
// Left, Bottom, Top, Right at once (the arrows walk on past it). A click
// chooses.
GridLayout {
  id: choice
  // [{ value, label }]
  property var options: []
  property string value: ""
  // "row", "column" or "grid".
  property string mode: "row"
  signal chosen(string value)

  readonly property int chosenIndex: options.findIndex(function (o) {
    return o.value === value;
  })
  // The chip the cursor is on, -1 while it is elsewhere.
  property int cursor: -1
  readonly property int deskStops: mode === "row" ? Math.max(1, options.length) : 1
  readonly property int deskHome: mode === "row" ? Math.max(0, chosenIndex) : 0
  readonly property int deskStop: mode === "row" ? Math.max(0, cursor) : 0
  function deskFocus(stop, reason) {
    cursor = mode === "row" ? stop : mode === "column" ? Math.max(0, chosenIndex) : -1;
    forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
  }
  readonly property var keyHints: mode === "grid" ? [
    {
      keys: "h j k l",
      label: "Left, bottom, top, right"
    }
  ] : mode === "column" ? [
    {
      keys: "j k",
      label: "Down, up the choices"
    },
    {
      keys: "space",
      label: "Choose it"
    }
  ] : [
    {
      keys: "space",
      label: "Choose it"
    }
  ]
  onActiveFocusChanged: if (!activeFocus)
    cursor = -1
  else if (cursor < 0 && mode !== "grid")
    cursor = Math.max(0, chosenIndex)

  columns: mode === "row" ? Math.max(1, options.length) : mode === "grid" ? 2 : 1
  columnSpacing: mode === "row" ? Style.space(2) : Style.space(3)
  rowSpacing: Style.space(3)
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
    var t = event.text.toLowerCase();
    var key = event.key === Qt.Key_Left ? "h" : event.key === Qt.Key_Down ? "j" : event.key === Qt.Key_Up ? "k" : event.key === Qt.Key_Right ? "l" : t;
    var activate = event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
    if (mode === "grid") {
      // The letters choose; the arrows still walk on, so the grid can be left.
      var edge = DeskModel.gridEdge(t);
      if (!edge)
        return;
      chosen(edge);
    } else if (activate)
      choose(cursor);
    else if (mode === "column" && (key === "j" || key === "k")) {
      var next = DeskModel.choiceStep(options.length, cursor, key === "j" ? 1 : -1);
      if (next < 0)
        return;
      cursor = next;
    } else
      return;
    event.accepted = true;
  }

  Repeater {
    model: choice.options
    Button {
      id: chip
      required property var modelData
      required property int index
      readonly property bool cursorHere: choice.activeFocus && (choice.mode === "grid" ? index === choice.chosenIndex : index === choice.cursor)
      Layout.fillWidth: true
      // A row's chips share the strip by their labels, so "Everywhere" fits.
      Layout.preferredWidth: choice.mode === "row" ? implicitWidth : 1
      text: modelData.label
      selected: index === choice.chosenIndex
      bordered: true
      foreground: Commons.Color.popups.text
      background: "transparent"
      fontSize: Style.font.caption
      verticalPadding: Style.space(4)
      horizontalPadding: choice.mode === "row" ? Style.space(3) : Style.space(4)
      onClicked: {
        choice.cursor = choice.mode === "grid" ? -1 : index;
        choice.forceActiveFocus(Qt.MouseFocusReason);
        choice.chosen(modelData.value);
      }
      // The cursor's accent ring.
      Rectangle {
        anchors.fill: parent
        visible: chip.cursorHere
        color: "transparent"
        radius: chip.radius
        border.width: 1
        border.color: Commons.Color.accent
        antialiasing: true
      }
    }
  }
}
