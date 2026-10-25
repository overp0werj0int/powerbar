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

// The bar's layout as layers (docs/behavior/preferences.md PREFS-99): one per
// visibility (On the bar, On demand, Hidden) and the tray, each holding the
// five zones in columns of one width that line up from layer to layer, Center
// on the screen's middle (under the camera on a notched screen), then a tile
// with the selected widget's settings. The layers tilt back like the bar
// exploded into its parts; the cursor's layer lies nearly flat. Preferences
// draws the bar horizontally whatever edge it is on; the zones are named by
// where they are on screen.
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
  // The screen the shelves picture: the bar is the same on every screen, but
  // a camera moves the center. Preferences' own screen unless another is picked.
  property string previewName: ""
  readonly property var screens: Quickshell.screens
  readonly property var previewScreen: screens.find(function(s) { return s.name === previewName }) || preferences.targetScreen || screens[0] || null
  function cameraOn(screen) { return !!bar && !sideBar && !!screen && !!bar.notchFor(screen) }
  readonly property bool previewCamera: cameraOn(previewScreen)
  readonly property var previewNotch: previewCamera ? bar.notchFor(previewScreen) : null
  // How far the layers tilt back, the cursor's layer, and the eye's distance
  // to them (Qt's Rotation.distanceToPlane), in degrees and px.
  readonly property real layerTilt: 32
  readonly property real nearTilt: 8
  readonly property real planeDistance: Style.space(1400)
  // The layer that lies nearly flat: the cursor's, or where the lifted widget
  // would land. A pointer drag keeps the one it started on, so no layer
  // changes height under the pointer.
  property string frozenNear: "shown"
  readonly property string nearMode: pointerLift ? frozenNear : activeCell.mode
  // The well being worked on: where the lifted widget would land, else the
  // cursor's. Its zone's captions read brighter on every layer.
  readonly property var activeCell: lifted && liftTarget ? liftTarget : cursorCell
  // Every badge has one width, the width a zone's well leaves.
  readonly property real chipWidth: Math.max(Style.space(80), shelfShown.columnWidth - 2 * Style.space(4))
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
  readonly property var zoneChoices: sections.map(function(s) { return { value: s, label: editor.zoneNames[s], share: 1 } })
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
    managed: { title: "On demand", caption: editor.bar && editor.bar.onDemandInline
      ? "Behind the zone's dots; shown on activity, or when you hover the dots"
      : editor.bar && editor.bar.onDemandMenu
      ? "In a menu from the zone's dots; shown briefly on activity"
      : "In the zone's drawer when you hover it, or briefly on activity" },
    hidden: { title: "Hidden", caption: "Kept off the bar" },
    tray: { title: "In the tray", caption: "Omarchy's tray icons. Drag one onto a layer above to place it like a widget" }
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
    { keys: "j k", label: "Move along, across layers" }, { keys: "h l", label: "Zone" },
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
    var mode = activeCell.mode
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
    if (lifted) liftTarget = Model.stepLayerLift(count, liftTarget, dx, dy, columnsFor, liftRows)
    else place(Model.stepLayer(count, cursorCell, dx, dy, columnsFor, rows))
    followCursor()
  }
  function lift(record, cell) {
    if (!record) return
    frozenNear = cell.mode
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
    // The layers are always drawn across: h and l change zone, j and k walk
    // a zone's list and go on to the next layer at its ends.
    if (key === Qt.Key_Left || t === "h") moveCursor(-1, 0)
    else if (key === Qt.Key_Right || t === "l") moveCursor(1, 0)
    else if (key === Qt.Key_Up || t === "k") moveCursor(0, -1)
    else if (key === Qt.Key_Down || t === "j") moveCursor(0, 1)
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
  // The gap under the pointer: before the first real badge whose middle the
  // pointer has not passed, reading the well top to bottom.
  function gapAt(cell, point) {
    var pos = 0
    for (var i = 0; cell.tiles && i < cell.tiles.count; i++) {
      var tile = cell.tiles.itemAt(i)
      if (!tile || tile.placeholder) continue
      var p = tile.mapFromItem(editor, point.x, point.y)
      if (p.y < tile.height / 2) return pos
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

  // The dragged item follows the pointer while its landing place is previewed,
  // flat and one badge wide whichever layer it is over.
  Tile {
    visible: editor.pointerLift && !!editor.lifted
    record: editor.lifted || ({})
    mode: editor.liftTarget ? editor.liftTarget.mode : "managed"
    ghost: true
    x: editor.pointer.x - width / 2
    y: editor.pointer.y - height / 2
    z: 100
  }

  // A badge's full name, icon and id, flat over the layers, after a short
  // rest on it; once one has shown, the next shows at once (PREFS-100).
  property Item hoverTile: null
  property bool tipWarm: false
  function hoverOn(tile) {
    if (tile === hoverTile) return
    hoverTile = tile
    if (!tile || lifted) { nameTip.shown = false; tipDelay.stop(); if (tipWarm) tipCool.restart(); return }
    tipCool.stop()
    if (tipWarm) showTip()
    else { nameTip.shown = false; tipDelay.restart() }
  }
  function showTip() {
    var tile = hoverTile
    if (!tile || lifted || !tile.record || !tile.record.instanceKey) return
    nameTip.record = tile.record
    var below = tile.mapToItem(editor, tile.width / 2, tile.height)
    var above = tile.mapToItem(editor, tile.width / 2, 0)
    var gap = Style.space(6)
    nameTip.x = Math.max(0, Math.min(editor.width - nameTip.width, below.x - nameTip.width / 2))
    nameTip.y = below.y + gap + nameTip.height <= editor.height ? below.y + gap : above.y - gap - nameTip.height
    nameTip.shown = true
    tipWarm = true
  }
  Timer { id: tipDelay; interval: 450; onTriggered: editor.showTip() }
  Timer { id: tipCool; interval: 600; onTriggered: editor.tipWarm = false }
  onLiftedChanged: if (lifted) hoverOn(null)
  BorderSurface {
    id: nameTip
    property bool shown: false
    property var record: ({})
    z: 110
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    width: tipRow.implicitWidth + Style.space(20)
    height: tipRow.implicitHeight + Style.space(12)
    radius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2))
    color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, 1)
    Row {
      id: tipRow
      anchors.centerIn: parent
      spacing: Style.space(8)
      InkIcon { record: nameTip.record; anchors.verticalCenter: parent.verticalCenter }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: nameTip.record && nameTip.record.instanceKey ? editor.preferences.title(nameTip.record) : ""
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: nameTip.record ? nameTip.record.groupId ? "Group" : nameTip.record.id || "" : ""
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
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
  // One visibility as a layer of the bar (PREFS-99): the five zones as wells
  // of one width, mirrored about the screen's middle with Center on it, so
  // on a notched screen Center sits under the camera and without one in its
  // own place. The layer tilts back about its middle line, which keeps its
  // width, so Center's axis stays on the camera's; the cursor's layer lies
  // nearly flat to be read. In a narrow window the zones stack, flat. The
  // layer is a Tab stop; the cursor lives in its wells.
  component Shelf: PrefsTile {
    id: shelf
    property string mode: "shown"
    property alias focusItem: shelfFocus
    readonly property bool stacked: shelfFocus.width < Style.space(560)
    readonly property var zoneColumns: mode === "tray" ? ["tray"] : editor.sections
    // The camera over Center, on a preview of a screen that has one; the
    // other layers darken Center below it.
    readonly property bool camera: editor.previewCamera && !stacked && mode !== "tray"
    readonly property real tilt: stacked ? 0 : editor.nearMode === mode ? editor.nearTilt : editor.layerTilt
    // The screen's middle (the camera's axis) in the layer: measured, since
    // the card or a scroll bar may sit it off the layer's own middle.
    property real axis: shelfFocus.width / 2
    function measureAxis() {
      var win = shelfFocus.Window.window
      if (!win || shelfFocus.width <= 0) return
      var x = shelfFocus.mapFromItem(null, win.width / 2, 0).x
      axis = Math.abs(x - shelfFocus.width / 2) < shelfFocus.width * 0.1 ? x : shelfFocus.width / 2
    }
    readonly property var geometry: Model.layerColumns(shelfFocus.width, bento.gap, axis, zoneColumns.length)
    readonly property real columnWidth: stacked ? shelfFocus.width : geometry.width
    // Every well on the layer is as tall as its tallest.
    readonly property real wellHeight: {
      var h = 0
      for (var i = 0; i < cellRepeater.count; i++) {
        var c = cellRepeater.itemAt(i)
        if (c && c.mode === mode) h = Math.max(h, c.naturalWell)
      }
      return h
    }
    title: editor.shelfInfo[mode].title
    caption: editor.shelfInfo[mode].caption
    span12: 12
    span6: 6
    animate: editor.bar ? editor.bar.animationsEnabled : true
    color: "transparent"
    borderSpec: shelfFocus.activeFocus ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.22), 1) : Border.none()

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
      onWidthChanged: Qt.callLater(shelf.measureAxis)
      onVisibleChanged: if (visible) Qt.callLater(shelf.measureAxis)
      Component.onCompleted: Qt.callLater(shelf.measureAxis)

      ColumnLayout {
        id: shelfBody
        width: parent.width
        spacing: Style.space(4)

        // The layer, tilted; this box keeps the room its tilted picture takes.
        Item {
          id: layerBox
          Layout.fillWidth: true
          Layout.topMargin: shelf.camera && shelf.mode === "shown" ? cameraMark.height : 0
          readonly property var extent: Model.tiltedExtent(layer.height, tiltRotation.angle, editor.planeDistance)
          implicitHeight: extent.above + extent.below
          Item {
            id: layer
            width: parent.width
            height: zoneFlow.height
            y: layerBox.extent.above - height / 2
            transform: Rotation {
              id: tiltRotation
              axis { x: 1; y: 0; z: 0 }
              origin.x: shelf.axis
              origin.y: layer.height / 2
              distanceToPlane: editor.planeDistance
              angle: shelf.tilt
              Behavior on angle { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
            Flow {
              id: zoneFlow
              x: shelf.stacked ? 0 : shelf.geometry.xs[0]
              width: shelf.stacked ? layer.width : shelf.zoneColumns.length * (shelf.columnWidth + bento.gap) - bento.gap
              spacing: bento.gap
              Repeater {
                model: shelf.zoneColumns
                Cell {
                  required property string modelData
                  section: modelData
                  mode: shelf.mode
                  caption: modelData !== "tray" ? editor.zoneNames[modelData] : ""
                  width: shelf.columnWidth
                  wellHeight: shelf.stacked ? 0 : shelf.wellHeight
                  shaft: shelf.camera && modelData === "center"
                  Component.onCompleted: cellRepeater.register(this)
                  Component.onDestruction: cellRepeater.unregister(this)
                }
              }
            }
            // The camera, over Center on the bar's layer: the screen's own
            // notch width, hanging over the layer's top edge.
            Rectangle {
              id: cameraMark
              visible: shelf.camera && shelf.mode === "shown"
              width: Math.min(shelf.columnWidth, editor.previewNotch ? editor.previewNotch.width : 0)
              height: Style.space(12)
              x: shelf.axis - width / 2
              y: -height
              color: "black"
              topLeftRadius: 0
              topRightRadius: 0
              bottomLeftRadius: Style.space(6)
              bottomRightRadius: Style.space(6)
            }
          }
        }

        Text {
          visible: shelf.mode === "shown"
          Layout.fillWidth: true
          Layout.topMargin: Style.space(4)
          text: editor.barCaption
          textFormat: Text.PlainText
          color: Qt.alpha(Commons.Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }

      // Every pointer gesture over the layer lands here, above the badges, so
      // a drag survives them being rebuilt as the preview moves. Points map
      // through the tilt to the badges. The press keeps it across the other
      // layers.
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
            editor.hoverOn(pressed ? null : tile)
          }
          if (pressed && editor.pressed && !editor.pointerLift
              && Math.abs(point.x - editor.pressPoint.x) + Math.abs(point.y - editor.pressPoint.y) > Style.space(6)) {
            editor.lift(editor.pressed.record, editor.pressed.cell)
            editor.pointerLift = true
          }
          editor.pointerMoved(point)
        }
        onExited: {
          if (!editor.pointerLift) editor.hoverKey = ""
          editor.hoverOn(null)
        }
        onPressed: function(mouse) {
          editor.hoverOn(null)
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

  // One zone on one layer: a well of badges, one under another in bar order,
  // its zone named at the top. A darker edge under it gives the layer its
  // thickness; under the camera the well is darker still (shaft).
  component Cell: Item {
    id: cell
    property string section: ""
    property string mode: ""
    property string caption: ""
    // At least this tall, to line up with the other wells of its layer.
    property real wellHeight: 0
    property bool shaft: false
    readonly property var tiles: chipTiles
    readonly property var list: editor.cellList(section, mode)
    readonly property bool targeted: !!editor.lifted && !!editor.liftTarget
      && editor.liftTarget.section === section && editor.liftTarget.mode === mode
    readonly property bool cursorHere: !editor.lifted && editor.cursorCell.section === section && editor.cursorCell.mode === mode
    readonly property real pad: Style.space(4)
    readonly property real radius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2))
    readonly property real captionHeight: caption !== "" ? captionText.implicitHeight + Style.space(4) : 0
    readonly property real naturalWell: Math.max(Style.space(42), captionHeight + chipColumn.implicitHeight + pad * 2)
    height: well.height

    Rectangle {
      y: Style.space(3)
      width: parent.width
      height: well.height
      radius: cell.radius
      color: Qt.rgba(0, 0, 0, 0.35)
    }
    BorderSurface {
      id: well
      width: parent.width
      height: Math.max(cell.naturalWell, cell.wellHeight)
      radius: cell.radius
      color: Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1),
        cell.shaft ? Qt.rgba(0, 0, 0, 0.45) : Qt.alpha(Commons.Color.popups.text, 0.05))
      // An empty well waiting for a drop is outlined the way the bar outlines
      // a landing place.
      borderSpec: cell.targeted && cell.list.length === 1 ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.45), 1)
        : Border.flat(Qt.alpha(Commons.Color.popups.text, 0.08), 1)
      Behavior on height { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      Text {
        id: captionText
        visible: cell.caption !== ""
        x: cell.pad + Style.space(2)
        y: cell.pad
        width: well.width - x - cell.pad
        text: cell.caption
        textFormat: Text.PlainText
        color: editor.activeCell.section === cell.section ? Commons.Color.popups.text : Qt.alpha(Commons.Color.popups.text, 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: editor.activeCell.section === cell.section && editor.activeCell.mode === cell.mode
        elide: Text.ElideRight
      }
      Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: cell.captionHeight / 2
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
      Column {
        id: chipColumn
        x: cell.pad
        y: cell.pad + cell.captionHeight
        width: Math.max(1, well.width - cell.pad * 2)
        spacing: Style.space(3)
        Repeater { id: chipTiles; model: tileList.model }
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
          width: chipColumn.width
        }
      }
    }
  }

  // A widget's icon in a square the size of a badge's icon: the middle of
  // its ink, so a wide widget (workspaces, a clock with its date) shows its
  // middle and nothing sticks out of the square.
  component InkIcon: Item {
    id: inkIcon
    property var record: ({})
    readonly property real box: Math.round(editor.iconSize * 0.7)
    readonly property bool hasImage: picture.hasImage
    readonly property var face: record && record.instanceKey ? editor.barFace(record) : null
    width: box
    height: box
    // Widget images in the bar's text colour that barely show on the
    // Preferences background get a backing (editor.inkBacked).
    Rectangle {
      anchors.fill: parent
      anchors.margins: -Style.space(2)
      visible: editor.inkBacked && picture.hasImage
      radius: Style.space(3)
      color: Commons.Color.popups.text
    }
    // A wide face shows its first glyph only: about the bar icon's own width.
    readonly property bool wide: {
      var f = face
      return hasImage && !!f && f.kind === "image" && f.w > 0 && f.inkLength / f.w * picture.width > box
    }
    Item {
      width: inkIcon.wide ? Math.round(inkIcon.box * 0.62) : parent.width
      height: parent.height
      clip: true
      WidgetIcon {
        id: picture
        preferences: editor.preferences
        record: inkIcon.record
        size: inkIcon.box
        maxAspect: 8
        anchors.verticalCenter: parent.verticalCenter
        x: {
          var f = inkIcon.face
          if (!hasImage || !f || f.kind !== "image" || !(f.w > 0)) return Math.round((inkIcon.box - width) / 2)
          // Ink wider than the box starts at its leading icon, not mid-word.
          var scale = width / f.w
          if (inkIcon.wide) return Math.round(-f.inkStart * scale)
          return Math.round(inkIcon.box / 2 - (f.inkStart + f.inkLength / 2) * scale)
        }
      }
    }
  }

  // A badge: the widget's icon and its name, elided, one width everywhere.
  component Tile: Item {
    id: tile
    property var record: ({})
    property bool placeholder: false
    property bool ghost: false
    property string section: ""
    property string mode: ""
    property int pos: 0
    readonly property bool isCursor: !ghost && !editor.lifted && editor.cursorKey !== "" && record.instanceKey === editor.cursorKey
    readonly property bool hovered: !ghost && !editor.lifted && editor.hoverKey === record.instanceKey
    readonly property var group: record.groupId ? editor.bar.groups.find(function(g) { return g.id === record.groupId }) || null : null
    readonly property int memberCount: group ? group.items.length : 0
    // Press feedback: the badge dips while the pointer holds it, before a drag.
    readonly property bool pressedDown: !ghost && !placeholder && !!editor.pressed && !editor.pointerLift
      && editor.pressed.record.instanceKey === record.instanceKey
    scale: pressedDown ? 0.97 : 1
    Behavior on scale { enabled: editor.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    width: editor.chipWidth
    height: Math.max(Style.space(26), chip.implicitHeight + Style.space(8))
    opacity: mode === "hidden" && !placeholder && !ghost ? 0.62 : ghost ? 0.9 : 1

    BorderSurface {
      anchors.fill: parent
      radius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2) - Style.space(2))
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
      x: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
      // A keyboard lift shows what it carries in its outline; a pointer
      // lift carries it under the pointer.
      opacity: tile.placeholder ? (editor.pointerLift ? 0 : 0.5) : 1
      InkIcon {
        id: rowIcon
        record: tile.record
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        id: nameLabel
        text: tile.record.instanceKey ? editor.preferences.title(tile.record) : ""
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        width: Math.max(Style.space(16), tile.width - Style.space(12) - rowIcon.width - chip.spacing
          - (tile.memberCount > 0 ? memberLabel.implicitWidth + chip.spacing : 0))
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
          cameraOver: editor.previewCamera ? "center" : ""
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
