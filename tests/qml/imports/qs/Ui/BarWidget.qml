import QtQuick
Item {
  property string moduleName: ""
  property var bar: null
  property var settings: ({})
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : 30
  function setting(key, fallback) { return settings[key] === undefined ? fallback : settings[key] }
  function broadcast(method) { if (typeof this[method] === "function") this[method]() }
}
