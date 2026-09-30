import QtQuick
import qs.Ui
import ".."

BarIndicator {
  id: root

  SharedIndicatorState { id: shared; bar: root.bar; kind: "Dictation"; settings: root.settings }
  readonly property string state: shared.producer ? shared.producer.state : "idle"
  readonly property string icon: state === "recording" ? "󰍬" : state === "transcribing" ? "󰔟" : ""
  active: state === "recording"
  activeText: icon
  inactiveText: "󰍬"
  activeTooltipText: state
  inactiveTooltipText: "Dictate"

  onPressed: function() {
    if (!root.bar) return
    root.bar.run("omarchy-voxtype-config")
  }
}
