import QtQuick
import Quickshell
import qs.Ui
import ".."

BarIndicator {
  id: root

  SharedIndicatorState { id: shared; bar: root.bar; kind: "Reminder"; settings: root.settings }
  readonly property int reminderCount: shared.producer ? shared.producer.reminderCount : 0
  readonly property string tooltip: shared.producer ? shared.producer.tooltip : ""
  active: reminderCount > 0
  activeText: "󰢌"
  inactiveText: "󰢌"
  activeTooltipText: tooltip
  inactiveTooltipText: tooltip
  function openReminderFlow() { Quickshell.execDetached(["omarchy-reminder", "-i"]) }

  onPressed: function() {
    if (root.reminderCount > 0) Quickshell.execDetached(["omarchy-reminder", "show"])
    else root.openReminderFlow()
  }
}
