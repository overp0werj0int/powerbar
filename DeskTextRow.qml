import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A text value on a desk strip (DeskStrip; docs/behavior/preferences.md
// PREFS-116): its label at the left and its value at the right, the
// placeholder faded while it has none. One stop with the desk row's cursor
// (DeskRow). Enter or a click edits the value in place; Enter saves it to
// the subject it was started for, Esc puts it back, leaving it saves.
BorderSurface {
  id: row
  property string label: ""
  property string value: ""
  property string placeholder: ""
  // What the typing is for: a change of subject mid-edit still saves to the
  // one it started with.
  property var subject: null
  signal committed(var subject, string text)

  property bool editing: false
  property var editSubject: null
  property string startText: ""
  function edit() {
    editSubject = subject;
    startText = value;
    input.text = value;
    editing = true;
    input.forceActiveFocus(Qt.OtherFocusReason);
    input.selectAll();
  }
  function finish(save) {
    if (!editing)
      return;
    var target = editSubject, text = input.text.trim();
    editing = false;
    editSubject = null;
    if (save && target && text !== startText.trim())
      committed(target, text);
  }

  readonly property int deskStops: 1
  readonly property int deskHome: 0
  function deskFocus(stop, reason) {
    forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
  }
  readonly property bool ownsFocusRing: true
  readonly property var keyHints: editing ? [
    {
      keys: "enter",
      label: "Save"
    },
    {
      keys: "esc",
      label: "Put it back"
    }
  ] : [
    {
      keys: "enter",
      label: "Edit"
    }
  ]

  readonly property Item strip: {
    for (var p = parent; p; p = p.parent)
      if (p.isDeskStrip)
        return p;
    return null;
  }
  readonly property color base: strip ? strip.surfaceColor : "transparent"
  readonly property bool cursorHere: activeFocus || editing
  CursorLift {
    id: lift
    up: row.cursorHere
    animate: row.strip && row.strip.desk ? row.strip.desk.animate : true
    lightTheme: row.strip ? row.strip.lightTheme : false
    radius: row.radius
    plate: row.base
  }
  transform: Translate {
    y: -lift.raise
  }
  scale: lift.grown
  z: lift.raised ? 1 : 0
  Layout.fillWidth: true
  Layout.leftMargin: -Gap.s
  Layout.rightMargin: -Gap.s
  implicitHeight: Gap.control
  radius: Round.control
  activeFocusOnTab: false
  opacity: enabled ? 1 : Ink.disabled
  color: cursorHere ? Qt.tint(base, Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)) : mouse.containsMouse && enabled ? Qt.alpha(Commons.Color.popups.text, 0.14) : "transparent"
  borderSpec: cursorHere ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
  Accessible.role: Accessible.EditableText
  Accessible.name: label + ": " + (value || placeholder)

  // While editing every key but Tab is the field's: the desk does not walk
  // on an arrow the field had no use for.
  Keys.onPressed: function (event) {
    if (row.editing) {
      if (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab)
        event.accepted = true;
      return;
    }
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      return;
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      row.edit();
      event.accepted = true;
    }
  }

  RowLayout {
    x: Gap.s
    width: row.width - 2 * Gap.s
    height: row.height
    spacing: Gap.m
    InkText {
      text: row.label
      Layout.alignment: Qt.AlignVCenter
    }
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      InkText {
        visible: !row.editing
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignRight
        text: row.value || row.placeholder
        role: "caption"
        tier: row.value ? 1 : Ink.secondary
        elide: Text.ElideLeft
      }
      TextInput {
        id: input
        visible: row.editing
        anchors.fill: parent
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignRight
        clip: true
        color: Commons.Color.popups.text
        selectionColor: Qt.alpha(Commons.Color.accent, 0.5)
        selectedTextColor: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Ink.caption
        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            row.finish(true);
            row.forceActiveFocus(Qt.OtherFocusReason);
            event.accepted = true;
          } else if (event.key === Qt.Key_Escape) {
            row.finish(false);
            row.forceActiveFocus(Qt.OtherFocusReason);
            event.accepted = true;
          }
        }
        onActiveFocusChanged: if (!activeFocus)
          row.finish(true)
      }
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    visible: !row.editing
    hoverEnabled: true
    enabled: row.enabled
    cursorShape: Qt.IBeamCursor
    onClicked: {
      row.forceActiveFocus(Qt.MouseFocusReason);
      row.edit();
    }
  }
}
