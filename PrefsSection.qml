import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// One titled block of related settings.
ColumnLayout {
  id: section
  property string title: ""
  property string description: ""
  default property alias content: body.data
  Layout.fillWidth: true
  spacing: Style.space(12)

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.space(3)
    Text {
      text: section.title
      textFormat: Text.PlainText
      color: Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
    }
    Text {
      visible: section.description !== ""
      text: section.description
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }
  ColumnLayout {
    id: body
    Layout.fillWidth: true
    spacing: Style.space(8)
  }
}
