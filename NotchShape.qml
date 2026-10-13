import QtQuick
import QtQuick.Shapes
import "NotchModel.js" as NotchModel

// The camera housing's own black (NotchModel.notchOf, notch-panels.json):
// the screen's top edge curves down into it at each shoulder and its bottom
// corners are round, as the hardware is, whatever rounding the bar's zones
// use. Its size is the item's; the bar window's input region on the camera
// follows it (Bar.qml mask).
Shape {
  id: housing
  property var notch: null
  property color color: "black"
  readonly property var corners: NotchModel.cornersOf(notch, width)
  readonly property real s: corners.shoulder
  readonly property real r: corners.radius
  readonly property real w: width
  readonly property real h: height
  preferredRendererType: Shape.CurveRenderer
  ShapePath {
    fillColor: housing.color
    strokeColor: "transparent"
    startX: 0; startY: 0
    PathLine { x: housing.w; y: 0 }
    PathArc { x: housing.w - housing.s; y: housing.s; radiusX: housing.s; radiusY: housing.s; direction: PathArc.Counterclockwise }
    PathLine { x: housing.w - housing.s; y: housing.h - housing.r }
    PathArc { x: housing.w - housing.s - housing.r; y: housing.h; radiusX: housing.r; radiusY: housing.r }
    PathLine { x: housing.s + housing.r; y: housing.h }
    PathArc { x: housing.s; y: housing.h - housing.r; radiusX: housing.r; radiusY: housing.r }
    PathLine { x: housing.s; y: housing.s }
    PathArc { x: 0; y: 0; radiusX: housing.s; radiusY: housing.s; direction: PathArc.Counterclockwise }
  }
}
