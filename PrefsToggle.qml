import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A labelled switch row in the popup palette. Space, Enter or a click flips it.
Toggle {
  signal toggled(bool checked)
  Layout.fillWidth: true
  foreground: Color.popups.text
  titleSize: Style.font.body
  descriptionSize: Style.font.bodySmall
  onClicked: toggled(!checked)
}
