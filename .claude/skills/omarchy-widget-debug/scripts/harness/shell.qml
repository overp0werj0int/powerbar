import Quickshell
import QtQuick
import qs.Commons
import qs.Ui

// Offscreen host for one Omarchy bar widget (omarchy-widget-debug).
// Loads the widget the way the Omarchy bar does (a PluginBarApi as `bar`,
// `moduleName`, `settings`), records every frame in which watched geometry
// changes (FRAME lines), and runs an optional driver's steps.
//
// Env: FD_WIDGET  absolute path of the widget's QML file (required)
//      FD_MODULE  module name (default: the plugin folder name)
//      FD_SETTINGS JSON object handed to the widget as `settings`
//      FD_BAR     bar size in px (default 30); FD_VERTICAL=1 for a vertical bar
//      FD_WATCH   comma-separated objectNames to record (default: the widget
//                 and its direct children)
//      FD_DEPTH   with no FD_WATCH, how deep below the widget to record (default 1)
//      FD_SECONDS how long to run when there is no driver (default 3)
ShellRoot {
  id: harness
  readonly property int barSize: Number(Quickshell.env("FD_BAR") || 30)
  readonly property bool vertical: Quickshell.env("FD_VERTICAL") === "1"
  readonly property string widgetPath: Quickshell.env("FD_WIDGET") || ""
  property Item widget: null
  property real t0: Date.now()
  property bool recording: true
  property string last: ""

  function log() { console.info("FD " + Array.prototype.slice.call(arguments).join(" ")) }
  function ms() { return Date.now() - t0 }

  // ---- what is recorded -------------------------------------------------
  function watched() {
    var names = (Quickshell.env("FD_WATCH") || "").split(",").filter(function(n) { return n })
    var maxDepth = Number(Quickshell.env("FD_DEPTH") || 1)
    var out = []
    function walk(item, depth, path) {
      if (!item) return
      var name = item.objectName || ""
      if (names.length ? names.indexOf(name) >= 0 : depth <= maxDepth) out.push({ item: item, key: name || path })
      if (depth >= 8) return
      var kids = item.children || []
      for (var i = 0; i < kids.length; i++) walk(kids[i], depth + 1, path + "/" + i)
    }
    walk(widget, 0, "w")
    return out
  }
  function r(v) { return Math.round(v * 10) / 10 }
  function state() {
    if (!widget) return ""
    return watched().map(function(w) {
      var it = w.item, p = it.mapToItem(null, 0, 0)
      return w.key + "=" + r(p.x) + "," + r(p.y) + "," + r(it.width) + "x" + r(it.height)
        + (it.opacity < 1 ? ",o" + r(it.opacity) : "") + (it.visible ? "" : ",hidden")
    }).join(" ")
  }
  FrameAnimation {
    running: harness.recording && !!harness.widget
    onTriggered: {
      var s = harness.state()
      if (s !== harness.last) { harness.log("FRAME", harness.ms(), s); harness.last = s }
    }
  }

  // ---- what takes a press -------------------------------------------------
  // The item a press goes to is the topmost visible, enabled item under the
  // point that accepts it (a MouseArea, or an item with a Tap or Drag
  // handler), not just the topmost item: a Text over a MouseArea lets the
  // press through, a child MouseArea under a parent's DragHandler takes it.
  function label(item) { return item.objectName || String(item).split("(")[0].replace(/_QMLTYPE_\d+/, "") }
  function takesPress(item) {
    if (String(item).indexOf("MouseArea") >= 0) return item.enabled !== false
    var data = item.data || []
    for (var i = 0; i < data.length; i++) {
      var d = String(data[i])
      if ((d.indexOf("TapHandler") >= 0 || d.indexOf("DragHandler") >= 0) && data[i].enabled !== false) return true
    }
    return false
  }
  function pressTaker(item, x, y, path) {
    if (!item || item.visible === false || item.enabled === false) return null
    var p = item.mapFromItem(null, x, y)
    var inside = p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height
    var kids = Array.prototype.slice.call(item.children || [])
    kids = kids.map(function(k, i) { return { k: k, i: i } }).sort(function(a, b) { return (b.k.z - a.k.z) || (b.i - a.i) })
    for (var c of kids) {
      var hit = pressTaker(c.k, x, y, path.concat([label(item)]))
      if (hit) return hit
    }
    return inside && takesPress(item) ? path.concat([label(item)]).join(" > ") : null
  }
  // The topmost item under a point, accepting or not.
  function hitChain(x, y) {
    var chain = [], item = window.contentItem
    while (item) {
      var p = item.mapFromItem(null, x, y)
      var next = item.childAt(p.x, p.y)
      if (!next) break
      chain.push(label(next) + (next.enabled === false ? "(disabled)" : ""))
      item = next
    }
    return chain.join(" > ")
  }
  // One HIT line per step across the widget along the bar.
  function census(tag, step) {
    if (!widget) return
    var o = widget.mapToItem(null, 0, 0), len = vertical ? widget.height : widget.width
    for (var a = 1; a < len; a += step || 4) {
      var x = vertical ? o.x + widget.width / 2 : o.x + a, y = vertical ? o.y + a : o.y + widget.height / 2
      log("HIT", tag, Math.round(vertical ? y : x), "press:", pressTaker(window.contentItem, x, y, []) || "nothing", "| top:", hitChain(x, y))
    }
  }

  // ---- the bar the widget sees ------------------------------------------
  PluginBarApi {
    id: api
    pluginId: Quickshell.env("FD_MODULE") || "debug.widget"
    moduleName: Quickshell.env("FD_MODULE") || "debug.widget"
    foreground: Color.foreground
    barForeground: Color.foreground
    background: Color.background
    urgent: Color.urgent
    fontFamily: Style.font.family
    position: harness.vertical ? "right" : "top"
    vertical: harness.vertical
    barSize: harness.barSize
    _showTooltip: function(target, text) { harness.log("CALL tooltip", text) }
    _hideTooltip: function(target) {}
    _registerClickTarget: function(target) { harness.log("CALL registerClickTarget") }
    _unregisterClickTarget: function(target) {}
    _requestPopout: function(owner) { harness.log("CALL requestPopout") }
    _releasePopout: function(owner) { harness.log("CALL releasePopout") }
    _switchPanelFrom: function(owner, direction) { return false }
    _targetBelongsToWindow: function(target, w) { return true }
    _moduleWidgets: function(id) { return harness.widget ? [harness.widget] : [] }
    _run: function(command) { harness.log("CALL run", command) }
    _setCenterHoverRevealSuppressed: function(value) {}
  }

  FloatingWindow {
    id: window
    implicitWidth: harness.vertical ? harness.barSize : 800
    implicitHeight: harness.vertical ? 600 : harness.barSize
    color: Color.background
    Loader {
      id: loader
      x: 8; y: 0
      source: harness.widgetPath ? "file://" + harness.widgetPath : ""
      onLoaded: {
        var w = item
        if ("bar" in w) w.bar = api
        if ("moduleName" in w) w.moduleName = api.moduleName
        if ("settings" in w) w.settings = JSON.parse(Quickshell.env("FD_SETTINGS") || "{}")
        harness.widget = w
        harness.log("LOADED", harness.widgetPath, w.width + "x" + w.height)
        driverTimer.start()
      }
      onStatusChanged: if (status === Loader.Error) { harness.log("LOAD ERROR"); Qt.quit() }
    }
  }

  // ---- the driver: Driver.qml in this folder, if any ----------------------
  // A QtObject with `function steps(h)` returning [{ wait: ms, run: function() }].
  property var steps: []
  Timer {
    id: driverTimer
    interval: 300
    onTriggered: {
      var c = Qt.createComponent(Qt.resolvedUrl("Driver.qml"))
      var d = c.status === Component.Ready ? c.createObject(harness) : null
      harness.steps = d && typeof d.steps === "function" ? d.steps(harness) : []
      harness.log("DRIVER", harness.steps.length ? harness.steps.length + " steps" : "none")
      if (!harness.steps.length) { endTimer.interval = Number(Quickshell.env("FD_SECONDS") || 3) * 1000; endTimer.start(); return }
      stepTimer.next()
    }
  }
  Timer {
    id: stepTimer
    property int at: 0
    function next() {
      if (at >= harness.steps.length) { endTimer.interval = 300; endTimer.start(); return }
      interval = Math.max(1, harness.steps[at].wait || 1)
      start()
    }
    onTriggered: {
      var step = harness.steps[at++]
      harness.log("STEP", at, step.label || "")
      try { if (step.run) step.run() } catch (e) { harness.log("STEP ERROR", at, e) }
      next()
    }
  }
  Timer { id: endTimer; onTriggered: { harness.log("END", harness.ms()); Qt.quit() } }
}
