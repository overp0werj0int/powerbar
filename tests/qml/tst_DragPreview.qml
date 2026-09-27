import QtQuick
import QtTest
import "../../"
import "../../DragModel.js" as DragModel

TestCase {
  name: "DragPreview"
  when: windowShown
  property var preview: ({ ready: false, sourceKey: "one", sourceSurface: "bar:left",
    targetKey: "two", targetSurface: "bar:right", after: false })
  property var emptyPreview: ({ ready: false, sourceKey: "one", sourceSurface: "bar:right",
    targetKey: "", targetSurface: "bar:left", after: false })
  Row {
    id: destination
    AnimatedSlot {
      id: target
      readonly property var decision: DragModel.slot(preview, "two", "bar:right")
      targetWidth: 20 + (decision.before || decision.after ? 24 : 0)
      targetHeight: 24
      motionDuration: 150; motionEasing: Easing.InOutSine; motionOvershoot: 0
    }
    AnimatedSlot { id: neighbour; targetWidth: 20; targetHeight: 24 }
  }
  Row {
    id: emptyIsland
    AnimatedSlot {
      targetWidth: DragModel.endGap(emptyPreview, "bar:left") ? 24 : 0
      targetHeight: 24
      motionDuration: 150; motionEasing: Easing.InOutSine; motionOvershoot: 0
    }
  }
  property bool leadingGap: false
  Item {
    id: leadingLayout
    implicitWidth: leadingSlot.width + leadingRow.width
    AnimatedSlot {
      id: leadingSlot
      targetWidth: leadingGap ? 24 : 0
      targetHeight: 24
      motionDuration: 150; motionEasing: Easing.InOutSine; motionOvershoot: 0
    }
    Row {
      id: leadingRow
      x: leadingSlot.width
      spacing: 6
      AnimatedSlot { id: leadingNeighbour; targetWidth: 20; targetHeight: 24 }
    }
  }
  property bool placeBefore: true
  AnimatedSlot {
    id: sideSwap
    targetWidth: 44
    targetHeight: 24
    targetInsetX: placeBefore ? 24 : 0
    motionDuration: 150; motionEasing: Easing.InOutSine; motionOvershoot: 0
    Item {
      id: sideSwapIcon
      width: 20; height: 24
      x: sideSwap.animatedInsetX
    }
  }
  property bool placeAbove: true
  AnimatedSlot {
    id: verticalSwap
    targetWidth: 24
    targetHeight: 44
    targetInsetY: placeAbove ? 24 : 0
    motionDuration: 150; motionEasing: Easing.InOutSine; motionOvershoot: 0
    Item { id: verticalIcon; width: 24; height: 20; y: verticalSwap.animatedInsetY }
  }
  function test_gapMovesNeighbourAndSurfaceTogether() {
    wait(120)
    compare(neighbour.x, 20)
    preview = Object.assign({}, preview, { ready: true })
    wait(40)
    verify(neighbour.x > 20 && neighbour.x < 44)
    compare(destination.width, neighbour.x + neighbour.width)
    tryCompare(neighbour, "x", 44, 300)
    preview = Object.assign({}, preview, { ready: false })
    wait(40)
    verify(neighbour.x > 20 && neighbour.x < 44)
    tryCompare(neighbour, "x", 20, 300)
  }
  function test_emptyIslandGrowsInsteadOfAppearingAtFullWidth() {
    wait(120)
    compare(emptyIsland.width, 0)
    emptyPreview = Object.assign({}, emptyPreview, { ready: true })
    wait(40)
    verify(emptyIsland.width > 0 && emptyIsland.width < 24)
    tryCompare(emptyIsland, "width", 24, 300)
  }
  function test_leadingGapDoesNotJumpByRowSpacing() {
    wait(120)
    compare(leadingNeighbour.x, 0)
    leadingGap = true
    tryVerify(function() { return leadingSlot.width > 4 && leadingSlot.width < 24 }, 300)
    verify(Math.abs(leadingRow.x + leadingNeighbour.x - leadingSlot.width) < 1,
      "A leading gap must not add an immediate Row spacing step")
  }
  function test_switchingInsertionSideSlidesIcon() {
    wait(120)
    compare(sideSwapIcon.x, 24)
    placeBefore = false
    wait(1)
    verify(sideSwapIcon.x > 0, "The icon must not jump across the gap")
    wait(40)
    verify(sideSwapIcon.x > 0 && sideSwapIcon.x < 24)
    tryCompare(sideSwapIcon, "x", 0, 300)
  }
  function test_verticalInsertionSideSlidesIcon() {
    wait(120)
    compare(verticalIcon.y, 24)
    placeAbove = false
    wait(40)
    verify(verticalIcon.y > 0 && verticalIcon.y < 24)
    tryCompare(verticalIcon, "y", 0, 300)
  }
}
