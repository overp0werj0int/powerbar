import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "GroupsModel.js" as Groups

// A grid of stock Omarchy glyphs. One focus stop: h/j/k/l or the arrows walk
// it (j/k hand focus on at the top and bottom rows), Space or Enter chooses.
ColumnLayout {
  id: grid
  readonly property bool ownsFocusRing: true
  property string glyph: ""
  property int cursor: Math.max(0, Groups.icons.findIndex(function(icon) { return icon.glyph === grid.glyph }))
  readonly property int cellSize: Style.space(38)
  readonly property int columns: Math.max(1, Math.floor((width + flow.spacing) / (cellSize + flow.spacing)))
  signal chosen(string glyph)
  spacing: Style.space(6)
  activeFocusOnTab: true
  Accessible.role: Accessible.List
  Accessible.name: "Group icon"
  Accessible.description: Groups.icons[cursor] ? Groups.icons[cursor].name : ""
  onGlyphChanged: cursor = Math.max(0, Groups.icons.findIndex(function(icon) { return icon.glyph === grid.glyph }))

  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
    var key = event.key, t = event.text, n = Groups.icons.length
    if (key === Qt.Key_Left || t === "h") cursor = Math.max(0, cursor - 1)
    else if (key === Qt.Key_Right || t === "l") cursor = Math.min(n - 1, cursor + 1)
    else if (key === Qt.Key_Down || t === "j") {
      if (cursor + columns >= n) return
      cursor += columns
    } else if (key === Qt.Key_Up || t === "k") {
      if (cursor - columns < 0) return
      cursor -= columns
    } else if (key === Qt.Key_Space || key === Qt.Key_Return || key === Qt.Key_Enter) grid.chosen(Groups.icons[cursor].glyph)
    else return
    event.accepted = true
  }

  Flow {
    id: flow
    Layout.fillWidth: true
    spacing: Style.space(4)
    Repeater {
      model: Groups.icons
      BorderSurface {
        required property var modelData
        required property int index
        readonly property bool selected: modelData.glyph === grid.glyph
        readonly property bool isCursor: grid.activeFocus && index === grid.cursor
        width: grid.cellSize
        height: grid.cellSize
        radius: Math.max(0, Style.cornerRadius - Style.space(2))
        color: isCursor ? Style.focusFillFor(Color.popups.text, Color.accent)
          : selected ? Style.selectedFillFor(Color.popups.text, Color.accent)
          : hover.hovered ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
        borderSpec: isCursor ? Border.controlSpec("focus", Color.popups.text, Color.accent)
          : selected ? Border.flat(Qt.alpha(Color.accent, 0.7), 1) : Border.none()
        HoverHandler { id: hover }
        Text {
          anchors.centerIn: parent
          text: modelData.glyph
          textFormat: Text.PlainText
          color: parent.selected ? Color.accent : Color.popups.text
          font.family: modelData.font || Style.font.family
          font.pixelSize: Style.font.iconLarge
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { grid.cursor = index; grid.forceActiveFocus(Qt.MouseFocusReason); grid.chosen(modelData.glyph) }
        }
      }
    }
  }
  Text {
    text: grid.activeFocus && Groups.icons[grid.cursor] ? Groups.icons[grid.cursor].name
      : (Groups.icons.find(function(icon) { return icon.glyph === grid.glyph }) || { name: "Custom icon" }).name
    textFormat: Text.PlainText
    color: Qt.alpha(Color.popups.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
