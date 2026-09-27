import QtQuick
import QtTest

TestCase {
  name: "DragCapture"
  when: windowShown
  Rectangle { id: icon; width: 24; height: 24; color: "#ef476f" }
  Image {
    id: ghost; x: 40; width: 24; height: 24
    onStatusChanged: if (status === Image.Ready) icon.opacity = 0
  }

  function test_iconSnapshotPrecedesSourceHiding() {
    var complete = false
    verify(icon.grabToImage(function(result) {
      ghost.source = result.url
      complete = true
    }, Qt.size(24, 24)))
    tryVerify(function() { return complete }, 1000)
    tryCompare(ghost, "status", Image.Ready, 1000)
    compare(icon.opacity, 0)
  }
}
