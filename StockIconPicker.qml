import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import "GroupsModel.js" as Groups

Controls.ComboBox {
  id: picker
  property string glyph: "󰉋"
  signal chosen(string glyph)
  model: Groups.icons
  textRole: "name"
  currentIndex: Groups.icons.findIndex(function(icon) { return icon.glyph === picker.glyph })
  Accessible.name: "Group icon from stock Omarchy widgets"
  onActivated: chosen(model[currentIndex].glyph)
  palette.button: Color.popups.background; palette.buttonText: Color.popups.text
  palette.base: Color.popups.background; palette.text: Color.popups.text
  palette.highlight: Color.accent
  contentItem: RowLayout {
    spacing: Style.space(10)
    Text {
      text: picker.glyph; color: Color.accent
      font.family: Groups.iconFont(text) || Style.font.family
      font.pixelSize: Style.font.body
    }
    Text {
      Layout.fillWidth: true; Layout.rightMargin: Style.space(20)
      text: picker.currentIndex >= 0 ? picker.model[picker.currentIndex].name : "Custom icon"
      color: Color.popups.text; font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight
    }
  }
  delegate: Controls.ItemDelegate {
    required property var modelData
    required property int index
    width: picker.width
    highlighted: picker.highlightedIndex === index
    contentItem: RowLayout {
      spacing: Style.space(10)
      Text {
        text: modelData.glyph; color: Color.accent
        font.family: modelData.font || Style.font.family
        font.pixelSize: Style.font.body
      }
      Text {
        Layout.fillWidth: true; text: modelData.name; color: Color.popups.text
        font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
