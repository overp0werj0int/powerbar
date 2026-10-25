import QtQuick
import qs.Commons
import qs.Commons as Commons
import "PreferencesModel.js" as Model

// The camera on the Layout and Groups pages (docs/behavior/preferences.md
// PREFS-24): the notch's cap, solid black from the page's top, giving way to
// a soft beam that falls behind the page and fades out at beamBottom; the
// camera's eye under the notch and "camera" below it. The beam is drawn on a
// plane tilted about `line` (the bar layer's top edge), as wide as Center, so
// its edges run on the lines that layer's Center tile edges lie on. Place it
// at the page's origin; everything is in the page's coordinates. Items that
// draw the beam over their own surface use a BeamShade with this one's peak,
// capEnd, capFade and span.
Item {
    id: camera
    // The screen's middle, the beam's half width, the line its plane turns
    // about, the page's top (the bar's edge) and where the beam has faded out,
    // all in the page.
    property real axis: 0
    property real half: 0
    property real line: 0
    property real pageTop: 0
    property real beamBottom: 0
    property real tilt: 34
    property real planeDistance: 1600
    property bool lightTheme: false
    // Where the cap gives way to the beam, as a seen height in the page: by
    // default past the camera's caption, 56 px under the page's top. Over
    // capLength the cap has fully become the beam.
    property real capBottom: pageTop + Style.space(56)
    property real capLength: line - capBottom
    readonly property real peak: lightTheme ? 0.5 : 0.65
    readonly property real capEnd: depth(capBottom)
    readonly property real capFade: depth(capBottom + capLength)
    readonly property real span: depth(beamBottom)
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

    BeamShade {
        id: beam
        vTop: camera.depth(camera.pageTop)
        vBottom: camera.depth(camera.beamBottom)
        peak: camera.peak
        capEnd: camera.capEnd
        capFade: camera.capFade
        span: camera.span
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
    // The camera's eye under the notch, named below it. The beam is black
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
