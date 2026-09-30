import QtQuick

// Each facade gets its own layout copy, only when the layout actually changes.
Item {
  id: sync
  property var apis: ({})
  property var popout: null
  property var owns: function(id, target) { return false }
  property string layoutJSON: "{}"
  property var targets: Object.create(null)
  visible: false
  function updatePopout(api) {
    api.activePopout = owns(api.pluginId, popout) ? popout : popout ? api.foreignPopoutMarker : null
  }
  function initialize(api) {
    updatePopout(api)
    api.layoutConfig = JSON.parse(layoutJSON)
    api.clickTargets = targets[api.pluginId] || []
  }
  function addTarget(id, target) {
    var current = targets[id] || []
    if (current.indexOf(target) >= 0) return
    targets[id] = current.concat([target])
    if (apis[id]) apis[id].clickTargets = targets[id]
  }
  function removeTarget(id, target) {
    var current = targets[id] || []
    if (current.indexOf(target) < 0) return
    var next = current.filter(function(t) { return t !== target })
    if (next.length) targets[id] = next
    else delete targets[id]
    if (apis[id]) apis[id].clickTargets = next
  }
  function forget(id) { delete targets[id] }
  onPopoutChanged: { for (var id in apis) updatePopout(apis[id]) }
  onLayoutJSONChanged: { for (var id in apis) apis[id].layoutConfig = JSON.parse(layoutJSON) }
}
