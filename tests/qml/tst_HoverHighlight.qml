import QtQuick
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

  function init() {
    mark.hovered = false
    mark.selected = false
    mark.older = false
  }

  function test_hidden_at_rest() {
    compare(mark.opacity, 0)
    compare(mark.visible, false)
  }

  function test_hover_shows_hover_fill() {
    mark.hovered = true
    compare(mark.opacity, 1)
    compare(mark.color, Qt.color("#20ffffff"))
  }

  function test_selection_wins_over_hover() {
    mark.hovered = true
    mark.selected = true
    compare(mark.color, Qt.color("#40ffffff"))
    mark.hovered = false
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
    compare(mark.opacity, 1)
    compare(mark.z, 1)
    mark.older = true
    compare(mark.opacity, 0.45)
    compare(mark.z, 0)
    mark.selected = false
    compare(mark.opacity, 0)
  }
}
