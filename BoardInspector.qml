import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "MotionModel.js" as MotionModel

// The inspector on a board page (PREFS-101, PREFS-26): a surface at the
// page's bottom right, in front of the plates, fading and growing in from
// 97 % about its bottom edge, with the shadow it casts on them. Its body is
// a small desk (InspectorDesk), which takes Tab and Shift+Tab itself; Tab
// from outside meets a stop before or after it and goes to the desk's
// start. Esc that no control took emits `escaped`. Clicks on it never reach
// the boards. Its children are the body, xl all round (PREFS-133);
// `bodyHeight` sizes it.
BorderSurface {
    id: panel
    // The Layout page, as InkIcon takes it: the theme and the Animations switch.
    required property var layout
    // Its desk: where focus starts.
    required property Item desk
    property bool shown: false
    property real bodyHeight: 0
    default property alias content: body.data
    signal escaped
    // Focus on the desk's start (Enter on a chip, PREFS-101).
    function focusFirst() {
        if (desk.visible)
            desk.focusFirst();
    }
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: Math.min(parent.width, Style.space(670))
    height: bodyHeight + 2 * Gap.xl
    z: 120
    radius: Round.container
    color: Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, 0.065))
    borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.16), 1)
    // Visible from the moment it is shown, so focus can go in before the
    // fade's first frame.
    visible: shown || opacity > 0
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.97
    transformOrigin: Item.Bottom
    Behavior on opacity {
        enabled: panel.layout.bar.animationsEnabled
        NumberAnimation {
            duration: MotionModel.APPEAR_MS
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        enabled: panel.layout.bar.animationsEnabled
        NumberAnimation {
            duration: MotionModel.APPEAR_SCALE_MS
            easing.type: Easing.OutCubic
        }
    }
    // A control that takes Esc gets it first (an open dropdown, a text field).
    Keys.onPressed: function (event) {
        if (event.key !== Qt.Key_Escape)
            return;
        panel.escaped();
        event.accepted = true;
    }
    // Tab from outside meets one of these stops: on to the desk's start.
    Item {
        activeFocusOnTab: panel.shown
        onActiveFocusChanged: if (activeFocus)
            panel.focusFirst()
    }
    MouseArea {
        anchors.fill: parent
    }
    // The shadow it casts on the plates.
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.topMargin: Style.space(10)
        anchors.bottomMargin: -Style.space(10)
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        radius: panel.radius
        color: Ink.band(panel.layout.lightTheme)
    }
    Item {
        id: body
        anchors.fill: parent
    }
    Item {
        activeFocusOnTab: panel.shown
        onActiveFocusChanged: if (activeFocus)
            panel.focusFirst()
    }
}
