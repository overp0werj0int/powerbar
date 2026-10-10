import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQml.Models as Models
import qs.Commons
import qs.Ui
import "BarModel.js" as BarModel
import "PreferencesModel.js" as PreferencesModel
import "ManagedModel.js" as ManagedModel
import "GroupsModel.js" as GroupsModel
import "GroupBadgeModel.js" as GroupBadgeModel
import "AppearanceModel.js" as AppearanceModel
import "DragModel.js" as DragModel
import "HighlightModel.js" as HighlightModel
import "CellModel.js" as CellModel
import "ZoneFitModel.js" as ZoneFitModel
import "InlineQueue.js" as InlineQueue
import "RenderModel.js" as RenderModel
import "ZoneOrderModel.js" as ZoneOrderModel
import "GlyphModel.js" as GlyphModel
import "ShortcutModel.js" as ShortcutModel
import "BarKeysModel.js" as KeysModel
import "TooltipModel.js" as TooltipModel

Item {
  id: root

  Preferences { id: preferencesPane; bar: root }
  // The keyboard mode (Super+B): a cursor on the bar (BarKeys.qml).
  BarKeys { id: barKeysItem; bar: root }
  readonly property var barKeys: barKeysItem
  // The command line (omarchy-shell powerbar …), read by the IpcHandler below.
  BarCli { id: cliItem; bar: root; preferences: preferencesPane }
  // `omarchy-shell powerbar show` holds an autohidden bar out until `hide`.
  property bool cliShown: false
  onAutoHideChanged: if (!autoHide) cliShown = false
  readonly property bool preferencesOpen: preferencesPane.opened
  // The bar's options with their clean-config defaults (BarModel.options).
  readonly property var barOptions: BarModel.options(barConfig)
  readonly property bool animationsEnabled: barOptions.animations
  // Neighbours make way over a time that grows with the gap (150 ms for an
  // icon, at most 260 ms), so wide widgets never sweep their neighbours.
  readonly property int dragMotionDuration: CellModel.dragDuration(vertical ? dragGapHeight : dragGapWidth, CellModel.iconGap(cellTokens))
  readonly property int dragMotionEasing: Easing.InOutSine
  readonly property real dragDeadZone: Style.space(3)
  property var managedOwner: null
  property var groups: []
  property var groupIndexes: ({ byId: Object.create(null), owner: Object.create(null) })
  function updateGroups(config) {
    var next = GroupsModel.groups(config).map(function(group) {
      var current = groupIndexes.byId[group.id]
      return RenderModel.equal(current, group) ? current : group
    })
    if (RenderModel.sameItems(groups, next)) return
    groupIndexes = RenderModel.groupIndex(next)
    groups = next
  }
  function groupFor(key) { return groupIndexes.owner[key] || null }
  function groupSlots(id, window) {
    var group = groupIndexes.byId[id]
    if (!group || !window || !window.widgetStore) return []
    var revision = window.widgetStore.revision
    return group.items.map(function(key) { return window.widgetStore.get(key) }).filter(function(slot) { return !!slot && !slot.groupHeader })
  }
  function groupBadge(id, window) {
    var group = groupIndexes.byId[id]
    if (!group) return { count: 0, urgent: false }
    return GroupBadgeModel.aggregate(groupSlots(id, window).map(function(slot) { return slot.badgeInfo }), group.badgeMode)
  }
  readonly property var configuredEntries: RenderModel.entryIndex(barConfig && barConfig.layout || {})
  function layoutEntryFor(key) { return configuredEntries[key] || null }
  function activityPeeksFor(key, id) { return ManagedModel.peeksOnActivity(layoutEntryFor(key), id) }
  function quietActivityId(id) { return ManagedModel.quietActivity(id) }
  // Per-widget opt-out from sliding an autohidden bar out on activity.
  function setActivityPeek(key, enabled) {
    return writeConfig(function(config) {
      for (var section of ["left", "center", "right"]) {
        for (var entry of (config.bar.layout[section] || [])) {
          if (entry && entry.powerbarInstance === key) {
            if (enabled) delete entry.powerbarActivityPeek
            else entry.powerbarActivityPeek = false
            return
          }
        }
      }
    })
  }
  function editMemberBadge(key, field, value) {
    if (field !== "badgeProperty" && field !== "urgentProperty") return false
    var safe = GroupBadgeModel.propertyName(value, field === "badgeProperty")
    if (value.trim() && !safe) return false
    return editGroups(function(config) {
      for (var section of ["left", "center", "right"]) {
        for (var entry of (config.bar.layout[section] || [])) {
          if (entry && entry.powerbarInstance === key) {
            var name = field === "badgeProperty" ? "powerbarBadgeProperty" : "powerbarUrgentProperty"
            if (safe) entry[name] = safe
            else delete entry[name]
            return
          }
        }
      }
    })
  }
  // keepDrawer: a drop into an open drawer leaves it open, under the pointer.
  function editGroups(operation, keepDrawer) {
    if (!keepDrawer && !keepDrawerThroughEdit) closeManagedDrawer()
    return writeConfig(function(config) { operation(config) })
  }
  // Set while a drop into a drawer commits: the drawer (a group's or a zone's)
  // stays open under the pointer through the edit, and leaves on the exit grace.
  property bool keepDrawerThroughEdit: false
  // Config edits show at once and reach shell.json once the bar has settled
  // (ConfigStore.qml: the queue, the host's config under it, and the rule that
  // only a config naming Powerbar is written).
  readonly property bool configWriteSettled: !barDragSource && !barDragSettling && !barMoveActive
  signal configWriteFailed()
  readonly property string barId: manifest && manifest.id ? String(manifest.id) : "p0werj0int.powerbar"
  ConfigStore {
    id: configStore
    shell: root.shell
    barId: root.barId
    shown: root.barConfig
    settled: root.configWriteSettled
    onShow: function(config) { root.barConfig = config }
    onFailed: root.configWriteFailed()
  }
  function canWriteConfig() { return configStore.canWrite() }
  function writeConfig(mutator) { return configStore.write(mutator) }
  function flushConfigWrites() { configStore.flush() }
  function assignGroup(key, id, before, keepDrawer) {
    return editGroups(function(config) { GroupsModel.assign(config, key, id, before || "") }, keepDrawer)
  }
  function showGroups(screen, id) { preferencesPane.showGroup(screen, id || "") }
  // Live images of one screen's widgets, keyed by instance, so Preferences can
  // show each widget as it really looks. Widgets on the bar are captured with
  // their slot; drawer and group members, loaded but off the bar, render their
  // own item. Every image is also kept on disk, so a widget that is later
  // hidden, and therefore never loaded, still shows its last look.
  readonly property string widgetImageDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/powerbar/widgets"
  function widgetImageFile(key) { return widgetImageDir + "/" + String(key).replace(/[^A-Za-z0-9._-]/g, "_") + ".png" }
  // Preferences always draws the bar horizontally, so only a horizontal bar is
  // captured: a vertical bar's widgets lay themselves out for a column, and
  // capturing them would also overwrite the saved horizontal look.
  CaptureQueue { id: imageCaptures }
  function captureWidgetImages(screen, done, keys, valid) {
    if (vertical) return
    var jobs = []
    moduleSlots.forEach(function(slot) {
      if (!slot || (keys && keys.indexOf(slot.instanceKey) < 0)) return
      var window = slotWindow(slot)
      if (!window || !screen || !sameWindow(window, { screen: screen })) return
      var onBar = slot.mainVisible && !slot.drawerHost && slot.visible
      var item = onBar ? slot.presentationItem : slot.needsPlaceholder ? null : slot.activeItem
      if (!item || typeof item.grabToImage !== "function") return
      var width = onBar ? item.width : Math.max(item.width, item.implicitWidth)
      var height = onBar ? item.height : Math.max(item.height, item.implicitHeight)
      if (width <= 0 || height <= 0) return
      var key = slot.instanceKey, record = slot.record, prepared = false
      jobs.push({ key: String(screen.name) + ":" + key, item: item,
        size: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2)),
        prepare: function(job) {
          // A queued readback starts on a later frame: use the current geometry
          // and the current bar/drawer source at that point.
          onBar = slot.mainVisible && !slot.drawerHost && slot.visible
          item = onBar ? slot.presentationItem : slot.needsPlaceholder ? null : slot.activeItem
          if (!item || typeof item.grabToImage !== "function") return false
          width = onBar ? item.width : Math.max(item.width, item.implicitWidth)
          height = onBar ? item.height : Math.max(item.height, item.implicitHeight)
          if (width <= 0 || height <= 0) return false
          prepared = true
          job.item = item
          job.size = Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
          return true
        },
        valid: function() {
          return (!valid || valid()) && !root.vertical && slot && slot.record === record
            && window && window.moduleItems.indexOf(slot) >= 0
            && (!prepared || (onBar ? slot.mainVisible && !slot.drawerHost && slot.presentationItem === item : slot.activeItem === item))
        },
        accept: function(result) {
          var face = root.faceOf(slot, onBar, width, height)
          // The result is kept with the snapshot: an itemgrabber url is only
          // valid while its result lives, and an image that loads it later
          // (a page shown again, a rebuilt tile) would otherwise draw nothing.
          done(key, { url: result.url, result: result, width: width, height: height, face: face })
          if (GroupsModel.isGroupKey(key)) return
          result.saveToFile(root.widgetImageFile(key))
          root.recordFace(key, face)
        }
      })
    })
    imageCaptures.enqueue(jobs)
  }
  Process { running: true; command: ["mkdir", "-p", root.widgetImageDir] }
  // Seed the image cache once the bar has settled, so widgets hidden later
  // keep a real look even if Preferences was never opened while they showed.
  Timer {
    interval: 5000
    running: true
    onTriggered: {
      // Everything loaded so far is captured here; only later arrivals are new.
      for (var slot of root.moduleSlots) if (slot && slot.instanceKey) root.lookKnownKeys[slot.instanceKey] = true
      root.pendingLookKeys = []
      root.widgetLooksSeeded = true
      root.readWidgetGlyphs()
      if (Quickshell.screens.length) root.captureWidgetImages(Quickshell.screens[0], function() {})
    }
  }
  // How a captured image sits on the bar, so Preferences can lay it out the
  // way the bar does (ShelfModel): its size, where its ink starts and how long
  // it is, whether it reads as a glyph, and the text colour it was drawn in
  // (an image from another theme no longer matches the bar). Ink is only
  // known for a widget captured on the bar itself.
  function faceOf(slot, onBar, width, height) {
    var face = { w: width, h: height, ink: colorHex(barForeground) }
    if (onBar && slot.ink && slot.ink.length > 0) {
      face.inkStart = slot.ink.start
      face.inkLength = slot.ink.length
      face.glyph = CellModel.isGlyph(slot.ink.length, slot.ink.glyph)
      face.cap = slot.compoundTargets.length < 2
    }
    return face
  }
  readonly property string widgetFaceFile: widgetImageDir.slice(0, widgetImageDir.lastIndexOf("/")) + "/faces.json"
  property var widgetFaces: ({})
  property bool widgetFacesLoaded: false
  FileView {
    id: widgetFaceStore
    path: root.widgetFaceFile
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root.widgetFacesLoaded) { root.widgetFaces = root.parseFaces(text()); root.widgetFacesLoaded = true }
    onLoadFailed: root.widgetFacesLoaded = true
  }
  function parseFaces(text) {
    try {
      var data = JSON.parse(String(text || "{}"))
      return data && typeof data === "object" && !Array.isArray(data) ? data : {}
    } catch (e) {
      if (String(text || "").trim()) console.warn("powerbar: ignoring an unreadable widget face cache: " + e)
      return {}
    }
  }
  // Captures come one or two a frame (CaptureQueue), forty or so after the
  // start: their faces are published together, once the run has gone quiet,
  // so what reads widgetFaces (the layout editor) updates once, not per widget.
  property var pendingFaces: ({})
  function recordFace(key, face) {
    if (!key || !face) return
    pendingFaces[key] = face
    facePublish.restart()
  }
  Timer { id: facePublish; interval: 100; onTriggered: root.publishFaces() }
  function publishFaces() {
    var next = Object.assign({}, widgetFaces), pending = pendingFaces
    pendingFaces = ({})
    for (var key in pending) {
      var face = pending[key]
      // A drawer capture knows no ink; it keeps what the bar measured before.
      var before = next[key]
      if (face.inkLength === undefined && before && before.inkLength !== undefined && before.w === face.w && before.h === face.h)
        face = Object.assign({}, before, { ink: face.ink })
      next[key] = face
    }
    widgetFaces = next
    faceWriteDelay.restart()
  }
  Timer {
    id: faceWriteDelay
    interval: 1000
    onTriggered: {
      var keys = {}
      for (var zone of ["left", "center", "right"])
        for (var entry of ((root.barConfig.layout || {})[zone] || [])) if (entry && entry.powerbarInstance) keys[entry.powerbarInstance] = true
      var kept = {}
      for (var key in root.widgetFaces) if (keys[key] || !Object.keys(keys).length) kept[key] = root.widgetFaces[key]
      widgetFaceStore.setText(JSON.stringify(kept) + "\n")
    }
  }
  // Each widget's own glyph, read from the button it draws (GlyphModel), for
  // Preferences to show where it has no image of the widget: a vertical bar is
  // never captured, and a widget added since the last capture has none. The
  // glyph is the same either way the bar faces, so it is read at both, and kept
  // on disk so a widget that is later hidden, and never loaded, keeps its own.
  readonly property string widgetGlyphFile: widgetImageDir.slice(0, widgetImageDir.lastIndexOf("/")) + "/glyphs.json"
  property var widgetGlyphs: ({})
  property bool widgetGlyphsLoaded: false
  property bool widgetLooksSeeded: false
  FileView {
    id: widgetGlyphStore
    path: root.widgetGlyphFile
    atomicWrites: true
    printErrors: false
    onLoaded: root.takeWidgetGlyphs(text())
    onLoadFailed: root.takeWidgetGlyphs("")
  }
  function takeWidgetGlyphs(text) {
    if (widgetGlyphsLoaded) return
    widgetGlyphs = GlyphModel.parse(text)
    widgetGlyphsLoaded = true
    glyphReadDelay.restart()
  }
  // Omarchy's WidgetButton (and BarIconButton, which extends it), by shape.
  function glyphButtons(item) {
    var out = [], stack = [item], seen = 0
    while (stack.length && seen < 400) {
      var node = stack.pop()
      seen++
      if (!node) continue
      if (typeof node.text === "string" && node.labelWidth !== undefined && node.textRotation !== undefined)
        out.push({ text: node.text, font: String(node.fontFamily || ""), visible: node.visible !== false && node.opacity !== 0,
          size: node.glyphFontSize > 0 ? node.glyphFontSize : Number(node.fontSize) || 0 })
      var kids = node.children
      if (kids) for (var i = kids.length - 1; i >= 0; i--) stack.push(kids[i])
    }
    return out
  }
  function readWidgetGlyphs() {
    if (!widgetGlyphsLoaded) return
    var store = widgetGlyphs
    for (var slot of moduleSlots) {
      if (!slot || slot.groupHeader || !slot.instanceKey || !slot.activeItem) continue
      var found = GlyphModel.pick(glyphButtons(slot.activeItem))
      store = found ? GlyphModel.merge(store, slot.instanceKey, found) : GlyphModel.forget(store, slot.instanceKey)
    }
    var keys = []
    for (var zone of ["left", "center", "right"])
      for (var entry of ((barConfig.layout || {})[zone] || [])) if (entry && entry.powerbarInstance) keys.push(entry.powerbarInstance)
    if (keys.length) store = GlyphModel.prune(store, keys)
    if (store === widgetGlyphs) return
    widgetGlyphs = store
    widgetGlyphStore.setText(JSON.stringify(store) + "\n")
  }
  // A widget that (re)loads is read again once it has filled its button. One
  // that is new to this session also gets its image saved, on a horizontal
  // bar; a rebuild of known widgets (every config write) captures nothing.
  property var pendingLookKeys: []
  property var lookKnownKeys: Object.create(null)
  function widgetLoaded(key) {
    if (key && !lookKnownKeys[key] && pendingLookKeys.indexOf(key) < 0) pendingLookKeys = pendingLookKeys.concat([key])
    glyphReadDelay.restart()
  }
  Timer {
    id: glyphReadDelay
    interval: 2000
    onTriggered: {
      root.readWidgetGlyphs()
      if (!root.widgetLooksSeeded) return
      var keys = root.pendingLookKeys
      root.pendingLookKeys = []
      for (var key of keys) root.lookKnownKeys[key] = true
      if (keys.length && Quickshell.screens.length) root.captureWidgetImages(Quickshell.screens[0], function() {}, keys)
    }
  }
  property var activityDeadlines: Object.create(null)
  property var slotCopies: Object.create(null)
  // Drawer timing is fixed; Preferences no longer offers it. The shell.json
  // keys still override it for anyone who sets them by hand. Activity keeps a
  // drawer widget on the bar exactly as long as an autohidden bar peeks for it,
  // so the widget and its island leave together.
  readonly property real managedRevealSeconds: ManagedModel.seconds(barConfig.powerbarManagedRevealSeconds, 2.5, 60)
  readonly property real managedEntrySeconds: ManagedModel.seconds(barConfig.powerbarManagedEntryGraceSeconds, 1, 15)
  readonly property real managedExitSeconds: ManagedModel.seconds(barConfig.powerbarManagedExitGraceSeconds, 1, 15)

  // On-demand widgets either open in a drawer island when their zone is
  // hovered ("drawer"), or wait behind the zone's dots and expand in the bar
  // when the dots are hovered ("inline"; docs/design/zone-fit.md).
  readonly property bool onDemandInline: barOptions.onDemand === "inline"
  // The keyboard mode's key strip (Preferences → Bar → Keyboard).
  readonly property bool keyLegend: barOptions.keyLegend
  // The count badge on a zone's dots (drawer handle and yield marker).
  readonly property bool dotsBadge: barOptions.dotsBadge
  onOnDemandInlineChanged: closeManagedDrawer()

  function closeManagedDrawer() { if (managedOwner) managedOwner.close("immediate") }
  onBarHiddenChanged: if (barHidden) closeManagedDrawer()
  // How long an autohidden bar, or one island, stays out after a widget changes.
  readonly property int autoHidePeekMs: Math.round(managedRevealSeconds * 1000)
  // Widgets load their first values just after the bar (re)builds; that is
  // not activity, so peeks wait until the bar has settled.
  property real peekQuietUntil: Date.now() + 6000
  onBarConfigSerialChanged: peekQuietUntil = Date.now() + 6000
  // Widget activity on an autohidden bar: slide out the widget's zone (islands)
  // or the whole bar, and highlight the widget, or its group's icon, meanwhile.
  function autoHidePeek(slot) {
    if (!autoHide || !autoHideActivity || barHidden || !slot) return
    if (!activityPeeksFor(slot.instanceKey, slot.moduleName)) return
    if (Date.now() < peekQuietUntil) return
    var window = slotWindow(slot)
    if (!window || typeof window.peek !== "function") return
    var target = slot, zone = slot.region
    if (slot.memberGroup) {
      zone = slot.memberGroup.section
      target = moduleSlots.find(function(s) {
        return s && s.groupHeader && s.entry.powerbarGroupId === slot.memberGroup.id && sameWindow(slotWindow(s), window)
      }) || slot
    }
    window.peek(zone)
    target.flashActivity()
  }
  function reportActivity(key) {
    if (!key) return
    var until = ManagedModel.deadline(Date.now(), managedRevealSeconds)
    setActivityDeadline(key, until)
    var owner = groupFor(key)
    if (owner && owner.visibility === "managed") setActivityDeadline(GroupsModel.groupKey(owner.id), until)
  }
  function setActivityDeadline(key, until) {
    activityDeadlines[key] = until
    for (var slot of (slotCopies[key] || [])) if (slot) slot.activityUntil = until
  }
  // Whether this config still follows the old visibility default (widgets not
  // from Omarchy On demand) until healVisibility writes it down.
  readonly property bool legacyVisibility: ManagedModel.legacyDefaults(barConfig)
  // Not from Omarchy: a command or QML module, or a plugin the registry does
  // not call first-party (by its id while the registry has not loaded it).
  function thirdPartyEntry(entry) {
    if (customModuleType(entry)) return true
    var id = canonicalWidgetId(entryId(entry))
    var metadata = barWidgetRegistry.metadataFor(id)
    return metadata ? metadata.firstParty !== true : id.indexOf("omarchy.") !== 0
  }
  // Assign stable identities once, preserving duplicate plugin instances on
  // moves. The visibility default is settled in the same write, before the
  // ids exist: they would make a fresh config look like one Powerbar ran on.
  function ensureInstanceIds() {
    if (!canWriteConfig() || !barConfig.layout) return
    var seen = {}, missing = barConfig.powerbarVisibilityDefault !== "shown"
    for (var zone of ["left", "center", "right"]) {
      for (var entry of (barConfig.layout[zone] || [])) {
        var key = entry && entry.powerbarInstance
        if (!key || seen[key]) missing = true
        seen[key] = true
      }
    }
    if (!missing) return
    configStore.writeNow(function(config) {
      ManagedModel.healVisibility(config.bar, root.thirdPartyEntry)
      var used = {}
      for (var zone of ["left", "center", "right"]) {
        var entries = config.bar.layout[zone] || []
        for (var i = 0; i < entries.length; i++) {
          var entry = typeof entries[i] === "string" ? { id: entries[i] } : entries[i]
          if (!entry.powerbarInstance || used[entry.powerbarInstance])
            entry.powerbarInstance = "pw-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2)
          used[entry.powerbarInstance] = true
          entries[i] = entry
        }
      }
    })
  }
  onShellChanged: Qt.callLater(ensureInstanceIds)
  function managedSlots(zone, window) {
    var slots = (window && window.moduleItems || []).filter(function(slot) {
      return slot && slot.moduleName && slot.region === zone && (slot.managed || slot.fitFolded) && !slot.memberGroup
    })
    // Widgets folded off the bar come first, then the zone's managed ones.
    return slots.filter(function(slot) { return slot.fitFolded }).concat(slots.filter(function(slot) { return !slot.fitFolded }))
  }
  function targetsForSlot(slot) { return slot ? slot.slotTargets : [] }
  property var targetSlots: []
  property var pendingTargets: []
  property var targetWatches: []
  Component {
    id: targetWatchFactory
    TargetOwnerObserver {
      id: watch
      onChanged: {
        if (!root) return
        if (target) root.refreshTargetOwner(target)
        else root.dropTargetWatch(watch)
      }
    }
  }
  function dropTargetWatch(watch) {
    var record = targetWatches.find(function(record) { return record.watch === watch })
    if (!record) return
    var owned = pluginObjectRecord(record.target)
    unregisterClickTarget(record.target)
    if (owned) {
      if (owned.popout) releasePopout(record.target)
      apiSync.removeTarget(owned.pluginId, record.target)
      pluginObjectOwners = pluginObjectOwners.filter(function(item) { return item !== owned })
    }
  }
  function refreshTargetOwner(target) {
    if (!target) { unregisterClickTarget(target); return }
    if (clickTargets.indexOf(target) < 0) return
    var previous = targetSlots.find(function(record) { return record.target === target })
    var next = resolveTargetSlot(target)
    if (previous && previous.slot === next) return
    if (previous) {
      detachTarget(previous.slot, target)
      targetSlots = targetSlots.filter(function(record) { return record !== previous })
    }
    pendingTargets = pendingTargets.filter(function(item) { return item !== target })
    if (!attachTarget(target)) pendingTargets.push(target)
  }
  // A slot's own list of targets. A slot that is being destroyed may already
  // have lost its properties while its widget's buttons unregister.
  function detachTarget(slot, target) {
    if (slot && Array.isArray(slot.slotTargets)) slot.slotTargets = slot.slotTargets.filter(function(item) { return item !== target })
  }
  // A destroyed slot's records go with it, so nothing later reads the dead slot.
  function forgetSlotTargets(slot) {
    targetSlots = targetSlots.filter(function(record) { return record.slot !== slot })
  }
  function itemWithin(item, ancestor) {
    for (var p = item; p; p = p.parent) if (p === ancestor) return true
    return false
  }
  function resolveTargetSlot(target) {
    if (!target || target.powerbarPlaceholder === true) return null
    for (var parent = target; parent; parent = parent.parent)
      if (parent.powerbarSlotOwner) return parent.powerbarSlotOwner
    return null
  }
  function attachTarget(target) {
    if (target && target.powerbarPlaceholder === true) return true
    var slot = resolveTargetSlot(target)
    if (!slot) return false
    if (slot.slotTargets.indexOf(target) < 0) slot.slotTargets = slot.slotTargets.concat([target])
    targetSlots.push({ target: target, slot: slot })
    return true
  }
  function resolvePendingTargets() {
    var pending = pendingTargets
    pendingTargets = []
    for (var target of pending) if (clickTargets.indexOf(target) >= 0 && !attachTarget(target)) pendingTargets.push(target)
  }
  // The keyboard's commands pick their bar one way (focusedBarWindow): the
  // focused monitor's, another only while no monitor is focused.
  function openManagedZone(zone) {
    if (["left", "center", "right"].indexOf(zone) < 0) return
    var window = focusedBarWindow()
    if (window && window.managedDrawer) window.managedDrawer.openZone(zone, true)
  }

  IpcHandler {
    target: "powerbar"
    function preferences(): void {
      var name = root.focusedScreenName()
      var screens = Quickshell.screens
      var screen = screens.find(function(screen) { return screen.name === name }) || screens[0]
      preferencesPane.show(screen)
    }
    function closePreferences(): void { preferencesPane.close() }
    function preferencesPage(page: int): void {
      if (!preferencesPane.opened) preferences()
      preferencesPane.setPage(PreferencesModel.pageIndex(page, preferencesPane.pages.length))
    }
    function managed(zone: string): void { root.openManagedZone(zone) }
    function closeManaged(): void { root.closeManagedDrawer() }
    // The keyboard mode on the focused monitor's bar (Super+B by default).
    function keys(): void { root.barKeys.toggle() }
    function keysStatus(): string { return JSON.stringify(root.barKeys.status()) }
    function group(id: string): void {
      var target = root.focusedBarWindow()
      var slot = target && root.moduleSlots.find(function(s) {
        return s.groupHeader && s.entry.powerbarGroupId === id && root.sameWindow(root.targetWindow(s), target)
      })
      if (slot) root.targetWindow(slot).managedDrawer.openGroup(id, slot, true)
    }
    // A group's shortcut: opens its drawer for the keyboard, or closes it.
    function toggleGroup(id: string): void {
      var owner = root.managedOwner
      if (owner && owner.opened && owner.groupId === id) root.closeManagedDrawer()
      else group(id)
    }
    // Groups is the second page (Layout, Groups, Bar).
    function groupsPreferences(): void { preferences(); preferencesPane.setPage(1) }
    function popupStatus(): string {
      return JSON.stringify(root.popupPlacements.filter(function(record) { return record.panel && record.panel.open }).map(function(record) {
        var panel = record.panel
        return { position: panel.barPos, x: panel.cardOrigin.x, y: panel.cardOrigin.y, width: panel.contentWidth, height: panel.contentHeight, screenWidth: panel.screenW, screenHeight: panel.screenH, gap: panel.gap, barExtent: root.barExtent }
      }))
    }
    function drawerStatus(): string {
      var drawer = root.managedOwner
      return JSON.stringify(drawer ? { opened: drawer.opened, aside: drawer.steppedAside, opacity: Math.round(drawer.opacity * 100) / 100, zone: drawer.zone, groupId: drawer.groupId, memberDisplay: drawer.memberDisplay, stripVertical: drawer.stripVertical, surfaceRole: drawer.surfaceRole, surfaceRadius: drawer.surfaceRadius, themeRadius: Style.cornerRadius, crossLength: drawer.crossLength, desiredCross: drawer.desiredCross, reveal: drawer.reveal, width: drawer.width, height: drawer.height, entered: drawer.entered, sourceHovered: drawer.sourceHovered, hovered: drawer.containsMouse, keyboard: drawer.keyboardMode, cursor: drawer.cursor, selectionVisible: drawer.selectionVisible, focused: drawer.activeFocus, ids: drawer.slots.map(function(s) { return s.moduleName }), count: drawer.slots.length } : { opened: false })
    }
    function managedStatus(): string {
      return JSON.stringify(root.moduleSlots.filter(function(s) { return s.managed }).map(function(s) {
        return { id: s.moduleName, key: s.instanceKey, zone: s.region, revealed: s.activityVisible, mainVisible: s.mainVisible, inDrawer: !!s.drawerHost, panelOpen: s.panelOpen, observing: s.activityTargets.length }
      }))
    }
    // Everything Preferences reads and changes, without Preferences
    // (BarCli.qml; `help` lists every function).
    function status(): string { return cliItem.status() }
    function get(setting: string): string { return cliItem.get(setting) }
    function set(setting: string, value: string): string { return cliItem.set(setting, value) }
    function reset(setting: string): string { return cliItem.reset(setting) }
    function toggle(setting: string): string { return cliItem.toggle(setting) }
    function settings(): string { return cliItem.settings() }
    function widgets(): string { return JSON.stringify(cliItem.widgetList()) }
    function setWidget(widget: string, change: string): string { return cliItem.setWidget(widget, change) }
    function groups(): string { return JSON.stringify(cliItem.groupList()) }
    function newGroup(name: string): string { return cliItem.newGroup(name) }
    function setGroup(group: string, change: string): string { return cliItem.setGroup(group, change) }
    function removeGroup(group: string): string { return cliItem.removeGroup(group) }
    function shortcuts(): string { return cliItem.shortcuts() }
    function clearShortcuts(): string { return cliItem.clearShortcuts() }
    function show(): string { return cliItem.show() }
    function hide(): string { return cliItem.hide() }
    function keysOn(): string { return cliItem.keysOn() }
    function keysOff(): string { return cliItem.keysOff() }
    function help(): string { return cliItem.help() }
  }

  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  // Injected by the host shell so bar slots can resolve enabled widgets.
  property var barWidgetRegistry: fallbackBarWidgetRegistry
  // Omarchy hands a full bar a copy of its widget registry. A copy taken while
  // the shell reloads its widgets (switching the bar does) lists widgets whose
  // component is already destroyed, and nothing refreshes it until the shell
  // registers another widget. widgetRepair loads those widgets from their own
  // plugins each time the bar is handed a copy and each time the copy changes.
  WidgetRepair {
    id: repairItem
    registry: root.barWidgetRegistry
  }
  property alias widgetRepair: repairItem
  // Read-only registry view for third-party full bars; the built-in bar does
  // not otherwise need it, but declaring it keeps clone construction atomic.
  property var pluginRegistry: null
  // Injected by the host shell every time shell.json is reloaded. Holds the
  // `bar:` subtree: position, centerAnchor, layout. The host owns file IO;
  // the bar just renders whatever it's handed. The bar font follows the
  // OS-level fontconfig monospace binding — it is not stored in shell.json.
  property var barConfig: ({})
  // Injected by the host shell. Used for shell-wide actions such as opening
  // settings and persisting inline widget state.
  property var shell: null
  // Manifest for the active bar option. Present for custom bars and useful for
  // diagnostics; the built-in bar does not otherwise need it.
  property var manifest: null
  QtObject {
    id: fallbackBarWidgetRegistry
    property var widgets: ({})
    property int revision: 0
    function metadataFor(id) { return null }
  }
  // Mirrors the on-disk `bar-off` flag so the user can hide the bar without
  // killing the entire shell. Hidden panels stay mapped but park off-screen
  // without an exclusion zone; updated by the FileView watcher further down.
  property bool barOffFlag: false
  // The keyboard mode shows a switched-off bar while it lasts; the flag itself
  // is never touched.
  readonly property bool barHidden: barOffFlag && !barKeysItem.active
  property string home: Quickshell.env("HOME")
  property string stateHome: home + "/.local/state"
  property string omarchyConfigDir: home + "/.config/omarchy"
  property var fallbackBarConfig: ({
    position: "top",
    transparent: false,
    centerAnchor: "omarchy.clock",
    layout: { left: [], center: [], right: [] }
  })
  property var layoutConfig: fallbackBarConfig.layout
  property string centerAnchor: ""
  property bool requestedTransparent: false
  property bool useTransparentForeground: false
  property bool transparent: false
  property int centerHoverCount: 0
  readonly property bool centerSectionHovered: centerHoverCount > 0
  property bool centerSectionRevealHeld: false
  // A centre side expanding inline, or asked for on its dots, keeps the
  // indicators' hover reveal from opening; it never closes one already open.
  // The dots sit at the outer end of the side the indicators grow, so either
  // change would slide them out from under the pointer resting on them (and
  // slide another zone's widgets in). Counted per bar window.
  property int centerRevealBlocks: 0
  // When the block lifts with the pointer still on the centre (a swipe across
  // the dots, an expansion that collapsed), the reveal opens.
  onCenterRevealBlocksChanged: if (centerRevealBlocks === 0) Qt.callLater(root.openCenterReveal)
  // One bar surface exists per monitor and each reports into this count, so a
  // pointer crossing between monitors stays counted however events interleave.
  property int barHoverCount: 0
  readonly property bool barHovered: barHoverCount > 0
  property bool centerHoverRevealSuppressed: false
  property int barConfigSerial: 0
  property bool reconcilingStructure: false
  property string position: "top"
  // Resolves through fontconfig at paint time (Style.font.family defaults
  // to "monospace"), so changing the system font (via `omarchy-font-set`)
  // updates the bar without a reload.
  property string fontFamily: Style.font.family
  // Bound to the central Color singleton so the bar tracks shell.toml's
  // [bar] section. Property names kept for the rest of this file's bindings.
  property color themeForeground: Color.bar.text
  property color themeContrastForeground: Color.background
  property color transparentForeground: Color.bar.text
  property color foreground: themeForeground
  // Text and icons on every Powerbar surface (Bar > Surface > Text and icons):
  // the theme's colours unless a fixed light or dark one is chosen. Omarchy's
  // transparent bar guesses a colour from the wallpaper; Powerbar draws a
  // surface in every style and cannot know what shows through it, so it never
  // guesses (AppearanceModel.foreground).
  readonly property string foregroundChoice: AppearanceModel.foreground(appearanceConfig, themeName)
  // Shape, Surface and Shadow follow the theme, the user's values for every
  // theme, or the user's values for this theme (AppearanceModel, "scopes").
  // The theme's part is its powerbar.toml where it ships one, then Omarchy's.
  property var themeLook: ({})
  FileView {
    id: themeLookFile
    path: root.stateHome + "/omarchy/current/theme/powerbar.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeLook = AppearanceModel.parseLook(text())
    onLoadFailed: root.themeLook = ({})
    onFileChanged: reload()
  }
  onThemeNameChanged: { themeLookFile.reload(); Qt.callLater(healAppearance) }
  readonly property var appearance: AppearanceModel.resolve(AppearanceModel.appearanceOf(barConfig, themeName), themeName, themeLook)
  // The bar's config with the resolved values in the keys the drawing reads.
  readonly property var appearanceConfig: AppearanceModel.flatten(barConfig, themeName, themeLook)
  // Tooltips, the keyboard name card and the key legend. A tile they follow
  // draws them as Omarchy draws that kind of surface while it follows a theme
  // without a Powerbar look of its own, and like the bar once it is yours (or
  // the theme's Powerbar look): one look for every Powerbar surface.
  readonly property var overlayStyled: ({
    shape: appearance.scopes.shape !== "theme" || appearance.look.shape,
    surface: appearance.scopes.surface !== "theme" || appearance.look.surface,
    shadow: appearance.scopes.shadow !== "theme" || appearance.look.shadow
  })
  readonly property bool overlayShadow: overlayStyled.shadow && surfaceEffects.shadow
  // Room around an overlay for its shadow, inside its window.
  readonly property real overlayShadowPad: overlayShadow ? Math.ceil(surfaceEffects.shadowSize) : 0
  // Earlier versions' flat keys move into powerbarAppearance once, and
  // themes no longer installed lose what was kept for them.
  // Earlier versions' values become the current theme's own, so migration
  // waits until the theme is known.
  function healAppearance() {
    if (!canWriteConfig() || !themeName || !AppearanceModel.legacyPresent(barConfig)) return
    var theme = themeName
    writeConfig(function(config) { if (config.bar) AppearanceModel.migrate(config.bar, theme) })
  }
  property var installedThemes: []
  // Themes come and go while the shell runs (omarchy-theme-set applies a new
  // one without a restart), so the list is read again before every prune;
  // pruning from a list read at startup would drop a theme installed since.
  property bool themesAgain: false
  function refreshThemes() {
    if (installedThemesProc.running) themesAgain = true
    else installedThemesProc.running = true
  }
  Process {
    id: installedThemesProc
    running: true
    onExited: if (root.themesAgain) { root.themesAgain = false; Qt.callLater(root.refreshThemes) }
    command: ["bash", "-c", "ls -1 \"${OMARCHY_PATH:-/usr/share/omarchy}/themes\" \"$HOME/.config/omarchy/themes\" 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n").map(function(l) { return l.trim() })
        // Both folders listed (ls heads each with "path:"), or nothing is
        // pruned: a partial list would drop themes that are still there.
        if (lines.filter(function(l) { return l.slice(-1) === ":" }).length !== 2) return
        root.installedThemes = lines.filter(function(l) { return l && l.slice(-1) !== ":" })
        root.pruneAppearanceThemes()
      }
    }
  }
  function pruneAppearanceThemes() {
    var keep = installedThemes.concat(themeName ? [themeName] : [])
    if (!installedThemes.length || !canWriteConfig() || !AppearanceModel.hasStaleThemes(barConfig, keep)) return
    writeConfig(function(config) { if (config.bar) AppearanceModel.pruneThemes(config.bar, keep) })
  }
  // The current Omarchy theme, which a Light or Dark choice belongs to. A theme
  // switch replaces the file, so it is also read again when the colours change.
  property string themeName: ""
  FileView {
    id: themeNameFile
    path: root.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeName = String(text() || "").trim()
    onLoadFailed: root.themeName = ""
    onFileChanged: reload()
  }
  readonly property var foregroundPair: AppearanceModel.textPair(themeForeground, themeContrastForeground)
  // Over a transparent bar (Omarchy's `bar.transparent`), the colour Omarchy
  // reads from the wallpaper, as its own bar does.
  property color barForeground: textOn(useTransparentForeground && AppearanceModel.wallpaperText(mainSurfaceColor.a, foregroundChoice)
    ? transparentForeground : themeForeground)
  // The chosen colour, or `themeColor` (the theme's own for that place) when
  // the choice is the theme's.
  function textOn(themeColor) {
    return foregroundChoice === "light" ? foregroundPair.light : foregroundChoice === "dark" ? foregroundPair.dark : themeColor
  }
  property bool foregroundAnimationEnabled: true
  property color background: Color.bar.background
  property color urgent: Color.bar.active

  // Omarchy's bar fades the text colour unless a switch asks for it at once;
  // with Animations off it never fades, here or in widgets (foregroundFades).
  readonly property bool foregroundFades: foregroundAnimationEnabled && animationsEnabled
  Behavior on barForeground { enabled: root.foregroundFades; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on background { enabled: root.animationsEnabled; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on urgent { enabled: root.animationsEnabled; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0
  property var activePopout: null
  property var barDragSource: null
  property var barDragDrop: null
  property string barDragSourceSurface: ""
  property var barDragSourceRect: null
  property var barDragWindow: null
  property var barDragScreen: null
  property url barDragImageUrl: ""
  property bool barDragImageReady: false
  property real barDragImageWidth: 0
  property real barDragImageHeight: 0
  property real barDragScreenX: 0
  property real barDragScreenY: 0
  // Where the pointer last was, to read the drop again when the bar changes
  // under a still pointer (an expansion opening or closing).
  property var barDragScene: null
  // The bar zone the drag is over, by its drop; "" off the bar or over a
  // drawer. An inline expansion holds only while the drag stays in its zone.
  readonly property string barDragZone: {
    var d = barDragDrop
    if (!barDragSource || !d) return ""
    if (d.handle) return d.managedZone || ""
    if (d.source) return barDragSource.region || ""
    if (d.slot) return d.slot.drawerHost ? "" : d.slot.region || ""
    return d.zone || ""
  }
  // The dots holding the drop, and where they were when they took it.
  property var barDragHandleHeld: null
  // The drop shown lands the widget On demand (behind the zone's dots).
  readonly property bool barDragLandsOnDemand: {
    var d = barDragDrop, source = barDragSource
    if (!source || !d || !d.slot || d.into || d.slot.drawerHost) return false
    return barGapOnDemand(d.slot, d.after, source)
  }
  function refreshIconDrag() {
    if (barDragSource && barDragScene) updateIconDrag(barDragScene, barDragSource)
  }
  property real barDragOffsetX: 0
  property real barDragOffsetY: 0
  // Release settle: a committed drop rebuilds every slot, so the captured
  // image glides from the pointer into the new slot while that slot stays
  // hidden. Without this the icon vanishes on release and pops in later.
  property bool barDragSettling: false
  property int barDragSettleEpoch: 0
  property string barDragSettleKey: ""
  property var barDragSettleWindow: null
  property var barDragSettleItem: null
  property bool barDragSettleFade: false
  property real barDragSettleFromX: 0
  property real barDragSettleFromY: 0
  property real barDragSettleProgress: 0
  // Local point on barDragSettleItem where the image centre lands; null centres it.
  property var barDragSettleLocal: null
  // A drop whose commit waits until the image has glided into its preview gap.
  property var barDragPendingDrop: null
  property int barDragSettleDuration: dragSettleDuration
  readonly property int dragSettleDuration: 180
  readonly property int dragSettleCorrectionDuration: 90
  readonly property bool dragMotionActive: !!barDragSource || barDragSettling
  NumberAnimation {
    id: dragSettleAnimation
    target: root
    property: "barDragSettleProgress"
    from: 0
    to: 1
    duration: root.barDragSettleDuration
    easing.type: Easing.OutCubic
    onFinished: root.finishDragSettleAnimation()
  }
  readonly property var dragPreview: {
    var source = barDragSource
    var drop = barDragDrop
    var surface = "", key = "", after = false
    if (drop && drop.slot) {
      key = drop.slot.instanceKey
      surface = root.dragSurfaceForSlot(drop.slot)
      after = drop.after === true
    } else if (drop && drop.drawer) {
      surface = root.dragSurfaceForDrawer(drop.drawer)
    } else if (drop && drop.zone) {
      surface = "bar:" + drop.zone
    } else if (drop && drop.managedZone) {
      surface = "managed:" + drop.managedZone
    } else if (drop && drop.source && source) {
      key = source.instanceKey
      surface = barDragSourceSurface
    }
    return { ready: !!source && barDragImageReady, sourceKey: source ? source.instanceKey : "", into: !!drop && drop.into === true,
      sourceSurface: barDragSourceSurface, targetKey: key, targetSurface: surface, after: after,
      self: !!drop && drop.source === true }
  }
  // The gap a drag opens is the dragged widget's own landing size: its cell
  // plus a gutter (Equal slots) or its glyph plus a gap (Equal gaps).
  // The commit clears the source before the released icon has settled, so the
  // settle keeps its landing size: the gap and the slot that replaces it stay
  // the same length, and the island never swells and shrinks back.
  property real barDragSettleLanding: 0
  readonly property real dragLandingExtent: barDragSource && barDragSource.landingExtent > 0 ? barDragSource.landingExtent
    : barDragSettling && barDragSettleLanding > 0 ? barDragSettleLanding : 0
  readonly property real dragGapWidth: !vertical && dragLandingExtent > 0 ? dragLandingExtent
    : Math.max(barSize, barDragImageWidth) + cellTokens.gutter
  readonly property real dragGapHeight: vertical && dragLandingExtent > 0 ? dragLandingExtent
    : Math.max(barSize, barDragImageHeight) + cellTokens.gutter
  property bool barMoveActive: false
  property string barMoveCandidate: ""
  property var barMoveWindow: null
  property var barMoveScreen: null
  property var clickTargets: []
  property var moduleSlots: []
  property var pluginBarApis: ({})
  property var pluginObjectOwners: []

  Component {
    id: pluginBarApiComponent
    PluginBarApi { }
  }

  PluginApiSync {
    id: apiSync
    apis: root.pluginBarApis
    popout: root.activePopout
    layoutJSON: JSON.stringify(root.layoutConfig || {})
    owns: function(id, target) { return root.pluginOwnsBarObject(id, target) }
  }

  function bindPluginBarApi(api) {
    if (!api) return
    api.foreground = Qt.binding(function() { return root.foreground })
    api.barForeground = Qt.binding(function() { return root.barForeground })
    api.background = Qt.binding(function() { return root.background })
    api.urgent = Qt.binding(function() { return root.urgent })
    api.fontFamily = Qt.binding(function() { return root.fontFamily })
    api.position = Qt.binding(function() { return root.position })
    api.vertical = Qt.binding(function() { return root.vertical })
    api.barSize = Qt.binding(function() { return root.barSize })
    api.transparent = Qt.binding(function() { return root.transparent })
    api.foregroundAnimationEnabled = Qt.binding(function() { return root.foregroundFades })
    api.centerSectionRevealHeld = Qt.binding(function() { return root.centerSectionRevealHeld })
    api._centerHoverRevealSuppressed = Qt.binding(function() { return root.centerHoverRevealSuppressed })
    apiSync.initialize(api)
  }

  function pluginObjectRecord(target) {
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var record = pluginObjectOwners[i]
      if (record && record.target === target) return record
    }
    return null
  }

  function markPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    if (!key || !target) return false
    var record = root.pluginObjectRecord(target)
    if (record && record.pluginId !== key) return false
    if (record && record[role] === true) return true
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var existing = pluginObjectOwners[i]
      if (!existing || existing.target !== target) next.push(existing)
    }
    var updated = record || { target: target, pluginId: key, clickTarget: false, popout: false }
    updated[role] = true
    next.push(updated)
    pluginObjectOwners = next
    return true
  }

  function unmarkPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var record = pluginObjectOwners[i]
      if (!record || record.target !== target || record.pluginId !== key) {
        next.push(record)
        continue
      }
      record[role] = false
      if (record.clickTarget || record.popout) next.push(record)
    }
    pluginObjectOwners = next
  }

  function pluginOwnsBarObject(pluginId, target) {
    var record = target ? root.pluginObjectRecord(target) : null
    return !!record && record.pluginId === String(pluginId || "")
  }

  function pluginClickTargets(pluginId) { return apiSync.targets[pluginId] || [] }

  function registerPluginClickTarget(pluginId, target) {
    if (!root.markPluginObject(pluginId, target, "clickTarget")) return
    root.registerClickTarget(target)
    apiSync.addTarget(pluginId, target)
  }

  function unregisterPluginClickTarget(pluginId, target) {
    if (!root.pluginOwnsBarObject(pluginId, target)) return
    root.unregisterClickTarget(target)
    apiSync.removeTarget(pluginId, target)
    root.unmarkPluginObject(pluginId, target, "clickTarget")
  }

  function requestPluginPopout(pluginId, owner) {
    if (!root.markPluginObject(pluginId, owner, "popout")) return
    root.requestPopout(owner)
  }

  function releasePluginPopout(pluginId, owner) {
    if (!root.pluginOwnsBarObject(pluginId, owner)) return
    root.releasePopout(owner)
    root.unmarkPluginObject(pluginId, owner, "popout")
  }

  function pluginBarApiFor(pluginId, moduleName, registered) {
    var key = String(pluginId || "")
    if (!key) return null

    var pluginShell = null
    if (registered && root.shell && typeof root.shell.pluginShellForId === "function") {
      // Only the trusted built-in bar receives ShellRoot and can request a
      // service-capable facade for the widget it is instantiating.
      pluginShell = root.shell.pluginShellForId(moduleName)
    } else if (root.shell && typeof root.shell.pluginShellForBarEntry === "function") {
      // Replacement bars receive a service-less entry facade. Giving an
      // untrusted bar a generic facade factory would let it retrieve another
      // third-party plugin's live service object.
      pluginShell = root.shell.pluginShellForBarEntry(key, moduleName)
    }

    if (pluginBarApis[key]) {
      pluginBarApis[key].shell = pluginShell
      return pluginBarApis[key]
    }

    var api = pluginBarApiComponent.createObject(null, {
      pluginId: key,
      moduleName: String(moduleName || ""),
      shell: pluginShell,
      _showTooltip: function(target, text) { root.showTooltip(target, text) },
      _hideTooltip: function(target) { root.hideTooltip(target) },
      _registerClickTarget: function(target) { root.registerPluginClickTarget(key, target) },
      _unregisterClickTarget: function(target) { root.unregisterPluginClickTarget(key, target) },
      _requestPopout: function(owner) { root.requestPluginPopout(key, owner) },
      _releasePopout: function(owner) { root.releasePluginPopout(key, owner) },
      _switchPanelFrom: function(owner, direction) { return root.switchPanelFrom(owner, direction) },
      _targetBelongsToWindow: function(target, window) { return root.targetBelongsToWindow(target, window) },
      _moduleWidgets: function(requestedId) {
        return String(requestedId || "") === String(moduleName || "")
          ? root.moduleWidgets(moduleName) : []
      },
      _run: function(command) { root.run(command) },
      _setCenterHoverRevealSuppressed: function(value) {
        root.centerHoverRevealSuppressed = !!value
      }
    })
    if (!api) return null
    root.bindPluginBarApi(api)

    var next = ({})
    for (var id in pluginBarApis) next[id] = pluginBarApis[id]
    next[key] = api
    pluginBarApis = next
    return api
  }

  function pluginBarApiUsed(pluginId) {
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.pluginApiId === pluginId) return true
    }
    return false
  }

  function releasePluginObjects(pluginId) {
    var owned = pluginObjectOwners.slice()
    for (var i = 0; i < owned.length; i++) {
      var record = owned[i]
      if (!record || record.pluginId !== pluginId) continue
      if (record.clickTarget) { root.unregisterClickTarget(record.target); apiSync.removeTarget(pluginId, record.target) }
      if (record.popout && root.activePopout === record.target) root.releasePopout(record.target)
    }
    pluginObjectOwners = pluginObjectOwners.filter(function(record) {
      return record && record.pluginId !== pluginId
    })
  }

  function prunePluginBarApis() {
    var next = ({})
    for (var id in pluginBarApis) {
      var api = pluginBarApis[id]
      if (root.pluginBarApiUsed(id)) {
        next[id] = api
        continue
      }
      root.releasePluginObjects(id)
      apiSync.forget(id)
      if (api && typeof api.destroy === "function") api.destroy()
    }
    pluginBarApis = next
  }

  onModuleSlotsChanged: Qt.callLater(prunePluginBarApis)

  Component.onDestruction: {
    flushConfigWrites()
    for (var id in pluginBarApis) {
      root.releasePluginObjects(id)
      if (pluginBarApis[id] && typeof pluginBarApis[id].destroy === "function")
        pluginBarApis[id].destroy()
    }
    pluginBarApis = ({})
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
    var watch = target.powerbarPlaceholder === true ? null : targetWatchFactory.createObject(root, { target: target })
    if (watch) targetWatches.push({ target: target, watch: watch })
    if (!attachTarget(target)) { pendingTargets.push(target); Qt.callLater(resolvePendingTargets) }
  }

  function unregisterClickTarget(target) {
    if (clickTargets.indexOf(target) < 0) return
    targetWatches = targetWatches.filter(function(record) {
      if (record.target !== target) return true
      record.watch.target = null
      record.watch.destroy()
      return false
    })
    targetSlots = targetSlots.filter(function(record) {
      if (record.target !== target) return true
      detachTarget(record.slot, target)
      return false
    })
    pendingTargets = pendingTargets.filter(function(t) { return t !== target })
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    slotCopies[slot.instanceKey] = (slotCopies[slot.instanceKey] || []).concat([slot])
    slot.activityUntil = activityDeadlines[slot.instanceKey] || 0
    moduleSlots = next
    Qt.callLater(resolvePendingTargets)
  }

  function unregisterModuleSlot(slot) {
    var copies = (slotCopies[slot.instanceKey] || []).filter(function(item) { return item !== slot })
    if (copies.length) slotCopies[slot.instanceKey] = copies
    else delete slotCopies[slot.instanceKey]
    var next = moduleSlots.filter(function(item) { return item !== slot })
    moduleSlots = next
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0)
      })
    }
    return out
  }

  function targetWindow(target) {
    return target && target.powerbarRetainedSlot === true && target.homeWindow
      ? target.homeWindow : target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return slot.homeWindow || targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function targetTooltipHovered(target) {
    // The keyboard cursor's name card stays while the cursor is there.
    if (!!target && barKeysItem.here && target === barKeysItem.cardTarget) return true
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  // Once a tooltip has been read, its neighbours along the bar show at once.
  property real tooltipWarmUntil: 0
  function clearTooltip() {
    if (tooltipShown) tooltipWarmUntil = Date.now() + 800
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function clearBarDrag() {
    // Interrupting a glide (a new press, a destroyed source) still applies the
    // drop the user already made.
    commitPendingDrop()
    springOpen.stop()
    springClose.stop()
    springGroupSlot = null
    springOpenedDrawer = null
    barDragSource = null
    barDragScene = null
    barDragHandleHeld = null
    barDragSourceSurface = ""
    barDragSourceRect = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragImageReady = false
    barDragImageLabelled = false
    barDragImageFromCell = false
    barDragImageWidth = 0
    barDragImageHeight = 0
    barDragDrop = null
    barDragScreenX = 0
    barDragScreenY = 0
    barDragOffsetX = 0
    barDragOffsetY = 0
    dragSettleAnimation.stop()
    barDragSettleEpoch++
    barDragSettling = false
    barDragSettleKey = ""
    barDragSettleWindow = null
    barDragSettleItem = null
    barDragSettleLocal = null
    barDragSettleFade = false
    barDragSettleProgress = 0
    barDragSettleDuration = dragSettleDuration
    barDragSettleLanding = 0
  }

  function windowScreenPoint(scenePoint, window) {
    var x = scenePoint ? scenePoint.x : 0
    var y = scenePoint ? scenePoint.y : 0
    if (!window || !window.screen) return { x: x, y: y }

    if (root.position === "bottom")
      y += Math.max(0, window.screen.height - window.height)
    else if (root.position === "right")
      x += Math.max(0, window.screen.width - window.width)

    return { x: x, y: y }
  }

  function barDragScreenPoint(scenePoint) {
    return windowScreenPoint(scenePoint, barDragWindow)
  }

  // Split the screen along its diagonals (in normalized space, so widescreens
  // don't bias toward left/right): whichever triangle holds the cursor names
  // the candidate edge.
  function nearestScreenEdge(point, screen) {
    var nx = screen.width > 0 ? Util.clamp(point.x / screen.width, 0, 1) : 0.5
    var ny = screen.height > 0 ? Util.clamp(point.y / screen.height, 0, 1) : 0.5

    var edge = "top"
    var best = ny
    if (1 - ny < best) { edge = "bottom"; best = 1 - ny }
    if (nx < best) { edge = "left"; best = nx }
    if (1 - nx < best) { edge = "right"; best = 1 - nx }
    return edge
  }

  function beginBarMove(window) {
    barMoveWindow = window
    barMoveScreen = window ? window.screen : null
    barMoveCandidate = position
    barMoveActive = true
  }

  function updateBarMove(screenPoint) {
    if (!barMoveActive || !barMoveScreen) return
    barMoveCandidate = nearestScreenEdge(screenPoint, barMoveScreen)
  }

  function clearBarMove() {
    barMoveActive = false
    barMoveCandidate = ""
    barMoveWindow = null
    barMoveScreen = null
  }

  function finishBarMove() {
    var edge = barMoveCandidate
    if (!barMoveActive || !edge || edge === position) {
      clearBarMove()
      return
    }

    clearBarMove()
    setBarPosition(edge)
  }

  function setBarPosition(value) {
    var next = normalizePosition(value)
    if (root.canWriteConfig()) {
      root.writeConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.position = next
      })
    } else {
      root.position = next
    }
  }

  // The image is the widget's own look. A menu row also holds the name, which
  // the ghost adds itself where a menu wants it, so a row that shows the
  // widget gives just the widget (the grab offset moves with it).
  property bool barDragImageLabelled: false
  // The image is a drawer member's whole cell, not just the widget.
  property bool barDragImageFromCell: false
  function captureBarDragGhost(slot) {
    var host = slot ? slot.drawerHost : null
    var item = !slot ? null : host && !(host.labelled && host.showNative) ? host : slot.presentationItem
    barDragImageUrl = ""
    barDragImageReady = false
    barDragImageLabelled = !!host && item === host && host.labelled === true
    barDragImageFromCell = !!host && item === host
    if (host && item === slot.presentationItem) {
      barDragOffsetX -= item.x
      barDragOffsetY -= item.y
    }
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageWidth = grabWidth
      root.barDragImageHeight = grabHeight
      root.barDragImageUrl = result.url
    }, Qt.size(grabWidth, grabHeight))
  }

  function dragSurfaceForDrawer(drawer) {
    return drawer.groupId ? "group:" + drawer.groupId : "managed:" + drawer.zone
  }

  function dragSurfaceForSlot(slot) {
    if (!slot.drawerHost) return "bar:" + slot.region
    var window = root.slotWindow(slot)
    return window && window.managedDrawer ? root.dragSurfaceForDrawer(window.managedDrawer) : ""
  }

  function beginIconDrag(slot, window, scenePoint, offsetX, offsetY) {
    if (root.barDragSettling) root.clearBarDrag()
    if (!slot || !window || root.barDragSource) return false
    root.barDragWindow = window
    root.barDragScreen = window.screen
    root.barDragSourceSurface = root.dragSurfaceForSlot(slot)
    var visual = slot.drawerHost || slot
    var origin = visual.mapToItem(null, 0, 0)
    root.barDragSourceRect = { x: origin.x, y: origin.y,
      width: visual.width, height: visual.height }
    root.barDragOffsetX = offsetX
    root.barDragOffsetY = offsetY
    root.barDragSource = slot
    // A pointer drag ends keyboard use of an open drawer: it stops holding the
    // keyboard (and the outside-click grab), and closes on hover like any
    // other. Kept open after a drop, it no longer swallows the next click.
    var owner = root.managedOwner
    if (owner && owner.keyboardMode) { owner.keyboardMode = false; owner.cursorActive = false }
    // A group's own drawer hangs off the icon being moved: it closes.
    if (owner && slot.groupHeader && owner.groupId && owner.groupId === slot.entry.powerbarGroupId) owner.close("immediate")
    root.captureBarDragGhost(slot)
    root.hideTooltip(slot.activeItem)
    root.updateIconDrag(scenePoint, slot)
    return true
  }

  // A drag resting on a group icon opens that group's drawer, so the widget
  // can be dropped among its members; leaving both closes it again.
  property var springGroupSlot: null
  property var springOpenedDrawer: null
  Timer {
    id: springOpen
    interval: 400
    onTriggered: {
      var slot = root.springGroupSlot
      var window = slot ? root.slotWindow(slot) : null
      if (!root.barDragSource || !window || !window.managedDrawer) return
      window.managedDrawer.openGroup(slot.entry.powerbarGroupId, slot, false)
      root.springOpenedDrawer = window.managedDrawer
    }
  }
  // The spring-opened drawer stays while the pointer is on the group icon, in
  // the drawer, or crossing between them; otherwise it closes after a short
  // grace, so a pointer drifting on its way to the drawer does not lose it.
  Timer {
    id: springClose
    interval: 450
    onTriggered: {
      var drawer = root.springOpenedDrawer
      root.springOpenedDrawer = null
      if (drawer && drawer.opened) drawer.close()
    }
  }
  function onSpringPath(drawer, scenePoint) {
    if (!drawer || !drawer.opened || !scenePoint) return false
    var p = drawer.mapFromItem(null, scenePoint.x, scenePoint.y)
    var reach = drawer.gap + root.barExtent + Style.space(8)
    var margin = Style.space(12)
    return root.vertical
      ? p.y >= -margin && p.y <= drawer.height + margin && p.x >= -reach && p.x <= drawer.width + reach
      : p.x >= -margin && p.x <= drawer.width + margin && p.y >= -reach && p.y <= drawer.height + reach
  }
  // A drag resting on a zone's dots opens the zone the way the dots do: in
  // the bar (inline mode), or its drawer. Dropping on the dots themselves
  // makes the widget On demand there.
  property string springHandleZone: ""
  Timer {
    id: springHandle
    interval: 400
    onTriggered: {
      var token = root.springHandleZone, zone = token.split(":")[0]
      var window = root.barDragWindow
      if (!root.barDragSource || !zone || !window) return
      if (root.onDemandInline) {
        window.inlineEnter(token, true)
        // A zone that can't expand opens its drawer; it closes like a group's.
        if (window.managedDrawer && window.managedDrawer.opened && window.managedDrawer.zone === zone) root.springOpenedDrawer = window.managedDrawer
      } else if (window.managedDrawer) {
        window.managedDrawer.openZone(zone, false)
        root.springOpenedDrawer = window.managedDrawer
      }
    }
  }
  function updateSpringGroup(drop, source, overGroup, scenePoint) {
    var canSpring = source && !source.groupHeader && !source.drawerHost
    var target = canSpring && overGroup ? overGroup : null
    if (target !== springGroupSlot) {
      springGroupSlot = target
      if (target) springOpen.restart()
      else springOpen.stop()
    }
    var handleZone = source && !source.drawerHost && drop && drop.handle ? drop.handleToken : ""
    if (handleZone !== springHandleZone) {
      springHandleZone = handleZone
      if (handleZone) springHandle.restart()
      else springHandle.stop()
    }
    var drawer = springOpenedDrawer
    if (!drawer) return
    var keep = !!target || !!handleZone || onSpringPath(drawer, scenePoint)
      || (drop && (drop.drawer === drawer || (drop.slot && drop.slot.drawerHost)))
    if (keep) springClose.stop()
    else if (!springClose.running) springClose.start()
  }
  function groupSlotAt(scenePoint, source) {
    var window = root.slotWindow(source) || root.barDragWindow
    return (window && window.moduleItems || []).find(function(slot) {
      if (!slot || !slot.groupHeader || slot.drawerHost || !slot.mainVisible || !root.sameWindow(root.slotWindow(slot), window)) return false
      var p = slot.mapFromItem(null, scenePoint.x, scenePoint.y)
      return p.x >= 0 && p.y >= 0 && p.x < slot.width && p.y < slot.height
    }) || null
  }

  function updateIconDrag(scenePoint, slot) {
    if (root.barDragSource !== slot) return
    root.barDragScene = { x: scenePoint.x, y: scenePoint.y }
    var screenPoint = root.barDragScreenPoint(scenePoint)
    root.barDragScreenX = screenPoint.x
    root.barDragScreenY = screenPoint.y
    var drop = root.moduleDropAtScene(scenePoint, slot)
    root.holdHandle(drop)
    root.updateSpringGroup(drop, slot, root.groupSlotAt(scenePoint, slot), scenePoint)
    var old = root.barDragDrop
    if (old && drop && old.source === drop.source && old.slot === drop.slot && old.after === drop.after &&
        old.drawer === drop.drawer && old.zone === drop.zone && old.managedZone === drop.managedZone && old.handle === drop.handle && old.handleToken === drop.handleToken && old.into === drop.into) return
    root.barDragDrop = drop
  }

  function holdHandle(drop) {
    var window = root.barDragWindow
    var handle = drop && drop.handle && window ? window.foldHandles.find(function(h) {
      return h && h.shown && h.visible && h.inlineToken === drop.handleToken
    }) : null
    if (!handle) { barDragHandleHeld = null; return }
    if (barDragHandleHeld && barDragHandleHeld.handle === handle) return
    var a = handle.mapToItem(window.contentItem, 0, 0), b = handle.mapToItem(window.contentItem, handle.width, handle.height)
    barDragHandleHeld = { handle: handle, x1: Math.min(a.x, b.x), y1: Math.min(a.y, b.y), x2: Math.max(a.x, b.x), y2: Math.max(a.y, b.y) }
  }

  function finishIconDrag(scenePoint, slot) {
    if (root.barDragSource !== slot) return false
    // The drop the preview shows: recomputing at release read a layout the open
    // gap had already shifted, so the icon could land beside the gap it glided
    // into and then slide to where it was committed.
    var drop = root.barDragDrop || root.moduleDropAtScene(scenePoint, slot)
    var predicted = drop && !drop.source && root.canSettleDrag() ? root.predictDropSettle(slot, drop) : null
    if (predicted) {
      // Glide into the open preview gap first and commit once the image has
      // landed. The commit rebuilds every slot synchronously, so committing at
      // release held the image frozen where the pointer let go.
      root.beginDragSettle(slot, scenePoint, true)
      root.barDragPendingDrop = { slot: slot, drop: drop }
      root.barDragSettleItem = predicted.item
      root.barDragSettleLocal = predicted.local
      root.barDragSettleFade = predicted.fade
      dragSettleAnimation.restart()
      return true
    }
    // A drop into an open gap on the bar swaps the gap for the slot in one
    // frame, as a glided drop does; a cancelled drag still eases back.
    var handover = !!drop && !drop.source && !drop.into && ((!!drop.slot && !drop.slot.drawerHost) || !!drop.zone)
    if (handover) root.dragHandover = true
    root.beginDragSettle(slot, scenePoint, false)
    var changed = false
    try {
      changed = drop ? root.dropBarModuleAtTarget(slot, drop) : false
    } finally {
      if (handover) Qt.callLater(function() { root.dragHandover = false })
    }
    if (!root.barDragSettling) return changed
    // The commit rebuilds the Repeaters synchronously; the settle target is
    // looked up once the new delegates exist and the drawer has closed.
    var epoch = root.barDragSettleEpoch
    Qt.callLater(function() { if (root.barDragSettleEpoch === epoch) root.resolveDragSettle(false) })
    return changed
  }

  function canSettleDrag() {
    return root.animationsEnabled && root.barDragImageReady && String(root.barDragImageUrl) !== ""
  }

  // Release the gesture but keep the captured image. Settling is set before the
  // source is cleared so the ghost layer surface is never unmapped in between.
  // keepPreview leaves the drop gap open while the image glides into it.
  function beginDragSettle(slot, scenePoint, keepPreview) {
    if (!root.canSettleDrag()) {
      root.clearBarDrag()
      return
    }
    var screenPoint = root.barDragScreenPoint(scenePoint)
    root.barDragSettleEpoch++
    root.barDragSettleFromX = screenPoint.x - root.barDragOffsetX
    root.barDragSettleFromY = screenPoint.y - root.barDragOffsetY
    root.barDragSettleKey = slot.instanceKey
    root.barDragSettleWindow = root.slotWindow(slot) || root.barDragWindow
    root.barDragSettleItem = null
    root.barDragSettleLocal = null
    root.barDragSettleFade = false
    root.barDragSettleProgress = 0
    root.barDragSettleDuration = root.dragSettleDuration
    root.barDragSettleLanding = root.dragLandingExtent
    root.barDragSettling = true
    if (keepPreview) return
    root.barDragSource = null
    root.barDragDrop = null
  }

  // Where the released image lands before the layout commits: the centre the
  // dragged icon will occupy inside a main-bar gap, or the group icon it joins.
  // Returns null for drops whose destination has no open gap to aim at.
  function predictDropSettle(sourceSlot, drop) {
    var target = drop.slot
    if (drop.into && target) return { item: target.presentationItem, local: null, fade: true }
    // A drawer's gaps glide and commit the same way (ManagedDrawer.landingPoint).
    var host = target ? target.drawerHost : null
    var drawerTarget = host && host.hostDrawer ? host.hostDrawer : !target && drop.drawer ? drop.drawer : null
    if (drawerTarget && drawerTarget.opened) {
      var p = drawerTarget.landingPoint(sourceSlot, host || null)
      return { item: p.item, local: p.local, fade: false }
    }
    if (!target || target.drawerHost || target.centerAnchorSlot) return null
    var start = drop.after === true ? target.cellExtent : 0
    var centre = start + sourceSlot.inkShift + (root.vertical ? sourceSlot.naturalHeight : sourceSlot.naturalWidth) / 2
    var local = root.vertical
      ? { x: target.width / 2, y: centre }
      : { x: centre, y: target.height / 2 }
    return { item: target, local: local, fade: false }
  }

  // The open gap and the slot that takes its place are the same length at the
  // same spot, so the commit swaps them in one frame. Easing the gap out while
  // the slot eased in slid the icon when the gap trailed the icon before it.
  property bool dragHandover: false
  function commitPendingDrop() {
    var pending = barDragPendingDrop
    if (!pending) return false
    barDragPendingDrop = null
    dragHandover = true
    try {
      barDragSource = null
      barDragDrop = null
      return dropBarModuleAtTarget(pending.slot, pending.drop)
    } catch (e) {
      console.warn("powerbar: a drop failed and the widget stayed where it was: " + e)
      return false
    } finally {
      Qt.callLater(function() { root.dragHandover = false })
    }
  }

  function finishDragSettleAnimation() {
    if (!root.barDragPendingDrop || root.barDragSettleFade) {
      root.clearBarDrag()
      return
    }
    // Freeze the image where it landed; the gap it tracked is rebuilt by the commit.
    var landed = root.dragSettleFrame(1)
    root.barDragSettleFromX = landed.x
    root.barDragSettleFromY = landed.y
    root.barDragSettleItem = null
    root.barDragSettleLocal = null
    root.barDragSettleProgress = 0
    root.commitPendingDrop()
    var epoch = root.barDragSettleEpoch
    Qt.callLater(function() { if (root.barDragSettleEpoch === epoch) root.resolveDragSettle(true) })
  }

  // correction: the image already sits on its predicted spot, so only nudge it
  // onto the committed slot, or hand off at once when it is already there.
  function resolveDragSettle(correction) {
    if (!root.barDragSettling) return
    var window = root.barDragSettleWindow
    var slots = (window && window.moduleItems || []).filter(function(candidate) {
      return candidate && candidate.visible && root.sameWindow(root.slotWindow(candidate), window)
    })
    var owner = root.groupFor(root.barDragSettleKey)
    var choice = DragModel.settleTarget(slots.map(function(candidate) {
      return { key: candidate.instanceKey, drawer: !!candidate.drawerHost,
        shown: !candidate.drawerHost && candidate.mainVisible }
    }), root.barDragSettleKey, owner ? GroupsModel.groupKey(owner.id) : "")
    var target = slots[choice.index] || null
    // Into a menu row that shows the widget, the image lands on the widget.
    var row = target && target.drawerHost
    root.barDragSettleItem = !target ? null : row && !(row.labelled && row.showNative) ? row : target.presentationItem
    root.barDragSettleLocal = null
    root.barDragSettleFade = choice.fade
    if (correction) {
      var end = root.dragSettleFrame(1)
      if (choice.fade || Math.abs(end.x - root.barDragSettleFromX) + Math.abs(end.y - root.barDragSettleFromY) < 2) {
        root.clearBarDrag()
        return
      }
      root.barDragSettleDuration = root.dragSettleCorrectionDuration
    }
    dragSettleAnimation.restart()
  }

  // Evaluated every animation frame, so the image follows a slot that is still
  // sliding into place (a cancelled source regaining its width, for example).
  function dragSettleFrame(progress) {
    var from = { x: root.barDragSettleFromX, y: root.barDragSettleFromY }
    var to = null
    var item = root.barDragSettleItem
    if (item) {
      try {
        var window = root.targetWindow(item) || root.barDragSettleWindow
        var local = root.barDragSettleLocal
        if (local) {
          var centre = root.windowScreenPoint(item.mapToItem(null, local.x, local.y), window)
          return DragModel.settleFrame(from, { x: centre.x - root.barDragImageWidth / 2,
            y: centre.y - root.barDragImageHeight / 2 }, progress, root.barDragSettleFade)
        }
        var topLeft = root.windowScreenPoint(item.mapToItem(null, 0, 0), window)
        var bottomRight = root.windowScreenPoint(item.mapToItem(null, item.width, item.height), window)
        to = { x: (topLeft.x + bottomRight.x - root.barDragImageWidth) / 2,
          y: (topLeft.y + bottomRight.y - root.barDragImageHeight) / 2 }
      } catch (e) {
        to = null
      }
    }
    return DragModel.settleFrame(from, to, progress, root.barDragSettleFade)
  }

  function slotSettleHidden(slot) {
    return root.barDragSettling && !root.barDragSource && slot.instanceKey === root.barDragSettleKey
      && root.sameWindow(root.targetWindow(slot), root.barDragSettleWindow)
  }

  property var popupPlacements: []

  function placeWidgetPopups(owner) {
    // KeyboardPanel measures its distance from the whole layer surface.
    // Our layer includes transparent drawer/shadow space, so compensate its
    // gap to open at the bar's edge, as Omarchy's bar does. A panel from a
    // drawer member opens there too: the drawer steps aside for it
    // (ManagedDrawer.steppedAside). PopupCard uses item anchors and must keep
    // its existing positioning.
    var seen = []
    function visit(item) {
      if (!item || seen.indexOf(item) !== -1) return
      seen.push(item)
      if ("cardOrigin" in item && "barH" in item && "anchorWindow" in item && "gap" in item) {
        var window = item.anchorWindow
        if (window && "managedDrawer" in window) {
          var records = root.popupPlacements.filter(function(record) { return !!record.panel })
          if (!records.some(function(record) { return record.panel === item })) {
            var record = { panel: item, gapOffset: item.gap - Style.gapsOut }
            records.push(record)
            root.popupPlacements = records
            item.gap = Qt.binding(function() {
              var host = item.anchorWindow
              if (!host) return Style.gapsOut + record.gapOffset
              return Style.gapsOut + record.gapOffset + root.barExtent - (root.vertical ? host.width : host.height)
            })
          }
        }
        return
      }
      if ("children" in item) for (var i = 0; i < item.children.length; i++) visit(item.children[i])
      if ("resources" in item) for (var j = 0; j < item.resources.length; j++) visit(item.resources[j])
    }
    visit(owner)
  }

  function requestPopout(owner) {
    placeWidgetPopups(owner)
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  readonly property var surfaceEffects: AppearanceModel.effects(appearanceConfig, Color.bar.background.a)
  // Drawers always lie over windows, and so does a bar that autohides; those
  // surfaces keep a readable minimum opacity (AppearanceModel.overlayOpacity).
  readonly property color overlaySurfaceColor: Qt.alpha(background, AppearanceModel.overlayOpacity(surfaceEffects))
  readonly property color mainSurfaceColor: surfaceColorFor(surfaceEffects)
  function surfaceColorFor(effects) {
    return Qt.alpha(background, AppearanceModel.barOpacity(effects, autoHide, transparent))
  }

  readonly property string barStyle: barOptions.style
  readonly property bool islands: barStyle === "islands"
  readonly property bool floating: barStyle === "floating"
  readonly property bool flat: barStyle === "flat"
  // Floating bars and islands keep this distance from the screen edges.
  readonly property real edgeGap: Style.space(4)
  // Counts highlight lightings, so overlapping highlights know which is newer.
  property real highlightClock: 0
  // How long a narrower value keeps its cell's width.
  readonly property int widthHoldMs: 8000
  readonly property bool autoHide: barOptions.autoHide
  // Whether widget activity slides an autohidden bar out (on by default).
  readonly property bool autoHideActivity: barOptions.autoHideActivity
  // The large bar is as thick as Preferences' Layout page draws it: the theme's
  // bar size plus a lip above and below each widget. Widgets keep their own
  // size and gain room around them; the islands' ends open up to match.
  readonly property bool largeBar: barOptions.largeBar
  readonly property real largeBarLip: Style.space(6)
  function barSizeFor(vertical) {
    return (vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal) + (largeBar ? largeBarLip * 2 : 0)
  }
  // One cell, one inset (docs/behavior/layout-zones.md): every item gets a cell along the
  // bar, square for glyphs, and the cell is its highlight. Equal slots puts
  // cells one gutter apart; Equal gaps puts the same air between glyphs.
  readonly property string spacingMode: barOptions.spacingMode
  readonly property var cellTokens: CellModel.tokens({ bar: barSize, spacing: widgetSpacing, mode: spacingMode })
  readonly property real highlightRadius: CellModel.radius(cellTokens, islandRounding)
  // Compounds (several click targets in one widget) show a faint track over
  // the whole cell and a thumb over the hovered target.
  readonly property color highlightTrackColor: Qt.rgba(barForeground.r, barForeground.g, barForeground.b, 0.06)
  // Islands keep the bar gap from the screen's sides, as from its edge; a
  // flat bar runs edge to edge, and its zones keep the end glyphs where
  // Omarchy's bar has them (CellModel.flatEdge).
  readonly property real islandScreenInset: flat ? CellModel.flatEdge(cellTokens, Style.space(8), Style.bar.iconSlot) : edgeGap
  // Preferences' layout preview pads its zones like an island end.
  readonly property real islandPadding: cellTokens.inset
  // Padding past the first or last slot so the end cell sits one inset from
  // the island's end and its curve runs parallel to the island's.
  function cellEndPad(spill) { return CellModel.endPad(cellTokens, spill) }
  // The preferences button's glyph: nine dots, three by three.
  readonly property real preferencesGlyphSize: Style.space(2) * 3 + Style.spaceReal(2.5) * 2
  // Zones keep one icon cell plus the spacing between them (docs/behavior/layout-zones.md).
  readonly property real zoneGap: cellTokens.cell + widgetSpacing
  // Folded widget counts per screen, for Preferences' note: { screen: { left, center, right } }.
  property var zoneFitReports: ({})
  function reportZoneFit(screenName, folded) {
    var next = Object.assign({}, zoneFitReports)
    var counts = folded ? { left: folded.left.length, center: folded.center.length, right: folded.right.length } : null
    if (counts && counts.left + counts.center + counts.right > 0) next[screenName] = counts
    else delete next[screenName]
    if (!RenderModel.equal(next, zoneFitReports)) zoneFitReports = next
  }
  // Island ends are the same during a drag: the outlined placeholder shows
  // where a widget lands, so islands no longer grow a landing lip.
  function islandEnd(zone, spill) { return cellEndPad(spill) }
  // The kit button that paints a widget's glyph, if any (depth-limited): an
  // icon button, or a text button showing a glyph (placeholders, group icons).
  // Only when that button is the widget's whole content: the search follows a
  // single painted child at each level (backgrounds aside), so compounds such
  // as Workspaces keep their measured span.
  function findKitGlyph(item, depth) {
    if (!item || depth > 3 || !item.visible) return null
    if ("glyphPaintedWidth" in item && "glyphFontSize" in item) return item
    if ("labelWidth" in item && "fontSize" in item && "text" in item && String(item.text) !== "") return item
    var kids = HighlightModel.withoutBadges(HighlightModel.paintedChildren(item)
      .filter(function(c) { return !HighlightModel.isBackground(c, item, false) }))
    return kids.length === 1 ? findKitGlyph(kids[0], depth + 1) : null
  }
  // The Text item inside a kit button that paints `text`.
  function findGlyphText(item, text, depth) {
    if (!item || depth > 4) return null
    if ("font" in item && "baselineOffset" in item && "contentWidth" in item && String(item.text) === text && item.visible) return item
    var kids = item.children || []
    for (var n = 0; n < kids.length; n++) {
      var found = findGlyphText(kids[n], text, depth + 1)
      if (found) return found
    }
    return null
  }
  // The spill of the first (or last) visible slot in a Row or Column.
  function edgeSpill(container, last) {
    var kids = container ? container.children : []
    for (var n = 0; n < kids.length; n++) {
      var c = kids[last ? kids.length - 1 - n : n]
      if (c && c.cellSpill !== undefined && c.visible && !c.fitYielded && (vertical ? c.height : c.width) > 0) return c.cellSpill
    }
    return 0
  }
  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: barSizeFor(vertical)
  // Widgets are drawn at this size whether or not the bar is large, so lists
  // of widget icons outside the bar keep to it.
  // Item highlight shared by the bar, its drawers and Preferences' layout
  // tiles: a fill in the bar's own foreground, nested inside island corners.
  readonly property color highlightHoverColor: Style.hoverFillFor(barForeground, Color.accent)
  readonly property color highlightSelectedColor: Style.selectedFillFor(barForeground, Color.accent)
  readonly property real highlightRounding: Math.max(Style.space(4), islandRounding - Style.space(3))
  // The highlight for a slot: its cell, centred on the slot along the bar, at
  // the cell thickness across it, in `host` coordinates.
  function cellHighlight(item, host, strip, cell) {
    var k = cellTokens
    var origin = item.mapToItem(host, 0, 0)
    var along = vertical ? item.height : item.width
    var s = strip.mapToItem(host, 0, 0)
    var start = (vertical ? origin.y : origin.x) + (along - cell) / 2
    var cross = vertical ? s.x + (strip.width - k.thickness) / 2 : s.y + (strip.height - k.thickness) / 2
    return vertical ? { x: cross, y: start, width: k.thickness, height: cell, radius: highlightRadius }
      : { x: start, y: cross, width: cell, height: k.thickness, radius: highlightRadius }
  }
  function highlightInset(extent) { return Math.min(Style.space(3), Math.max(0, (extent - Style.space(16)) / 2)) }
  readonly property int barExtent: Math.ceil(barSize + (flat ? 0 : edgeGap * 2))
  readonly property real widgetSpacing: Style.space(AppearanceModel.clampTo(AppearanceModel.ranges.spacing, barConfig.powerbarSpacing))
  readonly property var themeIslandBorder: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
  readonly property real islandRounding: roundingFor(appearanceConfig)
  // Every config delivery builds the spec afresh; an equal one keeps the last
  // object, so the islands, drawers, tooltip and strip that read it (through
  // Border.*) are not re-resolved for a change elsewhere in the config.
  readonly property var borderKept: ({})
  readonly property var islandBorder: {
    var next = borderFor(appearanceConfig)
    if (RenderModel.equal(borderKept.last, next)) return borderKept.last
    borderKept.last = next
    return next
  }
  // Surface geometry for a bar config.
  // Rounding stops at a full pill: past half the bar's thickness corners look
  // the same, and nested highlights would round past their cells.
  function roundingFor(config) {
    var v = config && config.powerbarIslandRounding
    var r = typeof v === "number" ? Style.space(AppearanceModel.clampTo(AppearanceModel.ranges.rounding, v)) : Style.cornerRadius
    return Math.min(r, barSize / 2)
  }
  function borderFor(config) {
    var c = config || {}
    if (c.powerbarIslandBorders === false) return Border.none()
    var spec = JSON.parse(JSON.stringify(themeIslandBorder))
    var custom = typeof c.powerbarIslandBorderWidth === "number"
    for (var side in spec.widths) {
      spec.widths[side] = (custom ? Style.spaceReal(AppearanceModel.clampTo(AppearanceModel.ranges.borderWidth, c.powerbarIslandBorderWidth)) : spec.widths[side])
    }
    return spec
  }
  // Rounding that reads as a full pill, in stored units (the slider's top).
  readonly property int roundingMax: AppearanceModel.roundingMax(barSize, Style.spacing.scale)

  function normalizePosition(value) {
    return BarModel.normalizePosition(value)
  }

  // Apply tray-pinning on top of the shared layout normalization so the
  // bar host and scriptable config helpers can't drift on entry shape.
  function normalizeLayout(layout) {
    var normalized = Util.normalizeLayout(Util.isPlainObject(layout) ? layout : fallbackBarConfig.layout)
    for (var section in normalized) {
      normalized[section] = normalized[section].filter(function(entry) {
        return PreferencesModel.mode(entry) !== "hidden"
      })
    }
    return GroupsModel.render({
      left:   pinTrayToInner(normalized.left,   "left"),
      center: pinTrayToInner(normalized.center, "center"),
      right:  pinTrayToInner(normalized.right,  "right")
    }, GroupsModel.groups(barConfig))
  }

  // The tray drawer reveals inward (away from the bar edge). Place it at the
  // section's inner edge: start of the right section, end of the left/center
  // sections. The drawer's reserved space then sits next to the bar center,
  // not stranded mid-section.
  function pinTrayToInner(entries, section) {
    return BarModel.pinTrayToInner(entries, section)
  }

  function applyBarConfig() {
    var config = Util.isPlainObject(barConfig) ? barConfig : fallbackBarConfig

    updateGroups(config)
    position = normalizePosition(config.position)
    setRequestedTransparency(config.transparent === true)
    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")

    var next = normalizeLayout(config.layout)
    if (RenderModel.equal(layoutConfig, next)) return
    var structural = BarModel.inlineSettingsDelta(layoutConfig, next) === null
    if (structural) {
      if (!keepDrawerThroughEdit) closeManagedDrawer()
      barConfigSerial++
    }
    // A retained widget can update presentation synchronously during injection.
    // Treat structural-edit initialization as the baseline, as rebuilt owners
    // did, while ordinary settings and subsequent events retain their policy.
    reconcilingStructure = structural
    try { layoutConfig = next } finally { reconcilingStructure = false }
  }

  onBarConfigChanged: {
    if (AppearanceModel.legacyPresent(barConfig)) Qt.callLater(healAppearance)
    // Only when the last list says a theme went: then read it again first.
    if (installedThemes.length && AppearanceModel.hasStaleThemes(barConfig, installedThemes.concat(themeName ? [themeName] : [])))
      Qt.callLater(refreshThemes)
    // A config from the host while edits wait to be written: the store shows
    // the edits on top of it rather than the host's config without them.
    if (configStore.delivered(barConfig)) return
    applyBarConfig()
    Qt.callLater(ensureInstanceIds)
    Qt.callLater(pruneGroupMembers)
  }
  // Widgets uninstalled since they were grouped have already left every group
  // as read (GroupsModel.groups); their keys leave shell.json too, in one
  // write, so nobody has to remove them by hand.
  function pruneGroupMembers() {
    if (!canWriteConfig() || configStore.pending || !Util.isPlainObject(barConfig)) return
    if (!GroupsModel.danglingMembers(barConfig)) return
    writeConfig(function(config) {
      if (config.bar && GroupsModel.danglingMembers(config.bar)) config.bar.powerbarGroups = GroupsModel.groups(config.bar)
    })
  }

  function layoutEntries(region) {
    var serial = barConfigSerial
    var entries = layoutConfig ? layoutConfig[region] : null
    return Array.isArray(entries) ? entries : []
  }

  // Tab order for the panels in one bar region. Scoped to a single bar surface
  // so tabbing walks the bar the open panel belongs to instead of hopping the
  // panel to another monitor's copy of the same widget.
  function panelNavigationSlots(region, window) {
    var entries = layoutEntries(region)
    var slots = []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      // A widget on the bar twice is told apart by its instance.
      var key = entries[i] && typeof entries[i] === "object" ? entries[i].powerbarInstance : ""
      for (var j = 0; j < moduleSlots.length; j++) {
        var slot = moduleSlots[j]
        if (!slot || slot.region !== region || (key ? slot.instanceKey !== key : slot.moduleName !== id)) continue
        if (window && !sameWindow(slotWindow(slot), window)) continue
        var item = slot.activeItem
        if (!item || item.visible !== true || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
        if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
        slots.push(slot)
        break
      }
    }
    return slots
  }

  // The Nth panel in a bar region, counted the way the bar reads: layout order,
  // and only the panels actually on screen. A widget with no panel (the tray)
  // and one that is hiding itself are passed over, so the number lands on the
  // Nth panel icon the user can see rather than the Nth layout entry.
  // One-based, because it exists for hotkeys; anything else lands on no slot.
  //
  // Counting any bar surface is enough: every monitor lays its bar out from the
  // one layout, and summoning the id routes through pickPanelSlot, which opens
  // the focused monitor's copy whichever surface was counted.
  // The host turns the answer into a summon by id; panelPick tells that
  // summon which copy was meant when the widget is on the bar twice.
  property var panelPick: null
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    if (!slot) return ""
    panelPick = { id: String(slot.moduleName || ""), instance: slot.instanceKey, at: Date.now() }
    return String(slot.moduleName || "")
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotWindow(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = -1
    for (var j = 0; j < slots.length; j++) {
      if (slots[j] === currentSlot) {
        currentIndex = j
        break
      }
    }
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live instance of a widget id. A bar surface is built per monitor, so
  // a widget that appears once in the layout is still live once per screen.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      items.push(slot.activeItem)
    }
    return items
  }

  // The bar window on the monitor Hyprland has focused.
  function focusedBarWindow() {
    var windows = [], names = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var w = targetWindow(moduleSlots[i])
      if (!w || !w.screen || windows.indexOf(w) >= 0) continue
      windows.push(w); names.push(String(w.screen.name || ""))
    }
    var at = KeysModel.startScreen(names, focusedScreenName())
    return at >= 0 ? windows[at] : null
  }
  // What a slot is called: a group's label, a widget's name.
  function slotName(slot) {
    if (!slot) return ""
    if (slot.groupHeader) return slot.groupConfig ? slot.groupConfig.label : ""
    return slot.displayName
  }
  // A widget's or group's shortcut as keycaps text ("Super Ctrl A"), or "".
  function shortcutLabel(target) { return shortcutCaps(target).join(" ") }
  // The same as a list of keycaps (["Super", "Ctrl", "A"]), or [].
  function shortcutCaps(target) {
    var store = preferencesPane.shortcuts
    if (!store || !store.ready) return []
    var info = store.info(target)
    var keys = info && info.keys ? info.keys : info && info.positional ? info.positional : ""
    return keys ? ShortcutModel.caps(keys) : []
  }
  function refreshShortcuts() { if (preferencesPane.shortcuts) preferencesPane.shortcuts.refresh() }
  readonly property var shortcutStore: preferencesPane.shortcuts
  // The keyboard cursor's name card: the bar's tooltip, shown at once.
  function showCard(target, text) {
    clearTooltip()
    if (!target || !text) return
    tooltipTarget = target
    tooltipText = text
    tooltipShown = true
  }
  function hideCard() { clearTooltip() }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // The output Hyprland has focused, which is where a keyboard-summoned panel
  // belongs. Empty until Hyprland reports one, which leaves panel routing on
  // its per-monitor fallback rather than guessing at an output.
  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  // Resolve the live bar-widget instance for a plugin id (e.g. "omarchy.bluetooth").
  // Only widgets that expose popup open/close methods count; plain indicators
  // (clock, workspaces, tray) return null. Used by shell.summon/toggle so
  // panel hotkeys route through the bar instead of a per-target IPC handler
  // that only reaches whichever per-monitor instance claimed the target.
  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      if (slot.moduleName !== id) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push({ slot: slot, instance: slot.instanceKey, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // Kept for a second, not used up: the host asks whether it is open, then
    // summons or hides it, and both must mean the same copy.
    var pick = panelPick && panelPick.id === id && Date.now() - panelPick.at < 1000 ? panelPick.instance : ""
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, focusedScreenName(), pick)
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  function entrySettings(entry) {
    return BarModel.entrySettings(entry)
  }

  function entryId(entry) {
    return BarModel.entryId(entry)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }

  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  Component.onCompleted: applyBarConfig()

  // Revealing the indicators widens the center island, which can slide a
  // neighbour under a stationary pointer or move the hovered icon away from it.
  // Collapsing on that un-hover would shift everything back and re-open the
  // peek, so once opened the reveal is held until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerHoverCount = Math.max(0, centerHoverCount + (hovered ? 1 : -1))
    if (hovered) {
      centerSectionRevealTimer.stop()
      // After the event: entering the centre on its dots asks for a side first.
      Qt.callLater(root.openCenterReveal)
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function openCenterReveal() {
    if (centerSectionHovered && centerRevealBlocks === 0) centerSectionRevealHeld = true
  }

  // The pointer on a zone's yield marker: end the hover moments it gave way to.
  function releaseYield(window, zone) {
    if (centerSectionRevealHeld && zone !== "center" && !centerSectionHovered) centerSectionRevealHeld = false
    if (window && window.inlineZone && window.inlineZoneName !== zone) window.inlineAsk("")
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    // Collapse only; opening is the center island's own hover, so a timer left
    // pending by a pointer that dipped off the bar cannot reveal anything.
    onTriggered: if (!root.centerSectionHovered && !root.barHovered) root.centerSectionRevealHeld = false
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount === 0) centerSectionRevealTimer.restart()
  }

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function toggleTransparency() {
    var nextTransparent = !(root.requestedTransparent === true)
    if (root.canWriteConfig()) {
      root.writeConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.transparent = nextTransparent
      })
    } else {
      root.setRequestedTransparency(nextTransparent)
    }
  }

  function dropBarModule(source, toRegion, beforeKey, visibility) {
    if (!source || !source.region || !source.instanceKey || !toRegion) return false
    if (!root.canWriteConfig()) return false

    // Plain values: the edit runs again later, after the slot has moved.
    var region = source.region, key = source.instanceKey, grouped = !!source.memberGroup
    var changed = false
    root.writeConfig(function(config) {
      var layout = config.bar && config.bar.layout
      var from = layout && layout[region], to = layout && layout[toRegion]
      // A group icon is not a layout entry: it sits before its anchor entry, so
      // "before the group" means before that anchor (or the zone's end).
      var before = beforeKey
      if (before && GroupsModel.isGroupKey(before)) {
        var group = GroupsModel.groups(config.bar).find(function(g) { return GroupsModel.groupKey(g.id) === before })
        before = group && Array.isArray(to) && to.some(function(entry) { return entry && entry.powerbarInstance === group.before }) ? group.before : ""
      }
      changed = false
      if (!Array.isArray(from) || !Array.isArray(to) ||
          !from.some(function(entry) { return entry && entry.powerbarInstance === key }) ||
          (before && !to.some(function(entry) { return entry && entry.powerbarInstance === before }))) return
      // A group anchored on the moving widget stays where it is.
      var next = GroupsModel.nextAnchor(config, region, key)
      changed = BarModel.moveInstanceInConfig(config, region, key, toRegion, before, visibility)
      if (changed) GroupsModel.reanchor(config, region, key, next)
      if (grouped) changed = GroupsModel.assign(config, key, "") || changed
    })
    return changed
  }

  // After a group icon: the widget takes the group's place before its anchor,
  // and the group re-anchors on the widget so it stays in front of it.
  function dropAfterGroup(source, groupId, visibility) {
    if (!source || !root.canWriteConfig()) return false
    // Plain values: the edit runs again later, after the slot has moved.
    var region = source.region, key = source.instanceKey, grouped = !!source.memberGroup
    var changed = false
    root.writeConfig(function(config) {
      changed = false
      var group = GroupsModel.groups(config.bar).find(function(g) { return g.id === groupId })
      var to = group && config.bar.layout && config.bar.layout[group.section]
      if (!group || !Array.isArray(to)) return
      var anchor = to.some(function(entry) { return entry && entry.powerbarInstance === group.before }) ? group.before : ""
      var next = GroupsModel.nextAnchor(config, region, key)
      if (!BarModel.moveInstanceInConfig(config, region, key, group.section, anchor, visibility || "shown")
          && !(region === group.section)) return
      GroupsModel.reanchor(config, region, key, next)
      if (grouped) GroupsModel.assign(config, key, "")
      changed = GroupsModel.edit(config, groupId, { before: key }) || true
    })
    return changed
  }

  function barZoneAt(point, window) {
    var coordinate = root.vertical ? point.y : point.x
    var length = root.vertical ? window.height : window.width
    return ["left", "center", "right"][Math.min(2, Math.max(0, Math.floor(coordinate * 3 / length)))]
  }

  // What a drag at scenePoint drops on. The measuring happens here (the
  // window, the open drawer, every slot's rect); the decisions are
  // DragModel.dropSurface and DragModel.resolveDrop, tested on their own.
  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    var zone = "", inStrip = false, inDrawer = false, drawer = null, handle = null
    if (sourceWindow && sourceWindow.contentItem) {
      var content = sourceWindow.contentItem
      var barPoint = content.mapFromItem(null, scenePoint.x, scenePoint.y)
      drawer = sourceWindow.managedDrawer
      var surface = DragModel.dropSurface(barPoint, { width: content.width, height: content.height },
        { width: sourceWindow.width, height: sourceWindow.height }, root.position, root.barExtent, root.barSize,
        drawer ? { open: drawer.opened, x: drawer.x, y: drawer.y, width: drawer.width, height: drawer.height } : null,
        !!(sourceSlot && sourceSlot.groupHeader && drawer && drawer.groupId))
      if (!surface) return null
      inStrip = surface.inStrip
      inDrawer = surface.inDrawer
      if (inStrip) zone = root.barZoneAt(barPoint, sourceWindow)
      handle = inStrip && typeof sourceWindow.foldHandleAt === "function" ? sourceWindow.foldHandleAt(barPoint) : null
      // A gap opening just before the dots pushes them along, and dropping on
      // them closes it again: the dots keep the drop while the pointer stays
      // where they were when they took it, so the two never trade places.
      var held = root.barDragHandleHeld
      if (inStrip && !handle && held && held.handle.shown && held.handle.visible && !held.handle.fitYielded
          && barPoint.x >= held.x1 && barPoint.x <= held.x2 && barPoint.y >= held.y1 && barPoint.y <= held.y2) handle = held.handle
    }

    // Landing follows the dragged widget's painted centre, not the pointer, so
    // a wide widget grabbed at one end lands where it looks.
    var probe = { x: scenePoint.x, y: scenePoint.y }
    // The ink is measured along the bar, so it only applies to a surface along
    // the bar: in a menu below a horizontal bar it pushed the landing a row on.
    var alongColumn = inDrawer ? drawer.stripVertical : root.vertical
    if (sourceSlot && sourceSlot.ink && sourceSlot.ink.length > 0 && alongColumn === root.vertical) {
      var inkCentre = (sourceSlot.ink.start + sourceSlot.ink.length / 2)
      if (alongColumn) probe.y = scenePoint.y - root.barDragOffsetY + inkCentre
      else probe.x = scenePoint.x - root.barDragOffsetX + inkCentre
    }
    var candidates = []
    var localSlots = sourceWindow && sourceWindow.moduleItems || []
    for (var i = 0; i < localSlots.length; i++) {
      var slot = localSlots[i]
      if (!slot || slot === sourceSlot || !slot.visible) continue
      // The drawer and main bar share an axis but are separate drop surfaces.
      // Never let a nearby drawer edge win over a group icon under the pointer.
      if (sourceWindow && (inStrip ? !!slot.drawerHost : !slot.drawerHost)) continue
      var item = slot.drawerHost || slot
      if (item.width <= 0 || item.height <= 0 || (!slot.mainVisible && !slot.drawerHost)) continue
      // Widgets out of view (yielded to an expansion, or in a zone it hid)
      // keep their place but take no drops: the pointer is over what is seen.
      if (!slot.drawerHost && (slot.fitYielded || (slot.homeWindow && slot.homeWindow.zoneHidden(slot.region)))) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var slotPoint = { x: slot.x, y: slot.y }
      try {
        slotPoint = item.mapToItem(null, 0, 0)
      } catch (e) {
      }

      candidates.push({
        slot: slot,
        region: slot.region,
        groupHeader: !!slot.groupHeader,
        inDrawer: !!slot.drawerHost,
        x: slotPoint.x,
        y: slotPoint.y,
        width: item.width,
        height: item.height,
        // A bar slot's landing reference is its cell, past any open drag gap.
        contentX: (slot.drawerHost ? slot.drawerHost.contentOffsetX : root.vertical ? 0 : slot.animatedInsetX),
        contentY: (slot.drawerHost ? slot.drawerHost.contentOffsetY : root.vertical ? slot.animatedInsetY : 0),
        contentWidth: (slot.drawerHost ? slot.drawerHost.baseWidth : root.vertical ? slot.naturalWidth : slot.cellExtent),
        contentHeight: (slot.drawerHost ? slot.drawerHost.baseHeight : root.vertical ? slot.cellExtent : slot.naturalHeight)
      })
    }

    var shown = root.barDragDrop
    var drop = DragModel.resolveDrop({ candidates: candidates, probe: probe, point: scenePoint, sourceRect: root.barDragSourceRect,
      handle: !!handle, sourceInDrawer: !!(sourceSlot && sourceSlot.drawerHost), sourceGroupHeader: !!(sourceSlot && sourceSlot.groupHeader),
      alongColumn: alongColumn, previous: shown && shown.slot ? { slot: shown.slot, after: shown.after } : null,
      deadZone: root.dragDeadZone, inDrawer: inDrawer, zone: zone })
    // The dots: the widget joins the zone's on-demand widgets on their side.
    if (drop.handle) return { managedZone: handle.zone, handle: true, handleToken: handle.inlineToken, managedBefore: root.handleDropBefore(handle, sourceSlot) }
    if (drop.drawer) return { drawer: drawer }
    return drop
  }

  // Dots at a zone's start take the widget at the start of the zone's list.
  function handleDropBefore(handle, sourceSlot) {
    if (handle.side !== "start") return ""
    var entries = layoutEntries(handle.zone)
    for (var i = 0; i < entries.length; i++) {
      var key = entries[i].powerbarInstance
      if (key && (!sourceSlot || key !== sourceSlot.instanceKey)) return key
    }
    return ""
  }

  function visibleModuleSlot(region, key, sourceSlot, inDrawer) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || slot.region !== region || slot.instanceKey !== key ||
          slot.groupHeader || !!slot.drawerHost !== inDrawer || !slot.visible) continue
      var item = slot.drawerHost || slot
      if (item.width <= 0 || item.height <= 0 || (!slot.mainVisible && !slot.drawerHost)) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue
      return slot
    }

    return null
  }

  function nextVisibleModuleKey(region, afterKey, sourceSlot, inDrawer) {
    var entries = layoutEntries(region)
    var found = false
    for (var i = 0; i < entries.length; i++) {
      var key = entries[i].powerbarInstance
      if (!found) {
        found = key === afterKey
        continue
      }

      if (visibleModuleSlot(region, key, sourceSlot, inDrawer)) return key
    }

    return ""
  }

  // Where a drop beside a widget on the bar lands in the saved layout. The bar
  // draws a zone's on-demand widgets as one run at its dots, so the drop is
  // read in drawn order: the widget lands at the gap (ZoneOrderModel).
  // The gap beside a bar widget, in the zone's drawn order (without the source).
  function barGap(targetSlot, after, sourceSlot) {
    var window = targetSlot.homeWindow
    if (!window) return null
    var models = window.widgetModels, region = targetSlot.region
    var lists = region !== "center" ? [region] : models.anchor.count ? ["before", "anchor", "after"] : ["center"]
    var sequence = [], anchorKey = ""
    for (var name of lists) {
      for (var i = 0; i < models[name].count; i++) {
        var s = models[name].get(i)
        if (!s) continue
        if (name === "anchor") anchorKey = s.instanceKey
        sequence.push({ key: s.instanceKey, list: name, managed: s.managed, group: s.groupHeader,
          expanded: s.inlineShown && s.mainVisible, hidden: !s.mainVisible })
      }
    }
    var rest = sequence.filter(function(item) { return item.key !== sourceSlot.instanceKey })
    var at = rest.findIndex(function(item) { return item.key === targetSlot.instanceKey })
    if (at < 0) return null
    return { sequence: sequence, rest: rest, gap: at + (after ? 1 : 0), anchorKey: anchorKey, region: region }
  }
  // A gap inside an expansion's run lands On demand; where the shown widgets
  // meet the expansion it joins the run of the widget the pointer is on
  // (ZoneOrderModel.landsOnDemand).
  function barGapOnDemand(targetSlot, after, sourceSlot) {
    var g = barGap(targetSlot, after, sourceSlot)
    return !!g && ZoneOrderModel.landsOnDemand(g.rest, g.gap, targetSlot.instanceKey)
  }
  function barDropBefore(targetSlot, after, sourceSlot, managed) {
    var g = barGap(targetSlot, after, sourceSlot)
    if (!g) return ""
    var layout = layoutEntries(g.region).filter(function(entry) { return entry && !entry.powerbarGroupId && entry.powerbarInstance })
      .map(function(entry) { return entry.powerbarInstance })
    return ZoneOrderModel.dropBefore({ sequence: g.sequence, gap: g.gap, managed: managed,
      layout: layout, source: sourceSlot.instanceKey, anchorKey: g.anchorKey })
  }

  function dropBarModuleAtTarget(sourceSlot, drop) {
    if (!sourceSlot || !drop) return false
    if (drop.source) return false
    // Into an open drawer (a zone's or a group's): it stays open under the
    // pointer, as the bar does, and leaves on the exit grace.
    var intoDrawer = !!drop.drawer || (!!drop.slot && !!drop.slot.drawerHost)
    if (intoDrawer && root.managedOwner) {
      root.managedOwner.entered = true
      root.keepDrawerThroughEdit = true
      try { return root.dropAt(sourceSlot, drop) } finally { root.keepDrawerThroughEdit = false }
    }
    return root.dropAt(sourceSlot, drop)
  }
  // Where the dragged widget or group icon lands, by the drop's target.
  function dropAt(sourceSlot, drop) {
    var targetSlot = drop.slot, afterTarget = drop.after
    if (sourceSlot.groupHeader) {
      var id = sourceSlot.entry.powerbarGroupId
      if (drop.managedZone) return root.editGroups(function(config) {
        GroupsModel.moveHeader(config, id, drop.managedZone, drop.managedBefore || "", "", false, "managed")
      })
      if (drop.drawer) {
        if (drop.drawer.groupId) return false
        var drawerZone = drop.drawer.zone
        return root.editGroups(function(config) {
          GroupsModel.moveHeader(config, id, drawerZone, "", "", false, "managed")
        })
      }
      if (targetSlot && targetSlot.drawerHost && targetSlot.memberGroup) return false
      var headerMode = targetSlot && (targetSlot.drawerHost || root.barGapOnDemand(targetSlot, afterTarget, sourceSlot)) ? "managed" : "shown"
      var before = !targetSlot ? ""
        : !targetSlot.drawerHost ? root.barDropBefore(targetSlot, afterTarget, sourceSlot, headerMode === "managed")
        : !afterTarget ? targetSlot.instanceKey : nextVisibleModuleKey(targetSlot.region, targetSlot.instanceKey, sourceSlot, true)
      var section = targetSlot ? targetSlot.region : drop.zone
      var besideGroup = targetSlot && targetSlot.groupHeader ? targetSlot.entry.powerbarGroupId : ""
      return root.editGroups(function(config) {
        GroupsModel.moveHeader(config, id, section, before, besideGroup, afterTarget, headerMode)
      })
    }
    if (drop.managedZone) return root.dropBarModule(sourceSlot, drop.managedZone, drop.managedBefore || "", "managed")
    if (drop.drawer) {
      if (drop.drawer.groupId) return root.assignGroup(sourceSlot.instanceKey, drop.drawer.groupId, "", true)
      return root.dropBarModule(sourceSlot, drop.drawer.zone, "", "managed")
    }
    if (drop.zone) return root.dropBarModule(sourceSlot, drop.zone, "", "shown")
    if (drop.into) return root.assignGroup(sourceSlot.instanceKey, targetSlot.entry.powerbarGroupId)
    // Inside an inline expansion's run the widget joins it On demand; where the
    // shown widgets meet the expansion it lands shown.
    var visibility = targetSlot.drawerHost || root.barGapOnDemand(targetSlot, afterTarget, sourceSlot) ? "managed" : "shown"
    // Right after a group icon of the same run (dropped on it, or before the
    // widget that follows it): a group is not a layout entry, so the widget
    // takes the group's place and the group re-anchors in front of it.
    if (!targetSlot.drawerHost) {
      var g = root.barGap(targetSlot, afterTarget, sourceSlot)
      var near = g ? ZoneOrderModel.neighbours(g.rest, g.gap) : null
      var prev = near ? near.prev : null
      var header = prev && prev.group ? root.moduleSlots.find(function(x) { return x && x.instanceKey === prev.key }) : null
      if (header && !!prev.managed === (visibility === "managed") && (!near.next || near.next.list === prev.list))
        return root.dropAfterGroup(sourceSlot, header.entry.powerbarGroupId, visibility)
    }
    if (targetSlot.drawerHost && targetSlot.memberGroup) {
      var group = targetSlot.memberGroup
      var index = group.items.indexOf(targetSlot.instanceKey) + (afterTarget ? 1 : 0)
      return root.assignGroup(sourceSlot.instanceKey, group.id, group.items[index] || "", true)
    }
    var beforeKey = !targetSlot.drawerHost ? root.barDropBefore(targetSlot, afterTarget, sourceSlot, visibility === "managed")
      : afterTarget ? nextVisibleModuleKey(targetSlot.region, targetSlot.instanceKey, sourceSlot, true) : targetSlot.instanceKey
    return dropBarModule(sourceSlot, targetSlot.region, beforeKey, visibility)
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  // Only the clicked widget's own targets (and targets not yet tied to a
  // widget) can take its click. A hidden widget's content keeps its size and
  // opacity inside a zero-width slot that positioners leave where it was, so a
  // scan of every target let invisible widgets steal clicks from visible ones.
  function moduleClickTargetAt(slot, localX, localY) {
    var own = slot.slotTargets
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (own.indexOf(target) < 0 && pendingTargets.indexOf(target) < 0) continue
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    if (root.managedOwner && !slot.drawerHost && !slot.groupHeader) {
      // Capture before closing: restoring managed widgets can move this slot.
      // Dispatch after the drawer has released its widgets and focus grab.
      root.closeManagedDrawer()
      Qt.callLater(function() {
        if (root.moduleTargetClickable(target)) target.triggerPress(button)
      })
    } else {
      target.triggerPress(button)
    }
    return true
  }

  function colorHex(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    function hexChannel(value) {
      var s = Math.round(Util.clamp(value, 0, 1) * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
  }

  function setRequestedTransparency(value) {
    var nextTransparent = value === true
    requestedTransparent = nextTransparent
    if (!nextTransparent) {
      foregroundAnimationEnabled = false
      useTransparentForeground = false
      transparent = false
      transparentForeground = themeForeground
      restoreForegroundAnimation()
      return
    }
    scheduleTransparentForegroundRefresh()
  }

  function restoreForegroundAnimation() {
    Qt.callLater(function() {
      Qt.callLater(function() { root.foregroundAnimationEnabled = true })
    })
  }

  function scheduleTransparentForegroundRefresh() {
    if (!requestedTransparent) {
      transparentForeground = themeForeground
      return
    }
    transparentForegroundTimer.restart()
  }

  // A change that lands while omarchy-bar-text-color runs (a theme switch
  // during a move) is answered by one more run once it is done, not dropped.
  property bool transparentAgain: false
  function refreshTransparentForeground() {
    if (!requestedTransparent) return
    if (transparentForegroundProc.running) { transparentAgain = true; return }

    transparentForegroundProc.command = [
      "omarchy-bar-text-color",
      root.position,
      String(root.barSize),
      colorHex(root.themeForeground),
      colorHex(root.themeContrastForeground)
    ]
    transparentForegroundProc.running = true
  }

  onRequestedTransparentChanged: scheduleTransparentForegroundRefresh()
  onPositionChanged: { closeManagedDrawer(); scheduleTransparentForegroundRefresh() }
  onThemeForegroundChanged: { themeNameFile.reload(); themeLookFile.reload(); scheduleTransparentForegroundRefresh() }
  onThemeContrastForegroundChanged: { themeNameFile.reload(); themeLookFile.reload(); scheduleTransparentForegroundRefresh() }

  Timer {
    id: transparentForegroundTimer
    interval: 120
    repeat: false
    onTriggered: root.refreshTransparentForeground()
  }

  Process {
    id: transparentForegroundProc
    onExited: if (root.transparentAgain) { root.transparentAgain = false; root.scheduleTransparentForegroundRefresh() }
    stdout: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return

        root.foregroundAnimationEnabled = false
        root.transparentForeground = value
        if (root.requestedTransparent) {
          root.useTransparentForeground = true
          root.transparent = true
        }
        root.restoreForegroundAnimation()
      }
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current"
    watchChanges: true
    printErrors: false
    // A theme applied again (an overlay changed) keeps its name and colours:
    // its powerbar.toml is read again here.
    onFileChanged: { root.scheduleTransparentForegroundRefresh(); themeLookFile.reload() }
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  function showTooltip(target, text) {
    clearTooltip()

    // A widget yielded, hidden or folded off the bar is still hovered by Qt
    // (it hovers disabled items); it shows no tooltip.
    var owner = resolveTargetSlot(target)
    var unseen = !!owner && !owner.drawerHost && !owner.mainVisible
    // As on Omarchy's bar, a widget's tooltip is its own text, and a widget
    // that brings none shows none. Shortcuts live in the keyboard mode's ?
    // sheet and in Preferences, not in tooltips.
    if (unseen || !targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.interval = Date.now() < tooltipWarmUntil ? 1 : 400
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // Presence of the `bar-off` flag = bar hidden. Watching the parent toggles
  // directory because FileView can't observe a file that doesn't exist yet,
  // and the flag is created/removed by `omarchy-toggle-bar`.
  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) {
      var off = String(line).trim() === "yes"
      // Autohide: Omarchy's bar toggle (Super+Shift+Space) reveals the bar
      // instead of hiding it for good, and the flag goes back off.
      if (off && !root.barOffFlag && root.autoHide) root.revealFromToggle()
      else root.barOffFlag = off
    } }
  }

  // The bar toggle on an autohidden bar works like the pointer at the edge:
  // the bar slides out and stays while the toggle's key is held, and slides
  // away the usual delay after it is let go (a tap: at once). Omarchy's own
  // bind fires once, on the press, so the key is followed by asking Hyprland
  // whether it is still down (hl.is_key_down): the toggle bind's key, or any
  // modifier when the bind can't be found. Nothing new is bound.
  property bool toggleHeld: false
  function revealFromToggle() {
    toggleHeld = true
    toggleKeyWatch.running = false
    toggleKeyWatch.running = true
    run("omarchy-toggle bar-off off")
  }
  Process {
    id: toggleKeyWatch
    command: ["bash", "-c", `
      key=$(hyprctl binds -j 2>/dev/null | jq -r 'map(select(.description == "Toggle top bar"))[0].key // ""' 2>/dev/null)
      # A key name goes into Lua below: only a plain one (letters, digits, _).
      case "$key" in *[!A-Za-z0-9_]*) key="" ;; esac
      mods='down("Super_L") or down("Super_R") or down("Shift_L") or down("Shift_R") or down("Control_L") or down("Control_R") or down("Alt_L") or down("Alt_R")'
      if [ -n "$key" ]; then held="down(\\"$key\\") or down(string.lower(\\"$key\\"))"; else held=$mods; fi
      lua="local function down(k) local ok, r = pcall(hl.is_key_down, k); return ok and r == true end; return $held"
      # At most a minute, a poll every 50 ms.
      for i in $(seq 1200); do
        [ "$(hyprctl repl "$lua" 2>/dev/null)" = true ] || break
        sleep 0.05
      done
      echo released`]
    stdout: SplitParser { onRead: function(line) { if (String(line).trim() === "released") root.toggleHeld = false } }
    onExited: root.toggleHeld = false
  }
  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  // The directory watch can permanently stop delivering events after flag
  // changes land in quick succession, stranding the bar off screen until the
  // shell restarts. `omarchy-toggle-bar` nudges this after flipping the flag
  // so the probe re-reads it even when the watch has gone quiet.
  IpcHandler {
    target: "omarchy.bar"

    // Start rather than restart: a probe already in flight was launched by the
    // directory watch after the flag flipped, so its answer is current, and
    // killing it here can swallow the result entirely.
    function syncHidden(): void {
      barHiddenProbe.running = true
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
      }
    }
  }

  // The keyboard mode's dismiss layer on every other monitor (each bar window
  // has its own for its monitor, keysDismiss): a click on another output ends
  // the mode too, as Omarchy's keyboard panels put a twin on every output, so
  // the bar never keeps the keys while the user works elsewhere.
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData
        readonly property var holder: root.barKeys.here ? root.barKeys.window : null
        screen: modelData
        // By output name: the holder's screen must be known before a twin maps.
        visible: !!holder && !!holder.screen && modelData.name !== holder.screen.name
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "powerbar-keys-dismiss"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onPressed: root.barKeys.leave()
        }
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      DragGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarMoveGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow
    Component.onDestruction: {
      root.reportZoneFit(barWindow.screen ? barWindow.screen.name : "", null)
      if (centerInlineBusy) root.centerRevealBlocks = Math.max(0, root.centerRevealBlocks - 1)
      // A monitor going away takes its bar: the keyboard mode on it ends, or
      // it would stay active with no bar to hold the cursor (and keep a
      // switched-off bar shown, INTEG-43).
      if (barKeysItem.window === barWindow) barKeysItem.leave()
    }
    property alias managedDrawer: drawer
    // The zone dots in this window, for drops (FoldHandle registers itself).
    property var foldHandles: []
    function registerFoldHandle(handle, present) {
      var list = foldHandles.filter(function(h) { return h !== handle })
      if (present) list.push(handle)
      foldHandles = list
    }
    function foldHandleAt(point) {
      for (var i = 0; i < foldHandles.length; i++) {
        var h = foldHandles[i]
        if (!h || !h.shown || h.fitYielded || !h.visible || zoneHidden(h.zone)) continue
        var a = h.mapToItem(barWindow.contentItem, 0, 0), b = h.mapToItem(barWindow.contentItem, h.width, h.height)
        if (point.x >= Math.min(a.x, b.x) && point.x <= Math.max(a.x, b.x) && point.y >= Math.min(a.y, b.y) && point.y <= Math.max(a.y, b.y)) return h
      }
      return null
    }
    property alias widgetStore: widgetStore
    property var widgetModels: ({ left: leftModel, right: rightModel, center: centerModel,
      before: beforeModel, anchor: anchorModel, after: afterModel })
    property var moduleItems: []
    // The zone fit for this window (docs/design/zone-fit.md): the one
    // place that decides which widgets fold into their zone's drawer, which
    // yield to a moment, and whether a zone is expanded inline. Its inputs are
    // bindings; refit() turns them into one result and publishes it at once.
    property var zoneFit: null
    property var zoneFitFolded: ({})
    property var zoneFitYielded: ({})
    // The last fit without a moment: moments freeze it.
    property var zoneFitLasting: null
    // A zone an inline expansion hides whole, island and all, while it lasts.
    function zoneHidden(zone) { return !!(zoneFit && zoneFit.hidden && zoneFit.hidden[zone]) }
    // Everything growing right now, highest priority first: a drag gap, the
    // indicators' hover reveal, activity reveals (one per zone), and last the
    // inline expansion, the one that can always give way to the drawer.
    readonly property var zoneFitMoments: {
      var out = []
      var preview = root.dragPreview
      if (preview.ready && preview.targetSurface.indexOf("bar:") === 0)
        out.push({ zone: preview.targetSurface.slice(4), sourceKey: preview.sourceKey })
      var items = moduleItems
      if (root.centerSectionRevealHeld) {
        var indicators = items.find(function(s) {
          return s && s.region === "center" && root.canonicalWidgetId(s.moduleName) === "omarchy.indicators"
        })
        out.push({ zone: "center", sourceKey: indicators ? indicators.instanceKey : null })
      }
      var seen = {}
      for (var i = 0; i < items.length; i++) {
        var s = items[i]
        if (s && s.managed && !s.drawerHost && !s.inlineShown && !seen[s.region] && (s.activityVisible || s.panelOpen || s.hovered)) {
          seen[s.region] = true
          out.push({ zone: s.region, sourceKey: s.instanceKey })
        }
      }
      if (inlineZone) out.push({ zone: inlineZoneName, sourceKey: null, unfold: inlineZoneName, side: inlineZone.split(":")[1] || "" })
      return out
    }
    // A moment that lasts longer than ten seconds counts as lasting content;
    // a held inline expansion never does.
    property var zoneFitBorn: ({})
    property var zoneFitAged: ({})
    function zoneFitMomentId(m) { return m.zone + "|" + m.sourceKey + "|" + !!m.unfold + "|" + (m.side || "") }
    function ageMoments() {
      var now = Date.now(), born = {}, aged = {}, next = 0
      for (var m of zoneFitMoments) {
        var id = zoneFitMomentId(m)
        born[id] = zoneFitBorn[id] || now
        if (m.unfold) continue
        var left = born[id] + 10000 - now
        if (left <= 0) aged[id] = true
        else next = next ? Math.min(next, left) : left
      }
      zoneFitBorn = born
      if (!RenderModel.equal(aged, zoneFitAged)) zoneFitAged = aged
      if (next) { zoneFitAge.interval = Math.max(1, next); zoneFitAge.restart() }
      else zoneFitAge.stop()
    }
    onZoneFitMomentsChanged: ageMoments()
    Timer { id: zoneFitAge; onTriggered: barWindow.ageMoments() }
    // A zone's widgets as the fit sees them. With expand (an inline token), the
    // hidden on-demand widgets it shows count as shown, at their measured size:
    // what the zone would be if it expanded inline.
    function zoneFitList(model, expand) {
      var out = []
      for (var i = 0; model && i < model.count; i++) {
        var s = model.get(i)
        if (s && s.fitExtent > 0) out.push({ key: s.instanceKey, extent: s.fitExtent, spill: s.cellSpill })
        else if (s && expand && s.inlineToken === expand && s.inlineCandidate && s.cellExtent > 0)
          out.push({ key: s.instanceKey, extent: s.cellExtent, spill: s.cellSpill })
      }
      return out
    }
    // Everything the fit reads; any change schedules one refit.
    readonly property var zoneFitInputs: {
      var anchors = zoneFitList(anchorModel)
      var prefs = CellModel.place(root.cellTokens, root.preferencesGlyphSize, true)
      var right = zoneFitList(rightModel)
      right.push({ key: "prefs", extent: prefs.extent, spill: prefs.spill })
      var hidden = inlineHidden
      var aged = zoneFitAged
      return {
        length: (root.vertical ? mainStrip.height : mainStrip.width),
        inset: root.islandScreenInset,
        gap: root.zoneGap,
        momentGap: root.edgeGap,
        gutter: root.cellTokens.gutter,
        left: zoneFitList(leftModel), right: right,
        before: zoneFitList(beforeModel), anchor: anchors.length ? anchors[0] : null, after: zoneFitList(afterModel),
        center: zoneFitList(centerModel),
        dots: { left: hidden.left > 0, center: { start: hidden.centerStart > 0, end: hidden.centerEnd > 0 }, right: hidden.right > 0 },
        moments: zoneFitMoments.filter(function(m) { return !aged[barWindow.zoneFitMomentId(m)] })
      }
    }
    onZoneFitInputsChanged: Qt.callLater(barWindow.refit)
    function zoneFitInput(i, transient) {
      var handle = CellModel.place(root.cellTokens, CellModel.TYPICAL_GLYPH, true)
      return {
        length: i.length, inset: i.inset, gap: i.gap, gutter: i.gutter, momentGap: i.momentGap,
        pad: function(spill) { return root.cellEndPad(spill) },
        handle: { extent: handle.extent, spill: handle.spill },
        zones: { left: i.left, right: i.right, before: i.before, anchor: i.anchor, after: i.after, center: i.center },
        dots: i.dots,
        previous: zoneFitLasting,
        transient: transient && transient.length ? transient : null
      }
    }
    // The inputs of the last fit: unchanged inputs give the same fit, so the
    // model only runs when something it reads has changed.
    property var zoneFitSeen: null
    function refit(force) {
      var i = zoneFitInputs
      if (!(i.length > 0)) return
      if (force !== true && RenderModel.equal(i, zoneFitSeen)) return
      zoneFitSeen = i
      var result = ZoneFitModel.fit(zoneFitInput(i, i.moments))
      // An inline expansion that can't be served (a higher moment needs the
      // room, or a widget measured differently once shown) gives way to the
      // drawer at once, and the bar is fitted again without it.
      if (inlineZone && (result.fallbacks || []).some(function(f) { return f.zone === barWindow.inlineZoneName })) {
        var zone = inlineZoneName, pointed = inlineHovered
        inlineRequest = ""
        inlineApply("")
        if (pointed) drawer.openZone(zone, false)
        return
      }
      if (!i.moments.length) {
        zoneFitLasting = result
        root.reportZoneFit(barWindow.screen ? barWindow.screen.name : "", result.folded)
      }
      if (RenderModel.equal(result, zoneFit)) return
      var folded = {}, yielded = {}
      result.folded.left.concat(result.folded.center, result.folded.right).forEach(function(key) { folded[key] = true })
      result.yielded.forEach(function(key) { yielded[key] = true })
      zoneFit = result
      if (!RenderModel.equal(folded, zoneFitFolded)) zoneFitFolded = folded
      if (!RenderModel.equal(yielded, zoneFitYielded)) zoneFitYielded = yielded
    }

    // Inline mode: hovering a zone's dots expands its hidden widgets in the
    // bar as a moment (neighbours yield, nothing slides). Requests go through
    // one queue: the pointer has to rest on the dots briefly (a swipe across
    // them expands nothing), and a switch collapses the open zone first and
    // expands the next only once that collapse has settled, so two zones never
    // move at once. An expansion holds while the pointer is on its zone, a
    // panel is open from it, a drag runs or a group drawer is open, then
    // collapses after the exit grace. A zone that can't fit opens its drawer.
    // Requests and the shown expansion are tokens: a zone, or the centre by
    // side ("center:start", "center:end"), whose dots expand independently.
    property string inlineRequest: ""
    property string inlineZone: ""
    readonly property string inlineZoneName: inlineZone.split(":")[0]
    // A centre side asked for or shown holds the indicators' reveal closed.
    readonly property bool centerInlineBusy: inlineZoneName === "center" || inlineRequest.split(":")[0] === "center"
    onCenterInlineBusyChanged: root.centerRevealBlocks = Math.max(0, root.centerRevealBlocks + (centerInlineBusy ? 1 : -1))
    // The dots under the pointer, if any.
    property string inlineHandleZone: ""
    readonly property int inlineIntentMs: 90
    // Long enough for a collapse (slots 120 ms) to finish before the next opens.
    readonly property int inlineSettleMs: root.animationsEnabled ? 170 : 0
    // No expansion before this time: a collapse is still settling.
    property real inlineReadyAt: 0
    // Each zone's on-demand widgets waiting behind its dots (folded ones apart),
    // the centre's also by the side of its anchor they wait on.
    readonly property var inlineHidden: {
      var out = { left: 0, center: 0, right: 0, centerStart: 0, centerEnd: 0 }
      if (!root.onDemandInline) return out
      for (var s of moduleItems) {
        if (!s || !s.inlineCandidate || out[s.region] === undefined) continue
        out[s.region]++
        if (s.region === "center") out[s.centerSide === "start" ? "centerStart" : "centerEnd"]++
      }
      return out
    }
    // An expansion holds while the pointer is anywhere on its zone.
    readonly property bool inlineHovered: inlineZone !== "" && (inlineHandleZone === inlineZone
      || moduleItems.some(function(s) { return s && s.region === barWindow.inlineZoneName && s.hovered && !s.drawerHost }))
    // A drag holds it only while it stays in the zone (or on its dots); it
    // closes on the exit grace once the drag leaves the bar, and at once when
    // the drag reaches another zone, so that zone's dots are never left
    // yielded or hidden under an expansion the drag has moved past.
    readonly property bool inlineDragHere: !!root.barDragSource && root.barDragZone === inlineZoneName
    readonly property bool inlineInteraction: inlineZone !== "" && (inlineDragHere
      || root.barKeys.heldBy(barWindow) && root.barKeys.zone === inlineZoneName
      || (drawer.presenting && !!drawer.groupId)
      || moduleItems.some(function(s) { return s && s.region === barWindow.inlineZoneName && s.panelOpen }))
    onInlineHoveredChanged: inlineSchedule()
    onInlineInteractionChanged: inlineSchedule()
    function inlineSchedule() {
      inlineCollapse.stop()
      if (!inlineZone || inlineHovered || inlineInteraction) return
      inlineCollapse.interval = Math.max(1, Math.round(root.managedExitSeconds * 1000))
      inlineCollapse.start()
    }
    Timer { id: inlineCollapse; onTriggered: barWindow.inlineAsk("") }
    Connections {
      target: root
      function onBarDragZoneChanged() {
        var asked = (barWindow.inlineZone || barWindow.inlineRequest).split(":")[0]
        if (root.barDragSource && root.barDragZone && asked && root.barDragZone !== asked
            && root.sameWindow(root.barDragWindow, barWindow)) barWindow.inlineAsk("")
      }
    }
    // An expansion opening or closing under a still pointer: once it has
    // settled, the drop is read again where the pointer is.
    Timer {
      id: inlineDragRefresh
      // Past the motion, or two frames for the layout to land without it.
      interval: root.animationsEnabled ? 330 : 40
      onTriggered: root.refreshIconDrag()
    }
    Timer { id: inlineStep; onTriggered: barWindow.inlineAdvance(true) }
    // Show a zone's expansion (or none) and fit the bar in the same step, so
    // its widgets and their neighbours' yields land in the same frame.
    function inlineApply(zone) {
      if (inlineZone === zone) return
      if (inlineZone) inlineReadyAt = Date.now() + inlineSettleMs
      inlineZone = zone
      // The dots give way to the widgets; from here the zone's slots hold it.
      if (zone) inlineHandleZone = ""
      refit(true)
      if (root.barDragSource) inlineDragRefresh.restart()
      inlineSchedule()
    }
    function inlineAsk(zone) {
      if (inlineRequest !== zone) { inlineRequest = zone; inlineStep.stop() }
      inlineAdvance(false)
    }
    // One step of the queue towards the request (InlineQueue.js decides);
    // due when the queue's timer fires.
    function inlineAdvance(due) {
      var now = Date.now()
      var step = InlineQueue.advance({ request: inlineRequest, zone: inlineZone, readyAt: inlineReadyAt }, {
        now: now, due: due === true, enabled: root.onDemandInline && !root.barHidden,
        intentMs: inlineIntentMs, settleMs: inlineSettleMs, timerRunning: inlineStep.running,
        holdHeld: root.centerSectionRevealHeld && !root.centerSectionHovered
      })
      if (step.collapse) inlineApply("")
      if (step.releaseHold) root.centerSectionRevealHeld = false
      inlineReadyAt = step.readyAt
      if (step.stop) inlineStep.stop()
      if (step.wait > 0) { inlineStep.interval = step.wait; inlineStep.restart() }
      if (step.hold) inlineSchedule()
      if (!step.expand) return
      // Measured now, beside every moment running now.
      if (!inlineFits(step.expand)) {
        inlineRequest = ""
        if (inlineHandleZone === step.expand) drawer.sourceEnter(step.expand.split(":")[0])
        return
      }
      // Not the drawer a drag is coming from: its row drives the drag.
      if (root.managedOwner && !root.managedOwner.dragMount) root.managedOwner.close("immediate")
      inlineApply(step.expand)
    }
    // Would the zone fit with its hidden widgets shown, beside every other
    // moment running now?
    function inlineFits(token) {
      var i = Object.assign({}, zoneFitInputs)
      var zone = token.split(":")[0], side = token.split(":")[1] || ""
      var models = zone === "left" ? { left: leftModel } : zone === "right" ? { right: rightModel }
        : { before: beforeModel, after: afterModel, center: centerModel }
      for (var name in models) i[name] = zoneFitList(models[name], token)
      if (zone === "right") {
        var prefs = CellModel.place(root.cellTokens, root.preferencesGlyphSize, true)
        i.right.push({ key: "prefs", extent: prefs.extent, spill: prefs.spill })
      }
      i.dots = Object.assign({}, i.dots)
      if (zone === "center") {
        i.dots.center = Object.assign({}, i.dots.center)
        i.dots.center[side] = false
      } else i.dots[zone] = false
      if (!(i.length > 0)) return false
      var moments = i.moments.filter(function(m) { return !m.unfold }).concat([{ zone: zone, sourceKey: null, unfold: zone, side: side }])
      var result = ZoneFitModel.fit(zoneFitInput(i, moments))
      return !(result.fallbacks || []).some(function(f) { return f.zone === zone })
    }
    // The dots: hovering asks for the zone, clicking skips the hover intent.
    function inlineEnter(zone, clicked) {
      inlineHandleZone = zone
      inlineAsk(zone)
      if (clicked && inlineRequest === zone && inlineZone !== zone) { inlineStep.stop(); inlineAdvance(true) }
    }
    function inlineLeave(zone) {
      if (inlineHandleZone === zone) inlineHandleZone = ""
      // Left before it opened: a swipe, not a request.
      if (inlineRequest === zone && inlineZone !== zone) inlineAsk("")
      var name = zone.split(":")[0]
      if (drawer.opened && drawer.zone === name && !drawer.groupId) drawer.sourceLeave(name)
      inlineSchedule()
    }
    function inlineCollapseNow() {
      inlineHandleZone = ""
      inlineRequest = ""
      inlineStep.stop()
      inlineCollapse.stop()
      inlineApply("")
    }
    Connections {
      target: root
      function onOnDemandInlineChanged() { barWindow.inlineCollapseNow() }
      function onBarHiddenChanged() { if (root.barHidden) barWindow.inlineCollapseNow() }
    }
    // A zone drawer (keyboard, IPC or the fallback) takes the zone's widgets.
    Connections {
      target: drawer
      function onPresentingChanged() { if (drawer.presenting && !drawer.groupId) barWindow.inlineCollapseNow() }
      function onZoneChanged() { if (drawer.presenting && !drawer.groupId) barWindow.inlineCollapseNow() }
    }
    Models.ObjectModel { id: leftModel }
    Models.ObjectModel { id: rightModel }
    Models.ObjectModel { id: centerModel }
    Models.ObjectModel { id: beforeModel }
    Models.ObjectModel { id: anchorModel }
    Models.ObjectModel { id: afterModel }
    RetainedStore {
      id: widgetStore
      factory: Component {
        ModuleSlot {
          homeWindow: barWindow
        }
      }
    }
    function reconcileWidgets() {
      var records = RenderModel.records(root.layoutConfig)
      widgetStore.reconcile(records)
      var partition = RenderModel.split(records, root.centerAnchor)
      var names = ["left", "right", "center", "before", "anchor", "after"]
      var models = [], lists = []
      // On-demand widgets draw as one run at their dots (ZoneOrderModel).
      var managed = function(item) { return item.managed }
      for (var name of names) {
        models.push(widgetModels[name])
        lists.push(ZoneOrderModel.arrange(partition[name].map(function(key) { return widgetStore.get(key) }).filter(function(item) { return !!item }), managed, name))
      }
      var items = records.map(function(record) { return widgetStore.get(record.key) }).filter(function(item) { return !!item })
      for (var item of items) {
        item.centerAnchorSlot = partition.anchor.indexOf(item.instanceKey) >= 0
        item.centerSide = partition.before.indexOf(item.instanceKey) >= 0 ? "start" : "end"
      }
      RenderModel.reconcileLists(models, lists, widgetStore)
      if (!RenderModel.sameItems(moduleItems, items)) moduleItems = items
      widgetStore.sweep()
    }
    Connections {
      target: root
      function onLayoutConfigChanged() { barWindow.reconcileWidgets() }
      function onCenterAnchorChanged() { barWindow.reconcileWidgets() }
    }
    Component.onCompleted: reconcileWidgets()

    // Keep the Wayland surface stable across drawer opens/closes. Only the
    // input region and drawer visibility change; no full-bar buffer resize.
    readonly property real effectPadding: 64
    readonly property real drawerExtent: drawer.thickness + drawer.gap + effectPadding
      + (root.groups.some(function(g) { return ManagedModel.groupMenu(g) }) ? Style.space(300) : 0)

    // Hiding parks the bar just past its screen edge instead of unmapping it.
    // Unmapping frees the layer surface and the whole scene graph, so every
    // reveal has to rebuild them — new surface, re-shaped glyphs, re-uploaded
    // textures — which measures ~150ms against ~20ms to tear down. Parking
    // keeps the surface alive, so showing is only a margin change.
    visible: !remapping
    // Hidden for a moment to remap (a blur change, a screen move). Widgets read
    // as invisible meanwhile, so the window freezes its slots' measurements
    // first and thaws them once the widgets have reported their sizes again.
    readonly property bool remapping: remapGuard.remapping || blurRemap.running
    property bool layoutFrozen: false
    function freezeLayout() { layoutFrozen = true; layoutThaw.stop(); layoutThawFallback.restart() }
    onRemappingChanged: if (!remapping && layoutFrozen) layoutThaw.restart()
    Timer { id: layoutThaw; interval: 250; onTriggered: if (!barWindow.remapping) barWindow.layoutFrozen = false }
    // A screen move that settles without a remap still thaws.
    Timer { id: layoutThawFallback; interval: 2000; onTriggered: if (!barWindow.remapping) barWindow.layoutFrozen = false }
    // Omarchy's remap guard waits 200 ms after the screen moves before it
    // hides the window; freeze on the move itself.
    Connections {
      target: barWindow.screen
      ignoreUnknownSignals: true
      function onXChanged() { barWindow.freezeLayout() }
      function onYChanged() { barWindow.freezeLayout() }
    }
    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: root.barHidden || root.autoHide ? 0 : root.barExtent

    // Autohide overlays windows without reserving space. The surface stays
    // mapped and its content slides past the screen edge, leaving a thin edge
    // strip in the input region to catch the pointer and slide it back.
    readonly property bool autoHideActive: root.autoHide && !root.barHidden
    readonly property bool autoHideHeld: windowHover.hovered || edgeHover.hovered || drawer.opened
      || (!!root.activePopout && root.sameWindow(root.targetWindow(root.activePopout), barWindow))
      || !!root.barDragSource || root.barDragSettling || root.barMoveActive || preferencesPane.opened || root.toggleHeld
      || root.barKeys.heldBy(barWindow) || root.cliShown
    property bool autoHideRevealed: false
    onAutoHideHeldChanged: {
      if (autoHideHeld) {
        autoHideDelay.stop()
        autoHideRevealed = true
      } else {
        autoHideDelay.restart()
      }
    }
    Timer {
      id: autoHideDelay
      interval: 400
      onTriggered: if (!barWindow.autoHideHeld) barWindow.autoHideRevealed = false
    }
    readonly property real autoHideDistance: root.barExtent + root.surfaceEffects.shadowSize + Style.space(8)
    // Zones slid out by widget activity: "all" for flat and floating bars, or
    // single zones for islands. One timer ends them; new activity extends it.
    // Per-zone layers between the islands and the widgets, where bar item
    // highlights are drawn so a widget's own clipped slot cannot cut them.
    property var highlightLayers: ({})
    property var zoneIslands: ({})
    function registerHighlight(zone, layer, island) {
      var layers = Object.assign({}, highlightLayers), islands = Object.assign({}, zoneIslands)
      layers[zone] = layer
      islands[zone] = island
      highlightLayers = layers
      zoneIslands = islands
    }
    property var peekZones: ({})
    function peek(zone) {
      if (!autoHideActive) return
      var next = Object.assign({}, peekZones)
      next[root.islands ? zone : "all"] = true
      peekZones = next
      peekEnd.restart()
    }
    Timer { id: peekEnd; interval: root.autoHidePeekMs; onTriggered: barWindow.peekZones = ({}) }
    readonly property bool peeking: !!(peekZones.all || peekZones.left || peekZones.center || peekZones.right)
    readonly property bool autoHideShown: !autoHideActive || autoHideRevealed || peeking
    property real autoHideOffset: autoHideShown ? 0 : autoHideDistance
    // A drawer opening or closing under a tooltip moves it clear. A tooltip
    // on a drawer's row (the keyboard's name card after a search opened the
    // group) is placed again once the drawer has its final size and scale:
    // at the start of the opening it is still growing, so the row is not yet
    // where it settles. One reposition per change batch, never per frame.
    function reanchorTooltip() { if (tooltipWindow.visible) tooltipAnchor.updateAnchor() }
    Connections {
      target: drawer
      function onOpenedChanged() { Qt.callLater(barWindow.reanchorTooltip) }
      function onSteppedAsideChanged() { Qt.callLater(barWindow.reanchorTooltip) }
      function onRevealChanged() { if (drawer.reveal >= 0.999 || drawer.reveal <= 0.001) Qt.callLater(barWindow.reanchorTooltip) }
      function onXChanged() { Qt.callLater(barWindow.reanchorTooltip) }
      function onYChanged() { Qt.callLater(barWindow.reanchorTooltip) }
      function onWidthChanged() { Qt.callLater(barWindow.reanchorTooltip) }
      function onHeightChanged() { Qt.callLater(barWindow.reanchorTooltip) }
    }
    // Sliding out answers the pointer, so it is a touch slower than sliding
    // away; tucked islands move on the strip's exact curve so they cancel out.
    readonly property int autoHideMotionMs: autoHideShown ? 180 : 130
    // While one island peeks the strip is out, so the others are pushed back
    // past the edge by the same distance, on the same curve.
    function zoneTucked(zone) { return root.islands && autoHideActive && !autoHideRevealed && peeking && !peekZones[zone] }
    property real leftShift: zoneTucked("left") ? autoHideDistance : 0
    property real centerShift: zoneTucked("center") ? autoHideDistance : 0
    property real rightShift: zoneTucked("right") ? autoHideDistance : 0
    // The centre's offset from the middle so zones keep their gap (docs/behavior/layout-zones.md).
    property real fitShift: zoneFit ? zoneFit.centerShift : 0
    Behavior on fitShift {
      enabled: root.animationsEnabled
      NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.77, 0, 0.175, 1, 1, 1] }
    }
    Behavior on leftShift { enabled: root.animationsEnabled; NumberAnimation { duration: barWindow.autoHideMotionMs; easing.type: Easing.OutCubic } }
    Behavior on centerShift { enabled: root.animationsEnabled; NumberAnimation { duration: barWindow.autoHideMotionMs; easing.type: Easing.OutCubic } }
    Behavior on rightShift { enabled: root.animationsEnabled; NumberAnimation { duration: barWindow.autoHideMotionMs; easing.type: Easing.OutCubic } }
    function shiftX(amount) { return root.position === "left" ? -amount : root.position === "right" ? amount : 0 }
    function shiftY(amount) { return root.position === "top" ? -amount : root.position === "bottom" ? amount : 0 }
    Behavior on autoHideOffset {
      enabled: root.animationsEnabled
      NumberAnimation { duration: barWindow.autoHideMotionMs; easing.type: Easing.OutCubic }
    }
    readonly property real autoHideEdge: 2
    // Mapping a surface stalls the bar's frames for a moment, so the keyboard
    // mode's own surfaces (the dismiss layer, the key legend) and any tooltip
    // wait until the bar has slid out: the slide is what the eye is on.
    readonly property bool sliding: autoHideOffset > 0.5

    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }
    readonly property bool blurEnabled: root.surfaceEffects.blur
    onBlurEnabledChanged: {
      if (visible) { freezeLayout(); blurRemap.restart() }
    }
    // The layer-shell namespace is fixed at map time. Remap only for an
    // explicit blur preference change, never for drawer transitions.
    Timer { id: blurRemap; interval: 60 }

    margins {
      top: root.barHidden && root.position === "top" ? -(root.barExtent + drawerExtent) : 0
      bottom: root.barHidden && root.position === "bottom" ? -(root.barExtent + drawerExtent) : 0
      left: root.barHidden && root.position === "left" ? -(root.barExtent + drawerExtent) : 0
      right: root.barHidden && root.position === "right" ? -(root.barExtent + drawerExtent) : 0
    }

    anchors {
      top: root.position === "top" || root.vertical
      bottom: root.position === "bottom" || root.vertical
      left: root.position === "left" || !root.vertical
      right: root.position === "right" || !root.vertical
    }

    implicitWidth: root.vertical ? root.barExtent + drawerExtent : 0
    implicitHeight: root.vertical ? 0 : root.barExtent + drawerExtent
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: root.surfaceEffects.blur ? "powerbar" : "powerbar-clear"
    WlrLayershell.layer: WlrLayer.Top

    // The keyboard: a keyboard-opened drawer's, or the keyboard mode's cursor
    // (not while a panel it opened has the keys).
    // Not during a hand-off either: the keys go to whatever the press opened
    // while the mode waits to see what it was (BarKeys.here).
    readonly property bool keysHere: root.barKeys.heldBy(barWindow) && !root.barKeys.suspended && !root.barKeys.handOff
    // As Omarchy's keyboard panels do: Exclusive takes the keyboard, then
    // OnDemand keeps it. Exclusive alone would send every click to the bar,
    // so the dismiss layer below (under the pointer everywhere off the bar)
    // could never see one.
    property bool keysFocusPrimed: false
    property int keysPrimeTries: 0
    onKeysHereChanged: { keysFocusPrimed = false; keysPrimeTries = 0; if (keysHere) keysPrime.restart(); else { keysPrime.stop(); keysKick.stop() } }
    // Right after the mode takes the keyboard (entering, or back from a panel
    // or a hand-off) it can be taken away: a closing panel hands focus back
    // to the window that had it before, after its fade-out. Asking for
    // Exclusive again while already Exclusive sends nothing, so the bar drops
    // to OnDemand for a moment and asks anew, a few times. Only then: a
    // window opened later is a destination and ends the mode (BarKeys).
    readonly property bool keysWindowActive: keyCatcherItem.Window.active
    Timer {
      id: keysPrime
      interval: 200
      onTriggered: {
        if (barWindow.keysHere && !barWindow.keysWindowActive && barWindow.keysPrimeTries < 6) {
          barWindow.keysPrimeTries++
          barWindow.keysFocusPrimed = true
          keysKick.restart()
          return
        }
        barWindow.keysFocusPrimed = barWindow.keysHere
      }
    }
    Timer { id: keysKick; interval: 50; onTriggered: if (barWindow.keysHere) { barWindow.keysFocusPrimed = false; keysPrime.restart() } }

    // While the keyboard mode is on this bar, it alone decides: a drawer it
    // entered must not hold the keys while a panel it opened has them.
    readonly property int keyboardFocusMode: root.barKeys.heldBy(barWindow)
      ? (keysHere ? (keysFocusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None)
      : drawer.opened && drawer.keyboardMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.keyboardFocus: keyboardFocusMode
    mask: Region {
      x: mainStrip.x; y: mainStrip.y
      width: mainStrip.width; height: mainStrip.height
      Region {
        item: autoHideStrip
        intersection: Intersection.Combine
      }
      // A drawer stepped aside for a member's panel takes no clicks.
      Region {
        x: drawer.x; y: drawer.y
        width: drawer.opened && !drawer.steppedAside ? drawer.width : 0
        height: drawer.opened && !drawer.steppedAside ? drawer.height : 0
        intersection: Intersection.Combine
      }
    }
    HyprlandFocusGrab {
      // Hover drawers must stay passive so wheel input reaches other windows.
      // Only an explicitly opened keyboard drawer needs outside-click dismissal.
      active: drawer.opened && drawer.keyboardMode && drawer.grabReady && !root.activePopout && !barWindow.keysHere
      windows: [barWindow]
      onCleared: drawer.close()
    }
    ManagedDrawer { id: drawer; bar: root; hostWindow: barWindow }
    Item {
      id: autoHideStrip
      visible: barWindow.autoHideActive
      x: root.position === "right" ? barWindow.width - width : 0
      y: root.position === "bottom" ? barWindow.height - height : 0
      width: !visible ? 0 : root.vertical ? barWindow.autoHideEdge : barWindow.width
      height: !visible ? 0 : root.vertical ? barWindow.height : barWindow.autoHideEdge
      HoverHandler { id: edgeHover }
    }
    EffectSurface {
      id: mainStrip
      x: root.position === "right" ? barWindow.drawerExtent + barWindow.autoHideOffset
        : root.position === "left" ? -barWindow.autoHideOffset : 0
      y: root.position === "bottom" ? barWindow.drawerExtent + barWindow.autoHideOffset
        : root.position === "top" ? -barWindow.autoHideOffset : 0
      width: root.vertical ? root.barExtent : barWindow.width
      height: root.vertical ? barWindow.height : root.barExtent
      // A flat bar is this strip itself, square and edge to edge like
      // Omarchy's bar; the other styles draw their surfaces inside it.
      color: root.flat ? root.mainSurfaceColor : "transparent"
      shadowEnabled: root.flat && root.surfaceEffects.shadow
      shadowSize: root.surfaceEffects.shadowSize
      shadowOpacity: root.surfaceEffects.shadowOpacity
      radius: 0
      borderSpec: Border.none()
    }
    // A floating bar: one continuous surface, held off the edges like islands.
    EffectSurface {
      visible: root.floating
      x: mainStrip.x + (root.vertical ? (root.barExtent - root.barSize) / 2 : root.edgeGap)
      y: mainStrip.y + (root.vertical ? root.edgeGap : (root.barExtent - root.barSize) / 2)
      width: root.vertical ? root.barSize : mainStrip.width - root.edgeGap * 2
      height: root.vertical ? mainStrip.height - root.edgeGap * 2 : root.barSize
      color: root.mainSurfaceColor
      shadowEnabled: root.surfaceEffects.shadow
      shadowSize: root.surfaceEffects.shadowSize
      shadowOpacity: root.surfaceEffects.shadowOpacity
      radius: root.islandRounding
      borderSpec: root.islandBorder
    }
    Loader {
      x: mainStrip.x
      y: mainStrip.y
      width: mainStrip.width
      height: mainStrip.height
      transformOrigin: Item.TopLeft
      sourceComponent: barContents

      // A child of the loader, not a sibling of the sections: an ancestor stays
      // hovered while the pointer is over a widget.
      HoverHandler {
        onHoveredChanged: root.setBarHovered(hovered)
        Component.onDestruction: if (hovered) root.setBarHovered(false)
      }
      HoverHandler { id: windowHover }
    }
    // The pointer over this window's bar, for areas that must know where it
    // is whatever widget sits on top (the centre's hover reveal).
    readonly property var barPointer: windowHover

    // The keyboard mode's keys (BarKeys.qml); a key let go unfolds a group
    // under the cursor, so a held key sweeping past never flashes one.
    readonly property Item keyCatcher: keyCatcherItem
    property Item prefsButton: null
    Item {
      id: keyCatcherItem
      Keys.onPressed: function(event) { if (root.barKeys.barKey(event)) event.accepted = true }
      Keys.onReleased: function(event) { if (!event.isAutoRepeat) root.barKeys.released() }
    }

    Item {
      x: mainStrip.x; y: mainStrip.y
      width: mainStrip.width; height: mainStrip.height
      Repeater {
        model: ["left", "center", "right"]
        Item {
          id: zoneTarget
          required property string modelData
          required property int index
          x: root.vertical ? 0 : index * parent.width / 3
          y: root.vertical ? index * parent.height / 3 : 0
          width: root.vertical ? parent.width : parent.width / 3
          height: root.vertical ? parent.height / 3 : parent.height
          readonly property var members: root.managedSlots(modelData, barWindow)
          WidgetButton {
            bar: root
            text: "󰇘"
            tooltipText: ({ left: "Left", center: "Center", right: "Right" })[zoneTarget.modelData] + " drawer"
            visible: !root.onDemandInline && zoneTarget.members.length > 0 && !root.moduleSlots.some(function(slot) {
              return slot.region === zoneTarget.modelData && root.sameWindow(root.targetWindow(slot), barWindow) && slot.mainVisible && slot.width > 0
            })
            anchors.centerIn: parent
            width: root.barSize; height: root.barSize
            onPressed: drawer.openZone(zoneTarget.modelData, true)
            HoverHandler {
              id: zoneHover
              enabled: parent.visible && !root.barHidden && !preferencesPane.opened
              onHoveredChanged: {
                if (hovered) drawer.sourceEnter(zoneTarget.modelData)
                else drawer.sourceLeave(zoneTarget.modelData)
              }
            }
            HoverHighlight {
              anchors.fill: parent
              anchors.margins: root.highlightInset(parent.height)
              z: -1
              hovered: zoneHover.hovered && !root.barDragSource
              motionEnabled: root.animationsEnabled
              hoverColor: root.highlightHoverColor
              selectedColor: root.highlightSelectedColor
              rounding: root.highlightRadius
            }
          }
        }
      }
    }

    // While the keyboard mode lasts, a click anywhere off the bar (and off a
    // drawer it opened) ends it, as a click outside dismisses Omarchy's
    // keyboard panels, so the keys are never trapped. The click is spent there.
    PanelWindow {
      id: keysDismiss
      screen: barWindow.screen
      visible: barWindow.keysHere && !barWindow.sliding
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "powerbar-keys-dismiss"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      anchors { top: true; bottom: true; left: true; right: true }
      // Everything but the bar strip and an open drawer. The bar window sits
      // at its edge of the screen, so its corner is the screen's size less its own.
      readonly property real barX: root.position === "right" ? width - barWindow.width : 0
      readonly property real barY: root.position === "bottom" ? height - barWindow.height : 0
      mask: Region {
        width: keysDismiss.width; height: keysDismiss.height
        Region {
          x: keysDismiss.barX + mainStrip.x; y: keysDismiss.barY + mainStrip.y
          width: mainStrip.width; height: mainStrip.height
          intersection: Intersection.Subtract
        }
        Region {
          x: keysDismiss.barX + drawer.x; y: keysDismiss.barY + drawer.y
          width: drawer.opened ? drawer.width : 0; height: drawer.opened ? drawer.height : 0
          intersection: Intersection.Subtract
        }
      }
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.barKeys.leave()
      }
    }

    // The keyboard mode's key strip (docs/behavior/keyboard.md): at the far edge from
    // the bar (along the bottom for a side bar), so panels and drawers that
    // open beside the bar are never under it. It shows this edge's keys, the
    // search while finding, and every shortcut on ?.
    PanelWindow {
      id: keysStrip
      readonly property var keys: root.barKeys
      readonly property bool wanted: keys.heldBy(barWindow) && !keys.suspended && (root.keyLegend || keys.searching || keys.sheet)
      screen: barWindow.screen
      visible: wanted && !barWindow.sliding
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      // The bar's own surface names, so its blur rule covers the legend too.
      WlrLayershell.namespace: root.overlayStyled.surface && root.surfaceEffects.blur ? "powerbar" : "powerbar-keys"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}
      anchors.bottom: root.position !== "bottom"
      anchors.top: root.position === "bottom"
      margins.bottom: root.position !== "bottom" ? Style.space(24) : 0
      margins.top: root.position === "bottom" ? Style.space(24) : 0
      implicitWidth: Math.ceil(stripCard.implicitWidth) + 2 * root.overlayShadowPad
      implicitHeight: Math.ceil(stripCard.implicitHeight) + 2 * root.overlayShadowPad
      // Its text: the bar's once the legend is drawn like the bar.
      readonly property color ink: root.overlayStyled.surface ? root.barForeground : Color.popups.text
      readonly property var entries: wanted ? KeysModel.legend(root.position, keys.mode, !root.onDemandInline) : []
      readonly property var sheetEntries: wanted && keys.sheet ? keys.sheetEntries() : []
      EffectSurface {
        id: stripCard
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        implicitWidth: stripColumn.implicitWidth + Style.space(24)
        implicitHeight: stripColumn.implicitHeight + Style.space(16)
        radius: root.overlayStyled.shape ? root.islandRounding : Style.cornerRadius
        color: root.overlayStyled.surface ? root.overlaySurfaceColor : Qt.alpha(Color.popups.background, 0.84)
        borderSpec: root.overlayStyled.shape ? root.islandBorder : Border.surfaceSpec("popups", "border", Color.popups.border, 1)
        shadowEnabled: root.overlayShadow
        shadowSize: root.surfaceEffects.shadowSize
        shadowOpacity: root.surfaceEffects.shadowOpacity
        Column {
          id: stripColumn
          anchors.centerIn: parent
          spacing: Style.space(10)
          // ?: every widget's own shortcut on this bar.
          Column {
            visible: keysStrip.keys.sheet
            spacing: Style.space(4)
            Text {
              text: keysStrip.sheetEntries.length ? "Shortcuts" : "No widget on this bar has a shortcut yet. Set them in Preferences → Layout."
              color: keysStrip.ink
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: keysStrip.sheetEntries.length > 0
            }
            Grid {
              columns: 2
              columnSpacing: Style.space(16)
              rowSpacing: Style.space(4)
              Repeater {
                model: keysStrip.sheetEntries.length * 2
                Item {
                  required property int index
                  readonly property var entry: keysStrip.sheetEntries[Math.floor(index / 2)]
                  implicitWidth: index % 2 ? sheetKeys.implicitWidth : sheetName.implicitWidth
                  implicitHeight: Math.max(sheetKeys.implicitHeight, sheetName.implicitHeight)
                  Text {
                    id: sheetName
                    visible: index % 2 === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry ? entry.name : ""
                    color: Qt.alpha(keysStrip.ink, 0.7)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                  KeyCombo {
                    id: sheetKeys
                    visible: index % 2 === 1
                    anchors.verticalCenter: parent.verticalCenter
                    keys: entry ? entry.keys : []
                    foreground: keysStrip.ink
                  }
                }
              }
            }
          }
          // /: what is typed, and whether anything matches.
          Row {
            visible: keysStrip.keys.searching
            spacing: Style.space(8)
            Text {
              text: "Find"
              color: Qt.alpha(keysStrip.ink, 0.7)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
            BorderSurface {
              width: Math.max(Style.space(140), queryText.implicitWidth + Style.space(16))
              height: queryText.implicitHeight + Style.space(8)
              // Nested inside the card: its radius less the card's inset.
              radius: Math.max(2, Math.min(stripCard.radius - Style.space(8), Style.space(6)))
              color: Qt.alpha(keysStrip.ink, 0.06)
              borderSpec: Border.flat(Color.accent, 1)
              Text {
                id: queryText
                x: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: keysStrip.keys.query + "▏"
                color: keysStrip.ink
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
            Text {
              readonly property bool none: keysStrip.keys.query !== "" && keysStrip.keys.matchCount === 0
              text: keysStrip.keys.query === "" ? "Type part of a name" : none ? "No widget named that"
                : keysStrip.keys.matchCount === 1 ? "1 match" : (keysStrip.keys.matchIndex + 1) + " of " + keysStrip.keys.matchCount
              color: none ? Color.urgent : Qt.alpha(keysStrip.ink, 0.7)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          // The keys for where the cursor is.
          Row {
            spacing: Style.space(14)
            Repeater {
              model: keysStrip.entries
              Row {
                required property var modelData
                spacing: Style.space(5)
                Repeater {
                  model: String(modelData.keys).split(" ")
                  KeyCap { required property var modelData; text: modelData }
                }
                Text {
                  text: modelData.label
                  color: Qt.alpha(keysStrip.ink, 0.75)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }
          }
        }
      }
    }

    PopupWindow {
      id: tooltipWindow
      // Never takes the pointer: a tooltip that slid over its widget or the
      // drawer would steal the hover that keeps it shown.
      mask: Region {}

      visible: root.tooltipShown && !barWindow.sliding && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth) + 2 * root.overlayShadowPad
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight) + 2 * root.overlayShadowPad

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        // Out from the bar beside the target, never over an open drawer or
        // menu (TooltipModel).
        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return
          var box = barWindow.contentItem.mapFromItem(target, 0, 0, target.width, target.height)
          var open = drawer.opened && !drawer.steppedAside
          var at = TooltipModel.place(root.position, { x: box.x, y: box.y, width: box.width, height: box.height },
            { width: Math.ceil(tooltipBubble.implicitWidth), height: Math.ceil(tooltipBubble.implicitHeight) }, 6,
            open ? { x: drawer.x, y: drawer.y, width: drawer.width, height: drawer.height, vertical: drawer.stripVertical } : null,
            open && root.itemWithin(target, drawer), { width: barWindow.width, height: barWindow.height },
            { x: mainStrip.x, y: mainStrip.y, width: mainStrip.width, height: mainStrip.height })
          // The window holds the shadow's room around the bubble.
          tooltipAnchor.rect.x = Math.round(at.x) - root.overlayShadowPad
          tooltipAnchor.rect.y = Math.round(at.y) - root.overlayShadowPad
        }
      }

      EffectSurface {
        id: tooltipBubble
        x: root.overlayShadowPad
        y: root.overlayShadowPad
        width: implicitWidth
        height: implicitHeight
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: root.overlayStyled.surface ? root.overlaySurfaceColor : Color.tooltip.background
        borderSpec: root.overlayStyled.shape ? root.islandBorder : Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
        // A pill at most, as drawers cap theirs.
        radius: root.overlayStyled.shape ? Math.min(root.islandRounding, implicitHeight / 2) : Style.cornerRadius
        shadowEnabled: root.overlayShadow
        shadowSize: root.surfaceEffects.shadowSize
        shadowOpacity: root.surfaceEffects.shadowOpacity

        Text {
          id: tooltipLabel
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.tooltipText
          color: root.overlayStyled.surface ? root.barForeground : Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Component {
      id: barContents
      Item {
        anchors.fill: parent
        // Beneath every zone: it takes presses on the bar's empty space only.
        // Kept out of the centre's own item so the centre can be raised over
        // the other zones while it expands without covering their widgets.
        CenterGestureArea {
          anchors.fill: parent
          transform: Translate {
            x: barWindow.shiftX(barWindow.centerShift) + (root.vertical ? 0 : barWindow.fitShift)
            y: barWindow.shiftY(barWindow.centerShift) + (root.vertical ? barWindow.fitShift : 0)
          }
        }
        IslandSurface {
          id: leftIsland
          zoneHidden: barWindow.zoneHidden("left")
          transform: Translate { x: barWindow.shiftX(barWindow.leftShift); y: barWindow.shiftY(barWindow.leftShift) }
          x: root.vertical ? (parent.width - width) / 2 : leftModules.x + leftModules.shownLead - root.islandEnd("left", leftModules.leadSpill)
          y: root.vertical ? leftModules.y + leftModules.shownLead - root.islandEnd("left", leftModules.leadSpill) : (parent.height - height) / 2
          width: root.vertical ? root.barSize : leftModules.width - leftModules.shownLead - leftModules.shownTrail + root.islandEnd("left", leftModules.leadSpill) + root.islandEnd("left", leftModules.trailSpill)
          height: root.vertical ? leftModules.height - leftModules.shownLead - leftModules.shownTrail + root.islandEnd("left", leftModules.leadSpill) + root.islandEnd("left", leftModules.trailSpill) : root.barSize
          visible: root.islands && leftModules.shownLength > 0 && opacity > 0
        }
        IslandSurface {
          id: rightIsland
          zoneHidden: barWindow.zoneHidden("right")
          transform: Translate { x: barWindow.shiftX(barWindow.rightShift); y: barWindow.shiftY(barWindow.rightShift) }
          readonly property real start: rightModules.shownLength > 0
            ? (root.vertical ? rightModules.y : rightModules.x) + rightModules.shownLead - root.islandEnd("right", rightModules.leadSpill)
            : (root.vertical ? preferencesButton.y : preferencesButton.x) - root.islandEnd("right", preferencesButton.cellSpill)
          x: root.vertical ? (parent.width - width) / 2 : start
          y: root.vertical ? start : (parent.height - height) / 2
          // Measured from start, never from x or y: on a vertical bar x depends on
          // width, so width depending on x would loop when the orientation flips.
          width: root.vertical ? root.barSize : preferencesButton.x + preferencesButton.width + root.islandEnd("right", preferencesButton.cellSpill) - start
          height: root.vertical ? preferencesButton.y + preferencesButton.height + root.islandEnd("right", preferencesButton.cellSpill) - start : root.barSize
        }
        CenterModules {
          anchors.fill: parent
          homeWindow: barWindow
          // An expanding zone lies over the zones it hides or yields, so the
          // pointer reaches its widgets first (Qt still hovers disabled items).
          z: barWindow.inlineZoneName === "center" ? 1 : 0
          transform: Translate {
            x: barWindow.shiftX(barWindow.centerShift) + (root.vertical ? 0 : barWindow.fitShift)
            y: barWindow.shiftY(barWindow.centerShift) + (root.vertical ? barWindow.fitShift : 0)
          }
        }
        HighlightLayer { zone: "left"; island: leftIsland; transform: Translate { x: barWindow.shiftX(barWindow.leftShift); y: barWindow.shiftY(barWindow.leftShift) } }
        HighlightLayer { zone: "right"; island: rightIsland; transform: Translate { x: barWindow.shiftX(barWindow.rightShift); y: barWindow.shiftY(barWindow.rightShift) } }
        LeftModules {
          id: leftModules
          homeWindow: barWindow
          z: barWindow.inlineZoneName === "left" ? 1 : 0
          transform: Translate { x: barWindow.shiftX(barWindow.leftShift); y: barWindow.shiftY(barWindow.leftShift) }
          // Positioned with x/y, never with anchors switched by orientation: a
          // switch passes through a state anchored both ways, and Qt then writes
          // width/height directly, which removes their bindings for good.
          x: root.vertical ? (parent.width - width) / 2 : root.islandScreenInset + root.cellEndPad(leadSpill)
          y: root.vertical ? root.islandScreenInset + root.cellEndPad(leadSpill) : (parent.height - height) / 2
        }
        PreferencesButton {
          id: preferencesButton
          zoneHidden: barWindow.zoneHidden("right")
          // The keyboard mode's last stop on the bar.
          Component.onCompleted: barWindow.prefsButton = preferencesButton
          Component.onDestruction: if (barWindow.prefsButton === preferencesButton) barWindow.prefsButton = null
          transform: Translate { x: barWindow.shiftX(barWindow.rightShift); y: barWindow.shiftY(barWindow.rightShift) }
          x: root.vertical ? (parent.width - width) / 2 : parent.width - root.islandScreenInset - root.cellEndPad(cellSpill) - width
          y: root.vertical ? parent.height - root.islandScreenInset - root.cellEndPad(cellSpill) - height : (parent.height - height) / 2
        }
        RightModules {
          id: rightModules
          homeWindow: barWindow
          z: barWindow.inlineZoneName === "right" ? 1 : 0
          transform: Translate { x: barWindow.shiftX(barWindow.rightShift); y: barWindow.shiftY(barWindow.rightShift) }
          x: root.vertical ? (parent.width - width) / 2 : preferencesButton.x - width
          y: root.vertical ? preferencesButton.y - height : (parent.height - height) / 2
        }
      }
    }
  }

  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }

  // The landing placeholder in an open drag gap: the dragged widget's own
  // highlight, outlined, centred in the gap.
  component HighlightLayer: Item {
    id: layer
    property string zone: ""
    property Item island: null
    anchors.fill: parent
    Accessible.ignored: true
    // The window is known only once the layer is in the scene, so register
    // whenever it (or the island) arrives, not just on completion.
    readonly property var hostWindow: root.targetWindow(layer)
    function register() {
      var window = root.targetWindow(layer)
      if (window && typeof window.registerHighlight === "function") window.registerHighlight(zone, layer, island)
    }
    onHostWindowChanged: register()
    onIslandChanged: register()
    Component.onCompleted: Qt.callLater(register)
  }

  // Shared theme chrome; dimensions follow the rendered zone, including drawers.
  // The yield fade (layout-zones.md): a widget, island or button making room
  // fades out at once and fast, and comes back after a pause, once the
  // moment's zone has shrunk. leaving: fading out now; outMs: how fast it
  // goes (80 for a yield, 110 for a fold).
  component YieldFade: SequentialAnimation {
    property bool leaving: false
    property int outMs: 80
    PauseAnimation { duration: leaving ? 0 : 120 }
    NumberAnimation { duration: leaving ? outMs : 160; easing.type: Easing.OutCubic }
  }

  component IslandSurface: EffectSurface {
    // Hidden whole by an inline expansion: fades with its widgets, out fast,
    // back once the expansion has shrunk (the yield timings).
    property bool zoneHidden: false
    opacity: zoneHidden ? 0 : 1
    Behavior on opacity { enabled: root.animationsEnabled; YieldFade { leaving: zoneHidden } }
    visible: root.islands && opacity > 0
    color: root.mainSurfaceColor
    shadowEnabled: root.surfaceEffects.shadow
    shadowSize: root.surfaceEffects.shadowSize
    shadowOpacity: root.surfaceEffects.shadowOpacity
    radius: root.islandRounding
    borderSpec: root.islandBorder
  }

  component PreferencesButton: Item {
    id: preferencesButton
    readonly property bool isPrefsButton: true
    readonly property string label: "Powerbar preferences"
    function activate() { preferencesPane.show(root.targetWindow(preferencesButton).screen) }
    // Part of the right zone: hidden with it by an inline expansion.
    property bool zoneHidden: false
    opacity: zoneHidden ? 0 : 1
    enabled: !zoneHidden
    Behavior on opacity { enabled: root.animationsEnabled; YieldFade { leaving: preferencesButton.zoneHidden } }
    // A glyph cell like any icon widget: square highlight, one gutter (or one
    // equal gap) around its nine dots.
    readonly property real glyphSize: root.preferencesGlyphSize
    readonly property var cellPlace: CellModel.place(root.cellTokens, glyphSize, true)
    readonly property real cellSpill: cellPlace.spill
    implicitWidth: root.vertical ? root.barSize : cellPlace.extent
    implicitHeight: root.vertical ? cellPlace.extent : root.barSize
    width: implicitWidth
    height: implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: "Powerbar preferences"
    readonly property bool keysCursor: root.barKeys.here && root.barKeys.cursor === preferencesButton
    Rectangle {
      x: buttonHighlight.x; y: buttonHighlight.y; width: buttonHighlight.width; height: buttonHighlight.height
      radius: buttonHighlight.radius
      z: 3
      visible: preferencesButton.keysCursor
      color: "transparent"
      border.width: 1.5
      border.color: Color.accent
    }
    HoverHighlight {
      id: buttonHighlight
      hovered: (buttonMouse.containsMouse || preferencesButton.keysCursor) && !root.barDragSource && !root.barHidden
      selected: preferencesPane.opened
      motionEnabled: root.animationsEnabled
      hoverColor: root.highlightHoverColor
      selectedColor: root.highlightSelectedColor
      width: root.vertical ? root.cellTokens.thickness : preferencesButton.cellPlace.cell
      height: root.vertical ? preferencesButton.cellPlace.cell : root.cellTokens.thickness
      x: (preferencesButton.width - width) / 2
      y: (preferencesButton.height - height) / 2
      rounding: root.highlightRadius
    }
    Grid {
      id: preferencesGlyph
      anchors.centerIn: parent
      columns: 3; spacing: Style.spaceReal(2.5)
      Repeater {
        model: 9
        Rectangle { width: Style.space(2); height: width; radius: width / 2; color: root.barForeground }
      }
    }
    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: !preferencesButton.zoneHidden
      cursorShape: Qt.PointingHandCursor
      onClicked: preferencesButton.activate()
      onEntered: root.showTooltip(preferencesButton, "Powerbar preferences")
      onExited: root.hideTooltip(preferencesButton)
    }
  }

  component DragGhostPanel: PanelWindow {
    id: ghostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barDragScreen === ghostScreen ||
      (root.barDragScreen && ghostScreen && root.barDragScreen.name && ghostScreen.name && root.barDragScreen.name === ghostScreen.name)
    readonly property bool active: (!!root.barDragSource || root.barDragSettling) && root.barDragScreen && screenMatches
    visible: active && String(root.barDragImageUrl) !== ""
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only drag feedback. Keep the input region empty so the ghost can
    // sit under the cursor without stealing the MouseArea's active pointer grab.
    mask: Region {}

    // Over a group drawer the ghost takes that group's member style: its own
    // look, its name, or both, as a menu row would show it.
    readonly property var targetGroup: {
      var drop = root.barDragDrop
      if (!root.barDragSource || !drop) return null
      var id = drop.drawer && drop.drawer.groupId ? drop.drawer.groupId
        : drop.slot && drop.slot.drawerHost && drop.slot.memberGroup ? drop.slot.memberGroup.id : ""
      return id ? root.groups.find(function(g) { return g.id === id }) || null : null
    }
    readonly property string display: targetGroup ? targetGroup.memberDisplay : "native"
    readonly property string sourceTitle: {
      var source = root.barDragSource
      if (!source) return ""
      if (source.groupHeader && source.groupConfig) return source.groupConfig.label
      var metadata = root.barWidgetRegistry.metadataFor(root.canonicalWidgetId(source.moduleName)) || {}
      return BarModel.widgetName(metadata, source.moduleName)
    }
    BorderSurface {
      id: labelGhost
      visible: ghostWindow.visible && ghostWindow.display !== "native" && !root.barDragSettling
      x: Math.round(root.barDragScreenX - root.barDragOffsetX)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY)
      width: labelRow.implicitWidth + Style.space(20)
      height: Math.max(root.barDragImageHeight, labelText.implicitHeight + Style.space(12))
      // A menu row's shape, bordered like the drop outline it lands in.
      radius: root.highlightRadius
      // Over windows, like a drawer.
      color: root.overlaySurfaceColor
      borderSpec: Border.flat(Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.45), 1)
      Row {
        id: labelRow
        anchors.verticalCenter: parent.verticalCenter
        x: Style.space(10)
        spacing: Style.space(8)
        Image {
          visible: ghostWindow.display === "both"
          source: root.barDragImageUrl
          width: visible ? root.barDragImageWidth : 0
          height: root.barDragImageHeight
          fillMode: Image.PreserveAspectFit
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          id: labelText
          // A captured menu row already shows the name.
          visible: !(root.barDragImageLabelled && ghostWindow.display === "both")
          text: ghostWindow.sourceTitle
          textFormat: Text.PlainText
          color: root.barForeground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
    Image {
      readonly property var settle: ghostWindow.active && root.barDragSettling ? root.dragSettleFrame(root.barDragSettleProgress) : null
      visible: ghostWindow.visible && status === Image.Ready && (ghostWindow.display === "native" || root.barDragSettling)
      x: Math.round(settle ? settle.x : root.barDragScreenX - root.barDragOffsetX)
      y: Math.round(settle ? settle.y : root.barDragScreenY - root.barDragOffsetY)
      opacity: settle ? settle.opacity : 1
      scale: settle ? settle.scale : 1
      width: root.barDragImageWidth
      height: root.barDragImageHeight
      source: root.barDragImageUrl
      fillMode: Image.PreserveAspectFit
      smooth: true
      onStatusChanged: if (status === Image.Ready && ghostWindow.active) root.barDragImageReady = true
    }

  }

  component BarMoveGhostPanel: PanelWindow {
    id: moveGhostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barMoveScreen === ghostScreen ||
      (root.barMoveScreen && ghostScreen && root.barMoveScreen.name && ghostScreen.name && root.barMoveScreen.name === ghostScreen.name)
    visible: root.barMoveActive && screenMatches
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-move-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only preview of the candidate edge. Keep the input region empty
    // so the overlay never steals the gesture area's active pointer grab.
    mask: Region {}

    // One fixed-geometry slab per edge, crossfaded on candidate changes.
    // Resizing a single slab between edges repaints mid-transition and
    // flickers; fading between static ones does not.
    Repeater {
      model: ["top", "bottom", "left", "right"]

      BorderSurface {
        id: edgeSlab

        required property string modelData
        readonly property bool edgeVertical: modelData === "left" || modelData === "right"
        readonly property int edgeSize: root.barSizeFor(edgeVertical)

        x: modelData === "right" ? parent.width - edgeSize : 0
        y: modelData === "bottom" ? parent.height - edgeSize : 0
        width: edgeVertical ? edgeSize : parent.width
        height: edgeVertical ? parent.height : edgeSize
        // The bar's own surface, faded: where it would land.
        color: root.mainSurfaceColor
        borderSpec: Border.flat(root.barForeground, 1)
        visible: opacity > 0
        opacity: root.barMoveCandidate === modelData ? 0.7 : 0

        Behavior on opacity {
          enabled: root.animationsEnabled
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  function findCenterAnchorEntry() {
    var entries = root.layoutEntries("center")
    var idx = root.entryIndex(entries, root.centerAnchor)
    return idx === -1 ? null : entries[idx]
  }

  component LeftModules: ModuleList {
    entries: root.layoutEntries("left")
    region: "left"
  }

  component RightModules: ModuleList {
    entries: root.layoutEntries("right")
    region: "right"
  }

  component CenterModules: Item {
    id: centerRoot
    property var homeWindow: null
    property var entries: root.layoutEntries("center")
    readonly property bool hasAnchor: root.entryIndex(entries, root.centerAnchor) !== -1
    readonly property var anchorEntry: root.findCenterAnchorEntry()
    readonly property var anchorPreview: anchorEntry
      ? DragModel.slot(root.dragPreview, anchorEntry.powerbarInstance, "bar:center") : ({ before: false, after: false })
    IslandSurface {
      id: centerIsland
      zoneHidden: !!centerRoot.homeWindow && centerRoot.homeWindow.zoneHidden("center")
      readonly property real start: centerRoot.hasAnchor
        ? (beforeModules.shownLength > 0 ? (root.vertical ? beforeModules.y : beforeModules.x) + beforeModules.shownLead : (root.vertical ? centerAnchorModule.y : centerAnchorModule.x))
        : (root.vertical ? groupModules.y : groupModules.x) + groupModules.shownLead
      readonly property real end: centerRoot.hasAnchor
        ? (afterModules.shownLength > 0 ? (root.vertical ? afterModules.y + afterModules.height : afterModules.x + afterModules.width) - afterModules.shownTrail
          : (root.vertical ? centerAnchorModule.y + centerAnchorModule.height : centerAnchorModule.x + centerAnchorModule.width))
        : (root.vertical ? groupModules.y + groupModules.height : groupModules.x + groupModules.width) - groupModules.shownTrail
      readonly property real leadSpill: centerRoot.hasAnchor
        ? (beforeModules.shownLength > 0 ? beforeModules.leadSpill : centerAnchorModule.cellSpill) : groupModules.leadSpill
      readonly property real trailSpill: centerRoot.hasAnchor
        ? (afterModules.shownLength > 0 ? afterModules.trailSpill : centerAnchorModule.cellSpill) : groupModules.trailSpill
      x: root.vertical ? (parent.width - width) / 2 : start - root.islandEnd("center", leadSpill)
      y: root.vertical ? start - root.islandEnd("center", leadSpill) : (parent.height - height) / 2
      width: root.vertical ? root.barSize : end - start + root.islandEnd("center", leadSpill) + root.islandEnd("center", trailSpill)
      height: root.vertical ? end - start + root.islandEnd("center", leadSpill) + root.islandEnd("center", trailSpill) : root.barSize
      visible: root.islands && end > start && opacity > 0
    }
    HighlightLayer { zone: "center"; island: centerIsland }
    Item {
      x: root.vertical ? 0 : centerIsland.x
      y: root.vertical ? centerIsland.y : 0
      width: root.vertical ? parent.width : Math.max(0, centerIsland.width)
      height: root.vertical ? Math.max(0, centerIsland.height) : parent.height
      // The pointer on the centre island, widgets included: read from the
      // bar's own hover, since a handler here sits below the widgets and
      // their hover-enabled buttons would hide the pointer from it (it saw
      // only the gaps between them). A hidden centre doesn't answer the
      // pointer passing over the expansion.
      readonly property var pointer: centerRoot.homeWindow ? centerRoot.homeWindow.barPointer : null
      readonly property bool pointerInside: {
        if (!pointer || !pointer.hovered || centerIsland.zoneHidden || width <= 0 || height <= 0) return false
        var pos = pointer.point.position
        var p = mapFromItem(pointer.parent, pos.x, pos.y)
        return x === x && y === y && p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
      }
      onPointerInsideChanged: root.setCenterSectionHovered(pointerInside)
      Component.onDestruction: if (pointerInside) root.setCenterSectionHovered(false)
    }
    ModuleList {
      id: groupModules
      homeWindow: centerRoot.homeWindow
      listRole: "center"
      visible: !centerRoot.hasAnchor
      region: "center"
      anchors.centerIn: parent
    }
    ModuleList {
      id: beforeModules
      homeWindow: centerRoot.homeWindow
      listRole: "before"
      visible: centerRoot.hasAnchor
      previewEnd: false
      previewAnchorEnd: centerRoot.anchorPreview.before
      region: "center"
      x: root.vertical ? centerAnchorModule.x + (centerAnchorModule.width - width) / 2 : centerAnchorModule.x - width
      y: root.vertical ? centerAnchorModule.y - height : centerAnchorModule.y + (centerAnchorModule.height - height) / 2
    }
    Item {
      id: centerAnchorModule
      readonly property var model: centerRoot.homeWindow ? centerRoot.homeWindow.widgetModels.anchor : null
      readonly property var slot: model && model.count ? model.get(0) : null
      readonly property real cellSpill: slot ? slot.cellSpill : 0
      visible: centerRoot.hasAnchor
      width: slot ? slot.width : 0; height: slot ? slot.height : 0
      anchors.centerIn: parent
      Repeater { model: centerAnchorModule.model }
    }
    ModuleList {
      id: afterModules
      homeWindow: centerRoot.homeWindow
      listRole: "after"
      visible: centerRoot.hasAnchor
      previewAnchorStart: centerRoot.anchorPreview.after
      region: "center"
      x: root.vertical ? centerAnchorModule.x + (centerAnchorModule.width - width) / 2 : centerAnchorModule.x + centerAnchorModule.width
      y: root.vertical ? centerAnchorModule.y + centerAnchorModule.height : centerAnchorModule.y + (centerAnchorModule.height - height) / 2
    }
  }

  component CenterGestureArea: MouseArea {
    id: gestureArea

    property bool dragging: false
    property bool suppressClick: false
    property real pressedX: 0
    property real pressedY: 0
    readonly property real dragThreshold: Style.space(4)

    acceptedButtons: Qt.LeftButton
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
    pressAndHoldInterval: 200

    function startDrag(x, y) {
      if (dragging) return
      dragging = true
      root.beginBarMove(root.targetWindow(gestureArea))
      var scenePoint = gestureArea.mapToItem(null, x, y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onPressed: function(mouse) {
      dragging = false
      suppressClick = false
      pressedX = mouse.x
      pressedY = mouse.y
    }

    onPressAndHold: function(mouse) {
      // A widget above us propagates its composed press-and-hold down here without
      // ever handing over the grab, so we'd get no release or cancel to end the move.
      if (!gestureArea.pressed) return
      startDrag(mouse.x, mouse.y)
    }

    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return

      if (!dragging) {
        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance < dragThreshold) return
        startDrag(mouse.x, mouse.y)
        return
      }

      var scenePoint = gestureArea.mapToItem(null, mouse.x, mouse.y)
      root.updateBarMove(root.windowScreenPoint(scenePoint, root.barMoveWindow))
    }

    onReleased: function(mouse) {
      if (!dragging) return
      dragging = false
      suppressClick = true
      root.finishBarMove()
      mouse.accepted = true
    }

    onCanceled: {
      dragging = false
      suppressClick = false
      root.clearBarMove()
    }

    onClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        mouse.accepted = true
      }
    }

    onDoubleClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        return
      }
      if (mouse.button === Qt.LeftButton) {
        root.toggleTransparency()
        mouse.accepted = true
      }
    }
  }

  // The drawer handle a zone shows when widgets were folded off the bar
  // (docs/behavior/layout-zones.md): a glyph cell with a count; it opens the zone's drawer.
  component FoldHandle: Item {
    id: foldHandle
    readonly property bool isFoldHandle: true
    property var homeWindow: null
    property string zone: ""
    // Which end of its list: "start" or "end". The centre has dots on each
    // side of its anchor, each for the widgets waiting on that side.
    property string side: "end"
    readonly property string inlineToken: zone === "center" ? "center:" + side : zone
    property bool active: false
    onHomeWindowChanged: if (homeWindow && homeWindow.registerFoldHandle) homeWindow.registerFoldHandle(foldHandle, true)
    Component.onDestruction: if (homeWindow && homeWindow.registerFoldHandle) homeWindow.registerFoldHandle(foldHandle, false)
    // A drag over the dots: dropping makes the widget On demand here.
    readonly property bool dropTarget: !!root.barDragDrop && root.barDragDrop.handle === true
      && root.barDragDrop.handleToken === inlineToken && !!homeWindow && root.sameWindow(root.barDragWindow, homeWindow)
    // Folded widgets, plus (inline mode) the zone's hidden on-demand widgets.
    readonly property int count: !active || !homeWindow || !homeWindow.zoneFit ? 0
      : zone === "center" ? (homeWindow.zoneFit.centerFolded || { start: [], end: [] })[side].length
        + (root.onDemandInline ? homeWindow.inlineHidden[side === "start" ? "centerStart" : "centerEnd"] : 0)
      : homeWindow.zoneFit.folded[zone].length + (root.onDemandInline ? homeWindow.inlineHidden[zone] : 0)
    readonly property bool shown: count > 0
    // An inline expansion replaces the dots under the pointer.
    onShownChanged: if (!shown) root.hideTooltip(foldHandle)
    readonly property var cellPlace: CellModel.place(root.cellTokens, CellModel.TYPICAL_GLYPH, true)
    readonly property real cellSpill: cellPlace.spill
    readonly property bool fitYielded: !!(homeWindow && homeWindow.zoneFitYielded["handle:" + (zone === "center" ? "center:" + side : zone)])
    readonly property var drawerRef: homeWindow ? homeWindow.managedDrawer : null
    readonly property bool drawerOpen: !!drawerRef && drawerRef.opened && drawerRef.zone === zone && !drawerRef.groupId
    // The last count stays on the badge while the handle fades out.
    property int shownCount: 0
    onCountChanged: if (count > 0) shownCount = count
    readonly property string label: shownCount === 1 ? "1 more widget" : shownCount + " more widgets"
    // Along the bar the handle eases in and out with the slots around it, so
    // the island's end never jumps when the widgets it stands for take over.
    width: root.vertical ? (shown || opacity > 0 ? root.barSize : 0) : shown ? cellPlace.extent : 0
    height: !root.vertical ? (shown || opacity > 0 ? root.barSize : 0) : shown ? cellPlace.extent : 0
    Behavior on width { enabled: root.animationsEnabled && !root.vertical; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: root.animationsEnabled && root.vertical; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    visible: shown || opacity > 0
    opacity: !shown || fitYielded ? 0 : 1
    scale: shown ? 1 : 0.96
    transformOrigin: Item.Center
    Behavior on opacity { enabled: root.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on scale { enabled: root.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    enabled: shown && !fitYielded
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: label
    Keys.onReturnPressed: if (drawerRef) drawerRef.openZone(zone, true)
    Keys.onSpacePressed: if (drawerRef) drawerRef.openZone(zone, true)
    readonly property bool keysCursor: root.barKeys.here && root.barKeys.cursor === foldHandle
    Rectangle {
      x: handleHighlight.x; y: handleHighlight.y; width: handleHighlight.width; height: handleHighlight.height
      radius: handleHighlight.radius
      z: 3
      visible: foldHandle.keysCursor
      color: "transparent"
      border.width: 1.5
      border.color: Color.accent
    }
    HoverHighlight {
      id: handleHighlight
      hovered: (handleMouse.containsMouse || foldHandle.activeFocus || foldHandle.keysCursor) && !root.barDragSource && !root.barHidden
      selected: foldHandle.drawerOpen || foldHandle.dropTarget
      motionEnabled: root.animationsEnabled
      hoverColor: root.highlightHoverColor
      selectedColor: root.highlightSelectedColor
      width: root.vertical ? root.cellTokens.thickness : foldHandle.cellPlace.cell
      height: root.vertical ? foldHandle.cellPlace.cell : root.cellTokens.thickness
      x: (foldHandle.width - width) / 2
      y: (foldHandle.height - height) / 2
      rounding: root.highlightRadius
    }
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.vertical ? "󰇙" : "󰇘"
      color: root.barForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Rectangle {
      id: handleBadge
      readonly property var spot: CellModel.badge(
        { x: handleHighlight.x, y: handleHighlight.y, width: handleHighlight.width, height: handleHighlight.height, radius: root.highlightRadius },
        { width: foldHandle.width, height: foldHandle.height }, { width: width, height: height })
      visible: root.dotsBadge && foldHandle.shownCount > 0
      width: Math.max(Style.space(12), handleBadgeLabel.implicitWidth + Style.space(5))
      height: Style.space(12)
      radius: height / 2
      x: spot.x
      y: spot.y
      z: 2
      color: Color.accent
      Accessible.ignored: true
      Text {
        id: handleBadgeLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: foldHandle.shownCount > 99 ? "99+" : String(foldHandle.shownCount)
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    MouseArea {
      id: handleMouse
      anchors.fill: parent
      // Qt hovers disabled items too: dots that gave way must not answer the
      // pointer passing over the widgets that took their place.
      hoverEnabled: foldHandle.enabled
      cursorShape: Qt.PointingHandCursor
      // Inline mode expands the zone in the bar; drawer mode opens its drawer.
      onEntered: {
        if (!foldHandle.enabled) return
        if (root.onDemandInline && foldHandle.homeWindow) foldHandle.homeWindow.inlineEnter(foldHandle.inlineToken)
        else if (foldHandle.drawerRef) foldHandle.drawerRef.sourceEnter(foldHandle.zone)
        root.showTooltip(foldHandle, foldHandle.label)
      }
      onExited: {
        if (root.onDemandInline && foldHandle.homeWindow) foldHandle.homeWindow.inlineLeave(foldHandle.inlineToken)
        else if (foldHandle.drawerRef) foldHandle.drawerRef.sourceLeave(foldHandle.zone)
        root.hideTooltip(foldHandle)
      }
      onClicked: {
        if (!foldHandle.enabled) return
        if (root.onDemandInline && foldHandle.homeWindow) foldHandle.homeWindow.inlineEnter(foldHandle.inlineToken, true)
        else if (foldHandle.drawerRef) foldHandle.drawerRef.openZone(foldHandle.zone, false)
      }
    }
  }

  // Where widgets yield to a moment: the same dots as the drawer handle, quiet
  // and not interactive, with the count of widgets out of view (docs/behavior/layout-zones.md).
  component YieldMarker: Item {
    id: yieldMarker
    readonly property bool isYieldMarker: true
    property var homeWindow: null
    property string zone: ""
    property int count: 0
    readonly property bool shown: count > 0
    readonly property var cellPlace: CellModel.place(root.cellTokens, CellModel.TYPICAL_GLYPH, true)
    width: root.vertical ? root.barSize : cellPlace.extent
    height: root.vertical ? cellPlace.extent : root.barSize
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Accessible.ignored: true
    Behavior on opacity { enabled: root.animationsEnabled; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: root.vertical ? "󰇙" : "󰇘"
      color: root.barForeground
      opacity: 0.45
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Rectangle {
      readonly property real thick: root.cellTokens.thickness
      readonly property var spot: CellModel.badge(
        { x: (yieldMarker.width - (root.vertical ? thick : yieldMarker.cellPlace.cell)) / 2,
          y: (yieldMarker.height - (root.vertical ? yieldMarker.cellPlace.cell : thick)) / 2,
          width: root.vertical ? thick : yieldMarker.cellPlace.cell, height: root.vertical ? yieldMarker.cellPlace.cell : thick,
          radius: root.highlightRadius },
        { width: yieldMarker.width, height: yieldMarker.height }, { width: width, height: height })
      visible: root.dotsBadge
      width: Math.max(Style.space(12), yieldBadgeLabel.implicitWidth + Style.space(5))
      height: Style.space(12)
      radius: height / 2
      x: spot.x
      y: spot.y
      color: Color.accent
      Text {
        id: yieldBadgeLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: yieldMarker.count > 99 ? "99+" : String(yieldMarker.count)
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    // Resting on the marker brings its widgets back: it ends the hover moment
    // that made them give way (the indicators' held reveal, or another zone's
    // inline expansion), after the same intent as the dots. Read from the bar
    // window's own pointer: the widgets it stands for still take hover.
    readonly property var pointer: homeWindow ? homeWindow.barPointer : null
    readonly property bool pointerInside: {
      if (!shown || !pointer || !pointer.hovered || root.barDragSource || width <= 0 || height <= 0) return false
      var pos = pointer.point.position
      var p = mapFromItem(pointer.parent, pos.x, pos.y)
      return p.x >= 0 && p.y >= 0 && p.x < width && p.y < height
    }
    onPointerInsideChanged: if (pointerInside) yieldRelease.restart(); else yieldRelease.stop()
    Timer {
      id: yieldRelease
      interval: 90
      onTriggered: root.releaseYield(yieldMarker.homeWindow, yieldMarker.zone)
    }
  }

  component ModuleList: Item {
    id: moduleListRoot
    property var entries: []
    property var homeWindow: null
    property string region: ""
    property string listRole: region
    readonly property var slotModel: homeWindow ? homeWindow.widgetModels[listRole] : null
    property bool previewEnd: true
    property bool previewAnchorStart: false
    property bool previewAnchorEnd: false
    readonly property bool previewStartGap: previewAnchorStart
    readonly property bool previewEndGap: previewAnchorEnd || (previewEnd && DragModel.endGap(root.dragPreview, "bar:" + region))
    // Where this list draws its zone's drawer handle, as the zone fit says.
    readonly property var fitHandles: homeWindow && homeWindow.zoneFit ? homeWindow.zoneFit.handles : null
    readonly property bool centerStartDots: !!fitHandles && (fitHandles.center === "start" || fitHandles.center === "both")
    readonly property bool centerEndDots: !!fitHandles && (fitHandles.center === "end" || fitHandles.center === "both")
    readonly property bool handleAtStart: !!fitHandles && ((listRole === "right" && fitHandles.right === "start")
      || ((listRole === "before" || listRole === "center") && centerStartDots))
    readonly property bool handleAtEnd: !!fitHandles && ((listRole === "left" && fitHandles.left === "end")
      || ((listRole === "after" || listRole === "center") && centerEndDots))
    width: root.vertical ? Math.max(root.barSize, contents.width) : startGap.width + startHandle.width + contents.width + endHandle.width + endGap.width
    height: root.vertical ? startGap.height + startHandle.height + contents.height + endHandle.height + endGap.height : Math.max(root.barSize, contents.height)
    readonly property real leadSpill: previewStartGap && root.barDragSource ? root.barDragSource.cellSpill
      : leadRun > 0 ? markerPlace.spill
      : startHandle.shown && !startHandle.fitYielded ? startHandle.cellSpill : root.edgeSpill(contents, false)
    readonly property real trailSpill: previewEndGap && root.barDragSource ? root.barDragSource.cellSpill
      : trailRun > 0 ? markerPlace.spill
      : endHandle.shown && !endHandle.fitYielded ? endHandle.cellSpill : root.edgeSpill(contents, true)
    // Yielded slots keep their space, but the island ends at the last one
    // still showing: the length of yielded slots at each end of the list.
    readonly property real yieldLead: yieldRun(false)
    readonly property real yieldTrail: yieldRun(true)
    function yieldRun(last) {
      var kids = [startHandle].concat(Array.prototype.slice.call(contents.children), [endHandle]), total = 0
      for (var n = 0; n < kids.length; n++) {
        var c = kids[last ? kids.length - 1 - n : n]
        var size = c ? (root.vertical ? c.height : c.width) : 0
        if (!c || c.cellSpill === undefined || !(size > 0)) continue
        if (!c.fitYielded) break
        total += size
      }
      return total
    }
    function yieldCount(last) {
      var kids = [startHandle].concat(Array.prototype.slice.call(contents.children), [endHandle]), count = 0
      for (var n = 0; n < kids.length; n++) {
        var c = kids[last ? kids.length - 1 - n : n]
        var size = c ? (root.vertical ? c.height : c.width) : 0
        if (!c || c.cellSpill === undefined || !(size > 0)) continue
        if (!c.fitYielded) break
        // A yielded drawer handle stands for the widgets folded behind it.
        count += c.isFoldHandle === true ? c.count : 1
      }
      return count
    }
    // When the whole list yields, the run faces the moment from one side only:
    // lists that end next to the moment (left, after) yield from their end.
    readonly property real listLength: root.vertical ? height : width
    readonly property bool yieldsFromEnd: listRole === "left" || listRole === "after"
    readonly property bool allYielded: yieldLead > 0 && yieldLead >= listLength - 0.5
    readonly property real leadRun: allYielded && yieldsFromEnd ? 0 : yieldLead
    readonly property real trailRun: allYielded && !yieldsFromEnd ? 0 : yieldTrail
    // The yielded widgets leave a marker (dots and their count) in the first
    // freed cell, next to the widgets still showing; the island ends past it.
    readonly property var markerPlace: CellModel.place(root.cellTokens, CellModel.TYPICAL_GLYPH, true)
    // A zone hidden whole leaves no marker; its island fades where it stands.
    readonly property bool zoneHidden: !!homeWindow && homeWindow.zoneHidden(region)
    readonly property real trimLead: leadRun > 0 && !zoneHidden ? leadRun - markerPlace.extent : 0
    readonly property real trimTrail: trailRun > 0 && !zoneHidden ? trailRun - markerPlace.extent : 0
    // The list's length without them, and the same eased for island ends.
    readonly property real shownLength: listLength - trimLead - trimTrail
    property real shownLead: trimLead
    property real shownTrail: trimTrail
    Behavior on shownLead { enabled: root.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on shownTrail { enabled: root.animationsEnabled; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    AnimatedSlot {
      id: startGap
      targetWidth: root.vertical ? root.barSize : moduleListRoot.previewStartGap ? root.dragGapWidth : 0
      targetHeight: !root.vertical ? root.barSize : moduleListRoot.previewStartGap ? root.dragGapHeight : 0
      DropOutline { bar: root; onDemand: root.barDragLandsOnDemand; gapLength: root.vertical ? parent.height : parent.width }
      motionEnabled: root.animationsEnabled && !root.dragHandover
      motionDuration: root.dragMotionDuration; motionEasing: root.dragMotionEasing
    }
    FoldHandle {
      id: startHandle
      homeWindow: moduleListRoot.homeWindow
      zone: moduleListRoot.region
      side: "start"
      active: moduleListRoot.handleAtStart
      x: root.vertical ? 0 : startGap.width
      y: root.vertical ? startGap.height : 0
    }
    YieldMarker {
      homeWindow: moduleListRoot.homeWindow
      zone: moduleListRoot.region
      count: moduleListRoot.leadRun > 0 && !moduleListRoot.zoneHidden ? moduleListRoot.yieldCount(false) : 0
      readonly property real along: moduleListRoot.leadRun - moduleListRoot.markerPlace.extent
      x: root.vertical ? 0 : along
      y: root.vertical ? along : 0
    }
    YieldMarker {
      homeWindow: moduleListRoot.homeWindow
      zone: moduleListRoot.region
      count: moduleListRoot.trailRun > 0 && !moduleListRoot.zoneHidden ? moduleListRoot.yieldCount(true) : 0
      readonly property real along: moduleListRoot.listLength - moduleListRoot.trailRun
      x: root.vertical ? 0 : along
      y: root.vertical ? along : 0
    }
    FoldHandle {
      id: endHandle
      homeWindow: moduleListRoot.homeWindow
      zone: moduleListRoot.region
      active: moduleListRoot.handleAtEnd
      x: root.vertical ? 0 : contents.x + contents.width
      y: root.vertical ? contents.y + contents.height : 0
    }
    Grid {
      id: contents
      x: root.vertical ? 0 : startGap.width + startHandle.width
      y: root.vertical ? startGap.height + startHandle.height : 0
      // Only columns follows orientation (rows stays automatic), so a switch
      // never passes through a 1 × 1 grid.
      columns: root.vertical ? 1 : 100000
      spacing: 0
      Repeater { model: moduleListRoot.slotModel }
    }
    AnimatedSlot {
      id: endGap
      x: root.vertical ? 0 : endHandle.x + endHandle.width
      y: root.vertical ? endHandle.y + endHandle.height : 0
      targetWidth: root.vertical ? root.barSize : moduleListRoot.previewEndGap ? root.dragGapWidth : 0
      targetHeight: !root.vertical ? root.barSize : moduleListRoot.previewEndGap ? root.dragGapHeight : 0
      DropOutline { bar: root; onDemand: root.barDragLandsOnDemand; gapLength: root.vertical ? parent.height : parent.width }
      motionEnabled: root.animationsEnabled && !root.dragHandover
      motionDuration: root.dragMotionDuration; motionEasing: root.dragMotionEasing
    }
  }

  component ModuleSlot: AnimatedSlot {
    id: slot

    required property var record
    readonly property bool powerbarRetainedSlot: true
    readonly property var entry: record.entry
    property var homeWindow: null
    readonly property string region: record.region
    property bool centerAnchorSlot: false
    // The side of the centre's anchor it sits on, and so the dots it waits behind.
    property string centerSide: "end"
    // The expansion that shows it in inline mode: its zone, the centre by side.
    readonly property string inlineToken: region === "center" ? "center:" + centerSide : region
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    readonly property bool groupHeader: !!(entry && entry.powerbarGroupId)
    readonly property var groupConfig: groupHeader ? root.groupIndexes.byId[entry.powerbarGroupId] || null : null
    readonly property string customType: groupHeader ? "group" : root.customModuleType(entry)
    readonly property var registryMetadata: root.barWidgetRegistry.metadataFor(root.canonicalWidgetId(moduleName))
    readonly property bool firstParty: registryMetadata && registryMetadata.firstParty === true
    readonly property string pluginApiId: registered ? root.canonicalWidgetId(moduleName) : "bar-entry:" + moduleName
    // Re-evaluate when the registry mutates (Component reference changes,
    // plugin enabled/disabled, etc.). Reading the `widgets` property creates
    // the binding dependency — the wrapped function call alone wouldn't.
    readonly property var registryComponent: {
      var w = root.barWidgetRegistry.widgets
      if (customType) return null
      var registryName = root.canonicalWidgetId(moduleName)
      return repairItem.componentFor(registryName, w[registryName] ? w[registryName].component : null)
    }
    readonly property bool qmlCustom: customType === "qml"
    readonly property bool commandCustom: customType === "command"
    readonly property bool registered: registryComponent !== null
    readonly property var activeItem: {
      if (registered) return registryLoader.item
      if (qmlCustom) return qmlLoader.item
      return componentLoader.item
    }
    readonly property bool hovered: drawerHost ? moduleHover.hovered : slotHover.hovered
    readonly property bool dragSource: root.barDragSource === slot
    // The released image is still gliding into this slot.
    readonly property bool settleHidden: root.slotSettleHidden(slot)
    readonly property bool panelOpen: root.activePopout === slot.activeItem
    readonly property bool drawerOpen: groupHeader && !!root.managedOwner && root.managedOwner.opened
      && root.managedOwner.groupId === entry.powerbarGroupId && root.managedOwner.anchorSlot === slot
    readonly property string instanceKey: record.key
    readonly property var preview: DragModel.slot(root.dragPreview, instanceKey, "bar:" + region)
    readonly property var memberGroup: groupHeader ? null : root.groupFor(instanceKey)
    readonly property var badgeInfo: memberGroup && memberGroup.badge ? GroupBadgeModel.sample(activeItem,
      entry && entry.powerbarBadgeProperty || "", entry && entry.powerbarUrgentProperty || "") : ({ count: 0, urgent: false })
    readonly property string visibilityMode: ManagedModel.mode(entry, registryMetadata || (customType ? { firstParty: false } : null), root.legacyVisibility)
    readonly property bool managed: visibilityMode === "managed"
    readonly property bool alwaysShown: visibilityMode === "shown"
    property var slotTargets: []
    property var drawerHost: null
    property alias presentationItem: presentation
    property alias highlightItem: barHighlight
    property bool activityVisible: false
    property real activityUntil: 0
    // Visible on the bar by its own rules, before the zone fit.
    // Shown in the bar by an inline expansion of its zone.
    readonly property bool inlineShown: managed && !!homeWindow && homeWindow.inlineZone !== "" && homeWindow.inlineZone === inlineToken
    readonly property bool baseVisible: !memberGroup && (alwaysShown || (managed && !drawerHost && (activityVisible || panelOpen || hovered || inlineShown)))
    // Waits behind its zone's dots in inline mode.
    readonly property bool inlineCandidate: root.onDemandInline && managed && !memberGroup && !baseVisible
    readonly property bool fitFolded: !!(homeWindow && homeWindow.zoneFitFolded[instanceKey])
    readonly property bool fitYielded: !!(homeWindow && homeWindow.zoneFitYielded[instanceKey])
    readonly property bool mainVisible: baseVisible && !fitFolded && !fitYielded
    // Fades only for zone-fit changes: a yield or fold fades the widget out
    // fast; a yielded widget comes back after the moment's zone has shrunk.
    // The flag stays up while yielded or folded, so the return fades too.
    property bool fitMotion: false
    onFitYieldedChanged: { fitMotion = true; fitMotionEnd.restart() }
    onFitFoldedChanged: { fitMotion = true; fitMotionEnd.restart() }
    Timer { id: fitMotionEnd; interval: 400; onTriggered: if (!slot.fitYielded && !slot.fitFolded) slot.fitMotion = false }
    readonly property var activityTargets: {
      var result = root.targetsForSlot(slot).slice()
      if (activeItem && result.indexOf(activeItem) < 0) result.unshift(activeItem)
      return result
    }
    function syncActivity() {
      activityExpiry.stop()
      var remaining = ManagedModel.remaining(activityUntil, Date.now())
      activityVisible = managed && remaining > 0
      if (activityVisible) { activityExpiry.interval = Math.max(1, remaining); activityExpiry.start() }
    }
    onActivityUntilChanged: syncActivity()
    // The run it draws in depends on its visibility, too.
    onManagedChanged: {
      syncActivity()
      if (homeWindow) Qt.callLater(homeWindow.reconcileWidgets)
    }
    Timer { id: activityExpiry; repeat: false; onTriggered: slot.activityVisible = false }
    // Highlighted like a hover while an autohidden bar shows it for activity.
    property bool activityFlash: false
    function flashActivity() { activityFlash = true; flashEnd.restart() }
    Timer { id: flashEnd; interval: root.autoHidePeekMs; onTriggered: slot.activityFlash = false }
    // One identity token per target rather than the targets themselves: a
    // Repeater over QObjects exposes all their properties as roles. It still
    // rebuilds exactly when the targets change; each observer reads its target
    // once from the plain table.
    readonly property var activityMounted: ({ list: [] })
    readonly property var activityTokens: {
      var list = activityTargets
      activityMounted.list = list
      return list.map(function(target) { return String(target) })
    }
    Repeater {
      model: slot.activityTokens
      ActivityObserver {
        required property int index
        target: slot.activityMounted.list[index]
        readonly property bool reveals: slot.managed || !!(slot.memberGroup && slot.memberGroup.visibility === "managed")
        enabledForActivity: reveals || (root.autoHide && root.autoHideActivity && root.activityPeeksFor(slot.instanceKey, slot.moduleName))
        onActivity: {
          if (root.reconcilingStructure) return
          if (reveals) root.reportActivity(slot.instanceKey)
          root.autoHidePeek(slot)
        }
      }
    }
    readonly property string displayName: BarModel.widgetName(registryMetadata, moduleName)
      || String(moduleName).split(".").pop()
    // A widget that hid itself (the update widget with nothing pending) still
    // has its own button; its placeholder presses that, as a click on the
    // widget would, before falling back to Preferences.
    function hiddenPrimaryTarget() {
      return root.targetsForSlot(slot).find(function(target) {
        return target && typeof target.triggerPress === "function" && target.interactive !== false
          && target.pressable !== false && target.concealed !== true
      }) || null
    }
    function canActivate() {
      if (root.targetsForSlot(slot).some(function(target) { return root.moduleTargetClickable(target) })) return true
      if (activeItem && (typeof activeItem.toggle === "function" || typeof activeItem.open === "function")) return true
      return !!hiddenPrimaryTarget()
    }
    function activate() {
      var targets = root.targetsForSlot(slot)
      for (var target of targets) {
        if (root.moduleTargetClickable(target)) { target.triggerPress(Qt.LeftButton); return true }
      }
      if (activeItem && typeof activeItem.toggle === "function") { activeItem.toggle(); return true }
      if (activeItem && typeof activeItem.open === "function") { activeItem.open(); return true }
      var hidden = hiddenPrimaryTarget()
      if (hidden) { hidden.triggerPress(Qt.LeftButton); return true }
      return false
    }
    // An empty widget hides itself as on Omarchy's bar unless the user placed
    // it (ManagedModel.placeholder); then a fallback icon keeps its place.
    readonly property bool needsPlaceholder: ManagedModel.placeholder(entry, visibilityMode) && (!activeItem || !activeItem.visible || activeItem.opacity === 0 || activeItem.implicitWidth <= 0 || activeItem.implicitHeight <= 0)
    // The widget's own box; drawers and drag images use it as is.
    readonly property real liveNaturalWidth: needsPlaceholder ? root.barSize : activeItem && activeItem.visible ? (root.vertical ? root.barSize : activeItem.implicitWidth) : 0
    readonly property real liveNaturalHeight: needsPlaceholder ? root.barSize : activeItem && activeItem.visible ? activeItem.implicitHeight : 0
    // While the bar window is hidden to remap (a blur change, a screen move),
    // every widget reads as invisible and would measure as an empty
    // placeholder. The window freezes its slots just before it hides: they
    // keep the last real measurements until the widgets are back, so nothing
    // resizes or animates around the remap.
    readonly property bool measureFrozen: !!homeWindow && homeWindow.layoutFrozen === true
    property var frozenMeasure: null
    onMeasureFrozenChanged: {
      frozenMeasure = measureFrozen ? { width: liveNaturalWidth, height: liveNaturalHeight, ink: liveInk, crossInk: liveCrossInk } : null
      if (!measureFrozen) Qt.callLater(updateHold)
    }
    readonly property real naturalWidth: frozenMeasure ? frozenMeasure.width : liveNaturalWidth
    readonly property real naturalHeight: frozenMeasure ? frozenMeasure.height : liveNaturalHeight
    // The cell: what the widget visibly paints along the bar decides its slot
    // and its highlight, never the box it asks for.
    readonly property Item inkItem: needsPlaceholder ? placeholderButton : activeItem
    // The last result of each measurement below. A value change re-lays the
    // label out in several steps, each re-running the chain; a step that
    // measures what the last one did returns the same object, so nothing
    // downstream (the cell, the hold, the zone fit) runs again for it. Same
    // values in the same frame: only the repeats are skipped.
    readonly property var measureKept: ({})
    function kept(name, next) {
      var last = measureKept[name]
      if (last === next || RenderModel.shallowSame(last, next)) return last
      measureKept[name] = next
      return next
    }
    readonly property var measuredInk: kept("measured", liveNaturalWidth > 0 && liveNaturalHeight > 0 && inkItem
      ? HighlightModel.inkRect(inkItem, root.vertical) : ({ start: 0, length: 0, glyph: false }))
    // When one kit button is the widget's whole content, measure the text it
    // actually paints: its exact font, its tight glyph bounds and where the
    // text sits. Kit hints give only a width and assume a centred glyph, but
    // icon-font glyphs often overhang their advance box (the speaker is 14 px of
    // ink in a 7.2 px box, so a text button paints it 3.4 px right of centre).
    readonly property Item kitGlyph: inkItem && liveNaturalWidth > 0 ? root.findKitGlyph(inkItem, 0) : null
    readonly property Item glyphText: kitGlyph ? root.findGlyphText(kitGlyph, String(kitGlyph.text), 0) : null
    TextMetrics {
      id: kitGlyphMetrics
      font: slot.glyphText ? slot.glyphText.font : Qt.font({ family: Style.font.family })
      text: slot.glyphText ? slot.glyphText.text : ""
    }
    readonly property var glyphInk: {
      var t = glyphText
      // TextMetrics measures one line; a stacked label (Scratchpeek's "◌" over
      // its count on a vertical bar) is measured from what it paints instead.
      if (!t || !inkItem || t.text === "" || String(t.text).indexOf("\n") >= 0 || Math.abs(Number(t.rotation) % 180) === 90) return null
      var r = kitGlyphMetrics.tightBoundingRect
      if (!(r.width > 0) || !(r.height > 0)) return null
      var geometry = t.x + t.y + t.width + t.height + inkItem.width + inkItem.height
      // Qt aligns a line by its advance, while contentWidth also counts the
      // overhang, so a centred icon-font glyph is drawn (width − advance) / 2 in.
      var advance = kitGlyphMetrics.advanceWidth
      var align = t.horizontalAlignment === Text.AlignHCenter ? (t.width - advance) / 2
        : t.horizontalAlignment === Text.AlignRight ? t.width - advance : 0
      var p = t.mapToItem(inkItem, align + r.x, t.baselineOffset + r.y)
      return kept("glyph", { x: p.x, y: p.y, width: r.width, height: r.height })
    }
    readonly property var liveInk: !glyphInk ? measuredInk : kept("live", root.vertical
      ? { start: glyphInk.y, length: glyphInk.height, glyph: measuredInk.glyph || glyphInk.width <= CellModel.GLYPH_INK }
      : { start: glyphInk.x, length: glyphInk.width, glyph: glyphInk.width <= CellModel.GLYPH_INK })
    readonly property var liveCrossInk: !root.vertical || liveNaturalWidth <= 0 || !inkItem ? null
      : kept("cross", glyphInk ? { start: glyphInk.x, length: glyphInk.width, glyph: glyphInk.width <= CellModel.GLYPH_INK }
      : HighlightModel.inkRect(inkItem, false))
    readonly property var ink: frozenMeasure ? frozenMeasure.ink : liveInk
    readonly property var crossInk: frozenMeasure ? frozenMeasure.crossInk : liveCrossInk
    // Only free text is capped: a compound (workspaces) or a vertical stack keeps its length.
    readonly property var cellPlace: kept("place", CellModel.place(root.cellTokens, ink.length, CellModel.isGlyph(ink.length, ink.glyph),
      !root.vertical && compoundTargets.length < 2))
    readonly property real landingExtent: naturalWidth > 0 && naturalHeight > 0 ? cellPlace.extent : 0
    // A value that gets narrower keeps its width for a while, so flickering
    // values never make the bar breathe; it grows at once.
    property real heldExtent: 0
    property real shrinkAt: 0
    // The hold starts once the widget has settled, so its first measurements
    // while loading are never held.
    property bool holdArmed: false
    Timer { interval: 2000; running: true; onTriggered: slot.holdArmed = true }
    // The hold is for a value changing in place, not for a new layout: a
    // retained slot that changes orientation, bar size or spacing starts fresh.
    readonly property string holdLayout: root.vertical + "|" + root.barSize + "|" + root.spacingMode + "|" + root.widgetSpacing
    property string heldLayout: ""
    onHoldLayoutChanged: Qt.callLater(updateHold)
    // The hold also waits out a remap freeze (measureFrozen).
    function updateHold() {
      if (!root || measureFrozen) return
      var target = landingExtent
      var relayout = heldLayout !== holdLayout
      heldLayout = holdLayout
      // A widget that animates its own width (the tray's reveal) opts out:
      // holding would leave its island wide after it closes.
      var holds = !(activeItem && activeItem.powerbarWidthHold === false)
      if (!(target > 0) || !baseVisible || !holdArmed || relayout || !holds) { heldExtent = target; shrinkAt = 0; holdTimer.stop(); return }
      var now = Date.now()
      var h = CellModel.hold(heldExtent, target, now, root.widthHoldMs, shrinkAt, root.cellTokens.cell)
      heldExtent = h.value
      shrinkAt = h.shrinkAt
      if (shrinkAt > 0) { holdTimer.interval = Math.max(1, shrinkAt - now); holdTimer.restart() } else holdTimer.stop()
    }
    // Deferred: a widget's size can change while its cell is being measured.
    onLandingExtentChanged: Qt.callLater(updateHold)
    onBaseVisibleChanged: Qt.callLater(updateHold)
    Timer { id: holdTimer; repeat: false; onTriggered: slot.updateHold() }
    readonly property real heldPad: Math.max(0, heldExtent - landingExtent)
    readonly property real cellExtent: landingExtent > 0 ? landingExtent + heldPad : 0
    readonly property real cellLength: cellPlace.cell + heldPad
    readonly property real cellSpill: cellPlace.spill + heldPad / 2
    // Along the bar the ink centres in its cell; across a vertical bar it
    // centres on the bar's centre line, whatever box the widget laid out.
    readonly property real inkShift: cellPlace.inkStart + heldPad / 2 - ink.start
    readonly property real crossShift: crossInk && crossInk.length > 0 ? naturalWidth / 2 - (crossInk.start + crossInk.length / 2) : 0
    readonly property var compoundTargets: {
      var targets = activeItem ? root.targetsForSlot(slot) : []
      return targets.length > 1 ? targets : []
    }
    // While settling, the committed slot keeps the extent of the drop gap it
    // replaces, then eases to its own size so neighbours never step.
    readonly property real settleExtraWidth: settleHidden && !centerAnchorSlot
      ? Math.max(0, root.dragGapWidth - cellExtent) : 0
    readonly property real settleExtraHeight: settleHidden && !centerAnchorSlot
      ? Math.max(0, root.dragGapHeight - cellExtent) : 0
    // The slot's length along the bar by its own rules: the zone fit's input,
    // so it never depends on the fit's result. A folded slot takes no space;
    // a yielded one keeps its space.
    readonly property real fitExtent: baseVisible && (!preview.hidden || preview.holdSpace)
      ? cellExtent + (root.vertical ? settleExtraHeight : settleExtraWidth)
        + (!centerAnchorSlot && (preview.before || preview.after) ? (root.vertical ? root.dragGapHeight : root.dragGapWidth) : 0) : 0
    readonly property real layoutExtent: fitFolded ? 0 : fitExtent
    targetWidth: root.vertical ? naturalWidth : layoutExtent
    // Across a horizontal bar every slot is at least the bar's thickness and the
    // widget's box is centred in it, so a widget shorter than the bar (the Agent
    // Orchestrator reports 27 px on a 38 px bar) never sits at the top.
    readonly property real crossLength: naturalHeight > 0 ? Math.max(naturalHeight, root.barSize) : 0
    readonly property real crossCentre: (crossLength - naturalHeight) / 2
    targetHeight: !root.vertical ? crossLength : layoutExtent
    targetInsetX: !root.vertical && !centerAnchorSlot && preview.before ? root.dragGapWidth : 0
    targetInsetY: root.vertical && !centerAnchorSlot && preview.before ? root.dragGapHeight : 0
    motionEnabled: root.animationsEnabled && !drawerHost && !root.dragHandover
    motionDuration: root.dragMotionActive ? root.dragMotionDuration : 120
    // An activity reveal opens after its neighbours have yielded (80 ms).
    motionDelay: root.animationsEnabled && managed && (activityVisible || inlineShown) && !hovered && !root.dragMotionActive ? 80 : 0
    motionEasing: root.dragMotionActive ? root.dragMotionEasing : Easing.OutCubic
    motionOvershoot: 0
    z: modulePointer.dragging ? 100 : 0

    // The whole slot, gutters included, is the widget's hover area on the bar.
    readonly property bool stopHovered: slotHover.hovered
    HoverHandler {
      id: slotHover
      enabled: slot.mainVisible && !root.barHidden && !preferencesPane.opened && !root.barDragSource
      onHoveredChanged: {
        var window = root.targetWindow(slot)
        if (!window || !window.managedDrawer) return
        // Another stop than the open drawer's source: it gives way first, so
        // the highlight and tooltip that follow never share the bar with it.
        if (hovered) window.managedDrawer.pointerOnStop(slot)
        if (hovered && slot.groupHeader) window.managedDrawer.sourceEnterGroup(slot.entry.powerbarGroupId, slot)
        // Inline mode: only the dots expand a zone; moving on to another zone
        // collapses the expanded one at once, as a drawer would switch.
        else if (root.onDemandInline && !slot.groupHeader) {
          var asked = (window.inlineZone || window.inlineRequest).split(":")[0]
          if (hovered && asked && asked !== slot.region && !root.barDragSource) window.inlineAsk("")
        }
        else if (hovered) window.managedDrawer.sourceEnter(slot.region)
        else window.managedDrawer.sourceLeave(slot.region)
      }
    }

    Component.onCompleted: { root.registerModuleSlot(slot); syncActivity(); Qt.callLater(updateHold) }
    Component.onDestruction: {
      if (root.barDragSource === slot) root.clearBarDrag()
      root.forgetSlotTargets(slot)
      root.unregisterModuleSlot(slot)
    }

    DropOutline {
      bar: root
      onDemand: root.barDragLandsOnDemand
      readonly property real slotLength: root.vertical ? slot.height : slot.width
      readonly property real insetLength: root.vertical ? slot.animatedInsetY : slot.animatedInsetX
      readonly property bool open: !slot.drawerHost && slot.mainVisible && (slot.preview.before || slot.preview.after)
      gapStart: slot.preview.before ? 0 : slot.cellExtent + (root.vertical ? slot.settleExtraHeight : slot.settleExtraWidth)
      gapLength: !open ? 0 : slot.preview.before ? insetLength : Math.max(0, slotLength - gapStart)
    }

    Item {
      id: presentation
      property var powerbarSlotOwner: slot
      parent: slot.drawerHost || slot
      // A widget off the bar (yielded to a moment, folded, waiting behind its
      // dots) keeps its box where the bar used to put it, and Qt still hovers
      // disabled and transparent items: it would take the pointer from
      // whatever now sits there (the centre's dots) and show its own tooltip.
      // Once faded out it is parked far away. Not hidden: a widget's
      // visibility can change its own size, which the zone fit reads.
      readonly property bool parked: !slot.drawerHost && !slot.mainVisible && opacity === 0
      x: parked ? -100000 : slot.drawerHost ? slot.drawerHost.contentOffsetX : slot.animatedInsetX + (root.vertical ? slot.crossShift : slot.inkShift)
      y: slot.drawerHost ? slot.drawerHost.contentOffsetY : slot.animatedInsetY + (root.vertical ? slot.inkShift : slot.crossCentre)
      width: slot.naturalWidth
      height: slot.naturalHeight
      opacity: slot.drawerHost ? (slot.drawerHost.showNative === false ? 0 : 1) : slot.mainVisible && !slot.preview.hidden && !slot.settleHidden ? 1 : 0
      Behavior on opacity {
        enabled: root.animationsEnabled && !slot.drawerHost && (slot.fitMotion || slot.fitYielded || slot.fitFolded)
        YieldFade { leaving: slot.fitYielded || slot.fitFolded; outMs: slot.fitYielded ? 80 : 110 }
      }
      enabled: !!slot.drawerHost || slot.mainVisible
    DragHandler {
      id: drawerDrag
      target: null
      enabled: !!slot.drawerHost && slot.drawerHost.showNative !== false
      acceptedButtons: Qt.LeftButton
      property point lastScene
      // The drawer row hosting this widget, held for the drag (ManagedDrawer.dragMount).
      property Item heldMount: null
      onCentroidChanged: if (active) { lastScene = centroid.scenePosition; root.updateIconDrag(lastScene, slot) }
      onActiveChanged: {
        if (active) {
          lastScene = centroid.scenePosition
          heldMount = slot.drawerHost
          if (heldMount && heldMount.hostDrawer) heldMount.hostDrawer.dragMount = heldMount
          if (!root.beginIconDrag(slot, root.targetWindow(slot), lastScene,
              (presentation.x + centroid.position.x),
              (presentation.y + centroid.position.y))) releaseMount()
        } else {
          if (root.barDragSource === slot) root.finishIconDrag(lastScene, slot)
          releaseMount()
        }
      }
      function releaseMount() {
        var mount = heldMount
        heldMount = null
        if (mount && mount.hostDrawer) mount.hostDrawer.releaseDrag(mount)
      }
    }
    HoverHandler { id: moduleHover }

    WidgetButton {
      id: placeholderButton
      property bool powerbarPlaceholder: true
      visible: slot.needsPlaceholder
      anchors.fill: parent
      bar: root
      text: PreferencesModel.icon(slot.moduleName)
      // Only while it shows: canActivate() reads the widget's targets, which
      // change with every opacity step of a widget that is drawn.
      tooltipText: !slot.needsPlaceholder ? "" : slot.displayName + " is inactive. " + (slot.canActivate() ? "Click to open it." : "Click to set it up.")
      onPressed: {
        if (!slot.activate()) preferencesPane.show(root.targetWindow(slot).screen)
      }
    }

    Loader {
      id: componentLoader
      active: !slot.qmlCustom && !slot.registered
      sourceComponent: slot.groupHeader ? groupButtonComponent : slot.commandCustom ? customCommandModuleComponent : emptyModuleComponent
      anchors.fill: parent
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: registryLoader
      active: slot.registered
      sourceComponent: slot.registered ? slot.registryComponent : null
      anchors.fill: parent
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: qmlLoader
      active: slot.qmlCustom
      source: slot.qmlCustom ? root.customModuleSource(slot.entry) : ""
      anchors.fill: parent
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    }
    // Hover, activity and an open panel share one highlight: the slot's cell,
    // centred on the slot, one inset from the bar's edges, one nested radius.
    // It is drawn in the zone's highlight layer, beneath the widgets. The layer
    // moves with its zone, so the highlight re-places only when geometry
    // changes, never per frame.
    // The keyboard cursor: the slot's highlight plus the accent ring the
    // drawer's keyboard cursor draws; it never animates.
    readonly property bool keysCursor: root.barKeys.here && root.barKeys.cursor === slot && !slot.drawerHost
      && !(root.barKeys.drawer && !root.barKeys.previewing)
    Rectangle {
      parent: barHighlight.parent
      x: barHighlight.x; y: barHighlight.y; width: barHighlight.width; height: barHighlight.height
      radius: barHighlight.radius
      z: 3
      visible: slot.keysCursor && slot.mainVisible
      color: "transparent"
      border.width: 1.5
      border.color: Color.accent
    }
    HoverHighlight {
      id: barHighlight
      readonly property var hostWindow: root.targetWindow(slot)
      readonly property Item hostLayer: hostWindow && hostWindow.highlightLayers ? hostWindow.highlightLayers[slot.region] || null : null
      parent: hostLayer || presentation
      hovered: (slot.hovered || slot.activityFlash || slot.preview.into || slot.keysCursor) && slot.mainVisible && !slot.dragSource && !root.barHidden && !preferencesPane.opened
      // A group icon shows the open fill while its drawer is open.
      selected: (slot.panelOpen || slot.drawerOpen) && !slot.dragSource
      motionEnabled: root.animationsEnabled
      hoverColor: slot.compoundTargets.length > 1 && !slot.activityFlash ? root.highlightTrackColor : root.highlightHoverColor
      selectedColor: root.highlightSelectedColor
      readonly property Item island: hostWindow && hostWindow.zoneIslands ? hostWindow.zoneIslands[slot.region] || null : null
      older: shown && root.spacingMode === "gaps" && (hostWindow && hostWindow.moduleItems || []).some(function(other) {
        var h = other && other.highlightItem
        if (!h || h === barHighlight || !h.shown || h.parent !== barHighlight.parent || h.litAt <= barHighlight.litAt) return false
        return Math.min(x + width, h.x + h.width) > Math.max(x, h.x) && Math.min(y + height, h.y + h.height) > Math.max(y, h.y)
      })
      onShownChanged: {
        if (shown) litAt = ++root.highlightClock
        place()
      }
      function place() {
        var host = barHighlight.parent
        if (!host || slot.width <= 0 || slot.height <= 0) return
        var g = root.cellHighlight(slot, host, barHighlight.hostLayer || host, slot.cellLength)
        x = g.x; y = g.y; width = g.width; height = g.height; rounding = g.radius
      }
      GeometryObserver {
        target: barHighlight.shown ? slot : null
        host: barHighlight.parent
        onChanged: Qt.callLater(barHighlight.place)
      }
      Connections {
        target: barHighlight.shown ? root : null
        function onCellTokensChanged() { Qt.callLater(barHighlight.place) }
        function onHighlightRadiusChanged() { Qt.callLater(barHighlight.place) }
      }
    }

    // The thumb over the hovered target of a compound, nested at the track's
    // curve: side min(T, pitch − 1).
    Rectangle {
      id: compoundThumb
      readonly property var targets: slot.compoundTargets
      property int metricsRevision: 0
      function refreshCentres() { metricsRevision++ }
      readonly property var centres: {
        var revision = metricsRevision
        if (!barHighlight.hovered || barHighlight.selected || slot.activityFlash) return []
        var along = root.vertical ? slot.height : slot.width
        return targets.map(function(t) {
          var p = t.mapToItem(slot, t.width / 2, t.height / 2)
          return root.vertical ? p.y : p.x
        }).filter(function(c) { return c >= 0 && c <= along })
      }
      readonly property real pitch: {
        var d = []
        for (var n = 1; n < centres.length; n++) d.push(Math.abs(centres[n] - centres[n - 1]))
        d.sort(function(a, b) { return a - b })
        return d.length ? d[Math.floor(d.length / 2)] : root.cellTokens.thickness
      }
      readonly property var geometry: CellModel.thumb(root.cellTokens, pitch, root.islandRounding)
      readonly property real pointer: root.vertical ? slotHover.point.position.y : slotHover.point.position.x
      readonly property int index: {
        var best = -1, distance = Infinity
        for (var n = 0; n < centres.length; n++) {
          var d = Math.abs(centres[n] - pointer)
          if (d < distance) { distance = d; best = n }
        }
        return best
      }
      parent: barHighlight.hostLayer || slot
      visible: centres.length > 1 && index >= 0 && barHighlight.hovered && !barHighlight.selected && !slot.activityFlash
      width: geometry.side
      height: geometry.side
      radius: geometry.radius
      color: root.highlightHoverColor
      z: 1
      Accessible.ignored: true
      onVisibleChanged: place()
      onIndexChanged: place()
      onCentresChanged: Qt.callLater(place)
      // Identity tokens, as for the activity observers above.
      readonly property var mounted: ({ list: [] })
      readonly property var targetTokens: {
        var list = targets
        mounted.list = list
        return list.map(function(target) { return String(target) })
      }
      Repeater {
        model: barHighlight.hovered && !barHighlight.selected && !slot.activityFlash ? compoundThumb.targetTokens : []
        GeometryObserver {
          required property int index
          target: compoundThumb.mounted.list[index]
          host: slot
          onChanged: Qt.callLater(compoundThumb.refreshCentres)
        }
      }
      function place() {
        var layer = compoundThumb.parent
        if (!visible || !layer || index < 0) return
        var o = slot.mapToItem(layer, 0, 0)
        var strip = barHighlight.hostLayer || layer
        var s = strip.mapToItem(layer, 0, 0)
        var along = (root.vertical ? o.y : o.x) + centres[index] - width / 2
        var cross = root.vertical ? s.x + (strip.width - width) / 2 : s.y + (strip.height - height) / 2
        x = root.vertical ? cross : along
        y = root.vertical ? along : cross
      }
      GeometryObserver {
        target: compoundThumb.visible ? slot : null
        host: compoundThumb.parent
        onChanged: Qt.callLater(compoundThumb.place)
      }
      Connections {
        target: compoundThumb.visible ? root : null
        function onCellTokensChanged() { Qt.callLater(compoundThumb.place) }
        function onHighlightRadiusChanged() { Qt.callLater(compoundThumb.place) }
      }
    }

    // A group's count rides its cell's top-right corner at 45° and stays 1 px
    // inside the island, drawn in the highlight layer so the slot's clip never
    // cuts it.
    Rectangle {
      id: cellBadge
      readonly property var info: slot.groupHeader && slot.activeItem && slot.activeItem.badge ? slot.activeItem.badge : null
      parent: barHighlight.hostLayer || slot
      visible: !!info && !!slot.groupConfig && !!slot.groupConfig.badge && info.count > 0
        && slot.mainVisible && slot.width > 0 && slot.height > 0 && !slot.preview.hidden && !slot.dragSource
      width: Math.max(Style.space(12), cellBadgeLabel.implicitWidth + Style.space(5))
      height: Style.space(12)
      radius: height / 2
      z: 8
      color: info && info.urgent ? Color.urgent : Color.accent
      Accessible.ignored: true
      onVisibleChanged: place()
      onWidthChanged: place()
      function place() {
        var layer = cellBadge.parent
        if (!visible || !layer || slot.width <= 0 || slot.height <= 0) return
        var g = root.cellHighlight(slot, layer, barHighlight.hostLayer || layer, slot.cellLength)
        var isl = barHighlight.island
        var m = root.islands && isl && isl.visible ? isl.mapToItem(layer, 0, 0) : null
        var r = m ? { x: m.x, y: m.y, width: isl.width, height: isl.height }
          : { x: 0, y: 0, width: layer.width, height: layer.height }
        var p = CellModel.badge({ x: g.x - r.x, y: g.y - r.y, width: g.width, height: g.height, radius: g.radius },
          { width: r.width, height: r.height }, { width: width, height: height })
        x = r.x + p.x
        y = r.y + p.y
      }
      GeometryObserver {
        target: cellBadge.visible ? barHighlight.island : null
        host: cellBadge.parent
        onChanged: Qt.callLater(cellBadge.place)
      }
      GeometryObserver {
        target: cellBadge.visible ? slot : null
        host: cellBadge.parent
        onChanged: Qt.callLater(cellBadge.place)
      }
      Connections {
        target: cellBadge.visible ? root : null
        function onCellTokensChanged() { Qt.callLater(cellBadge.place) }
        function onHighlightRadiusChanged() { Qt.callLater(cellBadge.place) }
      }
      Text {
        id: cellBadgeLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: !cellBadge.info ? "" : cellBadge.info.count > 99 ? "99+" : String(cellBadge.info.count)
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      id: modulePointer

      property bool dragging: false
      property bool suppressClick: false
      property real pressedX: 0
      property real pressedY: 0
      readonly property bool canReorder: root.canWriteConfig()
      readonly property real dragThreshold: Style.space(4)

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      enabled: root.barDragSource === slot || (slot.mainVisible && slot.visible && slot.width > 0 && slot.height > 0)
      propagateComposedEvents: true
      // Hit-testing scans every click target, so it runs only while the
      // pointer is over the slot: elsewhere the shape is never shown. The
      // slot's own hover gives the position (this area is not hover-enabled,
      // so mouseX only follows a press). No hover handler on this area: it
      // sits above the widget and would keep the pointer from the widget's
      // own buttons (their hover state and tooltips).
      cursorShape: dragging ? Qt.ClosedHandCursor
        : !slotHover.hovered && !pressed ? Qt.ArrowCursor
        : root.moduleClickTargetAt(slot, pressed ? mouseX : slotHover.point.position.x, pressed ? mouseY : slotHover.point.position.y)
          ? Qt.PointingHandCursor : Qt.ArrowCursor
      // Do not assign drag.target here: ModuleSlot is owned by Row/Column
      // positioners, and mutating slot.x/slot.y can leave stale offsets that
      // make neighboring modules overlap after a small aborted drag.

      onPressed: function(mouse) {
        dragging = false
        suppressClick = false
        pressedX = mouse.x
        pressedY = mouse.y
        root.clearBarDrag()
      }

      onPositionChanged: function(mouse) {
        if (!canReorder || !(mouse.buttons & Qt.LeftButton)) return

        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance >= dragThreshold) {
          if (!dragging) {
            var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
            // The ghost is the widget's own box, which sits shifted inside its cell.
            dragging = root.beginIconDrag(slot, root.targetWindow(slot), scenePoint,
              (pressedX - presentation.x), (pressedY - presentation.y))
          }
        }

        if (dragging) {
          var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
          root.updateIconDrag(scenePoint, slot)
        }
      }

      onReleased: function(mouse) {
        var wasDragging = dragging

        if (wasDragging) suppressClick = true

        dragging = false

        if (wasDragging) {
          root.finishIconDrag(slot.mapToItem(null, mouse.x, mouse.y), slot)
          mouse.accepted = true
        } else if (!wasDragging) {
          mouse.accepted = false
        }
      }

      onCanceled: {
        dragging = false
        suppressClick = false
        if (root.barDragSource === slot) root.clearBarDrag()
      }

      onClicked: function(mouse) {
        if (suppressClick) {
          suppressClick = false
          mouse.accepted = true
          return
        }

        if (slot.drawerHost) slot.activate()
        else if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
      }
    }

    onPluginApiIdChanged: Qt.callLater(root.prunePluginBarApis)
    onActiveItemChanged: {
      Qt.callLater(injectProps)
      if (!groupHeader && activeItem) root.widgetLoaded(instanceKey)
    }
    onModuleSettingsChanged: injectProps()

    function injectProps() {
      // A queued injection can outlive its slot during a layout/plugin reload.
      if (!root || groupHeader) return
      var target = activeItem
      if (!target) return
      if ("bar" in target) target.bar = firstParty
        ? root : root.pluginBarApiFor(pluginApiId, moduleName, registered)
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
    }

    Component {
      id: groupButtonComponent
      WidgetButton {
        id: groupButton
        bar: root
        readonly property var group: slot.groupConfig
        readonly property string preferredFace: group ? group.face : "glyph"
        // A side bar has no room for a name across it: groups show their icon
        // there, and their name on hover.
        readonly property bool nameHidden: root.vertical && preferredFace !== "glyph"
        readonly property string face: nameHidden ? "glyph" : preferredFace
        readonly property var badge: group ? root.groupBadge(group.id, root.targetWindow(slot)) : ({ count: 0, urgent: false })
        // Your own image, or an icon in another font beside the name, is
        // drawn as runs (GroupFace); everything else is the kit's one string.
        readonly property bool runs: !!group && GroupsModel.needsRuns(group, face)
        text: runs ? "" : !group ? "󰉋" : face === "text" ? group.label
          : face === "both" ? group.icon + "  " + group.label : group.icon
        fontFamily: face === "glyph" ? (GroupsModel.groupIconFont(group) || Style.font.family) : Style.font.family
        hasVisualContent: runs || text !== ""
        fixedWidth: runs && !root.vertical ? faceRuns.implicitWidth + scaledHorizontalMargin * 2 : -1
        fixedHeight: runs && root.vertical ? faceRuns.implicitHeight + scaledVerticalPadding * 2 : -1
        // What the runs paint along the bar, for the slot's ink (HighlightModel).
        readonly property real paintedWidth: runs ? faceRuns.paintedWidth : 0
        GroupFace {
          id: faceRuns
          visible: groupButton.runs
          anchors.centerIn: parent
          group: groupButton.runs ? groupButton.group : null
          faceMode: groupButton.face
          color: groupButton.foreground
          fontFamily: Style.font.family
          fontSize: groupButton.fontSize
        }
        tooltipText: group && (nameHidden || (group.tooltip === undefined ? face === "glyph" : group.tooltip))
          ? group.label : ""
        onPressed: function(button) {
          var window = root.targetWindow(slot)
          if (!window) return
          if (button === Qt.RightButton) root.showGroups(window.screen, slot.entry.powerbarGroupId)
          else if (button === Qt.LeftButton) window.managedDrawer.toggleGroup(slot.entry.powerbarGroupId, slot)
        }
      }
    }

    Component {
      id: customCommandModuleComponent
      CustomCommandModule { entry: slot.entry }
    }
  }

  component CustomCommandModule: WidgetButton {
    id: customRoot

    required property var entry
    readonly property string moduleName: root.entryId(entry)
    readonly property var settings: root.entrySettings(entry)
    property string outputText: ""
    property string outputTooltip: ""
    property bool outputActive: false

    function setting(name, fallback) {
      var value = settings ? settings[name] : undefined
      return value === undefined || value === null ? fallback : value
    }

    function update(raw) {
      var data = Util.parseModuleJson(raw)
      var klass = data.class || data.alt || ""

      outputText = data.text || String(raw || "").trim()
      outputTooltip = data.tooltip || String(setting("tooltip", ""))
      outputActive = klass === "active" || (Array.isArray(klass) && klass.indexOf("active") !== -1)
    }

    bar: root
    text: outputText || String(setting("text", ""))
    tooltipText: outputTooltip || String(setting("tooltip", ""))
    active: outputActive
    keepSpace: setting("keepSpace", false) === true
    horizontalMargin: Number(setting("horizontalMargin", 7.5))
    verticalPadding: Number(setting("verticalPadding", 6))
    fontSize: Number(setting("fontSize", 12))

    onPressed: function(button) {
      var command = ""
      if (button === Qt.RightButton)
        command = String(setting("onRightClick", ""))
      else if (button === Qt.MiddleButton)
        command = String(setting("onMiddleClick", ""))
      else
        command = String(setting("onClick", ""))

      if (command) root.run(command)
    }

    Process {
      id: customProc
      command: ["bash", "-lc", String(customRoot.setting("exec", ""))]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: customRoot.update(text)
      }
    }

    Timer {
      interval: Math.max(1, Number(customRoot.setting("interval", 5))) * 1000
      running: String(customRoot.setting("exec", "")) !== ""
      repeat: true
      triggeredOnStart: true
      onTriggered: root.runProcess(customProc)
    }
  }
}
