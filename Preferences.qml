import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "BarModel.js" as BarModel
import "AppearanceModel.js" as AppearanceModel
import "GroupsModel.js" as Groups
import "RenderModel.js" as RenderModel
import "BentoModel.js" as BentoModel
import "TrayItemsModel.js" as TrayItemsModel

// Powerbar preferences. Everything is reachable from the keyboard: 1-3 switch
// pages, Tab and j/k walk controls, h/l adjust them, Esc closes. The footer
// always lists the keys that apply to whatever has focus.
Item {
  id: prefs
  property var bar: null
  property bool opened: false
  property var targetScreen: null
  property int page: 0
  // Changes save as they are made, so the footer stays quiet unless one fails.
  property string status: ""
  property var snapshots: ({})
  property int openSerial: 0
  property int captureEpoch: 0
  property var snapshotBatch: ({})
  property var pendingCaptureKeys: []
  property var previousCaptureConfig: ({})
  readonly property string wallpaper: bar ? "file://" + bar.stateHome + "/omarchy/current/background?v=" + openSerial : ""
  readonly property var config: bar ? bar.barConfig : ({})
  // The bar's options as the bar reads them, defaults included.
  readonly property var options: BarModel.options(config)
  // Widget metadata, refreshed once after the registry changes. Omarchy
  // re-registers every bar widget, one at a time, on each config write; read
  // directly, every registration rebuilt every page's models.
  property var registryMetadata: ({})
  function refreshRegistryMetadata() {
    var registry = bar ? bar.barWidgetRegistry : null
    var widgets = registry && registry.widgets || {}
    var next = {}
    for (var id in widgets) next[id] = registry.metadataFor(id)
    if (!RenderModel.equal(next, registryMetadata)) registryMetadata = next
  }
  function metadataFor(id) { return registryMetadata[String(id)] || null }
  onBarChanged: refreshRegistryMetadata()
  Component.onCompleted: refreshRegistryMetadata()
  readonly property var entries: Model.records(config.layout, function(id) { return prefs.metadataFor(id) }, bar ? bar.legacyVisibility : false)
  readonly property var layoutEntries: {
    var result = entries.filter(function(e) { return !bar.groupFor(e.instanceKey) })
    bar.groups.forEach(function(g) {
      var list = result.filter(function(e) { return e.section === g.section })
      var anchor = list.find(function(e) { return e.instanceKey === g.before })
      result.push({ id: "powerbar.group." + g.id, groupId: g.id, instanceKey: Groups.groupKey(g.id),
        label: g.label, icon: g.icon, iconFont: g.iconFont, iconImage: g.iconImage, iconTint: g.iconTint, mode: g.visibility, section: g.section,
        index: anchor ? anchor.index : (config.layout && config.layout[g.section] || []).length,
        fingerprint: JSON.stringify(g) })
    })
    return result.sort(function(a, b) { return a.index - b.index || (a.groupId ? -1 : b.groupId ? 1 : 0) })
  }
  readonly property var pages: [
    { title: "Layout", icon: "󰕰" }, { title: "Groups", icon: "󰉋" },
    { title: "Bar", icon: "󰒓" }
  ]
  readonly property var pageItems: [layoutPage.item, groupsPage.item, barPage.item]
  // Built on the first open (the page Loaders), then kept.
  property bool pagesLoaded: false
  // A group asked for before its page exists, selected as it loads.
  property string pendingGroupId: ""
  function selectGroup(id) { if (groupsPage.item) groupsPage.item.selectedId = id; else pendingGroupId = id }
  readonly property var hints: pageItems[page] ? pageItems[page].hints : []

  function open(payloadJson) {
    // Preferences takes the keyboard: a keyboard mode left on would hold it too.
    if (bar.barKeys && bar.barKeys.active) bar.barKeys.leave()
    bar.closeManagedDrawer()
    bar.clearTooltip()
    bar.requestPopout(prefs)
    captureEpoch++
    snapshotBatch = ({})
    snapshots = ({})
    previousCaptureConfig = JSON.parse(JSON.stringify(config))
    pendingCaptureKeys = []
    openSerial++
    cacheListing.running = true
    gapsInProc.running = true
    opened = true
    bar.readWidgetGlyphs()
    refreshSnapshots()
    Qt.callLater(focusPage)
  }
  // Widget and group shortcuts: read from Hyprland each time Preferences opens.
  ShortcutStore { id: shortcutStore; bar: prefs.bar; preferences: prefs }
  readonly property var shortcuts: shortcutStore
  onOpenedChanged: {
    if (!opened) return
    pagesLoaded = true
    if (bar) shortcutStore.refresh()
  }
  function close() {
    shortcutStore.stopRecording()
    opened = false
    captureEpoch++
    snapshotBatch = ({})
    snapshotDelay.stop()
    if (bar) bar.releasePopout(prefs)
  }
  function closeToKeys() {
    close()
    if (bar && bar.barKeys) Qt.callLater(bar.barKeys.backFromPreferences)
  }
  function show(screen) { targetScreen = screen; open("{}") }
  // Bar → Keyboard, the cursor on the keyboard mode's shortcut row.
  property bool pendingKeyboard: false
  function showKeyboard(screen) {
    pendingKeyboard = true
    if (opened) setPage(2)
    else { page = 2; show(screen) }
  }
  function showGroup(screen, id) { if (id) selectGroup(id); page = 1; show(screen) }
  function openGroup(id) { selectGroup(id); setPage(1) }
  function setPage(index) {
    if (index < 0 || index >= pages.length) return
    page = index
    Qt.callLater(focusPage)
  }
  function focusPage() {
    var item = pageItems[page]
    if (!item) return
    if (pendingKeyboard && item.keyboardRow) { pendingKeyboard = false; item.keyboardRow.forceActiveFocus(Qt.OtherFocusReason) }
    else item.focusFirst()
  }
  function publishSnapshots() {
    if (!opened || !Object.keys(snapshotBatch).length) return
    snapshots = Object.assign({}, snapshots, snapshotBatch)
    snapshotBatch = ({})
  }
  function refreshSnapshots(keys) {
    if (!opened || !bar || !targetScreen) return
    var epoch = captureEpoch, screen = targetScreen
    bar.captureWidgetImages(screen, function(key, image) {
      if (!prefs.opened || epoch !== prefs.captureEpoch || screen !== prefs.targetScreen) return
      prefs.snapshotBatch[key] = image
      Qt.callLater(prefs.publishSnapshots)
    }, keys, function() { return prefs.opened && epoch === prefs.captureEpoch && screen === prefs.targetScreen })
  }
  onTargetScreenChanged: if (opened) { captureEpoch++; snapshotBatch = ({}); refreshSnapshots() }
  function title(record) {
    if (record.groupId) return record.label
    if (record.trayTitle) return record.trayTitle
    if (record.label) return record.label
    var metadata = metadataFor(record.id)
    return BarModel.widgetName(metadata, record.id)
  }
  // Saved widget images on disk, listed once per opening.
  property var cachedImages: ({})
  function cachedImageUrl(key) {
    if (!bar) return ""
    var file = bar.widgetImageFile(key)
    return cachedImages[file.slice(file.lastIndexOf("/") + 1)] ? "file://" + file + "?v=" + openSerial : ""
  }
  Process {
    id: cacheListing
    command: ["ls", "-1", prefs.bar ? prefs.bar.widgetImageDir : "/nonexistent"]
    property var found: ({})
    stdout: SplitParser { onRead: function(line) { cacheListing.found[String(line).trim()] = true } }
    onStarted: found = ({})
    onExited: prefs.cachedImages = found
  }
  // Where Preferences has no image of a widget: the glyph the widget itself
  // draws (read by the bar at any orientation), then Powerbar's stock one.
  function readGlyph(record) { return !record.groupId && bar && bar.widgetGlyphs ? bar.widgetGlyphs[record.instanceKey] || null : null }
  function iconFont(record) {
    var read = readGlyph(record)
    if (record.groupId) return Groups.groupIconFont(record) || Style.font.family
    return read && read.font || Groups.iconFont(icon(record)) || Style.font.family
  }
  function icon(record) {
    if (record.groupId) return record.icon
    var read = readGlyph(record)
    return read ? read.glyph : Model.icon(String(record.id || ""))
  }
  // Edits show on the bar at once and are written once it settles
  // (Bar.writeConfig); a write that fails later is reported here.
  function setOption(key, value) {
    if (!bar || !bar.shell) return
    var glassyOmarchy = bar.omarchyGlassy === true
    var result = bar.writeConfig(function(config) {
      if (!config.bar) config.bar = {}
      // Undefined returns the setting to its default.
      if (value === undefined) delete config.bar[key]
      else config.bar[key] = value
      // Omarchy's bar background has two forms (AppearanceModel.barBackground):
      // the one written replaces the other, and an Omarchy with glassy keeps
      // only `background`, as `omarchy bar transparent` does there.
      if (key === "background") delete config.bar.transparent
      if (key === "transparent") {
        delete config.bar.background
        if (value !== undefined && glassyOmarchy) {
          config.bar.background = value === true ? "none" : "opaque"
          delete config.bar.transparent
        }
      }
    })
    status = result === false ? "Could not save. Check that shell.json is writable." : ""
  }
  readonly property string themeName: bar ? bar.themeName : ""
  // Appearance scopes (AppearanceModel): what each tile follows in the current
  // theme, the resolved values, and writes to the scope the tile follows.
  readonly property var look: bar ? bar.appearance : null
  function scopeOf(tile) { return look ? look.scopes[tile] : "theme" }
  function lookValue(key) { return look ? look.values[key] : undefined }
  function writeLook(mutator) {
    if (!bar || !bar.shell) return
    var theme = themeName
    var result = bar.writeConfig(function(config) {
      if (!config.bar) config.bar = {}
      mutator(config.bar, theme)
    })
    status = result === false ? "Could not save. Check that shell.json is writable." : ""
  }
  function setScope(tile, scope) {
    var look = bar ? bar.themeLook : ({})
    writeLook(function(b, theme) { AppearanceModel.setScope(b, theme, tile, scope, look) })
  }
  // Choosing an opacity ends Omarchy's clear or glassy bar (`omarchy bar
  // background`, or `transparent` before it).
  function setLook(tile, key, value) {
    writeLook(function(b, theme) {
      AppearanceModel.setValue(b, theme, tile, key, value)
      if (tile === "surface" && key === "opacity") { delete b.transparent; delete b.background }
    })
  }
  function setText(value) { writeLook(function(b, theme) { AppearanceModel.setText(b, theme, value) }) }
  // The line under a tile's header: where its values come from, or what a
  // change there reaches.
  function scopeHint(tile) {
    if (!look) return ""
    var theme = themeName || "this theme", own = !!look.look[tile]
    var scope = look.scopes[tile]
    // One line in a tile a third of the card wide: the page must not scroll.
    if (scope === "theme") return own ? "Using " + theme + "'s Powerbar look." : "Using " + theme + "'s look."
    if (scope === "all") return own ? "Yours everywhere; " + theme + " has its own look." : "Yours, in every theme that has no own choice."
    return "Yours, only while " + theme + " is on."
  }
  component ScopeChoice: ButtonGroup {
    property string tile: ""
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    options: [{ value: "theme", label: "Theme" }, { value: "all", label: "Everywhere" }, { value: "this", label: "Just here" }]
    value: prefs.scopeOf(tile)
    foreground: Commons.Color.popups.text
    background: "transparent"
    fontSize: Style.font.caption
    Accessible.name: tile.charAt(0).toUpperCase() + tile.slice(1) + " values"
    onChanged: function(value) { prefs.setScope(tile, value) }
  }
  component ScopeHint: Text {
    property string tile: ""
    text: prefs.scopeHint(tile)
    textFormat: Text.PlainText
    color: Qt.alpha(Commons.Color.popups.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
    Accessible.name: text
    Layout.fillWidth: true
    Layout.leftMargin: Style.spacing.rowPaddingX
    Layout.rightMargin: Style.spacing.rowPaddingX
    Layout.bottomMargin: Style.space(2)
  }
  function setBarStyle(value) {
    if (!bar || !bar.shell) return
    var result = bar.writeConfig(function(config) { BarModel.setBarStyle(config, value) })
    status = result === false ? "Could not save. Check that shell.json is writable." : ""
  }
  readonly property var ranges: AppearanceModel.ranges
  // The Notch style: black ears around the camera, at the top of a notched
  // screen, no drawers; other screens and edges draw it as islands. Settings
  // that only the islands use hide when every screen has the notch look.
  readonly property bool notchMode: !!bar && bar.notchMode
  readonly property bool motion: !bar || bar.animationsEnabled
  // Tiles sit apart like tiled windows: twice Hyprland's inner gap, read once
  // per opening; 8 px until it is known or when it cannot be read.
  property int gapsIn: -1
  readonly property real tileGap: gapsIn >= 0 ? gapsIn * 2 : Style.space(8)
  Process {
    id: gapsInProc
    command: ["hyprctl", "-j", "getoption", "general:gaps_in"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var json = JSON.parse(text || "{}")
          var n = Number((String(json.css || "").match(/-?\d+(?:\.\d+)?/) || [json.int])[0])
          if (isFinite(n) && n >= 0) prefs.gapsIn = Math.round(n)
        } catch (e) {}
      }
    }
  }

  Connections {
    target: prefs.bar
    ignoreUnknownSignals: true
    function onConfigWriteFailed() { prefs.status = "Could not save. Check that shell.json is writable." }
  }
  // `before` is an index into the layout shown now; the edit names the widget
  // and its new neighbour by instance key, so replayed on a layout that
  // changed meanwhile (a queued edit is re-run on each delivery) it lands
  // beside the same neighbour, or reports that the neighbour is gone.
  function move(record, section, mode, before) {
    if (!record || !bar || !bar.shell) return
    var beforeKey = Model.anchorKey(config.layout, section, before, record.groupId ? "" : record.instanceKey)
    var changed = false, inPlace = false
    var accepted = bar.writeConfig(function(config) {
      changed = false
      inPlace = false
      if (record.groupId) {
        changed = Groups.edit(config, record.groupId, { section: section, visibility: mode, before: beforeKey })
        return
      }
      var layout = config.bar.layout
      if (!record.instanceKey) { changed = Model.move(config, record, section, mode, Math.ceil(before)); return }
      var from = Model.sections.find(function(zone) {
        return (layout[zone] || []).some(function(entry) { return entry && entry.powerbarInstance === record.instanceKey })
      })
      var to = layout[section] || []
      if (!from || (beforeKey && !to.some(function(entry) { return entry && entry.powerbarInstance === beforeKey }))) return
      // A group anchored on the moving widget stays where it is.
      var next = Groups.nextAnchor(config, from, record.instanceKey)
      if (!Array.isArray(layout[section])) layout[section] = []
      changed = BarModel.moveInstanceInConfig(config, from, record.instanceKey, section, beforeKey, mode)
      if (changed) Groups.reanchor(config, from, record.instanceKey, next)
      else inPlace = true
    })
    status = accepted === false ? "Could not save the layout. Check that shell.json is writable."
      : changed || inPlace ? "" : "The layout changed elsewhere. Try again."
  }

  // Omarchy's tray icons (TrayItemsModel.js): the ones still in the tray, as
  // the Layout page's last row, and each icon's live image.
  readonly property var trayEntries: TrayItemsModel.trayRows(SystemTray.items.values, config.layout, Status.Passive)
  function trayIcon(record) {
    if (!record || !record.trayItem) return ""
    var item = TrayItemsModel.find(SystemTray.items.values, { item: record.trayItem, title: record.trayTitle })
    return item ? String(item.icon || "") : ""
  }
  // Moves a tray icon out onto the bar, before layout index `before` of
  // `section`; returns the new entry's instance key ("" when it did not move).
  function takeFromTray(record, section, mode, before) {
    if (!record || !bar || !bar.shell) return ""
    var item = TrayItemsModel.find(SystemTray.items.values, { item: record.trayItem, title: record.trayTitle })
    if (!item) { status = "That app has left the tray."; return "" }
    var beforeKey = Model.anchorKey(config.layout, section, before, "")
    var key = "pw-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
    var moved = false
    var accepted = bar.writeConfig(function(config) {
      moved = !!TrayItemsModel.moveOut(config, item, section, mode, beforeKey, key)
    })
    status = accepted === false ? "Could not save the layout. Check that shell.json is writable." : ""
    return accepted !== false && moved ? key : ""
  }
  // Puts a moved icon back in the tray. A group anchored on it moves on to
  // the widget after it.
  function returnToTray(record) {
    if (!record || !record.instanceKey || !bar || !bar.shell) return
    var accepted = bar.writeConfig(function(config) {
      var next = Groups.nextAnchor(config, record.section, record.instanceKey)
      if (TrayItemsModel.moveBack(config, record.instanceKey)) Groups.reanchor(config, record.section, record.instanceKey, next)
    })
    status = accepted === false ? "Could not save the layout. Check that shell.json is writable." : ""
  }

  Timer {
    id: snapshotDelay
    interval: 260
    onTriggered: {
      var keys = prefs.pendingCaptureKeys
      prefs.pendingCaptureKeys = []
      prefs.refreshSnapshots(keys)
    }
  }
  Connections {
    target: prefs.bar
    function onBarConfigChanged() {
      // Opening takes its own baseline, so a closed window has nothing to track.
      if (!prefs.opened) return
      var next = JSON.parse(JSON.stringify(prefs.config))
      var keys = RenderModel.captureDelta(prefs.previousCaptureConfig, next)
      prefs.previousCaptureConfig = next
      if (keys && !keys.length) return
      if (keys === null || prefs.pendingCaptureKeys === null) prefs.pendingCaptureKeys = null
      else prefs.pendingCaptureKeys = Array.from(new Set(prefs.pendingCaptureKeys.concat(keys)))
      snapshotDelay.restart()
    }
    function onFontFamilyChanged() { if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() } }
    function onBarSizeChanged() { if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() } }
    function onBarWidgetRegistryChanged() { if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() } }
    function onBarForegroundChanged() { if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() } }
    function onBackgroundChanged() { if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() } }
    function onUrgentChanged() { if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() } }
    function onForegroundChanged() { if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() } }
  }

  Connections {
    target: prefs.bar
    ignoreUnknownSignals: true
    function onBarWidgetRegistryChanged() { Qt.callLater(prefs.refreshRegistryMetadata) }
  }
  Connections {
    target: prefs.bar ? prefs.bar.barWidgetRegistry : null
    ignoreUnknownSignals: true
    function onWidgetsChanged() { Qt.callLater(prefs.refreshRegistryMetadata) }
    function onRevisionChanged() {
      Qt.callLater(prefs.refreshRegistryMetadata)
      if (prefs.opened) { prefs.pendingCaptureKeys = null; snapshotDelay.restart() }
    }
  }

  PanelWindow {
    id: window
    screen: prefs.targetScreen
    visible: prefs.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "powerbar-preferences"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: prefs.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Commons.Color.menu.scrim
      MouseArea { anchors.fill: parent; onClicked: prefs.close() }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(parent.width - Style.space(48), Style.space(1180))
      height: Math.min(parent.height - Style.space(64), Style.space(790))
      color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
      borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, 1)
      radius: Style.cornerRadius
      focus: true
      opacity: prefs.opened ? 1 : 0
      scale: prefs.opened ? 1 : 0.98
      Behavior on opacity { enabled: prefs.bar && prefs.bar.animationsEnabled; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on scale { enabled: prefs.bar && prefs.bar.animationsEnabled; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      // Keys nothing inside wanted: page switching and closing.
      Keys.onPressed: function(event) {
        var ctrl = event.modifiers & Qt.ControlModifier
        var digit = event.key - Qt.Key_1
        if (event.key === Qt.Key_Escape) { prefs.close(); event.accepted = true }
        // , (the keyboard mode's key for Preferences) closes it, back to the
        // mode when it came from there (KEYS-81).
        else if (event.text === "," && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { prefs.closeToKeys(); event.accepted = true }
        else if (digit >= 0 && digit < prefs.pages.length && !(event.modifiers & Qt.AltModifier)) { prefs.setPage(digit); event.accepted = true }
        else if (ctrl && event.key === Qt.Key_Tab) { prefs.setPage((prefs.page + 1) % prefs.pages.length); event.accepted = true }
        else if (ctrl && event.key === Qt.Key_Backtab) { prefs.setPage((prefs.page + prefs.pages.length - 1) % prefs.pages.length); event.accepted = true }
      }
      // Ctrl+digit works even while typing in a field.
      Shortcut { sequences: ["Ctrl+1"]; onActivated: prefs.setPage(0) }
      Shortcut { sequences: ["Ctrl+2"]; onActivated: prefs.setPage(1) }
      Shortcut { sequences: ["Ctrl+3"]; onActivated: prefs.setPage(2) }
      MouseArea { anchors.fill: parent } // Keep clicks inside the card.

      // One accent ring follows keyboard focus from control to control, so the
      // current place is obvious whatever the theme's own focus styling.
      // Lists and grids that draw their own cursor opt out with ownsFocusRing.
      // The ring is clipped to the scrolling area its control sits in, so a
      // control scrolled out of view never drags the ring over the header or
      // footer. Only controls on the pages get it: popups and dropdown lists
      // sit above the card and keep their own highlight.
      Item {
        id: ringClip
        z: 1000
        clip: true
        visible: focusRing.shown

        BorderSurface {
          id: focusRing
          readonly property Item focused: card.Window.activeFocusItem
          readonly property Item target: prefs.opened && focused && focused !== card && !focused.ownsFocusRing
            && focused.width > 0 && focused.height > 0 && focusRing.onPages(focused) ? focused : null
          readonly property real pad: Style.space(3)
          property bool gliding: false
          // Visibility lives on the clipping parent; a child's own `visible`
          // reads false while its parent is hidden, so it cannot drive it.
          readonly property bool shown: !!target && target.visible
          color: "transparent"
          radius: Style.cornerRadius + pad
          borderSpec: Border.flat(Commons.Color.accent, Math.max(1, Style.space(2)))
          onTargetChanged: { gliding = true; glideEnd.restart(); follow() }
          function onPages(item) {
            for (var p = item; p; p = p.parent) if (p === pages) return true
            return false
          }
          function viewportOf(item) {
            for (var p = item.parent; p && p !== pages; p = p.parent)
              if (p.contentY !== undefined && p.flicking !== undefined) return p
            return pages
          }
          function follow() {
            if (!target) return
            var view = viewportOf(target)
            var v = view.mapToItem(card, 0, 0)
            ringClip.x = v.x - pad
            ringClip.y = v.y - pad
            ringClip.width = view.width + pad * 2
            ringClip.height = view.height + pad * 2
            var p = target.mapToItem(ringClip, 0, 0)
            x = p.x - pad
            y = p.y - pad
            width = target.width + pad * 2
            height = target.height + pad * 2
          }
          Timer { id: glideEnd; interval: 170; onTriggered: focusRing.gliding = false }
          GeometryObserver {
            target: focusRing.shown ? focusRing.target : null
            host: card
            onChanged: focusRing.follow()
          }
          Behavior on x { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          Behavior on y { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          Behavior on width { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
          Behavior on height { enabled: focusRing.gliding && prefs.bar.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(28)
        anchors.rightMargin: Style.space(28)
        anchors.topMargin: Style.space(20)
        anchors.bottomMargin: Style.space(14)
        spacing: 0

        // ---------------------------------------------------------- header
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(28)
          Text {
            text: "Powerbar"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Row {
            spacing: Style.space(4)
            Repeater {
              model: prefs.pages
              Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool current: prefs.page === index
                width: tabRow.implicitWidth + Style.space(20)
                height: tabRow.implicitHeight + Style.space(18)
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.title
                Accessible.selected: current
                Row {
                  id: tabRow
                  anchors.centerIn: parent
                  spacing: Style.space(8)
                  KeyCap {
                    text: tab.index + 1
                    foreground: tab.current ? Commons.Color.accent : Commons.Color.popups.text
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: tab.modelData.title
                    textFormat: Text.PlainText
                    color: tab.current ? Commons.Color.popups.text : Qt.alpha(Commons.Color.popups.text, tabMouse.containsMouse ? 0.85 : 0.55)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: tab.current
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: tab.current ? parent.width - Style.space(12) : 0
                  height: Math.max(2, Style.space(2))
                  radius: height / 2
                  color: Commons.Color.accent
                  Behavior on width { enabled: prefs.bar && prefs.bar.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: prefs.setPage(tab.index)
                }
              }
            }
          }
          Item { Layout.fillWidth: true }
          Item {
            implicitWidth: closeRow.implicitWidth
            implicitHeight: closeRow.implicitHeight
            opacity: closeMouse.containsMouse ? 1 : 0.65
            Accessible.role: Accessible.Button
            Accessible.name: "Close"
            Row {
            id: closeRow
            spacing: Style.space(8)
            KeyCap { text: "esc"; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: "Close"
              textFormat: Text.PlainText
              color: Commons.Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
            }
            MouseArea {
              id: closeMouse
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: prefs.close()
            }
          }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Commons.Color.popups.text, 0.1) }

        // ----------------------------------------------------------- pages
        StackLayout {
          id: pages
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.topMargin: Style.space(20)
          Layout.bottomMargin: Style.space(14)
          currentIndex: prefs.page

          // The pages are built the first time Preferences opens, not at the
          // shell's start, and then kept: nothing in them shows while closed.
          Loader {
            id: layoutPage
            active: prefs.pagesLoaded
            sourceComponent: Component { LayoutEditor { preferences: prefs; columns: BentoModel.columnsFor(card.width / Style.spacing.scale) } }
          }
          Loader {
            id: groupsPage
            active: prefs.pagesLoaded && !!layoutPage.item
            sourceComponent: Component { GroupsPreferences { preferences: prefs; layout: layoutPage.item; columns: BentoModel.columnsFor(card.width / Style.spacing.scale) } }
            onLoaded: if (prefs.pendingGroupId) { item.selectedId = prefs.pendingGroupId; prefs.pendingGroupId = "" }
          }

          // General and Appearance as one page of tiles. Changes show on
          // the bar itself, so the page draws no preview of its own.
          Loader {
            id: barPage
            active: prefs.pagesLoaded
            sourceComponent: Component {
              PrefsForm {
                  maxContentWidth: Infinity
                  readonly property Item keyboardRow: barKeysRow

                PrefsBento {
                  id: bento
                  Layout.fillWidth: true
                  columns: BentoModel.columnsFor(card.width / Style.spacing.scale)
                  gap: prefs.tileGap

                  PrefsTile {
                    title: "Style and position"
                    span12: 8; span6: 6
                    GridLayout {
                      id: placement
                      readonly property var screen: prefs.targetScreen
                      Layout.fillWidth: true
                      Layout.leftMargin: Style.spacing.rowPaddingX
                      Layout.topMargin: Style.space(4)
                      Layout.bottomMargin: Style.space(4)
                      columns: width >= Style.space(560) ? 2 : 1
                      columnSpacing: Style.space(16)
                      rowSpacing: Style.space(8)
                      BarPlacement {
                        Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                        bar: prefs.bar
                        source: prefs.wallpaper
                        aspect: placement.screen && placement.screen.height > 0 ? placement.screen.width / placement.screen.height : 16 / 10
                        onEdgeChosen: function(edge) { prefs.setOption("position", edge) }
                      }
                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Style.space(2)
                        PrefsChoice {
                          compact: true
                          Layout.leftMargin: 0
                          stacked: true
                          label: "Style"
                          description: value === "islands" ? "A surface for each zone" : value === "floating" ? "One bar, off the edges"
                            : value === "notch" ? "Notch applies on the top edge of the notched screen; elsewhere it draws as islands" : "Edge to edge, like Omarchy"
                          // Notch is offered where a screen has one.
                          options: [{ value: "flat", label: "Flat" }, { value: "floating", label: "Floating" }, { value: "islands", label: "Islands" }]
                            .concat(prefs.bar && (prefs.bar.screenNotch || prefs.bar.notchStyle) ? [{ value: "notch", label: "Notch" }] : [])
                          value: prefs.bar ? (prefs.bar.notchStyle ? "notch" : prefs.bar.barStyle) : "flat"
                          onChosen: function(value) { prefs.setBarStyle(value) }
                        }
                        PrefsChoice {
                          compact: true
                          Layout.leftMargin: 0
                          stacked: true
                          label: "Screen edge"
                          options: [{ value: "top", label: "Top" }, { value: "bottom", label: "Bottom" }, { value: "left", label: "Left" }, { value: "right", label: "Right" }]
                          value: prefs.bar ? prefs.bar.position : "top"
                          onChosen: function(value) { prefs.setOption("position", value) }
                        }
                      }
                    }
                  }
                  PrefsTile {
                    title: "Size"
                    span12: 4; span6: 3
                    // The notch's bar is always as tall as the camera.
                    PrefsToggle {
                      visible: !prefs.notchMode
                      compact: true
                      label: "Large bar"
                      checked: prefs.bar ? prefs.bar.largeBar : false
                      onToggled: function(checked) { prefs.setOption("powerbarLargeBar", checked) }
                    }
                    PrefsChoice {
                      compact: true
                      stacked: true
                      label: "Spacing"
                      options: [{ value: "slots", label: "Equal slots" }, { value: "gaps", label: "Equal gaps" }]
                      value: prefs.bar ? prefs.bar.spacingMode : "slots"
                      onChosen: function(value) { prefs.setOption("powerbarSpacingMode", value) }
                    }
                    PrefsSlider {
                      compact: true
                      label: "Space between widgets"
                      minimum: prefs.ranges.spacing.min; maximum: prefs.ranges.spacing.max; stepSize: prefs.ranges.spacing.step
                      defaultValue: prefs.ranges.spacing.fallback
                      value: AppearanceModel.clampTo(prefs.ranges.spacing, prefs.config.powerbarSpacing)
                      formatter: function(v) { return v === 0 ? "None" : "" }
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setOption("powerbarSpacing", v) }
                    }
                  }
                  // The notch's zones take the camera's corners and have no
                  // border: nothing here applies to them.
                  PrefsTile {
                    id: shapeTile
                    readonly property bool editable: prefs.scopeOf("shape") !== "theme"
                    visible: !prefs.notchMode
                    title: "Shape"
                    span12: 4; span6: 3
                    animate: prefs.motion
                    ScopeChoice { parent: shapeTile.headerSlot; tile: "shape" }
                    ScopeHint { tile: "shape" }
                    PrefsSlider {
                      readonly property real themeRounding: Style.cornerRadius / Style.spacing.scale
                      compact: true
                      enabled: shapeTile.editable
                      label: "Corner rounding"
                      minimum: 0; maximum: prefs.bar ? prefs.bar.roundingMax : 16; stepSize: 1
                      defaultValue: Math.min(maximum, Math.round(themeRounding))
                      value: typeof prefs.lookValue("rounding") === "number" ? prefs.lookValue("rounding") : themeRounding
                      formatter: function(v) { return v === 0 ? "Square" : v >= maximum ? "Pill" : "" }
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setLook("shape", "rounding", v) }
                    }
                    PrefsToggle {
                      compact: true
                      label: "Borders"
                      enabled: shapeTile.editable
                      opacity: enabled ? 1 : 0.45
                      checked: prefs.lookValue("borders") !== false
                      onToggled: function(checked) { prefs.setLook("shape", "borders", checked) }
                    }
                    PrefsSlider {
                      readonly property real themeWidth: prefs.bar ? Border.top(prefs.bar.themeIslandBorder) / Style.space(1) : 1
                      compact: true
                      label: "Border thickness"
                      minimum: prefs.ranges.borderWidth.min; maximum: prefs.ranges.borderWidth.max; stepSize: prefs.ranges.borderWidth.step
                      defaultValue: themeWidth
                      enabled: shapeTile.editable && prefs.lookValue("borders") !== false
                      value: AppearanceModel.clampTo(prefs.ranges.borderWidth, prefs.lookValue("borderWidth"), themeWidth)
                      formatter: function(v) { return v === prefs.ranges.borderWidth.min ? "Hairline" : "" }
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setLook("shape", "borderWidth", v) }
                    }
                  }
                  // The Notch style's ears blend into the camera, which takes the
                  // place of Surface (black, no blur there). In every style the
                  // camera's size places the center and the large bar.
                  PrefsTile {
                    id: notchTile
                    readonly property var notch: prefs.bar ? prefs.bar.screenNotch : null
                    visible: !!notch
                    title: "Notch"
                    caption: prefs.notchMode ? "Black, like the camera" : "The camera's size"
                    span12: 4; span6: 3
                    PrefsSlider {
                      compact: true
                      label: "Notch width"
                      unit: "px"
                      minimum: 40; maximum: 600; stepSize: 1
                      defaultValue: notchTile.notch ? notchTile.notch.housing : 191
                      value: notchTile.notch ? notchTile.notch.width : (prefs.options.notchWidth || 191)
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setOption("powerbarNotchWidth", v === defaultValue ? undefined : v) }
                    }
                    PrefsSlider {
                      visible: !!notchTile.notch
                      compact: true
                      label: "Notch height"
                      unit: "px"
                      minimum: 16; maximum: 96; stepSize: 1
                      defaultValue: notchTile.notch ? notchTile.notch.detectedHeight : 32
                      value: notchTile.notch ? notchTile.notch.height : 32
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setOption("powerbarNotchHeight", v === defaultValue ? undefined : v) }
                    }
                  }
                  PrefsTile {
                    id: surfaceTile
                    readonly property bool editable: prefs.scopeOf("surface") !== "theme"
                    visible: !prefs.notchMode
                    title: "Surface"
                    span12: 4; span6: 3
                    animate: prefs.motion
                    ScopeChoice { parent: surfaceTile.headerSlot; tile: "surface" }
                    ScopeHint { tile: "surface" }
                    PrefsSlider {
                      compact: true
                      enabled: surfaceTile.editable
                      label: "Background opacity"
                      unit: "%"
                      minimum: prefs.ranges.backgroundOpacity.min; maximum: prefs.ranges.backgroundOpacity.max; stepSize: prefs.ranges.backgroundOpacity.step
                      defaultValue: prefs.ranges.backgroundOpacity.fallback
                      // A transparent bar (Omarchy's Transparency) shows as Clear,
                      // a glassy one as the opacity it draws.
                      value: !prefs.bar ? 100 : Math.round(AppearanceModel.barOpacity(prefs.bar.surfaceEffects, false, prefs.bar.requestedTransparent, prefs.bar.glassy) * 100)
                      formatter: function(v) { return v === 0 ? "Clear" : v === 100 ? "Opaque" : "" }
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setLook("surface", "opacity", v) }
                    }
                    PrefsToggle {
                      compact: true
                      label: "Background blur"
                      enabled: surfaceTile.editable
                      opacity: enabled ? 1 : 0.45
                      checked: prefs.bar ? prefs.bar.surfaceEffects.blur : false
                      onToggled: function(checked) { prefs.setLook("surface", "blur", checked) }
                    }
                    // Kept per theme in every scope: a light or dark choice can't be
                    // shared between light and dark themes.
                    PrefsChoice {
                      compact: true
                      label: "Text and icons"
                      description: "Kept per theme"
                      options: [{ value: "theme", label: "Theme" }, { value: "light", label: "Light" }, { value: "dark", label: "Dark" }]
                      value: prefs.bar ? prefs.bar.foregroundChoice : "theme"
                      onChosen: function(value) { prefs.setText(value) }
                    }
                  }
                  PrefsTile {
                    id: shadowTile
                    readonly property bool editable: prefs.scopeOf("shadow") !== "theme"
                    readonly property bool shadowOn: !!prefs.bar && prefs.bar.surfaceEffects.shadow
                    title: "Shadow"
                    span12: 4; span6: 3
                    animate: prefs.motion
                    ScopeChoice { parent: shadowTile.headerSlot; tile: "shadow" }
                    ScopeHint { tile: "shadow" }
                    PrefsToggle {
                      compact: true
                      label: "Shadow"
                      enabled: shadowTile.editable
                      opacity: enabled ? 1 : 0.45
                      checked: shadowTile.shadowOn
                      onToggled: function(checked) { prefs.setLook("shadow", "enabled", checked) }
                    }
                    PrefsSlider {
                      compact: true
                      label: "Softness"
                      minimum: prefs.ranges.shadowSize.min; maximum: prefs.ranges.shadowSize.max; stepSize: prefs.ranges.shadowSize.step
                      defaultValue: prefs.ranges.shadowSize.fallback
                      enabled: shadowTile.editable && shadowTile.shadowOn
                      value: prefs.bar ? prefs.bar.surfaceEffects.shadowSize : prefs.ranges.shadowSize.fallback
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setLook("shadow", "softness", v) }
                    }
                    PrefsSlider {
                      compact: true
                      label: "Strength"
                      unit: "%"
                      minimum: prefs.ranges.shadowOpacity.min; maximum: prefs.ranges.shadowOpacity.max; stepSize: prefs.ranges.shadowOpacity.step
                      defaultValue: prefs.ranges.shadowOpacity.fallback
                      enabled: shadowTile.editable && shadowTile.shadowOn
                      value: prefs.bar ? Math.round(prefs.bar.surfaceEffects.shadowOpacity * 100) : prefs.ranges.shadowOpacity.fallback
                      animate: prefs.motion
                      onEdited: function(v) { prefs.setLook("shadow", "strength", v) }
                    }
                  }
                  PrefsTile {
                    title: "Behavior"
                    span12: 4; span6: 3
                    PrefsToggle {
                      compact: true
                      label: "Autohide"
                      checked: prefs.options.autoHide
                      onToggled: function(checked) { prefs.setOption("powerbarAutoHide", checked) }
                    }
                    // Peeks on an autohidden bar and on one switched off
                    // (Super+Shift+Space), so it holds whether Autohide is on.
                    PrefsToggle {
                      compact: true
                      label: "Show on widget activity"
                      checked: prefs.options.autoHideActivity
                      onToggled: function(checked) { prefs.setOption("powerbarAutoHideActivity", checked) }
                    }
                    // Powerbar's safety minimum for surfaces over windows, not a theme
                    // value, so it stays outside the appearance scopes. The notch is
                    // always opaque, so it has nothing to raise there.
                    PrefsToggle {
                      visible: !prefs.notchMode
                      compact: true
                      label: "Readable over windows"
                      checked: prefs.bar ? prefs.bar.surfaceEffects.readableOverlay : true
                      onToggled: function(checked) { prefs.setOption("powerbarReadableOverlay", checked) }
                    }
                    PrefsToggle {
                      compact: true
                      label: "Animations"
                      checked: prefs.bar ? prefs.bar.animationsEnabled : true
                      onToggled: function(checked) { prefs.setOption("powerbarAnimations", checked) }
                    }
                  }
                  PrefsTile {
                    title: "On demand"
                    span12: 4; span6: 3
                    // The notch has no drawers: there the choice is the bar or a menu.
                    PrefsChoice {
                      compact: true
                      // Three chips leave the label no room beside them.
                      stacked: bento.columns !== 12 || options.length > 2
                      label: "Show them"
                      readonly property string shown: prefs.notchMode && prefs.options.onDemand === "drawer" ? "inline" : prefs.options.onDemand
                      description: value === "inline"
                        ? "Behind dots in their zone; they expand in the bar when you hover the dots"
                        : value === "menu"
                        ? "Behind dots in their zone; the dots open a menu of them, groups as submenus"
                        : "Hovering a zone opens them in a drawer next to the bar"
                      options: prefs.notchMode
                        ? [{ value: "inline", label: "In the bar" }, { value: "menu", label: "In a menu" }]
                        : [{ value: "drawer", label: "In a drawer" }, { value: "inline", label: "In the bar" }, { value: "menu", label: "In a menu" }]
                      value: shown
                      onChosen: function(value) { prefs.setOption("powerbarOnDemand", value) }
                    }
                    PrefsToggle {
                      compact: true
                      label: "Count on the dots"
                      checked: prefs.options.dotsBadge
                      onToggled: function(checked) { prefs.setOption("powerbarDotsBadge", checked) }
                    }
                  }
                  // The keyboard mode (docs/behavior/keyboard.md): its shortcuts (offered,
                  // never bound until taken here; KEYS-84) and its strip of keys.
                  PrefsTile {
                    title: "Keyboard"
                    span12: 4; span6: 6
                    ShortcutRow {
                      id: barKeysRow
                      label: "Bar keyboard"
                      store: prefs.shortcuts
                      target: "bar:keys"
                      suggested: prefs.shortcuts.suggested("bar:keys")
                    }
                    ShortcutRow {
                      label: "Bar search"
                      store: prefs.shortcuts
                      target: "bar:search"
                      suggested: prefs.shortcuts.suggested("bar:search")
                    }
                    PrefsToggle {
                      compact: true
                      label: "Key legend"
                      checked: prefs.options.keyLegend
                      onToggled: function(checked) { prefs.setOption("powerbarKeyLegend", checked) }
                    }
                  }
                }
              }
            }
          }
        }

        // ---------------------------------------------------------- footer
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(Commons.Color.popups.text, 0.1) }
        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(12)
          spacing: Style.space(18)
          Repeater {
            model: prefs.hints
            Row {
              required property var modelData
              spacing: Style.space(6)
              Repeater {
                model: String(parent.modelData.keys).split(" ")
                KeyCap { required property string modelData; text: modelData; anchors.verticalCenter: parent ? parent.verticalCenter : undefined }
              }
              Text {
                text: parent.modelData.label
                textFormat: Text.PlainText
                color: Qt.alpha(Commons.Color.popups.text, 0.6)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }
          Item { Layout.fillWidth: true }
          Text {
            text: prefs.status
            textFormat: Text.PlainText
            color: Commons.Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideLeft
            Layout.maximumWidth: Style.space(320)
          }
        }
      }
    }
  }
}
