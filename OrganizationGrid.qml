import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui

ColumnLayout {
  id: editor
  required property var preferences
  property var entries: []
  property var outsideDrop: null
  property var selected: null
  property var dragRecord: null
  property var dropCell: null
  property int dropIndex: -1
  property point dragPoint: Qt.point(0, 0)
  property var sections: ["left", "center", "right"]
  property var columnLabels: ["LEFT", "CENTER", "RIGHT"]
  property bool membership: false
  property var modes: ["shown", "managed", "hidden"]
  signal move(var record, string section, string mode, int before)
  onEntriesChanged: selected = null
  function title(record) { return preferences.title(record) }
  function keyboardMove(record, dx, dy) {
    editor.move(record, sections[Math.max(0, Math.min(sections.length - 1, sections.indexOf(record.section) + dx))],
      modes[Math.max(0, Math.min(modes.length - 1, modes.indexOf(record.mode) + dy))], -1)
    Qt.callLater(function() { editor.forceActiveFocus() })
  }
  function updateDrag(point) {
    dragPoint = point
    dropCell = null
    dropIndex = -1
    for (var i = 0; i < cells.count; i++) {
      var cell = cells.itemAt(i)
      var local = cell.mapFromItem(editor, point.x, point.y)
      if (local.x < 0 || local.y < 0 || local.x >= cell.width || local.y >= cell.height) continue
      dropCell = cell
      for (var j = 0; j < cell.chips.count; j++) {
        var chip = cell.chips.itemAt(j)
        var p = chip.mapFromItem(editor, point.x, point.y)
        if (p.x >= 0 && p.y >= 0 && p.x < chip.width && p.y < chip.height) {
          dropIndex = chip.record.index
          break
        }
      }
      break
    }
  }

            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: Style.space(10)
            RowLayout {
              Layout.fillWidth: true
              Item { visible: !editor.membership; Layout.preferredWidth: Style.space(102) }
              Repeater {
                model: editor.columnLabels
                Label { required property string modelData; text: modelData; Layout.fillWidth: true; Layout.preferredWidth: 1; color: Qt.alpha(Color.popups.text, 0.65); font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignHCenter }
              }
            }
            RowLayout {
              Layout.fillWidth: true; Layout.fillHeight: true
              spacing: Style.space(12)
              ColumnLayout {
                visible: !editor.membership
                Layout.preferredWidth: Style.space(102); Layout.minimumWidth: Style.space(102); Layout.maximumWidth: Style.space(102); Layout.fillHeight: true
                spacing: Style.space(10)
                Repeater {
                  model: [{label: "Always shown", hint: "Keep visible", icon: "󰈈"}, {label: "Managed", hint: "Automatic", icon: "󰒓"}, {label: "Always hidden", hint: "Off the bar", icon: "󰈉"}]
                  Item {
                    id: rowHeading
                    required property var modelData
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredHeight: 1
                    Column {
                      width: parent.width
                      spacing: Style.space(10)
                      Label { text: rowHeading.modelData.icon; color: Color.accent; font.pixelSize: Style.space(22) }
                      Label { text: rowHeading.modelData.label; font.pixelSize: Style.font.bodySmall; font.bold: true }
                      Label { text: rowHeading.modelData.hint; color: Qt.alpha(Color.popups.text, 0.65); font.pixelSize: Style.font.bodySmall }
                    }
                  }
                }
              }
              GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                columns: editor.sections.length; rowSpacing: Style.space(10); columnSpacing: Style.space(10)
                Repeater {
                  id: cells
                  model: editor.sections.length * editor.modes.length
                  Rectangle {
                    id: cell
                    required property int index
                    property string section: editor.sections[index % editor.sections.length]
                    property string mode: editor.modes[Math.floor(index / editor.sections.length)]
                    property alias chips: chips
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.preferredWidth: 1; Layout.preferredHeight: 1
                    radius: Math.max(Style.cornerRadius, Style.space(8))
                    color: Qt.alpha(Color.popups.text, editor.dropCell === cell ? 0.09 : 0.035)
                    border.width: 1
                    border.color: editor.dropCell === cell ? Color.accent : Qt.alpha(Color.popups.text, 0.12)
                    Controls.ScrollView {
                      id: cellScroll
                      anchors.fill: parent; anchors.margins: Style.space(8)
                      contentWidth: availableWidth
                      clip: true
                      Column {
                        width: parent.width; spacing: Style.space(5)
                        Repeater {
                          id: chips
                          model: editor.entries.filter(function(e) { return e.section === cell.section && e.mode === cell.mode })
                          Rectangle {
                            id: chip
                            required property var modelData
                            property var record: modelData
                            width: parent.width; height: Style.space(38)
                            radius: Style.space(5)
                            activeFocusOnTab: true
                            color: activeFocus || (editor.selected && editor.selected.fingerprint === record.fingerprint && editor.selected.section === record.section && editor.selected.index === record.index) ? Qt.alpha(Color.accent, 0.18) : Qt.alpha(Color.popups.text, mouse.containsMouse ? 0.10 : 0.055)
                            border.width: activeFocus || (editor.dropCell === cell && editor.dropIndex === record.index) ? 1 : 0
                            border.color: Color.accent
                            Accessible.role: Accessible.Button
                            Accessible.name: editor.title(record) + ", " + cell.mode + ", " + cell.section
                            Keys.onSpacePressed: editor.selected = record
                            Keys.onReturnPressed: editor.selected = record
                            Keys.onPressed: function(event) {
                              if (!(event.modifiers & Qt.ControlModifier)) return
                              if (event.key === Qt.Key_Left) editor.keyboardMove(record, -1, 0)
                              else if (event.key === Qt.Key_Right) editor.keyboardMove(record, 1, 0)
                              else if (event.key === Qt.Key_Up) editor.keyboardMove(record, 0, -1)
                              else if (event.key === Qt.Key_Down) editor.keyboardMove(record, 0, 1)
                              else return
                              event.accepted = true
                            }
                            onActiveFocusChanged: {
                              if (!activeFocus) return
                              editor.selected = record
                              var view = cellScroll.contentItem
                              if (y < view.contentY) view.contentY = y
                              else if (y + height > view.contentY + view.height) view.contentY = y + height - view.height
                            }
                            RowLayout {
                              anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8)
                              Label { text: editor.preferences.icon(chip.record); font.family: editor.preferences.iconFont(chip.record); color: Color.accent; font.pixelSize: Style.space(18) }
                              Label { text: editor.title(chip.record) + (chip.record.groupId ? " · group" : ""); elide: Text.ElideRight; Layout.fillWidth: true; font.pixelSize: Style.font.bodySmall }
                              Label { text: "⠿"; color: Qt.alpha(Color.popups.text, 0.65) }
                            }
                            Controls.ToolTip.visible: mouse.containsMouse && !editor.dragRecord
                            Controls.ToolTip.text: editor.title(record) + "\n" + record.id
                            Controls.ToolTip.delay: 600
                            MouseArea {
                              id: mouse
                              anchors.fill: parent; hoverEnabled: true
                              cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                              preventStealing: true
                              property point origin
                              onPressed: function(event) { origin = Qt.point(event.x, event.y); chip.forceActiveFocus(); editor.selected = chip.record }
                              onPositionChanged: function(event) {
                                if (!pressed) return
                                if (!editor.dragRecord && Math.abs(event.x - origin.x) + Math.abs(event.y - origin.y) > Style.space(6)) editor.dragRecord = chip.record
                                if (editor.dragRecord) editor.updateDrag(chip.mapToItem(editor, event.x, event.y))
                              }
                              onReleased: {
                                var source = editor.dragRecord, target = editor.dropCell, before = editor.dropIndex
                                editor.dragRecord = null; editor.dropCell = null
                                if (source && editor.outsideDrop && editor.outsideDrop(source, editor.dragPoint)) return
                                if (source && target) editor.move(source, target.section, target.mode, before)
                              }
                              onCanceled: { editor.dragRecord = null; editor.dropCell = null }
                            }
                          }
                        }
                        Label { visible: chips.count === 0; text: "Drop widgets here"; color: Qt.alpha(Color.popups.text, 0.65); font.pixelSize: Style.font.bodySmall; width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: Style.space(12) }
                      }
                    }
                  }
                }
              }
            }
            Label { text: editor.membership ? "Drag to assign or reorder · Ctrl + Left / Right to transfer · Tab to navigate" : "Tab to an item · Ctrl + arrows to move between zones and visibility rows"; color: Qt.alpha(Color.popups.text, 0.65); font.pixelSize: Style.font.bodySmall; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            RowLayout {
              Layout.fillWidth: true
              Label { text: editor.selected ? editor.title(editor.selected) : "Select a widget to move it"; Layout.fillWidth: true; elide: Text.ElideRight }
              Controls.ComboBox {
                id: destinationSection
                model: editor.columnLabels
                Accessible.name: "Destination zone"
                palette.button: Color.popups.background; palette.buttonText: Color.popups.text; palette.base: Color.popups.background; palette.text: Color.popups.text
              }
              Controls.ComboBox {
                id: destinationMode
                visible: !editor.membership
                model: ["Always shown", "Managed", "Always hidden"]; currentIndex: 1
                Accessible.name: "Visibility"
                palette.button: Color.popups.background; palette.buttonText: Color.popups.text; palette.base: Color.popups.background; palette.text: Color.popups.text
              }
              Button { text: "Move"; bordered: true; focusable: true; enabled: editor.selected !== null; opacity: enabled ? 1 : 0.4; onClicked: editor.move(editor.selected, editor.sections[destinationSection.currentIndex], editor.membership ? "shown" : editor.modes[destinationMode.currentIndex], -1) }
            }

  component Label: Text {
    textFormat: Text.PlainText; color: Color.popups.text
    font.family: Style.font.family; font.pixelSize: Style.font.body
  }
}
