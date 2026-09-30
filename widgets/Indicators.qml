import QtQuick
import QtQml.Models as Models
import ".."
import "../RenderModel.js" as RenderModel
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.indicators"

  readonly property var defaultIndicatorEntries: [ "Dictation", "ScreenRecording", "Reminder", "NightLight", "Dnd", "StayAwake" ]
  readonly property var indicatorEntries: indicatorEntriesFromSettings(settings)
  property var activeIndicatorIds: []
  property var indicatorActiveStates: ({})
  property bool indicatorAreaHovered: false
  property bool indicatorItemHovered: false
  readonly property bool alwaysShowIndicators: setting("alwaysShow", false) === true
  // Revealing the inactive indicators is this widget's own expansion, not a
  // value that flickers, so Powerbar's width hold must not keep it open.
  readonly property bool powerbarWidthHold: false
  readonly property bool revealInactiveIndicators: alwaysShowIndicators || indicatorAreaHovered || indicatorItemHovered || (bar && bar.centerSectionRevealHeld === true && bar.centerHoverRevealSuppressed !== true)

  signal refreshRequested()

  function entryId(entry) {
    if (typeof entry === "string") return entry
    if (Util.isPlainObject(entry)) {
      var id = entry["id"]
      if (id !== undefined && id !== null && String(id) !== "") return String(id)
    }
    return ""
  }

  function entrySettings(entry) {
    if (!Util.isPlainObject(entry)) return {}
    var copy = {}
    for (var key in entry) {
      if (key === "id") continue
      copy[key] = entry[key]
    }
    return copy
  }

  function indicatorEntriesFromSettings(settings) {
    var source = defaultIndicatorEntries
    if (settings.items && typeof settings.items.length === "number" && settings.items.length > 0) source = settings.items
    else if (settings.indicators && typeof settings.indicators.length === "number" && settings.indicators.length > 0) source = settings.indicators

    var result = []
    for (var i = 0; i < source.length; i++) {
      var item = source[i]
      if (typeof item !== "string" && item !== null && typeof item === "object") {
        try {
          item = JSON.parse(JSON.stringify(item))
        } catch (error) {
        }
      }
      var id = entryId(item)
      if (id !== "") result.push(item)
    }
    return result
  }

  function setIndicatorAreaHovered(hovered) {
    indicatorAreaHovered = hovered
    if (hovered) indicatorHideTimer.stop()
    else indicatorHideTimer.restart()
  }

  function setIndicatorItemHovered(hovered) {
    if (hovered) {
      indicatorItemHovered = true
      indicatorHideTimer.stop()
    } else {
      indicatorHideTimer.restart()
    }
  }

  function hasIndicatorId(id) {
    for (var i = 0; i < indicatorEntries.length; i++) {
      if (entryId(indicatorEntries[i]) === id) return true
    }
    return false
  }

  function entryForId(id) {
    for (var i = 0; i < indicatorEntries.length; i++) {
      var entry = indicatorEntries[i]
      if (entryId(entry) === id) return entry
    }

    return { id: id }
  }

  function copyActiveStates() {
    var states = {}
    for (var id in indicatorActiveStates) {
      if (indicatorActiveStates[id] === true) states[id] = true
    }
    return states
  }

  function orderedActiveIds(states, preferredOrder) {
    var ids = []

    for (var i = 0; i < preferredOrder.length; i++) {
      var id = preferredOrder[i]
      if (ids.indexOf(id) === -1 && hasIndicatorId(id) && states[id] === true) ids.push(id)
    }

    return ids
  }

  function setIndicatorActive(entry, active) {
    var id = entryId(entry)
    if (id === "") return

    if ((indicatorActiveStates[id] === true) === active) return
    var states = copyActiveStates()
    if (active) states[id] = true
    else delete states[id]

    indicatorActiveStates = states

    var ids = orderedActiveIds(states, activeIndicatorIds)
    // The active block sits closest to the clock, so newcomers go on the far
    // side of it. Appending would shove everything already showing sideways.
    if (active && ids.indexOf(id) === -1 && hasIndicatorId(id)) ids.unshift(id)
    activeIndicatorIds = ids
  }

  function syncActiveIndicatorOrder() {
    activeIndicatorIds = orderedActiveIds(indicatorActiveStates, activeIndicatorIds)
  }

  function refresh() {
    root.refreshRequested()
    if (bar && bar.refreshIndicatorStates) bar.refreshIndicatorStates()
  }

  onIndicatorEntriesChanged: { syncActiveIndicatorOrder(); Qt.callLater(reconcileIndicators) }
  onActiveIndicatorIdsChanged: Qt.callLater(reconcileIndicators)

  implicitWidth: root.vertical ? Math.max(activeBlock.width, inactiveArea.width) : activeBlock.width + inactiveArea.width
  implicitHeight: root.vertical ? activeBlock.height + inactiveArea.height : Math.max(activeBlock.height, inactiveArea.height)

  IpcHandler {
    target: "omarchy.indicators"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Timer {
    id: indicatorHideTimer
    interval: 120
    onTriggered: {
      if (!root.indicatorAreaHovered)
        root.indicatorItemHovered = false
    }
  }

  Component.onCompleted: { reconcileIndicators(); refresh() }

  Models.ObjectModel { id: inactiveObjects }
  Models.ObjectModel { id: activeObjects }
  RetainedStore {
    id: indicatorStore
    recordProperty: "retainedRecord"
    factory: Component {
      IndicatorLoader {
        required property var retainedRecord
        entry: retainedRecord.entry
        indicatorsModule: root
        indicatorBlock: root.activeIndicatorIds.indexOf(indicatorId) >= 0 ? "active" : "inactive"
        reportActiveState: true
      }
    }
  }
  function reconcileIndicators() {
    var counts = ({})
    var records = indicatorEntries.map(function(entry) {
      var id = entryId(entry), occurrence = counts[id] || 0
      counts[id] = occurrence + 1
      return { key: id + ":" + occurrence, entry: entry }
    })
    indicatorStore.reconcile(records)
    var inactive = records.filter(function(r) { return activeIndicatorIds.indexOf(entryId(r.entry)) < 0 })
      .map(function(r) { return indicatorStore.get(r.key) })
    var active = activeIndicatorIds.map(function(id) { return indicatorStore.get(id + ":0") }).filter(function(item) { return !!item })
    RenderModel.reconcileLists([inactiveObjects, activeObjects], [inactive, active], indicatorStore)
    indicatorStore.sweep()
  }

  Item {
    id: inactiveArea
    width: root.vertical ? Math.max(inactiveBlock.width, root.barSize) : root.revealInactiveIndicators ? inactiveBlock.width : 0
    height: root.vertical ? root.revealInactiveIndicators ? inactiveBlock.height : 0 : Math.max(inactiveBlock.height, root.barSize)
    clip: true
    Grid {
      id: inactiveBlock
      // x/y rather than centre anchors switched by orientation, which would
      // leave the other axis where the previous orientation put it.
      x: root.vertical ? (parent.width - width) / 2 : 0
      y: root.vertical ? 0 : (parent.height - height) / 2
      columns: root.vertical ? 1 : 100000
      spacing: 0
      Repeater { model: inactiveObjects }
    }
    HoverHandler { onHoveredChanged: root.setIndicatorAreaHovered(hovered) }
  }
  Grid {
    id: activeBlock
    x: root.vertical ? 0 : inactiveArea.width
    y: root.vertical ? inactiveArea.height : 0
    columns: root.vertical ? 1 : 100000
    spacing: 0
    Repeater { model: activeObjects }
  }
  HoverHandler { onHoveredChanged: root.setIndicatorAreaHovered(hovered) }

  component IndicatorLoader: Item {
    id: indicatorSlot

    required property var entry
    property var indicatorsModule: null
    required property string indicatorBlock
    property bool reportActiveState: false
    readonly property string indicatorId: root.entryId(entry)
    readonly property var indicatorSettings: root.entrySettings(entry)
    readonly property var barRef: root.bar

    implicitWidth: indicatorSource.item && indicatorSource.item.visible ? indicatorSource.item.implicitWidth : 0
    implicitHeight: indicatorSource.item && indicatorSource.item.visible ? indicatorSource.item.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight
    onEntryChanged: {
      injectProps()
      syncActiveState()
    }
    onIndicatorBlockChanged: injectProps()
    onIndicatorSettingsChanged: injectProps()
    onIndicatorsModuleChanged: {
      injectProps()
      syncActiveState()
    }
    onReportActiveStateChanged: syncActiveState()
    onBarRefChanged: injectProps()

    Loader {
      id: indicatorSource

      anchors.fill: parent
      source: indicatorSlot.indicatorId ? Qt.resolvedUrl("../indicators/" + indicatorSlot.indicatorId + ".qml") : ""
      onLoaded: {
        indicatorSlot.injectProps()
        indicatorSlot.syncActiveState()
      }
      onStatusChanged: if (status === Loader.Error) console.warn("Indicator loader error", indicatorSlot.indicatorId, source)
    }

    Connections {
      target: indicatorSource.item
      ignoreUnknownSignals: true
      function onActiveChanged() { indicatorSlot.syncActiveState() }
    }

    function injectProps() {
      var target = indicatorSource.item
      if (!target) return
      if ("bar" in target) target.bar = root.bar
      if ("moduleName" in target) target.moduleName = indicatorId
      if ("settings" in target) target.settings = indicatorSettings
      if ("indicatorBlock" in target) target.indicatorBlock = indicatorBlock
      if ("indicatorHost" in target) target.indicatorHost = root
      if ("activeOverride" in target) target.activeOverride = null
    }

    function syncActiveState() {
      if (!reportActiveState || !indicatorsModule || !indicatorsModule.setIndicatorActive) return

      var active = !!indicatorSource.item && indicatorSource.item.active === true
      indicatorsModule.setIndicatorActive(entry, active)
    }
  }
}
