import QtQuick

// Where a dragged widget will land: its cell outlined inside the open drop
// gap. One look for every drop surface: the bar's zones, drawer strips and
// menu rows. The outline is kept one pixel inside the gap, on whole pixels,
// so all four borders draw even where the gap's slot clips (in Equal gaps a
// cell can be longer than the slot it lands in).
Rectangle {
  id: outline
  property var bar: null
  // The run the gap opens in: a column (true) or a row (false).
  property bool vertical: !!bar && bar.vertical
  // The gap along the run, in the parent's coordinates.
  property real gapStart: 0
  property real gapLength: 0
  // The landing cell: its length along the run and its thickness across.
  property real cellAlong: bar ? (bar.barDragSource ? bar.barDragSource.cellLength : bar.cellTokens.cell) : 0
  property real cellAcross: bar ? bar.cellTokens.thickness : 0
  // The run's size across; the cell centres in it.
  property real crossLength: vertical ? (parent ? parent.width : 0) : (parent ? parent.height : 0)
  // Where the cell starts in the gap; below zero it centres. A menu row lands
  // at the gap's start (or one inset past the row before it).
  property real landingOffset: -1
  // A fully open gap, so the outline fades in with it.
  property real fullGap: bar ? (vertical ? bar.dragGapHeight : bar.dragGapWidth) : 1
  property color ink: bar ? bar.barForeground : "transparent"
  readonly property real along: Math.max(0, Math.min(cellAlong, gapLength - 2))
  readonly property real alongStart: landingOffset >= 0 ? gapStart + Math.min(landingOffset, Math.max(0, gapLength - along - 1))
    : gapStart + (gapLength - along) / 2
  visible: !!bar && !!bar.barDragSource && gapLength > 1
  opacity: Math.min(1, gapLength / Math.max(1, fullGap))
  x: Math.round(vertical ? (crossLength - cellAcross) / 2 : alongStart)
  y: Math.round(vertical ? alongStart : (crossLength - cellAcross) / 2)
  width: vertical ? cellAcross : along
  height: vertical ? along : cellAcross
  radius: bar ? bar.highlightRadius : 0
  color: "transparent"
  border.width: 1
  border.color: Qt.rgba(ink.r, ink.g, ink.b, 0.45)
  Accessible.ignored: true
}
