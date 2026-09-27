import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "GroupsModel.js" as Model

ColumnLayout {
  id: pane
  required property var preferences
  readonly property var bar: preferences.bar
  readonly property var groups: bar.groups
  property string selectedId: ""
  readonly property var selectedGroup: groups.find(function(g) { return g.id === selectedId }) || null
  readonly property var members: selectedGroup ? selectedGroup.items.map(function(key) {
    return preferences.entries.find(function(e) { return e.instanceKey === key })
      || { instanceKey: key, id: "Unavailable widget", mode: "hidden" }
  }) : []
  function edit(patch) {
    var id = selectedId
    bar.editGroups(function(config) { Model.edit(config, id, patch) })
  }
  function assign(key, id, before) { bar.assignGroup(key, id, before || "") }
  function create() {
    var id = "g-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7)
    bar.editGroups(function(config) { Model.create(config, id, "New group") })
    selectedId = id
  }
  onGroupsChanged: if (!selectedGroup && groups.length) selectedId = groups[0].id
  spacing: Style.space(12)

  SectionHeading { title: "GROUPS"; Layout.fillWidth: true }
  Flow {
    id: groupChips
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    spacing: Style.space(8)
    Repeater {
      id: groupButtons
      model: pane.groups
      Button {
        required property var modelData
        text: modelData.label + "  ·  " + modelData.items.length + "  ·  " + modelData.section
        iconText: Model.iconFont(modelData.icon) ? "" : modelData.icon
        selected: pane.selectedId === modelData.id
        focusable: true; bordered: true
        onClicked: pane.selectedId = modelData.id
        Text {
          visible: !!Model.iconFont(parent.modelData.icon)
          text: parent.modelData.icon; font.family: "omarchy"; color: Color.accent
          anchors.left: parent.left; anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
    Button {
      text: "+ NEW GROUP"; focusable: true; bordered: true
      onClicked: pane.create()
    }
  }
  Text {
    text: "Each group is its own bar icon. Drag it in Layout or move it between zones."
    color: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall; Layout.fillWidth: true
  }
  Text {
    visible: !pane.selectedGroup
    text: "Create a group to collect related widgets in one drawer."
    color: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family
    Layout.fillWidth: true
  }
  Controls.ScrollView {
    visible: !!pane.selectedGroup
    Layout.fillWidth: true; Layout.fillHeight: true
    contentWidth: availableWidth; clip: true
    ColumnLayout {
      width: parent.width
      spacing: Style.space(12)
      SectionHeading { title: "APPEARANCE"; Layout.fillWidth: true }
      RowLayout {
        Layout.fillWidth: true
        Text { text: "LABEL"; color: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family; Layout.preferredWidth: Style.space(130) }
        Controls.TextField {
          Layout.fillWidth: true
          text: pane.selectedGroup ? pane.selectedGroup.label : ""
          onEditingFinished: if (pane.selectedGroup && text.trim()) pane.edit({ label: text })
          Accessible.name: "Group name"
          palette.text: Color.popups.text; palette.base: Color.popups.background
        }
        StockIconPicker {
          Layout.preferredWidth: Style.space(205)
          glyph: pane.selectedGroup ? pane.selectedGroup.icon : "󰉋"
          onChosen: function(glyph) { pane.edit({ icon: glyph }) }
        }
        Controls.ComboBox {
          model: ["Left", "Center", "Right"]
          currentIndex: pane.selectedGroup ? Model.sections.indexOf(pane.selectedGroup.section) : 2
          onActivated: pane.edit({ section: Model.sections[currentIndex] })
          Accessible.name: "Group zone"
          palette.buttonText: Color.popups.text; palette.button: Color.popups.background
        }
      }
      ChoiceRow {
        label: "BAR FACE"; choices: [{name:"GLYPH",value:"glyph"},{name:"TEXT",value:"text"},{name:"BOTH",value:"both"}]
        selectedValue: pane.selectedGroup ? pane.selectedGroup.face : "glyph"
        onChosen: function(value) { pane.edit({ face: value }) }
      }
      ChoiceRow {
        label: "HOVER TIP"; choices: [{name:"ON",value:true},{name:"OFF",value:false}]
        selectedValue: pane.selectedGroup ? (pane.selectedGroup.tooltip === undefined ? pane.selectedGroup.face === "glyph" : pane.selectedGroup.tooltip) : true
        hint: "Group name on hover"
        onChosen: function(value) { pane.edit({ tooltip: value }) }
      }
      ChoiceRow {
        label: "BADGE"; choices: [{name:"ON",value:true},{name:"OFF",value:false}]
        selectedValue: pane.selectedGroup ? pane.selectedGroup.badge : true
        hint: "Live notification count on the group icon"
        onChosen: function(value) { pane.edit({ badge: value }) }
      }
      ChoiceRow {
        visible: pane.selectedGroup && pane.selectedGroup.badge
        label: "BADGE MODE"; choices: [{name:"SUM",value:"sum"},{name:"COUNT",value:"members"}]
        selectedValue: pane.selectedGroup ? pane.selectedGroup.badgeMode : "sum"
        hint: "Sum values or count members with activity"
        onChosen: function(value) { pane.edit({ badgeMode: value }) }
      }
      ChoiceRow {
        label: "MEMBERS"; choices: [{name:"ICON",value:"native"},{name:"NAME",value:"name"},{name:"BOTH",value:"both"}]
        selectedValue: pane.selectedGroup ? pane.selectedGroup.memberDisplay : "native"
        hint: "Choose what each drawer member shows"
        onChosen: function(value) { pane.edit({ memberDisplay: value }) }
      }
      Text {
        visible: !!pane.selectedGroup && pane.selectedGroup.memberDisplay !== "native"
        text: "Named members open as a vertical menu with the theme's corner radius."
        color: Qt.alpha(Color.popups.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        Layout.fillWidth: true
      }
      SectionHeading { title: "WIDGETS"; Layout.fillWidth: true; Layout.topMargin: Style.space(8) }
      OrganizationGrid {
        id: memberGrid
        Layout.fillWidth: true; Layout.preferredHeight: Style.space(335)
        outsideDrop: function(record, point) {
          for (var i = 0; i < groupButtons.count; i++) {
            var button = groupButtons.itemAt(i)
            var p = button.mapFromItem(memberGrid, point.x, point.y)
            if (p.x >= 0 && p.y >= 0 && p.x < button.width && p.y < button.height) {
              pane.assign(record.instanceKey, button.modelData.id); return true
            }
          }
          return false
        }
        preferences: pane.preferences
        membership: true
        sections: ["members", "available"]
        columnLabels: ["IN THIS GROUP", "AVAILABLE WIDGETS"]
        modes: ["shown"]
        entries: {
          var members = pane.members.map(function(e, index) {
            return Object.assign({}, e, { section: "members", mode: "shown", index: index })
          })
          var available = pane.preferences.entries.filter(function(e) {
            return !pane.selectedGroup || pane.selectedGroup.items.indexOf(e.instanceKey) < 0
          }).map(function(e, index) { return Object.assign({}, e, { section: "available", mode: "shown", index: index }) })
          return members.concat(available)
        }
        onMove: function(record, section, mode, before) {
          var anchor = section === "members" && before >= 0 ? pane.members[before] : null
          pane.assign(record.instanceKey, section === "members" ? pane.selectedId : "", anchor ? anchor.instanceKey : "")
        }
      }
      RowLayout {
        visible: memberGrid.selected && memberGrid.selected.section === "members"
        Layout.fillWidth: true
        Text { text: "Badge property"; color: Color.popups.text; font.family: Style.font.family }
        Controls.TextField {
          Layout.preferredWidth: Style.space(155)
          text: memberGrid.selected ? memberGrid.selected.badgeProperty || "" : ""
          placeholderText: "auto · none"
          onEditingFinished: if (memberGrid.selected) pane.bar.editMemberBadge(memberGrid.selected.instanceKey, "badgeProperty", text.trim())
          Accessible.name: "Member badge property"
          palette.text: Color.popups.text; palette.base: Color.popups.background
        }
        Text { text: "Urgent property"; color: Color.popups.text; font.family: Style.font.family }
        Controls.TextField {
          Layout.preferredWidth: Style.space(155)
          text: memberGrid.selected ? memberGrid.selected.urgentProperty || "" : ""
          placeholderText: "auto"
          onEditingFinished: if (memberGrid.selected) pane.bar.editMemberBadge(memberGrid.selected.instanceKey, "urgentProperty", text.trim())
          Accessible.name: "Member urgent property"
          palette.text: Color.popups.text; palette.base: Color.popups.background
        }
        Item { Layout.fillWidth: true }
      }
      Text {
        text: "Badge values are detected from live widgets. Use a property name if needed, or 'none' to exclude one."
        color: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap; Layout.fillWidth: true
      }
      RowLayout {
        Layout.fillWidth: true
        Button {
          text: "Dissolve group"; focusable: true; bordered: true
          tooltipText: "Widgets return to their previous bar placement and visibility"
          onClicked: {
            var id = pane.selectedId
            pane.bar.editGroups(function(config) { Model.remove(config, id) })
            pane.selectedId = ""
          }
        }
        Item { Layout.fillWidth: true }
      }
    }
  }

  component ChoiceRow: RowLayout {
    property string label: ""
    property var choices: []
    property var selectedValue
    property string hint: ""
    signal chosen(var value)
    Layout.fillWidth: true
    spacing: Style.space(8)
    Text { text: parent.label; color: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family; Layout.preferredWidth: Style.space(130) }
    Repeater {
      model: parent.choices
      Button {
        required property var modelData
        text: modelData.name; selected: parent.selectedValue === modelData.value
        bordered: true; focusable: true
        onClicked: parent.chosen(modelData.value)
      }
    }
    Text {
      visible: parent.hint !== ""
      Layout.fillWidth: true; text: parent.hint
      color: Qt.alpha(Color.popups.text, 0.65); font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight
    }
  }
}
