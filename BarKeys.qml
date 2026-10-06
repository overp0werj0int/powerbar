import QtQuick
import Quickshell.Hyprland
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
    if (p.seek) {
      if (seen(p.seek)) { pending = null; landOn(p.seek, p.member); if (p.open) openMatch(); return }
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
      var shown = stops().filter(function(s) { return s.item.inlineShown && s.item.inlineToken === p.token })
      var pick = p.key ? shown.find(function(s) { return s.item.instanceKey === p.key }) : null
      // The widgets take a few frames to lay out after the zone opens, not
      // all at once: wait for the one asked for (a search's), else any.
      if (!pick && (p.key || !shown.length) && ++p.tries < 20) { landRetry.restart(); return }
      pending = null
      if (!shown.length) return
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
    // Preferences takes the keyboard: the cursor leaves first.
    if (item.isPrefsButton) { leave(); item.activate(); return }
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
    if (active && doubleEscape(name)) return true
    if (name && active && suspended) return panelKey(name)
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
    if (d && active && doubleEscape(name)) return true
    if (name && d && active && suspended) return panelKey(name)
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
    else if (it.open) activate(d.slots[d.cursor])
    else if (it.find) { closeDrawer(true); startSearch() }
    else if (it.sheet) sheet = true
    return true
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
      w.inlineEnter(token, true)
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
    if (opensDrawer(item)) openDrawer(false)
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
  // What the name card is on: the cursor, or the drawer's current member.
  property var cardTarget: null
  function showCard() {
    var d = drawer, target = null, slot = null
    // In a drawer the card names its current member, where hovering it would.
    // While it only previews beside the icon, the card would cover it.
    if (here && d) {
      if (!previewing && d.opened && d.cursorActive && !d.steppedAside) { slot = d.slots[d.cursor]; target = slot ? d.cellAt(d.cursor) : null }
    } else if (here && cursor && !opensDrawer(cursor)) { slot = cursor; target = cursor }
    if (!target) { cardTarget = null; bar.hideCard(); return }
    var name = nameOf(slot)
    var shortcut = targetOf(slot)
    var keysLabel = shortcut ? bar.shortcutLabel(shortcut) : ""
    cardTarget = target
    bar.showCard(target, keysLabel ? name + "   " + keysLabel : name)
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
