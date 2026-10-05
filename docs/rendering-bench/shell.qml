import Quickshell
import Quickshell.Io
import QtQuick
import QtTest
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
  // Omarchy's own indicators (BENCH_REAL_INDICATORS=1), for hover and tooltips.
  property Component realIndicators: Qt.createComponent("file:///usr/share/omarchy/shell/plugins/bar/widgets/Indicators.qml")
  QtObject {
    id: registry
    property var widgets: ({})
    property int revision: 0
    function metadataFor(id) { var w = widgets[String(id)]; return w ? w.metadata : null }
  }
  function kindFor(id) {
    if (id === "omarchy.clock") return clockWidget
    if (id === "omarchy.workspaces") return workspacesWidget
    if (id === "omarchy.indicators") return Quickshell.env("BENCH_REAL_INDICATORS") === "1" ? realIndicators : indicatorsWidget
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
    if (scenario === "sliders") return slidersRun()
    if (scenario === "inline") return inlineRun()
    if (scenario === "hover") return hoverRun()
    if (scenario === "tooltip") return tooltipRun()
    if (scenario === "prefskeys") return prefsKeysRun()
    if (scenario === "toggle") return toggleRun()
    if (scenario === "blur") return blurRun()
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

  // Preferences from the keyboard: on each page, Tab then Shift+Tab through
  // the tiles; logs the tile that holds focus after each key.
  function tileTitle(item) {
    for (var p = item; p; p = p.parent) if (p.title !== undefined && p.tileHints !== undefined) return p.title
    return "-"
  }
  function prefsFocus() {
    var win = null
    for (var d of prefsPane.data) if (d && d.contentItem !== undefined) win = d
    var found = null
    ;(function walk(item) {
      if (!item) return
      if (item.activeFocus) found = item
      for (var c of item.children) walk(c)
    })(win ? win.contentItem : null)
    return found
  }
  function prefsKeysRun() {
    prefsPane = findPrefs()
    if (!prefsPane || !prefsPane.pageItems) { log("no real preferences"); return finish() }
    prefsPane.show(Quickshell.screens[0])
    var q = []
    for (var w = 0; w < 40; w++) q.push(function() {})
    for (var page = 0; page < prefsPane.pages.length; page++) (function(page) {
      q.push(function() { prefsPane.setPage(page) })
      for (var w1 = 0; w1 < 20; w1++) q.push(function() {})
      if (Quickshell.env("BENCH_FOCUS_FIRST") !== "0") q.push(function() { prefsPane.pageItems[page].focusFirst(); })
      q.push(function() { log("KEYS page", page, "start", tileTitle(prefsFocus()), String(prefsFocus()).split("(")[0]) })
      ;[["Tab", Qt.Key_Tab, Qt.NoModifier], ["Tab", Qt.Key_Tab, Qt.NoModifier], ["Tab", Qt.Key_Tab, Qt.NoModifier],
        ["Shift+Tab", Qt.Key_Backtab, Qt.ShiftModifier], ["Shift+Tab", Qt.Key_Backtab, Qt.ShiftModifier], ["Shift+Tab", Qt.Key_Backtab, Qt.ShiftModifier]].forEach(function(k) {
        q.push(function() { pointer.keyClick(k[1], k[2]) })
        q.push(function() {})
        q.push(function() { log("KEYS page", page, k[0], tileTitle(prefsFocus()), String(prefsFocus()).split("(")[0]) })
      })
    })(page)
    q.push(function() { prefsPane.close(); finish() })
    prefsQueue = q
    prefsTimer.start()
  }

  // Omarchy's bar toggle on an autohidden bar (BENCH_AUTOHIDE=1; run with a
  // private HOME): the flag appears, the bar slides out, the flag goes back.
  property var toggleLog: []
  function toggleState(label) {
    var w = bar.slotWindow(bar.moduleSlots[0])
    log("TOGGLE", label, "hidden", bar.barHidden, "held", bar.toggleHeld, "revealed", w.autoHideRevealed, "shown", w.autoHideShown, "offset", Math.round(w.autoHideOffset))
  }
  function toggleRun() {
    toggleState("rest")
    toggleProc.command = ["bash", "-c", "mkdir -p $HOME/.local/state/omarchy/toggles && omarchy-toggle bar-off toggle && ls $HOME/.local/state/omarchy/toggles"]
    toggleProc.running = true
    toggleTimer.n = 0
    toggleTimer.start()
  }
  Process { id: toggleProc; stdout: SplitParser { onRead: function(line) { shellRoot.log("TOGGLE flag-dir", line) } } }
  Timer { id: toggleTimer; property int n: 0; interval: 100; repeat: true; onTriggered: {
    shellRoot.toggleState("t+" + (n * 100))
    if (++n > 12) { stop(); flagCheck.running = true }
  } }
  Process { id: flagCheck; command: ["bash", "-c", "ls -A $HOME/.local/state/omarchy/toggles; echo end"]
    stdout: SplitParser { onRead: function(line) { shellRoot.log("TOGGLE flag-after", line); if (line === "end") shellRoot.finish() } } }
  property real prefsDropTotal: 0
  Timer { id: prefsTimer; interval: 16; repeat: true; onTriggered: { var f = shellRoot.prefsQueue.shift(); if (!shellRoot.prefsQueue.length) stop(); if (f) f() } }

  // Preferences sliders: drive each gesture the way its pointer and key
  // handlers do and count how often the bar's config changes. A drag or a run
  // of key presses must reach the bar once, after it settles, not per move.
  // Each applied edit changes the config twice: once at once, then again when
  // the debounced write to shell.json comes back (about 300 ms later), so
  // phases start a second apart and report changes before the echo.
  property int configChanges: 0
  property var sliderPlan: []
  Connections {
    target: shellRoot.scenario === "sliders" ? shellRoot.bar : null
    ignoreUnknownSignals: true
    function onBarConfigChanged() { shellRoot.configChanges++ }
  }
  Timer {
    id: sliderTimer
    onTriggered: {
      var next = shellRoot.sliderPlan.shift()
      if (!next) return
      next.run()
      if (shellRoot.sliderPlan.length) { interval = shellRoot.sliderPlan[0].after; start() }
    }
  }
  function plan(after, run) { sliderPlan.push({ after: after, run: run }) }
  function findSliders(item, out) {
    if (!item) return out
    if (item.keyHints !== undefined && item.setDraft !== undefined && item.label !== undefined) out.push(item)
    for (var i = 0; i < item.children.length; i++) findSliders(item.children[i], out)
    return out
  }
  function prefsShot(label) {
    var file = Quickshell.env("BENCH_SHOT")
    if (!file || file === "/dev/null") return
    var top = prefsPane.pageItems[2]
    while (top.parent && String(top.parent).indexOf("ProxyWindowContentItem") < 0) top = top.parent
    top.grabToImage(function(r) { r.saveToFile(file.replace(/\.png$/, "") + "-" + label + ".png") })
  }
  function controlName(item) {
    return item.label || item.text || (item.Accessible ? item.Accessible.name : "") || String(item).split("(")[0]
  }
  function findForm(item) {
    if (!item) return null
    if (item.step !== undefined && item.focusFirst !== undefined && item.contentItem !== undefined) return item
    for (var i = 0; i < item.children.length; i++) { var f = findForm(item.children[i]); if (f) return f }
    return null
  }
  function findBento(item) {
    if (!item) return null
    if (item.jump !== undefined && item.shownTiles !== undefined) return item
    for (var i = 0; i < item.children.length; i++) { var f = findBento(item.children[i]); if (f) return f }
    return null
  }
  // Tab from the first control: which tiles it lands in, in order.
  function auditTabs(form, index) {
    var bento = findBento(form)
    if (!bento) return
    form.focusFirst()
    var titles = []
    for (var n = 0; n < bento.shownTiles.length; n++) {
      var t = bento.tileOf(form.focusedItem)
      titles.push(t ? t.title : "?")
      bento.jump(true)
    }
    log("AUDIT tabs", index + 1, "columns", bento.columns, "gap", bento.gap, JSON.stringify(titles), "wraps", bento.tileOf(form.focusedItem) === bento.shownTiles[0])
    for (var i = 0; i < bento.shownTiles.length; i++) {
      var tile = bento.shownTiles[i]
      log("AUDIT tile", JSON.stringify(tile.title), "x", Math.round(tile.x), "y", Math.round(tile.y), "w", Math.round(tile.width), "h", Math.round(tile.height), "needs", Math.round(tile.implicitHeight))
    }
  }
  function auditPage(host, index) {
    var page = findForm(host)
    var view = page.contentItem
    log("AUDIT page", index + 1, "viewport", Math.round(page.height), "content", Math.round(view.contentHeight), "scrolls", view.contentHeight > page.height + 1)
    page.focusFirst()
    var seen = [], stops = 0
    for (var n = 0; n < 60; n++) {
      var f = page.focusedItem
      if (!f || seen.indexOf(f) >= 0) break
      seen.push(f); stops++
      log("AUDIT stop", index + 1, JSON.stringify(controlName(f)), "y", Math.round(f.mapToItem(page, 0, 0).y), "scroll", Math.round(view.contentY))
      page.step(true)
    }
    log("AUDIT summary", index + 1, "stops", stops)
  }
  function slidersRun() {
    prefsPane = findPrefs()
    if (!prefsPane) { log("no real preferences"); return finish() }
    prefsPane.show(Quickshell.screens[0])
    prefsPane.setPage(2)
    var sliders = {}, c0 = 0
    plan(600, function() {
      var all = findSliders(prefsPane.pageItems[2], [])
      for (var s of all) {
        sliders[s.label] = s
        log("SLIDER", JSON.stringify(s.label), "range", s.minimum, s.maximum, "step", s.stepSize,
          "default", s.defaultValue, "shows", JSON.stringify(s.format(s.shown)), "enabled", s.enabled)
      }
      prefsShot("open")
    })
    // A pointer drag across the whole rounding range.
    plan(50, function() { var s = sliders["Corner rounding"]; s.forceActiveFocus(); c0 = configChanges; s.dragging = true })
    for (var i = 0; i <= 30; i++) (function(i) {
      plan(16, function() { var s = sliders["Corner rounding"]; s.setDraft(s.minimum + (s.maximum - s.minimum) * i / 30 * 0.6) })
    })(i)
    plan(16, function() {
      var s = sliders["Corner rounding"]
      log("drag: bar changes while held", configChanges - c0, "draft", s.draft, "bar rounding", bar.islandRounding)
      prefsShot("drag")
      s.endDrag()
    })
    plan(60, function() { log("drag: bar changes 60 ms after release", configChanges - c0) })
    plan(300, function() {
      var s = sliders["Corner rounding"]
      log("drag: bar changes 360 ms after release", configChanges - c0, "value", s.value, "drafting", s.drafting, "bar rounding", bar.islandRounding)
    })
    // Held key: repeats every 30 ms.
    plan(1200, function() { var s = sliders["Background opacity"]; s.forceActiveFocus(); c0 = configChanges })
    for (var k = 0; k < 12; k++) plan(30, function() { sliders["Background opacity"].step(-1) })
    plan(300, function() { log("key repeat: bar changes 300 ms after last repeat", configChanges - c0, "draft", sliders["Background opacity"].draft) })
    plan(250, function() { log("key repeat: bar changes 550 ms after last repeat", configChanges - c0, "value", sliders["Background opacity"].value) })
    // Deliberate taps every 400 ms.
    plan(1200, function() { c0 = configChanges })
    for (var t = 0; t < 4; t++) plan(t ? 400 : 0, function() { sliders["Background opacity"].step(1) })
    plan(450, function() { log("taps every 400 ms: bar changes 450 ms after last tap", configChanges - c0) })
    plan(250, function() { log("taps every 400 ms: bar changes 700 ms after last tap", configChanges - c0, "value", sliders["Background opacity"].value) })
    // Leaving a slider with a draft applies it at once.
    plan(1200, function() { var s = sliders["Background opacity"]; c0 = configChanges; s.step(2); prefsPane.setPage(1) })
    plan(30, function() { log("page switch with a draft: bar changes", configChanges - c0) })
    plan(400, function() { prefsPane.setPage(2) })
    plan(400, function() { prefsShot("end") })
    // The Bar page: whether it scrolls in this window, each focus stop, and
    // where Tab goes.
    plan(300, function() { auditPage(prefsPane.pageItems[2], 2) })
    plan(100, function() { auditTabs(findForm(prefsPane.pageItems[2]), 2) })
    for (var pg = 0; pg < 3; pg++) (function(pg) {
      plan(300, function() { prefsPane.setPage(pg) })
      plan(500, function() { prefsShot("page-" + (pg + 1)) })
    })(pg)
    plan(100, function() { prefsPane.close() })
    plan(100, function() { finish() })
    sliderTimer.interval = sliderPlan[0].after
    sliderTimer.start()
  }

  // Blur on and off: the window remaps to change its layer namespace; every
  // widget must come back to the place it had.
  property var blurQueue: []
  function blurOrder(label) {
    for (var zone of ["left", "center", "right"]) {
      var row = bar.moduleSlots.filter(function(s) { return s.region === zone && s.mainVisible && !s.drawerHost && s.width > 0 })
        .map(function(s) { var p = s.mapToItem(null, 0, 0); return { x: Math.round(bar.vertical ? p.y : p.x), n: s.moduleName.split(".").pop() + "/" + Math.round(bar.vertical ? s.height : s.width) + "/i" + (s.ink ? s.ink.length.toFixed(1) : "-") + "/s" + (s.inkShift !== undefined ? s.inkShift.toFixed(1) : "-") + "/v" + (s.activeItem ? s.activeItem.visible : "-") } })
        .sort(function(a, b) { return a.x - b.x })
      log("GEO blur", label, zone, row.map(function(r) { return r.n + "@" + r.x }).join(" "))
    }
  }
  function blurRun() {
    blurQueue.push(function() { blurOrder("before") })
    blurQueue.push(function() { mutateShellConfig(function(c) { c.bar.powerbarBlur = !(c.bar.powerbarBlur === true) }) })
    for (var i = 0; i < 4; i++) (function(i) { blurQueue.push(function() { blurOrder("toggled-" + i) }) })(i)
    blurQueue.push(function() { mutateShellConfig(function(c) { c.bar.powerbarBlur = !(c.bar.powerbarBlur === true) }) })
    for (var j = 0; j < 4; j++) (function(j) { blurQueue.push(function() { blurOrder("back-" + j) }) })(j)
    blurQueue.push(function() { finish() })
    blurTimer.start()
  }
  Timer {
    id: blurTimer
    interval: 400; repeat: true
    onTriggered: { var next = shellRoot.blurQueue.shift(); if (next) next(); if (!shellRoot.blurQueue.length) stop() }
  }

  // Inline mode: open each zone's dots as a click would, then collapse.

  // Real pointer events (QtTest) across the centre: the indicators' hover
  // reveal and the centre's dots. Logs the reveal state after each move.
  TestCase { id: pointer; name: "pointer"; when: false }
  function findAll(item, pred, out) {
    out = out || []
    if (!item) return out
    if (pred(item)) out.push(item)
    for (var c of item.children) findAll(c, pred, out)
    return out
  }
  function centreOf(item, root) { var p = item.mapToItem(root, item.width / 2, item.height / 2); return { x: p.x, y: p.y } }
  function hoverState(label) {
    var w = bar.slotWindow(bar.moduleSlots[0])
    log("HOVER", label, "held", bar.centerSectionRevealHeld, "blocks", bar.centerRevealBlocks, "centerCount", bar.centerHoverCount,
      "barCount", bar.barHoverCount, "request", w.inlineRequest || "-", "zone", w.inlineZone || "-", "handle", w.inlineHandleZone || "-")
  }
  function hoverRun() {
    var w = bar.slotWindow(bar.moduleSlots[0])
    var root = w.contentItem
    var dots = findAll(root, function(i) { return i.inlineToken !== undefined && i.visible && i.width > 0 && i.enabled })
    log("HOVER dots", dots.map(function(d) { var c = centreOf(d, root); return d.inlineToken + "@" + Math.round(c.x) + "," + Math.round(c.y) }).join(" "))
    var clock = slotByName("omarchy.clock"), ind = slotByName("omarchy.indicators")
    var startDots = dots.find(function(d) { return d.inlineToken === "center:start" }) || dots.find(function(d) { return d.inlineToken.indexOf("center") === 0 })
    var steps = []
    function at(label, target, wait) { steps.push({ label: label, target: target, wait: wait }) }
    at("clock", clock, 400)
    if (startDots) at("dots-swipe", startDots, 40)
    at("back-to-clock", clock, 400)
    if (startDots) at("dots-rest", startDots, 900)
    at("clock-after-expand", clock, 400)
    at("indicators", ind, 400)
    hoverSteps = steps
    hoverStep()
  }
  property var hoverSteps: []
  // Hover each indicator button in turn (after opening the centre reveal on
  // the clock) and log whether its tooltip shows.
  function tooltipRun() {
    var w = bar.slotWindow(bar.moduleSlots[0])
    var ind = slotByName("omarchy.indicators"), clock = slotByName("omarchy.clock")
    var steps = [{ label: "clock", target: clock, wait: 600 }]
    hoverSteps = steps
    tooltipQueue = []
    hoverStepThen(function() {
      var buttons = findAll(ind, function(i) { return i.tooltipHovered !== undefined && i.visible && i.width > 0 })
      log("TIP buttons", buttons.length, buttons.map(function(b) { return (b.moduleName || "?") + ":" + b.text.codePointAt(0) + ":op" + b.opacity.toFixed(2) + ":" + JSON.stringify(b.tooltipText) }).join(" "))
      var others = findAll(slotByName("omarchy.clock"), function(i) { return i.tooltipHovered !== undefined })
        .concat(findAll(slotByName("omarchy.keyboard-layout"), function(i) { return i.tooltipHovered !== undefined }))
      tooltipQueue = others.concat(buttons)
      tooltipNext()
    })
  }
  property var tooltipQueue: []
  function tooltipNext() {
    var b = tooltipQueue.shift()
    if (!b) return finish()
    var w = bar.slotWindow(bar.moduleSlots[0])
    var c = centreOf(b, w.contentItem)
    pointer.mouseMove(w.contentItem, c.x, c.y)
    log("TIP move", b.moduleName, Math.round(c.x), Math.round(c.y))
    hoverState("moved-" + b.moduleName)
    tipTimer.button = b
    tipTimer.start()
  }
  Timer { id: tipTimer; property var button; interval: 700; onTriggered: {
    var b = button
    shellRoot.log("TIP", b.moduleName, "hovered", b.tooltipHovered, "concealed", b.concealed, "interactive", b.interactive, "op", b.opacity.toFixed(2),
      "target", shellRoot.bar.tooltipTarget === b, "shown", shellRoot.bar.tooltipShown, "text", JSON.stringify(shellRoot.bar.tooltipText), "held", shellRoot.bar.centerSectionRevealHeld)
    shellRoot.hoverState("after-" + b.moduleName)
    shellRoot.tooltipNext()
  } }
  property var hoverThen: null
  function hoverStepThen(f) { hoverThen = f; hoverStep() }
  function hoverStep() {
    var step = hoverSteps.shift()
    if (!step) { if (hoverThen) { var f = hoverThen; hoverThen = null; return f() } return finish() }
    var w = bar.slotWindow(bar.moduleSlots[0])
    var c = centreOf(step.target, w.contentItem)
    pointer.mouseMove(w.contentItem, c.x, c.y)
    hoverState(step.label + "-now")
    hoverTimer.interval = step.wait
    hoverTimer.label = step.label
    hoverTimer.start()
  }
  Timer { id: hoverTimer; property string label; onTriggered: { shellRoot.hoverState(label + "-later"); shellRoot.hoverStep() } }
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
