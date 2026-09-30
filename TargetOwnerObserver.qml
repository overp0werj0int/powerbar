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
  function rebuild() {
    var next = []
    for (var item = target; item; item = item.parent) {
      next.push(item)
      if (item.powerbarSlotOwner) break
    }
    chain = next
    Qt.callLater(notify)
  }
  function notify() { changed() }
  onTargetChanged: { bindLifetime(); rebuild() }
  Component.onCompleted: { if (!lifetime) bindLifetime(); rebuild() }
  Component.onDestruction: if (lifetime) { lifetime.watcher = null; lifetime.destroy() }
  Repeater {
    model: observer.chain
    Item {
      required property var modelData
      Connections {
        target: modelData
        ignoreUnknownSignals: true
        function onParentChanged() { observer.rebuild() }
      }
    }
  }
}
