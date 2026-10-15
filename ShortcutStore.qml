import QtQuick
import Quickshell
import Quickshell.Io
import "ShortcutModel.js" as Shortcuts

// Shortcuts for widgets and groups (ShortcutModel.js): what Hyprland has
// bound, what Omarchy's and the user's binding files say, and Powerbar's own
// changes (bar.powerbarShortcuts), written as a marked block of Omarchy o.bind
// calls in ~/.config/hypr/bindings.lua, the way Omarchy plugins add binds.
// Preferences reads it when it opens and after every change.
Item {
  id: store
  required property var bar
  required property var preferences
  visible: false

  readonly property var config: bar && bar.barConfig && bar.barConfig.powerbarShortcuts
    && typeof bar.barConfig.powerbarShortcuts === "object" ? bar.barConfig.powerbarShortcuts : ({})
  property var binds: []
  // The keys Powerbar's own block binds now: not a clash with itself.
  property var ownKeys: []
  property var defaults: ({ widgets: [], positions: [] })
  property bool ready: false
  // A change being written and Hyprland reloading.
  property bool busy: false
  property string error: ""
  // A failure shows in Preferences' footer, where save errors go.
  onErrorChanged: if (error) preferences.status = error
  // The target whose row is recording; Hyprland sits in the empty submap.
  property string recording: ""

  // What each target is called in Hyprland's list and in messages.
  function nameOf(target) {
    if (target === "bar:keys") return "Powerbar keyboard"
    if (target === "bar:search") return "Powerbar search"
    if (target.indexOf("group:") === 0) {
      var g = (bar.groups || []).find(function(x) { return "group:" + x.id === target })
      return (g ? g.label : target.slice(6)) + " group"
    }
    return preferences.title({ id: target.slice(7) })
  }
  function names(config) {
    var out = {}
    Object.keys(config || {}).forEach(function(t) { out[t] = store.nameOf(t) })
    return out
  }

  // { keys, source, fallback, positional }: the shortcut a row shows.
  function info(target) {
    var e = Shortcuts.effective(target, config, defaults, binds)
    e.positional = ""
    if (target.indexOf("widget:") === 0 && bar.panelNavigationSlots) {
      var slots = bar.panelNavigationSlots("right", null)
      for (var i = 0; i < slots.length; i++) if (slots[i].moduleName === target.slice(7)) {
        e.positional = Shortcuts.positional(defaults, "right", i + 1, binds)
        break
      }
    }
    return e
  }
  function conflicts(keys, target) {
    var named = {}
    Object.keys(config).forEach(function(t) { named[t] = store.nameOf(t) })
    return Shortcuts.conflicts(keys, target, config, binds, named, ownKeys)
  }

  function suggested(target) { return Shortcuts.suggested(target) }

  // A first start (keyboard.md KEYS-84): Powerbar's first write on a config
  // it never ran on leaves bar.powerbarShortcutOffer. Once Hyprland's binds
  // are read, a notification that stays until dismissed names the bar's
  // suggested shortcuts, free or held by what; a click on it opens
  // Preferences at them. Nothing is bound until the user takes them there.
  readonly property bool offerPending: !!bar && !!bar.barConfig && bar.barConfig.powerbarShortcutOffer === true
  // Finished reads of Hyprland's binds; the offer waits for one it asked for,
  // so it judges the binds as they are now, not as they were at start.
  property int reads: 0
  property int offerAfter: -1
  // Later, not inside the change: the offer writes the config offerPending reads.
  onOfferPendingChanged: offerLater.restart()
  onReadsChanged: offerLater.restart()
  // Owned Timers, not Qt.callLater closures: they stop with the store, so
  // nothing writes bindings.lua for a bar that is going away.
  Timer { id: offerLater; interval: 0; onTriggered: store.offerSuggested() }
  Timer {
    id: pruneLater
    interval: 0
    onTriggered: {
      if (!store.staleGroups.length || store.busy) return
      var next = store.config
      store.staleGroups.forEach(function(t) { next = Shortcuts.restore(next, t) })
      store.write(next)
    }
  }
  property bool retired: false
  function offerSuggested() {
    if (!offerPending || busy) return
    if (offerAfter < 0) { offerAfter = reads + 1; refresh(); return }
    if (reads < offerAfter || !bar.canWriteConfig()) return
    offerAfter = -1
    var text = Shortcuts.offerMessage(Shortcuts.offer(config, binds, names(config), ownKeys))
    preferences.setOption("powerbarShortcutOffer", undefined)
    if (text) notifyOffer(text)
  }
  // Critical, so it stays until dismissed. A click runs Omarchy's
  // omarchy-exec-argv (newer Omarchy, kept across shell restarts), or answers
  // "default" to the --wait here (other daemons, Omarchy 4.0.4).
  function notifyOffer(text) {
    // Plain words only: notification daemons read markup in the body, and
    // the text names other binds by their descriptions.
    text = String(text || "").replace(/[<>&\x00-\x1f\x7f]/g, " ").slice(0, 300)
    offerNotice.command = ["notify-send", "-a", "Powerbar", "-u", "critical", "--wait",
      "--action=default=Open Preferences",
      "-h", "string:omarchy-exec-argv:" + JSON.stringify(["omarchy-shell", "powerbar", "preferencesKeyboard"]),
      "Powerbar shortcuts", text]
    offerNotice.running = true
  }
  Process {
    id: offerNotice
    stdout: StdioCollector {
      onStreamFinished: if (text.trim() === "default") store.bar.showPreferencesKeyboard()
    }
  }

  function save(target, keys) { write(Shortcuts.assign(config, target, keys)) }
  function restore(target) { write(Shortcuts.restore(config, target)) }
  // What powerbarShortcuts held before the write in flight: put back when
  // Hyprland refuses the block or the file can't be written, so the saved
  // shortcuts always match the bound ones.
  property var previous: undefined
  function write(next) {
    // The block follows the saved shortcuts: no config write, no block.
    if (retired || !bar.canWriteConfig()) {
      error = "Powerbar can't save its settings right now, so no shortcut changed."
      return
    }
    error = ""
    previous = Object.keys(config).length ? JSON.parse(JSON.stringify(config)) : undefined
    preferences.setOption("powerbarShortcuts", Object.keys(next).length ? next : undefined)
    busy = true
    applyProc.command = ["bash", applyScript, Shortcuts.render(next, defaults, names(next)),
      Shortcuts.BEGIN, Shortcuts.END, Shortcuts.OLD_START, Shortcuts.OLD_END]
    applyProc.running = true
  }

  function refresh() { readProc.running = true }

  function startRecording(target) {
    recording = target
    evalProc.exec(["hyprctl", "eval", Shortcuts.recordLua(true)])
  }
  function stopRecording() {
    if (!recording) return
    recording = ""
    evalProc.exec(["hyprctl", "eval", Shortcuts.recordLua(false)])
  }

  // Groups that are gone take their shortcuts with them.
  readonly property var staleGroups: Object.keys(config).filter(function(t) {
    return t.indexOf("group:") === 0 && !(bar.groups || []).some(function(g) { return "group:" + g.id === t })
  })
  onStaleGroupsChanged: pruneStaleGroups()
  // Also once a write in flight is done: a group dissolved meanwhile.
  onBusyChanged: if (!busy) { pruneStaleGroups(); offerLater.restart() }
  // Not again after a write that failed (error set): a refusal would put the
  // stale shortcut back and this would try forever; the next change retries.
  function pruneStaleGroups() {
    if (!staleGroups.length || busy || error) return
    pruneLater.restart()
  }

  // Hyprland's binds (plain text: its JSON drops code: keys), then every
  // binding file in load order: Omarchy's defaults, then the user's.
  Process {
    id: readProc
    command: ["bash", "-c", `
      echo "@@BINDS"; timeout 3s hyprctl binds 2>/dev/null | head -c 1048576
      for f in "\${OMARCHY_PATH:-/usr/share/omarchy}"/default/hypr/bindings/*.lua; do
        [ -f "$f" ] && { echo "@@FILE omarchy $f"; head -c 1048576 -- "$f"; echo; }
      done
      for f in "\${POWERBAR_HYPR_DIR:-\${XDG_CONFIG_HOME:-$HOME/.config}/hypr}"/*.lua; do
        case "$f" in */powerbar.lua) continue ;; esac
        [ -f "$f" ] && { echo "@@FILE config $f"; head -c 1048576 -- "$f"; echo; }
      done`]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.split(/^@@/m), binds = [], files = [], own = []
        for (var p of parts) {
          var nl = p.indexOf("\n"), head = p.slice(0, nl), body = p.slice(nl + 1)
          if (head === "BINDS") binds = Shortcuts.parseBinds(body)
          else if (head.indexOf("FILE ") === 0) {
            // Powerbar's own block is not the user's: cut it out, keep its keys.
            own = own.concat(Shortcuts.blockKeys(body))
            files.push({ origin: head.split(" ")[1], text: Shortcuts.strip(body) })
          }
        }
        store.binds = binds
        store.ownKeys = own
        store.defaults = Shortcuts.readDefaults(files)
        store.ready = true
        store.reads++
      }
    }
  }

  // ShortcutApply.sh puts the block in bindings.lua between its markers, in
  // one step, only when the markers are whole; Hyprland then reloads and a
  // new config error puts the file back.
  readonly property string applyScript: decodeURIComponent(Qt.resolvedUrl("ShortcutApply.sh").toString().replace(/^file:\/\//, ""))
  Process {
    id: applyProc
    stdout: StdioCollector {
      onStreamFinished: {
        var line = text.trim().split("\n").pop() || ""
        if (line.indexOf("error") === 0) store.error = "Hyprland refused the shortcut, so nothing changed: " + line.slice(6)
        else if (line.indexOf("fail") === 0) store.error = "Could not update Hyprland's shortcuts, so nothing changed: " + line.slice(5)
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        if (!store.error) store.error = "Could not update Hyprland's shortcuts, so nothing changed."
        console.warn("powerbar: shortcuts not written (exit " + code + "): " + store.error)
        store.preferences.setOption("powerbarShortcuts", store.previous)
      }
      store.busy = false
      store.refresh()
    }
  }
  Process {
    id: evalProc
    function exec(argv) { running = false; command = argv; running = true }
  }

  Component.onDestruction: {
    retired = true
    offerLater.stop()
    pruneLater.stop()
    if (recording) Quickshell.execDetached(["hyprctl", "eval", Shortcuts.recordLua(false)])
  }
}
