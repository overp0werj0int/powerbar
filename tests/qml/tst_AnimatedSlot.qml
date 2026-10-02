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
  AnimatedSlot { id: delayed; targetWidth: 0; targetHeight: 10; motionDuration: 100; motionDelay: 80 }
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
  function test_motionDelay() {
    wait(120)
    delayed.targetWidth = 40
    wait(40)
    compare(delayed.width, 0)
    wait(200)
    compare(delayed.width, 40)
    delayed.motionDelay = 0
    delayed.targetWidth = 0
    wait(30)
    verify(delayed.width > 0 && delayed.width < 40, "No delay: must already be moving: " + delayed.width)
    wait(150)
    compare(delayed.width, 0)
    delayed.motionEnabled = false
    delayed.motionDelay = 80
    delayed.targetWidth = 40
    compare(delayed.width, 40)
  }
}
