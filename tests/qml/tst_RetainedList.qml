import QtQuick
import QtTest
import "../../"

TestCase {
  id: test
  name: "StablePreferencesRows"
  when: windowShown
  width: 240; height: 240
  property int born: 0
  property int died: 0
  RetainedList {
    id: rows
    factory: Component {
      Rectangle {
        required property var record
        width: 40; height: 20
        property int retainedState: 7
        Component.onCompleted: test.born++
        Component.onDestruction: test.died++
      }
    }
  }
  Component {
    id: initialFactory
    RetainedList {
      records: [{key: 'first'}, {key: 'second'}]
      factory: Component { Item { required property var record } }
    }
  }
  function test_initialRecordsBeforePresentationMount() {
    var list = createTemporaryObject(initialFactory, test)
    verify(list !== null)
    compare(list.model.count, 2)
    compare(list.model.get(0).record.key, 'first')
  }
  Flow { id: flow; width: 100; spacing: 4; Repeater { model: rows.model } }
  function cleanup() { rows.records = []; flow.forceLayout(); wait(1); born = 0; died = 0 }
  function test_gapMovesRetainOtherRowsAndWrapping() {
    rows.records = [{key:'a'}, {key:'b'}, {key:'c'}]; flow.forceLayout(); wait(1)
    var a = rows.model.get(0), b = rows.model.get(1), c = rows.model.get(2)
    a.retainedState = 99
    compare(c.y, 24)
    rows.records = [{key:'a'}, {key:'insertion-gap'}, {key:'b'}, {key:'c'}]; flow.forceLayout(); wait(1)
    var gap = rows.model.get(1)
    compare(born, 4); compare(died, 0)
    rows.records = [{key:'a'}, {key:'b'}, {key:'c'}, {key:'insertion-gap'}]; flow.forceLayout(); wait(1)
    compare(rows.model.get(0), a); compare(rows.model.get(1), b); compare(rows.model.get(2), c); compare(rows.model.get(3), gap)
    compare(a.retainedState, 99); compare(born, 4); compare(died, 0)
    rows.records = [{key:'a'}, {key:'b'}, {key:'c'}]; flow.forceLayout(); wait(1)
    compare(died, 1); compare(born, 4)
  }
}
