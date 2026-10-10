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
  // An ancestor that target and host share moves both alike, so it cannot
  // change where the target sits in the host (an autohide slide moves one
  // every frame): only the two chains below it are watched. The target and
  // the host themselves always are, as readers use their sizes too.
  function rebuild() {
    var next = []
    function ancestors(start) {
      var chain = []
      for (var item = start; item; item = item.parent) {
        chain.push(item)
        var transforms = item.transform || []
        for (var i = 0; i < transforms.length; i++) chain.push(transforms[i])
      }
      return chain
    }
    if (target) {
      var fromTarget = ancestors(target), fromHost = ancestors(host)
      var own = function(item, chain, other) { return chain[0] === item || other.indexOf(item) < 0 }
      for (var a of fromTarget) if (own(a, fromTarget, fromHost) && next.indexOf(a) < 0) next.push(a)
      for (var b of fromHost) if (own(b, fromHost, fromTarget) && next.indexOf(b) < 0) next.push(b)
    }
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
