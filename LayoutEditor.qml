import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "GroupsModel.js" as Groups
import "ZoneFitNotice.js" as ZoneFitNotice
import "AppearanceModel.js" as AppearanceModel
import "CellModel.js" as CellModel
import "ShelfModel.js" as ShelfModel

// The bar's layout as tiles (docs/behavior/preferences.md): one shelf per visibility
// (On the bar, On demand, Hidden), each holding the three zones in columns that
// line up from shelf to shelf, then a tile with the selected widget's settings.
// Preferences draws the bar horizontally whatever edge it is on; the zones are
// named by where they are on screen.
//
// Keyboard and pointer share one state machine: a cursor rests on an item or
// an empty cell, Space (or a drag) lifts the item, moving it previews where it
// will land, and Space (or release) drops it. Esc puts it back. Each shelf is
// a Tab stop sharing that cursor.
Item {
  id: editor
  required property var preferences
  // Bento columns for the window (12, 6 or 1), set by Preferences.
  property int columns: 12
  readonly property var bar: preferences.bar
  // The layout's widgets, then the icons still in Omarchy's tray (its row).
  readonly property var entries: preferences.layoutEntries.concat(preferences.trayEntries)
  // Every shelf has the five zones (Model.sections); the tray's row one column.
  function columnsFor(mode) { return mode === "tray" ? ["tray"] : Model.sections }
  // The rows: the three visibilities, then the tray. Only a tray icon can be
  // lifted into the tray's row.
  readonly property var rows: Model.rows
  readonly property var liftRows: lifted && lifted.trayItem ? Model.rows : Model.modes
  readonly property var cellEntries: {
    var cells = ({})
    for (var mode of Model.rows) for (var column of columnsFor(mode))
      cells[column + ":" + mode] = Model.cell(entries, column, mode, "")
    return cells
  }
  function members(section, mode, exclude) {
    var items = cellEntries && cellEntries[section + ":" + mode] || []
    return exclude ? items.filter(function(r) { return r.instanceKey !== exclude }) : items
  }
  readonly property var snapshots: preferences.snapshots
  readonly property var sections: Model.sections
  readonly property var modes: Model.modes
  readonly property bool sideBar: !!bar && bar.vertical
  readonly property var zoneNames: ({ left: sideBar ? "Top" : "Left", centerBegin: sideBar ? "Above center" : "Left of center",
    center: "Center", centerEnd: sideBar ? "Below center" : "Right of center", right: sideBar ? "Bottom" : "Right", tray: "Tray" })
  // A zone's share of the shelf's width (300/170/150/170/300 at 1100 px).
  readonly property var zoneShares: ({ left: 30, centerBegin: 17, center: 15, centerEnd: 17, right: 30, tray: 1 })
  // Which way a zone grows on the bar, so its items pack from that side: Left
  // and Right of center hang off the box, Center is centred on the middle.
  // The screen the shelves picture: the bar is the same on every screen, but
  // a camera moves the center. Preferences' own screen unless another is picked.
  property string previewName: ""
  readonly property var screens: Quickshell.screens
  readonly property var previewScreen: screens.find(function(s) { return s.name === previewName }) || preferences.targetScreen || screens[0] || null
  function cameraOn(screen) { return !!bar && !sideBar && !!screen && !!bar.notchFor(screen) }
  readonly property bool previewCamera: cameraOn(previewScreen)
  // Only screens that look different get a switcher.
  readonly property bool screensDiffer: screens.some(function(s) { return editor.cameraOn(s) }) && screens.some(function(s) { return !editor.cameraOn(s) })
  readonly property string barCaption: sideBar
    ? (screens.some(function(s) { return !!editor.bar && !!editor.bar.notchFor(s, "top") }) ? "No camera on this edge: Center sits over the middle; Above center and Below center hang off it."
      : "Center sits over the screen's middle; Above center and Below center hang off it.")
    : previewCamera ? "Left of center sits left of the camera; Center and Right of center sit right of it."
    : "Center sits over the screen's middle; Left of center and Right of center hang off it."
  // Where a zone sits by the camera, for the Zone choice.
  function cameraNote(zone) {
    if (!previewCamera || zone === "left" || zone === "right") return ""
    return (zone === "centerBegin" ? "left of the camera" : "right of the camera") + (screensDiffer && previewScreen ? " on " + previewScreen.name : "")
  }
  readonly property var zoneChoices: sections.map(function(s) { return { value: s, label: editor.zoneNames[s], share: editor.zoneShares[s] } })
  function zonePack(zone) { return zone === "left" || zone === "centerEnd" ? "start" : zone === "right" || zone === "centerBegin" ? "end" : "middle" }
  // Preferences draws a horizontal bar, at the size it has on a top edge.
  readonly property real barThickness: bar ? bar.barSizeFor(false) : Style.bar.sizeHorizontal
  readonly property real iconSize: Style.bar.sizeHorizontal
  // Widget images are drawn in the bar's text colour. When that barely shows
  // on the Preferences background (Light text in a light theme), they sit on
  // a backing in the Preferences text colour instead.
  readonly property bool inkBacked: {
    if (!bar || !bar.barForeground) return false
    var a = AppearanceModel.luminance(bar.barForeground), b = AppearanceModel.luminance(Commons.Color.popups.background)
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05) < 3
  }
  // The bar shelf draws the bar as it is: its cell geometry at the size it
  // has on a top edge, its text colour and font, its surface (opaque: the
  // wallpaper behind it is not drawn), rounding and border.
  readonly property var barTokens: CellModel.tokens({ bar: barThickness, spacing: bar ? bar.widgetSpacing : 0, mode: bar ? bar.spacingMode : "slots" })
  readonly property color barInk: bar ? bar.barForeground : Commons.Color.popups.text
  readonly property string barInkHex: bar ? bar.colorHex(bar.barForeground) : ""
  readonly property color barSurface: bar ? Qt.rgba(bar.mainSurfaceColor.r, bar.mainSurfaceColor.g, bar.mainSurfaceColor.b, 1) : Commons.Color.popups.background
  readonly property string barFont: bar ? bar.fontFamily : Style.font.family
  // Ink of a line of text, measured once per text, font and size. Each font
  // gets its own FontMetrics, made once, so measuring never changes a
  // property a binding reads.
  property var inkCache: ({})
  property var fontMetrics: ({})
  function textInk(text, family, size) {
    var key = family + "|" + size + "|" + text
    var known = inkCache[key]
    if (known) return known
    var fontKey = family + "|" + size
    var metrics = fontMetrics[fontKey]
    if (!metrics) {
      metrics = Qt.createQmlObject("import QtQuick; FontMetrics {}", editor)
      metrics.font = Qt.font({ family: family, pixelSize: size })
      fontMetrics[fontKey] = metrics
    }
    var r = metrics.tightBoundingRect(text)
    known = { start: r.x, length: r.width, advance: metrics.advanceWidth(text) }
    inkCache[key] = known
    return known
  }
  function textFace(text, family, size, glyph) {
    var ink = textInk(text, family, size)
    return { kind: "text", text: text, family: family, size: size, inkStart: ink.start, inkLength: ink.length, glyph: glyph, cap: true }
  }
  function imageFace(url, f) {
    // An image from before Powerbar recorded ink is placed as the bar places
    // a glyph of its width.
    var known = f.inkLength !== undefined
    // Drawn in another text colour (another theme, or before Powerbar noted
    // it): shown in the bar's current colour until the bar recaptures it.
    return { kind: "image", url: url, w: f.w, h: f.h, inkStart: known ? f.inkStart : 0, inkLength: known ? f.inkLength : f.w,
      glyph: known ? f.glyph : f.w <= barTokens.cell, cap: known ? f.cap !== false : true, recolour: f.ink !== barInkHex }
  }
  // How the bar draws a widget, the truest way known: a live image; a saved
  // one drawn in the bar's current text colour; a group's face; the glyph the
  // widget draws itself, in the bar's font, size and colour (unless it draws
  // several, like workspaces); a saved image from another theme, recoloured;
  // Powerbar's stock glyph.
  function barFace(record) {
    if (!record || !record.instanceKey) return null
    var key = record.instanceKey
    var live = snapshots[key]
    if (live && live.face && live.face.inkLength !== undefined) return imageFace(live.url, live.face)
    var saved = !record.groupId && bar && bar.widgetFaces ? bar.widgetFaces[key] || imageSizes[key] || null : null
    var url = saved ? preferences.cachedImageUrl(key) : ""
    if (url && saved.inkLength !== undefined && saved.ink === barInkHex) return imageFace(url, saved)
    var group = record.groupId && bar ? bar.groups.find(function(g) { return g.id === record.groupId }) || null : null
    if (group) return groupFace(group, "")
    var read = preferences.readGlyph(record)
    if (read && !(read.parts > 1 && url)) return textFace(read.glyph, read.font || barFont, read.size || Style.font.body, true)
    if (url) return imageFace(url, saved)
    if (live) return imageFace(live.url, { w: live.width, h: live.height })
    var stock = Model.icon(String(record.id || ""))
    return textFace(stock, Groups.iconFont(stock) || barFont, Style.font.body, true)
  }
  // A group's face as the bar draws it (GroupFace): its runs, measured run by
  // run, the ink from the first run's to the last run's.
  function groupFace(group, mode) {
    var x = 0, start = null, end = 0
    var runs = Groups.faceRuns(group, mode)
    runs.forEach(function(run, index) {
      if (run.kind === "image") {
        if (start === null) start = x
        end = x + 16
        x += 16
        return
      }
      var ink = textInk(run.text, run.font || barFont, Style.font.body)
      if (run.kind !== "gap") {
        if (start === null) start = x + ink.start
        end = x + ink.start + ink.length
      }
      // An icon before the name ends at its ink (GroupFace).
      x += index === 0 && runs.length > 1 ? Math.max(0, ink.start + ink.length) : ink.advance
    })
    var face = mode || group.face
    return { kind: "group", group: group, mode: mode, inkStart: start || 0, inkLength: Math.max(0, end - (start || 0)),
      glyph: face === "glyph", cap: true }
  }
  // Sizes of saved images from before faces.json, learnt as they load.
  property var imageSizes: ({})
  readonly property var unsizedImages: entries.filter(function(e) {
    return e.mode === "shown" && !e.groupId && !(editor.bar && editor.bar.widgetFaces[e.instanceKey]) && !editor.imageSizes[e.instanceKey]
      && editor.preferences.cachedImageUrl(e.instanceKey) !== ""
  }).map(function(e) { return e.instanceKey })
  Repeater {
    model: editor.unsizedImages
    Image {
      required property string modelData
      visible: false
      asynchronous: true
      source: editor.preferences.cachedImageUrl(modelData)
      onStatusChanged: if (status === Image.Ready) {
        var scale = 2 * Math.max(1, Screen.devicePixelRatio)
        var next = Object.assign({}, editor.imageSizes)
        next[modelData] = { w: sourceSize.width / scale, h: sourceSize.height / scale }
        editor.imageSizes = next
      }
    }
  }
  readonly property var fitNotes: editor.bar ? ZoneFitNotice.lines(editor.bar.zoneFitReports) : []
  readonly property var shelfInfo: ({
    shown: { title: "On the bar", caption: fitNotes.length ? fitNotes.join(" ") : "Always visible" },
    // Side by side on a side bar, the shelves have room for a few words.
    managed: { title: "On demand", caption: sideBar ? (editor.bar && editor.bar.onDemandInline ? "Behind the dots" : "In a drawer")
      : editor.bar && editor.bar.onDemandInline
      ? "Behind the zone's dots; shown on activity, or when you hover the dots"
      : "In the zone's drawer when you hover it, or briefly on activity" },
    hidden: { title: "Hidden", caption: "Kept off the bar" },
    tray: { title: "In the tray", caption: sideBar ? "" : "Omarchy's tray icons. Drag one onto a row above to place it like a widget" }
  })
  // The zone a tray icon goes to when moved without a place: the tray's own.
  readonly property string trayZone: {
    var tray = entries.find(function(e) { return e.id === "omarchy.tray" && !e.groupId })
    return tray && sections.indexOf(tray.section) >= 0 ? tray.section : sections[sections.length - 1]
  }

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
  // Set while the editor moves focus itself, so a shelf gaining focus only
  // moves the cursor when Tab brought it there.
  property bool focusMoving: false

  readonly property string liftedKey: lifted ? lifted.instanceKey : ""
  readonly property var cursorItems: members(cursorCell.section, cursorCell.mode, liftedKey)
  readonly property var cursorRecord: lifted || cursorItems[cursorCell.pos] || null
  readonly property bool gridFocused: shelfShown.focusItem.activeFocus || shelfManaged.focusItem.activeFocus || shelfHidden.focusItem.activeFocus
    || shelfTray.focusItem.activeFocus
  readonly property var hints: lifted ? [
    { keys: sideBar ? "j k" : "h l", label: "Reorder" }, { keys: sideBar ? "h l" : "j k", label: "Shelf" },
    { keys: "space", label: "Drop" }, { keys: "esc", label: "Cancel" }
  ] : gridFocused ? [
    { keys: "h j k l", label: "Move" }, { keys: "space", label: "Pick up" },
    { keys: "x", label: "Hide" }, { keys: "enter", label: "Settings" },
    { keys: "tab shift+tab", label: "Next, previous tile" }, { keys: "1-3", label: "Pages" }, { keys: "esc", label: "Close" }
  ] : form.hints

  function shelfFor(mode) { return mode === "shown" ? shelfShown : mode === "managed" ? shelfManaged : mode === "tray" ? shelfTray : shelfHidden }
  function focusShelf(mode, reason) {
    focusMoving = true
    shelfFor(mode).focusItem.forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason)
    focusMoving = false
  }
  function focusFirst() { focusShelf(cursorCell.mode, Qt.TabFocusReason) }
  // Focus follows the cursor from shelf to shelf.
  function followCursor() {
    var mode = lifted && liftTarget ? liftTarget.mode : cursorCell.mode
    if (gridFocused && !shelfFor(mode).focusItem.activeFocus) focusShelf(mode)
  }
  // The column a zone has on another shelf; the tray's one column meets the
  // last zone, as j and k do.
  function columnOn(mode, section) {
    var cols = columnsFor(mode)
    return cols.indexOf(section) >= 0 ? section : cols[cols.length - 1]
  }
  function shelfFocusChanged(mode, focused) {
    if (focused) {
      if (focusMoving) return
      // Tab or Shift+Tab: the cursor (or the lifted widget) moves to this shelf.
      if (lifted) {
        // Only a tray icon can be carried into the tray's row.
        if (liftRows.indexOf(mode) < 0) return
        if (liftTarget && liftTarget.mode !== mode) liftTarget = { section: columnOn(mode, liftTarget.section), mode: mode, pos: 0 }
      } else if (cursorCell.mode !== mode) place({ section: columnOn(mode, cursorCell.section), mode: mode, pos: 0 })
      return
    }
    Qt.callLater(function() { if (!editor.gridFocused && editor.lifted && !editor.pointerLift) editor.cancel() })
  }

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
    for (var m = 0; m < rows.length; m++) for (var column of columnsFor(rows[m])) {
      var list = members(column, rows[m], "")
      for (var i = 0; i < list.length; i++) if (list[i].instanceKey === cursorKey) {
        cursorCell = { section: column, mode: rows[m], pos: i }
        return
      }
    }
    if (columnsFor(cursorCell.mode).indexOf(cursorCell.section) < 0) cursorCell = { section: columnOn(cursorCell.mode, cursorCell.section), mode: cursorCell.mode, pos: 0 }
    var n = count(cursorCell.section, cursorCell.mode)
    place({ section: cursorCell.section, mode: cursorCell.mode, pos: Math.max(0, Math.min(cursorCell.pos, n - 1)) })
  }
  // Deferred: entries can be re-evaluated lazily while cursorItems is being
  // computed, and moving the cursor there would change cursorItems' own input.
  // A Timer the editor owns, not a closure: it stops with the editor.
  onEntriesChanged: syncLater.restart()
  Timer { id: syncLater; interval: 0; onTriggered: editor.syncCursor() }

  function moveCursor(dx, dy) {
    if (lifted) liftTarget = Model.stepLift(count, liftTarget, dx, dy, columnsFor, liftRows)
    else place(Model.stepCursor(count, cursorCell, dx, dy, columnsFor, rows))
    followCursor()
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
    followCursor()
  }
  function drop() {
    if (!lifted) return
    var record = lifted, target = liftTarget, origin = liftOrigin
    var unchanged = target.section === origin.section && target.mode === origin.mode && target.pos === origin.pos
    var before = Model.dropBefore(members(target.section, target.mode, record.instanceKey), target.pos)
    lifted = null
    pointerLift = false
    cursorKey = record.instanceKey
    cursorCell = target
    if (unchanged) return
    // Out of the tray, back into it, or within it (the tray keeps its order).
    if (origin.mode === "tray") {
      if (target.mode !== "tray") cursorKey = preferences.takeFromTray(record, target.section, target.mode, before)
    } else if (target.mode === "tray") preferences.returnToTray(record)
    else preferences.move(record, target.section, target.mode, before)
  }
  // Keep an item's place in its zone when only its visibility changes.
  // Rows widgets were hidden from this session, so showing one again restores it.
  property var hiddenFrom: ({})
  function setPlacement(record, section, mode) {
    if (!record || (record.section === section && record.mode === mode)) return
    if (record.mode === "tray") {
      if (mode !== "tray") cursorKey = preferences.takeFromTray(record, section === "tray" ? trayZone : section, mode, -1)
      return
    }
    if (mode === "tray") { preferences.returnToTray(record); return }
    if (mode === "hidden" && record.mode !== "hidden") {
      var remembered = Object.assign({}, hiddenFrom)
      remembered[record.instanceKey] = record.mode
      hiddenFrom = remembered
    }
    var before = section !== record.section ? -1 : record.groupId ? record.index : record.index + 1
    cursorKey = record.instanceKey
    preferences.move(record, section, mode, before)
  }
  function keyPressed(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
    var key = event.key, t = event.text
    // Turned for a side bar, the zones run down and the shelves across:
    // h and l change shelf, j and k walk the zones.
    if (key === Qt.Key_Left || t === "h") sideBar ? moveCursor(0, -1) : moveCursor(-1, 0)
    else if (key === Qt.Key_Right || t === "l") sideBar ? moveCursor(0, 1) : moveCursor(1, 0)
    else if (key === Qt.Key_Up || t === "k") sideBar ? moveCursor(-1, 0) : moveCursor(0, -1)
    else if (key === Qt.Key_Down || t === "j") sideBar ? moveCursor(1, 0) : moveCursor(0, 1)
    else if (key === Qt.Key_Space) {
      if (lifted) drop()
      else lift(cursorRecord, cursorCell)
    } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
      if (lifted) drop()
      else if (cursorRecord) settingsTile.focusFirst()
    } else if (key === Qt.Key_Escape && lifted) cancel()
    else if ((t === "x" || key === Qt.Key_Delete) && !lifted && cursorRecord) {
      var r = cursorRecord
      setPlacement(r, r.section, Model.toggledHidden(r.mode, hiddenFrom[r.instanceKey]))
    } else if (t === "g" && !lifted && cursorRecord && cursorRecord.groupId)
      preferences.openGroup(cursorRecord.groupId)
    else return
    event.accepted = true
  }

  // Pointer hit testing in editor coordinates.
  function cellAt(point) {
    for (var i = 0; i < cellRepeater.count; i++) {
      var cell = cellRepeater.itemAt(i)
      if (!cell || !cell.visible) continue
      var p = cell.mapFromItem(editor, point.x, point.y)
      if (p.x >= 0 && p.y >= 0 && p.x < cell.width && p.y < cell.height) return cell
    }
    return null
  }
  function tileAt(point) {
    var cell = cellAt(point)
    if (!cell || !cell.tiles) return null
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
    for (var i = 0; cell.tiles && i < cell.tiles.count; i++) {
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
    if (cell && liftRows.indexOf(cell.mode) >= 0) {
      var next = { section: cell.section, mode: cell.mode, pos: gapAt(cell, point) }
      if (!liftTarget || next.section !== liftTarget.section || next.mode !== liftTarget.mode || next.pos !== liftTarget.pos) liftTarget = next
    }
  }

  PrefsForm {
    id: form
    anchors.fill: parent
    maxContentWidth: Infinity

    PrefsBento {
      id: bento
      Layout.fillWidth: true
      columns: editor.columns
      gap: editor.preferences.tileGap

      Shelf { id: shelfShown; mode: "shown" }
      Shelf { id: shelfManaged; mode: "managed" }
      Shelf { id: shelfHidden; mode: "hidden" }
      Shelf { id: shelfTray; mode: "tray" }
      Settings { id: settingsTile }
    }
  }

  // Which screen the shelves picture, when screens differ (a camera on one):
  // it changes the picture only, never the layout.
  ButtonGroup {
    // Parented only when shown, so the header keeps no empty slot.
    parent: editor.screensDiffer ? shelfShown.headerSlot : null
    options: editor.screens.map(function(s) { return { value: s.name, label: s.name + (editor.cameraOn(s) ? " (camera)" : "") } })
    value: editor.previewScreen ? editor.previewScreen.name : ""
    foreground: Commons.Color.popups.text
    background: "transparent"
    fontSize: Style.font.caption
    Accessible.name: "Preview"
    onChanged: function(value) { editor.previewName = value }
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

  // A zone's row on a side bar: its tallest cell on the three zone shelves.
  function rowHeight(zone) {
    var h = 0
    for (var i = 0; i < cellRepeater.count; i++) {
      var c = cellRepeater.itemAt(i)
      if (c && c.section === zone) h = Math.max(h, c.naturalWell)
    }
    return h
  }
  QtObject {
    id: cellRepeater
    property var cells: []
    readonly property int count: cells.length
    function itemAt(i) { return cells[i] }
    function register(cell) { cells = cells.concat([cell]) }
    function unregister(cell) { cells = cells.filter(function(c) { return c !== cell }) }
  }

  // -------------------------------------------------------------- components
  // One visibility: the five zones side by side, sized and packed as the bar
  // has them (one under another in a narrow window). On a side bar the editor
  // turns with it: the shelves stand side by side and the zones are rows,
  // each the height of its tallest cell. The shelf is a Tab stop; the cursor
  // lives in its cells.
  component Shelf: PrefsTile {
    id: shelf
    property string mode: "shown"
    property alias focusItem: shelfFocus
    readonly property bool stacked: editor.sideBar || shelfFocus.width < Style.space(560)
    readonly property var zoneColumns: mode === "tray" ? ["tray"] : editor.sections
    // The camera's slot between Left of center and Center, on a preview of a
    // screen that has one.
    readonly property bool camera: editor.previewCamera && !stacked && mode !== "tray"
    readonly property real cameraSlot: camera ? Style.space(24) : 0
    readonly property real gridWidth: Math.max(1, shelfFocus.width)
    // Shares of the row, mirrored about its middle: Right of center is as
    // wide as Left of center and the camera's slot together, so Center stays
    // on the middle and the two sides match on every shelf.
    function columnWidth(zone) {
      var free = gridWidth - bento.gap * (zoneColumns.length - 1) - 2 * cameraSlot
      var total = zoneColumns.reduce(function(sum, z) { return sum + editor.zoneShares[z] }, 0)
      return Math.max(1, free * editor.zoneShares[zone] / total + (zone === "centerEnd" ? cameraSlot : 0))
    }
    title: editor.shelfInfo[mode].title
    caption: editor.shelfInfo[mode].caption
    span12: editor.sideBar ? 3 : 12
    span6: editor.sideBar ? 3 : 6
    animate: editor.bar ? editor.bar.animationsEnabled : true
    borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, shelfFocus.activeFocus ? 0.28 : 0.1), 1)

    Item {
      id: shelfFocus
      readonly property bool ownsFocusRing: true
      Layout.fillWidth: true
      Layout.leftMargin: Math.round(Style.spacing.rowPaddingX / 2)
      Layout.rightMargin: Math.round(Style.spacing.rowPaddingX / 2)
      Layout.bottomMargin: Math.round(Style.spacing.rowPaddingX / 2)
      implicitHeight: shelfBody.implicitHeight
      activeFocusOnTab: true
      Accessible.role: Accessible.Table
      Accessible.name: shelf.title
      Accessible.description: editor.cursorRecord ? editor.preferences.title(editor.cursorRecord) : "Empty"
      Keys.onPressed: function(event) { editor.keyPressed(event) }
      onActiveFocusChanged: editor.shelfFocusChanged(shelf.mode, activeFocus)

      ColumnLayout {
        id: shelfBody
        width: parent.width
        spacing: Style.space(4)

        // The zones, named once, over the bar shelf, each where its items pack.
        Row {
          visible: shelf.mode === "shown" && !shelf.stacked
          Layout.fillWidth: true
          spacing: bento.gap
          Repeater {
            model: shelf.zoneColumns
            Text {
              required property string modelData
              width: shelf.columnWidth(modelData) + (modelData === "centerBegin" ? shelf.cameraSlot : 0)
              rightPadding: modelData === "centerBegin" ? shelf.cameraSlot : 0
              text: editor.zoneNames[modelData]
              textFormat: Text.PlainText
              color: editor.cursorCell.section === modelData ? Commons.Color.popups.text : Qt.alpha(Commons.Color.popups.text, 0.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: editor.cursorCell.section === modelData
              elide: Text.ElideRight
              horizontalAlignment: editor.zonePack(modelData) === "start" ? Text.AlignLeft : editor.zonePack(modelData) === "end" ? Text.AlignRight : Text.AlignHCenter
            }
          }
        }

        Item {
          Layout.fillWidth: true
          implicitHeight: zoneGrid.implicitHeight
          GridLayout {
            id: zoneGrid
            width: parent.width
            columns: shelf.stacked ? 1 : shelf.zoneColumns.length
            columnSpacing: bento.gap
            rowSpacing: Style.space(6)
            Repeater {
              model: shelf.zoneColumns
              Cell {
                required property string modelData
                section: modelData
                mode: shelf.mode
                caption: shelf.stacked && modelData !== "tray" ? editor.zoneNames[modelData] : ""
                // Turned, a zone's row is as tall as its tallest cell on any shelf.
                rowHeight: editor.sideBar ? editor.rowHeight(modelData) : 0
                Layout.fillWidth: shelf.stacked
                Layout.preferredWidth: shelf.stacked ? -1 : shelf.columnWidth(modelData)
                Layout.rightMargin: modelData === "centerBegin" ? shelf.cameraSlot : 0
                Layout.alignment: Qt.AlignTop
                Component.onCompleted: cellRepeater.register(this)
                Component.onDestruction: cellRepeater.unregister(this)
              }
            }
          }
          // The camera: a dark capsule on the bar shelf, a dotted seam below.
          Item {
            id: cameraMark
            visible: shelf.camera
            readonly property var cell: {
              for (var i = 0; i < cellRepeater.count; i++) {
                var c = cellRepeater.itemAt(i)
                if (c && c.mode === shelf.mode && c.section === "centerBegin") return c
              }
              return null
            }
            x: cell ? cell.x + cell.width + (shelf.cameraSlot + bento.gap - width) / 2 : 0
            y: 0
            width: Style.space(14)
            height: zoneGrid.height
            Rectangle {
              visible: shelf.mode === "shown"
              anchors.fill: parent
              radius: width / 2
              color: "black"
              border.width: 1
              border.color: Qt.alpha(Commons.Color.popups.text, 0.2)
            }
            Column {
              visible: shelf.mode !== "shown"
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(4)
              Repeater {
                model: Math.max(0, Math.floor(cameraMark.height / Style.space(8)))
                Rectangle { width: 1; height: Style.space(4); color: Qt.alpha(Commons.Color.popups.text, 0.3) }
              }
            }
          }
        }

        Text {
          visible: shelf.mode === "shown"
          Layout.fillWidth: true
          text: editor.barCaption
          textFormat: Text.PlainText
          color: Qt.alpha(Commons.Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }

      // Every pointer gesture over the shelf lands here, above the tiles, so a
      // drag survives the tiles being rebuilt as the preview moves. The press
      // keeps it across the other shelves.
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
        onExited: if (!editor.pointerLift) editor.hoverKey = ""
        onPressed: function(mouse) {
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
          editor.focusShelf(editor.cursorCell.mode, Qt.MouseFocusReason)
        }
        onReleased: {
          editor.pressed = null
          if (editor.pointerLift) editor.drop()
          editor.followCursor()
        }
        onCanceled: {
          editor.pressed = null
          if (editor.pointerLift) editor.cancel()
        }
        onDoubleClicked: if (editor.cursorRecord) settingsTile.focusFirst()
      }
    }
  }

  // One zone on one shelf: a well of widgets. On the bar shelf the zone is
  // drawn the way the bar draws it (ShelfModel): an island in the bar's own
  // surface, rounding and border, each widget in the slot the bar gives it, at
  // its own size. A zone longer than the well wraps onto another island rather
  // than shrinking. The other shelves list icon and name.
  component Cell: Item {
    id: cell
    property string section: ""
    property string mode: ""
    property string caption: ""
    // At least this tall, to line up with the zone's cells on other shelves.
    property real rowHeight: 0
    readonly property var tiles: content.item ? content.item.repeater : null
    readonly property var list: editor.cellList(section, mode)
    readonly property bool barRow: mode === "shown"
    readonly property bool targeted: !!editor.lifted && !!editor.liftTarget
      && editor.liftTarget.section === section && editor.liftTarget.mode === mode
    readonly property bool cursorHere: !editor.lifted && editor.cursorCell.section === section && editor.cursorCell.mode === mode
    readonly property real pad: Style.space(4)
    readonly property real radius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2))
    readonly property string pack: editor.zonePack(section)
    // The bar shelf: every widget's face, and where the bar would put it.
    readonly property var faces: barRow ? list.map(function(value) { return editor.barFace(value.record) }) : []
    readonly property var layout: barRow ? ShelfModel.zone(CellModel, editor.barTokens, faces, Math.max(1, well.width - pad * 2)) : ({ lines: [], width: 0 })
    readonly property real lineGap: Style.space(4)
    // Each line packs from the side its zone grows from (editor.zonePack).
    function lineX(n) {
      var w = layout.lines[n] ? layout.lines[n].width : 0
      return pack === "start" ? pad : pack === "end" ? well.width - pad - w : (well.width - w) / 2
    }
    function lineY(n) {
      var spare = well.height - naturalWell
      return pad + n * (editor.barThickness + lineGap) + (pack === "start" ? 0 : pack === "end" ? spare : spare / 2)
    }
    readonly property real naturalWell: barRow
      ? Math.max(1, layout.lines.length) * (editor.barThickness + lineGap) - lineGap + pad * 2
      : Math.max(Style.space(42), (content.item ? content.item.height : 0) + pad * 2)
    function slotRect(index) {
      var at = ShelfModel.slotOf(layout, index)
      return at ? { x: lineX(at.line) + at.slot.x, y: lineY(at.line) } : { x: 0, y: 0 }
    }
    implicitHeight: (captionText.visible ? captionText.implicitHeight + Style.space(3) : 0) + well.height

    Text {
      id: captionText
      visible: cell.caption !== ""
      width: parent.width
      text: cell.caption
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
    BorderSurface {
      id: well
      y: captionText.visible ? captionText.implicitHeight + Style.space(3) : 0
      width: parent.width
      height: Math.max(cell.naturalWell, cell.rowHeight)
      radius: cell.radius
      color: Qt.alpha(Commons.Color.popups.text, 0.04)
      // An empty well waiting for a drop is outlined the way the bar outlines
      // a landing place.
      borderSpec: cell.targeted && cell.list.length === 1 ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.45), 1) : Border.none()
      Behavior on height { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      Text {
        anchors.centerIn: parent
        visible: cell.list.length === 0 && cell.cursorHere && editor.gridFocused
        text: "Empty"
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      BorderSurface {
        anchors.fill: parent
        anchors.margins: Style.space(3)
        visible: cell.list.length === 0 && cell.cursorHere && editor.gridFocused
        color: "transparent"
        radius: Math.max(0, cell.radius - Style.space(3))
        borderSpec: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
      }

      Loader {
        id: content
        sourceComponent: cell.barRow ? barStrip : chipFlow
      }
    }

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
          face: cell.barRow ? cell.faces[retainedRecord.index] || null : null
          maxWidth: Math.max(1, well.width - cell.pad * 2)
          x: cell.barRow ? cell.slotRect(retainedRecord.index).x : 0
          y: cell.barRow ? cell.slotRect(retainedRecord.index).y : 0
        }
      }
    }

    Component {
      id: barStrip
      Item {
        property alias repeater: barTiles
        width: well.width
        height: well.height
        Repeater {
          model: cell.layout.lines
          BorderSurface {
            required property var modelData
            required property int index
            x: cell.lineX(index)
            y: cell.lineY(index)
            width: modelData.width
            height: editor.barThickness
            color: editor.barSurface
            radius: Math.min(editor.bar.islandRounding, editor.barThickness / 2)
            borderSpec: editor.bar.islands ? editor.bar.islandBorder : Border.none()
          }
        }
        Repeater { id: barTiles; model: tileList.model }
      }
    }
    Component {
      id: chipFlow
      Flow {
        property alias repeater: chipTiles
        x: cell.pad
        y: cell.pad
        width: Math.max(1, well.width - cell.pad * 2)
        spacing: Style.space(4)
        Repeater { id: chipTiles; model: tileList.model }
      }
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
    // On the bar shelf: how the bar draws this widget (editor.barFace).
    property var face: null
    // A narrow well elides the name to fit.
    property real maxWidth: Infinity
    readonly property bool isCursor: !ghost && !editor.lifted && editor.cursorKey !== "" && record.instanceKey === editor.cursorKey
    readonly property bool hovered: !ghost && !editor.lifted && editor.hoverKey === record.instanceKey
    readonly property var group: record.groupId ? editor.bar.groups.find(function(g) { return g.id === record.groupId }) || null : null
    readonly property int memberCount: group ? group.items.length : 0
    readonly property bool onBar: mode === "shown"
    readonly property var barFace: onBar ? face || editor.barFace(record) : null
    // The slot the bar gives this widget, and its highlight (CellModel).
    readonly property var placed: barFace ? CellModel.place(editor.barTokens, barFace.inkLength, barFace.glyph, barFace.cap) : null
    readonly property real faceOffset: placed ? placed.inkStart - barFace.inkStart : 0
    // Press feedback: the tile dips while the pointer holds it, before a drag.
    readonly property bool pressedDown: !ghost && !placeholder && !!editor.pressed && !editor.pointerLift
      && editor.pressed.record.instanceKey === record.instanceKey
    scale: pressedDown ? 0.97 : 1
    Behavior on scale { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    implicitWidth: onBar ? (placed ? placed.extent : 0) : chip.implicitWidth + Style.space(16)
    implicitHeight: onBar ? editor.barThickness : Math.max(Style.spacing.controlHeight, chip.implicitHeight + Style.space(8))
    width: implicitWidth
    height: implicitHeight
    opacity: mode === "hidden" && !placeholder && !ghost ? 0.62 : ghost ? 0.9 : 1

    // On the bar: the bar's own highlight, the cell centred on the slot and
    // inset from the island; a landing place is outlined as on the bar.
    BorderSurface {
      visible: tile.onBar
      x: tile.placed ? (tile.placed.extent - tile.placed.cell) / 2 : 0
      y: editor.barTokens.inset
      width: tile.placed ? tile.placed.cell : 0
      height: editor.barTokens.thickness
      radius: CellModel.radius(editor.barTokens, editor.bar.islandRounding)
      color: tile.placeholder ? "transparent"
        : tile.ghost ? editor.barSurface
        : tile.isCursor && editor.gridFocused ? Style.focusFillFor(editor.barInk, Commons.Color.accent)
        : tile.isCursor ? Style.selectedFillFor(editor.barInk, Commons.Color.accent)
        : tile.hovered ? Style.hoverFillFor(editor.barInk, Commons.Color.accent)
        : "transparent"
      borderSpec: tile.placeholder || tile.ghost ? Border.flat(Qt.alpha(editor.barInk, 0.45), 1)
        : tile.isCursor && editor.gridFocused ? Border.controlSpec("focus", editor.barInk, Commons.Color.accent)
        : Border.none()
      Behavior on color { enabled: editor.bar.animationsEnabled; ColorAnimation { duration: 90 } }
    }
    BarFace {
      visible: tile.onBar && !tile.placeholder && !!tile.barFace
      x: tile.faceOffset
      face: tile.onBar && !tile.placeholder ? tile.barFace : null
      barThickness: editor.barThickness
      ink: editor.barInk
      fontFamily: editor.barFont
    }

    // Elsewhere: a chip with the widget's icon and name.
    BorderSurface {
      visible: !tile.onBar
      anchors.fill: parent
      radius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2))
      color: tile.placeholder ? "transparent"
        : tile.ghost ? Commons.Color.popups.background
        : tile.isCursor && editor.gridFocused ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)
        : tile.isCursor ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent)
        : tile.hovered ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent)
        : Qt.alpha(Commons.Color.popups.text, 0.06)
      borderSpec: tile.placeholder || tile.ghost ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.45), 1)
        : tile.isCursor && editor.gridFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
        : tile.isCursor ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1)
        : Border.none()
      Behavior on color { enabled: editor.bar.animationsEnabled; ColorAnimation { duration: 90 } }
    }
    Row {
      id: chip
      visible: !tile.onBar
      anchors.centerIn: parent
      spacing: Style.space(6)
      opacity: tile.placeholder ? 0 : 1
      Item {
        width: rowIcon.width + (tile.backed ? Style.space(4) : 0)
        height: rowIcon.height + (tile.backed ? Style.space(2) : 0)
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
          anchors.fill: parent
          visible: tile.backed
          radius: Style.space(3)
          color: Commons.Color.popups.text
        }
        WidgetIcon {
          id: rowIcon
          anchors.centerIn: parent
          preferences: editor.preferences
          record: tile.record
          size: Math.round(editor.iconSize * 0.85)
          maxAspect: 3.2
        }
      }
      Text {
        id: nameLabel
        text: tile.record.instanceKey ? editor.preferences.title(tile.record) : ""
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        width: Math.max(Style.space(24), Math.min(implicitWidth, Style.space(190),
          tile.maxWidth - Style.space(16) - rowIcon.width - chip.spacing
            - (tile.memberCount > 0 ? memberLabel.implicitWidth + chip.spacing : 0)))
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        id: memberLabel
        visible: tile.memberCount > 0
        text: tile.memberCount
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    // Widget images in the bar's text colour that barely show on the
    // Preferences background get a backing (editor.inkBacked).
    readonly property bool backed: editor.inkBacked && rowIcon.hasImage
  }

  // The selected widget's settings, titled with its name. Zone and Visibility
  // move it without dragging; a setting that does not apply dims with its
  // reason rather than disappearing, so nothing jumps as the cursor moves.
  component Settings: PrefsTile {
    id: panel
    readonly property var record: editor.lifted ? null : editor.cursorRecord
    readonly property bool isGroup: !!record && !!record.groupId
    readonly property var group: isGroup ? editor.bar.groups.find(function(g) { return g.id === record.groupId }) || null : null
    // A tray icon, and whether it is still in Omarchy's tray.
    readonly property bool trayIcon: !!record && !!record.trayItem
    readonly property bool inTray: !!record && record.mode === "tray"
    function focusFirst() {
      var next = bento.firstControl(panel)
      if (next) next.forceActiveFocus(Qt.TabFocusReason)
    }
    title: record ? editor.preferences.title(record) : "Nothing selected"
    caption: isGroup ? (group ? group.items.length + (group.items.length === 1 ? " widget" : " widgets") + " in this group" : "")
      : trayIcon ? (inTray ? "In Omarchy's tray" : "Moved out of Omarchy's tray") : record ? record.id : ""
    span12: 12
    span6: 6
    animate: editor.bar ? editor.bar.animationsEnabled : true

    Text {
      visible: !panel.record
      Layout.fillWidth: true
      Layout.leftMargin: Style.spacing.rowPaddingX
      Layout.rightMargin: Style.spacing.rowPaddingX
      Layout.bottomMargin: Style.space(6)
      text: editor.lifted ? "Moving " + editor.preferences.title(editor.lifted) + ". Space drops it, Esc puts it back."
        : editor.cursorCell.mode === "tray" ? "Nothing in the tray. Apps put their icons here while they run."
        : "Nothing " + (editor.cursorCell.mode === "shown" ? "on the bar in " : editor.cursorCell.mode === "managed" ? "on demand in " : "hidden in ")
          + editor.zoneNames[editor.cursorCell.section] + " yet. Pick up a widget with Space, or drag one here."
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    GridLayout {
      visible: !!panel.record
      Layout.fillWidth: true
      Layout.leftMargin: Style.spacing.rowPaddingX
      Layout.rightMargin: Style.spacing.rowPaddingX
      Layout.bottomMargin: Style.space(4)
      id: settingsGrid
      columns: editor.columns === 12 ? 3 : editor.columns === 6 ? 2 : 1
      // Zone and Visibility sit beside their label when the column has room.
      readonly property bool roomy: (width - columnSpacing * (columns - 1)) / columns >= Style.space(340)
      columnSpacing: Style.space(20)
      rowSpacing: Style.space(8)
      // Esc returns to the shelf; an open dropdown takes it first.
      Keys.onPressed: function(event) {
        if (event.key !== Qt.Key_Escape) return
        editor.focusShelf(editor.cursorCell.mode, Qt.OtherFocusReason)
        event.accepted = true
      }

      // Where it is: the way to move it without dragging.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(2)
        PrefsZoneMap {
          compact: true
          stacked: !settingsGrid.roomy
          Layout.leftMargin: 0
          zones: editor.zoneChoices
          cameraAfter: editor.previewCamera ? "centerBegin" : ""
          noteFor: function(zone) { return editor.cameraNote(zone) }
          marker: Component {
            WidgetIcon {
              preferences: editor.preferences
              record: panel.record || ({})
              size: Math.round(editor.iconSize * 0.6)
              maxAspect: 1.6
            }
          }
          value: panel.record && !panel.inTray ? panel.record.section : ""
          // Out of the tray, an icon waits on demand until placed otherwise.
          onChosen: function(value) { editor.setPlacement(panel.record, value, panel.inTray ? "managed" : panel.record.mode) }
        }
        PrefsChoice {
          compact: true
          // A tray icon's fourth choice needs the row to itself.
          stacked: !settingsGrid.roomy || panel.trayIcon
          Layout.leftMargin: 0
          label: "Visibility"
          options: [{ value: "shown", label: "On the bar" }, { value: "managed", label: "On demand" }, { value: "hidden", label: "Hidden" }]
            .concat(panel.trayIcon ? [{ value: "tray", label: "In the tray" }] : [])
          value: panel.record ? panel.record.mode : ""
          onChosen: function(value) { editor.setPlacement(panel.record, panel.record.section, value) }
        }
        Hint {
          visible: panel.inTray
          Layout.leftMargin: Style.spacing.rowPaddingX
          text: "Placed on the bar, it leaves the tray and works as it does there: click, right-click menu, scroll"
        }
        // Opens its panel (a group: its drawer) from anywhere.
        ShortcutRow {
          visible: !panel.inTray
          padding: 0
          store: editor.preferences.shortcuts
          target: !panel.record ? "" : panel.isGroup ? "group:" + panel.record.groupId : "widget:" + panel.record.id
          unavailable: !panel.record ? ""
            : panel.record.mode === "hidden" ? (panel.isGroup ? "Hidden groups can't open" : "Hidden widgets can't open")
            : panel.isGroup || editor.bar.findPanelWidget(panel.record.id) || store.ready && store.info(target).keys ? ""
            : "Nothing to open"
        }
      }

      // How it behaves on the bar.
      ColumnLayout {
        visible: !panel.isGroup && !panel.inTray
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 0
        PrefsToggle {
          id: activityToggle
          readonly property bool clockDriven: !!panel.record && !!editor.bar.quietActivityId(panel.record.id)
          compact: true
          label: "Show on activity"
          enabled: editor.bar.autoHide && editor.bar.autoHideActivity && !clockDriven
          opacity: enabled ? 1 : 0.45
          checked: !!panel.record && !clockDriven && editor.bar.activityPeeksFor(panel.record.instanceKey, panel.record.id)
          onToggled: function(checked) { editor.bar.setActivityPeek(panel.record.instanceKey, checked) }
        }
        Hint {
          Layout.leftMargin: Style.spacing.rowPaddingX
          dim: !activityToggle.enabled
          text: activityToggle.clockDriven ? "It changes on a clock, so it never brings the bar out"
            : !editor.bar.autoHide ? "Applies while the bar autohides"
            : !editor.bar.autoHideActivity ? "Turned off for every widget on the Bar page"
            : "Slide the bar out briefly when it changes"
        }
      }

      // A group's members, by their faces.
      ColumnLayout {
        visible: panel.isGroup
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(4)
        Text {
          text: "Members"
          textFormat: Text.PlainText
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Flow {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Repeater {
            model: panel.group ? panel.group.items : []
            WidgetIcon {
              required property string modelData
              preferences: editor.preferences
              record: editor.preferences.entries.find(function(e) { return e.instanceKey === modelData }) || ({})
              size: Math.round(editor.iconSize * 0.85)
            }
          }
        }
      }

      // Its group.
      ColumnLayout {
        visible: !panel.inTray
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(4)
        Text {
          text: "Group"
          textFormat: Text.PlainText
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Dropdown {
          visible: !panel.isGroup
          Layout.fillWidth: true
          label: "Group"
          showLabel: false
          options: [{ value: "", label: "Not grouped" }].concat(editor.bar.groups.map(function(g) { return { value: g.id, label: g.label } }))
          value: ""
          onChanged: function(value) { if (value && panel.record) editor.bar.assignGroup(panel.record.instanceKey, value, "") }
        }
        Hint {
          dim: false
          text: panel.isGroup ? "Its face, badge and members are set on the Groups page." : "A grouped widget moves into its group's drawer."
        }
        Button {
          visible: panel.isGroup
          text: "Edit group"
          iconText: "󰏫"
          focusable: true
          bordered: true
          foreground: Commons.Color.popups.text
          onClicked: editor.preferences.openGroup(panel.record.groupId)
        }
      }
    }
  }

  component Hint: Text {
    property bool dim: false
    Layout.fillWidth: true
    textFormat: Text.PlainText
    color: Qt.alpha(Commons.Color.popups.text, dim ? 0.35 : 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
