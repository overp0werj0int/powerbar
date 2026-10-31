import QtQuick
import QtTest
import "../../"
import "../../CellModel.js" as CellModel

// A zone's drawer (docs/behavior/on-demand-drawers.md) against a bar that
// hands it members: a member is hosted by one of the drawer's rows while the
// drawer shows it (its drawerHost) and back on the bar once it has closed.
TestCase {
  id: test
  name: "ManagedDrawer"
  when: windowShown
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
    function updateIconDrag() {}
    function beginIconDrag() { return true }
    function finishIconDrag() {}
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

  function init() {
    bar.members = { left: [a, b], right: [c] }
    drawer.close("immediate")
    drawer.reveal = 0
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
}
