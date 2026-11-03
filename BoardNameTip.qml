import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "MotionModel.js" as MotionModel

// A chip's (or a face's, a "+"'s) full name after a short rest on it
// (PREFS-100): a rest of TIP_REST_MS the first time, and at once while one
// has shown in the last TIP_WARM_MS. It never shows during a lift. The page
// calls hover() from its pointer and says what to show and where in
// describe(); the tip sits inside its parent, the page.
BorderSurface {
    id: tip
    // The Layout page, as InkIcon takes it: the icon and the Animations switch.
    required property var layout
    // A lift is on: the tip hides and stays hidden.
    property bool suppressed: false
    // describe(subject) -> { record, below, above, title?, detail? }, or null to
    // leave the tip as it is. Called when the tip shows, so it reads geometry
    // and the pointer as they are then. `below` is the tip's top-centre when
    // it fits under, `above` its bottom-centre when it does not. A caller
    // that binds `title` and `detail` itself leaves them out.
    property var describe: null
    // Place the tip once as it shows, from its size then (the Layout page),
    // or keep it placed from its size as that changes (the Groups page).
    property bool placeOnce: false
    property bool shown: false
    property var record: ({})
    property string title: ""
    property string detail: ""
    property point below: Qt.point(0, 0)
    property point above: Qt.point(0, 0)
    property var hoveredId: null
    property var hoveredSubject: null
    property bool warm: false
    readonly property real placedX: Math.max(0, Math.min(parent.width - width, below.x - width / 2))
    readonly property real placedY: below.y + height <= parent.height ? below.y : above.y - height
    // What the pointer rests on: `id` says whether it moved (compared with
    // ===; null or "" is nothing), `subject` is handed to describe().
    function hover(id, subject) {
        id = id || null;
        if (id === hoveredId)
            return;
        hoveredId = id;
        hoveredSubject = id ? subject : null;
        if (!id || suppressed) {
            shown = false;
            delay.stop();
            if (warm)
                cool.restart();
            return;
        }
        cool.stop();
        if (warm)
            show();
        else {
            shown = false;
            delay.restart();
        }
    }
    function show() {
        if (!hoveredSubject || suppressed)
            return;
        var d = describe(hoveredSubject);
        if (!d)
            return;
        record = d.record;
        if (d.title !== undefined)
            title = d.title;
        if (d.detail !== undefined)
            detail = d.detail;
        below = d.below;
        above = d.above;
        if (placeOnce) {
            x = placedX;
            y = placedY;
        }
        shown = true;
        warm = true;
    }
    onSuppressedChanged: if (suppressed)
        hover(null)
    Binding on x {
        when: !tip.placeOnce
        value: tip.placedX
    }
    Binding on y {
        when: !tip.placeOnce
        value: tip.placedY
    }
    Timer {
        id: delay
        interval: MotionModel.TIP_REST_MS
        onTriggered: tip.show()
    }
    Timer {
        id: cool
        interval: MotionModel.TIP_WARM_MS
        onTriggered: tip.warm = false
    }
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity {
        enabled: tip.layout.bar.animationsEnabled
        NumberAnimation {
            duration: MotionModel.TIP_FADE_MS
            easing.type: Easing.OutCubic
        }
    }
    // A surface over the page, not a chip (PREFS-133): m above and below, l
    // at the sides, one step past its own m gaps.
    width: tipRow.implicitWidth + 2 * Gap.l
    height: tipRow.implicitHeight + 2 * Gap.m
    radius: Round.container
    color: Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, 0.1))
    borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.16), 1)
    Row {
        id: tipRow
        anchors.centerIn: parent
        spacing: Gap.m
        InkIcon {
            visible: !!tip.record.instanceKey
            layout: tip.layout
            record: tip.record
            anchors.verticalCenter: parent.verticalCenter
        }
        InkText {
            anchors.verticalCenter: parent.verticalCenter
            text: tip.title
        }
        InkText {
            visible: text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: tip.detail
            role: "caption"
        }
    }
}
