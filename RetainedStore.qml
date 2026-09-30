import QtQuick
import "RenderModel.js" as Model

// QObject ownership stays here while ObjectModels move the visual items.
Item {
  id: store
  property Component factory: null
  property string recordProperty: "record"
  property var equivalent: Model.equal
  property var objects: Object.create(null)
  property var retired: []
  property int revision: 0
  visible: false
  function get(key) { return objects[key] || null }
  function reconcile(records) {
    var next = Object.create(null), membershipChanged = false
    for (var record of records) {
      var object = objects[record.key]
      if (!object) {
        var properties = {}
        properties[recordProperty] = record
        object = factory ? factory.createObject(store, properties) : null
        membershipChanged = true
      } else if (!equivalent(object[recordProperty], record)) {
        object[recordProperty] = record
      }
      if (object) next[record.key] = object
    }
    var removed = []
    for (var key in objects) if (!next[key]) { removed.push(objects[key]); membershipChanged = true }
    if (membershipChanged) {
      objects = next
      retired = retired.concat(removed)
      revision++
    }
  }
  function sweep() {
    var removed = retired
    retired = []
    for (var object of removed) { object.parent = store; object.destroy() }
  }
}
