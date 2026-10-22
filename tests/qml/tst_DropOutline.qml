import QtQuick
import QtTest
import "../../"

TestCase {
  name: "DropOutline"
  when: windowShown

  // What the outline reads off the bar, mid-drag of a 20 px cell.
  QtObject {
    id: bar
    property bool vertical: false
    property var barDragSource: ({ cellLength: 20 })
    property var cellTokens: ({ cell: 20, thickness: 24 })
    property real dragGapWidth: 30
    property real dragGapHeight: 30
    property color barForeground: "white"
    property bool animationsEnabled: true
    property bool dragHandover: false
    property int dragMotionDuration: 150
    property real highlightRadius: 6
    function targetWindow(item) { return null }
    function tokensIn(window) { return cellTokens }
    function thicknessIn(window) { return cellTokens.thickness }
    function highlightRadiusIn(window) { return highlightRadius }
    property string fontFamily: "sans"
  }

  // Two gaps of one zone and one of another, sharing a glide (DRAG-75).
  HighlightGlide { id: glide }
  Item {
    id: row
    width: 300
    height: 30
    DropOutline { id: first; bar: bar; gapStart: 0; glide: glide; glideKey: "left" }
    DropOutline { id: second; bar: bar; gapStart: 150; glide: glide; glideKey: "left" }
    DropOutline { id: other; bar: bar; gapStart: 260; glide: glide; glideKey: "right" }
  }

  function init() {
    bar.animationsEnabled = true
    bar.barDragSource = { cellLength: 20 }
    for (const o of [first, second, other]) { o.open = false; o.gapLength = 0 }
    for (const o of [first, second, other]) tryCompare(o, "opacity", 0)
    glide.current = null
  }

  function test_hidden_at_rest() {
    compare(first.visible, false)
  }

  function test_first_appearance_fades_in_at_the_cell_size() {
    first.gapLength = 4
    first.open = true
    tryCompare(first, "lit", true)
    verify(first.opacity < 1, "it fades in")
    compare(first.body.width, 20, "at its cell's size while the gap opens")
    compare(first.sliding, false)
    tryCompare(first, "opacity", 1)
    first.gapLength = 30
    compare(first.x, 5, "centred in the open gap")
  }

  function test_the_next_gap_slides_from_the_last() {
    first.gapLength = 30
    first.open = true
    tryCompare(first, "opacity", 1)
    first.open = false
    second.gapLength = 4
    second.open = true
    tryCompare(second, "sliding", true)
    compare(first.opacity, 0, "the last one goes at once, no fade")
    compare(second.opacity, 1, "the next one is drawn from the first frame")
    verify(second.body.x < -100, "it starts where the last one was")
    tryCompare(second, "sliding", false)
    compare(second.body.x, 0)
    compare(second.body.width, 20)
  }

  function test_another_zone_fades_in_place() {
    first.gapLength = 30
    first.open = true
    tryCompare(first, "opacity", 1)
    first.open = false
    other.gapLength = 30
    other.open = true
    tryCompare(other, "lit", true)
    compare(other.sliding, false)
    verify(other.opacity < 1)
  }

  function test_fading_out_it_stays_where_it_was() {
    first.gapLength = 30
    first.open = true
    tryCompare(first, "opacity", 1)
    var x = first.x
    first.open = false
    first.gapLength = 0
    tryCompare(first, "lit", false)
    compare(first.x, x)
  }

  function test_animations_off_show_and_hide_at_once() {
    bar.animationsEnabled = false
    first.gapLength = 30
    first.open = true
    tryCompare(first, "lit", true)
    compare(first.opacity, 1)
    first.open = false
    second.gapLength = 30
    second.open = true
    tryCompare(second, "lit", true)
    compare(second.sliding, false)
    compare(first.opacity, 0)
  }

  function test_no_outline_without_a_drag() {
    first.gapLength = 30
    first.open = true
    tryCompare(first, "opacity", 1)
    bar.barDragSource = null
    compare(first.visible, false)
  }
}
