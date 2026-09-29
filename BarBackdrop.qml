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
    // Previews always draw a horizontal bar, so a side bar reads as top (left)
    // or bottom (right) of the screen.
    verticalAlignment: backdrop.position === "bottom" || backdrop.position === "right" ? Image.AlignBottom : Image.AlignTop
    horizontalAlignment: Image.AlignHCenter
    sourceSize.width: Style.space(1600)
    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
  }
}
