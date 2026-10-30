import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Omarchy's Dropdown (qs.Ui Dropdown.qml), the same trigger and popup, with
// the popup opening above the trigger (the Layout page's inspector sits at
// the window's bottom, where the kit's popup, always below, would open
// off-screen). The kit's has no placement of its own. Keyboard as the kit's:
// Tab to the trigger, Enter, Space or Down opens, j/k or Up/Down walk the
// options, Enter picks, Esc closes. `keyHints` name the keys for the page's
// legend on the trigger, `listHints` while it is open. `label` names it for
// accessibility; the field draws no label.
Item {
    id: root

    property string label: ""
    property string value: ""
    property var options: []
    property string openLabel: "Open"
    readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", Commons.Color.popups.border, Commons.Color.popups.border, Style.normalBorderWidth)

    readonly property bool popupOpen: popup.opened
    // The keys while the list is open, for the page's legend.
    readonly property var listHints: [
        {
            keys: "j k",
            label: "Walk the options"
        },
        {
            keys: "enter",
            label: "Choose"
        },
        {
            keys: "esc",
            label: "Close"
        }
    ]
    function toggle() {
        popup.opened ? popup.close() : popup.open();
    }

    signal changed(string value)

    function optionValue(o) {
        return (o && typeof o === "object") ? String(o.value) : String(o);
    }
    function optionLabel(o) {
        return (o && typeof o === "object") ? String(o.label) : String(o);
    }
    function currentLabel() {
        for (var i = 0; i < options.length; i++) {
            if (optionValue(options[i]) === value)
                return optionLabel(options[i]);
        }
        return value;
    }

    implicitWidth: Style.spacing.dropdownWidth
    implicitHeight: Gap.control

    BorderSurface {
        id: trigger
        width: parent.width
        height: Gap.control
        radius: Round.control

        readonly property bool focusedNow: trigger.activeFocus
        readonly property bool hot: triggerHover.hovered
        readonly property var keyHints: [
            {
                keys: "space",
                label: root.openLabel
            }
        ]

        color: Style.controlFill(trigger.focusedNow, trigger.hot, Commons.Color.popups.text, Commons.Color.accent)
        borderSpec: Border.controlSpec(trigger.focusedNow ? "focus" : (trigger.hot ? "hover-cursor" : "normal"), Commons.Color.popups.text, Commons.Color.accent)

        activeFocusOnTab: true
        Accessible.role: Accessible.ComboBox
        Accessible.name: root.label + ": " + root.currentLabel()

        HoverHandler {
            id: triggerHover
        }

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                root.toggle();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape && popup.opened) {
                popup.close();
                event.accepted = true;
            }
        }

        InkText {
            anchors.left: parent.left
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: trigger.borderLeft + Gap.s
            anchors.rightMargin: Gap.m
            text: root.currentLabel()
            color: Commons.Color.popups.text
            elide: Text.ElideRight
        }

        GrayText {
            id: chevron
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: trigger.borderRight + Gap.s
            text: "󰅃"
            color: Qt.alpha(Commons.Color.popups.text, Ink.secondary)
            font.family: Style.font.family
            font.pixelSize: Ink.label
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                trigger.forceActiveFocus();
                root.toggle();
            }
        }

        Popup {
            id: popup
            x: 0
            y: -height - Style.spacing.xxs
            width: trigger.width
            implicitHeight: Math.min(root.options.length * Gap.control + Math.max(0, root.options.length - 1) * Style.spacing.labelGap + Style.spacing.xxs, Gap.control * 8 + 7 * Style.spacing.labelGap + Style.spacing.xxs)
            padding: Style.spacing.hairline
            leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
            rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
            topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
            bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
            focus: true

            background: BorderSurface {
                color: Commons.Color.popups.background
                borderSpec: root.popupBorderSpec
                radius: Round.container
            }

            onOpened: {
                optionList.currentIndex = Math.max(0, optionList.indexOfValue(root.value));
                optionList.forceActiveFocus();
            }
            contentItem: ListView {
                id: optionList
                spacing: Style.spacing.labelGap

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Escape) {
                        popup.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.text === "j") {
                        optionList.currentIndex = Math.min(root.options.length - 1, optionList.currentIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.text === "k") {
                        optionList.currentIndex = Math.max(0, optionList.currentIndex - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        optionList.selectCurrent();
                        event.accepted = true;
                    }
                }
                implicitHeight: contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.options
                currentIndex: -1

                function indexOfValue(v) {
                    for (var i = 0; i < root.options.length; i++)
                        if (root.optionValue(root.options[i]) === v)
                            return i;
                    return -1;
                }

                function selectCurrent() {
                    if (currentIndex < 0 || currentIndex >= root.options.length)
                        return;
                    var v = root.optionValue(root.options[currentIndex]);
                    root.value = v;
                    root.changed(v);
                    popup.close();
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: optionList.width
                    height: Gap.control
                    color: index === optionList.currentIndex ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"

                    GrayText {
                        textFormat: Text.PlainText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Gap.s
                        anchors.rightMargin: Gap.s
                        text: root.optionLabel(parent.modelData)
                        color: parent.index === optionList.currentIndex ? Style.hoverStateColor(Commons.Color.popups.text, Commons.Color.accent) : Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Ink.label
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: optionList.currentIndex = parent.index
                        onClicked: optionList.selectCurrent()
                    }
                }
            }
        }
    }
}
