import QtQuick
import QtTest
import "../../"
import "../../CellModel.js" as CellModel

// A zone's drawer (docs/behavior/on-demand-drawers.md) against a bar that
// hands it members: a member is hosted by one of the drawer's rows while the
// drawer shows it (its drawerHost) and back on the bar once it has closed.
// The window's root is a plain Item: a TestCase root receives no mouse events.
Item {
  id: test
  width: 800
  height: 200

  // A widget's slot as the drawer reads it.
  component Member: Item {
    property var drawerHost: null
    property string region: "left"
    property string displayName: ""
    property string instanceKey: displayName
    property bool groupHeader: false
    property bool panelOpen: false
    property bool settleHidden: false
    property bool pictured: false
    property var slotTargets: []
    property var cellPlace: ({ extent: 32, cell: 32, spill: 0 })
    property var ink: ({ start: 4, length: 16, glyph: true, iconStart: 0, iconLength: 0 })
    property real naturalWidth: 24
    property real naturalHeight: 24
    property real inkShift: 4
    property real crossShift: 0
    property real cellLength: 32
    function activate() {}
  }

  // What the drawer reads off the bar.
  QtObject {
    id: bar
    property var members: ({})
    property var managedOwner: null
    property bool vertical: false
    function along(p) { return vertical ? p.y : p.x }
    function alongSize(r) { return vertical ? r.height : r.width }
    property string position: "top"
    property bool animationsEnabled: false
    property bool onDemandMenu: false
    property bool barHidden: false
    property bool barHovered: false
    property bool flat: false
    property bool islands: true
    property real edgeGap: 6
    property var drawerTokens: CellModel.tokens({ bar: 38, spacing: 0 })
    property real islandRounding: 10
    property var islandBorder: null
    property var surfaceEffects: ({ shadow: false, shadowSize: 0, shadowOpacity: 0, blur: false })
    property var notchCorners: ({ shoulder: 0, radius: 0 })
    property color mainSurfaceColor: "black"
    property color overlaySurfaceColor: "black"
    property color barForeground: "white"
    property color highlightHoverColor: "gray"
    property color highlightSelectedColor: "gray"
    property string fontFamily: "sans"
    property var groups: []
    property var activePopout: null
    property var barDragSource: null
    property bool dragMotionActive: false
    property bool dragHandover: false
    property var dragPreview: null
    property real dragGapWidth: 30
    property real dragGapHeight: 30
    property int dragMotionDuration: 150
    property int dragMotionEasing: Easing.OutCubic
    property bool barDragImageLabelled: false
    property bool barDragImageFromCell: false
    property real managedEntrySeconds: 1
    property real managedExitSeconds: 1
    property QtObject barKeys: QtObject {
      property bool here: false
      property var drawer: null
      function heldBy() { return false }
      function pointerOnRow() {}
      function pointerLeft() {}
      function released() {}
      function drawerKey() { return false }
    }
    function managedSlots(zone) { return members[String(zone).split(":")[0]] || [] }
    function groupSlots() { return [] }
    function slotName(slot) { return slot ? slot.displayName : "" }
    function ev() {}
    function textOn(c) { return c }
    function metricsOf() { return { extent: 38, tokens: drawerTokens, thickness: drawerTokens.thickness, highlightRadius: 6 } }
    function edgeSpill() { return 0 }
    function dragSurfaceForDrawer(d) { return "managed:" + d.zone }
    function targetsForSlot(slot) { return slot ? slot.slotTargets : [] }
    function targetWindow() { return null }
    function showTooltip() {}
    function hideTooltip() {}
    // What the drawer's rows hand the bar's drag (Bar.beginIconDrag and on).
    property var drags: []
    property var dragPoint: null
    function updateIconDrag(scenePoint) { dragPoint = scenePoint }
    function beginIconDrag(slot, window, scenePoint, offsetX, offsetY) {
      drags = drags.concat([{ slot: slot, x: scenePoint.x, y: scenePoint.y, offsetX: offsetX, offsetY: offsetY }])
      dragPoint = scenePoint
      return true
    }
    function releaseIconDrag(scenePoint, slot, after) { if (after) after() }
    function clearBarDrag() {}
  }

  Item {
    id: host
    width: 800
    height: 200
    property real drawerExtent: 150
    property bool notchLook: false
    property real notchOvershoot: 0
    property var foldHandles: []
    property var zoneIslands: ({})
    property var screen: null
    property var managedSubmenu: null
    property Item contentItem: host
    Member { id: a; displayName: "a" }
    Member { id: b; displayName: "b" }
    Member { id: c; displayName: "c"; region: "right" }
    ManagedDrawer { id: drawer; bar: bar; hostWindow: host }
  }

  TestCase {
  name: "ManagedDrawer"
  when: windowShown

  function init() {
    bar.onDemandMenu = false
    bar.vertical = false
    bar.position = "top"
    bar.drags = []
    bar.dragPoint = null
    bar.members = { left: [a, b], right: [c] }
    drawer.close("immediate")
    drawer.reveal = 0
  }
  // A failed check leaves its test mid-drag: end the drag before the next.
  function cleanup() {
    if (!drawer.dragMount) return
    mouseRelease(drawer.dragMount)
    drawer.releaseDrag(drawer.dragMount)
  }

  function test_membersAreHostedOnlyWhileTheDrawerShows() {
    compare(a.drawerHost, null, "on the bar before any open")
    drawer.openZone("left", false)
    verify(a.drawerHost !== null, "a row hosts the member while the drawer shows")
    verify(b.drawerHost !== null)
    verify(a.drawerHost !== b.drawerHost, "one row per member")
    compare(c.drawerHost, null, "another zone's member stays on the bar")
    compare(drawer.cellAt(0), a.drawerHost, "rows in the members' order")
    compare(drawer.cellAt(1), b.drawerHost)
    drawer.close("immediate")
    compare(a.drawerHost, null, "back on the bar once closed")
    compare(b.drawerHost, null)
  }

  function test_switchingZonesHandsMembersOver() {
    drawer.openZone("left", false)
    drawer.openZone("right", false)
    compare(a.drawerHost, null, "the left zone's members go back to the bar")
    verify(c.drawerHost !== null)
    compare(drawer.cellAt(0), c.drawerHost)
  }

  function test_aMemberLeavingTheZoneGoesBackToTheBar() {
    drawer.openZone("left", false)
    bar.members = { left: [b], right: [c] }
    compare(a.drawerHost, null)
    verify(b.drawerHost !== null)
    compare(drawer.cellAt(0), b.drawerHost)
  }

  // A row is built once per member, not on every open: opening only hosts
  // the members in the rows they had.
  function test_reopeningKeepsTheRows() {
    drawer.openZone("left", false)
    var rowA = a.drawerHost, rowB = b.drawerHost
    drawer.close("immediate")
    drawer.openZone("left", false)
    compare(a.drawerHost, rowA, "the same row after a close")
    compare(b.drawerHost, rowB)
    drawer.openZone("right", false)
    var rowC = c.drawerHost
    drawer.openZone("left", false)
    compare(a.drawerHost, rowA, "the same row after another zone's drawer")
    compare(drawer.cellAt(0), rowA)
    drawer.openZone("right", false)
    compare(c.drawerHost, rowC)
  }

  function test_aNewMemberGetsItsOwnRow() {
    drawer.openZone("left", false)
    var rowA = a.drawerHost
    var d = memberFactory.createObject(host, { displayName: "d" })
    bar.members = { left: [d, a, b], right: [c] }
    verify(d.drawerHost !== null && d.drawerHost !== rowA)
    compare(drawer.cellAt(0), d.drawerHost, "in its place among the rows")
    compare(drawer.cellAt(1), rowA)
    bar.members = { left: [a, b], right: [c] }
    d.destroy()
    wait(0)
    drawer.close("immediate")
    drawer.openZone("left", false)
    compare(drawer.cellAt(0), rowA)
    compare(drawer.cellAt(2), null, "a gone member leaves no row")
  }
  Component { id: memberFactory; Member {} }

  function test_aDragKeepsTheRowsUntilItEnds() {
    drawer.openZone("left", false)
    var row = a.drawerHost
    drawer.dragMount = row
    bar.members = { left: [b], right: [c] }
    compare(a.drawerHost, row, "the dragged row stays while the drag runs")
    drawer.releaseDrag(row)
    compare(a.drawerHost, null, "the drawer catches up once the drag ends")
    verify(b.drawerHost !== null)
  }

  // A menu row's drag (DRAG-3): the bar draws the dragged icon at the
  // pointer less the grab offset, so the offset is where the button went
  // down on the row, not where the pointer had got to when the drag began;
  // and the drop follows the pointer itself.
  function test_aMenuRowDragHoldsThePressedSpotUnderThePointer_data() {
    return [{ tag: "top bar", vertical: false, position: "top" }, { tag: "left bar", vertical: true, position: "left" }]
  }
  function test_aMenuRowDragHoldsThePressedSpotUnderThePointer(data) {
    bar.vertical = data.vertical
    bar.position = data.position
    bar.onDemandMenu = true
    drawer.openZone("left", false)
    verify(drawer.namedMenu, "the zone opens as a menu")
    var row = b.drawerHost
    // Wait for the menu's rows to be laid out and the drawer to be shown.
    tryVerify(function() { return drawer.reveal === 1 && row.parent.height >= 2 * row.height })
    var px = Math.round(row.width / 3), py = Math.round(row.height / 2)
    mousePress(row, px, py)
    for (var i = 1; i <= 25; i++) mouseMove(row, px + i, py + 2 * i, 5, Qt.LeftButton)
    compare(bar.drags.length, 1, "one drag")
    var drag = bar.drags[0]
    compare(drag.slot, b)
    var pressed = row.mapToItem(null, px, py)
    var began = row.mapToItem(null, 0, 0)
    verify(drag.x - pressed.x + Math.abs(drag.y - pressed.y) > 0, "the drag begins past the press")
    fuzzyCompare(drag.offsetX, px, 0.5, "the icon keeps the pressed spot under the pointer, across")
    fuzzyCompare(drag.offsetY, py, 0.5, "and along the menu")
    fuzzyCompare(drag.x - drag.offsetX, began.x + (drag.x - pressed.x), 0.5, "the icon moved as far as the pointer")
    var pointer = row.mapToItem(null, px + 25, py + 50)
    fuzzyCompare(bar.dragPoint.x, pointer.x, 0.5, "the drop follows the pointer")
    fuzzyCompare(bar.dragPoint.y, pointer.y, 0.5)
  }
}
}
