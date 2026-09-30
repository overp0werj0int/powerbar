import QtQuick

Item {
  id: services
  property var producers: Object.create(null)
  visible: false
  Component { id: producerFactory; IndicatorProducer {} }
  function acquire(kind, settings) {
    var key = kind + ":" + JSON.stringify(settings || {})
    var entry = producers[key]
    if (!entry) {
      var object = producerFactory.createObject(services, { kind: kind })
      if (!object) return null
      entry = { object: object, users: 0 }
      producers[key] = entry
    }
    entry.users++
    return entry.object
  }
  function release(object) {
    for (var key in producers) {
      var entry = producers[key]
      if (entry.object !== object) continue
      if (--entry.users === 0) { delete producers[key]; object.destroy() }
      return
    }
  }
  function refresh() { Qt.callLater(refreshAll) }
  function refreshAll() {
    for (var key in producers) producers[key].object.refresh()
  }
}
