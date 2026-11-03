import QtQuick
import qs.Commons

// The mark for a zone's waiting widgets (its dots): a small empty circle in
// the bar's ink, held back so it stays quiet, centred in its parent.
Rectangle {
  property color ink: "white"
  anchors.centerIn: parent
  width: Style.space(4)
  height: width
  radius: width / 2
  color: "transparent"
  border.width: 1
  border.color: ink
  antialiasing: true
  opacity: 0.55
}
