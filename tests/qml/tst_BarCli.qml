import QtQuick
import QtTest
import "../../"
import "../../GroupsModel.js" as GroupsModel

// `omarchy-shell powerbar <fn>` answers (docs/behavior/integration.md
// INTEG-117 to INTEG-140): BarCli against a bar and Preferences that keep the
// config and read it back the way the real ones do.
TestCase {
  id: test
  name: "BarCli"

  // Plays the bar: what it shows follows its config, as the real bar's
  // properties follow barConfig.
  QtObject {
    id: bar
    property var barConfig: ({})
    property bool canWrite: true
    property bool keep: true
    readonly property string position: barConfig.position || "top"
    readonly property bool autoHide: barConfig.powerbarAutoHide === true
    readonly property var barOptions: ({ style: barConfig.powerbarStyle || "islands" })
    property string themeName: "nord"
    property var appearance: ({ scopes: { shape: "theme", surface: "theme", shadow: "theme" }, values: {} })
    property string foregroundChoice: "theme"
    readonly property real roundingMax: 12
    property var groups: []
    property var moduleSlots: []
    property var assigned: []
    function canWriteConfig() { return canWrite }
    function editGroups(operation) {
      if (!keep) return false
      var config = { bar: JSON.parse(JSON.stringify(barConfig)) }
      operation(config)
      barConfig = config.bar
      groups = GroupsModel.groups(barConfig)
      return true
    }
    function assignGroup(key, id) {
      if (!keep) return false
      assigned = assigned.concat([{ key: key, group: id }])
      return true
    }
    function setActivityPeek() { return keep }
    function editMemberBadge() { return keep }
    function layoutEntryFor() { return null }
    function groupFor() { return null }
  }

  // Plays Preferences: its writers change the bar's config at once; `status`
  // is what it reports when it could not queue a write.
  QtObject {
    id: prefs
    property string status: ""
    property string refuse: ""
    property var calls: []
    property var entries: [
      { id: "omarchy.clock", instanceKey: "clock-1", section: "center", index: 0, mode: "shown" },
      { id: "omarchy.audio", instanceKey: "audio-1", section: "right", index: 1, mode: "shown" },
      { id: "omarchy.wifi", instanceKey: "wifi-1", section: "right", index: 2, mode: "shown" }
    ]
    property var shortcuts: store
    function note(call) {
      calls = calls.concat([call])
      if (refuse) status = refuse
    }
    function setOption(key, value) {
      note("setOption " + key)
      var next = JSON.parse(JSON.stringify(bar.barConfig))
      if (value === undefined) delete next[key]
      else next[key] = value
      bar.barConfig = next
    }
    function setBarStyle(value) { note("setBarStyle"); setOption("powerbarStyle", value) }
    function setScope(tile, value) {
      note("setScope " + tile)
      var scopes = Object.assign({}, bar.appearance.scopes)
      scopes[tile] = value
      bar.appearance = { scopes: scopes, values: bar.appearance.values }
    }
    function setLook(tile, look, value) {
      note("setLook " + tile + "." + look)
      var values = Object.assign({}, bar.appearance.values)
      if (value === undefined) delete values[look]
      else values[look] = value
      bar.appearance = { scopes: bar.appearance.scopes, values: values }
    }
    function setText(value) { note("setText"); bar.foregroundChoice = value }
    function move(record, section, mode, before) { note("move " + record.instanceKey + " " + section + " " + mode + " " + before) }
    function title(record) { return record.id }
  }

  // Plays the shortcut store (ShortcutStore.qml).
  QtObject {
    id: store
    property bool busy: false
    property bool ready: true
    property var config: ({})
    property var ownKeys: []
    property int refreshes: 0
    property var saved: []
    function refresh() { refreshes++ }
    function info() { return { keys: "", source: "none", fallback: "" } }
    function nameOf(target) { return target }
    function conflicts() { return [] }
    function save(target, keys) { saved = saved.concat([target + "=" + keys]) }
    function restore(target) { saved = saved.concat([target + "=default"]) }
    function write() { saved = saved.concat(["cleared"]) }
  }

  BarCli { id: cli; bar: bar; preferences: prefs }

  function init() {
    bar.barConfig = {}
    bar.canWrite = true
    bar.keep = true
    bar.themeName = "nord"
    bar.appearance = { scopes: { shape: "theme", surface: "theme", shadow: "theme" }, values: {} }
    bar.foregroundChoice = "theme"
    bar.groups = []
    bar.assigned = []
    prefs.status = ""
    prefs.refuse = ""
    prefs.calls = []
    store.busy = false
    store.ready = true
    store.config = {}
    store.ownKeys = []
    store.refreshes = 0
    store.saved = []
  }
  function makeGroup(label) {
    var answer = cli.newGroup(label)
    verify(answer.indexOf("{") === 0, answer)
    return JSON.parse(answer).id
  }

  // ---- settings ----------------------------------------------------------------

  function test_INTEG123_INTEG126_option_round_trip() {
    compare(cli.set("autoHide", "true"), "ok")
    compare(cli.get("autoHide"), "true")
    compare(cli.set("position", "bottom"), "ok")
    compare(cli.get("position"), "\"bottom\"")
    compare(bar.barConfig, { powerbarAutoHide: true, position: "bottom" })
  }

  function test_INTEG121_named_by_shell_json_key() {
    compare(cli.set("powerbarAutoHide", "on"), "ok")
    compare(cli.get("autoHide"), "true")
  }

  function test_INTEG126_INTEG127_style_writer() {
    compare(cli.set("style", "notch"), "ok")
    compare(prefs.calls[0], "setBarStyle")
    compare(cli.get("style"), "\"notch\"")
    bar.barConfig = { powerbarStyle: "notch", powerbarIslands: true }
    compare(cli.reset("style"), "ok")
    compare(bar.barConfig, {}, "reset drops the style and the older islands key")
  }

  function test_INTEG126_look_waits_for_a_scope_of_its_own() {
    compare(cli.set("shape.rounding", "6"), "error: shape follows the theme; set shape.scope to all or this first")
    compare(prefs.calls, [], "nothing written")
    compare(cli.set("shape.scope", "all"), "ok")
    compare(cli.get("shape.scope"), "\"all\"")
    compare(cli.set("shape.rounding", "6"), "ok")
    compare(cli.get("shape.rounding"), "6")
    compare(cli.set("shape.borders", "false"), "ok")
    compare(cli.get("shape.borders"), "false")
    compare(cli.reset("shape.rounding"), "ok")
    verify(!("rounding" in bar.appearance.values), "reset deletes the look value")
  }

  function test_INTEG127_look_reset_while_following_the_theme_changes_nothing() {
    compare(cli.reset("shape.rounding"), "ok")
    compare(prefs.calls, [])
  }

  function test_INTEG126_text_writer() {
    compare(cli.set("surface.text", "light"), "ok")
    compare(cli.get("surface.text"), "\"light\"")
    compare(cli.reset("surface.text"), "ok")
    compare(cli.get("surface.text"), "\"theme\"")
  }

  function test_INTEG126_theme_writers_wait_for_the_theme() {
    bar.themeName = ""
    compare(cli.set("surface.text", "dark"), "error: the current theme is not known yet")
    compare(cli.set("shadow.scope", "all"), "error: the current theme is not known yet")
    compare(prefs.calls, [])
  }

  function test_INTEG121_unknown_setting() {
    compare(cli.get("nope"), "error: no setting nope; omarchy-shell powerbar settings lists them")
    compare(cli.set("nope", "1"), "error: no setting nope; omarchy-shell powerbar settings lists them")
    compare(cli.reset("nope"), "error: no setting nope; omarchy-shell powerbar settings lists them")
    verify(cli.get("zones").indexOf("error: zones are always five") === 0, "a retired setting says what replaced it")
  }

  function test_INTEG126_bad_values() {
    compare(cli.set("autoHide", "maybe"), "error: autoHide is true or false")
    compare(cli.set("position", "middle"), "error: position is one of top, bottom, left, right")
    compare(cli.set("spacing", "\"4\""), "error: spacing is a number")
    compare(cli.set("spacing", "17"), "error: spacing is from 0 to 16")
    compare(cli.set("surface.opacity", "33"), "error: surface.opacity moves in steps of 5")
  }

  function test_INTEG126_rounding_tops_at_the_bars_own() {
    cli.set("shape.scope", "all")
    compare(cli.set("shape.rounding", "13"), "error: shape.rounding is from 0 to 12")
  }

  function test_INTEG128_toggle() {
    compare(cli.toggle("autoHide"), "ok")
    compare(cli.get("autoHide"), "true")
    compare(cli.toggle("autoHide"), "ok")
    compare(cli.get("autoHide"), "false")
    compare(cli.toggle("position"), "error: position is not a switch")
  }

  function test_INTEG119_no_way_to_save() {
    bar.canWrite = false
    compare(cli.set("autoHide", "true"), "error: the shell gives Powerbar no way to save its settings")
    compare(cli.newGroup("Media"), "error: the shell gives Powerbar no way to save its settings")
    compare(prefs.calls, [])
  }

  function test_INTEG119_write_refused_when_queued() {
    prefs.refuse = "Could not save. Check that shell.json is writable."
    compare(cli.set("autoHide", "true"), "error: Could not save. Check that shell.json is writable.")
    prefs.refuse = ""
    compare(cli.set("autoHide", "false"), "ok", "the next write starts with the status clear")
  }

  // ---- groups ------------------------------------------------------------------

  function test_INTEG133_newGroup() {
    var id = makeGroup("  Media ")
    verify(/^g-[0-9a-z]+-[0-9a-z]+$/.test(id), id)
    compare(bar.groups.length, 1)
    compare(bar.groups[0].label, "Media")
    compare(bar.groups[0].id, id)
    makeGroup("")
    compare(bar.groups[1].label, "New group")
  }

  function test_INTEG133_newGroup_refused() {
    var long = new Array(82).join("x")
    compare(cli.newGroup(long), "error: label is at most 80 characters")
    bar.keep = false
    compare(cli.newGroup("Media"), "error: the change could not be saved")
    compare(bar.groups, [])
  }

  function test_INTEG134_setGroup() {
    var id = makeGroup("Media")
    compare(cli.setGroup("Media", "{\"label\":\"Sound\",\"visibility\":\"managed\"}"), "ok")
    compare(bar.groups[0].label, "Sound")
    compare(bar.groups[0].visibility, "managed")
    compare(cli.setGroup(id, "{\"members\":[\"omarchy.audio\",\"wifi-1\"]}"), "ok")
    compare(bar.assigned, [{ key: "audio-1", group: id }, { key: "wifi-1", group: id }])
  }

  function test_INTEG134_setGroup_refused() {
    var id = makeGroup("Media")
    compare(cli.setGroup("Nope", "{\"label\":\"x\"}"), "error: no group Nope")
    compare(cli.setGroup(id, "{\"colour\":\"red\"}").indexOf("error: unknown field colour; fields are "), 0)
    compare(cli.setGroup(id, "{\"before\":\"omarchy.clock\"}"), "error: before names a widget in the center zone")
    compare(cli.setGroup(id, "{\"members\":[\"omarchy.nope\"]}"), "error: no widget omarchy.nope in the layout")
    compare(bar.assigned, [], "a bad member stops the change before any is made")
    bar.keep = false
    compare(cli.setGroup(id, "{\"label\":\"Sound\"}"), "error: the change could not be saved")
    compare(bar.groups[0].label, "Media")
  }

  function test_INTEG135_removeGroup() {
    var id = makeGroup("Media")
    bar.keep = false
    compare(cli.removeGroup(id), "error: the change could not be saved")
    compare(bar.groups.length, 1)
    bar.keep = true
    compare(cli.removeGroup("Media"), "ok")
    compare(bar.groups, [])
    compare(cli.removeGroup(id), "error: no group " + id)
  }

  // ---- widgets -----------------------------------------------------------------

  function test_INTEG131_setWidget_moves_through_preferences() {
    compare(cli.setWidget("omarchy.wifi", "{\"before\":\"audio-1\"}"), "ok")
    compare(prefs.calls, ["move wifi-1 right shown 1"])
    prefs.calls = []
    compare(cli.setWidget("omarchy.clock", "{\"visibility\":\"managed\"}"), "ok")
    compare(prefs.calls, ["move clock-1 center managed 1"], "visibility alone keeps its place")
  }

  function test_INTEG131_setWidget_placement_refused() {
    compare(cli.setWidget("omarchy.audio", "{\"before\":\"audio-1\"}"), "error: a widget can't go before itself")
    compare(cli.setWidget("omarchy.audio", "{\"zone\":\"left\",\"before\":\"omarchy.clock\"}"),
      "error: before names a widget in the center zone, not left")
    compare(cli.setWidget("omarchy.audio", "{\"badgeProperty\":\"1x\"}"), "error: 1x is not a property name")
    compare(cli.setWidget("omarchy.nope", "{}"), "error: no widget omarchy.nope in the layout")
    compare(prefs.calls, [], "nothing moved")
  }

  function test_INTEG131_setWidget_refused_edit() {
    var id = makeGroup("Media")
    bar.keep = false
    compare(cli.setWidget("omarchy.audio", "{\"group\":\"" + id + "\"}"), "error: the change could not be saved")
  }

  // ---- shortcuts ---------------------------------------------------------------

  function test_INTEG125_INTEG140_refused_while_the_store_is_busy() {
    store.busy = true
    var busy = "error: a shortcut change is still being applied; try again in a moment"
    compare(cli.set("shortcut.bar:keys", "SUPER + K"), busy)
    compare(cli.reset("shortcut.bar:keys"), busy)
    compare(cli.clearShortcuts(), busy)
    compare(store.saved, [])
    compare(store.refreshes, 0, "no reread while a change is being applied")
  }

  function test_INTEG125_first_use_reads_hyprland() {
    store.ready = false
    compare(cli.set("shortcut.bar:keys", "SUPER + K"), "error: reading Hyprland's shortcuts; try again in a moment")
    compare(store.refreshes, 1)
    compare(store.saved, [])
  }

  function test_INTEG125_set_and_reset() {
    compare(cli.set("shortcut.bar:keys", "super + k"), "ok")
    compare(cli.reset("shortcut.bar:keys"), "ok")
    compare(store.saved, ["bar:keys=SUPER + K", "bar:keys=default"])
    compare(cli.set("shortcut.group:nope", "SUPER + K"), "error: no group nope")
    compare(cli.set("shortcut.bar:keys", "K"), "error: Add Super, Ctrl or Alt")
  }
}
