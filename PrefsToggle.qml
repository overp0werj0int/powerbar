import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A labelled switch row in the popup palette. Space, Enter or a click flips it.
// Compact rows sit in tiles: one line, no description, and no surface until
// the pointer or focus is on them.
Toggle {
  id: toggle
  property bool compact: false
  signal toggled(bool checked)
  Layout.fillWidth: true
  foreground: Color.popups.text
  titleSize: Style.font.body
  descriptionSize: Style.font.bodySmall
  onClicked: toggled(!checked)

  readonly property bool resting: compact && !activeFocus && !_hot
  Binding { target: toggle; property: "description"; value: ""; when: toggle.compact }
  Binding { target: toggle; property: "implicitHeight"; value: Style.spacing.controlHeight + Style.space(8); when: toggle.compact }
  Binding { target: toggle; property: "radius"; value: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2)); when: toggle.compact }
  Binding { target: toggle; property: "color"; value: "transparent"; when: toggle.resting }
  Binding { target: toggle; property: "borderSpec"; value: Border.none(); when: toggle.resting }
}
