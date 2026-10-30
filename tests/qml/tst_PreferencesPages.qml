import QtQuick
import QtTest
import Powerbar
import qs.Commons
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
    function editMemberBadge(key, prop, text) { test.calls.push(["editMemberBadge", key, prop, text]) }
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
  // geometry and camera. Built in the first test, under failOnWarning. Behind
  // them, so its plates do not take their pointer.
  Loader {
    id: layoutLoader
    z: -1
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

  function test_groupsBadgeFieldTypedThenClick_data() {
    return [{ tag: "count", hint: "Count from: detected", prop: "badgeProperty" }, { tag: "urgent", hint: "Urgent from: detected", prop: "urgentProperty" }];
  }
  // The same rule for the badge fields: typed for the widget the cursor was
  // on, kept when a click moves the cursor to another before they finish.
  function test_groupsBadgeFieldTypedThenClick(data) {
    var page = createTemporaryObject(groupsPage, prefs);
    page.selectedId = "g2";
    wait(50);
    page.place({ area: "member", id: "g2", pos: 0 });
    compare(page.member.instanceKey, "c1");
    wait(50);
    var field = itemWith(page, function (k) { return k.placeholderText === data.hint });
    verify(field, "the inspector has the field for the cursor's widget");
    var at = centre(field);
    mouseClick(test, at.x, at.y);
    tryVerify(function () { return field.activeFocus }, 1000);
    keyClick("n");
    var other = centre(chipOf(page, "b1"));
    mouseClick(test, other.x, other.y);
    compare(page.selectedId, "g1", "the click selects the other group");
    compare(JSON.stringify(calls), JSON.stringify([["editMemberBadge", "c1", data.prop, "n"]]), "the text goes to the widget it was typed for");
  }

  // What both boards share, pinned on each page (PREFS-100, PREFS-104,
  // PREFS-26): the name tip, the raised cursor chip, the dragged copy, the
  // inspector's Tab fences.
  // The Groups page once its first-group choice has run, so a place set now stays.
  function settledGroups() {
    var page = createTemporaryObject(groupsPage, prefs);
    wait(50);
    return page;
  }
  function chipNamed(page, key) {
    return itemWith(page, function (k) { return k.ghost === true && k.record && k.record.instanceKey === key });
  }
  // The band a dragged copy casts under itself.
  function bandUnder(chip) {
    return itemWith(chip, function (k) { return k.x === 0.5 && k.y === chip.height });
  }
  // Whether the tip at depth `z` shows `title`.
  function tipShows(page, z, title) {
    return !!itemWith(page, function (k) { return k.z === z && !!itemWith(k, function (t) { return t.text === title }) });
  }
  function tabWalk(page) {
    var first = page.focused, seen = [first];
    for (var i = 0; i < 30; i++) {
      keyClick(Qt.Key_Tab);
      verify(page.inspectorFocused, "Tab stays inside the inspector");
      if (page.focused === first)
        return seen;
      seen.push(page.focused);
    }
    fail("Tab never wrapped to the first control");
    return seen;
  }

  function test_layoutOffBoardReleaseDropsAtLastTarget() {
    var page = layoutEditor;
    var from = centre(chipOf(page, "w1")), to = centre(chipOf(page, "c2"));
    drag(from, to);
    compare(page.liftTarget.section, "center");
    mouseMove(test, 3, 3);
    compare(page.liftTarget.section, "center", "off the layers the last target stays");
    mouseRelease(test, 3, 3);
    compare(page.lifted, null);
    compare(calls.length, 1, "the release drops it there");
    compare(calls[0][2], "center");
  }
  function test_groupsOffBoardReleasePutsItBack() {
    var page = createTemporaryObject(groupsPage, prefs);
    wait(50);
    var from = centre(chipOf(page, "w1")), to = centre(chipOf(page, "b1"));
    drag(from, to);
    compare(page.liftTarget.area, "gap");
    mouseMove(test, 3, 3);
    compare(page.liftTarget, null, "off the plates the target is cleared");
    mouseRelease(test, 3, 3);
    compare(page.lifted, null);
    compare(calls.length, 0, "nothing is written");
    compare(page.cursorKey, "pool:w1", "the widget is back");
  }
  function test_groupsDragSpentByEsc() {
    var page = createTemporaryObject(groupsPage, prefs);
    wait(50);
    var from = centre(chipOf(page, "w1")), to = centre(chipOf(page, "b1"));
    drag(from, to);
    verify(page.pointerLift);
    keyClick(Qt.Key_Escape);
    compare(page.lifted, null, "esc cancels the drag");
    mouseMove(test, to.x + 20, to.y);
    verify(!page.lifted, "the spent press lifts nothing");
    mouseRelease(test, to.x + 20, to.y);
    compare(calls.length, 0, "nothing is written");
  }
  function test_groupsPlusMakesAGroup() {
    var page = createTemporaryObject(groupsPage, prefs);
    wait(50);
    var tile = itemWith(page, function (k) { return k.zone === "right" && !!k.plus });
    verify(tile, "the right zone has a tile");
    var plus = tile.plus;
    var at = centre(plus);
    mouseClick(test, at.x, at.y);
    wait(50);
    compare(calls.length, 1);
    compare(calls[0][0], "editGroups");
    verify(/:New group@right/.test(calls[0][1]), "a new group in the plus's zone");
  }
  function test_groupsCarryRefusedOntoPlus() {
    var page = settledGroups();
    page.place({ area: "member", id: "g2", pos: 0 });
    page.focusFirst();
    tryVerify(function () { return page.stageFocused }, 1000);
    var before = JSON.stringify(page.at);
    keyClick(Qt.Key_J, Qt.ShiftModifier);
    compare(page.lifted, null, "nothing stays lifted");
    compare(calls.length, 0, "nothing is written");
    compare(JSON.stringify(page.at), before, "the cursor stays");
  }
  function test_groupsCarryRefusedOntoPool() {
    var page = settledGroups();
    page.place({ area: "pool", pos: 0 });
    page.focusFirst();
    tryVerify(function () { return page.stageFocused }, 1000);
    keyClick(Qt.Key_J, Qt.ShiftModifier);
    compare(page.lifted, null, "nothing stays lifted");
    compare(calls.length, 0, "nothing is written");
    compare(JSON.stringify(page.at), JSON.stringify({ area: "pool", pos: 0 }), "the cursor stays");
  }
  function test_groupsKeyLiftShowsTheCopy() {
    var page = groupsKeys();
    keyClick(Qt.Key_Space);
    tryVerify(function () { return page.copyShown }, 1000, "the lifted widget's copy shows over its landing place");
    verify(chipNamed(page, "w1"), "a flying copy of the widget");
    keyClick(Qt.Key_Escape);
  }

  function test_layoutCursorChipIsRaised() {
    var page = layoutKeys();
    verify(chipOf(page, "w1").raised, "the cursor's chip rises");
    verify(!chipOf(page, "c2").raised, "the others stay down");
  }
  function test_groupsCursorChipIsRaised() {
    var page = groupsKeys();
    verify(chipOf(page, "w1").raised, "the cursor's chip rises");
    verify(!chipOf(page, "c2").raised, "the others stay down");
  }
  function test_ghostBand() {
    var page = layoutEditor;
    drag(centre(chipOf(page, "w1")), centre(chipOf(page, "c2")));
    var ghost = chipNamed(page, "w1");
    verify(ghost, "Layout draws the dragged copy");
    verify(!bandUnder(ghost), "Layout's copy casts no band");
    mouseRelease(test, 0, 0);
    var groups = createTemporaryObject(groupsPage, prefs);
    wait(50);
    drag(centre(chipOf(groups, "w1")), centre(chipOf(groups, "b1")));
    ghost = chipNamed(groups, "w1");
    verify(ghost, "Groups draws the dragged copy");
    verify(bandUnder(ghost), "Groups' copy casts its band");
    mouseRelease(test, 0, 0);
  }

  function test_layoutNameTip() {
    var page = layoutKeys();
    wait(700);
    var a = centre(chipOf(page, "w1")), b = centre(chipOf(page, "c2"));
    mouseMove(test, a.x, a.y);
    verify(!tipShows(page, 110, "omarchy.workspaces"), "not at once");
    tryVerify(function () { return tipShows(page, 110, "omarchy.workspaces") }, 2000, "after a rest on the chip");
    mouseMove(test, b.x, b.y);
    verify(tipShows(page, 110, "omarchy.clock"), "the next chip shows it at once");
    mouseMove(test, a.x, a.y);
    verify(tipShows(page, 110, "omarchy.workspaces"));
    keyClick(Qt.Key_Space);
    verify(page.lifted, "a lift");
    verify(!tipShows(page, 110, "omarchy.workspaces"), "hides the tip");
    keyClick(Qt.Key_Escape);
  }
  function test_groupsNameTip() {
    var page = groupsKeys();
    var a = centre(chipOf(page, "w1")), b = centre(chipOf(page, "c2"));
    mouseMove(test, a.x, a.y);
    verify(!tipShows(page, 130, "omarchy.workspaces"), "not at once");
    tryVerify(function () { return tipShows(page, 130, "omarchy.workspaces") }, 2000, "after a rest on the chip");
    mouseMove(test, b.x, b.y);
    verify(tipShows(page, 130, "omarchy.clock"), "the next chip shows it at once");
    mouseMove(test, a.x, a.y);
    verify(tipShows(page, 130, "omarchy.workspaces"));
    keyClick(Qt.Key_Space);
    verify(page.lifted, "a lift");
    verify(!tipShows(page, 130, "omarchy.workspaces"), "hides the tip");
    keyClick(Qt.Key_Escape);
  }

  // The tip at depth `z`, once shown.
  function tipAt(page, z) {
    return itemWith(page, function (k) { return k.z === z && k.shown === true });
  }
  // Layout places the tip once, as it shows, under the chip. A longer name
  // afterwards does not move it.
  function test_layoutNameTipIsPlacedOnce() {
    var page = layoutKeys();
    wait(700);
    var chip = chipOf(page, "c2"), a = centre(chip);
    mouseMove(test, a.x, a.y);
    tryVerify(function () { return !!tipAt(page, 110) }, 2000, "after a rest on the chip");
    var tip = tipAt(page, 110), below = chip.mapToItem(page, chip.width / 2, chip.height);
    fuzzyCompare(tip.y, below.y + Style.space(6), 0.01, "under the chip");
    var x = tip.x, width = tip.width, record = tip.record;
    tip.record = { instanceKey: "x", id: "a.very.long.widget.identifier.for.the.tip" };
    tryVerify(function () { return tip.width > width }, 1000, "the longer name widens it");
    compare(tip.x, x, "it stays where it showed");
    tip.record = record;
    keyClick(Qt.Key_Space);
    keyClick(Qt.Key_Escape);
  }
  // Groups keeps its tip placed from its size, under the pointer.
  function test_groupsNameTipFollowsItsSize() {
    var page = groupsKeys();
    var a = centre(chipOf(page, "c2"));
    mouseMove(test, a.x, a.y);
    tryVerify(function () { return !!tipAt(page, 130) }, 2000, "after a rest on the chip");
    var tip = tipAt(page, 130), p = page.pointer;
    fuzzyCompare(tip.y, p.y + Style.space(26), 0.01, "under the pointer");
    fuzzyCompare(tip.x, Math.max(0, Math.min(page.width - tip.width, p.x - tip.width / 2)), 0.01, "centred on it");
    var x = tip.x;
    tip.title = "a much longer name than the widget's own";
    tryVerify(function () { return tip.x !== x }, 1000, "a longer name moves it");
    fuzzyCompare(tip.x, Math.max(0, Math.min(page.width - tip.width, p.x - tip.width / 2)), 0.01, "still centred");
    keyClick(Qt.Key_Space);
    keyClick(Qt.Key_Escape);
  }

  function test_layoutInspectorTabWraps() {
    var page = layoutKeys();
    keyClick(Qt.Key_Return);
    tryVerify(function () { return page.inspectorFocused }, 1000, "the inspector takes the keys");
    var seen = tabWalk(page);
    verify(seen.length > 1, "the inspector has controls");
    keyClick(Qt.Key_Tab, Qt.ShiftModifier);
    verify(page.inspectorFocused);
    compare(page.focused, seen[seen.length - 1], "Shift+Tab from the first goes to the last");
    page.pushBack();
  }
  function test_groupsInspectorTabWrapsAndEscReturns() {
    var page = createTemporaryObject(groupsPage, prefs);
    page.selectedId = "g1";
    wait(50);
    page.place({ area: "face", id: "g1" });
    page.focusFirst();
    tryVerify(function () { return page.stageFocused }, 1000);
    keyClick(Qt.Key_Return);
    tryVerify(function () { return page.inspectorFocused }, 1000, "enter on a face takes the name field");
    var seen = tabWalk(page);
    verify(seen.length > 1, "the inspector has controls");
    keyClick(Qt.Key_Tab, Qt.ShiftModifier);
    verify(page.inspectorFocused);
    compare(page.focused, seen[seen.length - 1], "Shift+Tab from the first goes to the last");
    keyClick(Qt.Key_Tab);
    keyClick(Qt.Key_Escape);
    verify(page.stageFocused, "esc goes back to the chosen face");
    verify(!page.inspectorFocused);
  }

  // A landing place shows what it carries at half strength for a keyboard
  // lift, and nothing inside for a pointer lift (the copy is under the pointer).
  function landingContent(page) {
    var place = itemWith(page, function (k) { return k.placeholder === true && k.ghost === false && k.width > 0 });
    verify(place, "the landing place is drawn");
    return place.children.filter(function (c) { return c.spacing !== undefined })[0];
  }
  function test_layoutLandingPlaceContent() {
    var page = layoutKeys();
    keyClick(Qt.Key_Space);
    compare(landingContent(page).opacity, 0.5, "a keyboard lift shows its content");
    keyClick(Qt.Key_Escape);
    drag(centre(chipOf(page, "w1")), centre(chipOf(page, "c2")));
    verify(page.pointerLift);
    compare(landingContent(page).opacity, 0, "a pointer lift shows nothing inside");
    mouseRelease(test, 0, 0);
    mouseMove(test, 1300, 800);
  }
  function test_groupsLandingPlaceContent() {
    var page = groupsKeys();
    keyClick(Qt.Key_Space);
    compare(landingContent(page).opacity, 0.5, "a keyboard lift shows its content");
    keyClick(Qt.Key_Escape);
    drag(centre(chipOf(page, "w1")), centre(chipOf(page, "b1")));
    verify(page.pointerLift);
    compare(landingContent(page).opacity, 0, "a pointer lift shows nothing inside");
    mouseRelease(test, 0, 0);
    mouseMove(test, 1300, 800);
  }
}
