import QtQuick
import qs.Commons

// Where a dragged widget will land: its cell outlined inside the open drop
// gap. One look for every drop surface: the bar's zones, drawer strips and
// menu rows. The outline is kept one pixel inside the gap, on whole pixels,
// so all four borders draw even where the gap's slot clips (in Equal gaps a
// cell can be longer than the slot it lands in).
//
// It moves as the highlights do (DRAG-75, HighlightGlide.qml): the outline
// the drop moves to starts where the last one was drawn and glides to its
// own gap, while the last one goes out at once. One that shows with none to
// take over from fades in, already at its cell's size, as its gap opens.
Item {
  id: outline
  property var bar: null
  // The run the gap opens in: a column (true) or a row (false).
  property bool vertical: !!bar && bar.vertical
  // The gap along the run, in the parent's coordinates.
  property real gapStart: 0
  property real gapLength: 0
  // The drop lands here: the gap is opening or open (it may still be short).
  property bool open: gapLength > 1
  // The landing cell: its length along the run and its thickness across.
  property real cellAlong: bar ? (bar.barDragSource ? bar.barDragSource.cellLength : bar.cellTokens.cell) : 0
  property real cellAcross: bar ? bar.cellTokens.thickness : 0
  // The run's size across; the cell centres in it.
  property real crossLength: vertical ? (parent ? parent.width : 0) : (parent ? parent.height : 0)
  // Where the cell starts in the gap; below zero it centres. A menu row lands
  // at the gap's start (or one inset past the row before it).
  property real landingOffset: -1
  // A fully open gap: the outline is drawn at the size it has there while
  // the gap is still opening (or closing).
  property real fullGap: bar ? (vertical ? bar.dragGapHeight : bar.dragGapWidth) : 1
  property color ink: bar ? bar.barForeground : "transparent"
  // The widget lands On demand here: the outline holds the zone's dots, drawn
  // as quietly as a yield marker, so the landing says where the widget goes.
  property bool onDemand: false
  // The slide and the fade take as long as the gap's own motion.
  property bool motionEnabled: !!bar && bar.animationsEnabled && !bar.dragHandover
  property int motionDuration: bar ? bar.dragMotionDuration : 200
  // Outlines sharing a glide and a key (one zone of one bar, or one drawer)
  // hand the outline from one to the next.
  property QtObject glide: null
  property string glideKey: ""
  readonly property bool shown: open && !!bar && !!bar.barDragSource
  readonly property alias body: frame

  readonly property real roomAlong: Math.max(gapLength, fullGap)
  readonly property real along: Math.max(0, Math.min(cellAlong, roomAlong - 2))
  readonly property real landingStart: landingOffset >= 0 ? gapStart + Math.min(landingOffset, Math.max(0, roomAlong - along - 1))
    : gapStart + (gapLength - along) / 2
  // Fading out it stays where it was: its gap closes under it, and some
  // surfaces drop the gap's length as soon as the drop leaves.
  property real lastStart: 0
  onLandingStartChanged: if (shown) lastStart = landingStart
  readonly property real alongStart: shown ? landingStart : lastStart
  x: Math.round(vertical ? (crossLength - cellAcross) / 2 : alongStart)
  y: Math.round(vertical ? alongStart : (crossLength - cellAcross) / 2)
  width: vertical ? cellAcross : along
  height: vertical ? along : cellAcross

  // Lit and put out once per event-loop turn, so the outline the drop leaves
  // and the one it reaches change in either order and still hand over.
  property bool lit: false
  property bool handedOff: false
  property bool sliding: false
  onShownChanged: {
    if (shown) lastStart = landingStart
    Qt.callLater(outline.settle)
  }
  Component.onCompleted: settle()
  function settle() {
    if (shown && !lit) {
      handedOff = false
      var from = glideLive() && motionEnabled ? glide.takeOver(outline) : null
      if (from) slideFrom(from)
    }
    if (!shown && lit && glideLive()) glide.release(outline)
    lit = shown
  }
  // A settle queued with Qt.callLater can run while the glide is being torn
  // down, when Qt 6.12 has already dropped its functions.
  function glideLive() { return !!glide && typeof glide.release === "function" }
  function handOff() { slide.stop(); handedOff = true }
  // From a rect in scene coordinates to the outline's own place.
  function slideFrom(r) {
    var p = outline.mapFromItem(null, r.x, r.y)
    var dx = p.x, dy = p.y, dw = r.width - width, dh = r.height - height
    if (Math.hypot(dx + dw / 2, dy + dh / 2) < 0.5) return
    slide.stop()
    offX = dx; offY = dy; offW = dw; offH = dh
    sliding = true
    slide.start()
  }
  property real offX: 0
  property real offY: 0
  property real offW: 0
  property real offH: 0
  ParallelAnimation {
    id: slide
    NumberAnimation { target: outline; property: "offX"; to: 0; duration: outline.motionDuration; easing.type: Easing.OutCubic }
    NumberAnimation { target: outline; property: "offY"; to: 0; duration: outline.motionDuration; easing.type: Easing.OutCubic }
    NumberAnimation { target: outline; property: "offW"; to: 0; duration: outline.motionDuration; easing.type: Easing.OutCubic }
    NumberAnimation { target: outline; property: "offH"; to: 0; duration: outline.motionDuration; easing.type: Easing.OutCubic }
    onStopped: { outline.sliding = false; outline.offX = 0; outline.offY = 0; outline.offW = 0; outline.offH = 0 }
  }

  // The fade runs on `shade`, so a hand-off cuts a fade-out already running.
  property real shade: lit ? 1 : 0
  Behavior on shade { enabled: outline.motionEnabled && !outline.sliding; NumberAnimation { duration: outline.motionDuration; easing.type: Easing.OutCubic } }
  opacity: handedOff ? 0 : shade
  visible: !!bar && !!bar.barDragSource && opacity > 0 && along > 0
  Accessible.ignored: true

  Rectangle {
    id: frame
    x: Math.round(outline.offX)
    y: Math.round(outline.offY)
    width: Math.max(0, Math.round(outline.width + outline.offW))
    height: Math.max(0, Math.round(outline.height + outline.offH))
    radius: outline.bar ? outline.bar.highlightRadius : 0
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(outline.ink.r, outline.ink.g, outline.ink.b, 0.45)
    Text {
      anchors.centerIn: parent
      visible: outline.onDemand
      textFormat: Text.PlainText
      text: outline.vertical ? "󰇙" : "󰇘"
      color: outline.ink
      opacity: 0.45
      font.family: outline.bar ? outline.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
