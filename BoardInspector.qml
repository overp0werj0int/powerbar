import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "BoardModel.js" as Board
import "MotionModel.js" as MotionModel

// The inspector on a board page (PREFS-101, PREFS-26): a surface at the
// page's bottom right, in front of the plates, fading and growing in from
// 97 % about its bottom edge, with the shadow it casts on them. Tab and
// Shift+Tab walk its controls and wrap round inside it: a stop before
// `first` and one after the last control send focus on round, because Qt
// walks Tab itself and the stops are where it can be met. Esc that no
// control took emits `escaped`. Clicks on it never reach the boards. Its
// children are the body, xl all round (PREFS-133); `bodyHeight` sizes it.
BorderSurface {
    id: panel
    // The Layout page, as InkIcon takes it: the theme and the Animations switch.
    required property var layout
    // Where Tab starts and wraps to.
    required property Item first
    property bool shown: false
    property real bodyHeight: 0
    default property alias content: body.data
    signal escaped
    // The control focus was last on inside, for the fences.
    property Item lastInside: null
    readonly property Item focused: panel.Window.activeFocusItem
    // Focus on the first control, as Tab would (Enter on a chip, PREFS-101).
    function focusFirst() {
        first.forceActiveFocus(Qt.TabFocusReason);
    }
    // The last control in Tab order inside the panel.
    function lastControl() {
        var last = first;
        for (var item = first.nextItemInFocusChain(true); item && item !== endFence && item !== first && Board.within(item, panel); item = item.nextItemInFocusChain(true))
            last = item;
        return last;
    }
    onFocusedChanged: {
        if (focused && focused !== startFence && focused !== endFence && Board.within(focused, panel))
            lastInside = focused;
    }
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: Math.min(parent.width, Style.space(670))
    height: bodyHeight + 2 * Gap.xl
    z: 120
    radius: Round.container
    color: Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, 0.065))
    borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.16), 1)
    visible: opacity > 0
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
    // Shift+Tab from the first control meets this stop: on to the last.
    // Tab from outside meets it first: on to the first.
    Item {
        id: startFence
        activeFocusOnTab: panel.shown
        onActiveFocusChanged: if (activeFocus)
            (panel.lastInside === panel.first ? panel.lastControl() : panel.first).forceActiveFocus(Qt.TabFocusReason)
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
    // The caller's children sit between the fences, so the Tab chain runs
    // through them in order.
    Item {
        id: body
        anchors.fill: parent
    }
    Item {
        id: endFence
        activeFocusOnTab: panel.shown
        onActiveFocusChanged: if (activeFocus)
            (panel.lastInside === panel.lastControl() ? panel.first : panel.lastControl()).forceActiveFocus(Qt.TabFocusReason)
    }
}
