import QtQuick
import qs.Ui
import ".."

BarIndicator {
  id: root

  SharedIndicatorState { id: shared; bar: root.bar; kind: "ScreenRecording"; settings: root.settings }
  readonly property bool recording: shared.producer ? shared.producer.recording : false
  active: recording
  activeText: "󰻂"
  inactiveText: "󰻂"
  activeTooltipText: "Stop recording"
  inactiveTooltipText: "Screen Recording"

  onPressed: function() {
    if (root.bar) {
      root.bar.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-menu toggle trigger.capture.screenrecord")
    }
  }
}
