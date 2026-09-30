import QtQuick
import QtQml.Models
import "RenderModel.js" as RenderModel

// Reconcile a presentation list without resetting delegates on drag previews.
Item {
  id: list
  property var records: []
  property alias factory: store.factory
  property alias recordProperty: store.recordProperty
  readonly property alias model: objects
  visible: false
  RetainedStore { id: store }
  ObjectModel { id: objects }
  function reconcile() {
    store.reconcile(records)
    RenderModel.reconcileLists([objects], [records.map(function(r) { return store.get(r.key) }).filter(function(item) { return !!item })], store)
    store.sweep()
  }
  onRecordsChanged: reconcile()
  Component.onCompleted: reconcile()
}
