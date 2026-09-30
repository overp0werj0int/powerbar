import QtQuick

Item {
  id: state
  property var bar: null
  property string kind: ""
  property var settings: ({})
  property var producer: null
  property var owner: null
  property string contract: ""
  visible: false
  function bind() {
    var next = kind + ":" + JSON.stringify(settings || {})
    if (bar === owner && next === contract) return
    if (producer && owner) owner.releaseIndicatorState(producer)
    owner = bar
    contract = next
    producer = kind && bar && bar.acquireIndicatorState ? bar.acquireIndicatorState(kind, settings) : null
  }
  onBarChanged: bind()
  onKindChanged: bind()
  onSettingsChanged: bind()
  Component.onCompleted: bind()
  Component.onDestruction: if (producer && owner) owner.releaseIndicatorState(producer)
}
