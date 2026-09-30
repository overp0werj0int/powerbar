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
import "RenderModel.js" as RenderModel

Item {
  id: root

  Preferences { id: preferencesPane; bar: root }
  readonly property bool animationsEnabled: barConfig.powerbarAnimations !== false
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
    if (!shell || typeof shell.mutateShellConfig !== "function") return false
    return shell.mutateShellConfig(function(config) {
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
  function editGroups(operation) {
    closeManagedDrawer()
    return shell && shell.mutateShellConfig(function(config) { operation(config) })
  }
  function assignGroup(key, id, before) {
    return editGroups(function(config) { GroupsModel.assign(config, key, id, before || "") })
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
          done(key, { url: result.url, width: width, height: height })
          if (key.indexOf("group:") !== 0) result.saveToFile(root.widgetImageFile(key))
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
    onTriggered: if (Quickshell.screens.length) root.captureWidgetImages(Quickshell.screens[0], function() {})
  }
  IndicatorServices { id: indicatorServices }
  function acquireIndicatorState(kind, settings) { return indicatorServices.acquire(kind, settings) }
  function releaseIndicatorState(producer) { if (indicatorServices) indicatorServices.release(producer) }
  function refreshIndicatorStates() { indicatorServices.refresh() }
  property var activityDeadlines: Object.create(null)
  property var slotCopies: Object.create(null)
  // Drawer timing is fixed; Preferences no longer offers it. The shell.json
  // keys still override it for anyone who sets them by hand. Activity keeps a
  // drawer widget on the bar exactly as long as an autohidden bar peeks for it,
  // so the widget and its island leave together.
  readonly property real managedRevealSeconds: ManagedModel.seconds(barConfig.powerbarManagedRevealSeconds, 2.5, 60)
  readonly property real managedEntrySeconds: ManagedModel.seconds(barConfig.powerbarManagedEntryGraceSeconds, 1, 15)
  readonly property real managedExitSeconds: ManagedModel.seconds(barConfig.powerbarManagedExitGraceSeconds, 1, 15)

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
    if (owner && owner.visibility === "managed") setActivityDeadline("group:" + owner.id, until)
  }
  function setActivityDeadline(key, until) {
    activityDeadlines[key] = until
    for (var slot of (slotCopies[key] || [])) if (slot) slot.activityUntil = until
  }
  // Assign stable identities once, preserving duplicate plugin instances on moves.
  function ensureInstanceIds() {
    if (!shell || !barConfig.layout) return
    var seen = {}, missing = false
    for (var zone of ["left", "center", "right"]) {
      for (var entry of (barConfig.layout[zone] || [])) {
        var key = entry && entry.powerbarInstance
        if (!key || seen[key]) missing = true
        seen[key] = true
      }
    }
    if (!missing) return
    shell.mutateShellConfig(function(config) {
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
    return (window && window.moduleItems || []).filter(function(slot) {
      return slot && slot.moduleName && slot.region === zone && slot.managed && !slot.memberGroup
    })
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
      previous.slot.slotTargets = previous.slot.slotTargets.filter(function(item) { return item !== target })
      targetSlots = targetSlots.filter(function(record) { return record !== previous })
    }
    pendingTargets = pendingTargets.filter(function(item) { return item !== target })
    if (!attachTarget(target)) pendingTargets.push(target)
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
  function openManagedZone(zone) {
    if (["left", "center", "right"].indexOf(zone) < 0) return
    var screenName = focusedScreenName()
    for (var slot of moduleSlots) {
      var window = targetWindow(slot)
      if (window && window.screen && window.screen.name === screenName && window.managedDrawer)
        { window.managedDrawer.openZone(zone, true); return }
    }
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
      preferencesPane.setPage(page - 1)
    }
    function managed(zone: string): void { root.openManagedZone(zone) }
    function closeManaged(): void { root.closeManagedDrawer() }
    function group(id: string): void {
      var slot = root.moduleSlots.find(function(s) {
        if (!s.groupHeader || s.entry.powerbarGroupId !== id) return false
        var window = root.targetWindow(s)
        return window && window.screen && window.screen.name === root.focusedScreenName()
      })
      if (slot) root.targetWindow(slot).managedDrawer.openGroup(id, slot, true)
    }
    function groupsPreferences(): void { preferences(); preferencesPane.page = 2 }
    function popupStatus(): string {
      return JSON.stringify(root.popupPlacements.filter(function(record) { return record.panel && record.panel.open }).map(function(record) {
        var panel = record.panel
        return { position: panel.barPos, x: panel.cardOrigin.x, y: panel.cardOrigin.y, width: panel.contentWidth, height: panel.contentHeight, screenWidth: panel.screenW, screenHeight: panel.screenH, gap: panel.gap, barExtent: root.barExtent }
      }))
    }
    function drawerStatus(): string {
      var drawer = root.managedOwner
      return JSON.stringify(drawer ? { opened: drawer.opened, zone: drawer.zone, groupId: drawer.groupId, memberDisplay: drawer.memberDisplay, stripVertical: drawer.stripVertical, surfaceRole: drawer.surfaceRole, surfaceRadius: drawer.surfaceRadius, themeRadius: Style.cornerRadius, crossLength: drawer.crossLength, desiredCross: drawer.desiredCross, reveal: drawer.reveal, width: drawer.width, height: drawer.height, entered: drawer.entered, sourceHovered: drawer.sourceHovered, hovered: drawer.containsMouse, keyboard: drawer.keyboardMode, cursor: drawer.cursor, selectionVisible: drawer.selectionVisible, focused: drawer.activeFocus, ids: drawer.slots.map(function(s) { return s.moduleName }), count: drawer.slots.length } : { opened: false })
    }
    function managedStatus(): string {
      return JSON.stringify(root.moduleSlots.filter(function(s) { return s.managed }).map(function(s) {
        return { id: s.moduleName, key: s.instanceKey, zone: s.region, revealed: s.activityVisible, mainVisible: s.mainVisible, inDrawer: !!s.drawerHost, panelOpen: s.panelOpen, observing: s.activityTargets.length }
      }))
    }
  }

  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  // Injected by the host shell so bar slots can resolve enabled widgets.
  property var barWidgetRegistry: fallbackBarWidgetRegistry
  // Omarchy keeps a per-bar copy of its widget registry. After switching bars
  // (and so on a first install), that copy can still point at widget
  // components the shell has since rebuilt and destroyed, which leaves every
  // widget a placeholder until the shell is restarted. When Powerbar finds such
  // entries it asks the shell to rescan its plugins once, which hands it fresh
  // components; the 30 s guard keeps a lasting fault from looping.
  // A rescan reloads every plugin, Powerbar included, so the guard lives in a
  // runtime file rather than in this instance: at most one rescan a minute.
  function registryStale() {
    var widgets = barWidgetRegistry && barWidgetRegistry.widgets || {}
    for (var id in widgets) if (widgets[id] && !widgets[id].component) return true
    return false
  }
  function checkRegistry() {
    if (!registryStale()) return
    var now = Date.now()
    if (now - Number(String(registryHealStamp.text() || "0").trim() || 0) < 60000) return
    registryHealStamp.setText(String(now))
    console.info("powerbar: widget registry is stale after a bar switch; asking the shell to rescan plugins")
    Util.execArgv(["omarchy-shell", "shell", "rescanPlugins"])
  }
  FileView {
    id: registryHealStamp
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/powerbar-registry-rescan"
    blockLoading: true
    printErrors: false
  }
  Connections {
    target: root.barWidgetRegistry
    ignoreUnknownSignals: true
    function onRevisionChanged() { registryCheck.restart() }
  }
  onBarWidgetRegistryChanged: registryCheck.restart()
  Timer { id: registryCheck; interval: 2500; onTriggered: root.checkRegistry() }
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
  property bool barHidden: false
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
  property color barForeground: !islands && useTransparentForeground ? transparentForeground : themeForeground
  property bool foregroundAnimationEnabled: true
  property color background: Color.bar.background
  property color urgent: Color.bar.active

  Behavior on barForeground { enabled: root.foregroundAnimationEnabled; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
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
  readonly property real dragLandingExtent: barDragSource && barDragSource.landingExtent > 0 ? barDragSource.landingExtent : 0
  readonly property real dragGapWidth: !vertical && dragLandingExtent > 0 ? dragLandingExtent
    : Math.max(barSize, barDragImageWidth / Math.max(0.01, barScale)) + cellTokens.gutter
  readonly property real dragGapHeight: vertical && dragLandingExtent > 0 ? dragLandingExtent
    : Math.max(barSize, barDragImageHeight / Math.max(0.01, barScale)) + cellTokens.gutter
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

  function publicLayoutConfig() { return JSON.parse(apiSync.layoutJSON) }

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
    api.foregroundAnimationEnabled = Qt.binding(function() { return root.foregroundAnimationEnabled })
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
      var slot = record.slot
      if (slot) slot.slotTargets = slot.slotTargets.filter(function(t) { return t !== target })
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
    barDragSourceSurface = ""
    barDragSourceRect = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragImageReady = false
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
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.position = next
      })
    } else {
      root.position = next
    }
  }

  function captureBarDragGhost(slot) {
    var item = slot ? (slot.drawerHost || slot.presentationItem) : null
    barDragImageUrl = ""
    barDragImageReady = false
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageWidth = grabWidth * root.barScale
      root.barDragImageHeight = grabHeight * root.barScale
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
      width: visual.width * root.barScale, height: visual.height * root.barScale }
    root.barDragOffsetX = offsetX
    root.barDragOffsetY = offsetY
    root.barDragSource = slot
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
  function updateSpringGroup(drop, source, overGroup, scenePoint) {
    var canSpring = source && !source.groupHeader && !source.drawerHost
    var target = canSpring && overGroup ? overGroup : null
    if (target !== springGroupSlot) {
      springGroupSlot = target
      if (target) springOpen.restart()
      else springOpen.stop()
    }
    var drawer = springOpenedDrawer
    if (!drawer) return
    var keep = !!target || onSpringPath(drawer, scenePoint)
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
    var screenPoint = root.barDragScreenPoint(scenePoint)
    root.barDragScreenX = screenPoint.x
    root.barDragScreenY = screenPoint.y
    var drop = root.moduleDropAtScene(scenePoint, slot)
    root.updateSpringGroup(drop, slot, root.groupSlotAt(scenePoint, slot), scenePoint)
    var old = root.barDragDrop
    if (old && drop && old.source === drop.source && old.slot === drop.slot && old.after === drop.after &&
        old.drawer === drop.drawer && old.zone === drop.zone && old.managedZone === drop.managedZone && old.into === drop.into) return
    root.barDragDrop = drop
  }

  function finishIconDrag(scenePoint, slot) {
    if (root.barDragSource !== slot) return false
    var drop = root.moduleDropAtScene(scenePoint, slot)
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
    root.beginDragSettle(slot, scenePoint, false)
    var changed = drop ? root.dropBarModuleAtTarget(slot, drop) : false
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
    if (!target || target.drawerHost || target.centerAnchorSlot) return null
    var start = drop.after === true ? target.cellExtent : 0
    var centre = start + sourceSlot.inkShift + (root.vertical ? sourceSlot.naturalHeight : sourceSlot.naturalWidth) / 2
    var local = root.vertical
      ? { x: target.width / 2, y: centre }
      : { x: centre, y: target.height / 2 }
    return { item: target, local: local, fade: false }
  }

  function commitPendingDrop() {
    var pending = barDragPendingDrop
    if (!pending) return false
    barDragPendingDrop = null
    barDragSource = null
    barDragDrop = null
    try {
      return dropBarModuleAtTarget(pending.slot, pending.drop)
    } catch (e) {
      return false
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
    }), root.barDragSettleKey, owner ? "group:" + owner.id : "")
    var target = slots[choice.index] || null
    root.barDragSettleItem = target ? (target.drawerHost || target.presentationItem) : null
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
    // gap using the visible source surface. PopupCard uses item anchors and
    // must keep its existing positioning.
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
              var sourceDrawer = null
              for (var parent = item.anchorItem; parent; parent = parent.parent) {
                if (parent === host.managedDrawer) { sourceDrawer = parent; break }
              }
              var edge = root.barExtent + (sourceDrawer ? sourceDrawer.gap + sourceDrawer.crossLength : 0)
              return Style.gapsOut + record.gapOffset + edge - (root.vertical ? host.width : host.height)
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

  readonly property var surfaceEffects: AppearanceModel.effects(barConfig)
  readonly property var mainEffects: surfaceEffects
  readonly property var extendedEffects: surfaceEffects
  // Drawers always lie over windows, and so does a bar that autohides; those
  // surfaces keep a readable minimum opacity (AppearanceModel.overlayOpacity).
  readonly property color overlaySurfaceColor: Qt.alpha(background, AppearanceModel.overlayOpacity(surfaceEffects))
  readonly property color mainSurfaceColor: autoHide ? overlaySurfaceColor : Qt.alpha(background, surfaceEffects.backgroundOpacity)
  readonly property color extendedSurfaceColor: overlaySurfaceColor

  readonly property string barStyle: BarModel.barStyle(barConfig)
  readonly property bool islands: barStyle === "islands"
  readonly property bool floating: barStyle === "floating"
  readonly property bool flat: barStyle === "flat"
  // Floating bars and islands keep this distance from the screen edges.
  readonly property real edgeGap: Style.space(4)
  // Counts highlight lightings, so overlapping highlights know which is newer.
  property real highlightClock: 0
  // How long a narrower value keeps its cell's width.
  readonly property int widthHoldMs: 8000
  readonly property bool autoHide: barConfig.powerbarAutoHide === true
  // Whether widget activity slides an autohidden bar out (on by default).
  readonly property bool autoHideActivity: barConfig.powerbarAutoHideActivity !== false
  // The large bar is as thick as Preferences' Layout page draws it: the theme's
  // bar size plus a lip above and below each widget. Widgets keep their own
  // size and gain room around them; the islands' ends open up to match.
  readonly property bool largeBar: barConfig.powerbarLargeBar === true
  readonly property real largeBarLip: Style.space(6)
  function barSizeFor(vertical) {
    return (vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal) + (largeBar ? largeBarLip * 2 : 0)
  }
  // One cell, one inset (docs/spacing-lab): every item gets a cell along the
  // bar, square for glyphs, and the cell is its highlight. Equal slots puts
  // cells one gutter apart; Equal gaps puts the same air between glyphs.
  readonly property string spacingMode: barConfig.powerbarSpacingMode === "gaps" ? "gaps" : "slots"
  readonly property var cellTokens: CellModel.tokens({ bar: barSize, spacing: widgetSpacing, mode: spacingMode })
  readonly property real highlightRadius: CellModel.radius(cellTokens, islandRounding)
  // Compounds (several click targets in one widget) show a faint track over
  // the whole cell and a thumb over the hovered target.
  readonly property color highlightTrackColor: Qt.rgba(barForeground.r, barForeground.g, barForeground.b, 0.06)
  // Islands keep the bar gap from the screen's sides, as from its edge; a
  // flat bar runs edge to edge.
  readonly property real islandScreenInset: flat ? 0 : edgeGap
  // Preferences' layout preview pads its zones like an island end.
  readonly property real islandPadding: cellTokens.inset
  // Padding past the first or last slot so the end cell sits one inset from
  // the island's end and its curve runs parallel to the island's.
  function cellEndPad(spill) { return CellModel.endPad(cellTokens, spill) }
  // Island ends are the same during a drag: the outlined placeholder shows
  // where a widget lands, so islands no longer grow a landing lip.
  function islandEnd(zone, spill) { return cellEndPad(spill) }
  // The spill of the first (or last) visible slot in a Row or Column.
  function edgeSpill(container, last) {
    var kids = container ? container.children : []
    for (var n = 0; n < kids.length; n++) {
      var c = kids[last ? kids.length - 1 - n : n]
      if (c && c.cellSpill !== undefined && c.visible && (vertical ? c.height : c.width) > 0) return c.cellSpill
    }
    return 0
  }
  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: barSizeFor(vertical)
  // Widgets are drawn at this size whether or not the bar is large, so lists
  // of widget icons outside the bar keep to it.
  readonly property int themeBarSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property real renderedBarSize: barSize
  readonly property real barScale: 1
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
  readonly property int barExtent: Math.ceil(renderedBarSize + (flat ? 0 : edgeGap * 2))
  readonly property real widgetSpacing: Style.space(Math.max(0, Math.min(24, Number(barConfig.powerbarSpacing) || 0)))
  readonly property var themeIslandBorder: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
  readonly property real islandRounding: typeof barConfig.powerbarIslandRounding === "number"
    ? Style.space(Math.max(0, Math.min(32, barConfig.powerbarIslandRounding))) : Style.cornerRadius
  readonly property var islandBorder: {
    if (barConfig.powerbarIslandBorders === false) return Border.none()
    var spec = JSON.parse(JSON.stringify(themeIslandBorder))
    var custom = typeof barConfig.powerbarIslandBorderWidth === "number"
    for (var side in spec.widths) {
      spec.widths[side] = (custom ? Style.spaceReal(Math.max(0, Math.min(4, barConfig.powerbarIslandBorderWidth))) : spec.widths[side]) / barScale
    }
    return spec
  }

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
      closeManagedDrawer()
      barConfigSerial++
    }
    // A retained widget can update presentation synchronously during injection.
    // Treat structural-edit initialization as the baseline, as rebuilt owners
    // did, while ordinary settings and subsequent events retain their policy.
    reconcilingStructure = structural
    try { layoutConfig = next } finally { reconcilingStructure = false }
  }

  onBarConfigChanged: { applyBarConfig(); Qt.callLater(ensureInstanceIds) }

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
      for (var j = 0; j < moduleSlots.length; j++) {
        var slot = moduleSlots[j]
        if (!slot || slot.region !== region || slot.moduleName !== id) continue
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
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
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
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, focusedScreenName())
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

  function moduleString(entry, key, fallback) {
    return BarModel.moduleString(entry, key, fallback)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }

  function entriesBefore(entries, name) {
    return BarModel.entriesBefore(entries, name)
  }

  function entriesAfter(entries, name) {
    return BarModel.entriesAfter(entries, name)
  }

  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function expandPath(path) {
    return BarModel.expandPath(path, home)
  }

  function customModuleSafeName(name) {
    return BarModel.customModuleSafeName(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  Component.onCompleted: { applyBarConfig(); registryCheck.restart() }

  // Revealing the indicators widens the center island, which can slide a
  // neighbour under a stationary pointer or move the hovered icon away from it.
  // Collapsing on that un-hover would shift everything back and re-open the
  // peek, so once opened the reveal is held until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerHoverCount = Math.max(0, centerHoverCount + (hovered ? 1 : -1))
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
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
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.transparent = nextTransparent
      })
    } else {
      root.setRequestedTransparency(nextTransparent)
    }
  }

  function dropBarModule(source, toRegion, beforeKey, visibility) {
    if (!source || !source.region || !source.instanceKey || !toRegion) return false
    if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

    var changed = false
    root.shell.mutateShellConfig(function(config) {
      var layout = config.bar && config.bar.layout
      var from = layout && layout[source.region], to = layout && layout[toRegion]
      // A group icon is not a layout entry: it sits before its anchor entry, so
      // "before the group" means before that anchor (or the zone's end).
      if (beforeKey && beforeKey.indexOf("group:") === 0) {
        var group = GroupsModel.groups(config.bar).find(function(g) { return "group:" + g.id === beforeKey })
        beforeKey = group && Array.isArray(to) && to.some(function(entry) { return entry && entry.powerbarInstance === group.before }) ? group.before : ""
      }
      if (!Array.isArray(from) || !Array.isArray(to) ||
          !from.some(function(entry) { return entry && entry.powerbarInstance === source.instanceKey }) ||
          (beforeKey && !to.some(function(entry) { return entry && entry.powerbarInstance === beforeKey }))) return
      changed = BarModel.moveInstanceInConfig(config, source.region, source.instanceKey, toRegion, beforeKey, visibility)
      if (source.memberGroup) changed = GroupsModel.assign(config, source.instanceKey, "") || changed
    })
    return changed
  }

  // After a group icon: the widget takes the group's place before its anchor,
  // and the group re-anchors on the widget so it stays in front of it.
  function dropAfterGroup(source, groupId) {
    if (!source || !root.shell) return false
    var changed = false
    root.shell.mutateShellConfig(function(config) {
      var group = GroupsModel.groups(config.bar).find(function(g) { return g.id === groupId })
      var to = group && config.bar.layout && config.bar.layout[group.section]
      if (!group || !Array.isArray(to)) return
      var anchor = to.some(function(entry) { return entry && entry.powerbarInstance === group.before }) ? group.before : ""
      if (!BarModel.moveInstanceInConfig(config, source.region, source.instanceKey, group.section, anchor, "shown")
          && !(source.region === group.section)) return
      if (source.memberGroup) GroupsModel.assign(config, source.instanceKey, "")
      changed = GroupsModel.edit(config, groupId, { before: source.instanceKey }) || true
    })
    return changed
  }

  function barZoneAt(point, window) {
    var coordinate = root.vertical ? point.y : point.x
    var length = root.vertical ? window.height : window.width
    return ["left", "center", "right"][Math.min(2, Math.max(0, Math.floor(coordinate * 3 / length)))]
  }

  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    var zone = "", managedZone = ""
    if (sourceWindow && sourceWindow.contentItem) {
      var barPoint = sourceWindow.contentItem.mapFromItem(null, scenePoint.x, scenePoint.y)
      if (barPoint.x < 0 || barPoint.x > sourceWindow.contentItem.width ||
          barPoint.y < 0 || barPoint.y > sourceWindow.contentItem.height)
        return null
      var stripX = root.position === "right" ? sourceWindow.width - root.barExtent : 0
      var stripY = root.position === "bottom" ? sourceWindow.height - root.barExtent : 0
      var drawer = sourceWindow.managedDrawer
      var inDrawer = drawer && drawer.opened && barPoint.x >= drawer.x && barPoint.x <= drawer.x + drawer.width && barPoint.y >= drawer.y && barPoint.y <= drawer.y + drawer.height
      // A release that drifts a little off the bar's inner edge still lands on
      // the bar, unless it is over an open drawer.
      var slack = inDrawer ? 0 : root.barSize * 0.6
      var cross = root.vertical ? barPoint.x : barPoint.y
      var stripStart = root.vertical ? stripX : stripY
      var inStrip = root.position === "top" || root.position === "left"
        ? cross >= stripStart && cross <= stripStart + root.barExtent + slack
        : cross >= stripStart - slack && cross <= stripStart + root.barExtent
      if (!inStrip && !inDrawer) return null
      if (inStrip) zone = root.barZoneAt(barPoint, sourceWindow)
      if (inStrip && typeof sourceWindow.managedDropZoneAt === "function")
        managedZone = sourceWindow.managedDropZoneAt(barPoint)
    }

    // Landing follows the dragged widget's painted centre, not the pointer, so
    // a wide widget grabbed at one end lands where it looks.
    var probe = { x: scenePoint.x, y: scenePoint.y }
    if (sourceSlot && sourceSlot.ink && sourceSlot.ink.length > 0) {
      var inkCentre = (sourceSlot.ink.start + sourceSlot.ink.length / 2) * root.barScale
      var alongDrawer = inDrawer ? drawer.stripVertical : root.vertical
      if (alongDrawer) probe.y = scenePoint.y - root.barDragOffsetY + inkCentre
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
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var slotPoint = { x: slot.x, y: slot.y }
      try {
        slotPoint = item.mapToItem(null, 0, 0)
      } catch (e) {
      }

      candidates.push({
        slot: slot,
        x: slotPoint.x,
        y: slotPoint.y,
        width: item.width * root.barScale,
        height: item.height * root.barScale,
        // A bar slot's landing reference is its cell, past any open drag gap.
        contentX: (slot.drawerHost ? slot.drawerHost.contentOffsetX : root.vertical ? 0 : slot.animatedInsetX) * root.barScale,
        contentY: (slot.drawerHost ? slot.drawerHost.contentOffsetY : root.vertical ? slot.animatedInsetY : 0) * root.barScale,
        contentWidth: (slot.drawerHost ? slot.drawerHost.baseWidth : root.vertical ? slot.naturalWidth : slot.cellExtent) * root.barScale,
        contentHeight: (slot.drawerHost ? slot.drawerHost.baseHeight : root.vertical ? slot.cellExtent : slot.naturalHeight) * root.barScale
      })
    }

    var hit = candidates.find(function(candidate) {
      return probe.x >= candidate.x && probe.x <= candidate.x + candidate.width
        && probe.y >= candidate.y && probe.y <= candidate.y + candidate.height
    }) || candidates.find(function(candidate) {
      return scenePoint.x >= candidate.x && scenePoint.x <= candidate.x + candidate.width
        && scenePoint.y >= candidate.y && scenePoint.y <= candidate.y + candidate.height
    })
    var alongColumn = inDrawer ? drawer.stripVertical : root.vertical
    var sourceRect = root.barDragSourceRect
    if (!hit && sourceRect && scenePoint.x >= sourceRect.x && scenePoint.x <= sourceRect.x + sourceRect.width &&
        scenePoint.y >= sourceRect.y && scenePoint.y <= sourceRect.y + sourceRect.height)
      return { source: true }
    if (managedZone) return { managedZone: managedZone }
    if (hit && hit.slot.groupHeader && !hit.slot.drawerHost && sourceSlot.drawerHost && !sourceSlot.groupHeader)
      return { slot: hit.slot, into: true }
    if (hit) {
      // A 3 px dead zone around the cell's centre keeps the gap from flickering.
      var previous = root.barDragDrop && root.barDragDrop.slot === hit.slot ? root.barDragDrop.after : undefined
      return { slot: hit.slot, after: alongColumn
        ? DragModel.afterCentre(probe.y, hit.y + hit.contentY + hit.contentHeight / 2, previous, root.dragDeadZone)
        : DragModel.afterCentre(probe.x, hit.x + hit.contentX + hit.contentWidth / 2, previous, root.dragDeadZone) }
    }
    var nearby = inDrawer ? candidates : candidates.filter(function(candidate) {
      return candidate.slot.region === zone
    })
    var nearest = BarModel.nearestDropTarget(nearby, probe, alongColumn)
    return nearest || (inDrawer ? { drawer: drawer } : { zone: zone })
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

  function dropBarModuleAtTarget(sourceSlot, drop) {
    if (!sourceSlot || !drop) return false
    if (drop.source) return false
    var targetSlot = drop.slot, afterTarget = drop.after

    if (sourceSlot.groupHeader) {
      var id = sourceSlot.entry.powerbarGroupId
      if (drop.managedZone) return root.editGroups(function(config) {
        GroupsModel.moveHeader(config, id, drop.managedZone, "", "", false, "managed")
      })
      if (drop.drawer) {
        if (drop.drawer.groupId) return false
        return root.editGroups(function(config) {
          GroupsModel.moveHeader(config, id, drop.drawer.zone, "", "", false, "managed")
        })
      }
      if (targetSlot && targetSlot.drawerHost && targetSlot.memberGroup) return false
      var before = targetSlot && !afterTarget
        ? targetSlot.instanceKey : targetSlot ? nextVisibleModuleKey(targetSlot.region, targetSlot.instanceKey, sourceSlot, !!targetSlot.drawerHost) : ""
      var section = targetSlot ? targetSlot.region : drop.zone
      return root.editGroups(function(config) {
        GroupsModel.moveHeader(config, id, section, before,
          targetSlot && targetSlot.groupHeader ? targetSlot.entry.powerbarGroupId : "",
          afterTarget, targetSlot && targetSlot.drawerHost ? "managed" : "shown")
      })
    }
    if (drop.managedZone) return root.dropBarModule(sourceSlot, drop.managedZone, "", "managed")
    if (drop.drawer) {
      if (drop.drawer.groupId) return root.assignGroup(sourceSlot.instanceKey, drop.drawer.groupId)
      return root.dropBarModule(sourceSlot, drop.drawer.zone, "", "managed")
    }
    if (drop.zone) return root.dropBarModule(sourceSlot, drop.zone, "", "shown")
    if (drop.into) return root.assignGroup(sourceSlot.instanceKey, targetSlot.entry.powerbarGroupId)
    if (targetSlot.groupHeader && !targetSlot.drawerHost && afterTarget)
      return root.dropAfterGroup(sourceSlot, targetSlot.entry.powerbarGroupId)
    if (targetSlot.groupHeader && !targetSlot.drawerHost)
      return dropBarModule(sourceSlot, targetSlot.region, targetSlot.instanceKey, "shown")
    if (targetSlot.drawerHost && targetSlot.memberGroup) {
      var group = targetSlot.memberGroup
      var index = group.items.indexOf(targetSlot.instanceKey) + (afterTarget ? 1 : 0)
      return root.assignGroup(sourceSlot.instanceKey, group.id, group.items[index] || "")
    }
    var beforeKey = afterTarget ? nextVisibleModuleKey(targetSlot.region, targetSlot.instanceKey, sourceSlot, !!targetSlot.drawerHost) : targetSlot.instanceKey
    return dropBarModule(sourceSlot, targetSlot.region, beforeKey, targetSlot.drawerHost ? "managed" : "shown")
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

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
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

  function refreshTransparentForeground() {
    if (!requestedTransparent || transparentForegroundProc.running) return

    transparentForegroundProc.command = [
      "omarchy-bar-text-color",
      root.position,
      String(root.renderedBarSize),
      colorHex(root.themeForeground),
      colorHex(root.themeContrastForeground)
    ]
    transparentForegroundProc.running = true
  }

  onRequestedTransparentChanged: scheduleTransparentForegroundRefresh()
  onPositionChanged: { closeManagedDrawer(); scheduleTransparentForegroundRefresh() }
  onThemeForegroundChanged: scheduleTransparentForegroundRefresh()
  onThemeContrastForegroundChanged: scheduleTransparentForegroundRefresh()

  Timer {
    id: transparentForegroundTimer
    interval: 120
    repeat: false
    onTriggered: root.refreshTransparentForeground()
  }

  Process {
    id: transparentForegroundProc
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
    onFileChanged: root.scheduleTransparentForegroundRefresh()
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
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
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
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
    property alias managedDrawer: drawer
    function managedDropZoneAt(point) {
      if (!root.dragPreview.ready) return ""
      for (var i = 0; i < 3; i++) {
        var target = managedDropTargets.itemAt(i)
        if (!target || !target.visible) continue
        var origin = target.mapToItem(barWindow.contentItem, 0, 0)
        if (point.x >= origin.x && point.x <= origin.x + target.width &&
            point.y >= origin.y && point.y <= origin.y + target.height) return target.modelData
      }
      return ""
    }
    property alias widgetStore: widgetStore
    property var widgetModels: ({ left: leftModel, right: rightModel, center: centerModel,
      before: beforeModel, anchor: anchorModel, after: afterModel })
    property var moduleItems: []
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
      for (var name of names) {
        models.push(widgetModels[name])
        lists.push(partition[name].map(function(key) { return widgetStore.get(key) }).filter(function(item) { return !!item }))
      }
      var items = records.map(function(record) { return widgetStore.get(record.key) }).filter(function(item) { return !!item })
      for (var item of items) item.centerAnchorSlot = partition.anchor.indexOf(item.instanceKey) >= 0
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
    visible: !remapGuard.remapping && !blurRemap.running
    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: root.barHidden || root.autoHide ? 0 : root.barExtent

    // Autohide overlays windows without reserving space. The surface stays
    // mapped and its content slides past the screen edge, leaving a thin edge
    // strip in the input region to catch the pointer and slide it back.
    readonly property bool autoHideActive: root.autoHide && !root.barHidden
    readonly property bool autoHideHeld: windowHover.hovered || edgeHover.hovered || drawer.opened
      || (!!root.activePopout && root.sameWindow(root.targetWindow(root.activePopout), barWindow))
      || !!root.barDragSource || root.barDragSettling || root.barMoveActive || preferencesPane.opened
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
    readonly property real autoHideDistance: root.barExtent + root.mainEffects.shadowSize + Style.space(8)
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
    // Sliding out answers the pointer, so it is a touch slower than sliding
    // away; tucked islands move on the strip's exact curve so they cancel out.
    readonly property int autoHideMotionMs: autoHideShown ? 180 : 130
    // While one island peeks the strip is out, so the others are pushed back
    // past the edge by the same distance, on the same curve.
    function zoneTucked(zone) { return root.islands && autoHideActive && !autoHideRevealed && peeking && !peekZones[zone] }
    property real leftShift: zoneTucked("left") ? autoHideDistance : 0
    property real centerShift: zoneTucked("center") ? autoHideDistance : 0
    property real rightShift: zoneTucked("right") ? autoHideDistance : 0
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

    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }
    readonly property bool blurEnabled: root.surfaceEffects.blur
    onBlurEnabledChanged: {
      if (visible) blurRemap.restart()
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

    WlrLayershell.keyboardFocus: drawer.opened && drawer.keyboardMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region {
      x: mainStrip.x; y: mainStrip.y
      width: mainStrip.width; height: mainStrip.height
      Region {
        item: autoHideStrip
        intersection: Intersection.Combine
      }
      Region {
        x: drawer.x; y: drawer.y
        width: drawer.opened ? drawer.width : 0
        height: drawer.opened ? drawer.height : 0
        intersection: Intersection.Combine
      }
    }
    HyprlandFocusGrab {
      // Hover drawers must stay passive so wheel input reaches other windows.
      // Only an explicitly opened keyboard drawer needs outside-click dismissal.
      active: drawer.opened && drawer.keyboardMode && drawer.grabReady && !root.activePopout
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
      shadowEnabled: root.flat && root.mainEffects.shadow
      shadowSize: root.mainEffects.shadowSize
      shadowOpacity: root.mainEffects.shadowOpacity
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
      shadowEnabled: root.mainEffects.shadow
      shadowSize: root.mainEffects.shadowSize
      shadowOpacity: root.mainEffects.shadowOpacity
      radius: root.islandRounding
      borderSpec: root.islandBorder
    }
    Loader {
      x: mainStrip.x
      y: mainStrip.y
      width: mainStrip.width / root.barScale
      height: mainStrip.height / root.barScale
      scale: root.barScale
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

    // A small destination remains available while another extended island is
    // open, so a member can move directly into any zone's Managed collection.
    Item {
      x: mainStrip.x; y: mainStrip.y
      width: mainStrip.width; height: mainStrip.height
      visible: root.dragPreview.ready && !root.barHidden
      z: 20
      Repeater {
        id: managedDropTargets
        model: ["left", "center", "right"]
        Rectangle {
          required property string modelData
          required property int index
          readonly property bool selected: root.barDragDrop && root.barDragDrop.managedZone === modelData
          width: Style.space(14); height: width
          x: root.vertical ? (root.position === "left" ? parent.width - width : 0)
            : (index + 0.5) * parent.width / 3 - width / 2
          y: root.vertical ? (index + 0.5) * parent.height / 3 - height / 2
            : (root.position === "top" ? parent.height - height : 0)
          radius: width / 2
          color: selected ? Color.accent : Qt.alpha(Color.accent, 0.68)
          border.width: selected ? Style.space(2) : 0
          border.color: root.barForeground
          Text {
            anchors.centerIn: parent
            text: "󰇘"
            color: Color.background
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
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
            visible: zoneTarget.members.length > 0 && !root.moduleSlots.some(function(slot) {
              return slot.region === zoneTarget.modelData && root.sameWindow(root.targetWindow(slot), barWindow) && slot.mainVisible && slot.width > 0
            })
            anchors.centerIn: parent
            width: root.renderedBarSize; height: root.renderedBarSize
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

    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var popupWidth = tooltipWindow.implicitWidth / root.barScale
          var popupHeight = tooltipWindow.implicitHeight / root.barScale
          var localX = target.width / 2 - popupWidth / 2
          var localY = target.height + 6

          if (root.position === "bottom") {
            localY = -popupHeight - 6
          } else if (root.position === "left") {
            localX = target.width + 6
            localY = target.height / 2 - popupHeight / 2
          } else if (root.position === "right") {
            localX = -popupWidth - 6
            localY = target.height / 2 - popupHeight / 2
          }

          var point = barWindow.contentItem.mapFromItem(target, localX, localY)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.tooltipText
          color: Color.tooltip.text
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
        IslandSurface {
          id: leftIsland
          transform: Translate { x: barWindow.shiftX(barWindow.leftShift); y: barWindow.shiftY(barWindow.leftShift) }
          x: root.vertical ? (parent.width - width) / 2 : leftModules.x - root.islandEnd("left", leftModules.leadSpill)
          y: root.vertical ? leftModules.y - root.islandEnd("left", leftModules.leadSpill) : (parent.height - height) / 2
          width: root.vertical ? root.barSize : leftModules.width + root.islandEnd("left", leftModules.leadSpill) + root.islandEnd("left", leftModules.trailSpill)
          height: root.vertical ? leftModules.height + root.islandEnd("left", leftModules.leadSpill) + root.islandEnd("left", leftModules.trailSpill) : root.barSize
          visible: root.islands && (root.vertical ? leftModules.height : leftModules.width) > 0
        }
        IslandSurface {
          id: rightIsland
          transform: Translate { x: barWindow.shiftX(barWindow.rightShift); y: barWindow.shiftY(barWindow.rightShift) }
          readonly property real start: (root.vertical ? rightModules.height : rightModules.width) > 0
            ? (root.vertical ? rightModules.y : rightModules.x) - root.islandEnd("right", rightModules.leadSpill)
            : (root.vertical ? preferencesButton.y : preferencesButton.x) - root.islandEnd("right", preferencesButton.cellSpill)
          x: root.vertical ? (parent.width - width) / 2 : start
          y: root.vertical ? start : (parent.height - height) / 2
          width: root.vertical ? root.barSize : preferencesButton.x + preferencesButton.width + root.islandEnd("right", preferencesButton.cellSpill) - x
          height: root.vertical ? preferencesButton.y + preferencesButton.height + root.islandEnd("right", preferencesButton.cellSpill) - y : root.barSize
        }
        CenterModules {
          anchors.fill: parent
          homeWindow: barWindow
          transform: Translate { x: barWindow.shiftX(barWindow.centerShift); y: barWindow.shiftY(barWindow.centerShift) }
        }
        HighlightLayer { zone: "left"; island: leftIsland; transform: Translate { x: barWindow.shiftX(barWindow.leftShift); y: barWindow.shiftY(barWindow.leftShift) } }
        HighlightLayer { zone: "right"; island: rightIsland; transform: Translate { x: barWindow.shiftX(barWindow.rightShift); y: barWindow.shiftY(barWindow.rightShift) } }
        LeftModules {
          id: leftModules
          homeWindow: barWindow
          transform: Translate { x: barWindow.shiftX(barWindow.leftShift); y: barWindow.shiftY(barWindow.leftShift) }
          // Positioned with x/y, never with anchors switched by orientation: a
          // switch passes through a state anchored both ways, and Qt then writes
          // width/height directly, which removes their bindings for good.
          x: root.vertical ? (parent.width - width) / 2 : root.islandScreenInset + root.cellEndPad(leadSpill)
          y: root.vertical ? root.islandScreenInset + root.cellEndPad(leadSpill) : (parent.height - height) / 2
        }
        PreferencesButton {
          id: preferencesButton
          transform: Translate { x: barWindow.shiftX(barWindow.rightShift); y: barWindow.shiftY(barWindow.rightShift) }
          x: root.vertical ? (parent.width - width) / 2 : parent.width - root.islandScreenInset - root.cellEndPad(cellSpill) - width
          y: root.vertical ? parent.height - root.islandScreenInset - root.cellEndPad(cellSpill) - height : (parent.height - height) / 2
        }
        RightModules {
          id: rightModules
          homeWindow: barWindow
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
  component DropOutline: Rectangle {
    property real gapStart: 0
    property real gapLength: 0
    readonly property real along: root.barDragSource ? root.barDragSource.cellLength : root.cellTokens.cell
    readonly property real cross: root.vertical ? (parent ? parent.width : root.barSize) : (parent ? parent.height : root.barSize)
    visible: !!root.barDragSource && gapLength > 1
    opacity: Math.min(1, gapLength / Math.max(1, root.vertical ? root.dragGapHeight : root.dragGapWidth))
    x: root.vertical ? (cross - root.cellTokens.thickness) / 2 : gapStart + (gapLength - along) / 2
    y: root.vertical ? gapStart + (gapLength - along) / 2 : (cross - root.cellTokens.thickness) / 2
    width: root.vertical ? root.cellTokens.thickness : along
    height: root.vertical ? along : root.cellTokens.thickness
    radius: root.highlightRadius
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.45)
    Accessible.ignored: true
  }

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
  component IslandSurface: EffectSurface {
    visible: root.islands
    color: root.mainSurfaceColor
    shadowEnabled: root.mainEffects.shadow
    shadowSize: root.mainEffects.shadowSize
    shadowOpacity: root.mainEffects.shadowOpacity
    surfaceScale: root.barScale
    radius: root.islandRounding / root.barScale
    borderSpec: root.islandBorder
  }

  component PreferencesButton: Item {
    id: preferencesButton
    // A glyph cell like any icon widget: square highlight, one gutter (or one
    // equal gap) around its nine dots.
    readonly property real glyphSize: Style.space(2) * 3 + Style.spaceReal(2.5) * 2
    readonly property var cellPlace: CellModel.place(root.cellTokens, glyphSize, true)
    readonly property real cellSpill: cellPlace.spill
    implicitWidth: root.vertical ? root.barSize : cellPlace.extent
    implicitHeight: root.vertical ? cellPlace.extent : root.barSize
    width: implicitWidth
    height: implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: "Powerbar preferences"
    HoverHighlight {
      id: buttonHighlight
      hovered: buttonMouse.containsMouse && !root.barDragSource && !root.barHidden
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
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: preferencesPane.show(root.targetWindow(preferencesButton).screen)
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
      return metadata.displayName || String(source.moduleName).split(".").pop()
    }
    BorderSurface {
      id: labelGhost
      visible: ghostWindow.visible && ghostWindow.display !== "native" && !root.barDragSettling
      x: Math.round(root.barDragScreenX - root.barDragOffsetX)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY)
      width: labelRow.implicitWidth + Style.space(20)
      height: Math.max(root.barDragImageHeight, labelText.implicitHeight + Style.space(12))
      radius: Style.cornerRadius
      color: Qt.alpha(root.background, Math.max(0.85, root.surfaceEffects.backgroundOpacity))
      borderSpec: Border.flat(Color.accent, Math.max(1, Style.space(2)))
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
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        visible: opacity > 0
        opacity: root.barMoveCandidate === modelData ? (root.transparent ? 0.45 : 0.7) : 0

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
      readonly property real start: centerRoot.hasAnchor
        ? ((root.vertical ? beforeModules.height : beforeModules.width) > 0 ? (root.vertical ? beforeModules.y : beforeModules.x) : (root.vertical ? centerAnchorModule.y : centerAnchorModule.x))
        : (root.vertical ? groupModules.y : groupModules.x)
      readonly property real end: centerRoot.hasAnchor
        ? ((root.vertical ? afterModules.height : afterModules.width) > 0 ? (root.vertical ? afterModules.y + afterModules.height : afterModules.x + afterModules.width)
          : (root.vertical ? centerAnchorModule.y + centerAnchorModule.height : centerAnchorModule.x + centerAnchorModule.width))
        : (root.vertical ? groupModules.y + groupModules.height : groupModules.x + groupModules.width)
      readonly property real leadSpill: centerRoot.hasAnchor
        ? ((root.vertical ? beforeModules.height : beforeModules.width) > 0 ? beforeModules.leadSpill : centerAnchorModule.cellSpill) : groupModules.leadSpill
      readonly property real trailSpill: centerRoot.hasAnchor
        ? ((root.vertical ? afterModules.height : afterModules.width) > 0 ? afterModules.trailSpill : centerAnchorModule.cellSpill) : groupModules.trailSpill
      x: root.vertical ? (parent.width - width) / 2 : start - root.islandEnd("center", leadSpill)
      y: root.vertical ? start - root.islandEnd("center", leadSpill) : (parent.height - height) / 2
      width: root.vertical ? root.barSize : end - start + root.islandEnd("center", leadSpill) + root.islandEnd("center", trailSpill)
      height: root.vertical ? end - start + root.islandEnd("center", leadSpill) + root.islandEnd("center", trailSpill) : root.barSize
      visible: root.islands && end > start
    }
    CenterGestureArea { anchors.fill: parent }
    HighlightLayer { zone: "center"; island: centerIsland }
    Item {
      x: root.vertical ? 0 : centerIsland.x
      y: root.vertical ? centerIsland.y : 0
      width: root.vertical ? parent.width : Math.max(0, centerIsland.width)
      height: root.vertical ? Math.max(0, centerIsland.height) : parent.height
      HoverHandler {
        onHoveredChanged: root.setCenterSectionHovered(hovered)
        Component.onDestruction: if (hovered) root.setCenterSectionHovered(false)
      }
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
    width: root.vertical ? Math.max(root.barSize, contents.width) : startGap.width + contents.width + endGap.width
    height: root.vertical ? startGap.height + contents.height + endGap.height : Math.max(root.barSize, contents.height)
    readonly property real leadSpill: previewStartGap && root.barDragSource ? root.barDragSource.cellSpill : root.edgeSpill(contents, false)
    readonly property real trailSpill: previewEndGap && root.barDragSource ? root.barDragSource.cellSpill : root.edgeSpill(contents, true)
    AnimatedSlot {
      id: startGap
      targetWidth: root.vertical ? root.barSize : moduleListRoot.previewStartGap ? root.dragGapWidth : 0
      targetHeight: !root.vertical ? root.barSize : moduleListRoot.previewStartGap ? root.dragGapHeight : 0
      DropOutline { gapLength: root.vertical ? parent.height : parent.width }
      motionEnabled: root.animationsEnabled
      motionDuration: root.dragMotionDuration; motionEasing: root.dragMotionEasing
    }
    Grid {
      id: contents
      x: root.vertical ? 0 : startGap.width
      y: root.vertical ? startGap.height : 0
      // Only columns follows orientation (rows stays automatic), so a switch
      // never passes through a 1 × 1 grid.
      columns: root.vertical ? 1 : 100000
      spacing: 0
      Repeater { model: moduleListRoot.slotModel }
    }
    AnimatedSlot {
      id: endGap
      x: root.vertical ? 0 : contents.x + contents.width
      y: root.vertical ? contents.y + contents.height : 0
      targetWidth: root.vertical ? root.barSize : moduleListRoot.previewEndGap ? root.dragGapWidth : 0
      targetHeight: !root.vertical ? root.barSize : moduleListRoot.previewEndGap ? root.dragGapHeight : 0
      DropOutline { gapLength: root.vertical ? parent.height : parent.width }
      motionEnabled: root.animationsEnabled
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
      return w[registryName] ? w[registryName].component : null
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
    readonly property string visibilityMode: ManagedModel.mode(entry, registryMetadata || (customType ? { firstParty: false } : null))
    readonly property bool managed: visibilityMode === "managed"
    readonly property bool alwaysShown: visibilityMode === "shown"
    property var slotTargets: []
    property var drawerHost: null
    property alias presentationItem: presentation
    property alias highlightItem: barHighlight
    property bool activityVisible: false
    property real activityUntil: 0
    readonly property bool mainVisible: !memberGroup && (alwaysShown || (managed && !drawerHost && (activityVisible || panelOpen || hovered)))
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
    onManagedChanged: syncActivity()
    Timer { id: activityExpiry; repeat: false; onTriggered: slot.activityVisible = false }
    // Highlighted like a hover while an autohidden bar shows it for activity.
    property bool activityFlash: false
    function flashActivity() { activityFlash = true; flashEnd.restart() }
    Timer { id: flashEnd; interval: root.autoHidePeekMs; onTriggered: slot.activityFlash = false }
    Repeater {
      model: slot.activityTargets
      ActivityObserver {
        required property var modelData
        target: modelData
        readonly property bool reveals: slot.managed || !!(slot.memberGroup && slot.memberGroup.visibility === "managed")
        enabledForActivity: reveals || (root.autoHide && root.autoHideActivity && root.activityPeeksFor(slot.instanceKey, slot.moduleName))
        onActivity: {
          if (root.reconcilingStructure) return
          if (reveals) root.reportActivity(slot.instanceKey)
          root.autoHidePeek(slot)
        }
      }
    }
    readonly property string displayName: registryMetadata && (registryMetadata.displayName || registryMetadata.name)
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
    readonly property bool needsPlaceholder: (alwaysShown || managed) && (!activeItem || !activeItem.visible || activeItem.opacity === 0 || activeItem.implicitWidth <= 0 || activeItem.implicitHeight <= 0)
    // The widget's own box; drawers and drag images use it as is.
    readonly property real naturalWidth: needsPlaceholder ? root.barSize : activeItem && activeItem.visible ? (root.vertical ? root.barSize : activeItem.implicitWidth) : 0
    readonly property real naturalHeight: needsPlaceholder ? root.barSize : activeItem && activeItem.visible ? activeItem.implicitHeight : 0
    // The cell: what the widget visibly paints along the bar decides its slot
    // and its highlight, never the box it asks for.
    readonly property Item inkItem: needsPlaceholder ? placeholderButton : activeItem
    readonly property var ink: naturalWidth > 0 && naturalHeight > 0 && inkItem
      ? HighlightModel.inkRect(inkItem, root.vertical) : ({ start: 0, length: 0, glyph: false })
    readonly property var crossInk: root.vertical && naturalWidth > 0 && inkItem ? HighlightModel.inkRect(inkItem, false) : null
    readonly property var cellPlace: CellModel.place(root.cellTokens, ink.length, CellModel.isGlyph(ink.length, ink.glyph))
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
    function updateHold() {
      if (!root) return
      var target = landingExtent
      var relayout = heldLayout !== holdLayout
      heldLayout = holdLayout
      // A widget that animates its own width (the tray's reveal) opts out:
      // holding would leave its island wide after it closes.
      var holds = !(activeItem && activeItem.powerbarWidthHold === false)
      if (!(target > 0) || !mainVisible || !holdArmed || relayout || !holds) { heldExtent = target; shrinkAt = 0; holdTimer.stop(); return }
      var now = Date.now()
      var h = CellModel.hold(heldExtent, target, now, root.widthHoldMs, shrinkAt, root.cellTokens.cell)
      heldExtent = h.value
      shrinkAt = h.shrinkAt
      if (shrinkAt > 0) { holdTimer.interval = Math.max(1, shrinkAt - now); holdTimer.restart() } else holdTimer.stop()
    }
    // Deferred: a widget's size can change while its cell is being measured.
    onLandingExtentChanged: Qt.callLater(updateHold)
    onMainVisibleChanged: Qt.callLater(updateHold)
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
    targetWidth: root.vertical ? naturalWidth : mainVisible && (!preview.hidden || preview.holdSpace)
      ? cellExtent + settleExtraWidth + (!centerAnchorSlot && (preview.before || preview.after) ? root.dragGapWidth : 0) : 0
    // Across a horizontal bar every slot is at least the bar's thickness and the
    // widget's box is centred in it, so a widget shorter than the bar (the Agent
    // Orchestrator reports 27 px on a 38 px bar) never sits at the top.
    readonly property real crossLength: naturalHeight > 0 ? Math.max(naturalHeight, root.barSize) : 0
    readonly property real crossCentre: (crossLength - naturalHeight) / 2
    targetHeight: !root.vertical ? crossLength : mainVisible && (!preview.hidden || preview.holdSpace)
      ? cellExtent + settleExtraHeight + (!centerAnchorSlot && (preview.before || preview.after) ? root.dragGapHeight : 0) : 0
    targetInsetX: !root.vertical && !centerAnchorSlot && preview.before ? root.dragGapWidth : 0
    targetInsetY: root.vertical && !centerAnchorSlot && preview.before ? root.dragGapHeight : 0
    motionEnabled: root.animationsEnabled && !drawerHost
    motionDuration: root.dragMotionActive ? root.dragMotionDuration : 120
    motionEasing: root.dragMotionActive ? root.dragMotionEasing : Easing.OutCubic
    motionOvershoot: 0
    z: modulePointer.dragging ? 100 : 0

    // The whole slot, gutters included, is the widget's hover area on the bar.
    HoverHandler {
      id: slotHover
      enabled: slot.mainVisible && !root.barHidden && !preferencesPane.opened && !root.barDragSource
      onHoveredChanged: {
        var window = root.targetWindow(slot)
        if (!window || !window.managedDrawer) return
        if (hovered && slot.groupHeader) window.managedDrawer.sourceEnterGroup(slot.entry.powerbarGroupId, slot)
        else if (hovered) window.managedDrawer.sourceEnter(slot.region)
        else window.managedDrawer.sourceLeave(slot.region)
      }
    }

    Component.onCompleted: { root.registerModuleSlot(slot); syncActivity(); Qt.callLater(updateHold) }
    Component.onDestruction: {
      if (root.barDragSource === slot) root.clearBarDrag()
      root.unregisterModuleSlot(slot)
    }

    DropOutline {
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
      x: slot.drawerHost ? slot.drawerHost.contentOffsetX : slot.animatedInsetX + (root.vertical ? slot.crossShift : slot.inkShift)
      y: slot.drawerHost ? slot.drawerHost.contentOffsetY : slot.animatedInsetY + (root.vertical ? slot.inkShift : slot.crossCentre)
      width: slot.naturalWidth
      height: slot.naturalHeight
      opacity: slot.drawerHost ? (slot.drawerHost.showNative === false ? 0 : 1) : slot.mainVisible && !slot.preview.hidden && !slot.settleHidden ? 1 : 0
      enabled: !!slot.drawerHost || slot.mainVisible
    DragHandler {
      id: drawerDrag
      target: null
      enabled: !!slot.drawerHost && slot.drawerHost.showNative !== false
      acceptedButtons: Qt.LeftButton
      property point lastScene
      onCentroidChanged: if (active) { lastScene = centroid.scenePosition; root.updateIconDrag(lastScene, slot) }
      onActiveChanged: {
        if (active) {
          lastScene = centroid.scenePosition
          root.beginIconDrag(slot, root.targetWindow(slot), lastScene,
            (presentation.x + centroid.position.x) * root.barScale,
            (presentation.y + centroid.position.y) * root.barScale)
        } else if (root.barDragSource === slot) {
          root.finishIconDrag(lastScene, slot)
        }
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
      tooltipText: slot.displayName + " is inactive. " + (slot.canActivate() ? "Click to open it." : "Click to set it up.")
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
    HoverHighlight {
      id: barHighlight
      readonly property var hostWindow: root.targetWindow(slot)
      readonly property Item hostLayer: hostWindow && hostWindow.highlightLayers ? hostWindow.highlightLayers[slot.region] || null : null
      parent: hostLayer || presentation
      hovered: (slot.hovered || slot.activityFlash || slot.preview.into) && slot.mainVisible && !slot.dragSource && !root.barHidden && !preferencesPane.opened
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
      Repeater {
        model: barHighlight.hovered && !barHighlight.selected && !slot.activityFlash ? compoundThumb.targets : []
        GeometryObserver {
          required property var modelData
          target: modelData
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
      readonly property bool canReorder: root.shell && typeof root.shell.mutateShellConfig === "function"
      readonly property real dragThreshold: Style.space(4)

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      enabled: root.barDragSource === slot || (slot.mainVisible && slot.visible && slot.width > 0 && slot.height > 0)
      propagateComposedEvents: true
      cursorShape: dragging ? Qt.ClosedHandCursor
        : root.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
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
              (pressedX - presentation.x) * root.barScale, (pressedY - presentation.y) * root.barScale)
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
    onActiveItemChanged: Qt.callLater(injectProps)
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
        // Nothing grows across a vertical bar: a text face wider than the
        // highlight shows the group's glyph there.
        readonly property string face: root.vertical && preferredFace !== "glyph"
          && labelMetrics.width > root.cellTokens.thickness ? "glyph" : preferredFace
        readonly property var badge: group ? root.groupBadge(group.id, root.targetWindow(slot)) : ({ count: 0, urgent: false })
        text: !group ? "󰉋" : face === "text" ? group.label
          : face === "both" ? group.icon + "  " + group.label : group.icon
        fontFamily: face === "glyph" ? (GroupsModel.iconFont(text) || Style.font.family) : Style.font.family
        TextMetrics {
          id: labelMetrics
          font.family: Style.font.family
          font.pixelSize: groupButton.fontSize
          text: groupButton.preferredFace === "both" && group ? group.icon + "  " + group.label : group ? group.label : ""
        }
        tooltipText: group && (group.tooltip === undefined ? face === "glyph" : group.tooltip)
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
