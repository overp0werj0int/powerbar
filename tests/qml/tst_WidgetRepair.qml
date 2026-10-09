import QtQuick
import QtTest
import "../../"

TestCase {
  id: test
  name: "WidgetRepair"
  readonly property string fixtures: String(Qt.resolvedUrl("../fixtures/repair")).replace(/^file:\/\//, "")
  QtObject { id: registry; property var widgets: ({}) }
  Component { id: liveComponent; Item {} }
  // The manifests the bar's FileView would read, by path in the fixtures.
  readonly property var manifests: ({
    "x.clock/manifest.json": '{ "id": "x.clock", "entryPoints": { "barWidget": "BarWidget.qml" } }',
    "x.broken/manifest.json": '{ "id": "x.broken", "entryPoints": { "barWidget": "BarWidget.qml" } }',
    "widgets/KeyboardLayout.manifest.json": '{ "id": "omarchy.keyboard-layout", "entryPoints": { "barWidget": "KeyboardLayout.qml" } }'
  })
  function readFile(path) {
    return path.indexOf(fixtures + "/") === 0 ? manifests[path.slice(fixtures.length + 1)] || "" : ""
  }
  WidgetRepair { id: repair; registry: registry; readText: function(path) { return test.readFile(path) } }
  function entry(id, component) { return { component: component, metadata: { sourceDir: fixtures + "/" + id + "/" } } }
  function init() { repair.repaired = ({}); repair.failed = ({}); registry.widgets = ({}) }

  function test_lostComponentIsLoadedFromItsPlugin() {
    registry.widgets = { "x.clock": entry("x.clock", null) }
    repair.sync()
    var component = repair.componentFor("x.clock", null)
    verify(component, "a component for the stale widget")
    compare(component.status, Component.Ready)
    var item = component.createObject(test)
    compare(item.kind, "fixture clock")
    item.destroy()
    compare(repair.report().stale, ["x.clock"])
    compare(repair.report().repaired, ["x.clock"])
  }
  Component { id: registryFactory; QtObject { property var widgets: ({}) } }
  function test_aHandedRegistryIsRepairedAtOnce() {
    var handed = registryFactory.createObject(test, { widgets: { "x.clock": entry("x.clock", null) } })
    repair.registry = handed
    verify(repair.componentFor("x.clock", null), "repaired when the registry is handed over")
    repair.registry = registry
    handed.destroy()
  }
  function test_aChangedRegistryIsRepairedAtOnce() {
    registry.widgets = { "x.clock": entry("x.clock", null) }
    verify(repair.componentFor("x.clock", null), "repaired when the registry's widgets change")
  }
  function test_firstPartyWidgetIsFoundByItsSiblingManifest() {
    registry.widgets = { "omarchy.keyboard-layout": { component: null, metadata: { sourceDir: fixtures + "/widgets", firstParty: true } } }
    var component = repair.componentFor("omarchy.keyboard-layout", null)
    verify(component, "loaded through widgets/KeyboardLayout.manifest.json")
    var item = component.createObject(test)
    compare(item.kind, "fixture layout")
    item.destroy()
  }
  function test_liveComponentIsLeftAlone() {
    registry.widgets = { "x.clock": entry("x.clock", liveComponent) }
    repair.sync()
    compare(repair.componentFor("x.clock", liveComponent), liveComponent)
    compare(Object.keys(repair.repaired).length, 0)
  }
  function test_refreshedRegistryKeepsTheLoadedComponent() {
    registry.widgets = { "x.clock": entry("x.clock", null) }
    repair.sync()
    var own = repair.componentFor("x.clock", null)
    registry.widgets = { "x.clock": entry("x.clock", liveComponent) }
    repair.sync()
    compare(repair.componentFor("x.clock", liveComponent), own, "a working widget is not rebuilt")
  }
  function test_unregisteredWidgetDropsItsComponent() {
    registry.widgets = { "x.clock": entry("x.clock", null) }
    repair.sync()
    registry.widgets = ({})
    repair.sync()
    compare(Object.keys(repair.repaired).length, 0)
    compare(repair.componentFor("x.clock", null), null)
  }
  function test_unloadableWidgetsAreReported() {
    registry.widgets = { "x.broken": entry("x.broken", null), "x.gone": entry("x.gone", null),
      "x.nodir": { component: null, metadata: {} } }
    ignoreWarning(new RegExp("x.broken has no component"))
    ignoreWarning(new RegExp("x.gone has no component"))
    ignoreWarning(new RegExp("x.nodir has no component"))
    repair.sync()
    compare(repair.componentFor("x.broken", null), null)
    verify(repair.failed["x.broken"].length > 0, "the QML error")
    compare(repair.failed["x.gone"], "manifest unreadable")
    compare(repair.failed["x.nodir"], "no plugin folder")
  }
}
