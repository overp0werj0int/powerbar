import QtQuick
import QtTest
import "../../"

TestCase {
  name: "IslandLayout"
  when: windowShown
  Row {
    id: row
    AnimatedSlot { targetWidth: 20; targetHeight: 24 }
    AnimatedSlot { id: middle; targetWidth: 0; targetHeight: 24 }
    AnimatedSlot { id: neighbour; targetWidth: 20; targetHeight: 24 }
  }
  Rectangle { id: chrome; width: row.width; height: row.height; visible: false }
  function test_middleInsertionAndRemoval() {
    wait(120)
    compare(neighbour.x, 20)
    middle.targetWidth = 24
    wait(40)
    verify(neighbour.x > 20 && neighbour.x < 44, "Neighbour must move with the new slot, not jump to its final position: " + neighbour.x + ", extent=" + middle.width)
    for (var i = 0; i < 8; i++) {
      verify(neighbour.x + neighbour.width <= chrome.width + 0.1)
      wait(16)
    }
    compare(neighbour.x, 44)
    middle.targetWidth = 0
    wait(40)
    verify(neighbour.x > 20 && neighbour.x < 44)
    wait(120)
    compare(neighbour.x, 20)
    middle.motionEnabled = false
    middle.targetWidth = 24
    row.forceLayout()
    compare(neighbour.x, 44)
  }
}
