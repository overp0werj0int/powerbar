import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ManagedModel.js" as Model
import "DragModel.js" as DragModel
import "CellModel.js" as CellModel
import "RenderModel.js" as RenderModel
import "NotchModel.js" as NotchModel

// Lives in the bar's window: widgets keep the same QsWindow and popup anchors.
Item {
  id: drawer
  required property var bar
  required property var hostWindow
  property bool opened: false
  property bool instantClose: false
  property bool replaying: false
  property real reveal: 0
  // When the drawer last opened or changed its widgets: its rows may come
  // under a resting pointer until it has settled.
  property real shownAt: 0
  property int transitionEpoch: 0
  property real closingLength: thickness
  // A drag that started on one of the drawer's rows is driven by a handler on
  // that row. While it runs, the drawer keeps presenting and keeps its rows,
  // whatever closes it or changes its members; destroying that row would
  // leave the drag without its release (the bar stuck mid-drag).
  property Item dragMount: null
  // A drag's landing outline slides on to the next landing spot (DRAG-75).
  readonly property HighlightGlide dropGlide: HighlightGlide {}
  readonly property bool presenting: opened || reveal > 0.001 || !!dragMount
  onPresentingChanged: if (!presenting && bar.managedOwner === drawer) bar.managedOwner = null
  Behavior on reveal {
    enabled: bar.animationsEnabled && !drawer.instantClose && !drawer.replaying
    // Drawers open a few dozen times a day: quick, a strong ease-out both
    // ways, and closing faster than opening. On the notch, the zones' slide
    // out of the camera: a spring held to a few px out, ease-out back in.
    NumberAnimation {
      duration: drawer.fromNotch ? (drawer.opened ? 220 : 140) : drawer.opened ? 160 : 110
      easing.type: drawer.fromNotch ? (drawer.opened ? Easing.OutBack : Easing.OutCubic) : Easing.BezierSpline
      easing.overshoot: NotchModel.backOvershoot(drawer.height, drawer.hostWindow.notchOvershoot)
      easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
    }
  }
  // On the notched screen the drawer is the notch's (docs/behavior/groups.md):
  // black, hanging from the bar, sliding down out of it.
  readonly property bool fromNotch: !!hostWindow.notchLook && !bar.vertical && !isSubmenu
  // In the notch's colours: its drawers, and a submenu of a notch menu.
  readonly property bool notchColours: fromNotch || isSubmenu && parentMenu.fromNotch
  opacity: (fromNotch ? 1 : Math.max(0, Math.min(1, reveal))) * asideOpacity
  // The opening motion starts on the second frame after the open: the first
  // lays out and paints the rows just mounted and the main bar's change,
  // which can take a few frames' time. Started before it, the motion was
  // about 64% done on its first painted frame (on-demand-drawers.md DEMAND-91).
  FrameAnimation {
    id: revealStart
    property int epoch: 0
    property int ticks: 0
    onTriggered: {
      if (++ticks < 2) return
      stop()
      if (!drawer.opened || drawer.transitionEpoch !== epoch) return
      drawer.replaying = false
      drawer.reveal = 1
    }
  }
  // A member's panel open: the drawer steps aside (fades out and leaves the
  // bar's input region) and the panel opens at the bar's edge, as a bar
  // widget's would, instead of below the drawer. It stays open underneath,
  // since the panel is anchored to the member. Once the panel closes it comes
  // back for the keyboard, and closes for the pointer: the panel was the last
  // stop. The grace lets one member's panel hand over to another's.
  readonly property bool memberPanelOpen: slots.some(function(slot) { return slot.panelOpen })
    || (!!submenu && submenu.opened && submenu.memberPanelOpen)
  property bool steppedAside: false
  onSteppedAsideChanged: bar.ev("drawer", steppedAside ? "aside" : "back")
  onMemberPanelOpenChanged: {
    if (memberPanelOpen) { asideEnd.stop(); steppedAside = opened }
    else if (steppedAside) asideEnd.restart()
  }
  Timer { id: asideEnd; interval: 150; onTriggered: drawer.asideCheck() }
  // For the keyboard it comes back once no panel at all is open (Tab in a
  // panel moves on to the next widget's, which may be outside the drawer).
  function asideCheck() {
    if (!steppedAside || memberPanelOpen) return
    var keys = keyboardMode || barKeysHeld
    if (keys && bar.activePopout) return
    steppedAside = false
    if (opened && !keys) close("immediate")
  }
  Connections {
    target: drawer.bar
    function onActivePopoutChanged() { if (drawer.steppedAside && !asideEnd.running) asideEnd.restart() }
  }
  property real asideOpacity: steppedAside ? 0 : 1
  Behavior on asideOpacity { enabled: bar.animationsEnabled && drawer.opened; NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
  // Grows out of the icon that opened it (the source cell's centre on the
  // drawer's near edge) from 96%; nothing appears from nothing.
  readonly property real originAlong: sourceCell ? (sourceCell.start + sourceCell.end) / 2 - axisPosition
    : zone === "left" ? 0 : zone === "right" ? paintedLength : paintedLength / 2
  // A submenu grows out of its row's side of the menu.
  transform: Scale {
    origin.x: drawer.isSubmenu ? (drawer.subPlace && drawer.subPlace.before ? drawer.width : 0)
      : bar.vertical ? (bar.position === "left" ? 0 : drawer.width) : drawer.originAlong
    origin.y: drawer.isSubmenu ? (bar.position === "bottom" ? drawer.height : 0)
      : !bar.vertical ? (bar.position === "top" ? 0 : drawer.height) : drawer.originAlong
    xScale: drawer.fromNotch ? 1 : 0.96 + 0.04 * Math.max(0, drawer.reveal)
    yScale: drawer.fromNotch ? 1 : 0.96 + 0.04 * Math.max(0, drawer.reveal)
  }
  property bool grabReady: false
  onOpenedChanged: {
    grabReady = false
    if (opened) grabDelay.restart()
    else grabDelay.stop()
    if (!opened) { asideEnd.stop(); steppedAside = false }
    if (opened) bar.ev("drawer", "open " + (isSubmenu ? "submenu " : "") + (groupId ? "group:" + groupId : token) + (keyboardMode ? " keys" : "")
      + " on " + (hostWindow && hostWindow.screen ? hostWindow.screen.name : "?"), bar.animationsEnabled ? 200 : 0)
  }
  Timer { id: grabDelay; interval: 250; onTriggered: drawer.grabReady = drawer.opened }
  // A click pinning a hover drawer waits the same moment: a grab that starts
  // before the bar has the keyboard is cleared at once, closing the drawer.
  onKeyboardModeChanged: if (keyboardMode && opened && !grabDelay.running) { grabReady = false; grabDelay.restart() }
  property string zone: ""
  // What a zone's drawer opened for: its region, or in menu mode the side of
  // it whose dots opened it ("center:start"); `zone` is the region either way.
  property string token: ""
  property string groupId: ""
  // On demand "menu" (on-demand-drawers.md DEMAND-94): a zone's drawer is a
  // menu of icons and names hanging from its dots, and a group's row in it
  // opens the group's members in a submenu beside it. A drawer with a
  // parentMenu is that submenu.
  property var parentMenu: null
  readonly property bool isSubmenu: !!parentMenu
  readonly property bool zoneMenu: bar.onDemandMenu && !groupId && !isSubmenu
  readonly property var submenu: isSubmenu ? null : hostWindow.managedSubmenu || null
  // The dots a zone's menu hangs from.
  property Item anchorHandle: null
  // A submenu's row in its menu.
  property Item parentRow: null
  function rowGroup(slot) { return zoneMenu && !!slot && slot.groupHeader === true }
  readonly property var groupConfig: bar.groups.find(function(g) { return g.id === groupId }) || null
  readonly property string surfaceRole: zoneMenu || isSubmenu ? "menu" : Model.drawerSurface(groupConfig)
  readonly property bool namedMenu: surfaceRole === "menu"
  // Drawers are islands with the island radius, always floating one bar gap
  // from the bar (docs/behavior/on-demand-drawers.md). Menus and strips are
  // one size on every bar, the large bar's (Bar.drawerTokens), whatever the
  // bar's own size or the notch's.
  readonly property var tokens: bar.drawerTokens
  readonly property real surfaceRadius: Math.min(bar.islandRounding, tokens.bar / 2)
  readonly property bool stripVertical: namedMenu || Model.drawerVertical(groupConfig, bar.vertical)
  // Menus of the menu mode show icons and names; a submenu of a group set to
  // names only shows names.
  readonly property string memberDisplay: zoneMenu ? "both"
    : isSubmenu ? (groupConfig && groupConfig.memberDisplay === "name" ? "name" : "both")
    : groupConfig ? groupConfig.memberDisplay : "native"
  function memberTitle(slot) { return bar.slotName(slot) }
  FontMetrics {
    id: menuMetrics
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
  }
  // Menus: rows are highlight cells. An icon (a glyph, or a picture that fits
  // the cell, ManagedModel.menuIcon) keeps its cell at the row's
  // start and its name starts after it; a row without an icon starts its name
  // at the icon edge; anything that is text on the bar (the clock, the
  // battery) is a value, right-aligned one air from the row's end.
  readonly property bool menuIcons: namedMenu && memberDisplay === "both"
  function menuInk(slot) { return bar.vertical && slot.crossInk ? slot.crossInk : slot.ink }
  function menuGlyph(slot) {
    var ink = menuInk(slot)
    return Model.menuIcon(CellModel.isGlyph(ink.length, ink.glyph), slot.pictured, ink.length, tokens.cell)
  }
  // A group's row: its icon in the icon cell, its name, and a chevron where
  // a value would be.
  readonly property real chevronWidth: menuMetrics.advanceWidth("󰅂")
  // Whether a submenu opens before this menu (ManagedModel.placeSubmenu's
  // rule, for a submenu as wide as the menu).
  readonly property bool subBefore: zoneMenu && (bar.vertical ? bar.position === "right"
    : x + 2 * width + tokens.inset > hostWindow.width - bar.edgeGap)
  function menuValueWidth(slot) {
    return rowGroup(slot) ? chevronWidth : Model.menuValueWidth(menuIcons, menuGlyph(slot), menuInk(slot).length, CellModel.MAX_INK)
  }
  function menuLabelStart(slot) { return Model.menuLabelStart(rowGroup(slot) || menuIcons && menuGlyph(slot), tokens.cell, tokens.air) }
  readonly property real menuRowWidth: !namedMenu ? 0 : Model.menuRowWidth(slots.map(function(slot) {
    return { labelStart: menuLabelStart(slot), title: menuMetrics.advanceWidth(memberTitle(slot)), value: menuValueWidth(slot) }
  }), tokens)
  property var anchorSlot: null
  property real anchorCenter: -1
  property string suppressedZone: ""
  property bool sourceHovered: false
  property bool entered: false
  property bool keyboardMode: false
  // Opened from the bar's keyboard cursor (BarKeys.qml): it stays while the
  // cursor is on it, and its keys go to the cursor's rules first.
  property bool barKeysHeld: false
  property int cursor: 0
  property bool cursorActive: false
  readonly property bool selectionVisible: Model.cursorVisible(keyboardMode, cursorActive, slots.length)
  // A zone's menu counts its submenu as part of it.
  readonly property bool containsMouse: hover.hovered || (!!submenu && submenu.opened && submenu.containsMouse)
  readonly property var slots: presenting ? (groupId ? bar.groupSlots(groupId, hostWindow) : bar.managedSlots(token || zone, hostWindow)) : []
  // The mounts' model is one identity token per member, not the members: a
  // Repeater over QObjects exposes every property of every member as a role,
  // which cost milliseconds per member on each open. The Repeater still
  // rebuilds exactly when the members change; each mount reads its member
  // from this plain table, which never notifies.
  readonly property var mounted: ({ list: [] })
  property var mountTokens: []
  function refreshMounts() {
    if (dragMount) return
    var list = slots
    mounted.list = list
    var tokens = list.map(function(slot) { return String(slot) })
    if (!RenderModel.equal(tokens, mountTokens)) mountTokens = tokens
  }
  onDragMountChanged: refreshMounts()
  function releaseDrag(mount) { if (dragMount === mount) dragMount = null }
  // Where a released widget's image lands in an open gap here, as the bar
  // predicts its own: the centre of the widget's look in the cell or row that
  // will take the gap. mount: the member whose gap it is, or null for the end
  // gap. Returns { item, local } for the settle glide.
  function landingPoint(source, mount) {
    var item = mount || endGap
    var along = drawer.stripVertical
    var start = !mount ? (namedMenu ? padding : 0)
      : mount.preview.before ? 0 : (along ? mount.baseHeight : mount.baseWidth) + (namedMenu ? padding : 0)
    if (namedMenu) {
      if (bar.barDragImageLabelled || memberDisplay === "name")
        return { item: item, local: { x: menuRowWidth / 2, y: start + tokens.thickness / 2 } }
      var ink = menuInk(source), value = menuValueWidth(source)
      var ox = menuIcons && menuGlyph(source) ? tokens.cell / 2 - (ink.start + ink.length / 2)
        : value > 0 ? menuRowWidth - tokens.air - (ink.start + ink.length) : 0
      return { item: item, local: { x: ox + source.naturalWidth / 2, y: start + (tokens.thickness - source.naturalHeight) / 2 + source.naturalHeight / 2 } }
    }
    // A strip cell: the image is the widget (from the bar) or its whole cell
    // (from a drawer), centred on the cell either way.
    var extent = source.landingExtent > 0 ? source.landingExtent : (along ? bar.dragGapHeight : bar.dragGapWidth)
    var centre = bar.barDragImageFromCell ? start + extent / 2
      : start + source.inkShift + (along ? source.naturalHeight : source.naturalWidth) / 2
    var cross = (along ? item.width : item.height) / 2
    return { item: item, local: along ? { x: cross, y: centre } : { x: centre, y: cross } }
  }
  readonly property bool interactionHeld: keyboardMode || barKeysHeld || bar.dragMotionActive || memberPanelOpen
    || (!!submenu && submenu.opened && submenu.keyboardMode)
  // Menu padding, and the pitch a drag opens between rows.
  readonly property real padding: tokens.inset
  readonly property real rowPitch: tokens.thickness + tokens.inset
  // One bar gap from the bar: a floating bar's extent already includes it; a
  // flat bar has none, so its drawers add it.
  readonly property real gap: bar.flat ? bar.edgeGap : 0
  readonly property real thickness: tokens.bar
  readonly property real extent: opened ? thickness + gap : 0
  readonly property real axisExtent: bar.vertical ? hostWindow.height : hostWindow.width
  // Strip ends: the island rule, so the end cells sit one inset from the ends.
  readonly property real leadPad: namedMenu ? padding : CellModel.endPad(tokens, bar.edgeSpill(contents, false))
  readonly property real trailPad: namedMenu ? padding : CellModel.endPad(tokens, bar.edgeSpill(contents, true))
  readonly property real desiredLength: (bar.vertical ? grid.height : grid.width)
    + (namedMenu ? 2 * padding : leadPad + trailPad)
  readonly property real desiredCross: (bar.vertical ? grid.width : grid.height) + 2 * padding
  readonly property real crossLength: namedMenu
    ? Math.min(Math.max(thickness, desiredCross), hostWindow.drawerExtent - gap - bar.edgeGap) : thickness
  readonly property real length: opened ? Math.min(Math.max(thickness, desiredLength), Math.max(thickness, axisExtent - 2 * bar.edgeGap)) : closingLength
  readonly property real paintedLength: bar.vertical ? height : width
  // The group icon's cell along the bar, in the window's coordinates. The icon
  // moves with its zone too (a zone grows, slides or yields), which its own x
  // never shows, so the observers below follow the whole ancestor chain.
  property int anchorRevision: 0
  property int islandRevision: 0
  GeometryObserver {
    target: drawer.presenting ? drawer.anchorSlot || drawer.anchorHandle : null
    host: drawer.hostWindow.contentItem
    onChanged: drawer.anchorRevision++
  }
  GeometryObserver {
    target: drawer.presenting && drawer.hostWindow.zoneIslands ? drawer.hostWindow.zoneIslands[drawer.zone] || null : null
    host: drawer.hostWindow.contentItem
    onChanged: drawer.islandRevision++
  }
  readonly property var sourceCell: {
    if (anchorCenter >= 0) return { start: anchorCenter - tokens.cell / 2, end: anchorCenter + tokens.cell / 2 }
    // The dots' highlight cell, centred in their slot.
    if (anchorHandle) {
      var handleGeometry = anchorRevision + anchorHandle.x + anchorHandle.y + anchorHandle.width + anchorHandle.height
      var h = anchorHandle.mapToItem(hostWindow.contentItem, 0, 0)
      var cell = anchorHandle.cellPlace ? anchorHandle.cellPlace.cell : tokens.cell
      var mid = bar.vertical ? h.y + anchorHandle.height / 2 : h.x + anchorHandle.width / 2
      return { start: mid - cell / 2, end: mid + cell / 2 }
    }
    if (!anchorSlot) return null
    var geometry = anchorRevision + anchorSlot.x + anchorSlot.y + anchorSlot.width + anchorSlot.height + anchorSlot.cellLength
    var p = anchorSlot.mapToItem(hostWindow.contentItem, 0, 0)
    var along = bar.vertical ? anchorSlot.height : anchorSlot.width
    // The icon's own stretch of its slot, as the highlight (DRAG-75): a drop
    // gap the slot holds is left out.
    var lead = anchorSlot.cellLead > 0 ? anchorSlot.cellLead : 0
    var own = anchorSlot.cellExtent > 0 ? Math.min(along - lead, anchorSlot.cellExtent) : along - lead
    var start = (bar.vertical ? p.y : p.x) + lead + (own - anchorSlot.cellLength) / 2
    return { start: start, end: start + anchorSlot.cellLength }
  }
  readonly property var zoneIsland: {
    var island = hostWindow.zoneIslands ? hostWindow.zoneIslands[zone] : null
    if (!island || !island.visible || !bar.islands) return null
    var geometry = islandRevision + island.x + island.y + island.width + island.height
    var p = island.mapToItem(hostWindow.contentItem, 0, 0)
    return bar.vertical ? { start: p.y, end: p.y + island.height } : { start: p.x, end: p.x + island.width }
  }
  readonly property var placement: {
    var o = { length: paintedLength, screen: axisExtent, edge: bar.edgeGap, source: sourceCell, island: zoneIsland,
      zone: zone, snap: tokens.thickness / 2, inset: tokens.inset, row: tokens.thickness, vertical: bar.vertical }
    return namedMenu ? Model.placeMenu(o) : Model.placeStrip(o)
  }
  readonly property real axisPosition: placement.start
  // A submenu beside its row (ManagedModel.placeSubmenu).
  property int rowRevision: 0
  readonly property var subPlace: {
    if (!isSubmenu || !parentRow || !parentMenu) return null
    var geometry = rowRevision + parentMenu.x + parentMenu.y + parentMenu.width + parentMenu.height
    var r = parentRow.mapToItem(hostWindow.contentItem, 0, 0)
    return Model.placeSubmenu({ menu: { x: parentMenu.x, y: parentMenu.y, width: parentMenu.width, height: parentMenu.height },
      row: { y: r.y, height: parentRow.height }, width: width, height: height,
      screen: { width: hostWindow.width, height: hostWindow.height }, edge: bar.edgeGap, inset: tokens.inset, position: bar.position })
  }
  width: bar.vertical ? crossLength : length
  height: bar.vertical ? length : crossLength
  x: isSubmenu ? (subPlace ? subPlace.x : 0)
    : bar.vertical ? (bar.position === "left" ? bar.extentOf(hostWindow) + gap : hostWindow.drawerExtent - gap - width) : axisPosition
  y: isSubmenu ? (subPlace ? subPlace.y : 0)
    : bar.vertical ? axisPosition : (bar.position === "top" ? bar.extentOf(hostWindow) + gap : hostWindow.drawerExtent - gap - height)
  visible: presenting
  enabled: opened
  focus: opened && keyboardMode

  // nextZone: a region, or in menu mode a side's token ("center:end");
  // nextHandle: the dots a zone's menu hangs from.
  function openZone(nextZone, keyboard, nextGroup, nextAnchor, nextHandle) {
    nextGroup = nextGroup || ""
    var nextToken = String(nextZone || "")
    // The centre has a menu per side: a bare "center" (managed center) opens
    // the first side with widgets.
    if (bar.onDemandMenu && !nextGroup && nextToken === "center")
      nextToken = bar.managedSlots("center:start", hostWindow).length ? "center:start" : "center:end"
    if (bar.barHidden || (nextGroup ? bar.groupSlots(nextGroup, hostWindow) : bar.managedSlots(nextToken, hostWindow)).length === 0) return
    if (!keyboard && suppressedZone === nextToken) return
    if (keyboard) suppressedZone = ""
    if (bar.managedOwner && bar.managedOwner !== drawer) bar.managedOwner.close("immediate")
    var changingZone = opened && (token !== nextToken || groupId !== nextGroup)
    if (changingZone) { closeMemberPanel(); if (submenu) submenu.close("immediate") }
    var needsReveal = !opened || changingZone
    if (needsReveal) {
      replaying = true
      reveal = 0
      shownAt = Date.now()
    }
    if (changingZone || !opened) { entered = false; cursor = 0; sourceHovered = false }
    cursorActive = false
    zone = nextToken.split(":")[0]
    token = nextToken
    groupId = nextGroup
    anchorSlot = nextAnchor || null
    anchorHandle = bar.onDemandMenu && !nextGroup ? nextHandle || handleFor(nextToken) : null
    anchorCenter = -1
    keyboardMode = keyboard === true
    instantClose = false
    opened = true
    bar.managedOwner = drawer
    if (needsReveal) {
      revealStart.epoch = ++transitionEpoch
      revealStart.ticks = 0
      revealStart.restart()
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
    // Its icon while a member's panel is open: the panel closes and the
    // drawer comes back pinned, rather than closing under the panel.
    if (opened && groupId === id && steppedAside) {
      closeMemberPanel()
      openGroup(id, slot, true)
      asideCheck()
    } else if (opened && groupId === id && keyboardMode) close()
    else openGroup(id, slot, true)
  }
  // A member's panel is anchored to the member: it closes with the drawer,
  // or it would follow the member back to its hidden slot on the bar.
  function closeMemberPanel() {
    if (memberPanelOpen && bar.activePopout && typeof bar.activePopout.close === "function") bar.activePopout.close()
  }
  // A submenu: group `id`'s members beside `row`, its row in the menu. For
  // the keyboard it takes the keys with the cursor on its first member.
  function openSub(id, row, keyboard) {
    if (!isSubmenu || !row || bar.groupSlots(id, hostWindow).length === 0) return
    var changing = opened && groupId !== id
    if (changing) closeMemberPanel()
    var needsReveal = !opened || changing
    if (needsReveal) {
      replaying = true
      reveal = 0
      shownAt = Date.now()
      entered = false
      cursor = 0
    }
    zone = parentMenu.zone
    token = ""
    groupId = id
    parentRow = row
    rowRevision++
    keyboardMode = keyboard === true
    cursorActive = keyboardMode
    if (keyboardMode) cursor = 0
    instantClose = false
    opened = true
    if (needsReveal) {
      revealStart.epoch = ++transitionEpoch
      revealStart.ticks = 0
      revealStart.restart()
    }
    if (keyboardMode) Qt.callLater(function() { if (drawer.opened && drawer.keyboardMode) drawer.forceActiveFocus() })
  }
  // The submenu closes; the keys come back to this menu's row.
  function closeSubmenu(refocus) {
    if (!submenu || !submenu.opened) return
    submenu.close()
    if (refocus && opened && keyboardMode) forceActiveFocus()
  }
  // Row i pressed (a click, Enter): a group's row opens its submenu, any
  // other does what a click on the widget does.
  function activateRow(i, keyboard) {
    var slot = slots[i]
    if (!slot) return
    if (rowGroup(slot)) {
      var row = widgets.itemAt(i)
      if (submenu && row) submenu.openSub(slot.entry.powerbarGroupId, row, keyboard === true)
      return
    }
    slot.activate()
  }
  // The pointer on a row of a zone's menu: a group's row opens its submenu
  // after a short rest; another row lets an open submenu go after a grace,
  // so a pointer crossing a row on its way into the submenu keeps it.
  function rowHovered(row) {
    if (!zoneMenu || !submenu) return
    if (row.opensSubmenu) { subIntent.row = row; subIntent.restart() }
    else subIntent.stop()
    if (submenu.opened && submenu.parentRow !== row && !submenu.keyboardMode) subAway.restart()
  }
  Timer {
    id: subIntent
    interval: 120
    property Item row: null
    onTriggered: {
      var row = subIntent.row
      if (row && row.rowHovered && drawer.opened && drawer.submenu && !drawer.bar.barDragSource)
        drawer.submenu.openSub(row.modelData.entry.powerbarGroupId, row, false)
    }
  }
  Timer {
    id: subAway
    interval: 250
    onTriggered: {
      var sub = drawer.submenu
      if (!sub || !sub.opened || sub.keyboardMode || sub.containsMouse || sub.memberPanelOpen) return
      if (sub.parentRow && sub.parentRow.rowHovered) return
      sub.close()
    }
  }
  // A group icon opens its drawer once the pointer has rested on it 90 ms,
  // as the dots do (groups.md GROUP-32), so a pointer sweeping along the bar
  // flashes no drawers. Its own drawer, already open, is held at once.
  property string intentGroup: ""
  property Item intentSlot: null
  function sourceEnterGroup(id, slot) {
    if (opened && groupId === id) { enterGroupNow(id, slot); return }
    intentGroup = id
    intentSlot = slot
    groupIntent.restart()
  }
  Timer {
    id: groupIntent
    interval: 90
    onTriggered: {
      var id = drawer.intentGroup, slot = drawer.intentSlot
      drawer.intentGroup = ""
      drawer.intentSlot = null
      if (slot && slot.stopHovered) drawer.enterGroupNow(id, slot)
    }
  }
  function enterGroupNow(id, slot) {
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
    if (opened) bar.ev("drawer", "close " + (isSubmenu ? "submenu " : "") + (groupId ? "group:" + groupId : token) + " " + (reason || "-"),
      bar.animationsEnabled && reason !== "immediate" ? 110 : 0)
    closeMemberPanel()
    if (submenu) submenu.close("immediate")
    subIntent.stop()
    subAway.stop()
    dismissal.stop()
    ++transitionEpoch
    replaying = false
    instantClose = reason === "immediate"
    // Only explicit dismissal under the pointer waits for a fresh hover.
    // A timed dismissal must never lock out the next entry.
    suppressedZone = reason !== "timeout" && sourceHovered ? token : ""
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
  // A zone's widgets, dots and drawer button open its drawer once the pointer
  // has rested on one of them 90 ms, as a group icon does (DEMAND-17), so a
  // sweep along the bar flashes no drawers. `still` says whether the pointer
  // is still there; without it (a decision already made) the drawer opens at
  // once. The zone's own drawer, already open, is held at once.
  property string intentZone: ""
  property var intentStill: null
  property Item intentHandle: null
  function sourceEnter(nextZone, still, handle) {
    if (opened && keyboardMode) {
      sourceHovered = token === nextZone
      return
    }
    zoneIntent.stop()
    intentZone = ""
    intentStill = null
    intentHandle = handle || null
    if (!still || (opened && token === nextZone && !groupId)) { enterZoneNow(nextZone, handle); return }
    intentZone = nextZone
    intentStill = still
    zoneIntent.restart()
  }
  Timer {
    id: zoneIntent
    interval: 90
    onTriggered: {
      var zone = drawer.intentZone, still = drawer.intentStill
      drawer.intentZone = ""
      drawer.intentStill = null
      if (zone && still && still()) drawer.enterZoneNow(zone, drawer.intentHandle)
    }
  }
  function enterZoneNow(nextZone, handle) {
    openZone(nextZone, false, "", null, handle)
    if (opened && token === nextZone) { sourceHovered = true; dismissal.stop() }
  }
  // The pointer reached another stop along the bar: a hover-opened drawer
  // closes rather than waiting out the grace (ManagedModel.closesForStop),
  // once the pointer has stayed there 100 ms, so a diagonal way from the
  // source into a wide menu that brushes a neighbour on the bar never counts.
  property Item stopSlot: null
  function pointerOnStop(slot) {
    stopSlot = slot
    if (opened && !keyboardMode) stepAway.restart()
  }
  Timer {
    id: stepAway
    interval: 100
    onTriggered: {
      var slot = drawer.stopSlot
      if (!slot || !slot.stopHovered || drawer.containsMouse || drawer.sourceHovered) return
      var stop = { groupId: slot.groupHeader ? slot.entry.powerbarGroupId : "", region: slot.region }
      var held = bar.dragMotionActive || drawer.memberPanelOpen
      if (Model.closesForStop(drawer.opened, drawer.keyboardMode, held, drawer.groupId, drawer.zone, stop, drawer.zoneMenu)) drawer.close()
    }
  }
  function sourceLeave(nextZone) {
    if (suppressedZone === nextZone) suppressedZone = ""
    if (token !== nextZone) return
    sourceHovered = false
    scheduleDismissal()
  }
  function scheduleDismissal() {
    dismissal.stop()
    // A submenu goes with its menu.
    if (!opened || isSubmenu) return
    var delay = Model.dismissDelay(sourceHovered, containsMouse, interactionHeld, entered, bar.managedEntrySeconds, bar.managedExitSeconds)
    if (delay > 0) { dismissal.interval = delay; dismissal.start() }
  }
  onContainsMouseChanged: {
    if (containsMouse) entered = true
    scheduleDismissal()
  }
  onInteractionHeldChanged: scheduleDismissal()
  onSlotsChanged: {
    refreshMounts()
    if (opened && slots.length === 0) close()
  }
  Component.onCompleted: refreshMounts()
  Component.onDestruction: if (bar.managedOwner === drawer) bar.managedOwner = null
  Timer { id: dismissal; repeat: false; onTriggered: drawer.close("timeout") }

  // The cell showing member i (the keyboard's name card anchors on it).
  function cellAt(i) { return widgets.itemAt(i) }
  function navigate(delta) {
    if (!slots.length) return
    cursor = cursorActive ? (cursor + delta + slots.length) % slots.length : delta > 0 ? 0 : slots.length - 1
    cursorActive = true
    var cell = widgets.itemAt(cursor)
    if (!cell) return
    // Scrolled into view with the strip's end pads kept around it.
    var lead = namedMenu ? 0 : leadPad, trail = namedMenu ? 0 : trailPad
    var start = (drawer.stripVertical ? grid.y + cell.y : grid.x + cell.x) - lead
    var size = (drawer.stripVertical ? cell.height : cell.width) + lead + trail
    var offset = drawer.stripVertical ? viewport.contentY : viewport.contentX
    var span = drawer.stripVertical ? viewport.height : viewport.width
    var next = start < offset ? start : start + size > offset + span ? start + size - span : offset
    if (drawer.stripVertical) viewport.contentY = next
    else viewport.contentX = next
  }
  // A key let go here after it took the keys back to the bar (an along key
  // out of a menu, Tab): the cursor's next drawer previews as from the bar.
  Keys.onReleased: function(event) { if (!event.isAutoRepeat && bar.barKeys.heldBy(hostWindow)) bar.barKeys.released() }
  // Keys meant for the drawer reach it before any window-wide Shortcut a
  // widget declares (Bar.qml keyCatcher).
  Keys.onShortcutOverride: function(event) { if (keyboardMode || barKeysHeld) event.accepted = true }
  Keys.onPressed: function(event) {
    if (subKey(event)) { event.accepted = true; return }
    if (barKeysHeld && bar.barKeys.drawerKey(event)) { event.accepted = true; return }
    switch (event.key) {
    case Qt.Key_Escape: if (isSubmenu) parentMenu.closeSubmenu(true); else close(); break
    case Qt.Key_Tab: navigate(event.modifiers & Qt.ShiftModifier ? -1 : 1); break
    case Qt.Key_Backtab: case Qt.Key_Left: case Qt.Key_Up: navigate(-1); break
    case Qt.Key_Right: case Qt.Key_Down: navigate(1); break
    case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: {
      var press = Model.pressAction(keyboardMode, cursorActive, slots.length)
      if (press === "select") navigate(1)
      else if (press === "activate") activateRow(cursor, keyboardMode)
      break
    }
    default: return
    }
    event.accepted = true
  }

  // The dots of a zone or centre side on this bar.
  function handleFor(t) { return (hostWindow.foldHandles || []).find(function(h) { return h && h.inlineToken === t }) || null }
  // The side keys of the menu mode: on a group's row in a zone's menu the one
  // its chevron points along opens its submenu; in the submenu the one
  // towards the menu goes back.
  function subKey(event) {
    var side = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0
    if (!side || event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier)) return false
    if (isSubmenu) {
      var towards = subPlace && subPlace.before ? 1 : -1
      if (side === towards) parentMenu.closeSubmenu(true)
      return true
    }
    if (!zoneMenu || !cursorActive || !rowGroup(slots[cursor]) || side !== (subBefore ? -1 : 1)) return false
    activateRow(cursor, true)
    return true
  }

  // A drop's landing spot in this drawer, outlined as on the bar: a cell in a
  // strip, a row in a menu.
  component DrawerOutline: DropOutline {
    bar: drawer.bar
    glide: drawer.dropGlide
    glideKey: "drawer"
    vertical: drawer.stripVertical
    cellAlong: drawer.namedMenu ? drawer.tokens.thickness : (drawer.bar.barDragSource ? drawer.bar.barDragSource.cellLength : drawer.tokens.cell)
    cellAcross: drawer.namedMenu ? drawer.menuRowWidth : drawer.tokens.thickness
    ink: drawer.namedMenu && !drawer.notchColours ? drawer.bar.textOn(Commons.Color.menu.text) : drawer.bar.barForeground
  }
  // On the notch (fromNotch) the drawer slides down out of the bar and is
  // cut at the bar's bottom edge, as a zone slides out of the camera: the
  // clip runs along the drawer's top, wide and deep enough for its shoulders
  // and shadow. Elsewhere it neither clips nor moves.
  Item {
    id: clipper
    readonly property real side: drawer.fromNotch ? bar.notchCorners.shoulder + Math.ceil(bar.surfaceEffects.shadowSize) * 2 : 0
    // How far past its place the body is (OutBack's overshoot, a few px).
    readonly property real overshoot: drawer.fromNotch ? Math.max(0, (drawer.reveal - 1) * drawer.height) : 0
    x: -side
    width: drawer.width + 2 * side
    height: drawer.height + side
    clip: drawer.fromNotch
    Item {
      id: body
      x: clipper.side
      width: drawer.width
      height: drawer.height
      transform: Translate { y: drawer.fromNotch ? -(1 - drawer.reveal) * drawer.height : 0 }
      EffectSurface {
        anchors.fill: parent
        visible: !drawer.fromNotch
        color: drawer.notchColours ? bar.mainSurfaceColor : bar.overlaySurfaceColor
        shadowEnabled: bar.surfaceEffects.shadow
        shadowSize: bar.surfaceEffects.shadowSize
        shadowOpacity: bar.surfaceEffects.shadowOpacity
        radius: drawer.surfaceRadius
        borderSpec: bar.islandBorder
      }
      // The notch's: its shoulders curve up into the bar's bottom edge either
      // side, as the screen's top edge curves into the camera, and its bottom
      // corners are the camera's. While the spring overshoots, the body moves
      // past its place and the shape reaches back up by as much, so its top
      // stays on the bar and never shows a gap.
      NotchShape {
        visible: drawer.fromNotch
        x: -bar.notchCorners.shoulder
        y: -clipper.overshoot
        width: parent.width + 2 * bar.notchCorners.shoulder
        height: parent.height + clipper.overshoot
        shoulderStart: bar.notchCorners.shoulder; shoulderEnd: bar.notchCorners.shoulder
        radiusStart: bar.notchCorners.radius; radiusEnd: bar.notchCorners.radius
        color: bar.mainSurfaceColor
        shadowEnabled: bar.surfaceEffects.shadow
        shadowSize: bar.surfaceEffects.shadowSize
        shadowOpacity: bar.surfaceEffects.shadowOpacity
      }
      HoverHandler { id: hover }
      Flickable {
        id: viewport
        anchors.fill: parent
        // Menus pad every side by one inset. Strips pad only their ends, by the
        // island rule, inside the viewport: an end cell's highlight spills into
        // that pad (Equal gaps) and is clipped only by the strip's own end.
        anchors.margins: drawer.namedMenu ? drawer.padding : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: grid.width + (drawer.namedMenu || bar.vertical ? 0 : drawer.leadPad + drawer.trailPad)
        contentHeight: grid.height + (drawer.namedMenu || !bar.vertical ? 0 : drawer.leadPad + drawer.trailPad)
        flickableDirection: drawer.stripVertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        Controls.ScrollBar.horizontal: Controls.ScrollBar { policy: !drawer.stripVertical && viewport.contentWidth > viewport.width ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: drawer.stripVertical && viewport.contentHeight > viewport.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
        Item {
          id: grid
          x: drawer.namedMenu || bar.vertical ? 0 : drawer.leadPad
          y: drawer.namedMenu || !bar.vertical ? 0 : drawer.leadPad
          implicitWidth: drawer.stripVertical ? Math.max(contents.width, drawer.thickness) : contents.width + endGap.width
          implicitHeight: drawer.stripVertical ? contents.height + endGap.height : Math.max(contents.height, drawer.thickness)
          transformOrigin: Item.TopLeft
          // Strip highlights live beneath the cells, so an Equal gaps cell can
          // spill past its slot like on the bar.
          Item { id: stripHighlights; anchors.fill: parent }
          // A row's highlight slides on to the next row (LOOK-139).
          HighlightGlide { id: rowGlide }
          Grid {
            id: contents
            columns: drawer.stripVertical ? 1 : Math.max(1, drawer.slots.length)
            // Slots carry their gutters; menu rows sit one inset apart.
            spacing: drawer.namedMenu ? drawer.padding : 0
            Repeater {
              id: widgets
              model: drawer.mountTokens
              AnimatedSlot {
                id: mount
                required property int index
                // Read once: a mount keeps its member for its whole life.
                readonly property var modelData: drawer.mounted.list[index]
                readonly property string title: drawer.memberTitle(modelData)
                readonly property bool labelled: drawer.namedMenu
                // A group's row in a zone's menu draws the group's icon and opens
                // its members in the submenu.
                readonly property bool opensSubmenu: drawer.rowGroup(modelData)
                readonly property bool rowHovered: memberHover.hovered
                readonly property bool showNative: drawer.memberDisplay !== "name" && !opensSubmenu
                readonly property var place: modelData ? modelData.cellPlace : null
                // Strip slots report their spill so the strip's ends follow the island rule.
                readonly property real cellSpill: drawer.namedMenu || !place ? 0 : place.spill
                readonly property var rowInk: modelData ? drawer.menuInk(modelData) : null
                readonly property bool rowIcon: drawer.menuIcons && !!modelData && drawer.menuGlyph(modelData)
                readonly property real valueWidth: modelData ? drawer.menuValueWidth(modelData) : 0
                readonly property real labelStart: modelData ? drawer.menuLabelStart(modelData) : 0
                readonly property real dragGap: drawer.namedMenu ? drawer.rowPitch : drawer.stripVertical ? bar.dragGapHeight : bar.dragGapWidth
                readonly property var preview: modelData
                  ? DragModel.slot(bar.dragPreview, modelData.instanceKey, bar.dragSurfaceForDrawer(drawer))
                  : ({ hidden: false, before: false, after: false })
                readonly property real baseWidth: !modelData ? 0 : drawer.namedMenu ? drawer.menuRowWidth
                  : bar.vertical ? drawer.thickness : place.extent
                readonly property real baseHeight: !modelData ? 0 : drawer.namedMenu ? drawer.tokens.thickness
                  : bar.vertical ? place.extent : Math.max(modelData.naturalHeight, drawer.thickness)
                // Where the widget's own box sits: its ink centred in its cell (strips),
                // its glyph centred in the icon cell or its value right-aligned (menus).
                readonly property real contentOffsetX: animatedInsetX + (!modelData ? 0
                  : drawer.namedMenu ? (rowIcon ? drawer.tokens.cell / 2 - (rowInk.start + rowInk.length / 2)
                    : valueWidth > 0 ? drawer.menuRowWidth - drawer.tokens.air - (rowInk.start + rowInk.length) : 0)
                  : bar.vertical ? modelData.crossShift : modelData.inkShift)
                readonly property real contentOffsetY: animatedInsetY + (!modelData ? 0
                  : drawer.namedMenu ? (drawer.tokens.thickness - modelData.naturalHeight) / 2
                  : bar.vertical ? modelData.inkShift : (baseHeight - modelData.naturalHeight) / 2)
                targetWidth: preview.hidden && !preview.holdSpace && !drawer.stripVertical ? 0
                  : baseWidth + (!drawer.stripVertical && (preview.before || preview.after) ? dragGap : 0)
                targetHeight: preview.hidden && !preview.holdSpace && drawer.stripVertical ? 0
                  : baseHeight + (drawer.stripVertical && (preview.before || preview.after) ? dragGap : 0)
                targetInsetX: !drawer.stripVertical && preview.before ? dragGap : 0
                targetInsetY: drawer.stripVertical && preview.before ? dragGap : 0
                // The commit swaps a gap for the row that takes it in one frame, as on the bar.
                motionEnabled: bar.animationsEnabled && drawer.opened && !drawer.replaying && !bar.dragHandover
                motionDuration: bar.dragMotionActive ? bar.dragMotionDuration : 120
                motionEasing: bar.dragMotionActive ? bar.dragMotionEasing : Easing.OutCubic
                motionOvershoot: 0
                opacity: preview.hidden || (modelData && modelData.settleHidden) ? 0 : 1
                readonly property var hostDrawer: drawer
                // The landing spot in this member's gap, outlined as on the bar: a
                // cell in a strip, a row in a menu.
                DrawerOutline {
                  readonly property real lengthAlong: drawer.stripVertical ? mount.height : mount.width
                  readonly property real insetAlong: drawer.stripVertical ? mount.animatedInsetY : mount.animatedInsetX
                  readonly property real base: drawer.stripVertical ? mount.baseHeight : mount.baseWidth
                  open: drawer.opened && !mount.preview.hidden && (mount.preview.before || mount.preview.after)
                  gapStart: mount.preview.before ? 0 : base
                  gapLength: !open ? 0 : mount.preview.before ? insetAlong : Math.max(0, lengthAlong - base)
                  fullGap: mount.dragGap
                  landingOffset: drawer.namedMenu ? (mount.preview.before ? 0 : drawer.padding) : -1
                  z: 3
                }
                Component.onCompleted: if (modelData) modelData.drawerHost = mount
                Component.onDestruction: {
                  if (modelData && modelData.drawerHost === mount) modelData.drawerHost = null
                  if (drawer.submenu && drawer.submenu.parentRow === mount) drawer.submenu.close("immediate")
                  // The row driving a drag can't report its release any more: end
                  // the drag rather than leave the bar stuck in it.
                  if (drawer.dragMount === mount) {
                    drawer.dragMount = null
                    if (modelData && bar.barDragSource === modelData) bar.clearBarDrag()
                  }
                }
                HoverHandler {
                  id: memberHover
                  enabled: drawer.opened && !bar.barDragSource
                  // In the keyboard mode the pointer moves the cursor onto the row.
                  onPointChanged: if (hovered) bar.barKeys.pointerOnRow(drawer, mount.index, point.scenePosition)
                  // A menu row shows its name already; it shows the widget's own
                  // tooltip (a volume, a status), which the row's pointer would
                  // otherwise keep from the widget. The keyboard's card shows that
                  // text while the keys hold the drawer.
                  onHoveredChanged: {
                    if (hovered) drawer.rowHovered(mount)
                    if (!hovered) bar.barKeys.pointerLeft()
                    if (!drawer.namedMenu || bar.barKeys.here && bar.barKeys.drawer === drawer) return
                    if (!hovered) { bar.hideTooltip(mount); return }
                    var text = mount.ownTooltip()
                    // Once the row's hover has reached tooltipHovered.
                    if (text && text !== mount.title) Qt.callLater(function() { if (memberHover.hovered) bar.showTooltip(mount, text) })
                  }
                }
                readonly property bool tooltipHovered: memberHover.hovered && drawer.opened
                function ownTooltip() {
                  if (opensSubmenu) return ""
                  var targets = modelData ? modelData.slotTargets || [] : []
                  for (var i = 0; i < targets.length; i++) if (targets[i] && targets[i].tooltipText) return String(targets[i].tooltipText)
                  return ""
                }
                // The member's highlight: the whole row in a menu; its cell in a strip,
                // centred on the slot, like on the bar.
                HoverHighlight {
                  id: memberHighlight
                  readonly property real cell: drawer.namedMenu ? mount.baseWidth : mount.place ? mount.place.cell : 0
                  readonly property real thick: drawer.tokens.thickness
                  parent: drawer.namedMenu ? mount : stripHighlights
                  x: drawer.namedMenu ? mount.animatedInsetX
                    : bar.vertical ? mount.x + (mount.width - thick) / 2 : mount.x + mount.animatedInsetX + (mount.baseWidth - cell) / 2
                  y: drawer.namedMenu ? mount.animatedInsetY
                    : bar.vertical ? mount.y + mount.animatedInsetY + (mount.baseHeight - cell) / 2 : mount.y + (mount.height - thick) / 2
                  width: drawer.namedMenu || !bar.vertical ? cell : thick
                  height: drawer.namedMenu || !bar.vertical ? thick : cell
                  z: -1
                  // The keyboard cursor lights the same mark, outlined (KEYS-69).
                  readonly property bool keysCursor: drawer.selectionVisible && drawer.cursor === mount.index
                  hovered: ((memberHover.hovered && !bar.barDragSource) || keysCursor) && drawer.opened && !preview.hidden
                  outlined: keysCursor && hovered
                  // A group's row stays lit while its submenu is open.
                  selected: modelData ? modelData.panelOpen
                    || (mount.opensSubmenu && !!drawer.submenu && drawer.submenu.opened && drawer.submenu.parentRow === mount) : false
                  motionEnabled: bar.animationsEnabled
                  glide: rowGlide
                  glideKey: "rows"
                  hoverColor: bar.highlightHoverColor
                  selectedColor: bar.highlightSelectedColor
                  rounding: CellModel.radius(drawer.tokens, bar.islandRounding)
                }
                Text {
                  id: label
                  visible: mount.labelled
                  textFormat: Text.PlainText
                  text: mount.title
                  // On the notch's black, the bar's own light text.
              color: drawer.notchColours ? drawer.bar.barForeground : drawer.bar.textOn(drawer.namedMenu ? Commons.Color.menu.text : Commons.Color.popups.text)
                  font.family: drawer.namedMenu ? Style.font.menuFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  // Names end one air before the row's end, or before a trailing value.
                  x: mount.labelStart + mount.animatedInsetX
                  y: (mount.baseHeight - height) / 2 + mount.animatedInsetY
                  width: Math.max(0, drawer.menuRowWidth - mount.labelStart - drawer.tokens.air
                    - (mount.valueWidth > 0 ? mount.valueWidth + drawer.tokens.air : 0))
                  elide: Text.ElideRight
                }
                GroupFace {
                  visible: mount.opensSubmenu
                  group: mount.opensSubmenu ? mount.modelData.groupConfig : null
                  faceMode: "glyph"
                  color: label.color
                  fontFamily: Style.font.family
                  fontSize: Style.font.body
                  x: mount.animatedInsetX + (drawer.tokens.cell - width) / 2
                  y: mount.animatedInsetY + (mount.baseHeight - height) / 2
                }
                Text {
                  visible: mount.opensSubmenu
                  textFormat: Text.PlainText
                  // Towards the side its submenu opens.
                  text: drawer.subBefore ? "󰅁" : "󰅂"
                  color: label.color
                  opacity: 0.7
                  font.family: Style.font.menuFamily
                  font.pixelSize: Style.font.bodySmall
                  x: mount.animatedInsetX + drawer.menuRowWidth - drawer.tokens.air - drawer.chevronWidth
                  y: (mount.baseHeight - height) / 2 + mount.animatedInsetY
                }
                // A menu row takes the pointer whole: a drag anywhere on it moves
                // the member and a click activates it. Above the widget, whose own
                // area took presses for itself, so a value widget (the battery)
                // could only be dragged by its name.
                Item {
                  id: rowPointer
                  anchors.fill: parent
                  visible: mount.labelled
                  z: 10
                  // A submenu takes no drags yet: a drop into it would not resolve.
                  DragHandler {
                    target: null
                    enabled: mount.labelled && !drawer.isSubmenu
                    acceptedButtons: Qt.LeftButton
                    property point lastScene
                    onCentroidChanged: if (active) { lastScene = centroid.scenePosition; bar.updateIconDrag(lastScene, modelData) }
                    onActiveChanged: {
                      if (active) {
                        lastScene = centroid.scenePosition
                        // Hold first: starting a drag can commit the previous
                        // drop, which may close this drawer.
                        drawer.dragMount = mount
                        if (!bar.beginIconDrag(modelData, hostWindow, lastScene,
                            centroid.position.x,
                            centroid.position.y)) drawer.releaseDrag(mount)
                      } else {
                        if (bar.barDragSource === modelData) bar.finishIconDrag(lastScene, modelData)
                        drawer.releaseDrag(mount)
                      }
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                      if (mouse.button === Qt.LeftButton) drawer.activateRow(mount.index, false)
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
              }
            }
          }
          AnimatedSlot {
            id: endGap
            readonly property bool gap: DragModel.endGap(bar.dragPreview, bar.dragSurfaceForDrawer(drawer))
            x: drawer.stripVertical ? 0 : contents.width
            y: drawer.stripVertical ? contents.height : 0
            targetWidth: drawer.stripVertical ? drawer.thickness : gap ? bar.dragGapWidth : 0
            targetHeight: drawer.stripVertical ? (gap ? (drawer.namedMenu ? drawer.rowPitch : bar.dragGapHeight) : 0) : drawer.thickness
            motionEnabled: bar.animationsEnabled && drawer.opened && !drawer.replaying && !bar.dragHandover
            DrawerOutline {
              open: endGap.gap
              gapLength: drawer.stripVertical ? parent.height : parent.width
              fullGap: drawer.namedMenu ? drawer.rowPitch : drawer.stripVertical ? drawer.bar.dragGapHeight : drawer.bar.dragGapWidth
              landingOffset: drawer.namedMenu ? drawer.padding : -1
            }
            motionDuration: bar.dragMotionDuration
            motionEasing: bar.dragMotionEasing
            motionOvershoot: 0
          }
        }
      }
    }
  }
}
