import QtQuick
import qs.Commons
import qs.Commons as Commons
import "PreferencesModel.js" as Model

// The camera on the Layout, Groups, Look and Behavior pages
// (docs/behavior/preferences.md PREFS-24): the notch's cap, solid black from
// the page's top down to a torn edge a little above the plates, with a fringe
// along the tear and a soft shade under it (Tuning's numbers); the
// camera's eye under the notch and "camera" below it. The cap is drawn on a
// plane tilted about `line` (the bar layer's top edge), as wide as Center, so
// its sides run on the lines that layer's Center tile edges lie on. Place it
// at the page's origin; everything is in the page's coordinates. Items that
// draw the cap over their own surface use a BeamShade with this one's tilt,
// distance and theme.
Item {
    id: camera
    // The screen's middle, the column's half width, the line its plane turns
    // about, the page's top (the bar's edge) and the bottom of the plane the
    // shade is drawn on, all in the page.
    property real axis: 0
    property real half: 0
    property real line: 0
    property real pageTop: 0
    property real beamBottom: 0
    property real tilt: 34
    property real planeDistance: 1600
    property bool lightTheme: false
    // The plane's own depth for a seen height in the page.
    function depth(y) {
        return Model.tiltedDepth(y - line, tilt, planeDistance);
    }
    // The eye's middle, for things placed beside it.
    readonly property real eyeY: cameraEye.y + cameraEye.height / 2
    x: 0
    y: 0
    width: 0
    height: 0

    // The shade past the column's sides (Tuning's shadeSpread), behind
    // the plates, on the same plane: the cap's own quad stays the column.
    BeamShade {
        id: spill
        readonly property real reach: shadeSpread
        visible: reach > 0
        spill: 1
        outer: reach
        colWidth: 2 * camera.half
        tilt: camera.tilt
        planeDistance: camera.planeDistance
        lightTheme: camera.lightTheme
        vTop: camera.depth(camera.pageTop)
        vBottom: camera.depth(camera.beamBottom)
        x: camera.axis - camera.half - reach
        y: camera.line + vTop
        width: 2 * (camera.half + reach)
        height: Math.max(0, vBottom - vTop)
        transform: Rotation {
            axis {
                x: 1
                y: 0
                z: 0
            }
            origin.x: camera.half + spill.reach
            origin.y: -spill.vTop
            distanceToPlane: camera.planeDistance
            angle: camera.tilt
        }
    }
    BeamShade {
        id: beam
        vTop: camera.depth(camera.pageTop)
        vBottom: camera.depth(camera.beamBottom)
        tilt: camera.tilt
        planeDistance: camera.planeDistance
        lightTheme: camera.lightTheme
        x: camera.axis - camera.half
        y: camera.line + vTop
        width: 2 * camera.half
        height: Math.max(0, vBottom - vTop)
        transform: Rotation {
            axis {
                x: 1
                y: 0
                z: 0
            }
            origin.x: camera.half
            origin.y: -beam.vTop
            distanceToPlane: camera.planeDistance
            angle: camera.tilt
        }
    }
    // The camera's eye under the notch, named below it. The cap is black
    // on every theme, so both are drawn in white.
    Item {
        id: cameraEye
        x: camera.axis - width / 2
        y: camera.pageTop + Style.space(14)
        width: Style.space(16)
        height: width
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, Math.round(Style.space(1.5)))
            border.color: Qt.rgba(1, 1, 1, 0.5)
        }
        Rectangle {
            anchors.centerIn: parent
            width: Style.space(6)
            height: width
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.5)
        }
    }
    Text {
        x: camera.axis - width / 2
        y: cameraEye.y + cameraEye.height + Style.space(6)
        width: Style.space(200)
        horizontalAlignment: Text.AlignHCenter
        text: "camera"
        textFormat: Text.PlainText
        color: Qt.rgba(1, 1, 1, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
    }
}
