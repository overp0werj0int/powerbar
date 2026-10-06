import QtQuick
import qs.Commons
import "BarKeysModel.js" as KeysModel

// The bar's keyboard mode (docs/bar-keys-lab): Super+B (omarchy-shell
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
  readonly property bool here: active && !suspended
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
      drawer: d ? { group: d.groupId, zone: d.zone, previewing: previewing, cursor: d.cursorActive ? d.cursor : -1,
        member: d.cursorActive && d.slots[d.cursor] ? bar.slotName(d.slots[d.cursor]) : "" } : null,
      searching: searching, query: query, matches: matchCount, sheet: sheet, inline: window ? window.inlineZone : "",
      barHidden: bar.barHidden, windowActive: !!(window && window.keysWindowActive), drawerFocused: !!(drawer && drawer.activeFocus), pointer: window && window.barPointer ? { hovered: window.barPointer.hovered, x: Math.round(window.barPointer.point.position.x), y: Math.round(window.barPointer.point.position.y) } : null, card: { shown: bar.tooltipShown, text: bar.tooltipText, mine: bar.tooltipTarget === cursor, belongs: !!cursor && bar.targetBelongsToWindow(cursor, window) }, focused: !!(window && window.keyCatcher && window.keyCatcher.activeFocus) }
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
  // Every stop on the bar, in bar order: { item, kind, zone }.
  function stops() {
    var w = keys.window
    if (!w || !w.contentItem) return []
    var out = []
    var vertical = bar.vertical
    function add(item, kind, zone) {
      var c = item.mapToItem(w.contentItem, item.width / 2, item.height / 2)
      out.push({ item: item, kind: kind, zone: zone, at: vertical ? c.y : c.x })
    }
    ;(w.moduleItems || []).forEach(function(slot) {
      if (seen(slot)) add(slot, slot.groupHeader ? "group" : "widget", slot.region)
    })
    ;(w.foldHandles || []).forEach(function(h) { if (seen(h)) add(h, "dots", h.zone) })
    if (w.prefsButton && seen(w.prefsButton)) add(w.prefsButton, "prefs", "right")
    out.sort(function(a, b) { return a.at - b.at })
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

  // ---- entering and leaving ---------------------------------------------
  function toggle() { if (active) leave(); else enter() }
  function enter() {
    if (bar.preferencesOpen) return
    var w = bar.focusedBarWindow()
    if (!w) return
    window = w
    active = true
    searching = false; query = ""; sheet = false; drawer = null; previewing = false; pending = null
    bar.refreshShortcuts()
    // Start on the widget whose panel is open, else the clock, else the middle.
    var list = stops()
    var open = list.find(function(s) { return s.item.panelOpen })
    var anchor = list.find(function(s) { return s.item.centerAnchorSlot })
    var start = open || anchor || list[Math.floor(list.length / 2)]
    cursor = start ? start.item : null
    showCard()
    focusLater()
  }
  function leave() {
    if (!active) return
    previewTimer.stop()
    closeDrawer(false)
    if (window && window.inlineZone) window.inlineAsk("")
    bar.hideCard()
    active = false
    searching = false; query = ""; sheet = false; pending = null
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
  onSuspendedChanged: if (!suspended && active) { showCard(); focusLater() }

  // The keys must always land somewhere: if neither the bar nor a drawer it
  // opened has them (a drawer closed under them), the bar takes them back.
  readonly property bool hasFocus: !!window && (!!window.keyCatcher && window.keyCatcher.activeFocus || !!drawer && drawer.activeFocus)
  onHasFocusChanged: if (!hasFocus && here) refocus.restart()
  Timer { id: refocus; interval: 60; onTriggered: if (keys.here && !keys.hasFocus) keys.focusLater() }

  // ---- moving -------------------------------------------------------------
  function put(item, dir) {
    closeDrawer(false)
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
    var to = KeysModel.step(list.length, i, dir)
    if (to >= 0) put(list[to].item, dir)
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

  // Dots open the way the pointer opens them, and the cursor lands on the
  // first widget that appeared in the direction it was going (or on `key`).
  function openDots(token, dir, key) {
    var w = window
    pending = { token: token, dir: dir, key: key || "", tries: 0 }
    w.inlineEnter(token, true)
    Qt.callLater(checkPending)
  }
  function checkPending() {
    var p = pending, w = window
    if (!p || !w) return
    if (w.inlineZone === p.token) {
      var shown = stops().filter(function(s) { return s.item.inlineShown && s.item.inlineToken === p.token })
      // The widgets take a frame or two to lay out after the zone opens.
      if (!shown.length) { if (++p.tries < 20) landRetry.restart(); else pending = null; return }
      pending = null
      var pick = p.key ? shown.find(function(s) { return s.item.instanceKey === p.key }) : null
      if (!pick) pick = p.dir < 0 ? shown[shown.length - 1] : shown[0]
      cursor = pick.item
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
        if (p.open && d.slots[d.cursor]) d.slots[d.cursor].activate()
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
  // A group's drawer unfolds beside its icon once the key is let go, so a
  // held key sweeping past never flashes it.
  function released() {
    if (!here || drawer || !opensDrawer(cursor)) return
    previewTimer.restart()
  }
  Timer {
    id: previewTimer
    interval: 100
    onTriggered: if (keys.here && !keys.drawer && keys.opensDrawer(keys.cursor)) keys.openDrawer(false)
  }
  function openDrawer(enterIt) {
    var w = window, d = w ? w.managedDrawer : null, item = cursor
    if (!d || !item) return
    if (item.isFoldHandle) d.openZone(item.zone, enterIt)
    else d.openGroup(item.entry.powerbarGroupId, item, enterIt)
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
  function openCursor() {
    var item = cursor
    if (!item) return
    if (opensDrawer(item)) { openDrawer(true); return }
    // Preferences takes the keyboard: the cursor leaves first.
    if (item.isPrefsButton) { leave(); item.activate(); return }
    if (item.isFoldHandle) { openDots(item.inlineToken, 1, ""); return }
    bar.hideCard()
    item.activate()
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
  // A key on the bar. Returns whether it was used.
  function barKey(event) {
    var name = keyName(event)
    if (!name || !here) return false
    previewTimer.stop()
    if (searching && searchKey(name)) return true
    if (sheet) {
      sheet = false
      if (name === "Escape" || name === "?") return true
    }
    var it = KeysModel.barIntent(position, name)
    if (!it) return true
    if (it.move) moveBy(it.move)
    else if (it.zone) zoneJump(it.zone)
    else if (it.home) toEnd(false)
    else if (it.end) toEnd(true)
    else if (it.into) {
      if (opensDrawer(cursor)) openDrawer(true)
      // Drawer mode: a zone's on-demand widgets wait in its drawer, entered
      // from any widget of the zone.
      else if (!bar.onDemandInline && zone && bar.managedSlots(zone, window).length) openZoneDrawer(zone, "")
    }
    else if (it.open) openCursor()
    else if (it.find) startSearch()
    else if (it.sheet) sheet = true
    else if (it.leave) leave()
    return true
  }
  // A key in a drawer opened from the cursor.
  function drawerKey(event) {
    var name = keyName(event), d = drawer
    if (!name || !here || !d) return false
    if (searching && searchKey(name)) return true
    if (sheet) { sheet = false; if (name === "Escape" || name === "?") return true }
    var it = KeysModel.drawerIntent(position, name, d.cursorActive ? d.cursor : 0)
    if (!it) return true
    if (it.member) {
      var to = (d.cursorActive ? d.cursor : -1) + it.member
      if (to >= 0 && to < d.slots.length) { d.cursor = to; d.cursorActive = true; d.navigate(0) }
    } else if (it.back) closeDrawer(true)
    else if (it.backMove) { closeDrawer(true); moveBy(it.backMove) }
    else if (it.zone) { closeDrawer(true); zoneJump(it.zone) }
    else if (it.open) { var slot = d.slots[d.cursor]; if (slot) slot.activate() }
    else if (it.find) { closeDrawer(true); startSearch() }
    else if (it.sheet) sheet = true
    return true
  }

  // ---- finding --------------------------------------------------------------
  // Everything a search can reach: widgets and groups on the bar, the members
  // of groups, and the widgets waiting behind dots. Hidden widgets are not on
  // the bar, so there is nothing to put a cursor on.
  function catalogue() {
    var out = [], w = window
    if (!w) return out
    stops().forEach(function(s) {
      if (s.kind === "widget" || s.kind === "prefs") out.push({ name: nameOf(s.item), slot: s.item, stop: s.item })
      else if (s.kind === "group") {
        out.push({ name: bar.slotName(s.item), slot: s.item, stop: s.item })
        // A member is found by its group's name too ("ai a").
        var groupName = bar.slotName(s.item)
        bar.groupSlots(s.item.entry.powerbarGroupId, w).forEach(function(m) {
          out.push({ name: bar.slotName(m), text: groupName + " " + bar.slotName(m), slot: m, stop: s.item, member: true })
        })
      }
    })
    // Drawer mode: each zone's on-demand widgets, in its drawer.
    if (!bar.onDemandInline) KeysModel.ZONES.forEach(function(z) {
      bar.managedSlots(z, w).forEach(function(m) {
        if (!out.some(function(c) { return c.slot === m })) out.push({ name: bar.slotName(m), slot: m, zone: z, behind: true })
      })
    })
    // Inline mode: every widget waiting behind a zone's dots, whether the
    // zone is folded, opening or open right now.
    if (bar.onDemandInline) (w.moduleItems || []).forEach(function(m) {
      if (!m || m.drawerHost || !(m.inlineCandidate || m.inlineShown)) return
      if (out.some(function(c) { return c.slot === m })) return
      out.push({ name: bar.slotName(m), slot: m, token: m.inlineToken, behind: true })
    })
    return out
  }
  function startSearch() { searching = true; query = ""; matchIndex = 0; matchCount = 0; sheet = false }
  function searchKey(name) {
    if (name === "Escape") { searching = false; query = ""; return true }
    if (name === "Enter") { searching = false; query = ""; openMatch(); return true }
    if (name === "Tab") { reveal(matchIndex + 1); return true }
    if (name === "Backtab") { reveal(matchIndex - 1); return true }
    // An arrow, Home or End ends the search where it is and does its usual
    // job (↓ on a top bar goes into the group found).
    if (["Up", "Down", "Left", "Right", "Home", "End"].indexOf(name) >= 0) {
      searching = false
      query = ""
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
    var d = drawer
    if (d && !previewing && d.cursorActive && d.slots[d.cursor]) { bar.hideCard(); d.slots[d.cursor].activate(); return }
    if (pending) { pending.open = true; return }
    openCursor()
  }
  // Put the cursor on a match, opening the way to it.
  function reveal(which) {
    var list = catalogue(), found = KeysModel.matches(list.map(function(c) { return c.text || c.name }), query)
    matchCount = found.length
    if (!found.length) { matchIndex = 0; return }
    matchIndex = ((which % found.length) + found.length) % found.length
    var pick = list[found[matchIndex]]
    if (pick.member) {
      if (cursor !== pick.stop || !drawer || previewing) { put(pick.stop, 1); openDrawer(true) }
      var d = drawer
      if (d) { var at = d.slots.indexOf(pick.slot); if (at >= 0) { d.cursor = at; d.cursorActive = true; d.navigate(0) } }
      return
    }
    if (pick.behind) {
      closeDrawer(false)
      if (bar.onDemandInline) {
        if (seen(pick.slot)) { put(pick.slot, 1); return }
        var w = window
        if (w.inlineZone && w.inlineZone !== pick.token) w.inlineAsk("")
        var handle = (w.foldHandles || []).find(function(h) { return h && h.inlineToken === pick.token && h.shown })
        if (handle) cursor = handle
        openDots(pick.token, 1, pick.slot.instanceKey)
      } else {
        var near = stops().find(function(st) { return st.zone === pick.zone })
        if (near) cursor = near.item
        openZoneDrawer(pick.zone, pick.slot.instanceKey)
      }
      return
    }
    put(pick.stop, 1)
    if (opensDrawer(pick.stop)) openDrawer(false)
  }

  // ---- the shortcut sheet ---------------------------------------------------
  function targetOf(slot) {
    return !slot || slot.isFoldHandle || slot.isPrefsButton ? "" : slot.groupHeader ? "group:" + slot.entry.powerbarGroupId : "widget:" + slot.moduleName
  }
  // Every widget and group on this bar with a shortcut: [{ name, keys }].
  function sheetEntries() {
    var out = [], seenNames = {}
    catalogue().forEach(function(c) {
      var keysLabel = bar.shortcutLabel(targetOf(c.slot)), name = c.name
      if (!keysLabel || seenNames[name + keysLabel]) return
      seenNames[name + keysLabel] = true
      out.push({ name: name, keys: keysLabel })
    })
    return out
  }

  // ---- the name card --------------------------------------------------------
  function showCard() {
    // A drawer open beside the icon names its own widgets; the card would cover it.
    // A group (or a zone's dots in drawer mode) unfolds its drawer instead.
    if (!here || !cursor || drawer || opensDrawer(cursor)) { bar.hideCard(); return }
    var name = nameOf(cursor)
    var target = targetOf(cursor)
    var keysLabel = target ? bar.shortcutLabel(target) : ""
    bar.showCard(cursor, keysLabel ? name + "   " + keysLabel : name)
  }

  // The shortcuts are read again on entering: the card names them once they arrive.
  Connections {
    target: keys.bar.shortcutStore
    ignoreUnknownSignals: true
    function onReadyChanged() { if (keys.here) keys.showCard() }
    function onBindsChanged() { if (keys.here) keys.showCard() }
  }

  // The pointer takes over: moving it onto a stop moves the cursor there.
  property var lastPointer: null
  // Where the pointer was when the mode began: resting there is not a move.
  onActiveChanged: {
    var p = active && window ? window.barPointer : null
    lastPointer = p && p.hovered ? { x: p.point.position.x, y: p.point.position.y } : null
  }
  Connections {
    target: keys.window ? keys.window.barPointer : null
    ignoreUnknownSignals: true
    function onPointChanged() {
      var p = keys.window ? keys.window.barPointer : null
      if (!keys.here || keys.drawer && !keys.previewing || !p || !p.hovered) return
      var pos = p.point.position
      // Only a pointer that moved takes over: the handler also reports
      // the same point again when the bar changes under it.
      if (keys.lastPointer && Math.abs(keys.lastPointer.x - pos.x) < 1 && Math.abs(keys.lastPointer.y - pos.y) < 1) return
      keys.lastPointer = { x: pos.x, y: pos.y }
      var list = keys.stops()
      for (var i = 0; i < list.length; i++) {
        var item = list[i].item, local = item.mapFromItem(p.parent, pos.x, pos.y)
        if (local.x >= 0 && local.y >= 0 && local.x < item.width && local.y < item.height) {
          if (item !== keys.cursor) { keys.closeDrawer(false); keys.cursor = item; keys.showCard() }
          return
        }
      }
    }
  }
}
