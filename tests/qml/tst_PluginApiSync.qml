import QtQuick
import QtTest
import "../../"

TestCase {
  id: test
  name: "ScopedPluginApiUpdates"
  when: windowShown
  property int layoutUpdates: 0
  property int targetUpdates: 0
  Component {
    id: factory
    QtObject {
      required property string pluginId
      property var activePopout: null
      property var foreignPopoutMarker: ({ foreign: true })
      property var layoutConfig: ({})
      property var clickTargets: []
      onLayoutConfigChanged: test.layoutUpdates++
      onClickTargetsChanged: test.targetUpdates++
    }
  }
  PluginApiSync { id: sync; owns: function(id, target) { return target && target.owner === id } }
  QtObject { id: panel; property string owner: "a" }
  Item { id: button }
  function test_independentUpdatesAndCopyIsolation() {
    var a = factory.createObject(test, {pluginId: "a"}), b = factory.createObject(test, {pluginId: "b"})
    sync.layoutJSON = '{"left":[{"id":"x"}],"center":[],"right":[]}'
    sync.apis = { a: a, b: b }
    sync.initialize(a); sync.initialize(b)
    layoutUpdates = 0; targetUpdates = 0
    sync.popout = panel
    compare(a.activePopout, panel); compare(b.activePopout, b.foreignPopoutMarker)
    compare(layoutUpdates, 0); compare(targetUpdates, 0)
    sync.addTarget("a", button)
    compare(a.clickTargets.length, 1); compare(b.clickTargets.length, 0)
    compare(targetUpdates, 1); compare(layoutUpdates, 0)
    sync.addTarget("a", button)
    compare(targetUpdates, 1)
    a.layoutConfig.left[0].id = "modified"
    compare(b.layoutConfig.left[0].id, "x")
    sync.layoutJSON = sync.layoutJSON
    compare(layoutUpdates, 0)
    sync.layoutJSON = '{"left":[{"id":"y"}],"center":[],"right":[]}'
    compare(layoutUpdates, 2); compare(a.layoutConfig.left[0].id, "y")
    sync.removeTarget("a", button)
    compare(targetUpdates, 2); compare(a.clickTargets.length, 0)
    sync.removeTarget("a", button)
    compare(targetUpdates, 2)
    sync.apis = ({}); sync.popout = null; a.destroy(); b.destroy()
  }
}
