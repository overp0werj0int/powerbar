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

  function save(target, keys) { write(Shortcuts.assign(config, target, keys)) }
  function restore(target) { write(Shortcuts.restore(config, target)) }
  function write(next) {
    error = ""
    preferences.setOption("powerbarShortcuts", Object.keys(next).length ? next : undefined)
    busy = true
    applyProc.command = ["bash", "-c", applyScript, "powerbar", Shortcuts.render(next, defaults, names(next)),
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
      }
    }
  }

  // Puts the block ($1; "" removes it) into bindings.lua between its markers
  // ($2, $3), or at the end the first time, leaving the rest of the file as it
  // is on disk now. Removes the loader of the old powerbar.lua ($4..$5 in
  // hyprland.lua, after a backup) and that file. Then Hyprland reloads; a file
  // it reports a new error in is put back as it was.
  readonly property string applyScript: `
    c=\${POWERBAR_HYPR_DIR:-\${XDG_CONFIG_HOME:-$HOME/.config}/hypr}; f="$c/bindings.lua"; main="$c/hyprland.lua"
    mkdir -p "$c"; [ -e "$f" ] || : > "$f"
    prev=$(mktemp); cp "$f" "$prev"
    blockf=$(mktemp); printf '%s\n' "$1" > "$blockf"
    next=$(mktemp)
    awk -v b="$2" -v e="$3" -v bf="$blockf" -v has="\${1:+1}" '
      $0 == b { skip = 1; if (has && !done) { while ((getline l < bf) > 0) print l; done = 1 }; next }
      skip { if ($0 == e) skip = 0; next }
      { print }' "$f" > "$next"
    if [ -n "$1" ] && ! grep -qxF -- "$2" "$f"; then
      [ -s "$next" ] && printf '\n' >> "$next"
      cat "$blockf" >> "$next"
    fi
    cat "$next" > "$f"
    rm -f "$blockf" "$next"
    if [ -f "$main" ] && grep -qxF -- "$4" "$main"; then
      cp "$main" "$main.bak.$(date +%Y%m%d%H%M%S)-powerbar"
      old=$(mktemp)
      awk -v b="$4" -v e="$5" '$0 == b { skip = 1; next } skip { if ($0 == e) skip = 0; next } { print }' "$main" > "$old" && cat "$old" > "$main"
      rm -f "$old"
    fi
    rm -f "$c/powerbar.lua"
    before=$(hyprctl configerrors 2>/dev/null)
    hyprctl reload config-only >/dev/null 2>&1
    sleep 0.3
    after=$(hyprctl configerrors 2>/dev/null)
    if [ "$after" != "$before" ] && [ -n "$(printf '%s' "$after" | tr -d '[:space:]')" ]; then
      cat "$prev" > "$f"
      hyprctl reload config-only >/dev/null 2>&1
      rm -f "$prev"
      echo "error $(printf '%s' "$after" | head -1)"
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
