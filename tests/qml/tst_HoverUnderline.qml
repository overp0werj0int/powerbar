import QtQuick
import QtTest
import "../../"

TestCase {
  name: "HoverUnderline"
  when: windowShown
  // Hidden items paint nothing, so the measured content must be on screen.
  visible: true

  // Stand-ins for Omarchy's WidgetButton and BarIconButton: only the
  // properties the mark measures.
  component FakeGlyphButton: Item {
    property real glyphPaintedWidth: 14
    property real opticalSize: 18
    MouseArea { anchors.fill: parent }
  }
  component FakeLabelButton: Item {
    property string text: "Label"
    property string fontFamily: "sans-serif"
    property real fontSize: 12
    property real textRotation: 0
    property real labelWidth: 40
  }

  HoverUnderline {
    id: mark
    width: 100
    height: 26
    accent: "#ff6600"
    expandedFraction: 0.6
    horizontalInset: 8
    motionEnabled: true
  }

  // Two icons in differently padded slots.
  Item {
    id: narrowSlot
    width: 26; height: 26
    FakeGlyphButton { id: narrowGlyph; anchors.fill: parent }
    HoverUnderline { id: narrowMark; anchors.fill: parent; contentItem: narrowSlot; motionEnabled: false }
  }
  Item {
    id: wideSlot
    width: 44; height: 26
    // A BarWidget-style wrapper: one painted button beside a pointer area.
    FakeGlyphButton { anchors.centerIn: parent; width: 30; height: 26 }
    MouseArea { anchors.fill: parent }
    HoverUnderline { id: wideMark; anchors.fill: parent; contentItem: wideSlot; motionEnabled: false }
  }
  Item {
    id: multiSlot
    width: 90; height: 26
    Rectangle { x: 10; width: 20; height: 20 }
    Rectangle { x: 40; width: 20; height: 20 }
    Rectangle { x: 70; width: 20; height: 20; visible: false }
  }
  FakeLabelButton { id: labelButton; width: 60; height: 26 }
  // A vertical clock: the button hides its label and paints a stack of lines.
  FakeLabelButton {
    id: stackedButton
    width: 30; height: 52
    labelWidth: 0
    Column {
      anchors.centerIn: parent
      Rectangle { width: 16; height: 20 }
      Rectangle { width: 12; height: 20 }
    }
  }
  // Separate parts the mark cannot tell apart, but the widget names its mark.
  Item {
    id: hintedSlot
    width: 90; height: 26
    readonly property real openPanelIndicatorWidth: 24
    Rectangle { x: 10; width: 20; height: 20 }
    Rectangle { x: 40; width: 20; height: 20 }
  }

  function test_growsFromCenterAndRetracts() {
    compare(mark.strokeWidth, 0)
    mark.active = true
    wait(35)
    verify(mark.strokeWidth > 0 && mark.strokeWidth < 60)
    tryCompare(mark, "strokeWidth", 60, 300)
    compare(mark.strokeX, 20)
    mark.active = false
    wait(35)
    verify(mark.strokeWidth > 0 && mark.strokeWidth < 60)
    tryCompare(mark, "strokeWidth", 0, 300)
  }
  function test_menuRowsSpanTheRowLessInsets() {
    mark.mode = "row"
    mark.width = 180
    mark.active = true
    wait(35)
    verify(mark.strokeWidth > 0 && mark.strokeWidth < 164)
    tryCompare(mark, "strokeWidth", 164, 300)
    compare(mark.strokeX, 8)
    mark.active = false
    tryCompare(mark, "strokeWidth", 0, 300)
    mark.mode = "icon"
    mark.width = 100
  }
  function test_iconsMatchTheirGlyphNotTheirSlot() {
    narrowMark.active = true
    wideMark.active = true
    compare(narrowMark.strokeWidth, 14)
    compare(wideMark.strokeWidth, 14)
    compare(narrowMark.strokeX, 6)
    compare(wideMark.strokeX, 15)
    narrowGlyph.glyphPaintedWidth = 18
    compare(narrowMark.strokeWidth, 18)
    // An image icon has no glyph ink; its optical canvas is the painted size.
    narrowGlyph.glyphPaintedWidth = 0
    compare(narrowMark.strokeWidth, 18)
    narrowGlyph.opticalSize = 40
    compare(narrowMark.strokeWidth, 26)
    narrowGlyph.opticalSize = 18
    narrowGlyph.glyphPaintedWidth = 14
    narrowMark.active = false
    wideMark.active = false
  }
  function test_measurementRules() {
    compare(mark.inkWidth(multiSlot, 0), 50)
    verify(mark.inkWidth(labelButton, 0) > 0)
    labelButton.textRotation = 90
    compare(mark.inkWidth(labelButton, 0), 0)
    labelButton.textRotation = 0
    compare(mark.inkWidth(stackedButton, 0), 16)
    compare(mark.inkWidth(hintedSlot, 0), 24)
    mark.contentWidth = 22
    mark.motionEnabled = false
    mark.active = true
    compare(mark.strokeWidth, 22)
    mark.contentWidth = 2
    compare(mark.strokeWidth, mark.minimumWidth)
    mark.active = false
    mark.contentWidth = -1
    mark.motionEnabled = true
  }
  function test_labelUsesInkMetrics() {
    mark.contentItem = labelButton
    compare(mark.textSource, labelButton)
    verify(mark.measuredContentWidth > 0 && mark.measuredContentWidth <= labelButton.width)
    mark.contentItem = null
  }
  function test_reducedMotionSnapsToTarget() {
    mark.motionEnabled = false
    mark.active = true
    compare(mark.strokeWidth, 60)
    mark.active = false
    compare(mark.strokeWidth, 0)
    mark.motionEnabled = true
  }
}
