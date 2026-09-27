import QtQuick
import Quickshell.Widgets
import qs.Commons

// The current wallpaper, cropped to the edge the bar sits on, so previews
// show the bar's surface, borders and transparency as they really look.
ClippingRectangle {
  id: backdrop
  property string source: ""
  property string position: "top"
  radius: Math.max(Style.cornerRadius, Style.space(6))
  color: Qt.alpha(Color.popups.text, 0.08)
  Accessible.ignored: true
  Image {
    anchors.fill: parent
    source: backdrop.source
    asynchronous: true
    cache: false
    fillMode: Image.PreserveAspectCrop
    verticalAlignment: backdrop.position === "bottom" ? Image.AlignBottom : Image.AlignTop
    horizontalAlignment: backdrop.position === "right" ? Image.AlignRight : backdrop.position === "left" ? Image.AlignLeft : Image.AlignHCenter
    sourceSize.width: Style.space(1600)
    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
  }
}
