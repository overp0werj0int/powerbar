import QtQuick
import QtTest
import "../../"
import "../../widgets" as Widgets

TestCase {
  id: test
  name: "RetainedIndicatorProducers"
  when: windowShown
  width: 400; height: 400
  IndicatorServices { id: services }
  QtObject {
    id: hostBar
    property bool vertical: false
    property int barSize: 30
    property bool centerSectionRevealHeld: false
    property bool centerHoverRevealSuppressed: false
    function acquireIndicatorState(kind, settings) { return services.acquire(kind, settings) }
    function releaseIndicatorState(producer) { services.release(producer) }
    function refreshIndicatorStates() { services.refresh() }
  }
  Component {
    id: factory
    Widgets.Indicators {
      bar: hostBar
      settings: ({items: ["Dictation", "Reminder", "ScreenRecording"]})
    }
  }
  function producer(kind) {
    return services.producers[kind + ":{}"].object
  }
  function slots(widget) {
    var found = []
    function visit(item) {
      if (item.indicatorId !== undefined && item.entry !== undefined) found.push(item)
      var children = item.children || []
      for (var i = 0; i < children.length; i++) visit(children[i])
    }
    visit(widget)
    return found
  }
  function test_sharedStateRetainedAcrossActivityAndOrientation() {
    var a = factory.createObject(test), b = factory.createObject(test)
    wait(50)
    compare(Object.keys(services.producers).length, 3)
    compare(services.producers['Dictation:{}'].users, 2)
    var dictation = producer('Dictation'), reminder = producer('Reminder')
    var before = slots(a); compare(before.length, 3)
    dictation.state = 'recording'; wait(20)
    compare(a.activeIndicatorIds.length, 1); compare(a.activeIndicatorIds[0], 'Dictation')
    compare(b.activeIndicatorIds[0], 'Dictation')
    reminder.reminderCount = 2; wait(20)
    compare(a.activeIndicatorIds[0], 'Reminder'); compare(a.activeIndicatorIds[1], 'Dictation')
    hostBar.vertical = true; wait(20)
    var after = slots(a); compare(after.length, 3)
    for (var item of before) verify(after.indexOf(item) >= 0)
    compare(producer('Dictation'), dictation)
    dictation.state = 'idle'; wait(20); compare(a.activeIndicatorIds.length, 1)
    a.destroy(); wait(20); compare(services.producers['Dictation:{}'].users, 1)
    b.destroy(); wait(20); compare(Object.keys(services.producers).length, 0)
    hostBar.vertical = false
  }
  function test_settingsContractsAndRefreshCoalescing() {
    var a = services.acquire('Reminder', {}), b = services.acquire('Reminder', {}), c = services.acquire('Reminder', {variant: 'separate'})
    compare(a, b); verify(a !== c); compare(Object.keys(services.producers).length, 2)
    var proc = null
    for (var item of a.data) if (item.command && item.command[0] === 'omarchy-reminder') proc = item
    verify(proc.command[0] === 'omarchy-reminder')
    proc.running = false
    var starts = proc.starts
    services.refresh(); services.refresh(); wait(20)
    compare(proc.starts, starts + 1)
    proc.stdout.text = '{"count":3,"tooltip":"Fictional reminder"}'; proc.stdout.streamFinished()
    compare(a.reminderCount, 3); compare(a.tooltip, 'Fictional reminder')
    proc.exited(1); compare(a.reminderCount, 0); compare(a.tooltip, '')
    services.release(a); services.release(b); services.release(c); wait(20)
    compare(Object.keys(services.producers).length, 0)
  }
}
