import QtQuick
import qs.Commons
import qs.Commons as Commons

// The layers as a list of sheets, seen in the Layout page's perspective: the
// chosen one filled (docs/behavior/preferences.md PREFS-26). One Tab stop; j
// and k (or the arrows) choose the next layer down or up at once, a click
// chooses one. The Layout page's inspector and the Groups page's use it.
Item {
    id: picker
    property string value: ""
    property bool withTray: false
    property bool animate: true
    signal chosen(string value)
    readonly property var options: [
        {
            value: "shown",
            label: "On the bar"
        },
        {
            value: "managed",
            label: "On demand"
        },
        {
            value: "hidden",
            label: "Hidden"
        }
    ].concat(withTray ? [
        {
            value: "tray",
            label: "In the tray"
        }
    ] : [])
    readonly property var keyHints: [
        {
            keys: "j k",
            label: "Down or up a layer"
        }
    ]
    activeFocusOnTab: true
    implicitHeight: rows.implicitHeight
    Accessible.role: Accessible.List
    Accessible.name: "Layer"
    function step(dy) {
        var i = options.findIndex(function (o) {
            return o.value === picker.value;
        });
        var next = Math.max(0, Math.min(options.length - 1, i + dy));
        if (next !== i)
            chosen(options[next].value);
    }
    Keys.onPressed: function (event) {
        var t = event.text;
        if (event.key === Qt.Key_Down || t === "j")
            step(1);
        else if (event.key === Qt.Key_Up || t === "k")
            step(-1);
        else
            return;
        event.accepted = true;
    }
    Column {
        id: rows
        width: parent.width
        // A field (PREFS-133): its label, xxs, then its rows a control tall
        // and xs apart.
        spacing: Gap.xs
        InkText {
            text: "Layer"
            bottomPadding: Gap.xxs - Gap.xs
        }
        Repeater {
            model: picker.options
            Rectangle {
                id: row
                required property var modelData
                readonly property bool chosen: modelData.value === picker.value
                width: rows.width
                height: Gap.control
                radius: Round.control
                color: chosen ? Qt.alpha(Commons.Color.accent, 0.28) : rowMouse.containsMouse ? Qt.alpha(Commons.Color.popups.text, 0.06) : "transparent"
                Behavior on color {
                    enabled: picker.animate
                    ColorAnimation {
                        duration: 90
                    }
                }
                // The sheet, seen in the layers' perspective.
                // Its slant's foot s in from the row's edge.
                Rectangle {
                    id: sheet
                    x: Gap.s + Math.round(0.84 * height)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(34)
                    height: Style.space(10)
                    radius: Round.small
                    color: row.chosen ? Commons.Color.accent : "transparent"
                    border.width: 1
                    border.color: row.chosen ? Qt.alpha(Commons.Color.accent, 0.9) : Qt.alpha(Commons.Color.popups.text, 0.4)
                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(1, -0.84, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    }
                }
                InkText {
                    x: sheet.x + sheet.width + Gap.m
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.chosen(row.modelData.value)
                }
            }
        }
    }
}
