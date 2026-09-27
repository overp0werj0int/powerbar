import QtQuick
import QtTest
import "../../"

TestCase {
  id: testCase
  name: "SignalActivity"
  when: windowShown
  QtObject {
    id: widget
    property string text: "idle"
    property string icon: "bell"
    property int value: 0
    property int powerbarActivityRevision: 0
    property int width: 26
    signal powerbarActivity()
  }
  ActivityObserver { id: observer; target: widget }
  SignalSpy { id: spy; target: observer; signalName: "activity" }
  function init() {
    observer.enabledForActivity = false
    widget.text = "idle"; widget.icon = "bell"; widget.value = 0; widget.width = 26
    observer.enabledForActivity = true
    wait(1)
    spy.clear()
  }
  function test_baselineAndSignals() {
    compare(spy.count, 0)
    widget.text = "working"
    compare(spy.count, 1)
    widget.text = "working"
    compare(spy.count, 1)
    widget.icon = "alert"
    compare(spy.count, 2)
    widget.value = 3
    compare(spy.count, 3)
    widget.width = 52
    compare(spy.count, 3)
    widget.powerbarActivity()
    widget.powerbarActivity()
    compare(spy.count, 5)
  }
  function test_disabledChangesBecomeBaseline() {
    observer.enabledForActivity = false
    widget.text = "new baseline"
    compare(spy.count, 0)
    observer.enabledForActivity = true
    wait(1)
    compare(spy.count, 0)
    widget.text = "new event"
    compare(spy.count, 1)
  }
}
