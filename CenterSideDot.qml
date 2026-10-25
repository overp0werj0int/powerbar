import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons

// Which side of the camera Center sits on (powerbarCenterSide, ZONE-96), on
// the Layout and Groups pages (docs/behavior/preferences.md PREFS-105): a
// dashed accent leader from the bar layer's Center tile to a dot beside the
// camera on that side, captioned with Center's name. Drag the dot across the
// camera, click it, or h/l (Space, Enter) on it, to swap sides: `chosen`
// says which. Place it at the page's origin, as large as the page; it draws
// only while the camera does. `dot` is its Tab stop.
Item {
    id: root
    // The camera (CameraShaft): its axis, half width, eye and whether it shows.
    property Item camera: null
    property real axis: 0
    // The Center tile's top middle and the page's top, in the page.
    property real startY: 0
    property real pageTop: 0
    property string side: "right"
    property string label: "Center"
    property bool animate: true
    readonly property alias dot: sideDot
    signal chosen(string side)
    readonly property bool shown: !!camera && camera.visible
    x: 0
    y: 0

    // A Shape draws nothing outside its own box: this one reaches up to the
    // page's top, where the dot is.
    Shape {
        id: leader
        readonly property real x0: root.axis
        readonly property real y0: root.startY
        readonly property real x1: sideDot.x + sideDot.width / 2
        readonly property real y1: sideDot.y + sideDot.height / 2
        visible: root.shown
        x: 0
        y: root.pageTop
        width: root.width
        height: root.height - root.pageTop
        ShapePath {
            strokeColor: Commons.Color.accent
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            fillColor: "transparent"
            startX: leader.x0
            startY: leader.y0 - leader.y
            PathLine {
                x: leader.x1
                y: leader.y1 - leader.y
            }
        }
    }
    Item {
        id: sideDot
        readonly property bool onLeft: root.side === "left"
        readonly property real restX: root.axis + (onLeft ? -1 : 1) * ((root.camera ? root.camera.half : 0) + Style.space(16))
        property bool dragging: false
        property real dragX: 0
        readonly property var keyHints: [
            {
                keys: "h l",
                label: "Center left or right of the camera"
            },
            {
                keys: "space",
                label: "Swap sides"
            }
        ]
        readonly property bool ownsFocusRing: true
        visible: root.shown
        x: (dragging ? dragX : restX) - width / 2
        y: (root.camera ? root.camera.eyeY : 0) - height / 2
        width: Style.space(14)
        height: width
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Center " + (onLeft ? "left" : "right") + " of the camera"
        Behavior on x {
            enabled: root.animate && !sideDot.dragging
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Keys.onPressed: function (event) {
            var t = event.text.toLowerCase();
            if (event.key === Qt.Key_Left || t === "h")
                root.chosen("left");
            else if (event.key === Qt.Key_Right || t === "l")
                root.chosen("right");
            else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.chosen(sideDot.onLeft ? "right" : "left");
            else
                return;
            event.accepted = true;
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: dotMouse.containsMouse || sideDot.dragging ? Qt.alpha(Commons.Color.accent, 0.2) : "transparent"
            border.width: 1
            border.color: sideDot.activeFocus ? Commons.Color.accent : dotMouse.containsMouse ? Qt.alpha(Commons.Color.accent, 0.6) : "transparent"
        }
        Rectangle {
            anchors.centerIn: parent
            width: Style.space(6)
            height: width
            radius: width / 2
            color: Commons.Color.accent
        }
        Text {
            x: sideDot.onLeft ? -width - Style.space(6) : sideDot.width + Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        MouseArea {
            id: dotMouse
            anchors.fill: parent
            anchors.margins: -Style.space(8)
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            property real pressX: 0
            onPressed: function (mouse) {
                pressX = mapToItem(root, mouse.x, mouse.y).x;
                sideDot.dragX = sideDot.restX;
                sideDot.forceActiveFocus(Qt.MouseFocusReason);
            }
            onPositionChanged: function (mouse) {
                if (!pressed)
                    return;
                var x = mapToItem(root, mouse.x, mouse.y).x;
                if (!sideDot.dragging && Math.abs(x - pressX) <= Style.space(6))
                    return;
                sideDot.dragging = true;
                sideDot.dragX = x;
            }
            onReleased: function (mouse) {
                var x = mapToItem(root, mouse.x, mouse.y).x;
                var side = sideDot.dragging ? (x < root.axis ? "left" : "right") : (sideDot.onLeft ? "right" : "left");
                sideDot.dragging = false;
                root.chosen(side);
            }
            onCanceled: sideDot.dragging = false
        }
    }
}
