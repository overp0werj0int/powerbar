import QtQml
// Never reads a file: Omarchy's Commons fall back to their defaults.
QtObject {
  property string path: ""
  property bool watchChanges: false
  property bool printErrors: false
  signal fileChanged()
  signal loaded()
  signal loadFailed(var error)
  function text() { return "" }
  function reload() {}
}
