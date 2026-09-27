import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: fixture
  property string text: "idle"
  property string icon: "◇"
  property int activations: 0
  signal powerbarActivity()
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  WidgetButton {
    id: button
    bar: fixture.bar
    text: fixture.icon + " " + fixture.text
    tooltipText: "Managed-widget test fixture"
    anchors.fill: parent
    onPressed: fixture.activations++
  }
  IpcHandler {
    target: "powerbar-fixture"
    function value(next: string): void { fixture.text = next }
    function icon(next: string): void { fixture.icon = next }
    function event(): void { fixture.powerbarActivity() }
    function state(): string { return JSON.stringify({ text: fixture.text, activations: fixture.activations }) }
  }
}
