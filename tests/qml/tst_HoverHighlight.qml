import QtQuick
import QtQuick.Window
import QtTest
import "../../"

TestCase {
  name: "HoverHighlight"
  when: windowShown

  HoverHighlight {
    id: mark
    width: 40
    height: 20
    motionEnabled: false
    hoverColor: "#20ffffff"
    selectedColor: "#40ffffff"
    rounding: 16
  }

  // With motion, to tell a cursor move (at once) from pointer hover (faded).
  HoverHighlight {
    id: moving
    width: 40
    height: 20
    hoverColor: "#20ffffff"
  }

  // Two cells of one zone and one of another, sharing a glide (LOOK-139).
  HighlightGlide { id: glide }
  Item {
    id: row
    width: 200
    height: 20
    HoverHighlight { id: first; x: 0; width: 30; height: 20; glide: glide; glideKey: "left"; hoverColor: "#20ffffff" }
    HoverHighlight { id: second; x: 120; width: 50; height: 20; glide: glide; glideKey: "left"; hoverColor: "#20ffffff" }
    HoverHighlight { id: other; x: 180; width: 20; height: 20; glide: glide; glideKey: "right"; hoverColor: "#20ffffff" }
  }

  function init() {
    mark.hovered = false
    mark.selected = false
    mark.older = false
    moving.hovered = false
    moving.outlined = false
    tryCompare(mark, "lit", false)
    tryCompare(moving, "opacity", 0)
    for (const m of [first, second, other]) { m.hovered = false; m.outlined = false }
    for (const m of [first, second, other]) tryCompare(m, "opacity", 0)
    glide.current = null
  }

  function test_hidden_at_rest() {
    compare(mark.opacity, 0)
    compare(mark.visible, false)
  }

  function test_hover_shows_hover_fill() {
    mark.hovered = true
    tryCompare(mark, "opacity", 1)
    compare(mark.body.color, Qt.color("#20ffffff"))
  }

  function test_selection_wins_over_hover() {
    mark.hovered = true
    mark.selected = true
    compare(mark.body.color, Qt.color("#40ffffff"))
    mark.hovered = false
    wait(0)
    compare(mark.opacity, 1)
  }

  function test_rounding_never_exceeds_a_pill() {
    compare(mark.body.radius, 10)
    mark.rounding = 4
    compare(mark.body.radius, 4)
    mark.rounding = 16
  }

  function test_older_overlapped_highlight_fades_and_sits_below() {
    mark.selected = true
    tryCompare(mark, "opacity", 1)
    compare(mark.z, 1)
    mark.older = true
    compare(mark.opacity, 0.45)
    compare(mark.z, 0)
    mark.selected = false
    tryCompare(mark, "opacity", 0)
  }

  function test_cursor_move_shows_at_once() {
    moving.hovered = true
    moving.outlined = true
    tryCompare(moving, "lit", true)
    compare(moving.opacity, 1)
    compare(moving.body.border.width, moving.outlineWidth)
    moving.outlined = false
    moving.hovered = false
    tryCompare(moving, "lit", false)
    compare(moving.opacity, 0)
    compare(moving.body.border.width, 0)
  }

  function test_pointer_hover_fades() {
    moving.hovered = true
    tryCompare(moving, "lit", true)
    verify(moving.opacity < 1)
    tryCompare(moving, "opacity", 1)
  }

  function test_cursor_leaving_a_pointed_stop_keeps_the_fill() {
    moving.hovered = true
    moving.outlined = true
    tryCompare(moving, "ringed", true)
    moving.outlined = false
    tryCompare(moving, "ringed", false)
    compare(moving.opacity, 1)
    compare(moving.body.border.width, 0)
  }

  function test_ring_is_one_device_pixel() {
    compare(mark.outlineWidth * Math.max(1, Screen.devicePixelRatio), 1)
  }

  function test_next_cell_slides_from_the_last() {
    first.hovered = true
    tryCompare(first, "opacity", 1)
    first.hovered = false
    second.hovered = true
    tryCompare(second, "sliding", true)
    compare(first.opacity, 0, "the last one goes at once, no fade")
    compare(second.opacity, 1, "the next one is drawn from the first frame")
    verify(second.body.x < 0, "it starts where the last one was")
    verify(second.body.width < 50, "and at its size")
    tryCompare(second, "sliding", false)
    compare(second.body.x, 0)
    compare(second.body.width, 50)
  }

  function test_cursor_move_slides_whichever_settles_first() {
    first.hovered = true; first.outlined = true
    tryCompare(first, "ringed", true)
    second.hovered = true; second.outlined = true
    first.hovered = false; first.outlined = false
    tryCompare(second, "sliding", true)
    compare(first.opacity, 0)
    tryCompare(second, "sliding", false)
  }

  function test_another_zone_does_not_slide() {
    first.hovered = true
    tryCompare(first, "opacity", 1)
    first.hovered = false
    other.hovered = true
    tryCompare(other, "lit", true)
    compare(other.sliding, false)
    compare(other.body.x, 0)
  }

  function test_a_mark_still_lit_keeps_its_fill() {
    first.hovered = true
    tryCompare(first, "opacity", 1)
    second.hovered = true
    tryCompare(second, "lit", true)
    compare(second.sliding, false, "both lit: no hand-over")
    compare(first.opacity, 1)
  }

  function test_a_late_hover_after_the_grace_fades_in_place() {
    first.hovered = true
    tryCompare(first, "opacity", 1)
    first.hovered = false
    tryCompare(first, "opacity", 0)
    wait(glide.graceMs + 40)
    second.hovered = true
    tryCompare(second, "lit", true)
    compare(second.sliding, false)
  }
}
