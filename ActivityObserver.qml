import QtQuick
import "ManagedModel.js" as Model

// QML bindings subscribe to property notifications; there is no observation timer.
Item {
  id: observer
  property var target: null
  property bool enabledForActivity: true
  property bool armed: false
  property string previousSnapshot: ""
  readonly property string snapshot: enabledForActivity ? Model.snapshot(target) : ""
  signal activity()
  function establishBaseline() {
    armed = false
    Qt.callLater(function() { previousSnapshot = snapshot; armed = true })
  }
  onTargetChanged: establishBaseline()
  onEnabledForActivityChanged: establishBaseline()
  onSnapshotChanged: {
    var changed = previousSnapshot !== snapshot
    previousSnapshot = snapshot
    if (armed && enabledForActivity && changed) activity()
  }
  Component.onCompleted: establishBaseline()
  Connections {
    target: observer.target
    ignoreUnknownSignals: true
    function onPowerbarActivity() { if (observer.armed && observer.enabledForActivity) observer.activity() }
  }
}
