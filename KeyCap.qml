import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A key legend, as printed on a keycap.
BorderSurface {
  id: cap
  property string text: ""
  property color foreground: Commons.Color.popups.text
  implicitWidth: Math.max(implicitHeight, label.implicitWidth + Style.space(10))
  implicitHeight: label.implicitHeight + Style.space(4)
  radius: Math.min(Style.cornerRadius, Style.space(4))
  color: Qt.alpha(foreground, 0.07)
  borderSpec: Border.flat(Qt.alpha(foreground, 0.22), 1)
  Accessible.ignored: true
  Text {
    id: label
    anchors.centerIn: parent
    text: cap.text
    textFormat: Text.PlainText
    color: cap.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
