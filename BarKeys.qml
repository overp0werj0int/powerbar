import QtQuick
import Quickshell.Hyprland
import qs.Commons
import "BarKeysModel.js" as KeysModel

// The bar's keyboard mode (docs/behavior/keyboard.md): Super+B (omarchy-shell
// powerbar keys) puts a cursor on the clock of the focused monitor's bar.
// The keys that run along the bar move it, the key that points into the
// screen goes into a group's drawer, Tab jumps a zone, / finds a widget by
// name, ? lists every widget's shortcut, Enter opens, Esc steps back a layer.
//
// The cursor is on a stop: a widget or group icon on the bar, or a zone's
// dots. Stops are read from the bar as it stands, so an expansion or a fold
// changes them under the cursor the way it changes what the pointer finds.
// BarKeysModel.js decides what each key means on this edge.
Item {
  id: keys
  required property var bar
  visible: false

  property bool active: false
  // The bar window the cursor is on (the focused monitor's).
  property var window: null
  // The stop under the cursor: a slot, or a zone's dots (FoldHandle).
  property var cursor: null
  // A drawer opened from the cursor: a group's, or a zone's (drawer mode).
  property var drawer: null
  // The drawer is unfolded beside the icon but not entered.
  property bool previewing: false
  // Dots opening under the cursor: { token, dir, key } until they have.
  property var pending: null
  property bool searching: false
  property string query: ""
  property int matchIndex: 0
  property int matchCount: 0
  property bool sheet: false
  // A panel opened from the cursor holds the keyboard; Esc in it comes back.
  readonly property bool suspended: active && !!bar.activePopout
  // Just after Enter on a widget the bar lets go of the keyboard while it
  // sees what opens (handOff): a panel that registers with the bar
  // (Omarchy's KeyboardPanel, PopupCard) is a step into the bar, and Esc in
  // it comes back to the cursor; a window or layer of its own is a
  // destination, so the mode ends and the keys stay there; nothing (a
  // toggle) and the bar takes the keys back.
  property bool handOff: false
  readonly property bool here: active && !suspended && !handOff
  readonly property string position: bar.position
  readonly property bool cursorIsDots: !!cursor && cursor.isFoldHandle === true
  readonly property string zone: !cursor ? "" : cursorIsDots ? cursor.zone : cursor.isPrefsButton ? "right" : String(cursor.region || "")
  // What the key strip shows: "bar", "drawer" or "search".
  readonly property string mode: searching ? "search" : drawer && !previewing ? "drawer" : "bar"

  // For tests and IPC (powerbar keysStatus).
  function status() {
    var d = drawer
    return { active: active, suspended: suspended, screen: window && window.screen ? String(window.screen.name) : "",
      cursor: !cursor ? "" : cursorIsDots ? "dots:" + cursor.inlineToken : nameOf(cursor), kind: kindOf(cursor), zone: zone,
      cursorState: cursor && !cursorIsDots ? { managed: cursor.managed, inlineShown: cursor.inlineShown, activity: cursor.activityVisible, hovered: cursor.hovered, token: cursor.inlineToken } : null,
      stops: active ? stops().map(function(s) { return s.kind === "dots" ? "dots:" + s.item.inlineToken : nameOf(s.item) }) : [],
      drawer: d ? { group: d.groupId, zone: d.zone, previewing: previewing, aside: d.steppedAside, cursor: d.cursorActive ? d.cursor : -1,
        member: d.cursorActive && d.slots[d.cursor] ? bar.slotName(d.slots[d.cursor]) : "" } : null,
      searching: searching, query: query, matches: matchCount, sheet: sheet, handOff: handOff, foreign: foreign, inline: window ? window.inlineZone : "",
      barHidden: bar.barHidden, windowActive: !!(window && window.keysWindowActive), drawerFocused: !!(drawer && drawer.activeFocus), pointer: window && window.barPointer ? { hovered: window.barPointer.hovered, x: Math.round(window.barPointer.point.position.x), y: Math.round(window.barPointer.point.position.y) } : null, card: { shown: bar.tooltipShown, text: bar.tooltipText, mine: bar.tooltipTarget === cardTarget && !!cardTarget, belongs: !!cursor && bar.targetBelongsToWindow(cursor, window) }, focused: !!(window && window.keyCatcher && window.keyCatcher.activeFocus) }
  }
  function heldBy(window) { return active && !!keys.window && bar.sameWindow(keys.window, window) }

  // ---- the stops ---------------------------------------------------------
  function seen(item) {
    if (!item || !item.visible || item.width <= 0 || item.height <= 0) return false
    var w = keys.window
    if (item.isFoldHandle) return item.shown && !item.fitYielded && !w.zoneHidden(item.zone)
    if (item.isPrefsButton) return !w.zoneHidden("right")
    return item.mainVisible && !item.drawerHost && !item.fitYielded && !w.zoneHidden(item.region)
  }
  // A widget of an expansion that will be a stop once it has grown.
  function landable(slot) {
    return slot.mainVisible && !slot.drawerHost && !slot.fitYielded && !keys.window.zoneHidden(slot.region)
  }
  // Every stop on the bar, in bar order, row by row: { item, kind, zone, at,
  // row } (row 1: a notch zone's second row, under the bar's own).
  function stops() {
    var w = keys.window
    if (!w || !w.contentItem) return []
    var out = []
    var vertical = bar.vertical
    function add(item, kind, zone) {
      var c = item.mapToItem(w.contentItem, item.width / 2, item.height / 2)
      out.push({ item: item, kind: kind, zone: zone, at: vertical ? c.y : c.x, row: w.notchLook && c.y > bar.barSize ? 1 : 0 })
    }
    ;(w.moduleItems || []).forEach(function(slot) {
      if (seen(slot)) add(slot, slot.groupHeader ? "group" : "widget", slot.region)
    })
    ;(w.foldHandles || []).forEach(function(h) { if (seen(h)) add(h, "dots", h.zone) })
    if (w.prefsButton && seen(w.prefsButton)) add(w.prefsButton, "prefs", "right")
    out.sort(function(a, b) { return a.row - b.row || a.at - b.at })
    return out
  }
  function indexOf(list, item) {
    for (var i = 0; i < list.length; i++) if (list[i].item === item) return i
    return -1
  }
  // Where the cursor is in the list, or (its stop gone, dots that gave way)
  // the first stop of its zone.
  function at(list) {
    var i = indexOf(list, cursor)
    if (i >= 0 || !zone) return i
    for (var j = 0; j < list.length; j++) if (list[j].zone === zone) return j
    return -1
  }
  function kindOf(item) { return !item ? "" : item.isFoldHandle ? "dots" : item.isPrefsButton ? "prefs" : item.groupHeader ? "group" : "widget" }
  // What the cursor's stop is called on the card and in a search.
  function nameOf(item) { return !item ? "" : item.isFoldHandle || item.isPrefsButton ? item.label : bar.slotName(item) }
  // A stop that opens a drawer: a group, or a zone's dots in drawer mode.
  function opensDrawer(item) { var k = kindOf(item); return k === "group" || (k === "dots" && !bar.onDemandInline) }
  // The zone whose drawer the cursor here previews, as the pointer resting
  // there opens it (DEMAND-17): in drawer mode, a widget of a zone with On
  // demand widgets, or its dots. "" for anything else.
  function previewZone(item) {
    var k = kindOf(item)
    if (bar.onDemandInline || (k !== "widget" && k !== "dots")) return ""
    var z = k === "dots" ? item.zone : String(item.region || "")
    return z && bar.managedSlots(z, window).length ? z : ""
  }
  // A drawer the cursor previews: its group's, or its zone's.
  function previews(item) { return kindOf(item) === "group" || previewZone(item) !== "" }

  // ---- entering and leaving ---------------------------------------------
  function toggle() { if (active) leave(); else enter() }
  // `/` from outside (powerbar keysSearch): the mode on the focused monitor's
  // bar with the search open, from wherever the mode was; while a search is
  // open, the mode ends, so one shortcut opens and closes it.
  function search() {
    if (active && searching) { leave(); return }
    var w = bar.focusedBarWindow()
    if (active && (!here || !w || !bar.sameWindow(window, w))) leave()
    if (!active) enter()
    if (!active) return
    if (drawer) closeDrawer(true)
    startSearch()
  }
  // onWindow and at: a bar and a stop to start on (back from Preferences).
  function enter(onWindow, at) {
    if (bar.preferencesOpen) return
    var w = onWindow || bar.focusedBarWindow()
    if (!w) return
    window = w
    active = true
    searching = false; query = ""; sheet = false; drawer = null; previewing = false; pending = null
    bar.refreshShortcuts()
    // Start on the widget whose panel is open, else the clock, else the middle.
    var list = stops()
    var open = list.find(function(s) { return s.item.panelOpen })
    var anchor = list.find(function(s) { return s.item.centerAnchorSlot })
    var back = at ? list.find(function(s) { return s.item === at }) : null
    var start = back || open || anchor || list[Math.floor(list.length / 2)]
    cursor = start ? start.item : null
    showCard()
    focusLater()
  }
  function leave() {
    if (!active) return
    // A panel the cursor opened goes too: leaving is back to work.
    if (suspended && bar.activePopout && typeof bar.activePopout.close === "function") bar.activePopout.close()
    handOff = false
    handOffEnd.stop()
    foreignCheck.stop()
    previewTimer.stop()
    closeDrawer(false)
    if (window && window.inlineZone) window.inlineAsk("")
    bar.hideCard()
    active = false
    searching = false; query = ""; sheet = false; pending = null
    following = null
    dropQueued()
    cursor = null
    window = null
  }
  function focusLater() {
    Qt.callLater(function() {
      if (!keys.here || !keys.window) return
      if (keys.drawer && !keys.previewing && keys.drawer.opened) keys.drawer.forceActiveFocus()
      else if (keys.window.keyCatcher) keys.window.keyCatcher.forceActiveFocus()
    })
  }
  onSuspendedChanged: if (!suspended && active) { panelClosedAt = Date.now(); showCard(); focusLater() }

  // Esc twice quickly ends everything from any depth: the panel, the drawer,
  // the search, the mode. A panel's own Esc counts as the first (the bar sees
  // it close). Once the mode has ended the keys are the window's, as after
  // Omarchy's panels and menu: an extra Esc reaches it.
  readonly property int doubleEscMs: 400
  property real lastEscAt: 0
  property real panelClosedAt: 0
  function doubleEscape(name) {
    if (name !== "Escape") return false
    var now = Date.now(), quick = now - lastEscAt < doubleEscMs || now - panelClosedAt < doubleEscMs
    lastEscAt = now
    if (!quick) return false
    leave()
    return true
  }

  // The keys must always land somewhere: if neither the bar nor a drawer it
  // opened has them (a drawer closed under them), the bar takes them back.
  readonly property bool hasFocus: !!window && (!!window.keyCatcher && window.keyCatcher.activeFocus || !!drawer && drawer.activeFocus)
  onHasFocusChanged: if (!hasFocus && here) refocus.restart()
  Timer { id: refocus; interval: 60; onTriggered: if (keys.here && !keys.hasFocus) keys.focusLater() }

  // ---- moving -------------------------------------------------------------
  function put(item, dir) {
    // A zone's preview stays open while the cursor walks along its zone.
    var d = drawer
    if (!(d && previewing && !d.groupId && previewZone(item) === d.zone)) closeDrawer(false)
    cursor = item
    // Leaving an expanded zone folds it behind its dots again.
    var w = window
    if (w && w.inlineZone && w.inlineZoneName !== zone) w.inlineAsk("")
    if (cursorIsDots && bar.onDemandInline) openDots(cursor.inlineToken, dir, "")
    showCard()
    focusLater()
  }
  function moveBy(dir) {
    var list = stops(), i = at(list)
    if (i < 0) { if (list.length) put(list[dir > 0 ? 0 : list.length - 1].item, dir); return }
    var to = KeysModel.gridStep(list, i, dir, 0)
    if (to >= 0) put(list[to].item, dir)
  }
  // To the next row of the cursor's zone (a notch zone's second row): +1
  // away from the screen edge. Whether there was one.
  function moveRow(rows) {
    var list = stops(), i = at(list)
    var to = i >= 0 ? KeysModel.gridStep(list, i, 0, rows) : -1
    if (to < 0) return false
    put(list[to].item, rows)
    return true
  }
  function zoneJump(dir) {
    var list = stops(), i = at(list)
    var to = KeysModel.zoneStep(list.map(function(s) { return s.zone }), Math.max(0, i), dir)
    if (to >= 0) put(list[to].item, dir)
  }
  function toEnd(last) {
    var list = stops()
    if (list.length) put(list[last ? list.length - 1 : 0].item, last ? -1 : 1)
  }

  // ---- dragging (Shift+arrows, KEYS-86) ------------------------------------
  // The widget or group icon under the cursor moves to where the arrow would
  // move the cursor, landing as a pointer drop there lands (Bar.qml dropAt:
  // inside an expansion's run it goes On demand, on the dots too), and the
  // cursor goes with it. Shift with the into key sends it to its zone's open
  // drawer or expansion, with the out key back to the bar.
  function draggable(item) { var k = kindOf(item); return k === "widget" || k === "group" }
  function groupOf(slot) { return slot && slot.groupHeader ? slot.entry.powerbarGroupId : "" }
  // shell.json waits until Shift is let go (or another key, the mode
  // ending, a 2 s pause):
  // Omarchy's handling of each write would stall the next move.
  // One drag: the open drawer kept through the edit, and every slot that
  // moved gliding to its place. The write waits for the mode to end
  // (Bar.qml barInUse).
  function dragEdit(source, drop, what) {
    bar.keepDrawerThroughEdit = true
    var moved = false
    try { moved = bar.glideEdit(window, source, function() { return bar.dropAt(source, drop) }) }
    finally { bar.keepDrawerThroughEdit = false }
    bar.ev("keys", "drag " + nameOf(source) + " " + what + (moved ? "" : " refused"))
    return moved
  }
  // Beside the slot of `list` nearest `source` along the bar, on its side
  // facing `source`: { slot, after }, or null for an empty list.
  function alongOf(slot) {
    var item = slot.drawerHost || slot
    var c = item.mapToItem(window.contentItem, item.width / 2, item.height / 2)
    return bar.vertical ? c.y : c.x
  }
  function besideNearest(source, list) {
    var spot = KeysModel.besideNearest(list.map(alongOf), alongOf(source))
    return spot ? { slot: list[spot.index], after: spot.after } : null
  }
  function dragBy(dir) {
    var list = stops(), i = indexOf(list, cursor)
    if (i < 0 || !draggable(cursor)) return
    var to = KeysModel.gridStep(list, i, dir, 0)
    var drop = to >= 0 ? KeysModel.dragDrop(list[i].zone, list[to], dir) : null
    if (!drop) return
    var source = cursor, target = list[to].item
    var moved = drop.dots
      ? dragEdit(source, { managedZone: target.zone, handle: true, handleToken: target.inlineToken, managedBefore: bar.handleDropBefore(target, source) }, "dots " + target.zone)
      : dragEdit(source, { slot: target, after: drop.after }, (drop.after ? "after " : "before ") + nameOf(target))
    if (moved) follow(source, drop.dots ? target.zone : list[to].zone)
  }
  // Into the zone's open drawer, beside its member nearest the widget, and
  // the keys go in with it; or, In the bar, into the open expansion's run.
  function dragInto() {
    var source = cursor, w = window, d = drawer
    if (!draggable(source) || !w) return
    var spot, moved
    if (d && d.opened && !d.groupId && d.zone === zone) {
      var key = source.instanceKey, group = groupOf(source)
      spot = besideNearest(source, d.slots.filter(function(m) { return m && m.drawerHost }))
      moved = dragEdit(source, spot ? { slot: spot.slot, after: spot.after } : { drawer: d }, "into drawer " + d.zone)
      // Entered, as the into key enters it, with the cursor on the newcomer.
      if (moved) Qt.callLater(function() { if (keys.drawer === d && d.opened) { keys.openZoneDrawer(d.zone, key); keys.followMember(d, key, group, 0) } })
      return
    }
    if (!bar.onDemandInline || source.managed || w.inlineZoneName !== zone) return
    spot = besideNearest(source, (w.moduleItems || []).filter(function(s) {
      return s && s !== source && s.region === source.region && s.managed && seen(s)
    }))
    if (!spot) return
    moved = dragEdit(source, { slot: spot.slot, after: spot.after }, "into run " + (spot.after ? "after " : "before ") + nameOf(spot.slot))
    if (moved) follow(source, source.region)
  }
  // Out of the open expansion's run, beside the zone's shown widget nearest it.
  function dragOutOfRun() {
    var source = cursor, w = window
    if (!draggable(source) || !w || !source.managed || w.inlineZoneName !== zone) return
    var spot = besideNearest(source, (w.moduleItems || []).filter(function(s) {
      return s && s !== source && s.region === source.region && !s.managed && seen(s)
    }))
    var region = source.region
    if (dragEdit(source, spot ? { slot: spot.slot, after: spot.after } : { zone: region }, "out of run")) follow(source, region)
  }
  // The slot after the edit, by what it is, in its new zone.
  property var following: null
  function follow(source, zone) {
    following = { key: source.instanceKey, group: groupOf(source), zone: zone, tries: 0 }
    Qt.callLater(checkFollow)
  }
  function followed(slot, f) {
    if (!slot || slot.drawerHost || slot.region !== f.zone) return false
    return f.group ? groupOf(slot) === f.group : !slot.groupHeader && slot.instanceKey === f.key
  }
  function checkFollow() {
    var f = following, w = window
    if (!f || !w) return
    var slot = (w.moduleItems || []).find(function(s) { return followed(s, f) }) || null
    if (slot && seen(slot)) {
      following = null
      if (cursor !== slot) put(slot, 0)
      else showCard()
      return
    }
    // Gone behind its dots or into its zone's drawer: brought into view
    // there, as a search brings a widget in.
    if (++f.tries < 12) { followRetry.restart(); return }
    following = null
    if (slot) bringIn(slot)
  }
  Timer { id: followRetry; interval: 16; onTriggered: keys.checkFollow() }
  // In a drawer: the member under the cursor moves one row or cell, and the
  // cursor stays on it.
  function dragMember(step) {
    var d = drawer
    if (!d || !d.cursorActive) return
    var to = d.cursor + step
    if (to < 0 || to >= d.slots.length) return
    var source = d.slots[d.cursor], target = d.slots[to]
    var key = source.instanceKey, group = groupOf(source)
    if (dragEdit(source, { slot: target, after: step > 0 }, (step > 0 ? "after " : "before ") + nameOf(target) + " in drawer"))
      Qt.callLater(function() { followMember(d, key, group, 0) })
  }
  // Out of the drawer onto the bar: a zone's member beside the zone's stop
  // nearest it, a group's beside its group's icon. The cursor goes with it
  // and a zone's drawer folds back to its preview.
  function dragOut() {
    var d = drawer
    if (!d || !d.cursorActive || !d.slots[d.cursor]) return
    var source = d.slots[d.cursor], drop
    if (d.groupId) {
      var header = headerOf(source)
      if (!header) return
      drop = { slot: header, after: true }
    } else {
      var spot = besideNearest(source, stops().filter(function(st) {
        return st.zone === d.zone && !st.row && (st.kind === "widget" || st.kind === "group")
      }).map(function(st) { return st.item }))
      drop = spot ? { slot: spot.slot, after: spot.after } : { zone: d.zone }
    }
    var region = d.groupId ? (headerOf(source) || source).region : d.zone
    if (!dragEdit(source, drop, "out of drawer")) return
    // A zone's drawer folds back to the preview the cursor gives it there.
    if (!d.groupId) { d.openZone(d.zone, false); previewing = true }
    follow(source, region)
  }
  function followMember(d, key, group, tries) {
    if (drawer !== d) return
    var at = d.slots.findIndex(function(s) {
      return s && (group ? groupOf(s) === group : !s.groupHeader && s.instanceKey === key)
    })
    if (at < 0 && tries < 12) { Qt.callLater(function() { followMember(d, key, group, tries + 1) }); return }
    if (at < 0) return
    d.cursor = at
    d.cursorActive = true
    d.navigate(0)
  }

  // Dots open the way the pointer opens them, and the cursor lands on the
  // first widget that appeared in the direction it was going (or on `key`).
  function openDots(token, dir, key) {
    var w = window
    pending = { token: token, dir: dir, key: key || "", tries: 0 }
    w.inlineEnter(token, true, true)
    Qt.callLater(checkPending)
  }
  function checkPending() {
    var p = pending, w = window
    if (!p || !w) return
    if (p.seek) {
      if (seen(p.seek) || p.seek.inlineShown && w.inlineZone === p.token && landable(p.seek)) { pending = null; landOn(p.seek, p.member); if (p.open) openMatch(); return }
      // The expansion could not fit (the bar gave up on it): the zone's
      // drawer, as for the pointer.
      var refused = p.token && w.inlineRequest !== p.token && w.inlineZone !== p.token
      if (!refused && ++p.tries < 60) { landRetry.restart(); return }
      // Still out of view (another moment holds the room): its zone's
      // drawer, when it has a place there.
      pending = null
      if (inZoneDrawer(p.seek)) { openInZoneDrawer(p.seek, p.member); if (p.open && drawer) openMatch() }
      return
    }
    if (w.inlineZone === p.token) {
      // The cursor lands as the zone opens, on a widget that has yet to grow
      // (KEYS-12): its ring never leaves with the dots.
      var shown = w.inlineSlots(p.token).filter(landable)
      var pick = p.key ? shown.find(function(s) { return s.instanceKey === p.key }) : null
      // A search's widget may come a few frames later: wait for it.
      if (!pick && (p.key || !shown.length) && ++p.tries < 20) { landRetry.restart(); return }
      pending = null
      if (!shown.length) return
      if (!pick) pick = p.dir < 0 ? shown[shown.length - 1] : shown[0]
      cursor = pick
      showCard()
      if (p.open) openCursor()
      return
    }
    // The zone could not open in the bar: its drawer took the widgets.
    if (w.inlineRequest !== p.token && w.inlineZone !== p.token) {
      pending = null
      var zone = p.token.split(":")[0]
      w.managedDrawer.openZone(zone, true)
      if (w.managedDrawer.opened) {
        adoptDrawer(w.managedDrawer, p.key)
        var d = w.managedDrawer
        if (p.open) activate(d.slots[d.cursor])
      }
    }
  }
  Timer { id: landRetry; interval: 25; onTriggered: keys.checkPending() }
  Connections {
    target: keys.window
    ignoreUnknownSignals: true
    function onInlineZoneChanged() { if (keys.pending) Qt.callLater(keys.checkPending) }
    function onInlineRequestChanged() { if (keys.pending) Qt.callLater(keys.checkPending) }
  }

  // ---- drawers ------------------------------------------------------------
  // A group's drawer unfolds beside its icon, and a zone's beside the zone,
  // once the key is let go, so a held key sweeping past never flashes it.
  function released() {
    if (!here || drawer || !previews(cursor)) return
    previewTimer.restart()
  }
  Timer {
    id: previewTimer
    interval: 100
    onTriggered: if (keys.here && !keys.drawer && keys.previews(keys.cursor)) keys.openDrawer(false)
  }
  function openDrawer(enterIt) {
    var w = window, d = w ? w.managedDrawer : null, item = cursor
    if (!d || !item) return
    if (kindOf(item) === "group") d.openGroup(item.entry.powerbarGroupId, item, enterIt)
    else d.openZone(previewZone(item), enterIt)
    if (!d.opened) return
    d.barKeysHeld = true
    drawer = d
    previewing = !enterIt
    if (enterIt) { d.cursor = 0; d.cursorActive = true; d.navigate(0) }
    focusLater()
  }
  function openZoneDrawer(name, key) {
    var d = window ? window.managedDrawer : null
    if (!d) return
    d.openZone(name, true)
    if (d.opened) adoptDrawer(d, key)
  }
  function adoptDrawer(d, key) {
    d.barKeysHeld = true
    drawer = d
    previewing = false
    var at = key ? d.slots.findIndex(function(s) { return s.instanceKey === key }) : 0
    d.cursor = Math.max(0, at); d.cursorActive = true; d.navigate(0)
    focusLater()
  }
  // Out of a drawer the cursor would preview anyway (its group's icon, a
  // widget of its zone): it folds back to that preview where it is, not
  // closed and opened again.
  function backToBar() {
    var d = drawer, item = cursor
    var same = d && d.opened && !d.steppedAside && (kindOf(item) === "group" ? d.groupId === item.entry.powerbarGroupId
      : !d.groupId && previewZone(item) === d.zone)
    if (!same) { closeDrawer(true); return }
    // Previewing first: the card the drawer's cursor gives up moves to the
    // bar's cursor as the same popup (LOOK-136), never hidden in between.
    previewing = true
    openDrawer(false)
    showCard()
  }
  function closeDrawer(refocus) {
    previewTimer.stop()
    var d = drawer
    drawer = null
    previewing = false
    if (d) { d.barKeysHeld = false; if (d.opened) d.close("immediate") }
    if (refocus !== false) showCard()
    // The drawer may have had the keys: they always come back to the bar.
    focusLater()
  }
  Connections {
    target: keys.drawer
    ignoreUnknownSignals: true
    // Back from stepping aside for a member's panel: the keys go to it again.
    function onSteppedAsideChanged() { if (keys.drawer && !keys.drawer.steppedAside && keys.here) keys.focusLater(); if (keys.active) keys.showCard() }
    function onCursorChanged() { if (keys.active) keys.showCard() }
    function onCursorActiveChanged() { if (keys.active) keys.showCard() }
    // Closed from elsewhere (the pointer, a widget): the keys come back to the bar.
    function onOpenedChanged() {
      if (keys.drawer && !keys.drawer.opened) {
        keys.drawer.barKeysHeld = false
        keys.drawer = null
        keys.previewing = false
        if (keys.active) { keys.showCard(); keys.focusLater() }
      }
    }
  }

  // ---- opening ------------------------------------------------------------
  // Opens a widget as a click does, letting go of the keyboard for whatever
  // it opens (handOff above).
  function activate(slot) {
    if (!slot) return
    bar.hideCard()
    handOff = true
    handOffEnd.restart()
    slot.activate()
  }
  Timer { id: handOffEnd; interval: 400; onTriggered: { keys.handOff = false; if (keys.active && !keys.suspended) { keys.showCard(); keys.focusLater() } } }

  // A window or layer that is not the bar's opens (from Enter, or any other
  // way: a bind, a launcher): it is a destination, so the mode ends and leaves
  // the keys there. A registered panel is not: it shows as activePopout.
  // Surfaces that never take the keyboard don't count.
  function passive(namespace) {
    return /^powerbar/.test(namespace) || /^omarchy-(background|bar|bar-drag-ghost|bar-move-ghost|notifications|osd|keyboard-panel-dismiss|lock-preview)$/.test(namespace)
  }
  property string foreign: ""
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!keys.active || !event || !event.name) return
      var name = String(event.name), data = String(event.data || "")
      if (name === "openlayer" && !keys.passive(data) || name === "openwindow") {
        keys.foreign = name + " " + data
        foreignCheck.restart()
      }
    }
  }
  Timer {
    id: foreignCheck
    interval: 150
    onTriggered: if (keys.active && !keys.bar.activePopout) keys.leave()
  }
  function openCursor() {
    var item = cursor
    if (!item) return
    if (opensDrawer(item)) { openDrawer(true); return }
    // Preferences takes the keyboard: the mode ends until , brings it back.
    if (item.isPrefsButton) { openPreferences(); return }
    if (item.isFoldHandle) { openDots(item.inlineToken, 1, ""); return }
    activate(item)
  }

  // ---- keys ---------------------------------------------------------------
  function keyName(event) {
    switch (event.key) {
    case Qt.Key_Left: return "Left"
    case Qt.Key_Right: return "Right"
    case Qt.Key_Up: return "Up"
    case Qt.Key_Down: return "Down"
    case Qt.Key_Home: return "Home"
    case Qt.Key_End: return "End"
    case Qt.Key_PageUp: return "PageUp"
    case Qt.Key_PageDown: return "PageDown"
    case Qt.Key_Backtab: return "Backtab"
    case Qt.Key_Tab: return event.modifiers & Qt.ShiftModifier ? "Backtab" : "Tab"
    case Qt.Key_Return: case Qt.Key_Enter: return "Enter"
    case Qt.Key_Space: return "Space"
    case Qt.Key_Escape: return "Escape"
    case Qt.Key_Backspace: return "Backspace"
    }
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return ""
    return event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 ? event.text : ""
  }
  // A panel opened from the cursor is open, but the keys stayed with the bar
  // (a panel drawn as a popup of the bar, not a layer of its own): nothing
  // moves under it, and Esc closes it, as it would from inside.
  function panelKey(name) {
    var popout = bar.activePopout
    if (name === "Escape" && popout && typeof popout.close === "function") popout.close()
    return true
  }
  // A key on the bar. Returns whether it was used.
  function barKey(event) {
    var name = keyName(event)
    bar.ev("key", (name || "code=" + event.key) + " bar")
    if (active && doubleEscape(name)) return true
    if (name && active && suspended) return panelKey(name)
    if (!name || !here) return false
    previewTimer.stop()
    if (searching && searchKey(name)) return true
    if (sheet) {
      sheet = false
      if (name === "Escape" || name === "?") return true
    }
    var drag = KeysModel.dragKey(name, event.modifiers & Qt.ShiftModifier)
    if (drag) {
      var step = KeysModel.barIntent(position, drag)
      if (step && step.move) dragBy(step.move)
      else if (step && step.into) dragInto()
      else if (step && step.out) dragOutOfRun()
      return true
    }
    var it = KeysModel.barIntent(position, name)
    if (!it) return true
    if (it.move) moveBy(it.move)
    else if (it.zone) zoneJump(it.zone)
    else if (it.home) toEnd(false)
    else if (it.end) toEnd(true)
    else if (it.out) moveRow(-1)
    else if (it.into) {
      if (moveRow(1)) return true
      if (opensDrawer(cursor)) openDrawer(true)
      // Drawer mode: a zone's on-demand widgets wait in its drawer, entered
      // from any widget of the zone.
      else if (!bar.onDemandInline && zone && bar.managedSlots(zone, window).length) openZoneDrawer(zone, "")
    }
    else if (it.open) openCursor()
    else if (it.find) startSearch()
    else if (it.sheet) sheet = true
    else if (it.prefs) openPreferences()
    else if (it.leave) leave()
    return true
  }
  // A key in a drawer opened from the cursor.
  function drawerKey(event) {
    var name = keyName(event), d = drawer
    bar.ev("key", (name || "code=" + event.key) + " drawer")
    if (d && active && doubleEscape(name)) return true
    if (name && d && active && suspended) return panelKey(name)
    if (!name || !here || !d) return false
    if (searching && searchKey(name)) return true
    if (sheet) { sheet = false; if (name === "Escape" || name === "?") return true }
    var drag = KeysModel.dragKey(name, event.modifiers & Qt.ShiftModifier)
    if (drag) {
      var step = KeysModel.drawerIntent(position, drag, d.cursorActive ? d.cursor : 0, !d.namedMenu)
      if (step && step.member) dragMember(step.member)
      else if (step && step.back) dragOut()
      return true
    }
    var it = KeysModel.drawerIntent(position, name, d.cursorActive ? d.cursor : 0, !d.namedMenu)
    if (!it) return true
    if (it.member) {
      var to = (d.cursorActive ? d.cursor : -1) + it.member
      if (to >= 0 && to < d.slots.length) { d.cursor = to; d.cursorActive = true; d.navigate(0) }
    } else if (it.first || it.last) {
      if (d.slots.length) { d.cursor = it.first ? 0 : d.slots.length - 1; d.cursorActive = true; d.navigate(0) }
    } else if (it.back) backToBar()
    else if (it.backMove) { closeDrawer(true); moveBy(it.backMove) }
    else if (it.zone) { closeDrawer(true); zoneJump(it.zone) }
    else if (it.open) activate(d.slots[d.cursor])
    else if (it.find) { closeDrawer(true); startSearch() }
    else if (it.sheet) sheet = true
    else if (it.prefs) openPreferences()
    return true
  }

  // ---- Preferences ----------------------------------------------------------
  // , opens Preferences on this bar's monitor; Preferences takes the keyboard,
  // so the mode ends. , there (Preferences.qml) closes it and brings the mode
  // back on the same bar with the cursor where it was (KEYS-81).
  property var backFrom: null
  property bool toPreferences: false
  function openPreferences() {
    var w = window, at = cursor
    if (!w) return
    toPreferences = true
    bar.showPreferences(w.screen)
    toPreferences = false
    backFrom = { window: w, cursor: at }
  }
  function backFromPreferences() {
    var b = backFrom
    backFrom = null
    if (b && b.window) enter(b.window, b.cursor)
  }
  // Preferences opened any other way forgets the way back.
  Connections {
    target: keys.bar
    function onPreferencesOpenChanged() { if (keys.bar.preferencesOpen && !keys.toPreferences) keys.backFrom = null }
  }

  // ---- finding --------------------------------------------------------------
  // Everything a search can reach: every widget and group of this bar, from
  // the bar's own store, wherever it is right now (on the bar, behind dots, in
  // a drawer, folded off, or out of the way of another zone), plus the
  // Powerbar button. Hidden widgets have no slot. A member is found by its
  // group's name too ("ai a").
  function catalogue() {
    var w = window
    if (!w) return []
    var out = (w.moduleItems || []).filter(function(s) { return !!s }).map(function(s) {
      var name = bar.slotName(s)
      return { name: name, text: KeysModel.searchText(name, s.memberGroup ? s.memberGroup.label : ""), slot: s }
    })
    if (w.prefsButton) out.push({ name: nameOf(w.prefsButton), text: nameOf(w.prefsButton), slot: w.prefsButton })
    return out
  }
  function startSearch() { searching = true; query = ""; matchIndex = 0; matchCount = 0; sheet = false }
  function searchKey(name) {
    if (name === "Escape") { searching = false; query = ""; dropQueued(); return true }
    if (name === "Enter") { searching = false; query = ""; openMatch(); return true }
    if (name === "Tab") { reveal(matchIndex + 1, true); return true }
    if (name === "Backtab") { reveal(matchIndex - 1, true); return true }
    // An arrow, Home or End ends the search where it is and does its usual
    // job (↓ on a top bar goes into the group found).
    if (["Up", "Down", "Left", "Right", "Home", "End"].indexOf(name) >= 0) {
      searching = false
      query = ""
      dropQueued()
      return false
    }
    if (name === "Backspace") { query = query.slice(0, -1); reveal(0); return true }
    if (name.length === 1 && name !== " " || name === "Space") {
      query += name === "Space" ? " " : name
      reveal(0)
    }
    return true
  }
  // Enter on a match opens it: a member in its group's drawer, a widget behind
  // dots once they have opened, or what the cursor is on.
  function openMatch() {
    if (queued) flushQueued()
    var d = drawer
    if (d && !previewing && d.cursorActive && d.slots[d.cursor]) { activate(d.slots[d.cursor]); return }
    if (pending) { pending.open = true; return }
    openCursor()
  }
  // Put the cursor on a match, opening the way to it.
  // Typing moves the cursor at once to a match already on the bar; anything
  // that changes the bar (dots opening, another zone closing, a drawer) waits
  // for a pause, as the pointer's dots wait for intent, so the bar doesn't
  // flicker through each letter's match. Tab and Enter act at once.
  function reveal(which, now) {
    var list = catalogue(), found = KeysModel.matches(list.map(function(c) { return c.text }), query)
    matchCount = found.length
    queued = null
    revealPause.stop()
    if (!found.length) { matchIndex = 0; return }
    matchIndex = ((which % found.length) + found.length) % found.length
    var slot = list[found[matchIndex]].slot
    if (now || onBarNow(slot)) { bringIn(slot); return }
    queued = slot
    revealPause.restart()
  }
  property var queued: null
  Timer { id: revealPause; interval: 150; onTriggered: keys.flushQueued() }
  function flushQueued() {
    var slot = queued
    queued = null
    revealPause.stop()
    if (slot && active) bringIn(slot)
  }
  function dropQueued() { queued = null; revealPause.stop() }
  // On the bar now, or a member of a group whose icon is.
  function onBarNow(slot) {
    var target = slot.memberGroup ? headerOf(slot) : slot
    return !!target && seen(target)
  }
  // A member comes in through its group's icon.
  function headerOf(member) {
    var id = member && member.memberGroup ? member.memberGroup.id : ""
    return id ? (window.moduleItems || []).find(function(s) { return s && s.groupHeader && s.entry.powerbarGroupId === id }) || null : null
  }
  function inZoneDrawer(slot) {
    return !!slot.drawerHost || (!slot.isPrefsButton && bar.managedSlots(slot.region, window).indexOf(slot) >= 0)
  }
  // Brings a found widget into view the way the pointer would (route), then
  // lands on it once it is seen.
  function bringIn(slot) {
    var member = slot.memberGroup ? slot : null, target = member ? headerOf(member) : slot
    if (!target) return
    pending = null
    var w = window
    var how = KeysModel.route({ onBar: seen(target), inline: bar.onDemandInline, behindDots: !!target.inlineCandidate,
      folded: !!target.fitFolded, inDrawer: inZoneDrawer(target) })
    if (how === "put") { landOn(target, member); return }
    closeDrawer(false)
    if (how === "drawer") { openInZoneDrawer(target, member); return }
    var token = ""
    if (how === "dots") {
      // Its zone's dots open in place, as hovering them does: another zone's
      // expansion gives way, and the cursor waits on the dots.
      token = target.inlineToken
      if (w.inlineZone && w.inlineZone !== token) w.inlineAsk("")
      var handle = (w.foldHandles || []).find(function(h) { return h && h.inlineToken === token && seen(h) })
      if (handle) cursor = handle
      w.inlineEnter(token, true, true)
    } else if (w.inlineZone || w.inlineRequest) {
      // Out of the way of another zone's expansion: that closes.
      w.inlineCollapseNow()
    }
    pending = { seek: target, member: member, token: token, tries: 0 }
    Qt.callLater(checkPending)
  }

  // A widget in its zone's drawer; a group there opens its own drawer from
  // its row, at the member if one was found. The bar's cursor waits on the
  // zone's dots.
  function openInZoneDrawer(target, member) {
    var w = window
    var dots = (w.foldHandles || []).find(function(h) { return h && h.zone === target.region && seen(h) })
    var near = stops().find(function(st) { return st.zone === target.region })
    if (dots || near) cursor = dots || near.item
    openZoneDrawer(target.region, target.instanceKey)
    if (target.groupHeader && drawer) Qt.callLater(function() { openFoldedGroup(target, member) })
  }
  function openFoldedGroup(header, member) {
    var d = drawer, id = header.entry.powerbarGroupId
    if (!d || !header.drawerHost) return
    d.openGroup(id, header, true)
    if (d.opened && d.groupId === id) adoptDrawer(d, member ? member.instanceKey : "")
  }
  // The cursor on a widget the search brought in; for a member, its group's
  // drawer opens at it (unless already open there).
  function landOn(item, member) {
    if (member) {
      if (cursor !== item || !drawer || previewing) { put(item, 1); openDrawer(true) }
      var d = drawer
      if (d) { var at = d.slots.indexOf(member); if (at >= 0) { d.cursor = at; d.cursorActive = true; d.navigate(0) } }
      return
    }
    put(item, 1)
    if (previews(item)) openDrawer(false)
  }

  // ---- the shortcut sheet ---------------------------------------------------
  function targetOf(slot) {
    return !slot || slot.isFoldHandle || slot.isPrefsButton ? "" : slot.groupHeader ? "group:" + slot.entry.powerbarGroupId : "widget:" + slot.moduleName
  }
  // Every widget and group on this bar with a shortcut: [{ name, keys }].
  function sheetEntries() {
    var out = [], seenNames = {}
    catalogue().forEach(function(c) {
      var keys = bar.shortcutCaps(targetOf(c.slot)), name = c.name, seen = name + keys.join(" ")
      if (!keys.length || seenNames[seen]) return
      seenNames[seen] = true
      out.push({ name: name, keys: keys })
    })
    return out
  }

  // ---- the name card --------------------------------------------------------
  // What the name card is on: the cursor, or the drawer's current member.
  property var cardTarget: null
  function showCard() {
    var d = drawer, target = null, slot = null
    // In a drawer the card names its current member, where hovering it would.
    // A preview leaves the card on the cursor, past the drawer (LOOK-84); a
    // group's icon and the dots have none.
    if (here && d && !previewing) {
      if (d.opened && d.cursorActive && !d.steppedAside) { slot = d.slots[d.cursor]; target = slot ? d.cellAt(d.cursor) : null }
    } else if (here && cursor && !opensDrawer(cursor)) { slot = cursor; target = cursor }
    if (!target) { cardTarget = null; bar.hideCard(); return }
    var name = nameOf(slot)
    var menuRow = !!(here && d && d.namedMenu && target !== slot)
    var own = menuRow && typeof target.ownTooltip === "function" ? target.ownTooltip() : ""
    cardTarget = target
    bar.showCard(target, KeysModel.cardText(name, own, menuRow))
  }


  // The cursor follows the pointer (KEYS-45..47): it goes where the pointer
  // hovers, a stop on the bar or a drawer's row, and the keys carry on from
  // there. On the bar the pointer's own rules run as without the mode: a
  // drawer the keys held is let go to them, opening and closing as the
  // pointer's would.
  // Where the pointer last was, in its window's scene.
  property var lastPointer: null
  // Where the pointer was when the mode began: resting there is not a move.
  property real activeAt: 0
  onActiveChanged: {
    var p = active && window ? window.barPointer : null
    lastPointer = p && p.hovered ? { x: p.point.scenePosition.x, y: p.point.scenePosition.y } : null
    activeAt = Date.now()
  }
  // Only a pointer that moved counts: hover handlers also report the same
  // point again when the bar or a drawer changes under it, and the first
  // report after the pointer comes into an area (or one opens under it) is
  // where it rests, not a move. One that comes into an area settled under
  // it did move there.
  function pointerMoved(scene, settled) {
    var last = lastPointer
    lastPointer = { x: scene.x, y: scene.y }
    if (!last) return settled === true
    return Math.abs(last.x - scene.x) >= 1 || Math.abs(last.y - scene.y) >= 1
  }
  function pointerLeft() { lastPointer = null }
  Connections {
    target: keys.window ? keys.window.barPointer : null
    ignoreUnknownSignals: true
    function onPointChanged() {
      var p = keys.window ? keys.window.barPointer : null
      // The mode holds the bar shown: once it has slid in, a pointer that
      // comes onto it (from a drawer, say) did move there.
      var settled = keys.window.autoHideShown && Date.now() - keys.activeAt > 300
      if (!keys.here || !p || !p.hovered || !keys.pointerMoved(p.point.scenePosition, settled)) return
      keys.letDrawerGo()
      var pos = p.point.position
      var list = keys.stops()
      for (var i = 0; i < list.length; i++) {
        var item = list[i].item, local = item.mapFromItem(p.parent, pos.x, pos.y)
        if (local.x >= 0 && local.y >= 0 && local.x < item.width && local.y < item.height) {
          if (item !== keys.cursor) { keys.cursor = item; keys.showCard() }
          return
        }
      }
    }
    function onHoveredChanged() { if (keys.window && !keys.window.barPointer.hovered) keys.pointerLeft() }
  }
  // The pointer on the bar: a drawer the keys held goes back to the
  // pointer's rules (its icon under the pointer holds it, elsewhere it
  // closes as the pointer leaving it would). The keys take it again on the
  // into-key or when the pointer comes onto its rows.
  function letDrawerGo() {
    var d = drawer
    if (!d) return
    previewTimer.stop()
    drawer = null
    previewing = false
    d.barKeysHeld = false
    d.keyboardMode = false
    d.cursorActive = false
    showCard()
    focusLater()
  }
  // The pointer moved onto row `index` of drawer `d`: the cursor goes into
  // the drawer at that row, as the into-key and arrows would, and the keys
  // hold it, whoever opened it; its icon is the stop.
  function pointerOnRow(d, index, scene) {
    var settled = !!d && d.reveal >= 0.999 && Date.now() - d.shownAt > 250
    if (!pointerMoved(scene, settled) || !here || !d || !d.opened || index < 0 || index >= d.slots.length) return
    if (window && d !== window.managedDrawer) return
    if (drawer !== d) {
      var source = d.groupId ? d.anchorSlot : (window.foldHandles || []).find(function(h) { return h && h.zone === d.zone && seen(h) })
      if (!source || !seen(source)) return
      cursor = source
      d.barKeysHeld = true
      drawer = d
    }
    previewTimer.stop()
    previewing = false
    d.keyboardMode = true
    if (d.cursorActive && d.cursor === index) return
    d.cursor = index
    d.cursorActive = true
    d.navigate(0)
    showCard()
    focusLater()
  }
  // Dots the pointer opened under the cursor gave way to their widgets: the
  // cursor goes to the widget beside them (dots at the start of their run:
  // its first; at its end: its last).
  Connections {
    target: keys.window
    ignoreUnknownSignals: true
    function onInlineZoneChanged() {
      var w = keys.window, c = keys.cursor
      if (!keys.here || keys.pending || !w || !c || !c.isFoldHandle || w.inlineZone !== c.inlineToken) return
      var shown = w.inlineSlots(c.inlineToken).filter(keys.landable)
      if (!shown.length) return
      keys.cursor = c.side === "start" ? shown[0] : shown[shown.length - 1]
      keys.showCard()
    }
  }
}
