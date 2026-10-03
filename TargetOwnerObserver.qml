import QtQuick

// Geometry never changes click ownership. Watch only reparenting on the chain
// up to the stable presentation owner (drawer mounts sit above that boundary).
Item {
  id: observer
  property QtObject target: null
  property var chain: []
  property QtObject lifetime: null
  Component {
    id: lifetimeFactory
    QtObject {
      property QtObject watcher: null
      Component.onDestruction: if (watcher) watcher.targetGone()
    }
  }
  function targetGone() { lifetime = null; target = null; changed() }
  function bindLifetime() {
    if (lifetime) { lifetime.watcher = null; lifetime.destroy(); lifetime = null }
    if (target) lifetime = lifetimeFactory.createObject(target, { watcher: observer })
  }
  signal changed()
  visible: false
  // The chain's parent signals are connected directly; a destroyed item has
  // already dropped its connection.
  function watch(item, on) {
    try {
      var signal = item.parentChanged
      if (signal && typeof signal.connect === "function") {
        if (on) signal.connect(observer.rebuild)
        else signal.disconnect(observer.rebuild)
      }
    } catch (e) {
    }
  }
  function rebuild() {
    var next = []
    for (var item = target; item; item = item.parent) {
      next.push(item)
      if (item.powerbarSlotOwner) break
    }
    var previous = chain
    for (var old of previous) if (next.indexOf(old) < 0) watch(old, false)
    for (var added of next) if (previous.indexOf(added) < 0) watch(added, true)
    chain = next
    Qt.callLater(notify)
  }
  function notify() { changed() }
  onTargetChanged: { bindLifetime(); rebuild() }
  Component.onCompleted: { if (!lifetime) bindLifetime(); rebuild() }
  Component.onDestruction: {
    for (var item of chain) watch(item, false)
    chain = []
    if (lifetime) { lifetime.watcher = null; lifetime.destroy() }
  }
}
