import QtQuick
import Quickshell
import Quickshell.Io
import "ShortcutModel.js" as Shortcuts

// Shortcuts for widgets and groups (ShortcutModel.js): what Hyprland has
// bound, what Omarchy's and the user's binding files say, and Powerbar's own
// changes (bar.powerbarShortcuts), written to ~/.config/hypr/powerbar.lua.
// Preferences reads it when it opens and after every change.
Item {
  id: store
  required property var bar
  required property var preferences
  visible: false

  readonly property var config: bar && bar.barConfig && bar.barConfig.powerbarShortcuts
    && typeof bar.barConfig.powerbarShortcuts === "object" ? bar.barConfig.powerbarShortcuts : ({})
  property var binds: []
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
    return Shortcuts.conflicts(keys, target, config, binds, named)
  }

  function save(target, keys) { write(Shortcuts.assign(config, target, keys)) }
  function restore(target) { write(Shortcuts.restore(config, target)) }
  function write(next) {
    error = ""
    preferences.setOption("powerbarShortcuts", Object.keys(next).length ? next : undefined)
    busy = true
    applyProc.command = ["bash", "-c", applyScript, "powerbar", Shortcuts.render(next, defaults, names(next)), Shortcuts.BLOCK]
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
  onStaleGroupsChanged: if (staleGroups.length && !busy) Qt.callLater(function() {
    var next = store.config
    store.staleGroups.forEach(function(t) { next = Shortcuts.restore(next, t) })
    store.write(next)
  })

  // Hyprland's binds (plain text: its JSON drops code: keys), then every
  // binding file in load order: Omarchy's defaults, then the user's.
  Process {
    id: readProc
    command: ["bash", "-c", `
      echo "@@BINDS"; hyprctl binds 2>/dev/null
      for f in "\${OMARCHY_PATH:-/usr/share/omarchy}"/default/hypr/bindings/*.lua; do
        [ -f "$f" ] && { echo "@@FILE omarchy $f"; cat "$f"; echo; }
      done
      for f in "\${POWERBAR_HYPR_DIR:-\${XDG_CONFIG_HOME:-$HOME/.config}/hypr}"/*.lua; do
        case "$f" in */powerbar.lua) continue ;; esac
        [ -f "$f" ] && { echo "@@FILE config $f"; cat "$f"; echo; }
      done`]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = text.split(/^@@/m), binds = [], files = []
        for (var p of parts) {
          var nl = p.indexOf("\n"), head = p.slice(0, nl), body = p.slice(nl + 1)
          if (head === "BINDS") binds = Shortcuts.parseBinds(body)
          else if (head.indexOf("FILE ") === 0) files.push({ origin: head.split(" ")[1], text: body })
        }
        store.binds = binds
        store.defaults = Shortcuts.readDefaults(files)
        store.ready = true
      }
    }
  }

  // Writes powerbar.lua ($1), adds the loading block to hyprland.lua once ($2,
  // after a backup), reloads Hyprland and checks it took the file; a file
  // Hyprland rejects is put back as it was.
  readonly property string applyScript: `
    c=\${POWERBAR_HYPR_DIR:-\${XDG_CONFIG_HOME:-$HOME/.config}/hypr}; f="$c/powerbar.lua"; main="$c/hyprland.lua"
    mkdir -p "$c"
    prev=$(mktemp); had=0
    [ -f "$f" ] && { cp "$f" "$prev"; had=1; }
    printf '%s\\n' "$1" > "$f.tmp" && mv "$f.tmp" "$f"
    if [ -f "$main" ] && ! grep -qF -- '${Shortcuts.BLOCK_START}' "$main"; then
      cp "$main" "$main.bak.$(date +%Y%m%d%H%M%S)-powerbar"
      printf '\\n%s\\n' "$2" >> "$main"
    fi
    before=$(hyprctl configerrors 2>/dev/null)
    hyprctl reload config-only >/dev/null 2>&1
    sleep 0.3
    after=$(hyprctl configerrors 2>/dev/null)
    if [ "$after" != "$before" ] && printf '%s' "$after" | grep -qi powerbar; then
      if [ $had = 1 ]; then cp "$prev" "$f"; else rm -f "$f"; fi
      hyprctl reload config-only >/dev/null 2>&1
      rm -f "$prev"
      echo "error $(printf '%s' "$after" | grep -i powerbar | head -1)"
      exit 1
    fi
    rm -f "$prev"
    echo ok`
  Process {
    id: applyProc
    stdout: StdioCollector {
      onStreamFinished: {
        var line = text.trim().split("\n").pop() || ""
        if (line.indexOf("error") === 0) store.error = "Hyprland refused the shortcut, so nothing changed: " + line.slice(6)
      }
    }
    onExited: function(code) {
      if (code !== 0 && !store.error) store.error = "Could not update Hyprland's shortcuts. Check that ~/.config/hypr is writable."
      store.busy = false
      store.refresh()
    }
  }
  Process {
    id: evalProc
    function exec(argv) { running = false; command = argv; running = true }
  }

  Component.onDestruction: if (recording) Quickshell.execDetached(["hyprctl", "eval", Shortcuts.recordLua(false)])
}
