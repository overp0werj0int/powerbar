import QtQuick

// Follow layout and scroll notifications, including changes in the ancestor
// chain. One deferred notification covers all geometry signals in a layout pass.
Item {
  id: observer
  property Item target: null
  property Item host: null
  property var chain: []
  signal changed()
  visible: false
  function rebuild() {
    var next = []
    function ancestors(start) {
      for (var item = start; item; item = item.parent) {
        if (next.indexOf(item) < 0) next.push(item)
        var transforms = item.transform || []
        for (var i = 0; i < transforms.length; i++) if (next.indexOf(transforms[i]) < 0) next.push(transforms[i])
      }
    }
    if (target) { ancestors(target); ancestors(host) }
    chain = next
    schedule()
  }
  function schedule() { Qt.callLater(notify) }
  function notify() { if (target) changed() }
  onTargetChanged: rebuild()
  onHostChanged: rebuild()
  Component.onCompleted: rebuild()
  Repeater {
    model: observer.chain
    Item {
      required property var modelData
      Connections {
        target: modelData
        ignoreUnknownSignals: true
        function onXChanged() { observer.schedule() }
        function onYChanged() { observer.schedule() }
        function onVisibleChanged() { observer.schedule() }
        function onWidthChanged() { observer.schedule() }
        function onHeightChanged() { observer.schedule() }
        function onScaleChanged() { observer.schedule() }
        function onXScaleChanged() { observer.schedule() }
        function onYScaleChanged() { observer.schedule() }
        function onAngleChanged() { observer.schedule() }
        function onOriginChanged() { observer.schedule() }
        function onRotationChanged() { observer.schedule() }
        function onContentXChanged() { observer.schedule() }
        function onContentYChanged() { observer.schedule() }
        function onParentChanged() { observer.rebuild() }
      }
    }
  }
}
