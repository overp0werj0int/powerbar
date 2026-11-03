import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A group's face in the Groups page's inspector (docs/behavior/preferences.md
// PREFS-116), drawn as the bar draws it, on the bar's colour, in its ink and
// font, and edited where it is seen: its icon and its name are two stops on
// the desk (h/l between them and on to the next strip). Enter on the icon
// opens the icon picker (`pickIcon`); Enter on the name edits it in place:
// Enter saves it to the group it was started for, Esc puts it back, leaving
// saves. The part the face does not show on the bar (Show) is faded.
Item {
  id: face
  // The Layout page's editor: the bar's colour, ink and font.
  required property var layout
  property var group: null
  signal pickIcon
  signal renamed(var group, string text)

  // 0 the icon, 1 the name.
  property int cursor: 1
  readonly property int deskStops: 2
  readonly property int deskHome: 1
  readonly property int deskStop: cursor
  function deskFocus(stop, reason) {
    cursor = stop;
    forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
  }
  readonly property bool ownsFocusRing: true
  readonly property var keyHints: editing ? [
    {
      keys: "enter",
      label: "Save the name"
    },
    {
      keys: "esc",
      label: "Put it back"
    }
  ] : [
    {
      keys: "enter",
      label: cursor === 0 ? "Choose an icon" : "Rename"
    }
  ]

  property bool editing: false
  property var editGroup: null
  function edit() {
    if (!group)
      return;
    cursor = 1;
    editGroup = group;
    input.text = group.label;
    editing = true;
    input.forceActiveFocus(Qt.OtherFocusReason);
    input.selectAll();
  }
  function finish(save) {
    if (!editing)
      return;
    var target = editGroup, text = input.text.trim();
    editing = false;
    editGroup = null;
    if (save && target && text && text !== target.label)
      renamed(target, text);
  }

  readonly property string mode: group ? group.face || "glyph" : "glyph"
  readonly property bool cursorHere: activeFocus || editing
  Layout.fillWidth: true
  implicitHeight: Gap.xxl
  activeFocusOnTab: false
  Accessible.role: Accessible.Grouping
  Accessible.name: group ? "Face of " + group.label : ""

  Keys.onPressed: function (event) {
    if (face.editing) {
      if (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab)
        event.accepted = true;
      return;
    }
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      return;
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
      return;
    if (face.cursor === 0)
      face.pickIcon();
    else
      face.edit();
    event.accepted = true;
  }

  Rectangle {
    anchors.fill: parent
    radius: Round.control
    color: face.layout.barSurface
  }
  // A part of the face: its focus ring s round its ink.
  component Part: BorderSurface {
    id: part
    property int stop: 0
    property bool hot: false
    readonly property bool marked: face.cursorHere && face.cursor === stop
    radius: Round.small
    color: marked ? Qt.alpha(Commons.Color.accent, 0.18) : hot ? Qt.alpha(face.layout.barInk, 0.1) : "transparent"
    borderSpec: marked ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
  }
  Row {
    id: parts
    anchors.centerIn: parent
    spacing: Gap.xs
    Part {
      id: iconPart
      stop: 0
      hot: iconMouse.containsMouse
      // A square at least.
      width: Math.max(height, glyph.implicitWidth + 2 * Gap.s)
      height: face.height - 2 * Gap.xs
      GroupFace {
        id: glyph
        anchors.centerIn: parent
        opacity: face.mode === "text" ? Ink.disabled : 1
        group: face.group
        faceMode: "glyph"
        color: face.layout.barInk
        fontFamily: face.layout.barFont
        fontSize: Style.font.body
      }
      MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          face.deskFocus(0, Qt.MouseFocusReason);
          face.pickIcon();
        }
      }
    }
    Part {
      id: namePart
      readonly property real room: face.width - iconPart.width - parts.spacing - 2 * Gap.s
      stop: 1
      hot: nameMouse.containsMouse
      width: Math.min(room, Math.max(nameText.implicitWidth, face.editing ? Style.space(60) : 0) + 2 * Gap.s)
      height: face.height - 2 * Gap.xs
      Text {
        id: nameText
        visible: !face.editing
        anchors.fill: parent
        anchors.leftMargin: Gap.s
        anchors.rightMargin: Gap.s
        verticalAlignment: Text.AlignVCenter
        opacity: face.mode === "glyph" ? Ink.disabled : 1
        text: face.group ? face.group.label : ""
        textFormat: Text.PlainText
        color: face.layout.barInk
        font.family: face.layout.barFont
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        renderType: Text.NativeRendering
      }
      TextInput {
        id: input
        visible: face.editing
        anchors.fill: parent
        anchors.leftMargin: Gap.s
        anchors.rightMargin: Gap.s
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: face.layout.barInk
        selectionColor: Qt.alpha(Commons.Color.accent, 0.5)
        selectedTextColor: face.layout.barInk
        font.family: face.layout.barFont
        font.pixelSize: Style.font.body
        Accessible.name: "Group name"
        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            face.finish(true);
            face.forceActiveFocus(Qt.OtherFocusReason);
            event.accepted = true;
          } else if (event.key === Qt.Key_Escape) {
            face.finish(false);
            face.forceActiveFocus(Qt.OtherFocusReason);
            event.accepted = true;
          }
        }
        onActiveFocusChanged: if (!activeFocus)
          face.finish(true)
      }
      MouseArea {
        id: nameMouse
        anchors.fill: parent
        visible: !face.editing
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: {
          face.deskFocus(1, Qt.MouseFocusReason);
          face.edit();
        }
      }
    }
  }
}
