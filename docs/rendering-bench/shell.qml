import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui
import "Powerbar" as PB

// Benchmark host for Powerbar (docs/rendering-bench): plays the Omarchy shell's
// part (config, mutateShellConfig, the widget registry) with stand-in widgets
// for the user's layout, runs one scenario (BENCH_SCENARIO) and logs BENCH
// lines: timings (*_ms), the process's CPU time at each phase (CPU), and the
// resulting geometry and layout (GEO) for exact comparison between versions.
ShellRoot {
  id: shellRoot
  readonly property string scenario: Quickshell.env("BENCH_SCENARIO") || "startup"
  readonly property bool animations: Quickshell.env("BENCH_ANIM") === "1"
  property var shellConfig: ({})
  property var bar: null
  function log() { console.info("BENCH " + Array.prototype.slice.call(arguments).join(" ")) }
  function mutateShellConfig(mutator) {
    var copy = JSON.parse(JSON.stringify(shellConfig))
    mutator(copy)
    shellConfig = copy
    if (bar) bar.barConfig = JSON.parse(JSON.stringify(copy.bar))
  }

  FileView { id: barFile; path: Quickshell.shellDir + "/bar.json"; blockLoading: true }

  // --- Stand-in widgets -------------------------------------------------
  Component { id: glyphWidget; WidgetButton { property string moduleName; property var settings; text: "󰂯" } }
  Component { id: textWidget; WidgetButton { property string moduleName; property var settings; text: "100% 󰁹" } }
  Component { id: clockWidget; WidgetButton {
    property string moduleName; property var settings
    property int tick: 0
    text: (tick % 2 ? "Friday 23:45" : "Friday 23:46")
    Timer { interval: 1000; repeat: true; running: shellRoot.scenario === "idle"; onTriggered: parent.tick++ }
  } }
  Component { id: valueWidget; WidgetButton {
    property string moduleName; property var settings
    property int tick: 0
    text: ["󰤨", "󰤥", "󰤢"][tick % 3]
    Timer { interval: 2000; repeat: true; running: shellRoot.scenario === "idle"; onTriggered: parent.tick++ }
  } }
  Component { id: workspacesWidget; Row {
    id: ws
    property var bar; property string moduleName; property var settings
    Repeater { model: 5; WidgetButton { required property int index; bar: ws.bar; text: String(index + 1); active: index === 1 } }
  } }
  Component { id: indicatorsWidget; Row {
    id: ind
    property var bar; property string moduleName; property var settings
    Repeater { model: 3; WidgetButton { required property int index; bar: ind.bar; text: ["󰍬", "󰂚", "󰖩"][index] } }
  } }
  QtObject {
    id: registry
    property var widgets: ({})
    property int revision: 0
    function metadataFor(id) { var w = widgets[String(id)]; return w ? w.metadata : null }
  }
  function kindFor(id) {
    if (id === "omarchy.clock") return clockWidget
    if (id === "omarchy.workspaces") return workspacesWidget
    if (id === "omarchy.indicators") return indicatorsWidget
    if (id === "omarchy.network") return valueWidget
    if (id === "omarchy.power" || id === "omarchy.keyboard-layout") return textWidget
    return glyphWidget
  }

  property var shellCpuStart: 0
  Process {
    id: cpuProbe
    property string label: ""
    property var after: null
    command: ["sh", "-c", "cat /proc/$PPID/stat"]
    stdout: StdioCollector {
      onStreamFinished: {
        var f = text.split(") ")[1].split(" ")
        var ticks = Number(f[11]) + Number(f[12])
        shellRoot.log("CPU", cpuProbe.label, ticks * 10)
        var next = cpuProbe.after; cpuProbe.after = null
        if (next) next()
      }
    }
  }
  function cpu(label, after) { cpuProbe.label = label; cpuProbe.after = after || null; cpuProbe.running = true }

  Component { id: barComponent; PB.Bar { } }

  Component.onCompleted: {
    var config = JSON.parse(barFile.text())
    config.powerbarAnimations = animations
    config.powerbarAutoHide = Quickshell.env("BENCH_AUTOHIDE") === "1"
    shellConfig = { bar: config }
    var ids = {}
    for (var zone of ["left", "center", "right"]) for (var e of config.layout[zone]) ids[typeof e === "string" ? e : e.id] = true
    var w = {}
    for (var id in ids) w[id] = { component: kindFor(id), metadata: { firstParty: id.indexOf("omarchy.") === 0, displayName: id } }
    registry.widgets = w
    registry.revision++
    cpu("before-create", function() {
      var t0 = Date.now()
      var b = barComponent.createObject(shellRoot)
      b.shell = shellRoot
      b.barWidgetRegistry = registry
      b.barConfig = JSON.parse(JSON.stringify(config))
      bar = b
      var t1 = Date.now()
      log("create_ms", t1 - t0)
      Qt.callLater(function() { log("first_callLater_ms", Date.now() - t0) })
      settle.start()
    })
  }
  Timer { id: settle; interval: 2500; onTriggered: shellRoot.cpu("settled", shellRoot.runScenario) }

  function slots() { return bar.moduleSlots }
  function slotByName(name) { return bar.moduleSlots.find(function(s) { return s.moduleName === name }) }
  function runScenario() {
    log("slots", bar.moduleSlots.length, "targets", bar.clickTargets.length)
    if (scenario === "startup") return finish()
    if (scenario === "idle") { idleEnd.start(); return }
    if (scenario === "commit") return commitStep(0)
    if (scenario === "drag") return dragBegin()
    if (scenario === "churn") return churnStep(0)
    if (scenario === "settings") return settingsStep(0)
    if (scenario === "drawer") return drawerStep(0)
    if (scenario === "dnd") return dndRun()
    if (scenario === "prefs") return prefsRun()
    if (scenario === "inline") return inlineRun()
    if (scenario === "activity") return activityStep(0)
    if (scenario === "flash") return flashStep(0)
    finish()
  }
  Timer { id: idleEnd; interval: 10000; onTriggered: shellRoot.finish() }
  function geometry() {
    var out = bar.moduleSlots.map(function(s) {
      var p = s.mapToItem(null, 0, 0)
      var pr = s.presentationItem
      var q = pr.mapToItem(null, 0, 0)
      return [s.instanceKey.slice(-6), s.region, Math.round(p.x*10)/10, Math.round(p.y*10)/10, Math.round(s.width*10)/10, Math.round(s.height*10)/10,
        s.mainVisible, Math.round(q.x*10)/10, pr.opacity, !!s.drawerHost, s.fitFolded, s.fitYielded].join(",")
    })
    var w = bar.slotWindow(bar.moduleSlots[0])
    out.push("fit " + JSON.stringify(w.zoneFit))
    return out
  }
  Timer { id: quitFallback; interval: 1500; onTriggered: shellRoot.cpu("end", function() { Qt.quit() }) }
  function finish() {
    var g = geometry()
    for (var line of g) log("GEO", line)
    var w = bar.slotWindow(bar.moduleSlots[0])
    quitFallback.start()
    var top = bar.moduleSlots[0]; while (top.parent && String(top.parent).indexOf("ProxyWindowContentItem") < 0) top = top.parent
    var ok = top.grabToImage(function(r) {
      quitFallback.stop()
      r.saveToFile(Quickshell.env("BENCH_SHOT") || "/dev/null")
      cpu("end", function() { Qt.quit() })
    })
    if (!ok) log("grab failed")
  }

  // Reorders and cross-zone moves, each one config write.
  property real commitTotal: 0
  function commitStep(n) {
    if (n >= 40) { log("commit_avg_ms", (commitTotal / 40).toFixed(2)); return finish() }
    var names = ["b.everything", "sid.sessions", "omarchy.bluetooth", "cgranier.crashdesk"]
    var s = slotByName(names[n % names.length])
    var zones = ["left", "right", "center"]
    var to = zones[n % 3]
    var t0 = Date.now()
    bar.dropBarModule(s, to, "", "shown")
    commitTotal += Date.now() - t0
    commitTimer.n = n + 1
    commitTimer.start()
  }
  Timer { id: commitTimer; property int n: 0; interval: 60; onTriggered: shellRoot.commitStep(n) }

  // A pointer drag across the main bar, one step per 8 ms.
  property var dragSlot: null
  property var dragWindow: null
  property real dragX: 0
  property real dragY: 0
  property real dragTotal: 0
  property int dragSteps: 0
  function dragBegin() {
    dragSlot = slotByName("sid.sessions") || slots()[0]
    dragWindow = bar.slotWindow(dragSlot)
    var p = dragSlot.mapToItem(null, dragSlot.width / 2, dragSlot.height / 2)
    dragX = p.x; dragY = p.y
    var t0 = Date.now()
    bar.beginIconDrag(dragSlot, dragWindow, p, 5, 5)
    log("drag_begin_ms", Date.now() - t0)
    dragTimer.start()
  }
  Timer {
    id: dragTimer; interval: 8; repeat: true
    onTriggered: {
      var n = ++shellRoot.dragSteps
      var width = shellRoot.dragWindow.width
      shellRoot.dragX = 20 + (n * 4) % (width - 40)
      var t0 = Date.now()
      shellRoot.bar.updateIconDrag({ x: shellRoot.dragX, y: shellRoot.dragY }, shellRoot.dragSlot)
      shellRoot.dragTotal += Date.now() - t0
      if (n >= 600) {
        stop()
        shellRoot.log("drag_update_avg_ms", (shellRoot.dragTotal / n).toFixed(3))
        var t1 = Date.now()
        shellRoot.bar.finishIconDrag({ x: shellRoot.dragX, y: shellRoot.dragY }, shellRoot.dragSlot)
        shellRoot.log("drag_finish_ms", Date.now() - t1)
        dragDone.start()
      }
    }
  }
  Timer { id: dragDone; interval: 1000; onTriggered: shellRoot.finish() }

  // A widget whose value changes width and opacity, as live widgets do.
  property var churnItem: null
  function churnStep(n) {
    if (!churnItem) churnItem = slotByName("omarchy.power").activeItem
    if (n >= 200) return finish()
    churnItem.text = n % 2 ? "100% 󰁹" : "99% 󰂂"
    churnItem.dimmed = n % 4 < 2
    churnTimer.n = n + 1
    churnTimer.start()
  }
  Timer { id: churnTimer; property int n: 0; interval: 25; onTriggered: shellRoot.churnStep(n) }

  // Drag and drop through the pointer paths: across zones, into a group
  // drawer, and out of it again.
  property var dndQueue: []
  function centre(item) { return item.mapToItem(null, item.width / 2, item.height / 2) }
  function dragPath(slotFn, toFn, steps) {
    var s = null, from = null
    dndQueue.push(function() {
      s = slotFn(); from = centre(s.drawerHost || s)
      bar.beginIconDrag(s, bar.slotWindow(s), from, 4, 4)
    })
    for (var i = 1; i <= steps; i++) (function(i) {
      dndQueue.push(function() {
        var to = toFn()
        bar.updateIconDrag({ x: from.x + (to.x - from.x) * i / steps, y: from.y + (to.y - from.y) * i / steps }, s)
      })
    })(i)
    dndQueue.push(function() { var to = toFn(); bar.finishIconDrag(to, s) })
    for (var w = 0; w < 40; w++) dndQueue.push(function() {})
  }
  function dndRun() {
    var t0 = Date.now()
    dragPath(function() { return slotByName("omarchy.bluetooth") },
      function() { var t = slotByName("omarchy.workspaces"); var p = centre(t); return { x: p.x + t.width / 2 - 2, y: p.y } }, 12)
    dndQueue.push(function() {
      var header = bar.moduleSlots.find(function(s) { return s.groupHeader && s.region === "left" })
      bar.slotWindow(header).managedDrawer.openGroup(header.entry.powerbarGroupId, header, false)
    })
    for (var w = 0; w < 20; w++) dndQueue.push(function() {})
    dragPath(function() { return slotByName("omarchy.monitor") },
      function() { var m = bar.moduleSlots.find(function(s) { return s.drawerHost && s.moduleName === "sid.sessions" }); return centre(m.drawerHost) }, 12)
    dndQueue.push(function() {
      var header = bar.moduleSlots.find(function(s) { return s.groupHeader && s.region === "left" })
      bar.slotWindow(header).managedDrawer.openGroup(header.entry.powerbarGroupId, header, false)
    })
    for (var w2 = 0; w2 < 20; w2++) dndQueue.push(function() {})
    dragPath(function() { return bar.moduleSlots.find(function(s) { return s.drawerHost && s.moduleName === "meviusisback.agent-orchestr" }) },
      function() { var t = slotByName("omarchy.keyboard-layout"); return centre(t) }, 12)
    dndQueue.push(function() {
      log("dnd_ms", Date.now() - t0)
      log("GEO layout", JSON.stringify(shellConfig.bar.layout))
      log("GEO groups", JSON.stringify(shellConfig.bar.powerbarGroups))
      finish()
    })
    dndTimer.start()
  }
  Timer { id: dndTimer; interval: 16; repeat: true; onTriggered: { var f = shellRoot.dndQueue.shift(); if (!shellRoot.dndQueue.length) stop(); if (f) f() } }

  // Preferences: open (captures every widget), reorder tiles in the Layout
  // editor with its own lift/move/drop, then close.
  property var prefsPane: null
  property var prefsQueue: []
  function findPrefs() {
    for (var i = 0; i < bar.data.length; i++) if (bar.data[i] && bar.data[i].pageItems !== undefined) return bar.data[i]
    return null
  }
  function prefsRun() {
    prefsPane = findPrefs()
    if (!prefsPane || !prefsPane.pageItems) { log("no real preferences"); return finish() }
    var t0 = Date.now()
    prefsPane.show(Quickshell.screens[0])
    log("prefs_open_ms", Date.now() - t0)
    var editor = prefsPane.pageItems[0]
    for (var w = 0; w < 60; w++) prefsQueue.push(function() {})
    for (var n = 0; n < 8; n++) (function(n) {
      prefsQueue.push(function() {
        editor.place({ section: n % 2 ? "right" : "left", mode: "shown", pos: 1 })
        editor.lift(editor.cursorRecord, editor.cursorCell)
      })
      prefsQueue.push(function() { editor.moveCursor(1, 0) })
      prefsQueue.push(function() { editor.moveCursor(1, 0) })
      prefsQueue.push(function() { var t = Date.now(); editor.drop(); shellRoot.prefsDropTotal += Date.now() - t })
      for (var w2 = 0; w2 < 25; w2++) prefsQueue.push(function() {})
    })(n)
    prefsQueue.push(function() {
      log("prefs_drop_avg_ms", (prefsDropTotal / 8).toFixed(2))
      log("GEO snapshots", Object.keys(prefsPane.snapshots).length)
      log("GEO layout", JSON.stringify(shellConfig.bar.layout))
      var t = Date.now(); prefsPane.close(); log("prefs_close_ms", Date.now() - t)
    })
    for (var w3 = 0; w3 < 10; w3++) prefsQueue.push(function() {})
    prefsQueue.push(function() { finish() })
    prefsTimer.start()
  }
  property real prefsDropTotal: 0
  Timer { id: prefsTimer; interval: 16; repeat: true; onTriggered: { var f = shellRoot.prefsQueue.shift(); if (!shellRoot.prefsQueue.length) stop(); if (f) f() } }

  // Inline mode: open each zone's dots as a click would, then collapse.
  property var inlineQueue: []
  function inlineState(label) {
    var w = bar.slotWindow(bar.moduleSlots[0])
    var f = w.zoneFit || {}
    log("GEO inline", label, "zone", w.inlineZone, "hidden", JSON.stringify(f.hidden || null), "drawer", w.managedDrawer.opened, w.managedDrawer.zone)
    for (var z of ["left", "center", "right"]) {
      var shown = bar.moduleSlots.filter(function(s) { return s.region === z && s.mainVisible && !s.drawerHost }).length
      var yielded = bar.moduleSlots.filter(function(s) { return s.region === z && s.fitYielded }).length
      log("GEO inline", label, z, "shown", shown, "yielded", yielded)
    }
    // Drawn order: each visible widget's name and start along the bar.
    for (var zone of ["left", "center", "right"]) {
      var row = bar.moduleSlots.filter(function(s) { return s.region === zone && s.mainVisible && !s.drawerHost && s.width > 0 })
        .map(function(s) { var p = s.mapToItem(null, 0, 0); return { x: Math.round(bar.vertical ? p.y : p.x), n: s.moduleName.split(".").pop() + (s.managed ? "*" : "") } })
        .sort(function(a, b) { return a.x - b.x })
      log("GEO order", label, zone, row.map(function(r) { return r.n + "@" + r.x }).join(" "))
    }
  }
  // A picture of the bar at this moment, beside the scenario's own (BENCH_SHOT).
  function shot(label) {
    var file = Quickshell.env("BENCH_SHOT")
    if (!file || file === "/dev/null") return
    var top = bar.moduleSlots[0]
    while (top.parent && String(top.parent).indexOf("ProxyWindowContentItem") < 0) top = top.parent
    top.grabToImage(function(r) { r.saveToFile(file.replace(/\.png$/, "") + "-" + label + ".png") })
  }
  function inlineRun() {
    var w = bar.slotWindow(bar.moduleSlots[0])
    if (!bar.onDemandInline) { log("not inline"); return finish() }
    inlineQueue.push(function() { inlineState("rest") })
    for (var z of ["right", "left", "center:start", "center:end"]) (function(z) {
      inlineQueue.push(function() { w.inlineEnter(z, true) })
      for (var i = 0; i < 40; i++) inlineQueue.push(function() {})
      inlineQueue.push(function() { inlineState(z + "-open"); shot(z + "-open") })
      inlineQueue.push(function() { w.inlineCollapseNow(); w.managedDrawer.close("immediate") })
      for (var j = 0; j < 40; j++) inlineQueue.push(function() {})
      inlineQueue.push(function() { inlineState(z + "-closed") })
    })(z)
    inlineQueue.push(function() { finish() })
    inlineTimer.start()
  }
  Timer { id: inlineTimer; interval: 16; repeat: true; onTriggered: { var f = shellRoot.inlineQueue.shift(); if (!shellRoot.inlineQueue.length) stop(); if (f) f() } }

  // Open and close a group drawer and a zone drawer.
  property real drawerTotal: 0
  property real drawerOpenTotal: 0
  function drawerStep(n) {
    if (n >= 40) { log("drawer_avg_ms", (drawerTotal / 40).toFixed(2)); log("drawer_open_ms", (drawerOpenTotal / 20).toFixed(2)); return finish() }
    var w = bar.slotWindow(bar.moduleSlots[0])
    var t0 = Date.now()
    if (n % 2 === 0) {
      var header = bar.moduleSlots.find(function(s) { return s.groupHeader && s.region === (n % 4 === 0 ? "left" : "right") })
      w.managedDrawer.openGroup(header.entry.powerbarGroupId, header, false)
      drawerOpenTotal += Date.now() - t0
      if (n >= 36) drawerDump.start()
    } else {
      w.managedDrawer.close("immediate")
    }
    drawerTotal += Date.now() - t0
    drawerTimer.n = n + 1
    drawerTimer.start()
  }
  Timer {
    id: drawerDump; interval: 100
    onTriggered: {
      var w = shellRoot.bar.slotWindow(shellRoot.bar.moduleSlots[0])
      var d = w.managedDrawer
      shellRoot.log("GEO drawer", d.opened, d.groupId, d.x, d.y, d.width, d.height, d.slots.length)
      for (var s of shellRoot.bar.moduleSlots) if (s.drawerHost) {
        var h = s.drawerHost, p = s.presentationItem.mapToItem(null, 0, 0), m = h.mapToItem(null, 0, 0)
        shellRoot.log("GEO mount", s.instanceKey.slice(-6), Math.round(m.x*10)/10, Math.round(m.y*10)/10, h.width, h.height,
          Math.round(p.x*10)/10, Math.round(p.y*10)/10, s.presentationItem.parent === h, s.presentationItem.opacity, h.modelData === s)
      }
    }
  }
  Timer { id: drawerTimer; property int n: 0; interval: 120; onTriggered: shellRoot.drawerStep(n) }

  // An on-demand widget changes its value: it is revealed, neighbours yield.
  function activityStep(n) {
    if (n >= 6) return finish()
    var s = slotByName("omarchy.weather")
    s.activeItem.text = n % 2 ? "12°" : "13°"
    activityTimer.n = n + 1
    activityTimer.start()
  }
  Timer { id: activityTimer; property int n: 0; interval: 1500; onTriggered: shellRoot.activityStep(n) }

  // Highlights light up across the bar, as hover would.
  function flashStep(n) {
    var shown = bar.moduleSlots.filter(function(s) { return s.mainVisible })
    if (n >= 120) return finish()
    shown[n % shown.length].flashActivity()
    flashTimer.n = n + 1
    flashTimer.start()
  }
  Timer { id: flashTimer; property int n: 0; interval: 40; onTriggered: shellRoot.flashStep(n) }

  // Settings changes that do not move widgets.
  property real settingsTotal: 0
  function settingsStep(n) {
    if (n >= 20) { log("settings_avg_ms", (settingsTotal / 20).toFixed(2)); return finish() }
    var t0 = Date.now()
    mutateShellConfig(function(c) { c.bar.powerbarShadowOpacity = 40 + n % 2 })
    settingsTotal += Date.now() - t0
    settingsTimer.n = n + 1
    settingsTimer.start()
  }
  Timer { id: settingsTimer; property int n: 0; interval: 60; onTriggered: shellRoot.settingsStep(n) }
}
