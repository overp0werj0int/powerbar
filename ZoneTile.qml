import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PreferencesModel.js" as Model

// A zone's tile on a layer plate (LayerPlate), as the Layout and Groups pages
// draw it (docs/behavior/preferences.md PREFS-99, PREFS-106): its slab edge,
// its surface, the camera's cap and shade over it on Center (BeamShade,
// continuing CameraShaft's), the zone's name at its top, an empty note, and a window of
// rows that scrolls when the tile has more than its layer gives it, with
// fades over the rows cut at its edges and a hairline thumb. A dashed tile
// (the tray's) has no surface or edge. The page fills the window through
// `model` (a Repeater's) and adds its own children over it.
Item {
    id: cell
    property bool animate: true
    property bool lightTheme: false
    // The tray's look: a dashed edge, no surface.
    property bool dashed: false
    property bool dashLit: false
    // The surface: the bar layer's a little stronger.
    property bool lead: false
    property var borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.12), 1)
    property real pad: Style.space(8)
    property real radius: Math.min(Style.space(10), Style.cornerRadius)
    property real topRadius: radius
    // How far it rises off its layer (the cursor's tile, PREFS-104).
    property real raise: 0
    Behavior on raise {
        enabled: cell.animate
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
    transform: Translate {
        y: -cell.raise
    }
    // The camera's cap and shade over the part `shadeX` and `shadeWidth`
    // wide (the camera's column); seenTop is where the plate's top is seen and `line`
    // the line the camera's plane turns about, both in the page.
    property Item camera: null
    property bool shaded: false
    property real shadeX: 0
    property real shadeWidth: width
    // The shade past the column's sides (Tuning's shadeSpread, PREFS-24) on
    // every tile it reaches, cut to the tile, as on the desks' strips: the
    // column at beamX, beamWidth wide, in the tile's coordinates.
    property bool spillShown: false
    property real beamX: shadeX
    property real beamWidth: shadeWidth
    property real seenTop: 0
    property real line: 0
    property real tilt: 34
    property real planeDistance: 1600
    // The zone's name at the top.
    property string name: ""
    property bool nameShown: true
    property bool nameActive: false
    property bool nameBold: false
    property real nameRow: Style.space(20)
    // A note while it holds nothing.
    property string emptyText: ""
    property bool emptyShown: false
    property real emptyY: pad + nameRow
    property bool focusOutline: false
    // The window: where it starts and how much it keeps clear at the
    // bottom, its rows (perRow to a row, chipHeight tall, `spacing` apart,
    // flowWidth wide) and how bright the thumb is.
    property real viewTop: pad + nameRow
    property real viewBottom: Style.space(2)
    property real chipHeight: Style.space(24)
    property real spacing: Style.space(3)
    property real flowWidth: Math.max(1, width - 2 * pad)
    property int perRow: 1
    property bool current: false
    property alias model: chipTiles.model
    readonly property alias tiles: chipTiles
    readonly property color surfaceColor: well.color

    // The slab's thickness, below it, the same on every tile: a raised
    // tile takes its edge with it. Edges under the tilt are drawn
    // antialiased, or they step.
    Rectangle {
        visible: !cell.dashed
        y: Style.space(6)
        width: parent.width
        height: parent.height
        radius: cell.radius
        topLeftRadius: cell.topRadius
        topRightRadius: cell.topRadius
        antialiasing: true
        color: Qt.rgba(0, 0, 0, cell.lightTheme ? 0.3 : 0.45)
    }
    BorderSurface {
        id: well
        anchors.fill: parent
        antialiasing: true
        radius: cell.radius
        topLeftRadius: cell.topRadius
        topRightRadius: cell.topRadius
        color: cell.dashed ? "transparent" : Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, cell.lead ? 0.09 : 0.065))
        borderSpec: cell.dashed ? Border.none() : cell.borderSpec
    }
    Item {
        id: spillClip
        readonly property real reach: Tuning.values.shadeSpread * Style.space(1)
        visible: cell.spillShown && !!cell.camera && reach > 0 && cell.beamX + cell.beamWidth + reach > 0 && cell.beamX - reach < cell.width
        anchors.fill: parent
        clip: true
        BeamShade {
            spill: 1
            outer: spillClip.reach
            colWidth: cell.beamWidth
            tilt: cell.tilt
            planeDistance: cell.planeDistance
            lightTheme: cell.camera ? cell.camera.lightTheme : false
            x: cell.beamX - spillClip.reach
            width: cell.beamWidth + 2 * spillClip.reach
            height: parent.height
            vTop: Model.tiltedDepth(cell.seenTop - cell.line, cell.tilt, cell.planeDistance)
            vBottom: Model.tiltedDepth(cell.seenTop + Model.tiltedHeight(cell.height, cell.tilt, cell.planeDistance) - cell.line, cell.tilt, cell.planeDistance)
        }
    }
    // The torn cap's shade (and the tear, where it reaches the tile) over
    // its surface and under its rows, continuing what the gaps show.
    BeamShade {
        visible: cell.shaded && !!cell.camera
        tilt: cell.tilt
        planeDistance: cell.planeDistance
        lightTheme: cell.camera ? cell.camera.lightTheme : false
        x: cell.shadeX
        width: cell.shadeWidth
        height: parent.height
        vTop: Model.tiltedDepth(cell.seenTop - cell.line, cell.tilt, cell.planeDistance)
        vBottom: Model.tiltedDepth(cell.seenTop + Model.tiltedHeight(cell.height, cell.tilt, cell.planeDistance) - cell.line, cell.tilt, cell.planeDistance)
    }
    // The dashed edge.
    Shape {
        visible: cell.dashed
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(Commons.Color.popups.text, cell.dashLit ? 0.6 : 0.3)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: "transparent"
            startX: cell.radius
            startY: 0.5
            PathLine {
                x: cell.width - cell.radius
                y: 0.5
            }
            PathArc {
                x: cell.width - 0.5
                y: cell.radius
                radiusX: cell.radius
                radiusY: cell.radius
            }
            PathLine {
                x: cell.width - 0.5
                y: cell.height - cell.radius
            }
            PathArc {
                x: cell.width - cell.radius
                y: cell.height - 0.5
                radiusX: cell.radius
                radiusY: cell.radius
            }
            PathLine {
                x: cell.radius
                y: cell.height - 0.5
            }
            PathArc {
                x: 0.5
                y: cell.height - cell.radius
                radiusX: cell.radius
                radiusY: cell.radius
            }
            PathLine {
                x: 0.5
                y: cell.radius
            }
            PathArc {
                x: cell.radius
                y: 0.5
                radiusX: cell.radius
                radiusY: cell.radius
            }
        }
    }

    Text {
        visible: cell.nameShown
        x: cell.pad + Style.space(2)
        y: cell.pad
        z: 3
        width: cell.width - x - cell.pad
        text: cell.name
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, cell.nameActive ? 0.9 : 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: cell.nameBold ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
    }
    Text {
        x: cell.pad + Style.space(2)
        y: cell.emptyY
        visible: cell.emptyShown
        text: cell.emptyText
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.3)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
    }
    BorderSurface {
        anchors.fill: parent
        anchors.margins: Style.space(3)
        visible: cell.focusOutline
        antialiasing: true
        color: "transparent"
        radius: Math.max(0, cell.radius - Style.space(3))
        borderSpec: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
    }
    // The rows, in a window that scrolls when the tile has more rows than
    // its layer gives it (PREFS-106). The window reaches a little above the
    // first row and past the rows' sides, so a raised row is not cut; a thin
    // thumb at the tile's right edge shows where it is, and the tile's colour
    // fades over the rows cut at its edges.
    readonly property real rowStep: chipHeight + spacing
    readonly property real room: Style.space(10)
    readonly property real viewHeight: Math.max(0, cell.height - viewTop - viewBottom)
    readonly property real contentHeight: chipFlow.implicitHeight
    readonly property real maxScroll: Math.max(0, contentHeight - viewHeight)
    readonly property bool overflows: maxScroll > 0.5
    property real scroll: 0
    Behavior on scroll {
        enabled: cell.animate
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
    onMaxScrollChanged: if (scroll > maxScroll)
        scroll = maxScroll
    function scrollBy(dy) {
        scroll = Math.max(0, Math.min(maxScroll, scroll + dy));
    }
    // Row `pos` in view, with the room a raised row takes above it.
    function reveal(pos) {
        if (!overflows)
            return;
        var row = Math.floor(pos / Math.max(1, perRow));
        var top = row * rowStep, bottom = top + chipHeight;
        if (top - room < scroll)
            scroll = Math.max(0, top - room);
        else if (bottom > scroll + viewHeight)
            scroll = Math.min(maxScroll, bottom - viewHeight);
    }
    function viewContains(p) {
        return p.y >= viewTop - room && p.y < viewTop + viewHeight;
    }
    Item {
        id: viewport
        x: cell.pad - Style.space(4)
        y: cell.viewTop - cell.room
        width: cell.width - 2 * cell.pad + 2 * Style.space(4)
        height: cell.viewHeight + cell.room
        clip: true
        Flow {
            id: chipFlow
            x: Style.space(4)
            y: cell.room - cell.scroll
            width: cell.flowWidth
            spacing: cell.spacing
            Repeater {
                id: chipTiles
            }
        }
        Rectangle {
            visible: cell.scroll > 0.5
            z: 2
            width: parent.width
            height: cell.room + Style.space(10)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: well.color
                }
                GradientStop {
                    position: 0.5
                    color: well.color
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(well.color, 0)
                }
            }
        }
        Rectangle {
            visible: cell.scroll < cell.maxScroll - 0.5
            z: 2
            y: parent.height - height
            width: parent.width
            height: Style.space(14)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(well.color, 0)
                }
                GradientStop {
                    position: 1
                    color: well.color
                }
            }
        }
    }
    Rectangle {
        visible: cell.overflows
        x: cell.width - cell.pad + Style.space(3)
        y: cell.viewTop + (cell.contentHeight > 0 ? cell.scroll / cell.contentHeight * cell.viewHeight : 0)
        width: Style.spaceReal(1.5)
        height: Math.max(Style.space(16), cell.viewHeight * cell.viewHeight / Math.max(1, cell.contentHeight))
        radius: width / 2
        antialiasing: true
        color: Qt.alpha(Commons.Color.popups.text, cell.current ? 0.5 : 0.3)
    }
}
