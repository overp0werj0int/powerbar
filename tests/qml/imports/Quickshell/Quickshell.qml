pragma Singleton
import QtQml
QtObject {
  property var screens: []
  function execDetached(argv) {}
  function env(name) { return "" }
}
