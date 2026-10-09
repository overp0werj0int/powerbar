import QtQuick
import Quickshell.Io
import "BarModel.js" as BarModel

// Gives widgets back their component when Omarchy's registry copy has lost it.
// The shell hands a full bar a copy of its widget registry. A copy taken while
// the shell reloads its widgets (switching the bar does) lists widgets whose
// component is already destroyed, and nothing refreshes it until the shell
// registers another widget, so they stay placeholders. Each time the bar is
// handed a copy or the copy changes, sync() loads every such widget from its
// own plugin, the file the shell loads it from (BarModel.widgetEntryPath).
QtObject {
  id: repair

  property var registry: null
  onRegistryChanged: sync()
  property Connections registryWatch: Connections {
    target: repair.registry
    ignoreUnknownSignals: true
    function onWidgetsChanged() { repair.sync() }
  }
  // Reads a file's text; tests replace it.
  property var readText: function(path) {
    var file = fileReader.createObject(repair, { path: path })
    if (!file) return ""
    var text = file.text()
    file.destroy()
    return text
  }
  // { id: { sourceDir, url, component } }: widgets loaded here, owned by this
  // object so the components live as long as the bar.
  property var repaired: ({})
  // { id: reason }: widgets left without a component.
  property var failed: ({})

  property Component fileReader: Component {
    FileView {
      blockLoading: true
      printErrors: false
    }
  }

  // The component a slot uses: the one loaded here, else the registry's.
  function componentFor(id, registryComponent) {
    var own = repaired[id]
    return own && own.component && own.component.status === Component.Ready ? own.component : registryComponent
  }

  function sync() {
    var widgets = registry && registry.widgets || {}
    var next = ({}), lost = ({}), loaded = [], dropped = []
    for (var id in repaired) {
      if (BarModel.keepRepaired(repaired[id], widgets[id])) next[id] = repaired[id]
      else dropped.push(repaired[id].component)
    }
    var stale = BarModel.staleWidgetIds(widgets)
    for (var i = 0; i < stale.length; i++) {
      var staleId = stale[i]
      if (next[staleId]) continue
      var meta = widgets[staleId].metadata || {}
      var dir = String(meta.sourceDir || "").replace(/\/+$/, "")
      var found = findEntry(staleId, dir, meta.firstParty === true)
      if (found.error) { lost[staleId] = found.error; continue }
      var url = "file://" + found.path.split("/").map(encodeURIComponent).join("/")
      var component = Qt.createComponent(url, Component.PreferSynchronous, repair)
      if (component.status === Component.Error) {
        lost[staleId] = component.errorString().trim()
        component.destroy()
        continue
      }
      if (component.status === Component.Loading) component.statusChanged.connect(repair.settle)
      next[staleId] = { sourceDir: dir, url: url, component: component }
      loaded.push(staleId)
    }
    if (loaded.length || dropped.length) repaired = next
    if (JSON.stringify(lost) !== JSON.stringify(failed)) failed = lost
    if (loaded.length) console.info("powerbar: the shell's widget registry lost the component of "
      + loaded.join(", ") + "; loaded them from their plugins")
    for (var lostId in lost) console.warn("powerbar: " + lostId + " has no component and could not be loaded (" + lost[lostId] + ")")
    // A slot moves to its new component in the bindings this change runs;
    // the old one goes after them.
    if (dropped.length) Qt.callLater(function() { dropped.forEach(function(c) { if (c) c.destroy() }) })
  }

  // The widget's QML, from the first of its manifests that names it.
  function findEntry(id, dir, firstParty) {
    var names = BarModel.manifestCandidates(id, firstParty), found = null
    for (var i = 0; i < names.length; i++) {
      var next = BarModel.widgetEntryPath(id, dir, dir ? readText(dir + "/" + names[i]) : "")
      if (next.path) return next
      if (!found || found.error === "manifest unreadable") found = next
    }
    return found
  }

  // An asynchronous load finished: Ready reaches the slots, Error is reported.
  function settle() {
    var next = ({}), lost = Object.assign({}, failed), changed = false
    for (var id in repaired) {
      var own = repaired[id]
      if (own.component.status === Component.Error) {
        lost[id] = own.component.errorString().trim()
        console.warn("powerbar: " + id + " has no component and could not be loaded (" + lost[id] + ")")
        own.component.destroy()
        changed = true
      } else next[id] = own
    }
    repaired = changed ? next : Object.assign({}, repaired)
    if (changed) failed = lost
  }

  // For `powerbar status`.
  function report() {
    var widgets = registry && registry.widgets || {}
    return { widgets: Object.keys(widgets).length, stale: BarModel.staleWidgetIds(widgets),
      repaired: Object.keys(repaired).sort(), failed: failed }
  }
}
