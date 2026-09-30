import QtQml
// Deliberately never executes a command. Tests drive output/exit explicitly.
QtObject {
  property var command: []
  property bool running: false
  property QtObject stdout: null
  property QtObject stderr: null
  property int starts: 0
  signal exited(int exitCode)
  onRunningChanged: if (running) starts++
}
