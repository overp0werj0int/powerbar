import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A labelled pick-one row. The chips are a single focus stop: h/l or
// Left/Right walk them, Space or Enter chooses. Narrow places stack the label
// above the chips.
GridLayout {
  id: row
  property bool stacked: false
  property string label: ""
  property string description: ""
  property var options: []
  property string value: ""
  signal chosen(string value)
  Layout.fillWidth: true
  columns: stacked ? 1 : 2
  columnSpacing: Style.space(16)
  rowSpacing: Style.space(6)

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.space(2)
    Text {
      text: row.label
      textFormat: Text.PlainText
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      Layout.fillWidth: true
      elide: Text.ElideRight
    }
    Text {
      visible: row.description !== ""
      text: row.description
      textFormat: Text.PlainText
      color: Qt.alpha(Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }
  ButtonGroup {
    options: row.options
    value: row.value
    foreground: Color.popups.text
    background: "transparent"
    fontSize: Style.font.bodySmall
    Accessible.name: row.label
    onChanged: function(value) { row.chosen(value) }
  }
}
