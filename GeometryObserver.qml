import QtQuick

// Follow layout and scroll notifications, including changes in the ancestor
// chain. One deferred notification covers all geometry signals in a layout pass.
// The chain's signals are connected directly: a rebuild connects only the
// items that joined the chain, instead of re-creating a watcher per ancestor.
Item {
  id: observer
  property Item target: null
  property Item host: null
  property var chain: []
  readonly property var geometrySignals: ["xChanged", "yChanged", "visibleChanged", "widthChanged", "heightChanged",
    "scaleChanged", "xScaleChanged", "yScaleChanged", "angleChanged", "originChanged", "rotationChanged",
    "contentXChanged", "contentYChanged"]
  signal changed()
  visible: false
  function attach(item) {
    try {
      for (var name of geometrySignals) {
        var signal = item[name]
        if (signal && typeof signal.connect === "function") signal.connect(observer.schedule)
      }
      if (item.parentChanged && typeof item.parentChanged.connect === "function") item.parentChanged.connect(observer.rebuild)
    } catch (e) {
    }
  }
  // A destroyed item has already dropped its connections.
  function detach(item) {
    try {
      for (var name of geometrySignals) {
        var signal = item[name]
        if (signal && typeof signal.disconnect === "function") signal.disconnect(observer.schedule)
      }
      if (item.parentChanged && typeof item.parentChanged.disconnect === "function") item.parentChanged.disconnect(observer.rebuild)
    } catch (e) {
    }
  }
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
    var previous = chain
    for (var old of previous) if (next.indexOf(old) < 0) detach(old)
    for (var item of next) if (previous.indexOf(item) < 0) attach(item)
    chain = next
    schedule()
  }
  function schedule() { Qt.callLater(notify) }
  function notify() { if (target) changed() }
  onTargetChanged: rebuild()
  onHostChanged: rebuild()
  Component.onCompleted: rebuild()
  Component.onDestruction: {
    for (var item of chain) detach(item)
    chain = []
  }
}
