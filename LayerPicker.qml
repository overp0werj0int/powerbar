import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import QtQuick.Layouts
import "MotionModel.js" as MotionModel

// The layers as a list of sheets, seen in the Layout page's perspective: the
// chosen one filled (docs/behavior/preferences.md PREFS-26). On a desk strip
// (DeskStrip) each layer is a row the cursor rests on, as a pick group's
// rows are (DeskPickGroup): j/k walk them with the rest of the strip, Space
// or Enter moves the widget there, a click too. The Layout page's inspector
// and the Groups page's use it.
Item {
    id: picker
    property string value: ""
    property bool withTray: false
    property bool animate: true
    signal chosen(string value)
    // The desk walks the rows.
    readonly property bool deskGroup: true
    property var controls: []
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
    implicitHeight: rows.implicitHeight
    Layout.fillWidth: true
    Accessible.role: Accessible.List
    Accessible.name: "Layer"
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
            onItemAdded: function (index, item) {
                picker.controls = picker.controls.concat([item]).sort(function (a, b) {
                    return a.index - b.index;
                });
            }
            onItemRemoved: function (index, item) {
                picker.controls = picker.controls.filter(function (r) {
                    return r !== item;
                });
            }
            BorderSurface {
                id: row
                required property var modelData
                required property int index
                readonly property bool chosen: modelData.value === picker.value
                readonly property int deskStops: 1
                readonly property int deskHome: 0
                function deskFocus(stop, reason) {
                    forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
                }
                readonly property var keyHints: [
                    {
                        keys: "space",
                        label: "Move it to this layer"
                    }
                ]
                width: rows.width
                height: Gap.control
                radius: Round.control
                activeFocusOnTab: false
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.label
                Accessible.checked: chosen
                color: activeFocus ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent) : chosen ? Qt.alpha(Commons.Color.accent, 0.28) : rowMouse.containsMouse ? Qt.alpha(Commons.Color.popups.text, 0.06) : "transparent"
                borderSpec: activeFocus ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
                Keys.onPressed: function (event) {
                    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                        return;
                    if (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                        return;
                    if (!row.chosen)
                        picker.chosen(row.modelData.value);
                    event.accepted = true;
                }
                Behavior on color {
                    enabled: picker.animate
                    ColorAnimation {
                        duration: MotionModel.FILL_MS
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
                    onClicked: {
                        row.forceActiveFocus(Qt.MouseFocusReason);
                        if (!row.chosen)
                            picker.chosen(row.modelData.value);
                    }
                }
            }
        }
    }
}
