import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "NotchModel.js" as NotchModel

// The notch's black in the camera housing's shape (NotchModel.notchOf,
// notch-panels.json): the screen's top edge curves down into it at each
// shoulder, and its bottom corners are round, as the hardware is. The camera
// is drawn with both ends so; the notch's zones and badges take the same
// corners at their outer end and stay square where they meet the camera
// (docs/behavior/appearance.md LOOK-143). Its size is the item's, shoulders
// included; the bar window's input region on the camera follows it (Bar.qml
// mask).
Shape {
  id: housing
  // The camera: its corners come from its notch, shrunk to fit its width.
  property var notch: null
  readonly property var corners: NotchModel.cornersOf(notch, width)
  // Each end's shoulder (the top's inside curve) and bottom corner; 0 is square.
  property real shoulderStart: corners.shoulder
  property real shoulderEnd: corners.shoulder
  property real radiusStart: corners.radius
  property real radiusEnd: corners.radius
  property color color: "black"
  property bool shadowEnabled: false
  property real shadowSize: 16
  property real shadowOpacity: 0.3

  readonly property real w: width
  readonly property real h: height
  readonly property real sS: Math.max(0, Math.min(shoulderStart, h / 2, w / 2))
  readonly property real sE: Math.max(0, Math.min(shoulderEnd, h / 2, w / 2))
  // Below the shoulders the body is w - sS - sE wide.
  readonly property real body: Math.max(0, w - sS - sE)
  readonly property real rS: Math.max(0, Math.min(radiusStart, h - sS, body / 2))
  readonly property real rE: Math.max(0, Math.min(radiusEnd, h - sE, body / 2))
  preferredRendererType: Shape.CurveRenderer

  // The body's shadow, below the shoulders, as an island casts its own.
  RectangularShadow {
    z: -1
    visible: housing.shadowEnabled && housing.body > 0
    x: housing.sS
    width: housing.body
    height: housing.h
    radius: Math.max(housing.rS, housing.rE)
    blur: housing.shadowSize
    color: Qt.rgba(0, 0, 0, housing.shadowOpacity)
  }

  ShapePath {
    fillColor: housing.color
    strokeColor: "transparent"
    startX: 0; startY: 0
    PathLine { x: housing.w; y: 0 }
    PathArc { x: housing.w - housing.sE; y: housing.sE; radiusX: housing.sE; radiusY: housing.sE; direction: PathArc.Counterclockwise }
    PathLine { x: housing.w - housing.sE; y: housing.h - housing.rE }
    PathArc { x: housing.w - housing.sE - housing.rE; y: housing.h; radiusX: housing.rE; radiusY: housing.rE }
    PathLine { x: housing.sS + housing.rS; y: housing.h }
    PathArc { x: housing.sS; y: housing.h - housing.rS; radiusX: housing.rS; radiusY: housing.rS }
    PathLine { x: housing.sS; y: housing.sS }
    PathArc { x: 0; y: 0; radiusX: housing.sS; radiusY: housing.sS; direction: PathArc.Counterclockwise }
  }
}
