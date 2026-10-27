function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

// Bar style: "flat" hugs the screen edges like Omarchy's own bar, "floating"
// is one continuous surface held off the edges, "islands" floats each zone,
// "notch" grows the centre out of a camera (islands where there is none).
// Configs from before styles existed kept only the islands switch.
var barStyles = ["flat", "floating", "islands", "notch"]
function barStyle(config) {
  var value = config && config.powerbarStyle
  if (barStyles.indexOf(value) >= 0) return value
  return config && config.powerbarIslands === true ? "islands" : "flat"
}
function setBarStyle(config, value) {
  if (barStyles.indexOf(value) < 0) return false
  if (!config.bar) config.bar = {}
  config.bar.powerbarStyle = value
  delete config.bar.powerbarIslands
  return true
}

// The bar's own options, each with the value a config that never set it gets.
// With none set, Powerbar is Omarchy's bar plus its Preferences button: flat,
// always out, the theme's size, nothing on demand. Only a key the user wrote
// changes that; nothing here is ever written back. (Spacing between widgets
// is AppearanceModel.ranges.spacing; the look is AppearanceModel's scopes.)
function options(config) {
  var c = config || {}
  return {
    style: barStyle(c),
    autoHide: c.powerbarAutoHide === true,
    autoHideActivity: c.powerbarAutoHideActivity !== false,
    largeBar: c.powerbarLargeBar === true,
    spacingMode: c.powerbarSpacingMode === "gaps" ? "gaps" : "slots",
    onDemand: c.powerbarOnDemand === "inline" || c.powerbarOnDemand === "menu" ? c.powerbarOnDemand : "drawer",
    animations: c.powerbarAnimations !== false,
    keyLegend: c.powerbarKeyLegend !== false,
    dotsBadge: c.powerbarDotsBadge !== false,
    frameLog: c.powerbarFrameLog === true,
    // The Tuning page, for development (INTEG-155).
    tuning: c.powerbarTuning === true,
    // A camera notch's width in logical px where the default housing is off
    // (0: the default; NotchModel.js). Two-zone modes keep a gap that wide.
    notchWidth: typeof c.powerbarNotchWidth === "number" && c.powerbarNotchWidth > 0 ? Math.round(c.powerbarNotchWidth) : 0,
    notchHeight: typeof c.powerbarNotchHeight === "number" && c.powerbarNotchHeight > 0 ? Math.round(c.powerbarNotchHeight) : 0,
    // Which side of a camera the Center zone's widgets sit on (ZONE-96).
    centerSide: c.powerbarCenterSide === "left" ? "left" : "right"
  }
}

// Whether the shell's bar config is Powerbar's to write: it names Powerbar
// as the bar. Omarchy saves its whole config on every bar write, and a config
// it could not read (a file caught mid-write) falls back to its defaults,
// which name no bar; a write then would save those defaults over the file.
function ownsBarConfig(config, barId) {
  return isPlainObject(config) && !!barId && String(config.id || "") === String(barId)
}

// Widget repair (WidgetRepair.qml). Omarchy hands a full bar a copy of its
// widget registry. A copy taken while the shell reloads its widgets, as it
// does when the bar is switched, can list widgets whose component is already
// destroyed; nothing refreshes it until the shell registers another widget.

// The widgets in a registry copy with no component left. Sorted ids.
function staleWidgetIds(widgets) {
  var ids = []
  for (var id in widgets || {}) if (widgets[id] && !widgets[id].component) ids.push(id)
  return ids.sort()
}

// Where a widget's own QML is, read from its manifest as the shell reads it
// (PluginRegistry.entryPointUrl and isSafeEntryPoint): the barWidget entry
// point, a relative path inside the plugin's folder, of a manifest with the
// widget's id. → { path } or { error }
function widgetEntryPath(id, sourceDir, manifestText) {
  var dir = String(sourceDir || "").replace(/\/+$/, "")
  if (!dir || dir.charAt(0) !== "/") return { error: "no plugin folder" }
  var manifest = null
  try { manifest = JSON.parse(String(manifestText || "")) } catch (e) { manifest = null }
  if (!isPlainObject(manifest)) return { error: "manifest unreadable" }
  if (String(manifest.id || "") !== String(id)) return { error: "manifest is for " + (manifest.id || "no id") }
  var entry = isPlainObject(manifest.entryPoints) ? manifest.entryPoints.barWidget : null
  if (typeof entry !== "string" || !entry || entry.charAt(0) === "/" || entry.indexOf("..") !== -1)
    return { error: "no barWidget entry point" }
  return { path: dir + "/" + entry }
}

// The manifest files that can describe a widget, in its plugin folder, as the
// shell's scan accepts them: manifest.json, and for a first-party widget a
// sibling <Name>.manifest.json (widgets/KeyboardLayout.manifest.json for
// omarchy.keyboard-layout). widgetEntryPath checks the id inside.
function manifestCandidates(id, firstParty) {
  var names = ["manifest.json"]
  if (firstParty) {
    var name = String(id || "").split(".").pop().split("-").map(function(part) {
      return part.charAt(0).toUpperCase() + part.slice(1)
    }).join("")
    if (name) names.push(name + ".manifest.json")
  }
  return names
}

// Whether a widget Powerbar loaded itself stays in use once the registry
// changes: while the registry still lists it from the same folder. Moving a
// working widget to the shell's new component would rebuild it, briefly
// running two that each register their IPC handler.
function keepRepaired(repaired, entry) {
  var dir = function(path) { return String(path || "").replace(/\/+$/, "") }
  return !!(repaired && entry && entry.metadata && dir(repaired.sourceDir)
    && dir(entry.metadata.sourceDir) === dir(repaired.sourceDir))
}

// What a widget is called: its registry metadata's display name, else its
// manifest name, else the last part of its id.
function widgetName(metadata, id) {
  return metadata && (metadata.displayName || metadata.name) || String(id || "").split(".").pop()
}

function normalizePosition(value) {
  var next = String(value || "").trim()
  return /^(top|bottom|left|right)$/.test(next) ? next : "top"
}

function entrySettings(entry) {
  if (!isPlainObject(entry)) return {}
  var copy = {}
  for (var key in entry) {
    if (key === "id" || key === "powerbarInstance") continue
    copy[key] = entry[key]
  }
  return copy
}

function entryId(entry) {
  if (typeof entry === "string") return entry
  if (isPlainObject(entry)) {
    var id = entry["id"]
    if (id !== undefined && id !== null && String(id) !== "") return String(id)
  }
  return ""
}

// The bar's zone lists in order (SectionsModel.lists).
var zoneLists = ["left", "centerBegin", "center", "centerEnd", "right"]

function pinTrayToInner(entries, section) {
  var trayEntry = null
  var result = []
  var values = Array.isArray(entries) ? entries : []
  for (var i = 0; i < values.length; i++) {
    if (entryId(values[i]) === "omarchy.tray") trayEntry = values[i]
    else result.push(values[i])
  }
  if (trayEntry) {
    if (section === "right" || section === "centerEnd") result.unshift(trayEntry)
    else result.push(trayEntry)
  }
  return result
}

function entryIndex(entries, name) {
  if (!Array.isArray(entries)) return -1
  for (var i = 0; i < entries.length; i++) {
    if (entryId(entries[i]) === name) return i
  }
  return -1
}

function moveInstanceInConfig(config, fromRegion, instanceKey, toRegion, beforeKey, visibility) {
  var layout = config && config.bar && config.bar.layout
  // A widget of Omarchy's tray section can leave it; nothing lands there.
  if (!isPlainObject(layout) || zoneLists.concat(["tray"]).indexOf(fromRegion) < 0 ||
      zoneLists.indexOf(toRegion) < 0 || !instanceKey) return false
  var from = layout[fromRegion], to = layout[toRegion]
  if (!Array.isArray(from) || !Array.isArray(to)) return false
  var fromIndex = from.findIndex(function(entry) { return entry && entry.powerbarInstance === instanceKey })
  if (fromIndex < 0 || instanceKey === beforeKey) return false
  if (visibility !== undefined && ["shown", "managed", "hidden"].indexOf(visibility) < 0) return false
  var toIndex = beforeKey ? to.findIndex(function(entry) { return entry && entry.powerbarInstance === beforeKey }) : to.length
  if (toIndex < 0) return false
  if (from === to && fromIndex < toIndex) toIndex--
  if (from === to && fromIndex === toIndex &&
      (visibility === undefined || from[fromIndex].powerbarVisibility === visibility)) return false
  var entry = from.splice(fromIndex, 1)[0]
  if (visibility !== undefined) entry.powerbarVisibility = visibility
  to.splice(toIndex, 0, entry)
  return true
}

// A shell.json write that only changes inline widget settings (the battery
// percentage toggle, a clock format change) must not rebuild the bar.
// Compare two normalized layouts: when the structure is unchanged — same
// entry ids in the same order per region — return the settings-only changes
// as {region, index, entry}. Return null when the change is structural, or
// touches an entry a live settings push cannot safely reach: custom modules
// read their entry directly rather than an injected settings property, and
// a duplicated id makes the push ambiguous.
function inlineSettingsDelta(current, next) {
  if (!isPlainObject(current) || !isPlainObject(next)) return null
  var regions = zoneLists
  var counts = {}
  for (var r = 0; r < regions.length; r++) {
    var entries = Array.isArray(next[regions[r]]) ? next[regions[r]] : []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      counts[id] = (counts[id] || 0) + 1
    }
  }
  var changes = []
  for (var s = 0; s < regions.length; s++) {
    var region = regions[s]
    var a = Array.isArray(current[region]) ? current[region] : []
    var b = Array.isArray(next[region]) ? next[region] : []
    if (a.length !== b.length) return null
    for (var j = 0; j < a.length; j++) {
      if (entryId(a[j]) !== entryId(b[j])) return null
      if (JSON.stringify(a[j]) === JSON.stringify(b[j])) continue
      if (a[j].powerbarInstance !== b[j].powerbarInstance) return null
      if (entrySettings(a[j]).powerbarVisibility !== entrySettings(b[j]).powerbarVisibility) return null
      if (customModuleType(a[j]) || customModuleType(b[j])) return null
      if (counts[entryId(b[j])] > 1) return null
      changes.push({ region: region, index: j, entry: b[j] })
    }
  }
  return changes
}

function expandPath(value, home) {
  var path = String(value || "")
  if (path === "") return ""
  if (path.indexOf("~/") === 0) return home + path.substring(1)
  if (path.indexOf("$HOME/") === 0) return home + path.substring(5)
  return path
}

function customModuleSafeName(name) {
  var value = String(name || "")
  return value !== "" && value.indexOf("..") === -1 && value[0] !== "/"
}

function customModuleType(entry) {
  var settings = entrySettings(entry)
  var type = String(settings.type || "")
  if (type) return type
  if (settings.exec) return "command"
  if (settings.source) return "qml"
  return ""
}

function customModulePath(entry, home, configDir) {
  var settings = entrySettings(entry)
  var name = entryId(entry)
  var source = settings.source ? expandPath(settings.source, home) : ""
  if (!source && customModuleSafeName(name))
    source = String(configDir || "") + "/bar/modules/" + String(name) + ".qml"
  return source
}

// A widget can be mounted more than once (a copy per screen, a placeholder
// holding its place while it is drawn elsewhere). Panel routing has to pick the drawn one — it is the only
// one that can anchor a popup, carry the open-panel mark, or be found again
// by switchPanelFrom — and fall back to the placeholder only when nothing is
// on screen. The order the two are registered in is not stable across a live
// bar reconfiguration, so picking the first match is not good enough.
function isDrawnSlot(slot) {
  return !!slot && slot.visible === true && slot.width > 0 && slot.height > 0
}

function pickDrawnSlot(slots) {
  var placeholder = null
  var list = slots || []
  for (var i = 0; i < list.length; i++) {
    if (!list[i]) continue
    if (isDrawnSlot(list[i])) return list[i]
    if (!placeholder) placeholder = list[i]
  }
  return placeholder
}

// A bar surface is built per monitor, so a panel hotkey has several live
// copies of the same widget to route to, and the panel opens on whichever
// monitor's copy answers. Candidates are `{ slot, screenName, opened }`.
//
// An open copy wins first: hide and toggle have to reach the panel the user
// can actually see, wherever it was opened from. Otherwise the focused
// monitor's copy wins, so a summon lands where the user is working instead of
// on whichever output registered its slot first. Neither narrowing applies on
// a single monitor, or when the focused output has no bar of its own.
// prefer: an instance key a hotkey just named by position (the bar carries
// the same widget twice): its copies come first.
function pickPanelSlot(candidates, focusedScreen, prefer) {
  var rows = Array.isArray(candidates) ? candidates : []
  if (prefer) {
    var named = rows.filter(function(row) { return row && row.instance === prefer })
    if (named.length > 0) rows = named
  }
  var pool = rows.filter(function(row) { return row && row.opened === true })
  if (pool.length === 0) pool = rows.filter(function(row) { return !!row })

  var focused = String(focusedScreen || "")
  if (focused) {
    var onFocused = pool.filter(function(row) { return row.screenName === focused })
    if (onFocused.length > 0) pool = onFocused
  }

  return pickDrawnSlot(pool.map(function(row) { return row.slot }))
}

// Another writer can rewrite a layout entry without Powerbar's keys: Omarchy's
// updateEntryInline (a clock's format change, the tray's pin) saves {id} plus
// the widget's own settings, dropping powerbarInstance, and the tray drops
// powerbarVisibility too. A new instance id would cost the widget its groups
// and its place in them, so the keys come back from the layout the bar showed
// before: each entry without an instance gets the powerbar* keys it lacks from
// a previous entry of the same id whose instance is not in use now, the same
// list and position first, then the same list, then anywhere.
// Returns [{zone, index, id, keys}] (zone: the list), plain values for applyLostKeys.
function lostKeys(previous, next) {
  if (!isPlainObject(previous) || !isPlainObject(next)) return []
  var zones = zoneLists.concat(["tray"])
  var used = {}, candidates = []
  for (var z = 0; z < zones.length; z++) {
    var now = Array.isArray(next[zones[z]]) ? next[zones[z]] : []
    for (var i = 0; i < now.length; i++)
      if (isPlainObject(now[i]) && now[i].powerbarInstance) used[now[i].powerbarInstance] = true
  }
  for (var y = 0; y < zones.length; y++) {
    var before = Array.isArray(previous[zones[y]]) ? previous[zones[y]] : []
    for (var j = 0; j < before.length; j++) {
      var entry = before[j]
      if (isPlainObject(entry) && entry.powerbarInstance && !used[entry.powerbarInstance])
        candidates.push({ zone: zones[y], index: j, id: entryId(entry), entry: entry })
    }
  }
  var plan = []
  for (var x = 0; x < zones.length && candidates.length; x++) {
    var entries = Array.isArray(next[zones[x]]) ? next[zones[x]] : []
    for (var k = 0; k < entries.length; k++) {
      var current = entries[k]
      if (isPlainObject(current) && current.powerbarInstance) continue
      var id = entryId(current)
      if (!id) continue
      var best = -1, score = -1
      for (var c = 0; c < candidates.length; c++) {
        var candidate = candidates[c]
        if (candidate.id !== id) continue
        var s = candidate.zone !== zones[x] ? 0 : candidate.index === k ? 2 : 1
        if (s > score) { best = c; score = s }
      }
      if (best < 0) continue
      var old = candidates.splice(best, 1)[0].entry, keys = {}
      for (var key in old) {
        if (key.indexOf("powerbar") === 0 && !(isPlainObject(current) && key in current))
          keys[key] = JSON.parse(JSON.stringify(old[key]))
      }
      plan.push({ zone: zones[x], index: k, id: id, keys: keys })
    }
  }
  return plan
}

// Put lostKeys' keys back into a bar config ({layout}), in place. Only an
// entry still at that place, of that id and without an instance is touched,
// so a plan applied to a config that changed since does no harm. Returns how
// many entries it changed.
function applyLostKeys(config, plan) {
  var layout = config && config.layout
  if (!isPlainObject(layout) || !Array.isArray(plan)) return 0
  var changed = 0
  for (var p = 0; p < plan.length; p++) {
    var step = plan[p], entries = step && layout[step.zone]
    if (!Array.isArray(entries) || !(step.index >= 0 && step.index < entries.length)) continue
    var entry = entries[step.index]
    if (entryId(entry) !== step.id || (isPlainObject(entry) && entry.powerbarInstance)) continue
    if (!isPlainObject(entry)) entry = { id: entry }
    for (var key in step.keys) if (!(key in entry)) entry[key] = JSON.parse(JSON.stringify(step.keys[key]))
    entries[step.index] = entry
    changed++
  }
  return changed
}

if (typeof module !== "undefined") {
  module.exports = {
    barStyle: barStyle,
    setBarStyle: setBarStyle,
    isDrawnSlot: isDrawnSlot,
    pickDrawnSlot: pickDrawnSlot,
    pickPanelSlot: pickPanelSlot,
    normalizePosition: normalizePosition,
    entrySettings: entrySettings,
    entryId: entryId,
    pinTrayToInner: pinTrayToInner,
    widgetName: widgetName,
    entryIndex: entryIndex,
    moveInstanceInConfig: moveInstanceInConfig,
    inlineSettingsDelta: inlineSettingsDelta,
    lostKeys: lostKeys,
    applyLostKeys: applyLostKeys,
    expandPath: expandPath,
    customModuleSafeName: customModuleSafeName,
    customModuleType: customModuleType,
    customModulePath: customModulePath
  }
}
