import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "GroupsModel.js" as Groups
import "ZoneFitNotice.js" as ZoneFitNotice

// The bar, laid out as zones (columns) by visibility (rows). The top row is
// drawn with the bar's own surface and live images of the widgets on it.
//
// Keyboard and pointer share one state machine: a cursor rests on an item or
// an empty cell, Space (or a drag) lifts the item, moving it previews where it
// will land, and Space (or release) drops it. Esc puts it back.
Item {
  id: editor
  required property var preferences
  readonly property var bar: preferences.bar
  readonly property var entries: preferences.layoutEntries
  // With a centre anchor, the centre's On demand cell splits at it: the
  // widgets before it wait behind the dots at the centre's start, those after
  // it behind the dots at its end (Model.columns).
  readonly property int anchorIndex: {
    var anchor = editor.bar ? editor.bar.centerAnchor : ""
    var record = anchor ? entries.find(function(e) { return e.section === "center" && !e.groupId && e.id === anchor }) : null
    return record ? record.index : -1
  }
  function columnsFor(mode) { return Model.columns(mode, anchorIndex >= 0) }
  readonly property var cellEntries: {
    var cells = ({})
    for (var mode of Model.modes) for (var column of columnsFor(mode))
      cells[column + ":" + mode] = Model.cell(entries, column, mode, "", anchorIndex)
    return cells
  }
  function members(section, mode, exclude) {
    var items = cellEntries && cellEntries[section + ":" + mode] || []
    return exclude ? items.filter(function(r) { return r.instanceKey !== exclude }) : items
  }
  readonly property var snapshots: preferences.snapshots
  readonly property var sections: Model.sections
  readonly property var modes: Model.modes
  readonly property var zoneNames: ({ left: "Left", center: "Center", right: "Right",
    "center:start": editor.bar && editor.bar.vertical ? "Above center" : "Left of center",
    "center:end": editor.bar && editor.bar.vertical ? "Below center" : "Right of center" })
  readonly property var rows: [
    { mode: "shown", title: "On the bar", hint: "Always visible" },
    { mode: "managed", title: "On demand", hint: editor.bar && editor.bar.onDemandInline
        ? "Behind the zone's dots; shown on activity, or when you hover the dots"
        : "Shown on activity, or when you hover the zone" },
    { mode: "hidden", title: "Hidden", hint: "Kept off the bar" }
  ]

  property var cursorCell: ({ section: "left", mode: "shown", pos: 0 })
  property string cursorKey: ""
  property var lifted: null
  property var liftOrigin: null
  property var liftTarget: null
  property bool pointerLift: false
  property point pointer: Qt.point(0, 0)
  property var pressed: null
  property point pressPoint: Qt.point(0, 0)
  property string hoverKey: ""

  readonly property string liftedKey: lifted ? lifted.instanceKey : ""
  readonly property var cursorItems: members(cursorCell.section, cursorCell.mode, liftedKey)
  readonly property var cursorRecord: lifted || cursorItems[cursorCell.pos] || null
  readonly property bool gridFocused: grid.activeFocus
  readonly property var hints: lifted ? [
    { keys: "h l", label: "Reorder" }, { keys: "j k", label: "Visibility" },
    { keys: "space", label: "Drop" }, { keys: "esc", label: "Cancel" }
  ] : gridFocused ? [
    { keys: "h j k l", label: "Move" }, { keys: "space", label: "Pick up" },
    { keys: "x", label: "Hide" }, { keys: "enter", label: "Details" },
    { keys: "tab", label: "Inspector" }, { keys: "esc", label: "Close" }
  ] : [
    { keys: "j k", label: "Move" }, { keys: "h l", label: "Choose" },
    { keys: "tab", label: "Next" }, { keys: "esc", label: "Close" }
  ]

  function focusFirst() { grid.forceActiveFocus(Qt.TabFocusReason) }
  function count(section, mode) { return members(section, mode, liftedKey).length }
  function cellList(section, mode) {
    var list = members(section, mode, liftedKey).map(function(record) { return { record: record, placeholder: false } })
    if (lifted && liftTarget && liftTarget.section === section && liftTarget.mode === mode)
      list.splice(Math.min(liftTarget.pos, list.length), 0, { record: lifted, placeholder: true })
    return list
  }
  function place(cell) {
    cursorCell = cell
    var record = members(cell.section, cell.mode, "")[cell.pos]
    cursorKey = record ? record.instanceKey : ""
  }
  function syncCursor() {
    if (lifted) return
    for (var m = 0; m < modes.length; m++) for (var column of columnsFor(modes[m])) {
      var list = members(column, modes[m], "")
      for (var i = 0; i < list.length; i++) if (list[i].instanceKey === cursorKey) {
        cursorCell = { section: column, mode: modes[m], pos: i }
        return
      }
    }
    // The split appeared or went away under the cursor.
    if (columnsFor(cursorCell.mode).indexOf(cursorCell.section) < 0) cursorCell = { section: Model.sectionOf(cursorCell.section), mode: cursorCell.mode, pos: 0 }
    if (columnsFor(cursorCell.mode).indexOf(cursorCell.section) < 0) cursorCell = { section: cursorCell.section + ":start", mode: cursorCell.mode, pos: 0 }
    var n = count(cursorCell.section, cursorCell.mode)
    place({ section: cursorCell.section, mode: cursorCell.mode, pos: Math.max(0, Math.min(cursorCell.pos, n - 1)) })
  }
  // Deferred: entries can be re-evaluated lazily while cursorItems is being
  // computed, and moving the cursor there would change cursorItems' own input.
  onEntriesChanged: Qt.callLater(syncCursor)

  function moveCursor(dx, dy) {
    if (lifted) liftTarget = Model.stepLift(count, liftTarget, dx, dy, columnsFor)
    else place(Model.stepCursor(count, cursorCell, dx, dy, columnsFor))
  }
  function lift(record, cell) {
    if (!record) return
    lifted = record
    liftOrigin = cell
    liftTarget = cell
  }
  function cancel() {
    lifted = null
    pointerLift = false
    if (liftOrigin) place(liftOrigin)
  }
  function drop() {
    if (!lifted) return
    var record = lifted, target = liftTarget, origin = liftOrigin
    var unchanged = target.section === origin.section && target.mode === origin.mode && target.pos === origin.pos
    var before = Model.dropBefore(members(target.section, target.mode, record.instanceKey), target.pos, target.section, anchorIndex)
    lifted = null
    pointerLift = false
    cursorKey = record.instanceKey
    cursorCell = target
    if (!unchanged) preferences.move(record, Model.sectionOf(target.section), target.mode, before)
  }
  // Keep an item's place in its zone when only its visibility changes.
  // Rows widgets were hidden from this session, so showing one again restores it.
  property var hiddenFrom: ({})
  function setPlacement(record, section, mode) {
    if (!record || (record.section === section && record.mode === mode)) return
    if (mode === "hidden" && record.mode !== "hidden") {
      var remembered = Object.assign({}, hiddenFrom)
      remembered[record.instanceKey] = record.mode
      hiddenFrom = remembered
    }
    var before = section !== record.section ? -1 : record.groupId ? record.index : record.index + 1
    cursorKey = record.instanceKey
    preferences.move(record, section, mode, before)
  }

  // Pointer hit testing in editor coordinates.
  function cellAt(point) {
    for (var i = 0; i < cellRepeater.count; i++) {
      var cell = cellRepeater.itemAt(i)
      if (!cell) continue
      var p = cell.mapFromItem(editor, point.x, point.y)
      if (p.x >= 0 && p.y >= 0 && p.x < cell.width && p.y < cell.height) return cell
    }
    return null
  }
  function tileAt(point) {
    var cell = cellAt(point)
    if (!cell) return null
    for (var i = 0; i < cell.tiles.count; i++) {
      var tile = cell.tiles.itemAt(i)
      if (!tile || tile.placeholder) continue
      var p = tile.mapFromItem(editor, point.x, point.y)
      if (p.x >= 0 && p.y >= 0 && p.x < tile.width && p.y < tile.height) return tile
    }
    return null
  }
  // The gap under the pointer: before the first real tile the pointer has not
  // passed, reading the wrapped rows top to bottom.
  function gapAt(cell, point) {
    var pos = 0
    for (var i = 0; i < cell.tiles.count; i++) {
      var tile = cell.tiles.itemAt(i)
      if (!tile || tile.placeholder) continue
      var p = tile.mapFromItem(editor, point.x, point.y)
      if (p.y < 0 || (p.y < tile.height && p.x < tile.width / 2)) return pos
      pos++
    }
    return pos
  }
  function pointerMoved(point) {
    pointer = point
    if (!pointerLift) return
    var cell = cellAt(point)
    if (cell) {
      var next = { section: cell.section, mode: cell.mode, pos: gapAt(cell, point) }
      if (!liftTarget || next.section !== liftTarget.section || next.mode !== liftTarget.mode || next.pos !== liftTarget.pos) liftTarget = next
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(10)

    // Widgets that no longer fit sit in their zone's drawer; say so once.
    Text {
      readonly property var notes: editor.bar ? ZoneFitNotice.lines(editor.bar.zoneFitReports) : []
      Layout.fillWidth: true
      visible: notes.length > 0
      text: notes.join(" ")
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Qt.alpha(Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.space(20)

      // ---------------------------------------------------------------- matrix
      Controls.ScrollView {
        id: matrixScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        Item {
          id: grid
          readonly property bool ownsFocusRing: true
          width: matrixScroll.availableWidth
          implicitHeight: matrix.implicitHeight
          activeFocusOnTab: true
          Accessible.role: Accessible.Table
          Accessible.name: "Bar layout"
          Accessible.description: editor.cursorRecord ? editor.preferences.title(editor.cursorRecord) : "Empty"
          Keys.onPressed: function(event) {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
            var key = event.key, t = event.text
            if (key === Qt.Key_Left || t === "h") editor.moveCursor(-1, 0)
            else if (key === Qt.Key_Right || t === "l") editor.moveCursor(1, 0)
            else if (key === Qt.Key_Up || t === "k") editor.moveCursor(0, -1)
            else if (key === Qt.Key_Down || t === "j") editor.moveCursor(0, 1)
            else if (key === Qt.Key_Space) {
              if (editor.lifted) editor.drop()
              else editor.lift(editor.cursorRecord, editor.cursorCell)
            } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
              if (editor.lifted) editor.drop()
              else if (editor.cursorRecord) inspector.focusFirst()
            } else if (key === Qt.Key_Escape && editor.lifted) editor.cancel()
            else if ((t === "x" || key === Qt.Key_Delete) && !editor.lifted && editor.cursorRecord) {
              var r = editor.cursorRecord
              editor.setPlacement(r, r.section, Model.toggledHidden(r.mode, editor.hiddenFrom[r.instanceKey]))
            } else if (t === "g" && !editor.lifted && editor.cursorRecord && editor.cursorRecord.groupId)
              editor.preferences.openGroup(editor.cursorRecord.groupId)
            else return
            event.accepted = true
          }
          onActiveFocusChanged: if (!activeFocus && editor.lifted && !editor.pointerLift) editor.cancel()

          ColumnLayout {
            id: matrix
            width: parent.width
            spacing: Style.space(14)

            // Zone headings aligned over the columns.
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(10)
              Item { Layout.preferredWidth: rowHeaderWidth.width; Layout.minimumWidth: rowHeaderWidth.width }
              Repeater {
                model: editor.sections
                Text {
                  required property string modelData
                  text: editor.zoneNames[modelData]
                  textFormat: Text.PlainText
                  color: Model.sectionOf(editor.cursorCell.section) === modelData ? Color.popups.text : Qt.alpha(Color.popups.text, 0.55)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  Layout.fillWidth: true
                  Layout.preferredWidth: 1
                  horizontalAlignment: Text.AlignHCenter
                }
              }
            }

            Repeater {
              model: editor.rows
              RowLayout {
                id: rowItem
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: Style.space(10)

                ColumnLayout {
                  id: rowHeader
                  Layout.preferredWidth: rowHeaderWidth.width
                  Layout.minimumWidth: rowHeaderWidth.width
                  Layout.maximumWidth: rowHeaderWidth.width
                  Layout.alignment: Qt.AlignTop
                  Layout.topMargin: Style.space(8)
                  spacing: Style.space(2)
                  Text {
                    text: rowItem.modelData.title
                    textFormat: Text.PlainText
                    color: editor.cursorCell.mode === rowItem.modelData.mode ? Color.popups.text : Qt.alpha(Color.popups.text, 0.75)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                  }
                  Text {
                    text: rowItem.modelData.hint
                    textFormat: Text.PlainText
                    color: Qt.alpha(Color.popups.text, 0.5)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                  }
                }

                Item {
                  id: rowBody
                  readonly property real inset: rowItem.modelData.mode === "shown" ? Style.space(6) : 0
                  Layout.fillWidth: true
                  implicitHeight: cellsRow.implicitHeight + inset * 2

                  // The bar sits on a stand-in for the desktop so its own surface,
                  // islands and borders read against the panel.
                  BarBackdrop {
                    motionEnabled: !editor.bar || editor.bar.animationsEnabled
                    anchors.fill: parent
                    visible: rowItem.modelData.mode === "shown"
                    source: rowItem.modelData.mode === "shown" ? editor.preferences.wallpaper : ""
                    position: editor.bar.position
                    // Flat and floating bars are one strip behind all three
                    // zones: flat meets the edges, floating keeps the gap.
                    BorderSurface {
                      visible: !editor.bar.islands
                      x: editor.bar.flat ? 0 : rowBody.inset
                      y: editor.bar.flat ? 0 : rowBody.inset
                      width: parent.width - x * 2
                      height: editor.bar.flat ? cellsRow.height + rowBody.inset : cellsRow.height
                      color: editor.bar.mainSurfaceColor
                      radius: editor.bar.flat ? 0 : editor.bar.islandRounding
                      borderSpec: editor.bar.flat ? Border.none() : editor.bar.islandBorder
                    }
                  }

                  RowLayout {
                    id: cellsRow
                    x: rowBody.inset
                    y: rowItem.modelData.mode === "shown" && editor.bar.flat ? rowBody.inset / 2 : rowBody.inset
                    width: parent.width - rowBody.inset * 2
                    spacing: rowItem.modelData.mode === "shown" && !editor.bar.islands ? 0 : Style.space(10)
                    Repeater {
                      model: editor.sections
                      // One zone's column: its cell, or the split centre's two.
                      RowLayout {
                        id: zoneColumn
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: Style.space(6)
                        Repeater {
                          model: editor.columnsFor(rowItem.modelData.mode).filter(function(column) { return Model.sectionOf(column) === zoneColumn.modelData })
                          Cell {
                            required property string modelData
                            section: modelData
                            mode: rowItem.modelData.mode
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.alignment: Qt.AlignTop
                            Component.onCompleted: cellRepeater.register(this)
                            Component.onDestruction: cellRepeater.unregister(this)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // Every pointer gesture over the grid lands here, above the tiles, so a
          // drag survives the tiles being rebuilt as the preview moves.
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: editor.pointerLift ? Qt.ClosedHandCursor : editor.hoverKey ? Qt.OpenHandCursor : Qt.ArrowCursor
            onPositionChanged: function(mouse) {
              var point = mapToItem(editor, mouse.x, mouse.y)
              if (!editor.pointerLift) {
                var tile = editor.tileAt(point)
                editor.hoverKey = tile ? tile.record.instanceKey : ""
              }
              if (pressed && editor.pressed && !editor.pointerLift
                  && Math.abs(point.x - editor.pressPoint.x) + Math.abs(point.y - editor.pressPoint.y) > Style.space(6)) {
                editor.lift(editor.pressed.record, editor.pressed.cell)
                editor.pointerLift = true
              }
              editor.pointerMoved(point)
            }
            onExited: editor.hoverKey = ""
            onPressed: function(mouse) {
              grid.forceActiveFocus(Qt.MouseFocusReason)
              if (editor.lifted) editor.cancel()
              var point = mapToItem(editor, mouse.x, mouse.y)
              editor.pressPoint = point
              var tile = editor.tileAt(point)
              var cell = editor.cellAt(point)
              if (tile) {
                var at = { section: tile.section, mode: tile.mode, pos: tile.pos }
                editor.place(at)
                editor.pressed = { record: tile.record, cell: at }
              } else {
                editor.pressed = null
                if (cell) editor.place({ section: cell.section, mode: cell.mode, pos: editor.gapAt(cell, point) })
              }
            }
            onReleased: {
              editor.pressed = null
              if (editor.pointerLift) editor.drop()
            }
            onCanceled: {
              editor.pressed = null
              if (editor.pointerLift) editor.cancel()
            }
            onDoubleClicked: if (editor.cursorRecord) inspector.focusFirst()
          }
        }
      }

      // ------------------------------------------------------------- inspector
      Inspector {
        id: inspector
        Layout.preferredWidth: Style.space(300)
        Layout.minimumWidth: Style.space(260)
        Layout.fillHeight: true
      }
    }
  }

  // The dragged item follows the pointer while its landing place is previewed.
  Tile {
    visible: editor.pointerLift && !!editor.lifted
    record: editor.lifted || ({})
    mode: editor.liftTarget ? editor.liftTarget.mode : "managed"
    ghost: true
    x: editor.pointer.x - width / 2
    y: editor.pointer.y - height / 2
    z: 100
  }

  TextMetrics { id: rowHeaderWidth; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true; text: "On the bar___" }

  QtObject {
    id: cellRepeater
    property var cells: []
    readonly property int count: cells.length
    function itemAt(i) { return cells[i] }
    function register(cell) { cells = cells.concat([cell]) }
    function unregister(cell) { cells = cells.filter(function(c) { return c !== cell }) }
  }

  // -------------------------------------------------------------- components
  component Cell: BorderSurface {
    id: cell
    property string section: ""
    property string mode: ""
    property alias tiles: tileRepeater
    readonly property var list: editor.cellList(section, mode)
    readonly property bool barRow: mode === "shown"
    readonly property bool targeted: !!editor.lifted && !!editor.liftTarget
      && editor.liftTarget.section === section && editor.liftTarget.mode === mode
    readonly property bool cursorHere: !editor.lifted && editor.cursorCell.section === section && editor.cursorCell.mode === mode
    // The bar row is as thick as the bar itself, so it follows the bar size.
    implicitHeight: barRow ? editor.bar.barSize : Math.max(Style.space(58), flow.implicitHeight + Style.space(16))
    // The bar row never wraps: like the bar, a zone keeps one line and
    // shrinks to fit, aligned the way the zone aligns on screen.
    readonly property real contentWidth: flow.childrenRect.width
    readonly property real fit: barRow ? Math.min(1, (width - Style.space(16)) / Math.max(1, contentWidth)) : 1
    radius: barRow ? editor.bar.islandRounding : Math.max(Style.cornerRadius, Style.space(6))
    color: barRow ? (editor.bar.islands ? editor.bar.mainSurfaceColor : "transparent")
      : mode === "managed" ? Qt.alpha(Color.popups.text, 0.05) : Qt.alpha(Color.popups.text, 0.018)
    borderSpec: targeted ? Border.flat(Qt.alpha(Color.accent, 0.8), 1)
      : barRow ? (editor.bar.islands ? editor.bar.islandBorder : Border.none())
      : Border.flat(Qt.alpha(Color.popups.text, mode === "managed" ? 0.14 : 0.08), 1)

    Behavior on implicitHeight { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Text {
      anchors.centerIn: parent
      visible: cell.list.length === 0
      // A half of the split centre says which side it holds.
      text: cell.targeted ? "Drop here" : cell.cursorHere && editor.gridFocused ? "Empty"
        : cell.section.indexOf(":") > 0 ? editor.zoneNames[cell.section] : ""
      textFormat: Text.PlainText
      color: cell.targeted ? Color.accent : Qt.alpha(Color.popups.text, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      width: Math.min(implicitWidth, cell.width - Style.space(8))
      elide: Text.ElideRight
    }
    BorderSurface {
      anchors.fill: parent
      anchors.margins: Style.space(3)
      visible: cell.list.length === 0 && cell.cursorHere && editor.gridFocused
      color: "transparent"
      radius: Math.max(0, cell.radius - Style.space(3))
      borderSpec: Border.controlSpec("focus", Color.popups.text, Color.accent)
    }

    Flow {
      id: flow
      x: !cell.barRow || cell.section === "left" ? Style.space(8)
        : cell.section === "right" ? cell.width - Style.space(8) - cell.contentWidth * cell.fit
        : (cell.width - cell.contentWidth * cell.fit) / 2
      y: cell.barRow ? (cell.height - childrenRect.height * cell.fit) / 2 : Style.space(8)
      width: cell.barRow ? 100000 : parent.width - Style.space(16)
      scale: cell.fit
      transformOrigin: Item.TopLeft
      spacing: cell.barRow ? Math.max(Style.space(2), editor.bar.widgetSpacing) : Style.space(6)
      RetainedList {
        id: tileList
        recordProperty: "retainedRecord"
        records: cell.list.map(function(value, index) {
          return { key: value.placeholder ? "insertion-gap" : value.record.instanceKey || cell.section + ":" + cell.mode + ":" + index,
            entry: value.record, placeholder: value.placeholder, index: index }
        })
        factory: Component {
          Tile {
            required property var retainedRecord
            record: retainedRecord.entry
            placeholder: retainedRecord.placeholder
            section: cell.section
            mode: cell.mode
            pos: retainedRecord.index
            maxWidth: cell.barRow ? Infinity : flow.width
          }
        }
      }
      Repeater { id: tileRepeater; model: tileList.model }
    }
  }

  component Tile: Item {
    id: tile
    property var record: ({})
    property bool placeholder: false
    property bool ghost: false
    property string section: ""
    property string mode: ""
    property int pos: 0
    // A narrow cell (a half of the split centre) elides the name to fit.
    property real maxWidth: Infinity
    readonly property var snapshot: mode === "shown" && record.instanceKey ? editor.snapshots[record.instanceKey] : null
    readonly property bool isCursor: !ghost && !editor.lifted && editor.cursorKey !== "" && record.instanceKey === editor.cursorKey
    readonly property bool hovered: !ghost && !editor.lifted && editor.hoverKey === record.instanceKey
    readonly property var group: record.groupId ? editor.bar.groups.find(function(g) { return g.id === record.groupId }) || null : null
    readonly property int memberCount: group ? group.items.length : 0
    // On the bar row a tile is a bar slot: as thick as the bar, with its
    // highlight inset the way the bar insets its own.
    readonly property bool onBar: mode === "shown" && !ghost
    // Press feedback: the tile dips while the pointer holds it, before a drag.
    readonly property bool pressedDown: !ghost && !placeholder && !!editor.pressed && !editor.pointerLift
      && editor.pressed.record.instanceKey === record.instanceKey
    scale: pressedDown ? 0.97 : 1
    Behavior on scale { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    // On the bar row a widget is drawn as it looks: live on a horizontal bar,
    // otherwise its saved horizontal look, otherwise its glyph alone, as the
    // bar shows it; a group shows the face it is set to (glyph, name or both).
    // Names are for the rows below, which the bar does not show.
    readonly property bool pictured: !!snapshot || (onBar && rowIcon.hasImage)
    readonly property bool groupFace: onBar && !!group && !snapshot
    implicitWidth: body.implicitWidth + Style.space(pictured || onBar ? 8 : 16)
    implicitHeight: onBar ? editor.bar.barSize
      : Math.max(snapshot ? snapshot.height + Style.space(6) : Style.spacing.controlHeight, body.implicitHeight + Style.space(8))
    opacity: mode === "hidden" && !placeholder && !ghost ? 0.62 : ghost ? 0.9 : 1

    BorderSurface {
      anchors.fill: parent
      anchors.margins: tile.onBar ? editor.bar.highlightInset(tile.height) : 0
      radius: tile.onBar ? editor.bar.highlightRounding : Math.max(Style.cornerRadius - Style.space(2), Style.space(4))
      color: tile.placeholder ? Qt.alpha(Color.accent, 0.16)
        : tile.ghost ? Color.popups.background
        : tile.isCursor && editor.gridFocused ? Style.focusFillFor(Color.popups.text, Color.accent)
        : tile.isCursor ? Style.selectedFillFor(Color.popups.text, Color.accent)
        : tile.hovered ? Style.hoverFillFor(Color.popups.text, Color.accent)
        : tile.pictured || tile.onBar ? "transparent" : Qt.alpha(Color.popups.text, 0.06)
      borderSpec: tile.placeholder || tile.ghost ? Border.flat(Color.accent, Math.max(1, Style.space(2)))
        : tile.isCursor && editor.gridFocused ? Border.controlSpec("focus", Color.popups.text, Color.accent)
        : tile.isCursor ? Border.flat(Qt.alpha(Color.popups.text, 0.35), 1)
        : Border.none()
      Behavior on color { enabled: editor.bar.animationsEnabled; ColorAnimation { duration: 90 } }
    }

    Row {
      id: body
      anchors.centerIn: parent
      spacing: Style.space(6)
      Image {
        visible: !!tile.snapshot
        source: tile.snapshot ? tile.snapshot.url : ""
        width: tile.snapshot ? tile.snapshot.width : 0
        height: tile.snapshot ? tile.snapshot.height : 0
        sourceSize: tile.snapshot ? Qt.size(tile.snapshot.width * 2, tile.snapshot.height * 2) : undefined
        smooth: true
        anchors.verticalCenter: parent.verticalCenter
      }
      WidgetIcon {
        id: rowIcon
        visible: !tile.snapshot && !tile.groupFace
        preferences: editor.preferences
        record: tile.record
        size: Math.round(tile.onBar ? editor.bar.themeBarSize : editor.bar.themeBarSize * 0.85)
        maxAspect: tile.onBar ? 40 : 3.2
        anchors.verticalCenter: parent.verticalCenter
      }
      // A group's face, drawn the way the bar draws its button.
      Text {
        readonly property string face: tile.group ? tile.group.face : "glyph"
        visible: tile.groupFace
        text: !tile.group ? "" : face === "text" ? tile.group.label
          : face === "both" ? tile.group.icon + "  " + tile.group.label : tile.group.icon
        textFormat: Text.PlainText
        color: Color.popups.text
        font.family: face === "glyph" ? (Groups.iconFont(text) || Style.font.family) : Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        visible: !tile.pictured && !tile.onBar
        text: tile.record.instanceKey ? editor.preferences.title(tile.record) : ""
        textFormat: Text.PlainText
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        width: Math.max(Style.space(24), Math.min(implicitWidth, Style.space(150),
          tile.maxWidth - Style.space(16) - (rowIcon.visible ? rowIcon.width + body.spacing : 0)
            - (tile.memberCount > 0 ? memberLabel.implicitWidth + body.spacing : 0)))
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        id: memberLabel
        visible: tile.memberCount > 0 && !tile.pictured && !tile.onBar
        text: tile.memberCount
        textFormat: Text.PlainText
        color: Qt.alpha(Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  component Inspector: BorderSurface {
    id: panel
    readonly property var record: editor.cursorRecord
    readonly property bool isGroup: !!record && !!record.groupId
    readonly property var group: isGroup ? editor.bar.groups.find(function(g) { return g.id === record.groupId }) || null : null
    readonly property var snapshot: record ? editor.snapshots[record.instanceKey] : null
    function focusFirst() { form.focusFirst() }
    color: Qt.alpha(Color.popups.text, 0.035)
    radius: Math.max(Style.cornerRadius, Style.space(6))
    borderSpec: Border.flat(Qt.alpha(Color.popups.text, 0.1), 1)

    Text {
      anchors.fill: parent
      anchors.margins: Style.space(18)
      visible: !panel.record
      text: "Nothing " + (editor.cursorCell.mode === "shown" ? "on the " + editor.zoneNames[editor.cursorCell.section].toLowerCase() + " of the bar"
        : editor.cursorCell.mode === "managed" ? (editor.cursorCell.section.indexOf(":") > 0
          ? "on demand " + editor.zoneNames[editor.cursorCell.section].toLowerCase()
          : "in the " + editor.zoneNames[editor.cursorCell.section].toLowerCase() + " drawer")
        : "hidden on the " + editor.zoneNames[editor.cursorCell.section].toLowerCase()) + " yet.\n\nPick up a widget with Space, or drag one here."
      textFormat: Text.PlainText
      color: Qt.alpha(Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    PrefsForm {
      id: form
      visible: !!panel.record
      anchors.fill: parent
      anchors.margins: Style.space(16)
      maxContentWidth: width

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)
        BarBackdrop {
          motionEnabled: !editor.bar || editor.bar.animationsEnabled
          Layout.preferredWidth: Math.max(Style.space(52), Math.max(preview.width, inspectorIcon.width) + Style.space(28))
          Layout.preferredHeight: Style.space(56)
          source: editor.preferences.wallpaper
          position: editor.bar.position
          BorderSurface {
            anchors.centerIn: parent
            width: parent.width - Style.space(12)
            height: editor.bar.barSize
            radius: editor.bar.islandRounding
            color: editor.bar.mainSurfaceColor
            borderSpec: editor.bar.islandBorder
          }
          Image {
            id: preview
            anchors.centerIn: parent
            visible: !!panel.snapshot
            source: panel.snapshot ? panel.snapshot.url : ""
            width: panel.snapshot ? Math.min(panel.snapshot.width, Style.space(230)) : 0
            height: panel.snapshot ? panel.snapshot.height * width / Math.max(1, panel.snapshot.width) : 0
            fillMode: Image.PreserveAspectFit
          }
          WidgetIcon {
            id: inspectorIcon
            anchors.centerIn: parent
            visible: !panel.snapshot
            preferences: editor.preferences
            record: panel.record || ({})
            size: editor.bar.themeBarSize
          }
        }
        Text {
          text: panel.record ? editor.preferences.title(panel.record) : ""
          textFormat: Text.PlainText
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }
        Text {
          text: panel.isGroup ? (panel.group ? panel.group.items.length + (panel.group.items.length === 1 ? " widget" : " widgets") + " in this group" : "Group")
            : panel.record ? panel.record.id : ""
          textFormat: Text.PlainText
          color: Qt.alpha(Color.popups.text, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          Layout.fillWidth: true
          elide: Text.ElideMiddle
        }
      }

      PrefsSection {
        title: "Placement"
        spacing: Style.space(10)
        PrefsChoice {
          label: "Zone"
          stacked: true
          options: [{ value: "left", label: "Left" }, { value: "center", label: "Center" }, { value: "right", label: "Right" }]
          value: panel.record ? panel.record.section : ""
          onChosen: function(value) { editor.setPlacement(panel.record, value, panel.record.mode) }
        }
        PrefsChoice {
          label: "Visibility"
          stacked: true
          options: [{ value: "shown", label: "On the bar" }, { value: "managed", label: "On demand" }, { value: "hidden", label: "Hidden" }]
          value: panel.record ? panel.record.mode : ""
          onChosen: function(value) { editor.setPlacement(panel.record, panel.record.section, value) }
        }
        PrefsToggle {
          visible: !!panel.record && !panel.isGroup && panel.record.section === "center" && panel.record.mode === "shown"
          label: "Keep at screen center"
          description: "Other center widgets arrange around it"
          checked: !!panel.record && editor.bar.centerAnchor === panel.record.id
          onToggled: function(checked) { editor.preferences.setOption("centerAnchor", checked ? panel.record.id : "") }
        }
        PrefsToggle {
          readonly property bool clockDriven: !!panel.record && editor.bar.quietActivityId(panel.record.id)
          readonly property bool applies: editor.bar.autoHide && editor.bar.autoHideActivity && !clockDriven
          visible: !!panel.record && !panel.isGroup
          label: "Show on activity"
          description: clockDriven ? "It changes on a clock, so it never brings the bar out"
            : !editor.bar.autoHide ? "Applies while the bar autohides"
            : !editor.bar.autoHideActivity ? "Turned off for every widget in General"
            : "Slide the bar out briefly when this widget changes"
          enabled: applies
          opacity: enabled ? 1 : 0.45
          checked: !!panel.record && !clockDriven && editor.bar.activityPeeksFor(panel.record.instanceKey, panel.record.id)
          onToggled: function(checked) { editor.bar.setActivityPeek(panel.record.instanceKey, checked) }
        }
      }

      PrefsSection {
        visible: !panel.isGroup
        title: "Group"
        description: "A grouped widget moves into its group's drawer."
        Dropdown {
          Layout.fillWidth: true
          showLabel: false
          options: [{ value: "", label: "Not grouped" }].concat(editor.bar.groups.map(function(g) { return { value: g.id, label: g.label } }))
          value: ""
          onChanged: function(value) { if (value && panel.record) editor.bar.assignGroup(panel.record.instanceKey, value, "") }
        }
      }

      PrefsSection {
        visible: panel.isGroup
        title: "Members"
        Repeater {
          model: panel.group ? panel.group.items : []
          RowLayout {
            required property string modelData
            readonly property var member: editor.preferences.entries.find(function(e) { return e.instanceKey === modelData }) || null
            Layout.fillWidth: true
            spacing: Style.space(8)
            WidgetIcon {
              preferences: editor.preferences
              record: parent.member || ({})
              size: Math.round(editor.bar.themeBarSize * 0.8)
            }
            Text {
              text: parent.member ? editor.preferences.title(parent.member) : "Unavailable widget"
              textFormat: Text.PlainText
              color: Qt.alpha(Color.popups.text, 0.85)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
        }
        Button {
          text: "Edit group"
          iconText: "󰏫"
          focusable: true
          bordered: true
          foreground: Color.popups.text
          onClicked: editor.preferences.openGroup(panel.record.groupId)
        }
      }
    }
  }
}
