import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "ManagedModel.js" as Model
import "DragModel.js" as DragModel

// Lives in the bar's window: widgets keep the same QsWindow and popup anchors.
Item {
  id: drawer
  required property var bar
  required property var hostWindow
  property bool opened: false
  property bool instantClose: false
  property bool replaying: false
  property real reveal: 0
  property int transitionEpoch: 0
  property real closingLength: thickness
  readonly property bool presenting: opened || reveal > 0.001
  onPresentingChanged: if (!presenting && bar.managedOwner === drawer) bar.managedOwner = null
  Behavior on reveal {
    enabled: bar.animationsEnabled && !drawer.instantClose && !drawer.replaying
    // Drawers open a few dozen times a day: quick, a strong ease-out both
    // ways, and closing faster than opening.
    NumberAnimation {
      duration: drawer.opened ? 160 : 110
      easing.type: Easing.BezierSpline
      easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }
  }
  opacity: Math.max(0, Math.min(1, reveal))
  transform: Scale {
    origin.x: bar.vertical ? (bar.position === "left" ? 0 : drawer.width) : drawer.zone === "left" ? 0 : drawer.zone === "right" ? drawer.width : drawer.width / 2
    origin.y: !bar.vertical ? (bar.position === "top" ? 0 : drawer.height) : drawer.zone === "left" ? 0 : drawer.zone === "right" ? drawer.height : drawer.height / 2
    // Grows out of its edge from nearly full size; nothing appears from nothing.
    xScale: (bar.vertical ? 0.94 : 0.98) + (bar.vertical ? 0.06 : 0.02) * Math.max(0, drawer.reveal)
    yScale: (bar.vertical ? 0.98 : 0.94) + (bar.vertical ? 0.02 : 0.06) * Math.max(0, drawer.reveal)
  }
  property bool grabReady: false
  onOpenedChanged: {
    grabReady = false
    if (opened) grabDelay.restart()
    else grabDelay.stop()
  }
  Timer { id: grabDelay; interval: 250; onTriggered: drawer.grabReady = drawer.opened }
  property string zone: ""
  property string groupId: ""
  readonly property var groupConfig: bar.groups.find(function(g) { return g.id === groupId }) || null
  readonly property string surfaceRole: Model.drawerSurface(groupConfig)
  readonly property bool namedMenu: surfaceRole === "menu"
  readonly property real surfaceRadius: namedMenu ? Style.cornerRadius : bar.islandRounding
  readonly property bool stripVertical: Model.drawerVertical(groupConfig, bar.vertical)
  readonly property string memberDisplay: groupConfig ? groupConfig.memberDisplay : "native"
  function memberTitle(slot) {
    if (!slot) return ""
    var metadata = bar.barWidgetRegistry.metadataFor(bar.canonicalWidgetId(slot.moduleName)) || {}
    return metadata.displayName || slot.moduleName.split(".").pop()
  }
  FontMetrics {
    id: menuMetrics
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
  }
  readonly property real menuRowWidth: {
    if (!namedMenu) return 0
    var width = Style.space(72)
    for (var slot of slots) {
      var labelStart = Model.menuLabelStart(memberDisplay === "both", slot.naturalWidth, Style.space(8), Style.space(2))
      width = Math.max(width, labelStart + menuMetrics.advanceWidth(memberTitle(slot)) + Style.space(8))
    }
    return Math.min(width, Style.space(320))
  }
  property var anchorSlot: null
  property real anchorCenter: -1
  property string suppressedZone: ""
  property bool sourceHovered: false
  property bool entered: false
  property bool keyboardMode: false
  property int cursor: 0
  property bool cursorActive: false
  readonly property bool selectionVisible: Model.cursorVisible(keyboardMode, cursorActive, slots.length)
  readonly property bool containsMouse: hover.hovered
  readonly property var slots: presenting ? (groupId ? bar.groupSlots(groupId, hostWindow) : bar.managedSlots(zone, hostWindow)) : []
  readonly property bool interactionHeld: keyboardMode || bar.dragMotionActive || slots.some(function(slot) { return slot.panelOpen })
  readonly property real padding: Style.space(6)
  readonly property real gap: Style.space(6)
  readonly property real thickness: bar.renderedBarSize
  readonly property real extent: opened ? thickness + gap : 0
  readonly property real axisExtent: bar.vertical ? hostWindow.height : hostWindow.width
  readonly property real desiredLength: (bar.vertical ? grid.height : grid.width) * bar.barScale + padding * 2
  readonly property real desiredCross: (bar.vertical ? grid.width : grid.height) * bar.barScale + padding * 2
  readonly property bool wideCross: namedMenu
  readonly property real crossLength: wideCross
    ? Math.min(Math.max(thickness, desiredCross), hostWindow.drawerExtent - gap - Style.space(8)) : thickness
  readonly property real length: opened ? Math.min(Math.max(thickness, desiredLength), Math.max(thickness, axisExtent - Style.space(16))) : closingLength
  readonly property real paintedLength: bar.vertical ? height : width
  readonly property real axisPosition: {
    var desired = zone === "left" ? Style.space(8) : zone === "right" ? axisExtent - paintedLength - Style.space(8) : (axisExtent - paintedLength) / 2
    if (anchorCenter >= 0) desired = anchorCenter - paintedLength / 2
    else if (anchorSlot) {
      var geometry = anchorSlot.x + anchorSlot.y + anchorSlot.width + anchorSlot.height
      var point = anchorSlot.mapToItem(hostWindow.contentItem, anchorSlot.width / 2, anchorSlot.height / 2)
      desired = (bar.vertical ? point.y : point.x) - paintedLength / 2
    }
    return Math.max(Style.space(8), Math.min(desired, axisExtent - paintedLength - Style.space(8)))
  }
  width: bar.vertical ? crossLength : length
  height: bar.vertical ? length : crossLength
  x: bar.vertical ? (bar.position === "left" ? bar.barExtent + gap : hostWindow.drawerExtent - gap - width) : axisPosition
  y: bar.vertical ? axisPosition : (bar.position === "top" ? bar.barExtent + gap : hostWindow.drawerExtent - gap - height)
  visible: presenting
  enabled: opened
  focus: opened && keyboardMode

  function openZone(nextZone, keyboard, nextGroup, nextAnchor) {
    nextGroup = nextGroup || ""
    if (bar.barHidden || (nextGroup ? bar.groupSlots(nextGroup, hostWindow) : bar.managedSlots(nextZone, hostWindow)).length === 0) return
    if (!keyboard && suppressedZone === nextZone) return
    if (keyboard) suppressedZone = ""
    if (bar.managedOwner && bar.managedOwner !== drawer) bar.managedOwner.close("immediate")
    var changingZone = opened && (zone !== nextZone || groupId !== nextGroup)
    if (changingZone && slots.some(function(slot) { return slot.panelOpen })) {
      if (bar.activePopout && typeof bar.activePopout.close === "function") bar.activePopout.close()
    }
    var needsReveal = !opened || changingZone
    if (needsReveal) {
      replaying = true
      reveal = 0
    }
    if (changingZone || !opened) { entered = false; cursor = 0; sourceHovered = false }
    cursorActive = false
    zone = nextZone
    groupId = nextGroup
    anchorSlot = nextAnchor || null
    anchorCenter = -1
    keyboardMode = keyboard === true
    instantClose = false
    opened = true
    bar.managedOwner = drawer
    if (needsReveal) {
      var epoch = ++transitionEpoch
      // Mount widgets and update the main bar before the opening motion.
      Qt.callLater(function() {
        if (!drawer.opened || drawer.transitionEpoch !== epoch) return
        drawer.replaying = false
        drawer.reveal = 1
      })
    }
    dismissal.stop()
    if (keyboardMode) Qt.callLater(function() { drawer.forceActiveFocus() })
  }
  function openGroup(id, slot, keyboard) {
    // A managed group header returns to its hidden main slot when switching
    // drawers. Keep the clicked position as the anchor during that switch.
    var fromDrawer = !!slot.drawerHost
    var item = slot.presentationItem
    var point = fromDrawer ? item.mapToItem(hostWindow.contentItem, item.width / 2, item.height / 2) : null
    openZone(slot.region, keyboard, id, fromDrawer ? null : slot)
    if (point && groupId === id) anchorCenter = bar.vertical ? point.y : point.x
  }
  function toggleGroup(id, slot) {
    if (opened && groupId === id && keyboardMode) close()
    else openGroup(id, slot, true)
  }
  function sourceEnterGroup(id, slot) {
    if (opened && groupId === id && keyboardMode) { sourceHovered = true; return }
    openGroup(id, slot, false)
    if (opened && groupId === id) { sourceHovered = true; dismissal.stop() }
  }
  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (error) {}
    openZone(["left", "center", "right"].indexOf(payload.zone) >= 0 ? payload.zone : "center", true)
  }
  function close(reason) {
    dismissal.stop()
    ++transitionEpoch
    replaying = false
    instantClose = reason === "immediate"
    // Only explicit dismissal under the pointer waits for a fresh hover.
    // A timed dismissal must never lock out the next entry.
    suppressedZone = reason !== "timeout" && sourceHovered ? zone : ""
    closingLength = paintedLength
    // Keep widget presentations in the drawer until the contraction ends.
    // The presenting binding releases them back to the main bar afterward.
    opened = false
    reveal = 0
    if (instantClose) {
      // A second close during the exit animation must finish immediately,
      // before a main-bar action opens a popup against the restored layout.
      reveal = 0
    }
    keyboardMode = false
    cursorActive = false
    sourceHovered = false
    entered = false
    if (!presenting && bar.managedOwner === drawer) bar.managedOwner = null
  }
  function sourceEnter(nextZone) {
    if (opened && keyboardMode) {
      sourceHovered = zone === nextZone
      return
    }
    openZone(nextZone, false)
    if (opened && zone === nextZone) { sourceHovered = true; dismissal.stop() }
  }
  function sourceLeave(nextZone) {
    if (suppressedZone === nextZone) suppressedZone = ""
    if (zone !== nextZone) return
    sourceHovered = false
    scheduleDismissal()
  }
  function scheduleDismissal() {
    dismissal.stop()
    if (!opened) return
    var delay = Model.dismissDelay(sourceHovered, containsMouse, interactionHeld, entered, bar.managedEntrySeconds, bar.managedExitSeconds)
    if (delay > 0) { dismissal.interval = delay; dismissal.start() }
  }
  onContainsMouseChanged: {
    if (containsMouse) entered = true
    scheduleDismissal()
  }
  onInteractionHeldChanged: scheduleDismissal()
  onSlotsChanged: if (opened && slots.length === 0) close()
  Component.onDestruction: if (bar.managedOwner === drawer) bar.managedOwner = null
  Timer { id: dismissal; repeat: false; onTriggered: drawer.close("timeout") }

  function navigate(delta) {
    if (!slots.length) return
    cursor = cursorActive ? (cursor + delta + slots.length) % slots.length : delta > 0 ? 0 : slots.length - 1
    cursorActive = true
    var cell = widgets.itemAt(cursor)
    if (!cell) return
    var start = (drawer.stripVertical ? cell.y : cell.x) * bar.barScale
    var size = (drawer.stripVertical ? cell.height : cell.width) * bar.barScale
    var offset = drawer.stripVertical ? viewport.contentY : viewport.contentX
    var span = drawer.stripVertical ? viewport.height : viewport.width
    var next = start < offset ? start : start + size > offset + span ? start + size - span : offset
    if (drawer.stripVertical) viewport.contentY = next
    else viewport.contentX = next
  }
  Keys.onEscapePressed: close()
  Keys.onTabPressed: navigate(1)
  Keys.onBacktabPressed: navigate(-1)
  Keys.onLeftPressed: navigate(-1)
  Keys.onUpPressed: navigate(-1)
  Keys.onRightPressed: navigate(1)
  Keys.onDownPressed: navigate(1)
  Keys.onReturnPressed: if (slots[cursor]) slots[cursor].activate()
  Keys.onSpacePressed: if (slots[cursor]) slots[cursor].activate()

  EffectSurface {
    anchors.fill: parent
    color: bar.extendedSurfaceColor
    shadowEnabled: bar.extendedEffects.shadow
    shadowSize: bar.extendedEffects.shadowSize
    shadowOpacity: bar.extendedEffects.shadowOpacity
    radius: drawer.surfaceRadius
    // Bar specs compensate for barScale; this surface is in screen pixels.
    borderSpec: {
      var spec = JSON.parse(JSON.stringify(bar.islandBorder))
      for (var side in spec.widths) spec.widths[side] *= bar.barScale
      return spec
    }
  }
  HoverHandler { id: hover }
  Flickable {
    id: viewport
    anchors.fill: parent
    // Match the main bar's cross-axis size; pad only the ends of the row.
    anchors.leftMargin: drawer.namedMenu || !bar.vertical ? drawer.padding : 0
    anchors.rightMargin: drawer.namedMenu || !bar.vertical ? drawer.padding : 0
    anchors.topMargin: drawer.namedMenu || bar.vertical ? drawer.padding : 0
    anchors.bottomMargin: drawer.namedMenu || bar.vertical ? drawer.padding : 0
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: grid.width * bar.barScale
    contentHeight: grid.height * bar.barScale
    flickableDirection: drawer.stripVertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
    Controls.ScrollBar.horizontal: Controls.ScrollBar { policy: !drawer.stripVertical && viewport.contentWidth > viewport.width ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: drawer.stripVertical && viewport.contentHeight > viewport.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
    Item {
      id: grid
      implicitWidth: drawer.stripVertical ? Math.max(contents.width, drawer.thickness) : contents.width + endGap.width
      implicitHeight: drawer.stripVertical ? contents.height + endGap.height : Math.max(contents.height, drawer.thickness)
      scale: bar.barScale
      transformOrigin: Item.TopLeft
      Grid {
        id: contents
        columns: drawer.stripVertical ? 1 : Math.max(1, drawer.slots.length)
        spacing: Style.space(4) / bar.barScale
        Repeater {
          id: widgets
          model: drawer.slots
          AnimatedSlot {
            id: mount
            required property var modelData
            required property int index
            readonly property string title: modelData ? (bar.barWidgetRegistry.metadataFor(bar.canonicalWidgetId(modelData.moduleName)) || {}).displayName || modelData.moduleName.split(".").pop() : ""
            readonly property bool labelled: drawer.memberDisplay !== "native" && drawer.groupId !== ""
            readonly property bool showNative: drawer.memberDisplay !== "name"
            readonly property var preview: modelData
              ? DragModel.slot(bar.dragPreview, modelData.instanceKey, bar.dragSurfaceForDrawer(drawer))
              : ({ hidden: false, before: false, after: false })
            readonly property real baseWidth: !modelData ? 0 : drawer.namedMenu ? drawer.menuRowWidth
              : labelled ? (showNative ? modelData.naturalWidth + Style.space(6) : 0)
                + label.implicitWidth + Style.space(12) : modelData.naturalWidth
            readonly property real baseHeight: modelData ? Math.max(modelData.naturalHeight, drawer.thickness) : 0
            readonly property real contentOffsetX: animatedInsetX
            readonly property real contentOffsetY: animatedInsetY
            targetWidth: preview.hidden && !preview.holdSpace && !drawer.stripVertical ? 0
              : baseWidth + (!drawer.stripVertical && (preview.before || preview.after) ? bar.dragGapWidth : 0)
            targetHeight: preview.hidden && !preview.holdSpace && drawer.stripVertical ? 0
              : baseHeight + (drawer.stripVertical && (preview.before || preview.after) ? bar.dragGapHeight : 0)
            targetInsetX: !drawer.stripVertical && preview.before ? bar.dragGapWidth : 0
            targetInsetY: drawer.stripVertical && preview.before ? bar.dragGapHeight : 0
            motionEnabled: bar.animationsEnabled && drawer.opened && !drawer.replaying
            motionDuration: bar.dragMotionActive ? bar.dragMotionDuration : 120
            motionEasing: bar.dragMotionActive ? bar.dragMotionEasing : Easing.OutCubic
            motionOvershoot: 0
            opacity: preview.hidden || (modelData && modelData.settleHidden) ? 0 : 1
            Component.onCompleted: if (modelData) modelData.drawerHost = mount
            Component.onDestruction: if (modelData && modelData.drawerHost === mount) modelData.drawerHost = null
            HoverHandler {
              id: memberHover
              enabled: drawer.opened && !bar.barDragSource
            }
            HoverHighlight {
              x: mount.contentOffsetX + bar.highlightInset(mount.baseHeight) * (drawer.namedMenu || mount.labelled ? 1 : 0)
              y: mount.contentOffsetY + bar.highlightInset(mount.baseHeight)
              width: mount.baseWidth - bar.highlightInset(mount.baseHeight) * (drawer.namedMenu || mount.labelled ? 2 : 0)
              height: mount.baseHeight - bar.highlightInset(mount.baseHeight) * 2
              z: -1
              hovered: memberHover.hovered && drawer.opened && !bar.barDragSource && !preview.hidden
              motionEnabled: bar.animationsEnabled
              hoverColor: bar.highlightHoverColor
              selectedColor: bar.highlightSelectedColor
              rounding: bar.highlightRounding
            }
            Text {
              id: label
              visible: mount.labelled
              textFormat: Text.PlainText
              text: mount.title
              color: drawer.namedMenu
                ? (drawer.selectionVisible && drawer.cursor === mount.index ? Color.menu.selectedText : Color.menu.text)
                : Color.popups.text
              font.family: drawer.namedMenu ? Style.font.menuFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              readonly property real baseX: drawer.namedMenu
                ? Model.menuLabelStart(mount.showNative, modelData.naturalWidth, Style.space(8), Style.space(2))
                : mount.showNative ? modelData.naturalWidth + Style.space(6) : Style.space(6)
              x: baseX + mount.contentOffsetX
              y: (mount.baseHeight - height) / 2 + mount.contentOffsetY
              width: drawer.namedMenu ? Math.max(0, drawer.menuRowWidth - baseX - Style.space(8)) : implicitWidth
              elide: drawer.namedMenu ? Text.ElideRight : Text.ElideNone
              DragHandler {
                target: null
                enabled: mount.labelled
                acceptedButtons: Qt.LeftButton
                property point lastScene
                onCentroidChanged: if (active) { lastScene = centroid.scenePosition; bar.updateIconDrag(lastScene, modelData) }
                onActiveChanged: {
                  if (active) {
                    lastScene = centroid.scenePosition
                    bar.beginIconDrag(modelData, hostWindow, lastScene,
                      (label.x + centroid.position.x) * bar.barScale,
                      (label.y + centroid.position.y) * bar.barScale)
                  } else if (bar.barDragSource === modelData) {
                    bar.finishIconDrag(lastScene, modelData)
                  }
                }
              }
              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                  if (mouse.button === Qt.LeftButton) modelData.activate()
                  else {
                    var targets = bar.targetsForSlot(modelData)
                    for (var target of targets) if (target && typeof target.triggerPress === "function") {
                      target.triggerPress(Qt.RightButton); break
                    }
                  }
                }
                onWheel: function(wheel) {
                  var targets = bar.targetsForSlot(modelData)
                  for (var target of targets) if (target && typeof target.wheelMoved === "function") {
                    target.wheelMoved(wheel.angleDelta.y); break
                  }
                }
              }
            }
            BorderSurface {
              anchors.fill: parent
              z: drawer.namedMenu ? -1 : 100
              visible: drawer.selectionVisible && drawer.cursor === mount.index
              color: drawer.namedMenu ? Color.menu.selectedBackground : "transparent"
              borderSpec: drawer.namedMenu
                ? Border.surfaceSpec("menu", "selected-border", Color.menu.selectedBorder, 0)
                : Border.flat(Color.accent, 1 / bar.barScale)
              radius: Style.cornerRadius
            }
          }
        }
      }
      AnimatedSlot {
        id: endGap
        readonly property bool gap: DragModel.endGap(bar.dragPreview, bar.dragSurfaceForDrawer(drawer))
        x: drawer.stripVertical ? 0 : contents.width
        y: drawer.stripVertical ? contents.height : 0
        targetWidth: drawer.stripVertical ? drawer.thickness : gap ? bar.dragGapWidth : 0
        targetHeight: drawer.stripVertical ? (gap ? bar.dragGapHeight : 0) : drawer.thickness
        motionEnabled: bar.animationsEnabled && drawer.opened && !drawer.replaying
        motionDuration: bar.dragMotionDuration
        motionEasing: bar.dragMotionEasing
        motionOvershoot: 0
      }
    }
  }
}
