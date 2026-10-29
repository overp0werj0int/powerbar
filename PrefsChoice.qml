import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A labelled pick-one row: a field (docs/behavior/preferences.md PREFS-133),
// its label at the label size, regular, an optional caption, and xxs under
// them its chips, a desk's chips (PREFS-128): at the label size, xs × s of
// padding, xs apart, sharing the row by their labels. The chips are a single
// focus stop: h/l or Left/Right walk them, Space or Enter chooses. Narrow
// places stack the label above the chips.
GridLayout {
  id: row
  property bool stacked: false
  // Kept for its callers: the column it stands in spaces it.
  property bool compact: false
  property string label: ""
  property string description: ""
  property var options: []
  property string value: ""
  signal chosen(string value)
  Layout.fillWidth: true
  columns: stacked ? 1 : 2
  columnSpacing: Gap.l
  rowSpacing: Gap.xxs

  function indexOf(v) {
    for (var i = 0; i < options.length; i++)
      if (options[i].value === v)
        return i;
    return -1;
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Gap.xxs
    InkText {
      text: row.label
      Layout.fillWidth: true
      elide: Text.ElideRight
    }
    InkText {
      visible: row.description !== ""
      text: row.description
      role: "caption"
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }
  RowLayout {
    id: chips
    property int cursor: -1
    Layout.fillWidth: true
    spacing: Gap.xs
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: row.label
    onActiveFocusChanged: cursor = activeFocus ? Math.max(0, row.indexOf(row.value)) : -1
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function (event) {
      var key = Util.readingKey(event, true);
      if (key === Qt.Key_Left)
        cursor = Math.max(0, cursor - 1);
      else if (key === Qt.Key_Right)
        cursor = Math.min(row.options.length - 1, cursor + 1);
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        if (cursor >= 0 && row.options[cursor].value !== row.value)
          row.chosen(row.options[cursor].value);
      } else
        return;
      event.accepted = true;
    }
    Repeater {
      model: row.options
      Button {
        required property var modelData
        required property int index
        Layout.fillWidth: true
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: Gap.control
        text: modelData.label
        selected: modelData.value === row.value
        hasCursor: chips.activeFocus && chips.cursor === index
        bordered: true
        foreground: Commons.Color.popups.text
        background: "transparent"
        fontSize: Ink.label
        verticalPadding: Gap.xs
        horizontalPadding: Gap.s
        onClicked: {
          chips.cursor = index;
          if (modelData.value !== row.value)
            row.chosen(modelData.value);
        }
      }
    }
  }
}
