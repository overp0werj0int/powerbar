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

  function init() {
    mark.hovered = false
    mark.selected = false
    mark.older = false
    moving.hovered = false
    moving.outlined = false
    tryCompare(mark, "lit", false)
    tryCompare(moving, "opacity", 0)
  }

  function test_hidden_at_rest() {
    compare(mark.opacity, 0)
    compare(mark.visible, false)
  }

  function test_hover_shows_hover_fill() {
    mark.hovered = true
    tryCompare(mark, "opacity", 1)
    compare(mark.color, Qt.color("#20ffffff"))
  }

  function test_selection_wins_over_hover() {
    mark.hovered = true
    mark.selected = true
    compare(mark.color, Qt.color("#40ffffff"))
    mark.hovered = false
    wait(0)
    compare(mark.opacity, 1)
  }

  function test_rounding_never_exceeds_a_pill() {
    compare(mark.radius, 10)
    mark.rounding = 4
    compare(mark.radius, 4)
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
    compare(moving.border.width, moving.outlineWidth)
    moving.outlined = false
    moving.hovered = false
    tryCompare(moving, "lit", false)
    compare(moving.opacity, 0)
    compare(moving.border.width, 0)
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
    compare(moving.border.width, 0)
  }

  function test_ring_is_one_device_pixel() {
    compare(mark.outlineWidth * Math.max(1, Screen.devicePixelRatio), 1)
  }
}
