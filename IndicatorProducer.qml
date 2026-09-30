import QtQuick
import Quickshell.Io
import qs.Commons

// State outlives the active/inactive placement and is shared across monitors.
Item {
  id: producer
  property string kind: ""
  property string state: "idle"
  property int reminderCount: 0
  property string tooltip: ""
  property bool recording: false
  visible: false
  function refresh() {
    if (kind === "Reminder" && !reminder.running) reminder.running = true
    if (kind === "ScreenRecording" && !recordingStatus.running) recordingStatus.running = true
  }
  Component.onCompleted: refresh()
  Process {
    command: ["omarchy-voxtype-status"]
    running: producer.kind === "Dictation"
    stdout: SplitParser {
      onRead: function(raw) {
        var data = Util.parseModuleJson(raw)
        producer.state = String(data.alt || data.class || "idle")
      }
    }
  }
  Process {
    id: reminder
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var data = Util.parseModuleJson(text)
        producer.reminderCount = Number(data.count || 0)
        producer.tooltip = String(data.tooltip || "")
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) { producer.reminderCount = 0; producer.tooltip = "" }
    }
  }
  Process {
    id: recordingStatus
    command: ["pgrep", "--quiet", "-f", "^gpu-screen-recorder"]
    onExited: function(exitCode) { producer.recording = exitCode === 0 }
  }
}
