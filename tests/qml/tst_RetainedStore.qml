import QtQuick
import QtQml.Models
import QtTest
import "../../"
import "../../RenderModel.js" as RenderModel

TestCase {
  id: test
  name: "RetainedWidgetLifecycle"
  when: windowShown
  width: 400; height: 400
  property int born: 0
  property int died: 0
  Component {
    id: widgetFactory
    Rectangle {
      required property var record
      property int state: 42
      width: 20; height: 26
      Component.onCompleted: test.born++
      Component.onDestruction: test.died++
    }
  }
  RetainedStore { id: store; factory: widgetFactory }
  ObjectModel { id: leftModel }
  ObjectModel { id: rightModel }
  Grid { id: left; columns: vertical ? 1 : 2; property bool vertical: false; Repeater { model: leftModel } }
  Row { id: right; y: 100; Repeater { model: rightModel } }
  function entry(key, region, value) { return { key: key, region: region, value: value || 0 } }
  function render(records) {
    store.reconcile(records)
    var lists = [records.filter(function(r) { return r.region === "left" }).map(function(r) { return store.get(r.key) }),
      records.filter(function(r) { return r.region === "right" }).map(function(r) { return store.get(r.key) })]
    RenderModel.reconcileLists([leftModel, rightModel], lists, store)
    store.sweep()
    left.forceLayout(); right.forceLayout()
  }
  function cleanup() { render([]); wait(1); born = 0; died = 0; left.vertical = false }
  function test_movesUpdatesAndRotationRetainState() {
    render([entry("a", "left"), entry("b", "left")])
    var a = store.get("a"), b = store.get("b")
    a.state = 99
    compare(born, 2)
    render([entry("b", "left"), entry("a", "left")])
    compare(store.get("a"), a); compare(a.x, 20); compare(born, 2); compare(died, 0)
    render([entry("b", "left"), entry("a", "right", 7)])
    compare(a.parent, right); compare(a.record.value, 7); compare(a.state, 99)
    left.vertical = true; left.forceLayout()
    compare(store.get("b"), b); compare(born, 2); compare(died, 0)
    render([entry("a", "right", 7), entry("b", "left")])
    compare(store.get("a"), a); compare(a.state, 99); compare(born, 2)
  }
  function test_removalAndRestorationOnlyReplaceRemovedOwner() {
    render([entry("duplicate-1", "left"), entry("duplicate-2", "left")])
    var second = store.get("duplicate-2")
    render([entry("duplicate-2", "right")]); wait(1)
    compare(died, 1); compare(store.get("duplicate-2"), second)
    render([entry("duplicate-1", "left"), entry("duplicate-2", "right")])
    compare(born, 3); compare(store.get("duplicate-2"), second)
  }
  function test_identicalRecordDoesNotNotify() {
    render([entry("a", "left", 8)])
    var a = store.get("a"), record = a.record
    render([entry("a", "left", 8)])
    compare(a.record, record); compare(born, 1); compare(died, 0)
  }
}
