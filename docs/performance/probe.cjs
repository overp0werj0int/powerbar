// Actual Bar.qml update functions, with fictional slot/window/target objects.
// No shell, native services, helper commands, or desktop state is instantiated.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { pathToFileURL } = require('node:url');
const { spawnSync } = require('node:child_process');
const repo = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(repo, 'Bar.qml'), 'utf8');
function extract(name) {
  const start = source.indexOf('function ' + name + '(');
  if (start < 0) throw new Error('Missing Bar.qml function: ' + name);
  let end = source.indexOf('{', start), depth = 1;
  while (depth && end < source.length) { end++; if (source[end] === '{') depth++; if (source[end] === '}') depth--; }
  if (depth) throw new Error('Unbalanced function: ' + name);
  return source.slice(start, end + 1);
}
const emitAt = process.argv.indexOf('--emit');
const emitOnly = emitAt >= 0;
const dir = emitOnly ? path.resolve(process.argv[emitAt + 1]) : fs.mkdtempSync(path.join(os.tmpdir(), 'powerbar-render-probe-'));
fs.mkdirSync(dir, {recursive: true});
const functions = ['reconcileWidgets', 'resolveTargetSlot', 'attachTarget', 'resolvePendingTargets', 'registerClickTarget',
  'unregisterClickTarget', 'refreshTargetOwner', 'dropTargetWatch', 'registerModuleSlot', 'unregisterModuleSlot', 'targetsForSlot', 'pluginObjectRecord',
  'markPluginObject', 'unmarkPluginObject', 'pluginOwnsBarObject', 'registerPluginClickTarget', 'unregisterPluginClickTarget', 'captureWidgetImages', 'sameWindow', 'slotWindow', 'targetWindow'];
const qml = `import QtQuick
import QtQml.Models as Models
import QtTest
import ${JSON.stringify(pathToFileURL(repo).href)} as Powerbar
import ${JSON.stringify(pathToFileURL(path.join(repo, 'RenderModel.js')).href)} as RenderModel
import "Counters.js" as Counters
TestCase {
 id: root
 name: "PowerbarUpdatePaths"
 when: windowShown
 width: 600; height: 200
 property var layoutConfig: ({left: [], center: [], right: []})
 property string centerAnchor: ""
 property var moduleSlots: []
 property var moduleItems: []
 property var clickTargets: []
 property var targetSlots: []
 property var pendingTargets: []
 property var targetWatches: []
 Component { id: targetWatchFactory; Powerbar.TargetOwnerObserver { id: watch; onChanged: { if (target) root.refreshTargetOwner(target); else root.dropTargetWatch(watch) } } }
 property var slotCopies: Object.create(null)
 property var activityDeadlines: Object.create(null)
 property var pluginObjectOwners: []
 property int born: 0
 property int died: 0
 property int observed: 0
 property int observerDied: 0
 property int layouts: 0
 property bool vertical: false
 property int saves: 0
 property var captureCallbacks: []
 property var captureSizes: []
 property var images: []
 Powerbar.CaptureQueue { id: imageCaptures }
 QtObject {
  id: captureSource
  property real width: 40
  property real height: 20
  property real implicitWidth: 60
  property real implicitHeight: 30
  function grabToImage(callback, size) { root.captureCallbacks.push(callback); root.captureSizes.push(size); return true }
 }
 function widgetImageFile(key) { return "/tmp/unused-fixture-" + key }
 function captureResult() { return {url: "fixture", saveToFile: function(file) { root.saves++ }} }
 property alias widgetStore: widgetStore
 property var widgetModels: ({left:leftModel, right:rightModel, center:centerModel, before:beforeModel, anchor:anchorModel, after:afterModel})
 Models.ObjectModel { id: leftModel }
 Models.ObjectModel { id: rightModel }
 Models.ObjectModel { id: centerModel }
 Models.ObjectModel { id: beforeModel }
 Models.ObjectModel { id: anchorModel }
 Models.ObjectModel { id: afterModel }
 ${functions.map(name => name === 'targetsForSlot' ? extract(name).replace('{', '{ Counters.reads++;') : extract(name)).join('\n')}
 Powerbar.RetainedStore {
  id: widgetStore
  factory: Component {
   Item {
    id: slot
    required property var record
    readonly property string instanceKey: record.key
    readonly property string region: record.region
    property bool centerAnchorSlot: false
    property int state: 42
    property real activityUntil: 0
    property var slotTargets: []
    property alias presentationItem: presentation
    property alias activeItem: widget
    width: 20; height: 24
    Item { id: presentation; property var powerbarSlotOwner: slot; Item { id: widget; property string text: "idle" } }
    readonly property var activityTargets: {
      var result = root.targetsForSlot(slot).slice()
      if (result.indexOf(widget) < 0) result.unshift(widget)
      return result
    }
    Repeater {
      model: slot.activityTargets
      Powerbar.ActivityObserver {
        required property var modelData
        target: modelData
        Component.onCompleted: root.observed++
        Component.onDestruction: root.observerDied++
      }
    }
    Component.onCompleted: { root.born++; root.registerModuleSlot(slot) }
    Component.onDestruction: { root.died++; root.unregisterModuleSlot(slot) }
   }
  }
 }
 Grid { id: left; rows: vertical ? -1 : 1; columns: vertical ? 1 : -1; property bool vertical: false; Repeater { model: leftModel } }
 Row { id: right; y: 70; Repeater { model: rightModel } }
 Row { y: 100; Repeater { model: centerModel } }
 Row { y: 130; Repeater { model: beforeModel } }
 Row { y: 155; Repeater { model: anchorModel } }
 Row { y: 180; Repeater { model: afterModel } }
 Component { id: targetFactory; Item {} }
 Component {
  id: apiFactory
  QtObject {
   required property string pluginId
   property var layoutConfig: ({})
   property var clickTargets: []
   property var activePopout: null
   property var foreignPopoutMarker: ({foreign: true})
   onLayoutConfigChanged: root.layouts++
  }
 }
 Powerbar.PluginApiSync {
  id: apiSync
  layoutJSON: JSON.stringify(root.layoutConfig)
  owns: function(id, target) { return root.pluginOwnsBarObject(id, target) }
 }
 function entries() {
  var result = []
  for (var i = 0; i < 24; i++) result.push({id: "duplicate", powerbarInstance: "key" + i})
  return result
 }
 function render(leftEntries, rightEntries) { layoutConfig = { left: leftEntries, center: [], right: rightEntries || [] }; reconcileWidgets(); wait(1) }
 function cleanup() { apiSync.apis = ({}); apiSync.popout = null; render([]); wait(1); Counters.reads = 0; born = 0; died = 0; observed = 0; observerDied = 0 }
 function test_destroyedTargetCleanup() {
  render(entries())
  var slot = widgetStore.get("key0")
  var target = targetFactory.createObject(slot.presentationItem)
  registerClickTarget(target); wait(1)
  target.destroy(); wait(5)
  compare(slot.slotTargets.length, 0)
  compare(clickTargets.length, 0)
  compare(targetWatches.length, 0)
 }
 function test_captureSourceAndGenerationGuards() {
  var screen = {name: "fictional"}, window = {screen: screen, moduleItems: []}
  var slot = {instanceKey: "capture", record: {key:"capture"}, homeWindow: window,
    mainVisible: true, visible: true, drawerHost: null, needsPlaceholder: false,
    activeItem: captureSource, presentationItem: captureSource}
  window.moduleItems = [slot]; moduleSlots = [slot]
  var current = true
  captureWidgetImages(screen, function(key, image) { root.images.push(image) }, null, function() { return current })
  compare(captureSizes[0].width, 80); compare(captureSizes[0].height, 40)
  current = false; captureCallbacks[0](captureResult()); wait(1)
  compare(images.length, 0); compare(saves, 0)
  current = true
  captureWidgetImages(screen, function(key, image) { root.images.push(image) })
  slot.record = {key: "capture", changed: true}
  captureCallbacks[1](captureResult()); wait(1); compare(images.length, 0); compare(saves, 0)
  slot.mainVisible = false; slot.instanceKey = "group:fictional"
  captureWidgetImages(screen, function(key, image) { root.images.push(image) })
  compare(captureSizes[2].width, 120); compare(captureSizes[2].height, 60)
  captureCallbacks[2](captureResult()); wait(1)
  compare(images.length, 1); compare(images[0].width, 60); compare(saves, 0)
  slot.needsPlaceholder = true
  captureWidgetImages(screen, function() {})
  compare(captureCallbacks.length, 3)
  slot.needsPlaceholder = false; vertical = true
  captureWidgetImages(screen, function() {})
  compare(captureCallbacks.length, 3); vertical = false
  moduleSlots = []
 }
 function test_widgetMovesAndSettings() {
  var original = entries(); render(original)
  var slot = widgetStore.get("key0"); slot.state = 99
  compare(born, 24); compare(died, 0)
  for (var i = 0; i < 100; i++) {
   var leftEntries = original.slice().reverse(); leftEntries[23] = {id: "duplicate", powerbarInstance: "key0", format: i}
   layoutConfig = {left: leftEntries.slice(0, 23), center: [], right: [leftEntries[23]]}; reconcileWidgets()
   layoutConfig = {left: original, center: [], right: []}; reconcileWidgets()
  }
  left.vertical = true; left.forceLayout()
  compare(widgetStore.get("key0"), slot); compare(slot.state, 99)
  compare(born, 24); compare(died, 0)
  render(original.concat([{id:"new",powerbarInstance:"new"}]))
  compare(born, 25); compare(died, 0)
  console.log("COST moves=200 existing_created=0 existing_destroyed=0 add_created=1 add_destroyed=0")
 }
 function test_targetAndApiLocality() {
  render(entries()); wait(1)
  var apis = ({})
  for (var i = 0; i < 12; i++) { var api = apiFactory.createObject(root, {pluginId:"plugin"+i}); apis[api.pluginId] = api; apiSync.initialize(api) }
  apiSync.apis = apis; layouts = 0; Counters.reads = 0; observed = 0; observerDied = 0
  var slot = widgetStore.get("key7")
  var target = targetFactory.createObject(slot.presentationItem)
  registerPluginClickTarget("plugin7", target); wait(1)
  compare(Counters.reads, 1); compare(layouts, 0)
  compare(slot.slotTargets.length, 1); compare(apis.plugin7.clickTargets[0], target)
  compare(apis.plugin6.clickTargets.length, 0)
  var reads = Counters.reads
  registerPluginClickTarget("plugin7", target); wait(1); compare(Counters.reads, reads)
  apiSync.popout = target; compare(layouts, 0)
  compare(apis.plugin7.activePopout, target); compare(apis.plugin6.activePopout, apis.plugin6.foreignPopoutMarker)
  unregisterPluginClickTarget("plugin6", target); compare(slot.slotTargets.length, 1)
  console.log("COST one_target_slot_evaluations=" + reads + " unrelated_api_layout_notifications=" + layouts)
  unregisterPluginClickTarget("plugin7", target)
  unregisterPluginClickTarget("plugin7", target); target.destroy()
  apiSync.apis = ({})
  for (var key in apis) apis[key].destroy()
 }
 function test_pendingAndPlaceholderRouting() {
  render(entries())
  var slot = widgetStore.get("key0")
  var target = targetFactory.createObject(root)
  registerClickTarget(target); wait(1); compare(pendingTargets.length, 1)
  target.parent = slot.presentationItem; wait(1)
  compare(pendingTargets.length, 0); compare(slot.slotTargets[0], target)
  var other = widgetStore.get("key1")
  target.parent = other.presentationItem; wait(1)
  compare(slot.slotTargets.length, 0); compare(other.slotTargets[0], target)
  unregisterClickTarget(target); compare(other.slotTargets.length, 0); target.destroy()
  var placeholder = Qt.createQmlObject('import QtQuick; Item { property bool powerbarPlaceholder: true }', slot.presentationItem)
  registerClickTarget(placeholder); compare(pendingTargets.length, 0); compare(slot.slotTargets.length, 0)
  unregisterClickTarget(placeholder); placeholder.destroy()
 }
}
`;
fs.writeFileSync(path.join(dir, 'Counters.js'), '.pragma library\nvar reads = 0\n');
fs.writeFileSync(path.join(dir, 'tst_PowerbarPaths.qml'), qml);
if (emitOnly) console.log(dir);
else try {
 const result = spawnSync('/usr/lib/qt6/bin/qmltestrunner', ['-input', dir, '-o', '-', 'txt'], {
  encoding: 'utf8', env: {...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QPA_PLATFORMTHEME: '', QT_QUICK_CONTROLS_STYLE: 'Basic', QT_QUICK_BACKEND: 'software'}
 });
 process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || '');
 if (result.error) throw result.error;
 process.exitCode = result.status === null ? 1 : result.status;
} finally { fs.rmSync(dir, {recursive: true, force: true}); }
