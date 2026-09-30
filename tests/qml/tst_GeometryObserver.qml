import QtQuick
import QtTest
import "../../"

TestCase {
  id: test
  name: "IdleGeometryTracking"
  when: windowShown
  width: 400; height: 400
  property int updates: 0
  Item { id: host; width: 400; height: 400 }
  Flickable {
    id: viewport
    parent: host
    width: 200; height: 100
    contentWidth: 400; contentHeight: 400
    Item {
      id: target
      x: 10; y: 100; width: 30; height: 30
      transform: Translate { id: translation; x: 0 }
    }
  }
  Item { id: otherParent; parent: host; x: 40 }
  GeometryObserver { id: observer; target: target; host: host; onChanged: test.updates++ }
  function init() { observer.target = target; target.parent = viewport.contentItem; target.x = 10; target.y = 100; translation.x = 0; viewport.contentY = 0; wait(20); updates = 0 }
  function test_coalescesAndStopsAtRest() {
    target.x += 2; target.y += 3; target.width += 4
    tryCompare(test, "updates", 1)
    wait(60); compare(updates, 1)
  }
  function test_scrollTransformAndReparent() {
    viewport.contentY = 30; tryCompare(test, "updates", 1)
    translation.x = 7; tryCompare(test, "updates", 2)
    target.parent = otherParent; tryCompare(test, "updates", 3)
    otherParent.x += 2; tryCompare(test, "updates", 4)
    updates = 0; viewport.contentY = 40; wait(20); compare(updates, 0)
    observer.target = null; wait(20); updates = 0; target.x += 1; wait(20); compare(updates, 0)
  }
}
