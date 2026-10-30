import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons

// A dashed edge: the tray's (PREFS-97), a hidden face's, a "+" (the Groups page).
Shape {
    id: frame
    property real radius: 0
    property real topRadius: radius
    property color stroke: Qt.alpha(Commons.Color.popups.text, 0.3)
    readonly property real r: Math.max(0, Math.min(radius, width / 2, height / 2))
    readonly property real tr: Math.max(0, Math.min(topRadius, width / 2, height / 2))
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: frame.stroke
        strokeWidth: 1
        strokeStyle: ShapePath.DashLine
        dashPattern: [3, 3]
        fillColor: "transparent"
        startX: frame.tr
        startY: 0.5
        PathLine {
            x: frame.width - frame.tr
            y: 0.5
        }
        PathArc {
            x: frame.width - 0.5
            y: frame.tr
            radiusX: frame.tr
            radiusY: frame.tr
        }
        PathLine {
            x: frame.width - 0.5
            y: frame.height - frame.r
        }
        PathArc {
            x: frame.width - frame.r
            y: frame.height - 0.5
            radiusX: frame.r
            radiusY: frame.r
        }
        PathLine {
            x: frame.r
            y: frame.height - 0.5
        }
        PathArc {
            x: 0.5
            y: frame.height - frame.r
            radiusX: frame.r
            radiusY: frame.r
        }
        PathLine {
            x: 0.5
            y: frame.tr
        }
        PathArc {
            x: frame.tr
            y: 0.5
            radiusX: frame.tr
            radiusY: frame.tr
        }
    }
}
