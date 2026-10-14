import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// A notch zone that wraps (Bar.qml zoneWrap, docs/behavior/layout-zones.md
// "Notch"): its first row from the camera to the screen edge and the second
// row hanging under it there, drawn as one black shape. The outer end is one
// cap across both rows with the camera's corners (its shoulder at the top,
// its bottom radius below); where the second row ends it meets the first
// with an inside curve. The second row opens from the screen edge and closes
// back into it, on the widgets' clock.
Item {
  id: hanger
  property var bar: null
  property string side: "left"
  property var wrap: null
  // Along the bar: where the first row meets the camera, and where the
  // second row ends toward it.
  property real inner: 0
  property real rowEnd: 0
  property color color: "black"
  property bool shadowEnabled: false
  property real shadowSize: 16
  property real shadowOpacity: 0.3

  readonly property real h: bar ? bar.barSize : 0
  readonly property bool leftSide: side === "left"
  readonly property real outer: leftSide ? bar.islandScreenInset : width - bar.islandScreenInset
  // The camera's corners (Bar.qml notchCorners), as the zones have them.
  readonly property real shoulder: bar.notchCorners.shoulder
  readonly property real foot: Math.min(bar.notchCorners.radius, h / 2)
  property real reach: wrap ? Math.max(0, leftSide ? rowEnd - outer : outer - rowEnd) : 0
  Behavior on reach { enabled: bar.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  readonly property bool shown: reach > 0.5
  visible: shown

  // The first row, from the outer end to the camera, and its shadow.
  RectangularShadow {
    visible: hanger.shadowEnabled
    x: firstRow.x; width: firstRow.width; height: firstRow.height
    blur: hanger.shadowSize
    color: Qt.rgba(0, 0, 0, hanger.shadowOpacity)
  }
  Rectangle {
    id: firstRow
    x: hanger.leftSide ? hanger.outer : hanger.inner
    width: Math.max(0, hanger.leftSide ? hanger.inner - x : hanger.outer - hanger.inner)
    height: hanger.h
    color: hanger.color
  }
  // The cap across both rows: the camera's shoulder and bottom corner at the
  // outer end, the second row's foot toward the camera.
  NotchShape {
    x: hanger.leftSide ? hanger.outer - hanger.shoulder : hanger.outer - hanger.reach
    width: hanger.reach + hanger.shoulder
    height: hanger.h * 2
    color: hanger.color
    shoulderStart: hanger.leftSide ? hanger.shoulder : 0
    shoulderEnd: hanger.leftSide ? 0 : hanger.shoulder
    radiusStart: hanger.leftSide ? bar.notchCorners.radius : hanger.foot
    radiusEnd: hanger.leftSide ? hanger.foot : bar.notchCorners.radius
    shadowEnabled: hanger.shadowEnabled
    shadowSize: hanger.shadowSize
    shadowOpacity: hanger.shadowOpacity
  }
  // The inside curve where the second row meets the first.
  Shape {
    id: fillet
    readonly property real x0: hanger.leftSide ? hanger.outer + hanger.reach : hanger.outer - hanger.reach
    readonly property real f: Math.min(hanger.foot, Math.abs(hanger.inner - x0))
    visible: f > 0.5
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: hanger.color
      strokeColor: "transparent"
      startX: fillet.x0; startY: hanger.h
      PathLine { x: hanger.leftSide ? fillet.x0 + fillet.f : fillet.x0 - fillet.f; y: hanger.h }
      PathArc {
        x: fillet.x0; y: hanger.h + fillet.f
        radiusX: fillet.f; radiusY: fillet.f
        direction: hanger.leftSide ? PathArc.Counterclockwise : PathArc.Clockwise
      }
      PathLine { x: fillet.x0; y: hanger.h }
    }
  }
}
