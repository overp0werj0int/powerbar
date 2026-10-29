import QtQuick
import qs.Commons
import qs.Commons as Commons

// One layer's plate on the Layout and Groups pages (docs/behavior/
// preferences.md PREFS-99): tilted back about its top edge, seen from
// planeDistance, with the layer's name and what it is in the first of the
// seven columns (PreferencesModel.layerColumns) and how many it holds in the
// last, on the caption's line and in its size. Place the tiles in it as
// children, in its own coordinates (they turn with it). The page sets its
// width and height (the plate's own, before the tilt).
Item {
    id: face
    // The seven columns and the plate's side padding.
    property var columns: ({
            xs: [0, 0, 0, 0, 0, 0, 0],
            widths: [0, 0, 0, 0, 0, 0, 0]
        })
    property real pad: 0
    // The camera's axis in the plate: the line the tilt is seen about.
    property real axisX: width / 2
    property real tilt: 34
    property real planeDistance: 1600
    property bool animate: true
    property string title: ""
    property string caption: ""
    property string count: ""
    // Where the label column ends, for what a page puts under it.
    readonly property real labelBottom: labelColumn.y + labelColumn.height
    readonly property real labelX: labelColumn.x
    readonly property real labelWidth: labelColumn.width
    // It turns about its top edge, which stays at the plate's top with
    // everything near it while the height animates, so a layer only ever
    // grows or shrinks downward.
    y: 0
    transform: Rotation {
        axis {
            x: 1
            y: 0
            z: 0
        }
        origin.x: face.axisX
        origin.y: 0
        distanceToPlane: face.planeDistance
        angle: face.tilt
    }
    Behavior on height {
        enabled: face.animate
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Column {
        id: labelColumn
        // In line with the zones' names: a tile's padding down, a text pair
        // (PREFS-133).
        x: face.pad + face.columns.xs[0]
        y: Gap.m
        width: face.columns.widths[0]
        spacing: Gap.xxs
        InkText {
            width: parent.width
            text: face.title
            role: "section"
            elide: Text.ElideRight
        }
        InkText {
            id: captionText
            width: parent.width
            text: face.caption
            role: "caption"
            wrapMode: Text.WordWrap
        }
    }
    InkText {
        x: face.pad + face.columns.xs[6]
        y: labelColumn.y + captionText.y
        width: face.columns.widths[6] - Style.space(2)
        horizontalAlignment: Text.AlignRight
        text: face.count
        role: "caption"
    }
}
