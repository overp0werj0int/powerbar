import QtQuick
import QtTest
import "../../"
import "../../DragModel.js" as DragModel

// Mirrors Bar.qml's release settle: the drop rebuilds the Repeater, the ghost
// keeps showing and glides into the new slot, which stays hidden until then.
TestCase {
  name: "DragSettle"
  when: windowShown
  width: 400; height: 400

  readonly property real gap: 30 // dragGap minus spacing: max(barSize, icon)
  property var entries: ["a", "b", "c"]
  property bool vertical: false
  property bool settling: false
  property string settleKey: ""
  property var settleItem: null
  property real progress: 0
  property var from: ({ x: 0, y: 0 })
  property var gapAt: ({ key: "", before: false })
  property string draggedKey: ""
  property var landed: null

  NumberAnimation {
    id: settleAnimation
    target: testCase; property: "progress"; from: 0; to: 1; duration: 180
    easing.type: Easing.OutCubic
    onFinished: {
      var target = testCase.settleItem.mapToItem(null, 0, 0)
      testCase.landed = { x: ghost.x - target.x, y: ghost.y - target.y }
      testCase.settling = false; testCase.settleKey = ""; testCase.settleItem = null }
  }
  id: testCase

  Component {
    id: cell
    AnimatedSlot {
      id: slot
      required property var modelData
      readonly property bool settleHidden: testCase.settling && modelData === testCase.settleKey
      readonly property bool gapBefore: testCase.gapAt.key === modelData && testCase.gapAt.before
      readonly property bool dragged: testCase.draggedKey === modelData
      readonly property real extra: settleHidden ? Math.max(0, testCase.gap - 20) : 0
      targetWidth: testCase.vertical ? 24 : dragged ? 0 : 20 + extra + (gapBefore ? testCase.gap + 4 : 0)
      targetHeight: testCase.vertical ? (dragged ? 0 : 20 + extra + (gapBefore ? testCase.gap + 4 : 0)) : 24
      targetInsetX: !testCase.vertical && gapBefore ? testCase.gap + 4 : 0
      targetInsetY: testCase.vertical && gapBefore ? testCase.gap + 4 : 0
      motionDuration: 150; motionEasing: Easing.InOutSine; motionOvershoot: 0
      property alias presentation: icon
      Rectangle {
        id: icon
        x: slot.animatedInsetX; y: slot.animatedInsetY
        width: testCase.vertical ? 24 : 20; height: testCase.vertical ? 20 : 24
        opacity: slot.settleHidden ? 0 : 1
      }
    }
  }
  Row {
    id: row; x: 10; y: 10; spacing: 4; visible: !testCase.vertical
    Repeater { id: rowItems; model: testCase.vertical ? [] : testCase.entries; delegate: cell }
  }
  Column {
    id: column; x: 10; y: 10; spacing: 4; visible: testCase.vertical
    Repeater { id: columnItems; model: testCase.vertical ? testCase.entries : []; delegate: cell }
  }
  Rectangle {
    id: ghost
    readonly property var frame: {
      var to = null
      if (testCase.settleItem) {
        var p = testCase.settleItem.mapToItem(null, 0, 0)
        to = { x: p.x, y: p.y }
      }
      return DragModel.settleFrame(testCase.from, to, testCase.progress, false)
    }
    visible: testCase.settling
    x: frame.x; y: frame.y; width: 20; height: 24
  }

  function slotFor(key) {
    var items = vertical ? columnItems : rowItems
    for (var i = 0; i < items.count; i++) if (items.itemAt(i).modelData === key) return items.itemAt(i)
    return null
  }
  function release(point, nextEntries) {
    from = point
    settleKey = "a"
    progress = 0
    settling = true
    gapAt = { key: "", before: false }
    draggedKey = ""
    if (nextEntries) entries = nextEntries
    Qt.callLater(function() {
      settleItem = slotFor("a").presentation
      settleAnimation.restart()
    })
  }
  function init() {
    settleAnimation.stop()
    settling = false; settleKey = ""; settleItem = null; progress = 0; landed = null
    gapAt = { key: "", before: false }
    draggedKey = ""
    entries = ["a", "b", "c"]
    wait(120)
  }

  function test_reorderGlidesIntoRebuiltSlot() {
    vertical = false
    wait(120)
    // Preview: "a" collapsed away, gap opened before "c".
    draggedKey = "a"
    gapAt = { key: "c", before: true }
    tryCompare(slotFor("a"), "width", 0, 400)
    tryCompare(slotFor("c"), "width", 20 + gap + 4, 400)
    var neighbourBefore = slotFor("c").presentation.mapToItem(null, 0, 0).x
    release({ x: 200, y: 100 }, ["b", "a", "c"])
    verify(testCase.settling, "The ghost must survive the release")
    compare(ghost.x, 200)
    compare(slotFor("a").presentation.opacity, 0)
    wait(20)
    var neighbourAfter = slotFor("c").presentation.mapToItem(null, 0, 0).x
    verify(Math.abs(neighbourAfter - neighbourBefore) < 1, "The neighbour must not step when the layout commits")
    wait(60)
    verify(testCase.settling && ghost.x < 200 && ghost.x > slotFor("a").mapToItem(null, 0, 0).x,
      "The ghost glides toward the new slot")
    compare(slotFor("a").presentation.opacity, 0)
    tryVerify(function() { return !testCase.settling }, 500)
    compare(slotFor("a").presentation.opacity, 1)
    verify(landed && Math.abs(landed.x) < 0.5 && Math.abs(landed.y) < 0.5)
    tryCompare(slotFor("c"), "x", 48, 400)
  }

  function test_verticalGlideEndsOnSlot() {
    vertical = true
    wait(120)
    release({ x: 10, y: 250 }, ["b", "c", "a"])
    compare(ghost.y, 250)
    var lastY = ghost.y
    tryVerify(function() {
      if (!testCase.settling) return true
      verify(ghost.y <= lastY + 0.01, "The glide must be monotonic")
      lastY = ghost.y
      return false
    }, 500)
    verify(landed && Math.abs(landed.x) < 0.5 && Math.abs(landed.y) < 0.5, "The glide ends on the slot")
    compare(slotFor("a").presentation.opacity, 1)
  }

  function test_cancelReturnsToRegrowingSource() {
    vertical = false
    wait(120)
    draggedKey = "a"
    tryCompare(slotFor("a"), "width", 0, 400)
    release({ x: 300, y: 300 }, null)
    tryVerify(function() { return !testCase.settling }, 500)
    verify(landed && Math.abs(landed.x) < 0.5 && Math.abs(landed.y) < 0.5,
      "The ghost follows the source while it regrows")
    compare(slotFor("a").presentation.opacity, 1)
  }
}
