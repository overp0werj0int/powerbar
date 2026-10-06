import QtQuick
import qs.Commons
import "CliModel.js" as Cli
import "AppearanceModel.js" as AppearanceModel
import "GroupsModel.js" as GroupsModel
import "GroupBadgeModel.js" as GroupBadgeModel
import "ShortcutModel.js" as Shortcuts

// Powerbar from the command line: `omarchy-shell powerbar <function>` (README,
// "Command line"). Reads what the bar shows and writes through the same
// functions Preferences' pages call (Preferences.setOption, move, setLook…,
// the bar's group and widget edits), so a change from here is validated,
// queued and healed exactly like one made by hand. CliModel.js holds the
// rules; Bar.qml's IpcHandler calls in here.
Item {
  id: cli
  required property var bar
  required property var preferences
  visible: false

  function fail(message) { return "error: " + message }
  function json(value) { return JSON.stringify(value === undefined ? null : value) }
  function ctx() { return { roundingMax: bar.roundingMax, groups: bar.groups.map(function(g) { return g.id }) } }
  // Preferences reports a write it could not queue in its footer status, so a
  // change starts with it clear and is answered from it.
  function begin() {
    preferences.status = ""
    return bar.canWriteConfig() ? "" : fail("the shell gives Powerbar no way to save its settings")
  }
  function written() { return preferences.status ? fail(preferences.status) : "ok" }

  // ---- settings --------------------------------------------------------------
  // What the bar uses now: the stored value, else its default, read from the
  // same properties the drawing and Preferences read.
  function valueOf(s) {
    var b = bar, look = b.appearance, fx = b.surfaceEffects
    switch (s.name) {
    case "position": return b.position
    case "transparent": return b.requestedTransparent
    case "centerAnchor": return b.centerAnchor
    case "style": return b.barStyle
    case "largeBar": return b.largeBar
    case "spacingMode": return b.spacingMode
    case "spacing": return AppearanceModel.clampTo(AppearanceModel.ranges.spacing, b.barConfig.powerbarSpacing)
    case "autoHide": return b.autoHide
    case "autoHideActivity": return b.autoHideActivity
    case "readableOverlay": return fx.readableOverlay
    case "animations": return b.animationsEnabled
    case "onDemand": return b.onDemandInline ? "inline" : "drawer"
    case "dotsBadge": return b.dotsBadge
    case "keyLegend": return b.keyLegend
    case "revealSeconds": return b.managedRevealSeconds
    case "entryGraceSeconds": return b.managedEntrySeconds
    case "exitGraceSeconds": return b.managedExitSeconds
    case "shape.scope": case "surface.scope": case "shadow.scope": return look.scopes[s.tile]
    case "shape.rounding":
      return Math.min(b.roundingMax, typeof look.values.rounding === "number" ? look.values.rounding : Style.cornerRadius / Style.spacing.scale)
    case "shape.borders": return look.values.borders !== false
    case "shape.borderWidth":
      return AppearanceModel.clampTo(AppearanceModel.ranges.borderWidth, look.values.borderWidth, Border.top(b.themeIslandBorder) / Style.space(1))
    case "surface.opacity": return Math.round(fx.backgroundOpacity * 100)
    case "surface.blur": return fx.blur
    case "surface.text": return b.foregroundChoice
    case "shadow.enabled": return fx.shadow
    case "shadow.softness": return fx.shadowSize
    case "shadow.strength": return Math.round(fx.shadowOpacity * 100)
    }
    return null
  }
  function values() {
    var out = {}
    for (var s of Cli.settings) out[s.name] = valueOf(s)
    return out
  }
  function get(name) {
    var s = Cli.find(name)
    if (!s) return fail("no setting " + name + "; omarchy-shell powerbar settings lists them")
    if (s.type === "shortcut") {
      var bad = Cli.shortcutTarget(s.target, ctx())
      if (bad) return fail(bad)
      var info = json(shortcutInfo(s.target))
      reread()
      return info
    }
    return json(valueOf(s))
  }
  function set(name, text) {
    var s = Cli.find(name)
    if (!s) return fail("no setting " + name + "; omarchy-shell powerbar settings lists them")
    var cannot = begin()
    if (cannot) return cannot
    var checked = Cli.check(s, Cli.parseValue(text), ctx())
    return checked.error ? fail(checked.error) : write(s, checked.value)
  }
  function write(s, value) {
    switch (s.writer) {
    case "option": preferences.setOption(s.key, value); break
    case "style": preferences.setBarStyle(value); break
    case "scope":
      if (!bar.themeName) return fail("the current theme is not known yet")
      preferences.setScope(s.tile, value)
      break
    case "look":
      if (bar.appearance.scopes[s.tile] === "theme")
        return fail(s.tile + " follows the theme; set " + s.tile + ".scope to all or this first")
      preferences.setLook(s.tile, s.look, value)
      break
    case "text":
      if (!bar.themeName) return fail("the current theme is not known yet")
      preferences.setText(value)
      break
    case "shortcut": return setShortcut(s.target, value)
    }
    return written()
  }
  function reset(name) {
    var s = Cli.find(name)
    if (!s) return fail("no setting " + name + "; omarchy-shell powerbar settings lists them")
    var cannot = begin()
    if (cannot) return cannot
    switch (s.writer) {
    case "option": preferences.setOption(s.key, undefined); break
    case "style":
      // Earlier versions' powerbarIslands goes too, as choosing a style drops it.
      preferences.setOption("powerbarStyle", undefined)
      preferences.setOption("powerbarIslands", undefined)
      break
    case "scope":
      if (!bar.themeName) return fail("the current theme is not known yet")
      preferences.setScope(s.tile, AppearanceModel.defaultScope(AppearanceModel.appearanceOf(bar.barConfig, bar.themeName), s.tile))
      break
    case "look":
      // Following the theme, nothing of yours is in use here.
      if (bar.appearance.scopes[s.tile] === "theme") return "ok"
      preferences.setLook(s.tile, s.look, undefined)
      break
    case "text":
      if (!bar.themeName) return fail("the current theme is not known yet")
      preferences.setText("theme")
      break
    case "shortcut": return resetShortcut(s.target)
    }
    return written()
  }
  function toggle(name) {
    var s = Cli.find(name)
    if (!s) return fail("no setting " + name + "; omarchy-shell powerbar settings lists them")
    var next = Cli.toggled(s, valueOf(s))
    if (next.error) return fail(next.error)
    var cannot = begin()
    return cannot ? cannot : write(s, next.value)
  }
  function settings() { return json(Cli.describe(ctx())) }

  // ---- widgets ---------------------------------------------------------------
  // The bar's own reading where the widget is loaded: one the registry does
  // not describe yet draws as Omarchy's bar would draw it, so it is shown.
  function liveMode(record) {
    var slot = bar.moduleSlots.find(function(s) { return s && !s.groupHeader && s.instanceKey === record.instanceKey })
    return !slot ? record.mode : slot.visibilityMode === "pending" ? "shown" : slot.visibilityMode
  }
  function widgetList() {
    return preferences.entries.map(function(r) {
      var entry = bar.layoutEntryFor(r.instanceKey) || {}, own = {}
      for (var k in entry) if (k !== "id" && k.indexOf("powerbar") !== 0) own[k] = entry[k]
      var group = bar.groupFor(r.instanceKey)
      return { id: r.id, instance: r.instanceKey, name: preferences.title(r), zone: r.section, index: r.index,
        visibility: liveMode(r), group: group ? group.id : "", centered: r.section === "center" && bar.centerAnchor === r.id,
        activityPeek: bar.activityPeeksFor(r.instanceKey, r.id), badgeProperty: r.badgeProperty,
        urgentProperty: r.urgentProperty, settings: own }
    })
  }
  function setWidget(selector, text) {
    var cannot = begin()
    if (cannot) return cannot
    var entries = preferences.entries
    var found = Cli.widgetRecord(entries, selector)
    if (found.error) return fail(found.error)
    var checked = Cli.widgetPatch(Cli.parseValue(text), ctx())
    if (checked.error) return fail(checked.error)
    var p = checked.patch, r = Object.assign({}, found.record, { mode: liveMode(found.record) }), beforeRecord = null
    if (p.before) {
      var b = Cli.widgetRecord(entries, p.before)
      if (b.error) return fail(b.error)
      beforeRecord = b.record
    }
    var place = Cli.placement(r, p, beforeRecord)
    if (place.error) return fail(place.error)
    // Checked before anything is written, so a change lands whole or not at all.
    for (var field of ["badgeProperty", "urgentProperty"])
      if (p[field] && !GroupBadgeModel.propertyName(p[field], field === "badgeProperty"))
        return fail(p[field] + " is not a property name")
    if (p.centered === true && (place.section !== "center" || place.mode !== "shown"))
      return fail("centered is for a widget on the bar in the center zone")
    if (place.changed) {
      preferences.move(r, place.section, place.mode, place.before)
      if (preferences.status) return fail(preferences.status)
    }
    if (p.group !== undefined) bar.assignGroup(r.instanceKey, p.group, "")
    if (p.activityPeek !== undefined) bar.setActivityPeek(r.instanceKey, p.activityPeek)
    if (p.badgeProperty !== undefined) bar.editMemberBadge(r.instanceKey, "badgeProperty", p.badgeProperty)
    if (p.urgentProperty !== undefined) bar.editMemberBadge(r.instanceKey, "urgentProperty", p.urgentProperty)
    if (p.centered === true) preferences.setOption("centerAnchor", r.id)
    else if (p.centered === false && bar.centerAnchor === r.id) preferences.setOption("centerAnchor", "")
    return written()
  }

  // ---- groups ----------------------------------------------------------------
  function groupList() {
    var entries = preferences.entries
    return bar.groups.map(function(g) {
      return { id: g.id, label: g.label, icon: g.icon, iconFont: g.iconFont || "", iconImage: g.iconImage || "",
        iconTint: g.iconTint || "text", zone: g.section, before: g.before, visibility: g.visibility, face: g.face,
        tooltip: g.tooltip === undefined ? null : g.tooltip, badge: g.badge, badgeMode: g.badgeMode,
        memberDisplay: g.memberDisplay, members: g.items.map(function(key) {
          var r = entries.find(function(e) { return e.instanceKey === key })
          return { instance: key, id: r ? r.id : "" }
        }) }
    })
  }
  function newGroup(label) {
    var cannot = begin()
    if (cannot) return cannot
    var name = String(label || "").trim().slice(0, 80) || "New group"
    // As the Groups page makes them.
    var id = "g-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7)
    bar.editGroups(function(config) { GroupsModel.create(config, id, name) })
    return preferences.status ? fail(preferences.status) : json({ id: id })
  }
  function setGroup(selector, text) {
    var cannot = begin()
    if (cannot) return cannot
    var found = Cli.groupRecord(bar.groups, selector)
    if (found.error) return fail(found.error)
    var checked = Cli.groupPatch(Cli.parseValue(text))
    if (checked.error) return fail(checked.error)
    var g = found.group, p = checked.patch, entries = preferences.entries, edit = {}
    for (var k in p) if (k !== "members") edit[k] = p[k]
    if (p.before) {
      var b = Cli.widgetRecord(entries, p.before)
      if (b.error) return fail(b.error)
      if (b.record.section !== (p.section || g.section)) return fail("before names a widget in the " + b.record.section + " zone")
      edit.before = b.record.instanceKey
    }
    var keys = null
    if (p.members) {
      keys = []
      for (var sel of p.members) {
        var m = Cli.widgetRecord(entries, sel)
        if (m.error) return fail(m.error)
        if (keys.indexOf(m.record.instanceKey) < 0) keys.push(m.record.instanceKey)
      }
    }
    var id = g.id
    if (Object.keys(edit).length) bar.editGroups(function(config) { GroupsModel.edit(config, id, edit) })
    if (keys) for (var step of Cli.memberSteps(g.items, keys)) bar.assignGroup(step.key, step.group ? id : "", "")
    return written()
  }
  function removeGroup(selector) {
    var cannot = begin()
    if (cannot) return cannot
    var found = Cli.groupRecord(bar.groups, selector)
    if (found.error) return fail(found.error)
    var id = found.group.id
    bar.editGroups(function(config) { GroupsModel.remove(config, id) })
    return written()
  }

  // ---- shortcuts -------------------------------------------------------------
  // Preferences' store reads Hyprland when it opens; the command line reads
  // it again on each use, so the next answer is current.
  readonly property var store: preferences.shortcuts
  function reread() { if (!store.busy) store.refresh() }
  // Read once after the bar settles, so the first answer already knows them.
  Timer { interval: 6000; running: true; onTriggered: if (!cli.store.ready) cli.reread() }
  function shortcutInfo(target) {
    var e = store.info(target)
    return { target: target, name: store.nameOf(target), keys: e.keys, source: e.source, fallback: e.fallback,
      positional: e.positional || "", ready: store.ready }
  }
  function shortcutList() {
    var targets = ["bar:keys"].concat(bar.groups.map(function(g) { return "group:" + g.id }))
    var ids = []
    for (var r of preferences.entries) if (ids.indexOf(r.id) < 0) ids.push(r.id)
    targets = targets.concat(ids.map(function(id) { return "widget:" + id }))
    for (var t in (bar.barConfig.powerbarShortcuts || {})) if (targets.indexOf(t) < 0) targets.push(t)
    return targets.map(shortcutInfo).filter(function(s) {
      return s.target === "bar:keys" || s.keys || s.positional || s.source !== "none"
    })
  }
  function shortcuts() {
    var out = json({ ready: store.ready, shortcuts: shortcutList() })
    reread()
    return out
  }
  function shortcutReady() {
    if (store.busy) return fail("a shortcut change is still being applied; try again in a moment")
    if (!store.ready) { store.refresh(); return fail("reading Hyprland's shortcuts; try again in a moment") }
    return ""
  }
  function setShortcut(target, value) {
    var bad = Cli.shortcutTarget(target, ctx()) || shortcutReady()
    if (bad) return bad.indexOf("error: ") === 0 ? bad : fail(bad)
    var keys = ""
    if (value.keys) {
      var typed = Shortcuts.bindable(value.keys)
      if (typed.error) return fail(typed.error)
      keys = typed.keys
      var taken = store.conflicts(keys, target)
      if (taken.length && !value.replace) {
        return fail(keys + " is taken by " + taken.map(function(c) { return c.description }).join(", ")
          + "; to take it anyway: omarchy-shell powerbar set shortcut." + target + " '{\"keys\":\"" + keys + "\",\"replace\":true}'")
      }
    }
    store.save(target, keys)
    return written()
  }
  function resetShortcut(target) {
    var bad = Cli.shortcutTarget(target, ctx()) || shortcutReady()
    if (bad) return bad.indexOf("error: ") === 0 ? bad : fail(bad)
    store.restore(target)
    return written()
  }

  // ---- what the bar is doing -------------------------------------------------
  function windows() {
    var out = []
    for (var slot of bar.moduleSlots) {
      var w = bar.targetWindow(slot)
      if (w && w.screen && out.indexOf(w) < 0) out.push(w)
    }
    return out
  }
  function runtime() {
    var drawer = bar.managedOwner
    return { barOff: bar.barOffFlag, hidden: bar.barHidden, held: bar.cliShown,
      screens: windows().map(function(w) {
        return { screen: String(w.screen.name || ""), shown: !bar.barHidden && w.autoHideShown, peeking: w.peeking }
      }),
      keys: bar.barKeys.active,
      drawer: drawer && drawer.opened ? { zone: drawer.zone, group: drawer.groupId || "" } : null,
      preferences: { open: preferences.opened, page: preferences.opened ? preferences.pages[preferences.page].title : "" } }
  }
  function status() {
    return json({ bar: bar.manifest ? bar.manifest.id : "", version: bar.manifest ? bar.manifest.version : "",
      theme: bar.themeName, settings: values(), widgets: widgetList(), groups: groupList(),
      shortcuts: shortcutList(), runtime: runtime() })
  }

  // Bring the bar out or put it away. An autohidden bar is held out until
  // hide, as the pointer holds it at its edge. A bar switched off with
  // Omarchy's toggle comes back, and hide switches it off, through Omarchy's
  // own command (its bar-off flag) so both bars agree on what is off.
  function show() {
    if (bar.barOffFlag) bar.run("omarchy-toggle-bar off")
    if (bar.autoHide) bar.cliShown = true
    return "ok"
  }
  function hide() {
    if (bar.autoHide) {
      bar.cliShown = false
      return "ok"
    }
    if (!bar.barOffFlag) bar.run("omarchy-toggle-bar on")
    return "ok"
  }
  function keysOn() {
    if (!bar.barKeys.active) bar.barKeys.enter()
    return bar.barKeys.active ? "ok" : fail(bar.preferencesOpen ? "not while Preferences are open" : "no bar to put the cursor on")
  }
  function keysOff() {
    if (bar.barKeys.active) bar.barKeys.leave()
    return "ok"
  }
  function help() { return json(Cli.help()) }
}
