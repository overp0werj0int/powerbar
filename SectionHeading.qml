import QtQuick
import QtQuick.Layouts
import qs.Commons

RowLayout {
  id: heading
  property string title: ""
  spacing: Style.space(10)
  Text {
    text: heading.title
    color: Color.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.bold: true
  }
  Rectangle {
    Layout.fillWidth: true
    height: 1
    color: Qt.alpha(Color.popups.text, 0.3)
  }
}
