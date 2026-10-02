import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "GroupsModel.js" as Model

// Groups: the list of groups beside an editor for the selected one.
// Keyboard: j/k walk the list, n makes a group, x twice dissolves one, Enter or
// Tab moves into the editor, whose controls are walked with j/k or Tab.
Item {
  id: pane
  required property var preferences
  readonly property var bar: preferences.bar
  readonly property var groups: bar.groups
  property string selectedId: ""
  property string pendingDissolve: ""
  readonly property var selectedGroup: groups.find(function(g) { return g.id === selectedId }) || null
  readonly property int selectedIndex: groups.findIndex(function(g) { return g.id === selectedId })
  readonly property var members: selectedGroup ? selectedGroup.items.map(function(key) {
    return preferences.entries.find(function(e) { return e.instanceKey === key })
      || { instanceKey: key, id: "unavailable", label: "Unavailable widget", mode: "hidden" }
  }) : []
  readonly property var hints: listFocused ? [
    { keys: "j k", label: "Choose" }, { keys: "n", label: "New group" },
    { keys: "x", label: "Dissolve" }, { keys: "enter", label: "Edit" }, { keys: "esc", label: "Close" }
  ] : memberList.lifted ? [
    { keys: "j k", label: "Reorder" }, { keys: "space", label: "Drop" }, { keys: "esc", label: "Cancel" }
  ] : memberList.activeFocus ? [
    { keys: "j k", label: "Choose" }, { keys: "space", label: "Pick up" },
    { keys: "x", label: "Remove" }, { keys: "tab", label: "Next" }
  ] : availableList.activeFocus ? [
    { keys: "j k", label: "Choose" }, { keys: "enter", label: "Add" },
    { keys: "/", label: "Filter" }, { keys: "tab", label: "Next" }
  ] : [
    { keys: "j k", label: "Move" }, { keys: "h l", label: "Choose" },
    { keys: "shift+tab", label: "Groups" }, { keys: "esc", label: "Close" }
  ]
  readonly property bool listFocused: groupList.activeFocus

  function focusFirst() { groupList.forceActiveFocus(Qt.TabFocusReason) }
  function edit(patch) {
    var id = selectedId
    if (id) bar.editGroups(function(config) { Model.edit(config, id, patch) })
  }
  function create() {
    var id = "g-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7)
    bar.editGroups(function(config) { Model.create(config, id, "New group") })
    selectedId = id
    Qt.callLater(function() { nameField.forceActiveFocus(); nameField.selectAll() })
  }
  function dissolve(id) {
    if (pendingDissolve !== id) {
      pendingDissolve = id
      dissolveTimer.restart()
      return
    }
    pendingDissolve = ""
    var index = selectedIndex
    bar.editGroups(function(config) { Model.remove(config, id) })
    var rest = groups.filter(function(g) { return g.id !== id })
    selectedId = rest.length ? rest[Math.max(0, Math.min(index, rest.length - 1))].id : ""
  }
  function select(delta) {
    if (!groups.length) return false
    var next = selectedIndex + delta
    if (next < 0 || next >= groups.length) return false
    selectedId = groups[next].id
    pendingDissolve = ""
    return true
  }
  onGroupsChanged: if (!selectedGroup && groups.length) selectedId = groups[0].id
  Component.onCompleted: if (!selectedGroup && groups.length) selectedId = groups[0].id
  Timer { id: dissolveTimer; interval: 3000; onTriggered: pane.pendingDissolve = "" }

  RowLayout {
    anchors.fill: parent
    spacing: Style.space(20)

    // ------------------------------------------------------------ group list
    ColumnLayout {
      Layout.preferredWidth: Style.space(260)
      Layout.minimumWidth: Style.space(220)
      Layout.maximumWidth: Style.space(260)
      Layout.fillWidth: false
      Layout.fillHeight: true
      spacing: Style.space(8)

      Item {
        id: groupList
        readonly property bool ownsFocusRing: true
        Layout.fillWidth: true
        Layout.fillHeight: true
        activeFocusOnTab: true
        Accessible.role: Accessible.List
        Accessible.name: "Groups"
        Keys.onPressed: function(event) {
          if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
          var key = event.key, t = event.text
          if (key === Qt.Key_Down || t === "j") pane.select(1)
          else if (key === Qt.Key_Up || t === "k") pane.select(-1)
          else if (t === "n") pane.create()
          else if ((t === "x" || key === Qt.Key_Delete) && pane.selectedId) pane.dissolve(pane.selectedId)
          else if ((key === Qt.Key_Return || key === Qt.Key_Enter || t === "l" || key === Qt.Key_Right) && pane.selectedGroup) nameField.forceActiveFocus()
          else return
          event.accepted = true
        }

        Controls.ScrollView {
          anchors.fill: parent
          contentWidth: availableWidth
          clip: true
          Column {
            width: parent.width
            spacing: Style.space(4)
            Repeater {
              model: pane.groups
              BorderSurface {
                id: groupRow
                required property var modelData
                required property int index
                readonly property bool current: modelData.id === pane.selectedId
                readonly property bool dissolving: pane.pendingDissolve === modelData.id
                width: parent.width
                height: rowContent.implicitHeight + Style.space(16)
                scale: rowMouse.pressed ? 0.98 : 1
                Behavior on scale { enabled: pane.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                radius: Style.cornerRadius
                color: dissolving ? Qt.alpha(Color.urgent, 0.16)
                  : current && groupList.activeFocus ? Style.focusFillFor(Color.popups.text, Color.accent)
                  : current ? Style.selectedFillFor(Color.popups.text, Color.accent)
                  : rowMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
                borderSpec: dissolving ? Border.flat(Color.urgent, 1)
                  : current && groupList.activeFocus ? Border.controlSpec("focus", Color.popups.text, Color.accent) : Border.none()
                RowLayout {
                  id: rowContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(10)
                  Text {
                    text: groupRow.modelData.icon
                    textFormat: Text.PlainText
                    color: Color.accent
                    font.family: Model.iconFont(groupRow.modelData.icon) || Style.font.family
                    font.pixelSize: Style.font.iconLarge
                    Layout.preferredWidth: Style.space(24)
                    horizontalAlignment: Text.AlignHCenter
                  }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(1)
                    Text {
                      text: groupRow.modelData.label
                      textFormat: Text.PlainText
                      color: Color.popups.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: groupRow.current
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                    Text {
                      text: groupRow.dissolving ? "Press x again to dissolve"
                        : groupRow.modelData.items.length + (groupRow.modelData.items.length === 1 ? " widget, " : " widgets, ")
                          + (groupRow.modelData.visibility === "hidden" ? "hidden"
                            : (groupRow.modelData.visibility === "managed" ? "in the " : "on the ")
                              + groupRow.modelData.section + (groupRow.modelData.visibility === "managed" ? " drawer" : ""))
                      textFormat: Text.PlainText
                      color: groupRow.dissolving ? Color.urgent : Qt.alpha(Color.popups.text, 0.55)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }
                }
                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { pane.selectedId = groupRow.modelData.id; groupList.forceActiveFocus(Qt.MouseFocusReason) }
                }
              }
            }
            Text {
              visible: pane.groups.length === 0
              width: parent.width
              topPadding: Style.space(8)
              text: "No groups yet. A group gathers related widgets behind one bar icon."
              textFormat: Text.PlainText
              color: Qt.alpha(Color.popups.text, 0.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }
        }
      }
      Button {
        Layout.fillWidth: true
        text: "New group"
        iconText: "󰐕"
        // Reached with n; Tab goes straight from the list to the editor.
        focusable: false
        bordered: true
        foreground: Color.popups.text
        onClicked: pane.create()
        RowLayout {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          KeyCap { text: "n" }
        }
      }
    }

    Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Qt.alpha(Color.popups.text, 0.1) }

    // ---------------------------------------------------------------- editor
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      Text {
        anchors.centerIn: parent
        visible: !pane.selectedGroup
        text: "Press n to make your first group."
        textFormat: Text.PlainText
        color: Qt.alpha(Color.popups.text, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      PrefsForm {
        id: form
        anchors.fill: parent
        visible: !!pane.selectedGroup
        maxContentWidth: Style.space(720)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(14)
          BarBackdrop {
            motionEnabled: !bar || bar.animationsEnabled
            Layout.preferredWidth: Style.space(64)
            Layout.preferredHeight: Style.space(56)
            source: pane.preferences.wallpaper
            position: pane.bar.position
            BorderSurface {
              anchors.centerIn: parent
              width: parent.width - Style.space(12)
              height: pane.bar.barSize
              radius: pane.bar.islandRounding
              color: pane.bar.mainSurfaceColor
              borderSpec: pane.bar.islandBorder
            }
            Text {
              anchors.centerIn: parent
              text: pane.selectedGroup ? (pane.selectedGroup.face === "text" ? pane.selectedGroup.label.slice(0, 2) : pane.selectedGroup.icon) : ""
              textFormat: Text.PlainText
              color: Color.popups.text
              font.family: pane.selectedGroup && pane.selectedGroup.face !== "text" ? Model.iconFont(pane.selectedGroup.icon) || Style.font.family : Style.font.family
              font.pixelSize: Style.font.iconLarge
            }
          }
          TextField {
            id: nameField
            Layout.fillWidth: true
            text: pane.selectedGroup ? pane.selectedGroup.label : ""
            placeholderText: "Group name"
            foreground: Color.popups.text
            font.pixelSize: Style.font.heading
            font.bold: true
            Accessible.name: "Group name"
            onEditingFinished: if (pane.selectedGroup && text.trim() && text.trim() !== pane.selectedGroup.label) pane.edit({ label: text })
            Keys.onEscapePressed: function(event) {
              text = pane.selectedGroup ? pane.selectedGroup.label : ""
              groupList.forceActiveFocus()
              event.accepted = true
            }
          }
        }

        PrefsSection {
          title: "Icon"
          IconGrid {
            Layout.fillWidth: true
            glyph: pane.selectedGroup ? pane.selectedGroup.icon : ""
            onChosen: function(glyph) { pane.edit({ icon: glyph }) }
          }
        }

        PrefsSection {
          title: "Placement"
          PrefsChoice {
            label: "Zone"
            options: [{ value: "left", label: "Left" }, { value: "center", label: "Center" }, { value: "right", label: "Right" }]
            value: pane.selectedGroup ? pane.selectedGroup.section : ""
            onChosen: function(value) { pane.edit({ section: value }) }
          }
          PrefsChoice {
            label: "Visibility"
            options: [{ value: "shown", label: "On the bar" }, { value: "managed", label: "On demand" }, { value: "hidden", label: "Hidden" }]
            value: pane.selectedGroup ? pane.selectedGroup.visibility : ""
            onChosen: function(value) { pane.edit({ visibility: value }) }
          }
        }

        PrefsSection {
          title: "On the bar"
          PrefsChoice {
            label: "Show"
            options: [{ value: "glyph", label: "Icon" }, { value: "text", label: "Name" }, { value: "both", label: "Both" }]
            value: pane.selectedGroup ? pane.selectedGroup.face : ""
            onChosen: function(value) { pane.edit({ face: value }) }
          }
          PrefsToggle {
            label: "Name on hover"
            description: "Show the group's name when the pointer rests on its icon"
            checked: pane.selectedGroup ? (pane.selectedGroup.tooltip === undefined ? pane.selectedGroup.face === "glyph" : pane.selectedGroup.tooltip) : false
            onToggled: function(checked) { pane.edit({ tooltip: checked }) }
          }
          PrefsToggle {
            label: "Badge"
            description: "A live count from the group's widgets, drawn on its icon"
            checked: pane.selectedGroup ? pane.selectedGroup.badge : false
            onToggled: function(checked) { pane.edit({ badge: checked }) }
          }
          PrefsChoice {
            visible: !!pane.selectedGroup && pane.selectedGroup.badge
            label: "Badge counts"
            options: [{ value: "sum", label: "Add up counts" }, { value: "members", label: "Count busy widgets" }]
            value: pane.selectedGroup ? pane.selectedGroup.badgeMode : ""
            onChosen: function(value) { pane.edit({ badgeMode: value }) }
          }
        }

        PrefsSection {
          title: "In the drawer"
          PrefsChoice {
            label: "Widgets show"
            description: pane.selectedGroup && pane.selectedGroup.memberDisplay !== "native" ? "Named widgets open as a vertical menu" : ""
            options: [{ value: "native", label: "Icon" }, { value: "name", label: "Name" }, { value: "both", label: "Both" }]
            value: pane.selectedGroup ? pane.selectedGroup.memberDisplay : ""
            onChosen: function(value) { pane.edit({ memberDisplay: value }) }
          }
        }

        PrefsSection {
          title: "Widgets"
          description: "Drag to reorder or move between the lists. Grouped widgets keep their own settings."
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(14)
            WidgetList {
              id: memberList
              title: "In this group"
              empty: "Add widgets from the list beside this one."
              items: pane.members
              reorderable: true
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.alignment: Qt.AlignTop
              onActivated: function(record) { memberList.liftCurrent() }
              onRemoved: function(record) { pane.bar.assignGroup(record.instanceKey, "", "") }
              onReordered: function(record, before) { pane.bar.assignGroup(record.instanceKey, pane.selectedId, before) }
              onReceived: function(record, before) { pane.bar.assignGroup(record.instanceKey, pane.selectedId, before) }
            }
            WidgetList {
              id: availableList
              title: "Available"
              empty: filter.text ? "No widgets match." : "Every widget is in a group."
              filterable: true
              items: pane.preferences.entries.filter(function(e) {
                if (e.groupId || (pane.selectedGroup && pane.selectedGroup.items.indexOf(e.instanceKey) >= 0)) return false
                var q = filter.text.trim().toLowerCase()
                return !q || pane.preferences.title(e).toLowerCase().indexOf(q) >= 0 || e.id.toLowerCase().indexOf(q) >= 0
              })
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              Layout.alignment: Qt.AlignTop
              onActivated: function(record) { pane.bar.assignGroup(record.instanceKey, pane.selectedId, "") }
              onReceived: function(record) { pane.bar.assignGroup(record.instanceKey, "", "") }
              TextField {
                id: filter
                parent: availableList.header
                width: parent ? parent.width : 0
                placeholderText: "Filter widgets"
                foreground: Color.popups.text
                verticalPadding: Style.space(5)
                Accessible.name: "Filter available widgets"
                Keys.onDownPressed: availableList.forceActiveFocus()
                Keys.onEscapePressed: function(event) {
                  if (text) text = ""
                  else availableList.forceActiveFocus()
                  event.accepted = true
                }
              }
              onFilterRequested: filter.forceActiveFocus()
            }
          }
        }

        PrefsSection {
          visible: !!memberList.current
          title: memberList.current ? "Badge for " + pane.preferences.title(memberList.current) : ""
          description: "Values are read from the live widget. Name a property to read, or type none to leave it out."
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)
            ColumnLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.space(4)
              Text { text: "Count property"; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
            TextField {
              Layout.fillWidth: true
              text: memberList.current ? memberList.current.badgeProperty || "" : ""
              placeholderText: "Detected automatically"
              foreground: Color.popups.text
              Accessible.name: "Badge count property"
              onEditingFinished: if (memberList.current) pane.bar.editMemberBadge(memberList.current.instanceKey, "badgeProperty", text.trim())
            }
            }
            ColumnLayout {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: Style.space(4)
              Text { text: "Urgent property"; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall; font.bold: true }
            TextField {
              Layout.fillWidth: true
              text: memberList.current ? memberList.current.urgentProperty || "" : ""
              placeholderText: "Detected automatically"
              foreground: Color.popups.text
              Accessible.name: "Urgent property"
              onEditingFinished: if (memberList.current) pane.bar.editMemberBadge(memberList.current.instanceKey, "urgentProperty", text.trim())
            }
            }
          }
        }

        PrefsSection {
          title: "Dissolve group"
          description: "Its widgets return to the places they had before they were grouped."
          Button {
            text: pane.pendingDissolve === pane.selectedId ? "Press again to dissolve" : "Dissolve " + (pane.selectedGroup ? pane.selectedGroup.label : "")
            iconText: "󰆴"
            focusable: true
            bordered: true
            foreground: pane.pendingDissolve === pane.selectedId ? Color.urgent : Color.popups.text
            onClicked: pane.dissolve(pane.selectedId)
          }
        }
      }
    }
  }

  // The dragged widget follows the pointer between the two lists.
  BorderSurface {
    id: ghost
    property var record: null
    visible: !!record
    z: 100
    width: ghostIcon.width + ghostText.implicitWidth + Style.space(28)
    height: Style.spacing.controlHeight
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.flat(Color.accent, Math.max(1, Style.space(2)))
    opacity: 0.92
    WidgetIcon {
      id: ghostIcon
      x: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      preferences: pane.preferences
      record: ghost.record || ({})
      size: Math.round(pane.bar.themeBarSize * 0.8)
    }
    Text {
      id: ghostText
      anchors.left: ghostIcon.right
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: ghost.record ? pane.preferences.title(ghost.record) : ""
      textFormat: Text.PlainText
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  // A focusable list of widgets. j/k choose (and hand focus on at either end),
  // Space lifts for keyboard reordering when reorderable, x removes, Enter
  // activates. Rows can be dragged within a list and across to the other one.
  component WidgetList: ColumnLayout {
    id: list
    readonly property bool ownsFocusRing: true
    property string title: ""
    property string empty: ""
    property var items: []
    property bool reorderable: false
    property bool filterable: false
    property int cursor: 0
    property var lifted: null
    property int liftPos: 0
    property int dropPos: -1
    readonly property alias header: headerSlot
    readonly property var current: activeFocus || lifted ? (lifted || items[cursor] || null) : null
    readonly property var display: {
      var rows = items.filter(function(r) { return !list.lifted || r.instanceKey !== list.lifted.instanceKey })
        .map(function(r) { return { record: r, placeholder: false } })
      if (lifted) rows.splice(Math.min(liftPos, rows.length), 0, { record: lifted, placeholder: true })
      else if (dropPos >= 0 && ghost.record) rows.splice(Math.min(dropPos, rows.length), 0, { record: ghost.record, placeholder: true })
      return rows
    }
    signal activated(var record)
    signal removed(var record)
    signal reordered(var record, string before)
    signal received(var record, string before)
    signal filterRequested()
    spacing: Style.space(8)
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: title
    onItemsChanged: cursor = Math.max(0, Math.min(cursor, items.length - 1))
    onActiveFocusChanged: if (!activeFocus && lifted) lifted = null

    function recordKey(record) { return record ? record.instanceKey || record.section + ":" + record.index : "" }
    function liftCurrent() {
      if (!reorderable || !items[cursor]) return
      lifted = items[cursor]
      liftPos = cursor
    }
    function beforeKey(pos, excludeKey) {
      var rest = items.filter(function(r) { return r.instanceKey !== excludeKey })
      return rest[pos] ? rest[pos].instanceKey : ""
    }
    function dropLifted() {
      var record = lifted, pos = liftPos
      lifted = null
      if (pos !== cursor) reordered(record, beforeKey(pos, record.instanceKey))
      cursor = pos
    }
    function gapAt(point) {
      var pos = 0
      for (var i = 0; i < rowRepeater.count; i++) {
        var row = rowRepeater.itemAt(i)
        if (!row || row.placeholder) continue
        if (row.mapFromItem(pane, point.x, point.y).y < row.height / 2) return pos
        pos++
      }
      return pos
    }
    function rowAt(point) {
      for (var i = 0; i < rowRepeater.count; i++) {
        var row = rowRepeater.itemAt(i)
        if (!row || row.placeholder) continue
        var p = row.mapFromItem(pane, point.x, point.y)
        if (p.x >= 0 && p.y >= 0 && p.x < row.width && p.y < row.height) return row
      }
      return null
    }
    function contains(point) {
      var p = frame.mapFromItem(pane, point.x, point.y)
      return p.x >= 0 && p.y >= 0 && p.x < frame.width && p.y < frame.height
    }

    Keys.onPressed: function(event) {
      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
      var key = event.key, t = event.text
      if (key === Qt.Key_Down || t === "j") {
        if (lifted) liftPos = Math.min(items.length - 1, liftPos + 1)
        else if (cursor < items.length - 1) cursor++
        else return
      } else if (key === Qt.Key_Up || t === "k") {
        if (lifted) liftPos = Math.max(0, liftPos - 1)
        else if (cursor > 0) cursor--
        else return
      } else if (key === Qt.Key_Space && reorderable) {
        if (lifted) dropLifted()
        else liftCurrent()
      } else if (key === Qt.Key_Return || key === Qt.Key_Enter || (key === Qt.Key_Space && !reorderable)) {
        if (lifted) dropLifted()
        else if (items[cursor]) activated(items[cursor])
      } else if (key === Qt.Key_Escape && lifted) lifted = null
      else if ((t === "x" || key === Qt.Key_Delete) && reorderable && !lifted && items[cursor]) removed(items[cursor])
      else if (t === "/" && filterable) filterRequested()
      else return
      event.accepted = true
    }

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: list.title
        textFormat: Text.PlainText
        color: list.activeFocus ? Color.popups.text : Qt.alpha(Color.popups.text, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        Layout.fillWidth: true
      }
      Text {
        text: list.items.length
        textFormat: Text.PlainText
        color: Qt.alpha(Color.popups.text, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    Item {
      id: headerSlot
      visible: list.filterable
      Layout.fillWidth: true
      implicitHeight: children.length ? children[0].implicitHeight : 0
    }
    BorderSurface {
      id: frame
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(300)
      radius: Math.max(Style.cornerRadius, Style.space(6))
      color: Qt.alpha(Color.popups.text, 0.03)
      borderSpec: list.dropPos >= 0 ? Border.flat(Qt.alpha(Color.accent, 0.8), 1) : Border.flat(Qt.alpha(Color.popups.text, 0.1), 1)
      Controls.ScrollView {
        id: scroller
        anchors.fill: parent
        anchors.margins: Style.space(6)
        contentWidth: availableWidth
        clip: true
        Column {
          width: parent.width
          spacing: Style.space(3)
          RetainedList {
            id: rowList
            recordProperty: "retainedRecord"
            records: list.display.map(function(value, index) {
              return { key: value.placeholder ? "insertion-gap" : value.record.instanceKey || "row:" + index,
                entry: value.record, placeholder: value.placeholder }
            })
            factory: Component {
            BorderSurface {
              id: row
              required property var retainedRecord
              readonly property var record: retainedRecord.entry
              readonly property bool placeholder: retainedRecord.placeholder
              readonly property bool isCursor: !list.lifted && list.activeFocus && list.recordKey(list.items[list.cursor]) === list.recordKey(record)
              width: parent.width
              height: Style.spacing.controlHeight + Style.space(2)
              scale: !placeholder && listPointer.pressed && !ghost.record && list.recordKey(listPointer.pressedRecord) === list.recordKey(record) ? 0.98 : 1
              Behavior on scale { enabled: pane.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              radius: Math.max(0, Style.cornerRadius - Style.space(2))
              color: placeholder ? Qt.alpha(Color.accent, 0.16)
                : isCursor ? Style.focusFillFor(Color.popups.text, Color.accent)
                : rowHover.hovered ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
              borderSpec: placeholder ? Border.flat(Color.accent, Math.max(1, Style.space(2)))
                : isCursor ? Border.controlSpec("focus", Color.popups.text, Color.accent) : Border.none()
              onIsCursorChanged: if (isCursor) {
                var view = scroller.contentItem
                if (y < view.contentY) view.contentY = y
                else if (y + height > view.contentY + view.height) view.contentY = y + height - view.height
              }
              HoverHandler { id: rowHover }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                WidgetIcon {
                  preferences: pane.preferences
                  record: row.record
                  size: Math.round(pane.bar.themeBarSize * 0.8)
                  Layout.preferredWidth: Math.max(Style.space(20), implicitWidth)
                }
                Text {
                  text: row.record.label || pane.preferences.title(row.record)
                  textFormat: Text.PlainText
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  visible: row.isCursor || rowHover.hovered
                  text: list.reorderable ? "󰆴" : "󰐕"
                  textFormat: Text.PlainText
                  color: Qt.alpha(Color.popups.text, 0.6)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.icon
                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.reorderable ? list.removed(row.record) : list.activated(row.record)
                  }
                }
              }
            }
            }
          }
          Repeater { id: rowRepeater; model: rowList.model }
        }
      }
      Text {
        anchors.centerIn: parent
        width: parent.width - Style.space(32)
        visible: list.items.length === 0 && list.dropPos < 0
        text: list.empty
        textFormat: Text.PlainText
        color: Qt.alpha(Color.popups.text, 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
      // Pointer drags start here and may end over either list.
      MouseArea {
        anchors.fill: parent
        anchors.rightMargin: Style.space(28)
        id: listPointer
        preventStealing: true
        property var pressedRecord: null
        property point origin
        cursorShape: ghost.record ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: function(mouse) {
          var point = mapToItem(pane, mouse.x, mouse.y)
          var row = list.rowAt(point)
          list.forceActiveFocus(Qt.MouseFocusReason)
          pressedRecord = row ? row.record : null
          origin = point
          if (row) list.cursor = list.items.findIndex(function(item) { return list.recordKey(item) === list.recordKey(row.record) })
        }
        onPositionChanged: function(mouse) {
          var point = mapToItem(pane, mouse.x, mouse.y)
          if (pressedRecord && !ghost.record && Math.abs(point.x - origin.x) + Math.abs(point.y - origin.y) > Style.space(6))
            ghost.record = pressedRecord
          if (!ghost.record) return
          ghost.x = point.x - ghost.width / 2
          ghost.y = point.y - ghost.height / 2
          memberList.dropPos = memberList.contains(point) ? memberList.gapAt(point) : -1
          availableList.dropPos = availableList.contains(point) ? availableList.gapAt(point) : -1
        }
        onReleased: {
          var record = ghost.record
          ghost.record = null
          var toMembers = memberList.dropPos >= 0, toAvailable = availableList.dropPos >= 0
          var pos = memberList.dropPos
          memberList.dropPos = -1
          availableList.dropPos = -1
          pressedRecord = null
          if (!record) return
          if (toMembers) {
            var key = memberList.beforeKey(pos, record.instanceKey)
            if (list === memberList) memberList.reordered(record, key)
            else memberList.received(record, key)
          } else if (toAvailable && list === memberList) availableList.received(record, "")
        }
        onCanceled: {
          ghost.record = null
          memberList.dropPos = -1
          availableList.dropPos = -1
          pressedRecord = null
        }
        onDoubleClicked: if (list.items[list.cursor]) (list.reorderable ? list.removed(list.items[list.cursor]) : list.activated(list.items[list.cursor]))
      }
    }
  }
}
