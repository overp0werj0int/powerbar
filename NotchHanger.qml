import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// A notch zone that wraps (Bar.qml zoneWrap, docs/behavior/layout-zones.md
// "Notch"): its first row from the camera to the screen edge and the second
// row hanging under it there, drawn as one black shape. The outer end is one
// rounded cap across both rows; where the second row ends it meets the first
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
  readonly property real cap: Math.min(bar.islandRounding, h)
  readonly property real foot: Math.min(bar.islandRounding, h / 2)
  property real reach: wrap ? Math.max(0, leftSide ? rowEnd - outer : outer - rowEnd) : 0
  Behavior on reach { enabled: bar.animationsEnabled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  readonly property bool shown: reach > 0.5
  readonly property real capShown: Math.min(cap, reach / 2)
  visible: shown

  // The shadows of the cap with the second row and of the first row, as an
  // island casts its own (EffectSurface).
  RectangularShadow {
    visible: hanger.shadowEnabled
    x: capRect.x; width: capRect.width; height: capRect.height
    radius: hanger.cap
    blur: hanger.shadowSize
    color: Qt.rgba(0, 0, 0, hanger.shadowOpacity)
  }
  RectangularShadow {
    visible: hanger.shadowEnabled
    x: firstRow.x; width: firstRow.width; height: firstRow.height
    blur: hanger.shadowSize
    color: Qt.rgba(0, 0, 0, hanger.shadowOpacity)
  }
  // The cap and the second row.
  Rectangle {
    id: capRect
    x: hanger.leftSide ? hanger.outer : hanger.outer - hanger.reach
    width: hanger.reach
    height: hanger.h * 2
    color: hanger.color
    topLeftRadius: hanger.leftSide ? hanger.cap : 0
    bottomLeftRadius: hanger.leftSide ? hanger.cap : hanger.foot
    topRightRadius: hanger.leftSide ? 0 : hanger.cap
    bottomRightRadius: hanger.leftSide ? hanger.foot : hanger.cap
  }
  // The first row, from past the cap's curve to the camera.
  Rectangle {
    id: firstRow
    x: hanger.leftSide ? hanger.outer + hanger.capShown : hanger.inner
    width: Math.max(0, hanger.leftSide ? hanger.inner - x : hanger.outer - hanger.capShown - hanger.inner)
    height: hanger.h
    color: hanger.color
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
