import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons
import "DashModel.js" as DashModel

// A dashed edge: the tray's (PREFS-97), the pool's, a hidden face's, a "+"
// (the Groups page). Its dashes are placed (DashModel.frame): every corner
// one solid piece, each side whole dashes with even gaps, so all corners
// read alike.
Shape {
    id: frame
    property real radius: 0
    property real topRadius: radius
    property color stroke: Qt.alpha(Commons.Color.popups.text, 0.3)
    property real dash: 3
    property real gap: 3
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: frame.stroke
        strokeWidth: 1
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        PathMultiline {
            paths: DashModel.frame(frame.width, frame.height, frame.topRadius, frame.radius, frame.dash, frame.gap).map(function (line) {
                return line.map(function (p) {
                    return Qt.point(p.x, p.y);
                });
            })
        }
    }
}
