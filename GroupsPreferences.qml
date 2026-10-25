import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "GroupsModel.js" as Model
import "CellModel.js" as CellModel
import "ShelfModel.js" as ShelfModel
import "ManagedModel.js" as ManagedModel

// Groups as tiles (docs/behavior/preferences.md): a shelf of your groups drawn as the
// bar draws them, the selected group's settings, then its drawer drawn exactly
// as it opens beside the widgets not in a group. The two lower tiles are
// halves of one row and mirror each other: a row of controls, a well, a line
// under it.
//
// Keyboard: the shelf is one Tab stop (h/l choose, n new group, x twice
// dissolves, Enter goes to the icon); the drawer is one (j/k choose, Space
// lifts to reorder, x removes); the list is one (j/k choose, Enter adds,
// typing filters). Tab jumps tiles, j/k walk the page at their edges.
Item {
  id: pane
  required property var preferences
  // Layout's editor: how the bar draws each widget (barFace) and its tokens.
  required property var layout
  // Bento columns for the window (12, 6 or 1), set by Preferences.
  property int columns: 12
  readonly property var bar: preferences.bar
  readonly property var groups: bar.groups
  property string selectedId: ""
  property string pendingDissolve: ""
  readonly property var selectedGroup: groups.find(function(g) { return g.id === selectedId }) || null
  readonly property int selectedIndex: groups.findIndex(function(g) { return g.id === selectedId })
  // Members whose widget was uninstalled have already left the group (GroupsModel).
  readonly property var members: selectedGroup ? selectedGroup.items.map(function(key) {
    return preferences.entries.find(function(e) { return e.instanceKey === key }) || null
  }).filter(function(m) { return !!m }) : []
  readonly property var zoneNames: layout.zoneNames
  readonly property var hints: picker.opened ? picker.hints
    : shelfFocus.activeFocus ? [
      { keys: "h l", label: "Choose" }, { keys: "n", label: "New group" },
      { keys: "x", label: pendingDissolve && pendingDissolve === selectedId ? "Again to dissolve" : "Dissolve" },
      { keys: "enter", label: "Edit" }, { keys: "tab shift+tab", label: "Next, previous tile" }, { keys: "1-3", label: "Pages" }, { keys: "esc", label: "Close" }]
    : drawerFocus.activeFocus ? (drawerFocus.lifted ? [
      { keys: "j k", label: "Reorder" }, { keys: "space", label: "Drop" }, { keys: "esc", label: "Cancel" }] : [
      { keys: "j k", label: "Choose" }, { keys: "space", label: "Pick up" }, { keys: "x", label: "Remove" },
      { keys: "tab shift+tab", label: "Next, previous tile" }, { keys: "esc", label: "Close" }])
    : availFocus.activeFocus ? [
      { keys: "j k", label: "Choose" }, { keys: "enter", label: "Add to " + (selectedGroup ? selectedGroup.label : "group") },
      { keys: "type", label: "Filter" }, { keys: "tab shift+tab", label: "Next, previous tile" }, { keys: "esc", label: "Close" }]
    : form.hints

  function focusFirst() { shelfFocus.forceActiveFocus(Qt.TabFocusReason) }
  function edit(patch) {
    var id = selectedId
    if (id) bar.editGroups(function(config) { Model.edit(config, id, patch) })
  }
  function create() {
    var id = "g-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7)
    bar.editGroups(function(config) { Model.create(config, id, "New group") })
    selectedId = id
    pendingDissolve = ""
    Qt.callLater(function() { nameField.forceActiveFocus(); nameField.selectAll() })
  }
  function dissolve() {
    var id = selectedId
    if (!id) return
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
    var next = selectedIndex + delta
    if (next < 0 || next >= groups.length) return false
    selectedId = groups[next].id
    pendingDissolve = ""
    drawerFocus.cursor = 0
    return true
  }
  onGroupsChanged: if (!selectedGroup && groups.length) selectedId = groups[0].id
  Component.onCompleted: if (!selectedGroup && groups.length) selectedId = groups[0].id
  Timer { id: dissolveTimer; interval: 3000; onTriggered: pane.pendingDissolve = "" }

  // How the bar draws things, at the size it has on a top edge.
  readonly property var tokens: layout.barTokens
  readonly property var menuTokens: bar ? bar.menuTokensFor(false) : tokens
  readonly property real barThickness: layout.barThickness
  readonly property color barInk: layout.barInk
  readonly property string barFont: layout.barFont
  readonly property color menuSurface: bar ? Qt.rgba(bar.overlaySurfaceColor.r, bar.overlaySurfaceColor.g, bar.overlaySurfaceColor.b, 1) : Commons.Color.popups.background
  readonly property real surfaceRadius: bar ? Math.min(bar.islandRounding, barThickness / 2) : 0
  readonly property var surfaceBorder: bar && bar.islands ? bar.islandBorder : Border.none()
  readonly property real wellRadius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2))
  // The rows of the two lower tiles, the same height in both.
  readonly property real controlRow: Style.spacing.controlHeight + Style.space(8)
  readonly property real noteRow: Style.spacing.controlHeight

  PrefsForm {
    id: form
    anchors.fill: parent
    maxContentWidth: Style.space(1180)

    PrefsBento {
      id: bento
      Layout.fillWidth: true
      columns: pane.columns
      gap: pane.preferences.tileGap

      // ------------------------------------------------------- the shelf
      PrefsTile {
        id: shelfTile
        title: "Groups"
        caption: pane.columns > 1 ? "Your groups as the bar draws them" : ""
        span12: 12
        span6: 6
        animate: pane.bar.animationsEnabled
        borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, shelfFocus.activeFocus ? 0.28 : 0.1), 1)

        Item {
          id: shelfFocus
          readonly property bool ownsFocusRing: true
          Layout.fillWidth: true
          Layout.leftMargin: Math.round(Style.spacing.rowPaddingX / 2)
          Layout.rightMargin: Math.round(Style.spacing.rowPaddingX / 2)
          Layout.bottomMargin: Math.round(Style.spacing.rowPaddingX / 2)
          implicitHeight: shelfColumn.implicitHeight
          activeFocusOnTab: true
          Accessible.role: Accessible.List
          Accessible.name: "Groups"
          Accessible.description: pane.selectedGroup ? pane.selectedGroup.label : "No groups yet"
          Keys.onPressed: function(event) {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
            var key = event.key, t = event.text
            if (key === Qt.Key_Right || t === "l") pane.select(1)
            else if (key === Qt.Key_Left || t === "h") pane.select(-1)
            else if (t === "n") pane.create()
            else if ((t === "x" || key === Qt.Key_Delete) && pane.selectedId) pane.dissolve()
            else if ((key === Qt.Key_Return || key === Qt.Key_Enter) && pane.selectedGroup) iconWell.forceActiveFocus(Qt.TabFocusReason)
            else if (key === Qt.Key_Down || t === "j") form.step(true)
            else return
            event.accepted = true
          }

          ColumnLayout {
            id: shelfColumn
            width: parent.width
            spacing: Style.space(6)
            Flow {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Repeater {
                model: pane.groups
                GroupCard {
                  required property var modelData
                  group: modelData
                }
              }
              // A new group ends the shelf.
              BorderSurface {
                width: newLabel.implicitWidth + Style.space(28)
                height: pane.barThickness + Style.space(8)
                radius: pane.wellRadius
                color: newMouse.containsMouse ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
                borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.3), 1)
                Row {
                  id: newLabel
                  anchors.centerIn: parent
                  spacing: Style.space(8)
                  Text {
                    text: "+ New group"
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.8)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  KeyCap { text: "n"; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                  id: newMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: pane.create()
                }
              }
            }
            Text {
              visible: pane.groups.length === 0
              Layout.fillWidth: true
              Layout.leftMargin: Math.round(Style.spacing.rowPaddingX / 2)
              text: "No groups yet. A group gathers related widgets behind one icon on the bar. Press n to make your first."
              textFormat: Text.PlainText
              color: Qt.alpha(Commons.Color.popups.text, 0.65)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }
        }
      }

      // ------------------------------------------------ the selected group
      PrefsTile {
        id: groupTile
        visible: !!pane.selectedGroup
        title: pane.selectedGroup ? pane.selectedGroup.label : ""
        caption: !pane.selectedGroup ? "" : pane.members.length + (pane.members.length === 1 ? " widget" : " widgets")
          + ", " + ({ shown: "on the bar", managed: "on demand", hidden: "hidden" })[pane.selectedGroup.visibility]
          + (pane.selectedGroup.visibility === "hidden" ? "" : " at " + String(pane.zoneNames[pane.selectedGroup.section]).toLowerCase())
        span12: 12
        span6: 6
        animate: pane.bar.animationsEnabled
        actionText: "Dissolve"
        actionKey: "x"
        actionConfirming: pane.pendingDissolve !== "" && pane.pendingDissolve === pane.selectedId
        onAction: pane.dissolve()

        // Three columns whose rows line up: who it is and how it shows,
        // where it is, its badge.
        GridLayout {
          id: settingsGrid
          Layout.fillWidth: true
          Layout.bottomMargin: Style.space(4)
          // Filled column by column, so one column reads in the same order.
          columns: pane.columns === 1 ? 1 : 3
          rows: pane.columns === 1 ? 9 : 3
          flow: GridLayout.TopToBottom
          columnSpacing: Style.space(16)
          rowSpacing: 0
          // From the tile, not the grid: the cells' widths set the grid's.
          readonly property real columnWidth: (groupTile.width - 2 * groupTile.inset - columnSpacing * (columns - 1)) / columns
          // Chips beside their label when the column has room, else under it.
          readonly property bool roomy: columnWidth >= Style.space(330)
          // Every row is as tall as the icon well, the bar's own height.
          readonly property real rowHeight: Math.max(pane.barThickness, roomy ? pane.controlRow : pane.controlRow * 1.7)
          // Esc returns to the shelf; an open dropdown or field takes it first.
          Keys.onPressed: function(event) {
            if (event.key !== Qt.Key_Escape) return
            shelfFocus.forceActiveFocus(Qt.OtherFocusReason)
            event.accepted = true
          }

          // Column 1: the icon and name, Show, Name on hover
          RowLayout {
            Layout.preferredWidth: settingsGrid.columnWidth - Layout.leftMargin - Layout.rightMargin
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            Layout.preferredHeight: settingsGrid.rowHeight
            Layout.leftMargin: Style.spacing.rowPaddingX
            Layout.rightMargin: Style.spacing.rowPaddingX
            spacing: Style.space(8)
            IconWell {
              id: iconWell
              group: pane.selectedGroup
            }
            TextField {
              id: nameField
              Layout.fillWidth: true
              text: pane.selectedGroup ? pane.selectedGroup.label : ""
              placeholderText: "Group name"
              foreground: Commons.Color.popups.text
              font.bold: true
              Accessible.name: "Group name"
              onEditingFinished: if (pane.selectedGroup && text.trim() && text.trim() !== pane.selectedGroup.label) pane.edit({ label: text })
              Keys.onEscapePressed: function(event) {
                text = pane.selectedGroup ? pane.selectedGroup.label : ""
                shelfFocus.forceActiveFocus()
                event.accepted = true
              }
            }
          }
          Cell {
            PrefsChoice {
              compact: true
              Layout.alignment: Qt.AlignVCenter
              stacked: !settingsGrid.roomy
              label: "Show"
              options: [{ value: "glyph", label: "Icon" }, { value: "text", label: "Name" }, { value: "both", label: "Both" }]
              value: pane.selectedGroup ? pane.selectedGroup.face : ""
              onChosen: function(value) { pane.edit({ face: value }) }
            }
          }
          Cell {
            PrefsToggle {
              compact: true
              Layout.alignment: Qt.AlignVCenter
              label: "Name on hover"
              checked: pane.selectedGroup ? (pane.selectedGroup.tooltip === undefined ? pane.selectedGroup.face === "glyph" : pane.selectedGroup.tooltip) : false
              onToggled: function(checked) { pane.edit({ tooltip: checked }) }
            }
          }
          // Column 2: Zone, Visibility and what it means
          Cell {
            PrefsZoneMap {
              compact: true
              Layout.alignment: Qt.AlignVCenter
              stacked: !settingsGrid.roomy
              zones: pane.layout ? pane.layout.zoneChoices : []
              cameraOver: pane.layout && pane.layout.previewCamera ? "center" : ""
              noteFor: function(zone) { return pane.layout ? pane.layout.cameraNote(zone) : "" }
              value: pane.selectedGroup ? pane.selectedGroup.section : ""
              onChosen: function(value) { pane.edit({ section: value }) }
            }
          }
          Cell {
            PrefsChoice {
              compact: true
              Layout.alignment: Qt.AlignVCenter
              stacked: !settingsGrid.roomy
              label: "Visibility"
              options: [{ value: "shown", label: "On the bar" }, { value: "managed", label: "On demand" }, { value: "hidden", label: "Hidden" }]
              value: pane.selectedGroup ? pane.selectedGroup.visibility : ""
              onChosen: function(value) { pane.edit({ visibility: value }) }
            }
          }
          Cell {
            Hint {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              Layout.leftMargin: Style.spacing.rowPaddingX
              Layout.rightMargin: Style.spacing.rowPaddingX
              text: !pane.selectedGroup ? ""
                : pane.selectedGroup.visibility === "shown" ? "Its icon stays on the bar; the drawer opens on hover or click"
                : pane.selectedGroup.visibility === "managed" ? (pane.bar.onDemandInline ? "Behind the zone's dots until you hover them, or on activity"
                  : pane.bar.onDemandMenu ? "A row in the zone's menu; its widgets open beside it"
                  : "In the zone's drawer until you hover it, or on activity")
                : "Kept off the bar, with its widgets"
            }
          }
          // Column 3: Badge, Counts and what it counts
          Cell {
            PrefsToggle {
              compact: true
              Layout.alignment: Qt.AlignVCenter
              label: "Badge"
              checked: pane.selectedGroup ? pane.selectedGroup.badge : false
              onToggled: function(checked) { pane.edit({ badge: checked }) }
            }
          }
          Cell {
            PrefsChoice {
              compact: true
              Layout.alignment: Qt.AlignVCenter
              stacked: !settingsGrid.roomy
              enabled: !!pane.selectedGroup && pane.selectedGroup.badge
              opacity: enabled ? 1 : 0.45
              label: "Counts"
              options: [{ value: "sum", label: "Add up" }, { value: "members", label: "Busy widgets" }]
              value: pane.selectedGroup ? pane.selectedGroup.badgeMode : ""
              onChosen: function(value) { pane.edit({ badgeMode: value }) }
            }
          }
          Cell {
            Hint {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              Layout.leftMargin: Style.spacing.rowPaddingX
              Layout.rightMargin: Style.spacing.rowPaddingX
              dim: !pane.selectedGroup || !pane.selectedGroup.badge
              text: !pane.selectedGroup ? "" : !pane.selectedGroup.badge ? "Turn on the badge to count"
                : pane.selectedGroup.badgeMode === "sum" ? "The members' counts added together"
                : "How many members have something to show"
            }
          }
        }
        // The shortcut that opens its drawer, and what it means.
        RowLayout {
          Layout.fillWidth: true
          Layout.bottomMargin: Style.space(4)
          spacing: settingsGrid.columnSpacing
          ShortcutRow {
            id: shortcutRow
            Layout.fillWidth: false
            Layout.preferredWidth: settingsGrid.columnWidth
            store: pane.preferences.shortcuts
            target: pane.selectedGroup ? "group:" + pane.selectedGroup.id : ""
            unavailable: pane.selectedGroup && pane.selectedGroup.visibility === "hidden" ? "Hidden groups can't open" : ""
          }
          Hint {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: Style.spacing.rowPaddingX
            Layout.rightMargin: Style.spacing.rowPaddingX
            text: shortcutRow.message || (!pane.selectedGroup ? ""
              : shortcutRow.unavailable ? "Put it on the bar or on demand to give it a shortcut"
              : "Opens " + pane.selectedGroup.label + "'s drawer from anywhere, ready for the arrow keys")
          }
        }
      }

      // ---------------------------------------------------- the drawer
      PrefsTile {
        id: drawerTile
        visible: !!pane.selectedGroup
        title: "In the drawer"
        span12: 6
        span6: 3
        animate: pane.bar.animationsEnabled
        borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, drawerFocus.activeFocus ? 0.28 : 0.1), 1)

        // In the header, mirroring the filter in the tile beside it.
        Row {
          parent: drawerTile.headerSlot
          spacing: Style.space(8)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Widgets show"
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          ButtonGroup {
            anchors.verticalCenter: parent.verticalCenter
            options: [{ value: "native", label: "Icon" }, { value: "name", label: "Name" }, { value: "both", label: "Both" }]
            value: pane.selectedGroup ? pane.selectedGroup.memberDisplay : ""
            foreground: Commons.Color.popups.text
            background: "transparent"
            fontSize: Style.font.caption
            Accessible.name: "Widgets in the drawer show"
            onChanged: function(value) { pane.edit({ memberDisplay: value }) }
          }
        }
        DrawerWell { id: drawerFocus }
        // The selected member's badge source.
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: pane.noteRow
          Layout.leftMargin: Style.spacing.rowPaddingX
          Layout.rightMargin: Style.spacing.rowPaddingX
          spacing: Style.space(8)
          readonly property var member: drawerFocus.current
          Hint {
            Layout.fillWidth: true
            Layout.preferredWidth: 3
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            text: !parent.member ? "Pick a widget to set where its badge count comes from"
              : "Badge from " + pane.preferences.title(parent.member)
          }
          TextField {
            visible: !!parent.member
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            text: parent.member ? parent.member.badgeProperty || "" : ""
            placeholderText: "Count: detected"
            foreground: Commons.Color.popups.text
            font.pixelSize: Style.font.caption
            verticalPadding: Style.space(3)
            Accessible.name: "Badge count property"
            onEditingFinished: if (parent.member) pane.bar.editMemberBadge(parent.member.instanceKey, "badgeProperty", text.trim())
          }
          TextField {
            visible: !!parent.member
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            text: parent.member ? parent.member.urgentProperty || "" : ""
            placeholderText: "Urgent: detected"
            foreground: Commons.Color.popups.text
            font.pixelSize: Style.font.caption
            verticalPadding: Style.space(3)
            Accessible.name: "Urgent property"
            onEditingFinished: if (parent.member) pane.bar.editMemberBadge(parent.member.instanceKey, "urgentProperty", text.trim())
          }
        }
      }

      // --------------------------------------------- not in a group
      PrefsTile {
        id: availTile
        visible: !!pane.selectedGroup
        title: "Not in a group"
        span12: 6
        span6: 3
        animate: pane.bar.animationsEnabled
        borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, availFocus.activeFocus ? 0.28 : 0.1), 1)

        // In the header, mirroring Widgets show in the tile beside it.
        Item {
          parent: availTile.headerSlot
          implicitWidth: Math.min(Style.space(260), availTile.width * 0.5)
          implicitHeight: filter.implicitHeight
          TextField {
            id: filter
            anchors.fill: parent
            verticalPadding: Style.space(3)
            font.pixelSize: Style.font.caption
            placeholderText: "Filter " + availFocus.count + (availFocus.count === 1 ? " widget" : " widgets")
            foreground: Commons.Color.popups.text
            Accessible.name: "Filter widgets"
            Keys.onDownPressed: availFocus.forceActiveFocus()
            Keys.onEscapePressed: function(event) {
              if (text) text = ""
              else availFocus.forceActiveFocus()
              event.accepted = true
            }
          }
        }
        AvailWell { id: availFocus }
        Hint {
          Layout.fillWidth: true
          Layout.preferredHeight: pane.noteRow
          Layout.leftMargin: Style.spacing.rowPaddingX
          Layout.rightMargin: Style.spacing.rowPaddingX
          verticalAlignment: Text.AlignVCenter
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
          text: pane.selectedGroup ? "Enter or a click adds a widget to " + pane.selectedGroup.label + "; drag to place it in the drawer" : ""
        }
      }
    }
  }

  IconPicker {
    id: picker
    anchors.fill: parent
    z: 50
    preferences: pane.preferences
    onChosen: function(patch) {
      pane.edit(patch)
      picker.close()
    }
    onClosed: iconWell.forceActiveFocus(Qt.OtherFocusReason)
  }
  // The picker belongs to this page while Preferences shows it: closing
  // Preferences or leaving the page closes it, so it never comes back open
  // with its keys in the footer and the focus elsewhere.
  Connections {
    target: pane.preferences
    function onOpenedChanged() { if (!pane.preferences.opened) picker.close() }
    function onPageChanged() { if (pane.preferences.page !== 1) picker.close() }
  }

  // The widget being dragged between the drawer and the list.
  BorderSurface {
    id: ghost
    property var record: null
    property string from: ""
    visible: !!record
    z: 100
    width: ghostRow.implicitWidth + Style.space(18)
    height: Style.spacing.controlHeight
    radius: pane.wellRadius
    color: Commons.Color.popups.background
    borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.45), 1)
    opacity: 0.95
    Row {
      id: ghostRow
      anchors.centerIn: parent
      spacing: Style.space(6)
      WidgetIcon {
        preferences: pane.preferences
        record: ghost.record || ({})
        size: Math.round(pane.layout.iconSize * 0.85)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: ghost.record ? pane.preferences.title(ghost.record) : ""
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
  // One drag for both wells: a press past a few pixels lifts the widget; the
  // drawer previews where it lands; release drops it there, or returns a
  // member to the bar when it lands on the list.
  function dragMove(point) {
    ghost.x = point.x - ghost.width / 2
    ghost.y = point.y - ghost.height / 2
    drawerFocus.dropPos = drawerFocus.contains(point) ? drawerFocus.gapAt(point) : -1
    availFocus.targeted = ghost.from === "drawer" && availFocus.contains(point)
  }
  function dragEnd(commit) {
    var record = ghost.record, from = ghost.from, pos = drawerFocus.dropPos, toList = availFocus.targeted
    ghost.record = null
    drawerFocus.dropPos = -1
    availFocus.targeted = false
    if (!commit || !record || !selectedGroup) return
    if (pos >= 0) {
      var rest = selectedGroup.items.filter(function(k) { return k !== record.instanceKey })
      bar.assignGroup(record.instanceKey, selectedId, rest[pos] || "")
    } else if (toList && from === "drawer") bar.assignGroup(record.instanceKey, "", "")
  }

  // ------------------------------------------------------------ components
  // One cell of the settings grid: every cell in a row is the row's height,
  // its control centred in it, so the three columns line up row by row.
  component Cell: ColumnLayout {
    Layout.preferredWidth: settingsGrid.columnWidth
    Layout.minimumWidth: settingsGrid.columnWidth
    Layout.maximumWidth: settingsGrid.columnWidth
    Layout.preferredHeight: settingsGrid.rowHeight
    Layout.alignment: Qt.AlignTop
    spacing: 0
  }

  component Hint: Text {
    property bool dim: false
    textFormat: Text.PlainText
    color: Qt.alpha(Commons.Color.popups.text, dim ? 0.35 : 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  // A group on the shelf: its face as the bar draws it, on an island of the
  // bar's surface, with its name and count beside it.
  component GroupCard: BorderSurface {
    id: card
    property var group: null
    readonly property bool current: !!group && group.id === pane.selectedId
    readonly property bool dissolving: current && pane.pendingDissolve === group.id
    readonly property var face: group ? pane.layout.groupFace(group, "") : null
    readonly property var placed: face ? CellModel.place(pane.tokens, face.inkLength, face.glyph, true) : null
    readonly property real endPad: placed ? CellModel.endPad(pane.tokens, placed.spill) : 0
    readonly property int count: group ? group.items.filter(function(k) { return pane.preferences.entries.some(function(e) { return e.instanceKey === k }) }).length : 0
    width: cardRow.implicitWidth + Style.space(4) + Style.space(14)
    height: pane.barThickness + Style.space(8)
    radius: pane.wellRadius
    color: dissolving ? Qt.alpha(Commons.Color.urgent, 0.16)
      : current && shelfFocus.activeFocus ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)
      : current ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent)
      : cardMouse.containsMouse ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
    borderSpec: dissolving ? Border.flat(Commons.Color.urgent, 1)
      : current && shelfFocus.activeFocus ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
    Behavior on color { enabled: pane.bar.animationsEnabled; ColorAnimation { duration: 90 } }
    Row {
      id: cardRow
      x: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(10)
      BorderSurface {
        width: card.placed ? card.placed.extent + card.endPad * 2 : 0
        height: pane.barThickness
        color: pane.layout.barSurface
        radius: pane.surfaceRadius
        borderSpec: pane.surfaceBorder
        opacity: card.group && card.group.visibility === "hidden" ? 0.55 : 1
        BarFace {
          x: card.placed ? card.endPad + card.placed.inkStart - card.face.inkStart : 0
          face: card.face
          barThickness: pane.barThickness
          ink: pane.barInk
          fontFamily: pane.barFont
        }
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)
        Text {
          text: card.group ? card.group.label : ""
          textFormat: Text.PlainText
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          text: !card.group ? "" : card.dissolving ? "x again to dissolve"
            : card.count + (card.count === 1 ? " widget, " : " widgets, ") + String(pane.zoneNames[card.group.section]).toLowerCase()
              + (card.group.visibility === "shown" ? "" : card.group.visibility === "managed" ? ", on demand" : ", hidden")
          textFormat: Text.PlainText
          color: card.dissolving ? Commons.Color.urgent : Qt.alpha(Commons.Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
    MouseArea {
      id: cardMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        pane.selectedId = card.group.id
        pane.pendingDissolve = ""
        shelfFocus.forceActiveFocus(Qt.MouseFocusReason)
      }
    }
  }

  // The group's icon as the bar draws it, on an island of the bar's surface;
  // hover and focus light the bar's own cell. Enter, Space or a click opens
  // the picker.
  component IconWell: BorderSurface {
    id: well
    property var group: null
    readonly property bool ownsFocusRing: true
    readonly property var face: group ? pane.layout.groupFace(group, "glyph") : null
    readonly property var placed: face ? CellModel.place(pane.tokens, face.inkLength, true, true) : null
    readonly property real endPad: placed ? CellModel.endPad(pane.tokens, placed.spill) : 0
    implicitWidth: placed ? placed.extent + endPad * 2 : pane.barThickness
    implicitHeight: pane.barThickness
    color: pane.layout.barSurface
    radius: pane.surfaceRadius
    borderSpec: pane.surfaceBorder
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Group icon. Press Enter to change it."
    readonly property var keyHints: [{ keys: "enter", label: "Change icon" }]
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        picker.open(pane.selectedGroup, well)
        event.accepted = true
      }
    }
    BorderSurface {
      x: well.placed ? well.endPad + (well.placed.extent - well.placed.cell) / 2 : 0
      y: pane.tokens.inset
      width: well.placed ? well.placed.cell : 0
      height: pane.tokens.thickness
      radius: CellModel.radius(pane.tokens, pane.bar.islandRounding)
      color: well.activeFocus ? Style.focusFillFor(pane.barInk, Commons.Color.accent)
        : wellMouse.containsMouse ? Style.hoverFillFor(pane.barInk, Commons.Color.accent) : "transparent"
      borderSpec: well.activeFocus ? Border.controlSpec("focus", pane.barInk, Commons.Color.accent) : Border.none()
    }
    BarFace {
      x: well.placed ? well.endPad + well.placed.inkStart - well.face.inkStart : 0
      face: well.face
      barThickness: pane.barThickness
      ink: pane.barInk
      fontFamily: pane.barFont
    }
    MouseArea {
      id: wellMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: { well.forceActiveFocus(Qt.MouseFocusReason); picker.open(pane.selectedGroup, well) }
    }
  }

  // The drawer, drawn as the bar draws it: a menu (Name, Both) on the drawer's
  // surface, rows one inset apart, or a strip of icons in their bar slots
  // (Icon). One Tab stop with its own cursor.
  component DrawerWell: BorderSurface {
    id: drawer
    readonly property bool ownsFocusRing: true
    property int cursor: 0
    property var lifted: null
    property int liftPos: 0
    property int dropPos: -1
    readonly property var current: lifted || pane.members[cursor] || null
    readonly property bool menu: ManagedModel.groupMenu(pane.selectedGroup)
    // Drawn at the size a drawer has on every bar (Bar.drawerTokensFor), menu
    // or strip; the widgets in a strip keep the bar's own size.
    readonly property var cells: pane.menuTokens
    readonly property real lineThickness: cells.bar
    readonly property bool icons: !!pane.selectedGroup && pane.selectedGroup.memberDisplay === "both"
    // The members in the order shown, with the gap a move or a drag opens.
    readonly property var shown: {
      var list = pane.members.filter(function(r) { return !drawer.lifted || r.instanceKey !== drawer.lifted.instanceKey })
        .map(function(r) { return { record: r, gap: false } })
      if (lifted) list.splice(Math.min(liftPos, list.length), 0, { record: lifted, gap: true })
      else if (dropPos >= 0 && ghost.record) {
        list = list.filter(function(v) { return v.record.instanceKey !== ghost.record.instanceKey })
        list.splice(Math.min(dropPos, list.length), 0, { record: ghost.record, gap: true })
      }
      return list
    }
    readonly property var faces: shown.map(function(v) { return pane.layout.barFace(v.record) })
    // Menu geometry, as ManagedDrawer lays out a named menu.
    function glyphRow(face) { return !!face && CellModel.isGlyph(face.inkLength, face.glyph) }
    function labelStart(face) { return ManagedModel.menuLabelStart(drawer.icons && glyphRow(face), drawer.cells.cell, drawer.cells.air) }
    function valueWidth(face) { return face ? ManagedModel.menuValueWidth(drawer.icons, glyphRow(face), face.inkLength, CellModel.MAX_INK) : 0 }
    readonly property real rowWidth: ManagedModel.menuRowWidth(shown.map(function(row, i) {
      return { labelStart: labelStart(faces[i]), title: menuMetrics.advanceWidth(pane.preferences.title(row.record)), value: valueWidth(faces[i]) }
    }), drawer.cells)
    readonly property real pad: Style.space(6)
    readonly property var strip: menu ? ({ lines: [], width: 0 })
      : ShelfModel.zone(CellModel, drawer.cells, faces.map(function(f) { return f || { inkStart: 0, inkLength: 12, glyph: true, cap: true } }), Math.max(1, width - pad * 2))
    readonly property real drawingHeight: menu
      ? shown.length * drawer.cells.thickness + Math.max(0, shown.length - 1) * drawer.cells.inset + 2 * drawer.cells.inset
      : Math.max(1, strip.lines.length) * (lineThickness + Style.space(4)) - Style.space(4)
    readonly property real drawingWidth: menu ? rowWidth + 2 * drawer.cells.inset : strip.width
    FontMetrics {
      id: menuMetrics
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
    }

    Layout.fillWidth: true
    Layout.leftMargin: Math.round(Style.spacing.rowPaddingX / 2)
    Layout.rightMargin: Math.round(Style.spacing.rowPaddingX / 2)
    Layout.preferredHeight: Math.max(Style.space(120), drawingHeight + pad * 2)
    radius: pane.wellRadius
    color: Qt.alpha(Commons.Color.popups.text, 0.04)
    borderSpec: dropPos >= 0 && pane.members.length === 0 ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.45), 1) : Border.none()
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: "In the drawer"
    Accessible.description: current ? pane.preferences.title(current) : "Empty"
    onActiveFocusChanged: if (!activeFocus && lifted) lifted = null

    function contains(point) {
      var p = drawer.mapFromItem(pane, point.x, point.y)
      return p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
    }
    // The landing index: the first member the pointer has not passed.
    function gapAt(point) {
      var p = drawing.mapFromItem(pane, point.x, point.y), pos = 0
      for (var i = 0; i < shown.length; i++) {
        if (shown[i].gap) continue
        var r = rectOf(i)
        if (menu ? p.y < r.y + r.height / 2 : (p.y < r.y + r.height && p.x < r.x + r.width / 2)) return pos
        pos++
      }
      return pos
    }
    function rectOf(i) {
      if (menu) return { x: drawer.cells.inset, y: drawer.cells.inset + i * (drawer.cells.thickness + drawer.cells.inset), width: rowWidth, height: drawer.cells.thickness }
      var at = ShelfModel.slotOf(strip, i)
      if (!at) return { x: 0, y: 0, width: 0, height: 0 }
      return { x: stripLineX(at.line) + at.slot.x, y: at.line * (lineThickness + Style.space(4)), width: at.slot.extent, height: lineThickness }
    }
    function stripLineX(n) { return (drawingWidth - strip.lines[n].width) / 2 }
    function memberAt(point) {
      var p = drawing.mapFromItem(pane, point.x, point.y)
      for (var i = 0; i < shown.length; i++) {
        var r = rectOf(i)
        if (!shown[i].gap && p.x >= r.x && p.y >= r.y && p.x < r.x + r.width && p.y < r.y + r.height) return shown[i].record
      }
      return null
    }

    Keys.onPressed: function(event) {
      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
      var key = event.key, t = event.text, n = pane.members.length
      var next = key === Qt.Key_Down || t === "j" || key === Qt.Key_Right || t === "l"
      var prev = key === Qt.Key_Up || t === "k" || key === Qt.Key_Left || t === "h"
      if (lifted) {
        if (next) liftPos = Math.min(n - 1, liftPos + 1)
        else if (prev) liftPos = Math.max(0, liftPos - 1)
        else if (key === Qt.Key_Space || key === Qt.Key_Return || key === Qt.Key_Enter) {
          var record = lifted, pos = liftPos
          lifted = null
          var rest = pane.selectedGroup.items.filter(function(k) { return k !== record.instanceKey })
          if (pos !== pane.selectedGroup.items.indexOf(record.instanceKey)) pane.bar.assignGroup(record.instanceKey, pane.selectedId, rest[pos] || "")
          cursor = pos
        } else if (key === Qt.Key_Escape) lifted = null
        else return
      } else if (next) {
        if (cursor < n - 1) cursor++
        else { form.step(true); event.accepted = true; return }
      } else if (prev) {
        if (cursor > 0) cursor--
        else { form.step(false); event.accepted = true; return }
      } else if (key === Qt.Key_Space && pane.members[cursor]) {
        lifted = pane.members[cursor]
        liftPos = cursor
      } else if ((t === "x" || key === Qt.Key_Delete) && pane.members[cursor]) {
        pane.bar.assignGroup(pane.members[cursor].instanceKey, "", "")
        cursor = Math.max(0, Math.min(cursor, n - 2))
      } else return
      event.accepted = true
    }

    Item {
      id: drawing
      x: (drawer.width - width) / 2
      y: drawer.pad
      width: drawer.drawingWidth
      height: drawer.drawingHeight
      visible: pane.members.length > 0 || drawer.dropPos >= 0

      // A menu: the drawer's surface, rows one inset apart.
      BorderSurface {
        visible: drawer.menu
        anchors.fill: parent
        color: pane.menuSurface
        radius: pane.surfaceRadius
        borderSpec: pane.surfaceBorder
      }
      // A strip: the bar's islands, one per line.
      Repeater {
        model: drawer.menu ? [] : drawer.strip.lines
        BorderSurface {
          required property var modelData
          required property int index
          x: drawer.stripLineX(index)
          y: index * (drawer.lineThickness + Style.space(4))
          width: modelData.width
          height: drawer.lineThickness
          color: pane.menuSurface
          radius: pane.surfaceRadius
          borderSpec: pane.surfaceBorder
        }
      }
      Repeater {
        model: drawer.shown
        Item {
          id: member
          required property var modelData
          required property int index
          readonly property var record: modelData.record
          readonly property var face: drawer.faces[index]
          readonly property var rect: drawer.rectOf(index)
          readonly property bool isCursor: !modelData.gap && !drawer.lifted && drawer.activeFocus
            && pane.members[drawer.cursor] && pane.members[drawer.cursor].instanceKey === record.instanceKey
          readonly property bool chosen: !modelData.gap && !drawer.lifted && !drawer.activeFocus
            && pane.members[drawer.cursor] && pane.members[drawer.cursor].instanceKey === record.instanceKey
          x: rect.x
          y: rect.y
          width: rect.width
          height: rect.height
          readonly property var placed: face ? CellModel.place(drawer.cells, face.inkLength, face.glyph, face.cap) : null
          // The highlight: a whole row in a menu, the slot's cell on a strip.
          BorderSurface {
            x: drawer.menu ? 0 : (member.width - (member.placed ? member.placed.cell : member.width)) / 2
            y: drawer.menu ? 0 : drawer.cells.inset
            width: drawer.menu ? member.width : (member.placed ? member.placed.cell : member.width)
            height: drawer.menu ? member.height : drawer.cells.thickness
            radius: CellModel.radius(drawer.cells, pane.bar.islandRounding)
            color: member.modelData.gap ? "transparent"
              : member.isCursor ? Style.focusFillFor(pane.barInk, Commons.Color.accent)
              : member.chosen ? Style.selectedFillFor(pane.barInk, Commons.Color.accent) : "transparent"
            borderSpec: member.modelData.gap ? Border.flat(Qt.alpha(pane.barInk, 0.45), 1)
              : member.isCursor ? Border.controlSpec("focus", pane.barInk, Commons.Color.accent) : Border.none()
          }
          // Its face: in the icon cell of a menu row (Both), as a value at the
          // row's end when it is text on the bar, or in its strip slot.
          BarFace {
            visible: !member.modelData.gap && !!member.face && (!drawer.menu || drawer.icons)
            readonly property bool value: drawer.menu && drawer.valueWidth(member.face) > 0
            x: !member.face ? 0 : !drawer.menu ? member.placed.inkStart - member.face.inkStart
              : value ? member.width - drawer.cells.air - member.face.inkStart - drawer.valueWidth(member.face)
              : drawer.cells.cell / 2 - (member.face.inkStart + member.face.inkLength / 2)
            y: (member.height - pane.barThickness) / 2
            face: !member.modelData.gap && (!drawer.menu || drawer.icons) ? member.face : null
            barThickness: pane.barThickness
            ink: pane.barInk
            fontFamily: pane.barFont
          }
          Text {
            visible: drawer.menu && !member.modelData.gap
            x: drawer.labelStart(member.face)
            width: Math.max(0, member.width - x - drawer.cells.air - (drawer.valueWidth(member.face) > 0 ? drawer.valueWidth(member.face) + drawer.cells.air : 0))
            anchors.verticalCenter: parent.verticalCenter
            text: pane.preferences.title(member.record)
            textFormat: Text.PlainText
            color: pane.bar.textOn(Commons.Color.menu.text)
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }
    }
    Text {
      anchors.centerIn: parent
      width: parent.width - Style.space(40)
      visible: pane.members.length === 0 && drawer.dropPos < 0
      text: "Empty. Add widgets from the list beside this, or drag one here."
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }
    // Every pointer gesture over the drawer lands here, above the members.
    MouseArea {
      anchors.fill: parent
      preventStealing: true
      property var pressedRecord: null
      property point origin
      cursorShape: ghost.record ? Qt.ClosedHandCursor : Qt.ArrowCursor
      onPressed: function(mouse) {
        var point = mapToItem(pane, mouse.x, mouse.y)
        var record = drawer.memberAt(point)
        drawer.forceActiveFocus(Qt.MouseFocusReason)
        pressedRecord = record
        origin = point
        if (record) drawer.cursor = Math.max(0, pane.members.findIndex(function(m) { return m.instanceKey === record.instanceKey }))
      }
      onPositionChanged: function(mouse) {
        var point = mapToItem(pane, mouse.x, mouse.y)
        if (pressedRecord && !ghost.record && Math.abs(point.x - origin.x) + Math.abs(point.y - origin.y) > Style.space(6)) {
          ghost.record = pressedRecord
          ghost.from = "drawer"
        }
        if (ghost.record) pane.dragMove(point)
      }
      onReleased: { pressedRecord = null; if (ghost.record) pane.dragEnd(true) }
      onCanceled: { pressedRecord = null; pane.dragEnd(false) }
    }
  }

  // The widgets not in a group, by zone, as icon and name; the list scrolls
  // inside the well, whose height the drawer beside it sets.
  component AvailWell: BorderSurface {
    id: avail
    readonly property bool ownsFocusRing: true
    property int cursor: 0
    property bool targeted: false
    readonly property int count: pane.preferences.entries.filter(function(e) { return !pane.bar.groupFor(e.instanceKey) }).length
    readonly property var items: pane.preferences.entries.filter(function(e) {
      if (pane.bar.groupFor(e.instanceKey)) return false
      var q = filter.text.trim().toLowerCase()
      return !q || pane.preferences.title(e).toLowerCase().indexOf(q) >= 0 || String(e.id).toLowerCase().indexOf(q) >= 0
    }).sort(function(a, b) { return Model.sections.indexOf(a.section) - Model.sections.indexOf(b.section) || a.index - b.index })
    onItemsChanged: cursor = Math.max(0, Math.min(cursor, items.length - 1))
    // The list as drawn: a zone's name before its first widget.
    readonly property var display: {
      var out = []
      items.forEach(function(e, i) {
        if (i === 0 || items[i - 1].section !== e.section) out.push({ header: pane.zoneNames[e.section], record: null, at: -1 })
        out.push({ header: "", record: e, at: i })
      })
      return out
    }

    Layout.fillWidth: true
    Layout.leftMargin: Math.round(Style.spacing.rowPaddingX / 2)
    Layout.rightMargin: Math.round(Style.spacing.rowPaddingX / 2)
    // Beside the drawer: its height. Stacked under it: up to 260.
    Layout.preferredHeight: pane.columns > 1 ? drawerFocus.Layout.preferredHeight
      : Math.min(Style.space(260), chips.implicitHeight + Style.space(16))
    radius: pane.wellRadius
    color: Qt.alpha(Commons.Color.popups.text, 0.04)
    borderSpec: targeted ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.45), 1) : Border.none()
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: "Not in a group"
    Accessible.description: items[cursor] ? pane.preferences.title(items[cursor]) : "Empty"

    function contains(point) {
      var p = avail.mapFromItem(pane, point.x, point.y)
      return p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
    }
    function add(record) {
      if (record && pane.selectedGroup) pane.bar.assignGroup(record.instanceKey, pane.selectedId, "")
    }
    Keys.onPressed: function(event) {
      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
      var key = event.key, t = event.text
      if (key === Qt.Key_Down || t === "j" || key === Qt.Key_Right || t === "l") {
        if (cursor < items.length - 1) cursor++
        else { form.step(true); event.accepted = true; return }
      } else if (key === Qt.Key_Up || t === "k" || key === Qt.Key_Left || t === "h") {
        if (cursor > 0) cursor--
        else { filter.forceActiveFocus(); event.accepted = true; return }
      } else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) add(items[cursor])
      // Typing filters: the letters go to the field.
      else if (t.length === 1 && /\S/.test(t)) { filter.forceActiveFocus(); filter.insert(filter.length, t) }
      else return
      event.accepted = true
    }

    Flickable {
      id: scroller
      anchors.fill: parent
      anchors.margins: Style.space(8)
      contentWidth: width
      contentHeight: chips.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Controls.ScrollBar.vertical: Controls.ScrollBar { policy: scroller.contentHeight > scroller.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
      Flow {
        id: chips
        width: scroller.width
        spacing: Style.space(4)
        Repeater {
          model: avail.display
          Item {
            id: entry
            required property var modelData
            readonly property var record: modelData.record
            width: record ? chip.width : chips.width
            height: record ? chip.height : zoneLabel.implicitHeight + Style.space(2)
            Text {
              id: zoneLabel
              visible: !entry.record
              y: Style.space(2)
              text: entry.modelData.header
              textFormat: Text.PlainText
              color: Qt.alpha(Commons.Color.popups.text, 0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            BorderSurface {
              id: chip
              visible: !!entry.record
              readonly property bool isCursor: avail.activeFocus && avail.cursor === entry.modelData.at
              width: entry.record ? chipRow.implicitWidth + Style.space(16) : 0
              height: entry.record ? Math.max(Style.spacing.controlHeight, chipRow.implicitHeight + Style.space(8)) : 0
              radius: Math.max(0, pane.wellRadius - Style.space(2))
              color: isCursor ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)
                : chipMouse.containsMouse ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : Qt.alpha(Commons.Color.popups.text, 0.06)
              borderSpec: isCursor ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
              onIsCursorChanged: if (isCursor) {
                var top = entry.y, bottom = top + height
                if (top < scroller.contentY) scroller.contentY = top
                else if (bottom > scroller.contentY + scroller.height) scroller.contentY = bottom - scroller.height
              }
              Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Style.space(6)
                WidgetIcon {
                  preferences: pane.preferences
                  record: entry.record || ({})
                  size: Math.round(pane.layout.iconSize * 0.85)
                  maxAspect: 3.2
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: entry.record ? pane.preferences.title(entry.record) : ""
                  textFormat: Text.PlainText
                  color: Commons.Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, Style.space(190))
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              MouseArea {
                id: chipMouse
                anchors.fill: parent
                enabled: !!entry.record
                hoverEnabled: true
                preventStealing: true
                cursorShape: ghost.record ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                property point origin
                property bool dragged: false
                onPressed: function(mouse) {
                  origin = mapToItem(pane, mouse.x, mouse.y)
                  dragged = false
                  avail.cursor = entry.modelData.at
                  avail.forceActiveFocus(Qt.MouseFocusReason)
                }
                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  var point = mapToItem(pane, mouse.x, mouse.y)
                  if (!ghost.record && Math.abs(point.x - origin.x) + Math.abs(point.y - origin.y) > Style.space(6)) {
                    ghost.record = entry.record
                    ghost.from = "list"
                    dragged = true
                  }
                  if (ghost.record) pane.dragMove(point)
                }
                onReleased: if (dragged) pane.dragEnd(true); else avail.add(entry.record)
                onCanceled: pane.dragEnd(false)
              }
            }
          }
        }
      }
    }
    // A member dragged out of the drawer returns to the bar.
    Text {
      anchors.centerIn: parent
      visible: avail.items.length === 0
      width: parent.width - Style.space(40)
      text: filter.text ? "No widgets match." : "Every widget is in a group."
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }
  }
}
