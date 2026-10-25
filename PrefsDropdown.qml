import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Omarchy's Dropdown (qs.Ui Dropdown.qml), the same trigger and popup, with
// the popup opening above the trigger when `opensUp` (the Layout page's
// inspector sits at the window's bottom, where the kit's popup, always
// below, would open off-screen). The kit's has no placement of its own.
// Keyboard as the kit's: Tab to the trigger, Enter, Space or Down opens, j/k
// or Up/Down walk the options, Enter picks, Esc closes. `keyHints` name the
// keys for the page's legend on the trigger, `listHints` while it is open.
Item {
    id: root

    property string label: ""
    property string value: ""
    property var options: []
    property bool opensUp: true
    property string openLabel: "Open"

    property color foreground: Commons.Color.popups.text
    property color background: Commons.Color.popups.background
    property color popupBorder: Commons.Color.popups.border
    property color accent: Commons.Color.accent
    readonly property var popupBorderSpec: Border.localOrSurfaceSpec("popups", "border", popupBorder, Commons.Color.popups.border, Style.normalBorderWidth)
    property string fontFamily: Style.font.family
    property int rowHeight: Style.spacing.controlHeight
    property int popupRowHeight: Style.spacing.popupRowHeight
    property bool showLabel: true

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
    function open() {
        popup.open();
    }
    function close() {
        popup.close();
    }
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
    implicitHeight: showLabel && label !== "" ? rowHeight + Style.spacing.huge : rowHeight

    Column {
        anchors.fill: parent
        spacing: Style.spacing.labelGap

        Text {
            textFormat: Text.PlainText
            visible: root.showLabel && root.label !== ""
            text: root.label
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
        }

        BorderSurface {
            id: trigger
            width: parent.width
            height: root.rowHeight
            radius: Style.cornerRadius

            readonly property bool focusedNow: trigger.activeFocus
            readonly property bool hot: triggerHover.hovered
            readonly property var keyHints: [
                {
                    keys: "space",
                    label: root.openLabel
                }
            ]

            color: Style.controlFill(trigger.focusedNow, trigger.hot, root.foreground, root.accent)
            borderSpec: Border.controlSpec(trigger.focusedNow ? "focus" : (trigger.hot ? "hover-cursor" : "normal"), root.foreground, root.accent)

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

            Text {
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.right: chevron.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: trigger.borderLeft + Style.spacing.controlPaddingX
                anchors.rightMargin: trigger.borderRight + Style.spacing.md
                text: root.currentLabel()
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
            }

            Text {
                id: chevron
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: trigger.borderRight + Style.spacing.controlGap
                text: root.opensUp ? "󰅃" : "󰅀"
                color: Qt.darker(root.foreground, 1.2)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
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
                y: root.opensUp ? -height - Style.spacing.xxs : trigger.height + Style.spacing.xxs
                width: trigger.width
                implicitHeight: Math.min(root.options.length * root.popupRowHeight + Math.max(0, root.options.length - 1) * Style.spacing.labelGap + Style.spacing.xxs, root.popupRowHeight * 8 + 7 * Style.spacing.labelGap + Style.spacing.xxs)
                padding: Style.spacing.hairline
                leftPadding: Border.left(root.popupBorderSpec) + Style.spacing.hairline
                rightPadding: Border.right(root.popupBorderSpec) + Style.spacing.hairline
                topPadding: Border.top(root.popupBorderSpec) + Style.spacing.hairline
                bottomPadding: Border.bottom(root.popupBorderSpec) + Style.spacing.hairline
                focus: true

                background: BorderSurface {
                    color: root.background
                    borderSpec: root.popupBorderSpec
                    radius: Style.cornerRadius
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
                        height: root.popupRowHeight
                        color: index === optionList.currentIndex ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"

                        Text {
                            textFormat: Text.PlainText
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Style.spacing.controlPaddingX
                            anchors.rightMargin: Style.spacing.controlPaddingX
                            text: root.optionLabel(parent.modelData)
                            color: parent.index === optionList.currentIndex ? Style.hoverStateColor(root.foreground, root.accent) : root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
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
}
