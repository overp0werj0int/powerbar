import QtQuick
import QtTest
import Powerbar
import "../../BarModel.js" as BarModel
import "../../PreferencesModel.js" as Model
import "../../GroupsModel.js" as GroupsModel
import "../../AppearanceModel.js" as AppearanceModel

// Every Preferences page builds against a bar and a Preferences that hand it
// a small layout, with no warning from its own bindings; the Layout and
// Groups boards pick up, carry and drop by keys and by pointer, and write
// what they did before (docs/behavior/preferences.md PREFS-27, 117, 119).
TestCase {
  id: test
  name: "PreferencesPages"
  when: windowShown
  visible: true
  width: 1400
  height: 900

  // What the pages asked Preferences and the bar to write, in order.
  property var calls: []

  QtObject {
    id: fakeBar
    readonly property var barConfig: ({
      layout: {
        left: [{ id: "omarchy.workspaces", powerbarInstance: "w1" }, { id: "omarchy.clock", powerbarInstance: "c1", powerbarVisibility: "managed" }],
        center: [{ id: "omarchy.clock", powerbarInstance: "c2" }],
        right: [{ id: "omarchy.battery", powerbarInstance: "b1", powerbarVisibility: "hidden" }]
      },
      powerbarGroups: [{ id: "g1", label: "System", icon: "", section: "right", visibility: "shown", items: ["b1"] }, { id: "g2", label: "Time", icon: "", section: "left", visibility: "shown", items: ["c1"] }]
    })
    property bool vertical: false
    property string position: "top"
    property bool animationsEnabled: false
    property bool autoHide: false
    property bool autoHideActivity: true
    property bool onDemandInline: false
    property bool onDemandMenu: false
    property bool legacyVisibility: false
    property bool largeBar: false
    property bool glassy: false
    property bool requestedTransparent: false
    property string barStyle: "flat"
    property string notchStyle: ""
    property string spacingMode: "even"
    property string foregroundChoice: ""
    property string fontFamily: "Sans Serif"
    property real widgetSpacing: 4
    property real sizeHorizontal: 30
    property real roundingMax: 12
    property var screenNotch: null
    property var groups: GroupsModel.groups(barConfig)
    property var widgetFaces: ({})
    property var zoneFitReports: ({})
    property var barOptions: BarModel.options(barConfig)
    property var surfaceEffects: ({ shadow: false, shadowSize: 0, shadowOpacity: 0, blur: false, readableOverlay: true })
    property bool systemMotion: true
    property var themeIslandBorder: null
    property color barForeground: "white"
    property color mainSurfaceColor: "black"
    property var barWidgetRegistry: null
    function notchFor(screen, edge) { return null }
    function barSizeFor(screen) { return 30 }
    function colorHex(c) { return "#000000" }
    function findPanelWidget(id) { return null }
    function quietActivityId(id) { return "" }
    function activityPeeksFor(key, id) { return false }
    function setActivityPeek(key, on) {}
    function assignGroup(key, group, before) { test.calls.push(["assignGroup", key, group, before]) }
    function groupFor(key) { return groups.find(function (g) { return g.items.indexOf(key) >= 0 }) || null }
    // The groups an edit leaves, as id:label@zone.
    function editGroups(fn) {
      var config = { bar: JSON.parse(JSON.stringify(barConfig)) };
      fn(config);
      test.calls.push(["editGroups", GroupsModel.groups(config.bar).map(function (g) { return g.id + ":" + g.label + "@" + g.section }).join(" ")]);
    }
    function editMemberBadge(key, on) {}
  }

  Item {
    id: prefs
    anchors.fill: parent
    property var bar: fakeBar
    property bool opened: true
    property int page: 0
    property var targetScreen: null
    readonly property Item sheet: prefs
    property var snapshots: ({})
    readonly property var config: fakeBar.barConfig
    readonly property var options: BarModel.options(config)
    readonly property var entries: Model.records(config.layout, function () { return null }, false)
    readonly property var layoutEntries: entries
    readonly property var trayEntries: []
    readonly property QtObject shortcuts: QtObject {
      property bool ready: true
      property bool busy: false
      property string error: ""
      function info(target) { return { keys: "", source: "none", fallback: "", positional: "" } }
      function suggested(target) { return "" }
    }
    readonly property var motion: ({})
    readonly property var ranges: AppearanceModel.ranges
    property bool notchMode: false
    function md(text) { return text }
    function title(record) { return record ? record.id : "" }
    function icon(record) { return "x" }
    function iconFont(record) { return "Sans Serif" }
    function cachedImageUrl(record) { return "" }
    function readGlyph(record) { return "" }
    function move(record, section, mode, before, passed) { test.calls.push(["move", record.instanceKey, section, mode, before]) }
    function takeFromTray(record, section, mode, before) { test.calls.push(["takeFromTray", record.instanceKey, section, mode, before]); return "" }
    function returnToTray(record) { test.calls.push(["returnToTray", record.instanceKey]) }
    function openGroup(id) {}
    function setOption(key, value) {}
    function clearOptions(keys) {}
    function lookValue(key) { return undefined }
    function scopeHint(key) { return "" }
    function scopeOf(key) { return "" }
    function setScope(key, scope) {}
    function setBarStyle(style) {}
    function setLook(key, value) {}
    function setText(key, value) {}
  }

  // The Layout page outlives the others, as in Preferences: they read its
  // geometry and camera. Built in the first test, under failOnWarning.
  Loader {
    id: layoutLoader
    anchors.fill: prefs
    active: false
    sourceComponent: Component {
      LayoutEditor { preferences: prefs }
    }
  }
  readonly property var layoutEditor: layoutLoader.item
  Component {
    id: groupsPage
    GroupsEditor { anchors.fill: prefs; preferences: prefs; layout: test.layoutEditor }
  }
  Component {
    id: lookPage
    LookEditor { anchors.fill: prefs; preferences: prefs; layout: test.layoutEditor }
  }
  Component {
    id: behaviorPage
    BehaviorEditor { anchors.fill: prefs; preferences: prefs; layout: test.layoutEditor }
  }
  Component {
    id: tuningPage
    TuningEditor { anchors.fill: prefs; preferences: prefs; layout: test.layoutEditor }
  }

  // A widget's chip on a board: the item drawing that record in its layer
  // (not a picture of it, a drag's copy or a landing place).
  function chipOf(root, key) {
    var kids = root.children;
    for (var i = 0; i < kids.length; i++) {
      var k = kids[i];
      if (k.visible && k.placeholder === false && k.ghost === false && k.pulled !== true && k.record && k.record.instanceKey === key && k.width > 0)
        return k;
      var found = chipOf(k, key);
      if (found)
        return found;
    }
    return null;
  }
  function centre(item) {
    return item.mapToItem(test, item.width / 2, item.height / 2);
  }
  function drag(from, to) {
    mousePress(test, from.x, from.y);
    mouseMove(test, from.x + 10, from.y + 2);
    mouseMove(test, (from.x + to.x) / 2, (from.y + to.y) / 2);
    mouseMove(test, to.x, to.y);
  }

  function init() {
    failOnWarning(/./);
    layoutLoader.active = true;
    calls = [];
  }
  function cleanup() {
    if (layoutEditor && layoutEditor.lifted)
      layoutEditor.cancel();
  }

  function test_layoutPage() {
    verify(layoutEditor.width > 0, "the Layout page builds");
    compare(layoutEditor.rows.length, 4, "a layer per visibility and the tray");
  }
  function test_pages_data() {
    return [{ tag: "Groups", page: groupsPage }, { tag: "Look", page: lookPage }, { tag: "Behavior", page: behaviorPage }, { tag: "Tuning", page: tuningPage }];
  }
  function test_pages(data) {
    var page = createTemporaryObject(data.page, prefs);
    verify(page, data.tag + " builds");
    wait(50);
  }

  // Layout: keys on the first layer (PREFS-27).
  function layoutKeys() {
    var page = layoutEditor;
    page.place({ section: "left", mode: "shown", pos: 0 });
    page.focusFirst();
    tryVerify(function () { return page.gridFocused }, 1000, "the layers take the keys");
    return page;
  }
  function test_layoutKeyLiftStepDrop() {
    var page = layoutKeys();
    keyClick(Qt.Key_Space);
    compare(page.lifted.instanceKey, "w1", "space lifts the cursor's chip");
    keyClick(Qt.Key_L);
    compare(page.liftTarget.section, "centerBegin", "l carries it to the next zone");
    keyClick(Qt.Key_Space);
    compare(page.lifted, null, "space drops it");
    compare(JSON.stringify(calls), JSON.stringify([["move", "w1", "centerBegin", "shown", -1]]));
    compare(page.cursorKey, "w1", "the cursor stays on it");
  }
  function test_layoutKeyCarry() {
    var page = layoutKeys();
    keyClick(Qt.Key_L, Qt.ShiftModifier);
    compare(JSON.stringify(calls), JSON.stringify([["move", "w1", "centerBegin", "shown", -1]]), "shift+l moves it at once");
    calls = [];
    layoutKeys();
    keyClick(Qt.Key_J, Qt.ShiftModifier);
    compare(JSON.stringify(calls), JSON.stringify([["move", "w1", "left", "managed", 1]]), "shift+j takes it to the next layer");
  }
  function test_layoutKeyCancel() {
    var page = layoutKeys();
    keyClick(Qt.Key_Space);
    keyClick(Qt.Key_L);
    keyClick(Qt.Key_Escape);
    compare(page.lifted, null, "esc puts it back");
    compare(calls.length, 0, "nothing is written");
    compare(page.cursorCell.section, "left");
    compare(page.cursorKey, "w1");
  }
  function test_layoutKeyHideAndInspect() {
    var page = layoutKeys();
    keyClick(Qt.Key_X);
    compare(JSON.stringify(calls), JSON.stringify([["move", "w1", "left", "hidden", 1]]), "x sends it to the hidden layer");
    keyClick(Qt.Key_Return);
    verify(page.inspecting, "enter pulls it forward");
    tryVerify(function () { return page.inspectorFocused }, 1000, "the inspector takes the keys");
    keyClick(Qt.Key_Escape);
    verify(!page.inspecting, "esc pushes it back");
  }

  // Layout: the pointer (PREFS-27).
  function test_layoutDrag() {
    var page = layoutEditor;
    var from = centre(chipOf(page, "w1")), to = centre(chipOf(page, "c2"));
    drag(from, to);
    verify(page.pointerLift, "a drag past the threshold lifts the chip");
    compare(page.liftTarget.section, "center");
    mouseRelease(test, to.x, to.y);
    compare(page.lifted, null, "the release drops it");
    compare(calls.length, 1);
    compare(calls[0][0], "move");
    compare(calls[0][1], "w1");
    compare(calls[0][2], "center");
    compare(calls[0][3], "shown");
  }
  function test_layoutDragSpentByEsc() {
    var page = layoutEditor;
    var from = centre(chipOf(page, "w1")), to = centre(chipOf(page, "c2"));
    drag(from, to);
    verify(page.pointerLift);
    keyClick(Qt.Key_Escape);
    compare(page.lifted, null, "esc cancels the drag");
    mouseMove(test, to.x + 20, to.y);
    verify(!page.lifted, "the spent press lifts nothing");
    mouseRelease(test, to.x + 20, to.y);
    compare(calls.length, 0, "nothing is written");
  }
  function test_layoutClickInspects() {
    var page = layoutEditor;
    var at = centre(chipOf(page, "c2"));
    mouseClick(test, at.x, at.y);
    compare(page.cursorKey, "c2", "a click puts the cursor on the chip");
    verify(page.inspecting, "and pulls it forward");
    page.pushBack();
  }

  // Groups: the keys and the pointer (PREFS-117, PREFS-119).
  function groupsKeys() {
    var page = createTemporaryObject(groupsPage, prefs);
    page.place({ area: "pool", pos: 0 });
    page.focusFirst();
    tryVerify(function () { return page.stageFocused }, 1000, "the stage takes the keys");
    return page;
  }
  function itemWith(root, test) {
    var kids = root.children;
    for (var i = 0; i < kids.length; i++) {
      if (kids[i].visible && test(kids[i]))
        return kids[i];
      var found = itemWith(kids[i], test);
      if (found)
        return found;
    }
    return null;
  }
  function test_groupsKeyLiftStepDrop() {
    var page = groupsKeys();
    compare(page.cursorRecord.instanceKey, "w1");
    keyClick(Qt.Key_Space);
    compare(page.lifted.key, "w1", "space lifts the pool's widget");
    keyClick(Qt.Key_K);
    compare(JSON.stringify(page.liftTarget), JSON.stringify({ area: "gap", id: "g2", pos: 1 }), "k carries it into the group above");
    keyClick(Qt.Key_K);
    compare(JSON.stringify(page.liftTarget), JSON.stringify({ area: "gap", id: "g2", pos: 0 }));
    keyClick(Qt.Key_Space);
    compare(page.lifted, null, "space drops it");
    compare(JSON.stringify(calls), JSON.stringify([["assignGroup", "w1", "g2", "c1"]]));
  }
  function test_groupsKeyCancel() {
    var page = groupsKeys();
    keyClick(Qt.Key_Space);
    keyClick(Qt.Key_K);
    keyClick(Qt.Key_Escape);
    compare(page.lifted, null, "esc puts it back");
    compare(calls.length, 0, "nothing is written");
    compare(JSON.stringify(page.at), JSON.stringify({ area: "pool", pos: 0 }));
  }
  function test_groupsDrag() {
    var page = createTemporaryObject(groupsPage, prefs);
    wait(50);
    var from = centre(chipOf(page, "w1")), to = centre(chipOf(page, "b1"));
    drag(from, to);
    verify(page.pointerLift, "a drag past the threshold lifts the widget");
    compare(page.liftTarget.area, "gap");
    compare(page.liftTarget.id, "g1");
    mouseRelease(test, to.x, to.y);
    compare(page.lifted, null, "the release drops it");
    compare(calls.length, 1);
    compare(calls[0][0], "assignGroup");
    compare(calls[0][1], "w1");
    compare(calls[0][2], "g1");
  }
  // A name typed for one group stays with it when a click selects another
  // before the field finishes (the fix in a37aa7f).
  function test_groupsNameTypedThenClick() {
    var page = createTemporaryObject(groupsPage, prefs);
    page.selectedId = "g1";
    wait(50);
    var field = itemWith(page, function (k) { return k.placeholderText === "Group name" });
    verify(field, "the inspector has the name field");
    var at = centre(field);
    mouseClick(test, at.x, at.y);
    tryVerify(function () { return field.activeFocus }, 1000);
    field.selectAll();
    keyClick("N");
    keyClick("e");
    keyClick("t");
    var other = centre(chipOf(page, "c1"));
    mouseClick(test, other.x, other.y);
    compare(page.selectedId, "g2", "the click selects the other group");
    compare(JSON.stringify(calls), JSON.stringify([["editGroups", "g1:Net@right g2:Time@left"]]), "the name goes to the group it was typed for");
  }
}
