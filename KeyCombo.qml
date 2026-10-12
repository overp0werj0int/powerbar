import QtQuick
import qs.Commons
import qs.Commons as Commons

// A key combination as keycaps joined by "+" (Super + Ctrl + A): tooltips,
// the keyboard mode's name card and shortcut sheet, and Preferences' shortcut
// rows. Sequences and alternatives (the key strip's "Esc Esc", "Tab Shift+Tab") are not
// combinations and stay as separate caps.
Row {
  id: combo
  property var keys: []
  property color foreground: Commons.Color.popups.text
  spacing: Style.space(3)
  Repeater {
    model: combo.keys || []
    Row {
      required property string modelData
      required property int index
      spacing: combo.spacing
      KeyCap { text: parent.modelData; foreground: combo.foreground; anchors.verticalCenter: parent.verticalCenter }
      Text {
        visible: parent.index < (combo.keys || []).length - 1
        text: "+"
        textFormat: Text.PlainText
        color: Qt.alpha(combo.foreground, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
