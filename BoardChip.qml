import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A widget's chip on a board (the Layout and Groups pages, PREFS-22,
// PREFS-104): its icon, its name (elided) and, for a group, its member
// count. The cursor's chip rises off its tile, casting a band on it; a press
// dips it; a landing place or a pulled-out chip's own place is an accent
// outline; the copy a lift carries and the inspector's pulled-out copy sit
// flat in front. The page says which of those it is, and its cursor, hover
// and press, through an adapter (`component Tile: BoardChip`); the chip
// decides how each looks.
Item {
    id: chip
    // The Layout page, as InkIcon takes it: the icon, the title
    // (layout.preferences.title), the theme and the Animations switch.
    required property var layout
    property var record: ({})
    // A landing place.
    property bool placeholder: false
    // The copy a lift carries.
    property bool ghost: false
    // The inspector's pulled-out copy.
    property bool pulled: false
    // Its place while the inspector has it.
    property bool pulledOut: false
    // A group's members; 0 draws no pill.
    property int count: 0
    property bool isCursor: false
    property bool hovered: false
    property bool pressedDown: false
    // The board has the keys: the cursor's chip wears the focus ring.
    property bool boardFocused: false
    // A pointer lift: a landing place shows nothing inside.
    property bool pointerCarry: false
    // Its content at Ink.secondary.
    property bool dimmed: false
    // The tile under it is a lead one (a slightly lighter base).
    property bool leadTile: true
    property real riseHeight: Style.space(8)
    // A flat copy casts the 6 px band.
    property bool shadowed: ghost || pulled
    readonly property bool outline: placeholder || pulledOut
    readonly property bool raised: isCursor && !outline
    readonly property real raise: lift.value
    readonly property color pageColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    // It grows with its lift, to 103 % at the top, and shrinks with it:
    // nothing of the cursor's state lingers once the cursor has gone.
    scale: pressedDown ? 0.97 : 1 + 0.03 * (lift.height > 0 ? raise / lift.height : 0)
    Rise {
        id: lift
        up: chip.raised
        height: chip.riseHeight
        animate: chip.layout.bar.animationsEnabled
    }
    transform: Translate {
        y: -chip.raise
    }
    // Over its neighbours while it is up.
    z: raised || raise > 0 ? 1 : 0
    // The shadow a flat or raised chip casts on its tile, as far below it as
    // it has risen: one flat band in the chip's shape, as a slab's edge and
    // the inspector's shadow are (PREFS-104). Lighter on a light theme.
    // Only the band under the chip is drawn, from its bottom edge down, half
    // a pixel in from each side so none of it shows past the chip's ring
    // along its sides, square at the top and rounded at the bottom, as a
    // tile's edge is (ZoneTile).
    Rectangle {
        visible: chip.shadowed || chip.raise > 0
        x: 0.5
        y: parent.height
        width: parent.width - 1
        height: chip.shadowed ? Style.space(6) : chip.raise + Style.space(3)
        radius: Round.control
        topLeftRadius: 0
        topRightRadius: 0
        antialiasing: true
        color: Ink.band(chip.layout.lightTheme)
    }
    // The fill, and under a raised chip its tile's own colour, so what it
    // rises over does not show through.
    readonly property color fill: outline ? "transparent" : ghost || pulled ? Qt.tint(pageColor, Qt.alpha(Commons.Color.popups.text, 0.15)) : isCursor && boardFocused ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent) : isCursor ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent) : hovered ? Qt.alpha(Commons.Color.popups.text, 0.14) : Qt.alpha(Commons.Color.popups.text, 0.06)
    readonly property color base: Qt.tint(pageColor, Qt.alpha(Commons.Color.popups.text, leadTile ? 0.09 : 0.065))
    BorderSurface {
        anchors.fill: parent
        antialiasing: true
        radius: Round.control
        color: chip.raised ? Qt.tint(chip.base, chip.fill) : chip.fill
        borderSpec: chip.outline || chip.ghost || chip.pulled ? Border.flat(Commons.Color.accent, Math.max(1, Math.round(Style.space(1.5)))) : chip.isCursor && chip.boardFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : chip.isCursor ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1) : Border.none()
    }
    Row {
        id: content
        x: Gap.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: Gap.m
        // A keyboard lift shows what it carries in its outline; a pointer lift
        // carries it under the pointer, the inspector pulls it out in front.
        opacity: chip.outline ? (chip.placeholder && !chip.pointerCarry ? 0.5 : 0) : chip.dimmed ? Ink.secondary : 1
        InkIcon {
            id: icon
            layout: chip.layout
            record: chip.record
            anchors.verticalCenter: parent.verticalCenter
        }
        InkText {
            text: chip.record && chip.record.instanceKey ? chip.layout.preferences.title(chip.record) : ""
            elide: Text.ElideRight
            width: Math.max(Style.space(16), chip.width - 2 * Gap.s - icon.width - content.spacing - (chip.count > 0 ? pill.width + content.spacing : 0))
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            id: pill
            visible: chip.count > 0
            width: pillLabel.implicitWidth + 2 * Gap.s
            height: Ink.line(Ink.caption)
            radius: height / 2
            color: Qt.alpha(Commons.Color.popups.text, 0.12)
            anchors.verticalCenter: parent.verticalCenter
            InkText {
                id: pillLabel
                anchors.centerIn: parent
                text: chip.count
                role: "caption"
                tier: 1
            }
        }
    }
}
