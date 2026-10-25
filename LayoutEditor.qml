import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "GroupsModel.js" as Groups
import "ZoneFitNotice.js" as ZoneFitNotice
import "AppearanceModel.js" as AppearanceModel
import "CellModel.js" as CellModel

// The bar's layout as an exploded view (docs/behavior/preferences.md
// PREFS-99): one layer per visibility (On the bar, On demand, Hidden) and
// one for the tray, each a tilted plate holding the layer's name, the five
// zones as tiles of one width mirrored about the screen's middle (Center
// under the camera on a notched screen, with the camera's shaft running down
// through the layers), and the widgets as chips in their zones. Preferences
// draws the bar horizontally whatever edge it is on; the zones are named by
// where they are on screen.
//
// Keyboard and pointer share one state machine: a cursor rests on a chip or
// an empty tile, Space (or a drag) lifts the chip, moving it previews where
// it will land, and Space (or release) drops it. Esc puts it back. Enter (or
// a click) pulls the chip forward to an inspector at the front of the stack
// (PREFS-101). Each layer is a Tab stop sharing that cursor.
Item {
    id: editor
    required property var preferences
    readonly property var bar: preferences.bar
    // The layout's widgets, then the icons still in Omarchy's tray (its row).
    readonly property var entries: preferences.layoutEntries.concat(preferences.trayEntries)
    // Every shelf has the five zones (Model.sections); the tray's row one column.
    function columnsFor(mode) {
        return mode === "tray" ? ["tray"] : Model.sections;
    }
    // The rows: the three visibilities, then the tray. Only a tray icon can be
    // lifted into the tray's row.
    readonly property var rows: Model.rows
    readonly property var liftRows: lifted && lifted.trayItem ? Model.rows : Model.modes
    readonly property var cellEntries: {
        var cells = ({});
        for (var mode of Model.rows)
            for (var column of columnsFor(mode))
                cells[column + ":" + mode] = Model.cell(entries, column, mode, "");
        return cells;
    }
    function members(section, mode, exclude) {
        var items = cellEntries && cellEntries[section + ":" + mode] || [];
        return exclude ? items.filter(function (r) {
            return r.instanceKey !== exclude;
        }) : items;
    }
    readonly property var snapshots: preferences.snapshots
    readonly property var sections: Model.sections
    readonly property var modes: Model.modes
    readonly property bool sideBar: !!bar && bar.vertical
    readonly property var zoneNames: ({
            left: sideBar ? "Top" : "Left",
            centerBegin: sideBar ? "Above center" : "Left of center",
            center: "Center",
            centerEnd: sideBar ? "Below center" : "Right of center",
            right: sideBar ? "Bottom" : "Right",
            tray: "Tray"
        })
    // The screen the shelves picture: the bar is the same on every screen, but
    // a camera moves the center. Preferences' own screen unless another is picked.
    property string previewName: ""
    readonly property var screens: Quickshell.screens
    readonly property var previewScreen: screens.find(function (s) {
        return s.name === previewName;
    }) || preferences.targetScreen || screens[0] || null
    function cameraOn(screen) {
        return !!bar && !sideBar && !!screen && !!bar.notchFor(screen);
    }
    readonly property bool previewCamera: cameraOn(previewScreen)
    readonly property var previewNotch: previewCamera ? bar.notchFor(previewScreen) : null
    // ------------------------------------------------------------- geometry
    // The layers tilt back 34 degrees seen from 1600 px (Qt's
    // Rotation.distanceToPlane), as the design board draws them; with
    // animations off they lie flat (PREFS-99).
    readonly property real tilt: bar && !bar.animationsEnabled ? 0 : 34
    readonly property real planeDistance: Style.space(1600)
    readonly property real layerGap: Style.space(30)
    readonly property real platePad: Style.space(12)
    readonly property real columnGap: Style.space(8)
    readonly property real tilePad: Style.space(8)
    readonly property real chipHeight: Style.space(24)
    readonly property real chipGap: Style.space(3)
    readonly property real nameRow: Style.space(20)
    readonly property real minPlate: Style.space(52)
    // The screen's middle (the camera's axis) in the editor, measured: the
    // page may not be centred on it.
    property real axis: width / 2
    // Where the page's top (the bar's edge) is, above the editor.
    property real pageTop: 0
    function measureAxis() {
        var win = editor.Window.window;
        if (!win || width <= 0)
            return;
        var x = mapFromItem(null, win.width / 2, 0).x;
        axis = Math.abs(x - width / 2) < width * 0.1 ? x : width / 2;
        pageTop = -mapToItem(null, 0, 0).y;
    }
    onWidthChanged: Qt.callLater(measureAxis)
    Component.onCompleted: Qt.callLater(measureAxis)
    // A plate spans the editor, at most the board's 1380 px, centred on the
    // axis. Seven columns across it: the layer's name, the five zones, a
    // spare that mirrors the name's; Center as wide as the camera on a
    // notched preview, so it sits under it.
    readonly property real plateWidth: Math.min(width, Style.space(1380))
    readonly property real plateX: Math.max(0, Math.min(width - plateWidth, axis - plateWidth / 2))
    readonly property var columns: Model.layerColumns(plateWidth - 2 * platePad, columnGap, axis - plateX - platePad, 7, previewCamera && previewNotch ? previewNotch.width : 0)
    function column(section) {
        var i = section === "tray" ? 1 : sections.indexOf(section) + 1;
        return {
            x: platePad + columns.xs[i],
            width: section === "tray" ? columns.xs[5] + columns.widths[5] - columns.xs[1] : columns.widths[i]
        };
    }
    // Every chip has one width: what a zone's tile leaves.
    readonly property real chipWidth: Math.max(Style.space(80), columns.width - 2 * tilePad)
    // Rows on a layer: its fullest zone's chips, with a lifted one's place;
    // the tray's chips flow five to a row.
    function rowsOf(mode) {
        if (mode === "tray")
            return Math.max(1, Math.ceil(cellList("tray", "tray").length / 5));
        var n = 0;
        sections.forEach(function (s) {
            n = Math.max(n, cellList(s, mode).length);
        });
        return Math.max(1, n);
    }
    readonly property var plateHeights: rows.map(function (mode) {
        var r = rowsOf(mode);
        return Math.max(minPlate, 2 * tilePad + (mode === "tray" ? 0 : nameRow) + r * chipHeight + (r - 1) * chipGap);
    })
    readonly property var stack: Model.stackLayers(plateHeights, tilt, planeDistance, layerGap)

    // Only screens that look different get a switcher.
    readonly property bool screensDiffer: screens.some(function (s) {
        return editor.cameraOn(s);
    }) && screens.some(function (s) {
        return !editor.cameraOn(s);
    })
    readonly property string barCaption: sideBar ? (screens.some(function (s) {
            return !!editor.bar && !!editor.bar.notchFor(s, "top");
        }) ? "No camera on this edge: Center sits over the middle; Above center and Below center hang off it." : "Center sits over the screen's middle; Above center and Below center hang off it.") : previewCamera ? "Left of center sits left of the camera; Center and Right of center sit right of it." : "Center sits over the screen's middle; Left of center and Right of center hang off it."
    // Where a zone sits by the camera, for the Zone choice.
    function cameraNote(zone) {
        if (!previewCamera || zone === "left" || zone === "right")
            return "";
        return (zone === "centerBegin" ? "left of the camera" : "right of the camera") + (screensDiffer && previewScreen ? " on " + previewScreen.name : "");
    }
    readonly property var zoneChoices: sections.map(function (s) {
        return {
            value: s,
            label: editor.zoneNames[s],
            share: 1
        };
    })
    // Preferences draws a horizontal bar, at the size it has on a top edge.
    readonly property real barThickness: bar ? bar.barSizeFor(false) : Style.bar.sizeHorizontal
    readonly property real iconSize: Style.bar.sizeHorizontal
    // Widget images are drawn in the bar's text colour. When that barely shows
    // on the Preferences background (Light text in a light theme), they sit on
    // a backing in the Preferences text colour instead.
    readonly property bool inkBacked: {
        if (!bar || !bar.barForeground)
            return false;
        var a = AppearanceModel.luminance(bar.barForeground), b = AppearanceModel.luminance(Commons.Color.popups.background);
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05) < 3;
    }
    // The bar shelf draws the bar as it is: its cell geometry at the size it
    // has on a top edge, its text colour and font, its surface (opaque: the
    // wallpaper behind it is not drawn), rounding and border.
    readonly property var barTokens: CellModel.tokens({
        bar: barThickness,
        spacing: bar ? bar.widgetSpacing : 0,
        mode: bar ? bar.spacingMode : "slots"
    })
    readonly property color barInk: bar ? bar.barForeground : Commons.Color.popups.text
    readonly property string barInkHex: bar ? bar.colorHex(bar.barForeground) : ""
    readonly property color barSurface: bar ? Qt.rgba(bar.mainSurfaceColor.r, bar.mainSurfaceColor.g, bar.mainSurfaceColor.b, 1) : Commons.Color.popups.background
    readonly property string barFont: bar ? bar.fontFamily : Style.font.family
    // Ink of a line of text, measured once per text, font and size. Each font
    // gets its own FontMetrics, made once, so measuring never changes a
    // property a binding reads.
    property var inkCache: ({})
    property var fontMetrics: ({})
    function textInk(text, family, size) {
        var key = family + "|" + size + "|" + text;
        var known = inkCache[key];
        if (known)
            return known;
        var fontKey = family + "|" + size;
        var metrics = fontMetrics[fontKey];
        if (!metrics) {
            metrics = Qt.createQmlObject("import QtQuick; FontMetrics {}", editor);
            metrics.font = Qt.font({
                family: family,
                pixelSize: size
            });
            fontMetrics[fontKey] = metrics;
        }
        var r = metrics.tightBoundingRect(text);
        known = {
            start: r.x,
            length: r.width,
            advance: metrics.advanceWidth(text)
        };
        inkCache[key] = known;
        return known;
    }
    function textFace(text, family, size, glyph) {
        var ink = textInk(text, family, size);
        return {
            kind: "text",
            text: text,
            family: family,
            size: size,
            inkStart: ink.start,
            inkLength: ink.length,
            glyph: glyph,
            cap: true
        };
    }
    function imageFace(url, f) {
        // An image from before Powerbar recorded ink is placed as the bar places
        // a glyph of its width.
        var known = f.inkLength !== undefined;
        // Drawn in another text colour (another theme, or before Powerbar noted
        // it): shown in the bar's current colour until the bar recaptures it.
        return {
            kind: "image",
            url: url,
            w: f.w,
            h: f.h,
            inkStart: known ? f.inkStart : 0,
            inkLength: known ? f.inkLength : f.w,
            glyph: known ? f.glyph : f.w <= barTokens.cell,
            cap: known ? f.cap !== false : true,
            recolour: f.ink !== barInkHex
        };
    }
    // How the bar draws a widget, the truest way known: a live image; a saved
    // one drawn in the bar's current text colour; a group's face; the glyph the
    // widget draws itself, in the bar's font, size and colour (unless it draws
    // several, like workspaces); a saved image from another theme, recoloured;
    // Powerbar's stock glyph.
    function barFace(record) {
        if (!record || !record.instanceKey)
            return null;
        var key = record.instanceKey;
        var live = snapshots[key];
        if (live && live.face && live.face.inkLength !== undefined)
            return imageFace(live.url, live.face);
        var saved = !record.groupId && bar && bar.widgetFaces ? bar.widgetFaces[key] || imageSizes[key] || null : null;
        var url = saved ? preferences.cachedImageUrl(key) : "";
        if (url && saved.inkLength !== undefined && saved.ink === barInkHex)
            return imageFace(url, saved);
        var group = record.groupId && bar ? bar.groups.find(function (g) {
            return g.id === record.groupId;
        }) || null : null;
        if (group)
            return groupFace(group, "");
        var read = preferences.readGlyph(record);
        if (read && !(read.parts > 1 && url))
            return textFace(read.glyph, read.font || barFont, read.size || Style.font.body, true);
        if (url)
            return imageFace(url, saved);
        if (live)
            return imageFace(live.url, {
                w: live.width,
                h: live.height
            });
        var stock = Model.icon(String(record.id || ""));
        return textFace(stock, Groups.iconFont(stock) || barFont, Style.font.body, true);
    }
    // A group's face as the bar draws it (GroupFace): its runs, measured run by
    // run, the ink from the first run's to the last run's.
    function groupFace(group, mode) {
        var x = 0, start = null, end = 0;
        var runs = Groups.faceRuns(group, mode);
        runs.forEach(function (run, index) {
            if (run.kind === "image") {
                if (start === null)
                    start = x;
                end = x + 16;
                x += 16;
                return;
            }
            var ink = textInk(run.text, run.font || barFont, Style.font.body);
            if (run.kind !== "gap") {
                if (start === null)
                    start = x + ink.start;
                end = x + ink.start + ink.length;
            }
            // An icon before the name ends at its ink (GroupFace).
            x += index === 0 && runs.length > 1 ? Math.max(0, ink.start + ink.length) : ink.advance;
        });
        var face = mode || group.face;
        return {
            kind: "group",
            group: group,
            mode: mode,
            inkStart: start || 0,
            inkLength: Math.max(0, end - (start || 0)),
            glyph: face === "glyph",
            cap: true
        };
    }
    // Sizes of saved images from before faces.json, learnt as they load.
    property var imageSizes: ({})
    readonly property var unsizedImages: entries.filter(function (e) {
        return e.mode === "shown" && !e.groupId && !(editor.bar && editor.bar.widgetFaces[e.instanceKey]) && !editor.imageSizes[e.instanceKey] && editor.preferences.cachedImageUrl(e.instanceKey) !== "";
    }).map(function (e) {
        return e.instanceKey;
    })
    Repeater {
        model: editor.unsizedImages
        Image {
            required property string modelData
            visible: false
            asynchronous: true
            source: editor.preferences.cachedImageUrl(modelData)
            onStatusChanged: if (status === Image.Ready) {
                var scale = 2 * Math.max(1, Screen.devicePixelRatio);
                var next = Object.assign({}, editor.imageSizes);
                next[modelData] = {
                    w: sourceSize.width / scale,
                    h: sourceSize.height / scale
                };
                editor.imageSizes = next;
            }
        }
    }
    readonly property var fitNotes: editor.bar ? ZoneFitNotice.lines(editor.bar.zoneFitReports) : []
    readonly property var shelfInfo: ({
            shown: {
                title: "On the bar",
                caption: fitNotes.length ? fitNotes.join(" ") : "Always visible"
            },
            managed: {
                title: "On demand",
                caption: editor.bar && editor.bar.onDemandInline ? "Behind the zone's dots; shown on activity, or when you hover the dots" : editor.bar && editor.bar.onDemandMenu ? "In a menu from the zone's dots; shown briefly on activity" : "In the zone's drawer when you hover it, or briefly on activity"
            },
            hidden: {
                title: "Hidden",
                caption: "Kept off the bar"
            },
            tray: {
                title: "In the tray",
                caption: "Omarchy's tray icons"
            }
        })
    // The zone a tray icon goes to when moved without a place: the tray's own.
    readonly property string trayZone: {
        var tray = entries.find(function (e) {
            return e.id === "omarchy.tray" && !e.groupId;
        });
        return tray && sections.indexOf(tray.section) >= 0 ? tray.section : sections[sections.length - 1];
    }

    property var cursorCell: ({
            section: "left",
            mode: "shown",
            pos: 0
        })
    property string cursorKey: ""
    property var lifted: null
    property var liftOrigin: null
    property var liftTarget: null
    property bool pointerLift: false
    property point pointer: Qt.point(0, 0)
    property var pressed: null
    property point pressPoint: Qt.point(0, 0)
    property string hoverKey: ""
    // Set while the editor moves focus itself, so a layer gaining focus only
    // moves the cursor when Tab brought it there.
    property bool focusMoving: false
    // The cursor's chip pulled forward to the inspector (PREFS-101). It
    // follows the cursor while open.
    property bool inspecting: false

    readonly property string liftedKey: lifted ? lifted.instanceKey : ""
    readonly property var cursorItems: members(cursorCell.section, cursorCell.mode, liftedKey)
    readonly property var cursorRecord: lifted || cursorItems[cursorCell.pos] || null
    readonly property var inspected: inspecting ? cursorRecord : null
    readonly property string inspectedKey: inspected ? inspected.instanceKey : ""
    // The well being worked on: where the lifted chip would land, else the
    // cursor's. Its zone's names read brighter on every layer.
    readonly property var activeCell: lifted && liftTarget ? liftTarget : cursorCell
    readonly property Item focused: editor.Window.activeFocusItem
    function within(item, root) {
        for (var p = item; p; p = p.parent)
            if (p === root)
                return true;
        return false;
    }
    readonly property bool gridFocused: within(focused, sheet)
    readonly property bool inspectorFocused: within(focused, inspector)
    readonly property var hints: lifted ? [
        {
            keys: "j k",
            label: "Along the zone, on to the next layer"
        },
        {
            keys: "h l",
            label: "Zone"
        },
        {
            keys: "space",
            label: "Drop"
        },
        {
            keys: "esc",
            label: "Put it back"
        }
    ] : gridFocused ? [
        {
            keys: "h l",
            label: "Along the layer"
        },
        {
            keys: "j k",
            label: "Down the zone, on to the next layer"
        },
        {
            keys: "space",
            label: "Pick up, then drop"
        },
        {
            keys: "enter",
            label: inspecting ? "Push it back" : "Pull forward to inspect"
        },
        {
            keys: "x",
            label: "Send to the hidden layer"
        },
        {
            keys: "tab",
            label: "Next layer"
        },
        {
            keys: "1-3",
            label: "Pages"
        },
        {
            keys: "esc",
            label: inspecting ? "Push it back" : "Close"
        }
    ] : inspectorFocused ? [
        {
            keys: "tab shift+tab",
            label: "Next, previous control"
        }
    ].concat(focused && focused.keyHints ? focused.keyHints : [
        {
            keys: "h l",
            label: "Adjust"
        },
        {
            keys: "space",
            label: "Toggle"
        }
    ]).concat([
        {
            keys: "esc",
            label: "Back to the layers"
        }
    ]) : [
        {
            keys: "tab",
            label: "The layers"
        },
        {
            keys: "1-3",
            label: "Pages"
        },
        {
            keys: "esc",
            label: "Close"
        }
    ]

    QtObject {
        id: plates
        property var list: []
        function register(p) {
            list = list.concat([p]);
        }
        function unregister(p) {
            list = list.filter(function (x) {
                return x !== p;
            });
        }
        function forMode(mode) {
            return list.find(function (p) {
                return p.mode === mode;
            }) || null;
        }
    }
    function focusShelf(mode, reason) {
        var plate = plates.forMode(mode);
        if (!plate)
            return;
        focusMoving = true;
        plate.focusItem.forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
        focusMoving = false;
        revealPlate(mode);
    }
    function focusFirst() {
        focusShelf(cursorCell.mode, Qt.TabFocusReason);
    }
    // Focus follows the cursor from layer to layer.
    function followCursor() {
        var mode = activeCell.mode;
        var plate = plates.forMode(mode);
        if (gridFocused && plate && !plate.focusItem.activeFocus)
            focusShelf(mode);
        else
            revealPlate(mode);
    }
    // Scroll the sheet so the layer is in view.
    function revealPlate(mode) {
        var plate = plates.forMode(mode);
        if (!plate)
            return;
        var top = plate.y - Style.space(8), bottom = plate.y + plate.height + Style.space(8);
        var end = Math.max(0, sheet.contentHeight - sheet.height);
        if (top < sheet.contentY)
            sheet.contentY = Math.max(0, top);
        else if (bottom > sheet.contentY + sheet.height)
            sheet.contentY = Math.min(end, bottom - sheet.height);
    }
    // The column a zone has on another layer; the tray's one column meets the
    // last zone, as j and k do.
    function columnOn(mode, section) {
        var cols = columnsFor(mode);
        return cols.indexOf(section) >= 0 ? section : cols[cols.length - 1];
    }
    function plateFocusChanged(mode, focused) {
        if (focused) {
            if (focusMoving)
                return;
            // Tab or Shift+Tab: the cursor (or the lifted chip) moves to this layer.
            if (lifted) {
                // Only a tray icon can be carried into the tray's layer.
                if (liftRows.indexOf(mode) < 0)
                    return;
                if (liftTarget && liftTarget.mode !== mode)
                    liftTarget = {
                        section: columnOn(mode, liftTarget.section),
                        mode: mode,
                        pos: 0
                    };
            } else if (cursorCell.mode !== mode)
                place({
                    section: columnOn(mode, cursorCell.section),
                    mode: mode,
                    pos: 0
                });
            return;
        }
        Qt.callLater(function () {
            if (!editor.gridFocused && editor.lifted && !editor.pointerLift)
                editor.cancel();
        });
    }

    function count(section, mode) {
        return members(section, mode, liftedKey).length;
    }
    function cellList(section, mode) {
        var list = members(section, mode, liftedKey).map(function (record) {
            return {
                record: record,
                placeholder: false
            };
        });
        if (lifted && liftTarget && liftTarget.section === section && liftTarget.mode === mode)
            list.splice(Math.min(liftTarget.pos, list.length), 0, {
                record: lifted,
                placeholder: true
            });
        return list;
    }
    function place(cell) {
        cursorCell = cell;
        var record = members(cell.section, cell.mode, "")[cell.pos];
        cursorKey = record ? record.instanceKey : "";
    }
    function syncCursor() {
        if (lifted)
            return;
        for (var m = 0; m < rows.length; m++)
            for (var column of columnsFor(rows[m])) {
                var list = members(column, rows[m], "");
                for (var i = 0; i < list.length; i++)
                    if (list[i].instanceKey === cursorKey) {
                        cursorCell = {
                            section: column,
                            mode: rows[m],
                            pos: i
                        };
                        return;
                    }
            }
        if (columnsFor(cursorCell.mode).indexOf(cursorCell.section) < 0)
            cursorCell = {
                section: columnOn(cursorCell.mode, cursorCell.section),
                mode: cursorCell.mode,
                pos: 0
            };
        var n = count(cursorCell.section, cursorCell.mode);
        place({
            section: cursorCell.section,
            mode: cursorCell.mode,
            pos: Math.max(0, Math.min(cursorCell.pos, n - 1))
        });
    }
    // Deferred: entries can be re-evaluated lazily while cursorItems is being
    // computed, and moving the cursor there would change cursorItems' own input.
    // A Timer the editor owns, not a closure: it stops with the editor.
    onEntriesChanged: syncLater.restart()
    Timer {
        id: syncLater
        interval: 0
        onTriggered: editor.syncCursor()
    }

    function moveCursor(dx, dy) {
        if (lifted)
            liftTarget = Model.stepLayerLift(count, liftTarget, dx, dy, columnsFor, liftRows);
        else
            place(Model.stepLayer(count, cursorCell, dx, dy, columnsFor, rows));
        followCursor();
    }
    function lift(record, cell) {
        if (!record)
            return;
        lifted = record;
        liftOrigin = cell;
        liftTarget = cell;
    }
    function cancel() {
        lifted = null;
        pointerLift = false;
        if (liftOrigin)
            place(liftOrigin);
        followCursor();
    }
    function drop() {
        if (!lifted)
            return;
        var record = lifted, target = liftTarget, origin = liftOrigin;
        var unchanged = target.section === origin.section && target.mode === origin.mode && target.pos === origin.pos;
        var before = Model.dropBefore(members(target.section, target.mode, record.instanceKey), target.pos);
        lifted = null;
        pointerLift = false;
        cursorKey = record.instanceKey;
        cursorCell = target;
        if (unchanged)
            return;
        // Out of the tray, back into it, or within it (the tray keeps its order).
        if (origin.mode === "tray") {
            if (target.mode !== "tray")
                cursorKey = preferences.takeFromTray(record, target.section, target.mode, before);
        } else if (target.mode === "tray")
            preferences.returnToTray(record);
        else
            preferences.move(record, target.section, target.mode, before);
    }
    // Keep an item's place in its zone when only its visibility changes.
    // Rows widgets were hidden from this session, so showing one again restores it.
    property var hiddenFrom: ({})
    function setPlacement(record, section, mode) {
        if (!record || (record.section === section && record.mode === mode))
            return;
        if (record.mode === "tray") {
            if (mode !== "tray")
                cursorKey = preferences.takeFromTray(record, section === "tray" ? trayZone : section, mode, -1);
            return;
        }
        if (mode === "tray") {
            preferences.returnToTray(record);
            return;
        }
        if (mode === "hidden" && record.mode !== "hidden") {
            var remembered = Object.assign({}, hiddenFrom);
            remembered[record.instanceKey] = record.mode;
            hiddenFrom = remembered;
        }
        var before = section !== record.section ? -1 : record.groupId ? record.index : record.index + 1;
        cursorKey = record.instanceKey;
        preferences.move(record, section, mode, before);
    }
    // Pull the cursor's chip forward, or push it back; from the keyboard the
    // inspector takes focus.
    function inspect(byKey) {
        inspecting = true;
        if (byKey)
            inspector.focusFirst();
    }
    function pushBack() {
        inspecting = false;
        focusShelf(cursorCell.mode, Qt.OtherFocusReason);
    }
    function keyPressed(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
            return;
        var key = event.key, t = event.text;
        // h and l change zone; j and k walk a zone's chips and go on to the
        // same zone on the next layer at its ends.
        if (key === Qt.Key_Left || t === "h")
            moveCursor(-1, 0);
        else if (key === Qt.Key_Right || t === "l")
            moveCursor(1, 0);
        else if (key === Qt.Key_Up || t === "k")
            moveCursor(0, -1);
        else if (key === Qt.Key_Down || t === "j")
            moveCursor(0, 1);
        else if (key === Qt.Key_Space) {
            if (lifted)
                drop();
            else
                lift(cursorRecord, cursorCell);
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            if (lifted)
                drop();
            else if (inspecting)
                pushBack();
            else if (cursorRecord)
                inspect(true);
        } else if (key === Qt.Key_Escape && lifted)
            cancel();
        else if (key === Qt.Key_Escape && inspecting)
            pushBack();
        else if ((t === "x" || key === Qt.Key_Delete) && !lifted && cursorRecord) {
            var r = cursorRecord;
            setPlacement(r, r.section, Model.toggledHidden(r.mode, hiddenFrom[r.instanceKey]));
        } else if (t === "g" && !lifted && cursorRecord && cursorRecord.groupId)
            preferences.openGroup(cursorRecord.groupId);
        else
            return;
        event.accepted = true;
    }

    // Pointer hit testing in editor coordinates, through the layers' tilt.
    function cellAt(point) {
        for (var i = 0; i < cellRepeater.count; i++) {
            var cell = cellRepeater.itemAt(i);
            if (!cell || !cell.visible)
                continue;
            var p = cell.mapFromItem(editor, point.x, point.y);
            if (p.x >= 0 && p.y >= 0 && p.x < cell.width && p.y < cell.height)
                return cell;
        }
        return null;
    }
    function tileAt(point) {
        var cell = cellAt(point);
        if (!cell || !cell.tiles)
            return null;
        for (var i = 0; i < cell.tiles.count; i++) {
            var tile = cell.tiles.itemAt(i);
            if (!tile || tile.placeholder)
                continue;
            var p = tile.mapFromItem(editor, point.x, point.y);
            if (p.x >= 0 && p.y >= 0 && p.x < tile.width && p.y < tile.height)
                return tile;
        }
        return null;
    }
    // The gap under the pointer: before the first real chip the pointer has
    // not passed, reading a tile top to bottom and the tray's row left to
    // right.
    function gapAt(cell, point) {
        var pos = 0;
        for (var i = 0; cell.tiles && i < cell.tiles.count; i++) {
            var tile = cell.tiles.itemAt(i);
            if (!tile || tile.placeholder)
                continue;
            var p = tile.mapFromItem(editor, point.x, point.y);
            var passed = cell.flows ? p.y >= tile.height || (p.y >= 0 && p.x >= tile.width / 2) : p.y >= tile.height / 2;
            if (!passed)
                return pos;
            pos++;
        }
        return pos;
    }
    function pointerMoved(point) {
        pointer = point;
        if (!pointerLift)
            return;
        var cell = cellAt(point);
        if (cell && liftRows.indexOf(cell.mode) >= 0) {
            var next = {
                section: cell.section,
                mode: cell.mode,
                pos: gapAt(cell, point)
            };
            if (!liftTarget || next.section !== liftTarget.section || next.mode !== liftTarget.mode || next.pos !== liftTarget.pos)
                liftTarget = next;
        }
    }
    // The chip the inspector pulls forward: the lifted one's place while
    // moving, else the cursor's chip.
    function inspectedTile() {
        if (!inspected)
            return null;
        for (var i = 0; i < cellRepeater.count; i++) {
            var cell = cellRepeater.itemAt(i);
            if (!cell || !cell.tiles)
                continue;
            for (var j = 0; j < cell.tiles.count; j++) {
                var tile = cell.tiles.itemAt(j);
                if (tile && (lifted ? tile.placeholder : tile.record.instanceKey === inspectedKey))
                    return tile;
            }
        }
        return null;
    }

    QtObject {
        id: cellRepeater
        property var cells: []
        readonly property int count: cells.length
        function itemAt(i) {
            return cells[i];
        }
        function register(cell) {
            cells = cells.concat([cell]);
        }
        function unregister(cell) {
            cells = cells.filter(function (c) {
                return c !== cell;
            });
        }
    }

    // The camera's shaft: from the real notch, straight down through every
    // layer, flat behind them. It ends where the sheet does.
    Item {
        id: shaft
        visible: editor.previewCamera && !!editor.previewNotch
        z: -1
        x: editor.axis - width / 2
        y: editor.pageTop
        width: editor.previewNotch ? editor.previewNotch.width : 0
        height: Math.max(0, editor.stack.height - sheet.contentY - y + Style.space(8))
        clip: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "black"
                }
                GradientStop {
                    position: 0.7
                    color: Qt.rgba(0, 0, 0, 0.7)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
        Repeater {
            model: 2
            Column {
                required property int index
                x: index === 0 ? 0 : shaft.width - 1
                spacing: Style.space(4)
                Repeater {
                    model: Math.ceil(shaft.height / Style.space(8))
                    Rectangle {
                        width: 1
                        height: Style.space(4)
                        color: Qt.alpha(Commons.Color.popups.text, 0.12)
                    }
                }
            }
        }
        Text {
            x: 0
            y: Style.space(18)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "camera"
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }

    // The layers, stacked down the sheet; it scrolls only when they outgrow it.
    Flickable {
        id: sheet
        anchors.fill: parent
        contentWidth: width
        contentHeight: editor.stack.height + (inspector.shown ? inspector.height + Style.space(48) : Style.space(8))
        boundsBehavior: Flickable.StopAtBounds
        interactive: !editor.pointerLift
        clip: true
        Repeater {
            model: editor.rows
            Plate {}
        }
    }

    // Which screen the layers picture, when screens differ (a camera on one):
    // it changes the picture only, never the layout. It sits in the bar
    // layer's spare column, flat.
    Dropdown {
        visible: editor.screensDiffer
        anchors.right: parent.right
        y: 0
        z: 5
        width: Math.max(Style.space(120), editor.columns.widths[6])
        label: "Preview"
        showLabel: false
        options: editor.screens.map(function (s) {
            return {
                value: s.name,
                label: s.name + (editor.cameraOn(s) ? " (camera)" : "")
            };
        })
        value: editor.previewScreen ? editor.previewScreen.name : ""
        onChanged: function (value) {
            editor.previewName = value;
        }
    }

    // The dragged chip follows the pointer, flat, while its landing place is
    // previewed in the layers.
    Tile {
        visible: editor.pointerLift && !!editor.lifted
        record: editor.lifted || ({})
        mode: editor.liftTarget ? editor.liftTarget.mode : "managed"
        ghost: true
        x: editor.pointer.x - width / 2
        y: editor.pointer.y - height / 2
        z: 100
    }

    // A chip's full name, icon and id, flat over the layers, after a short
    // rest on it; once one has shown, the next shows at once (PREFS-100).
    property Item hoverTile: null
    property bool tipWarm: false
    function hoverOn(tile) {
        if (tile === hoverTile)
            return;
        hoverTile = tile;
        if (!tile || lifted) {
            nameTip.shown = false;
            tipDelay.stop();
            if (tipWarm)
                tipCool.restart();
            return;
        }
        tipCool.stop();
        if (tipWarm)
            showTip();
        else {
            nameTip.shown = false;
            tipDelay.restart();
        }
    }
    function showTip() {
        var tile = hoverTile;
        if (!tile || lifted || !tile.record || !tile.record.instanceKey)
            return;
        nameTip.record = tile.record;
        var below = tile.mapToItem(editor, tile.width / 2, tile.height);
        var above = tile.mapToItem(editor, tile.width / 2, 0);
        var gap = Style.space(6);
        nameTip.x = Math.max(0, Math.min(editor.width - nameTip.width, below.x - nameTip.width / 2));
        nameTip.y = below.y + gap + nameTip.height <= editor.height ? below.y + gap : above.y - gap - nameTip.height;
        nameTip.shown = true;
        tipWarm = true;
    }
    Timer {
        id: tipDelay
        interval: 450
        onTriggered: editor.showTip()
    }
    Timer {
        id: tipCool
        interval: 600
        onTriggered: editor.tipWarm = false
    }
    onLiftedChanged: if (lifted)
        hoverOn(null)
    BorderSurface {
        id: nameTip
        property bool shown: false
        property var record: ({})
        z: 110
        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutCubic
            }
        }
        width: tipRow.implicitWidth + Style.space(24)
        height: tipRow.implicitHeight + Style.space(16)
        radius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2))
        color: Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, 0.1))
        borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.16), 1)
        Row {
            id: tipRow
            anchors.centerIn: parent
            spacing: Style.space(10)
            InkIcon {
                record: nameTip.record
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: nameTip.record && nameTip.record.instanceKey ? editor.preferences.title(nameTip.record) : ""
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: nameTip.record ? nameTip.record.groupId ? "Group" : nameTip.record.id || "" : ""
                textFormat: Text.PlainText
                color: Qt.alpha(Commons.Color.popups.text, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
    }

    // ------------------------------------------------------------ inspector
    // The inspected chip, pulled out of its layer to the front: a dashed
    // leader from its place in the layer to a flat copy above the inspector.
    property Item inspectedItem: null
    function refreshInspected() {
        var tile = inspectedTile();
        if (tile !== inspectedItem)
            inspectedItem = tile;
        trackLeader();
    }
    onInspectedKeyChanged: Qt.callLater(refreshInspected)
    onLiftTargetChanged: Qt.callLater(refreshInspected)
    onInspectingChanged: Qt.callLater(refreshInspected)
    property point leaderStart: Qt.point(0, 0)
    function trackLeader() {
        var tile = inspectedItem;
        if (!tile)
            return;
        leaderStart = tile.mapToItem(editor, tile.width / 2, tile.height / 2);
    }
    onInspectedItemChanged: trackLeader()
    GeometryObserver {
        target: editor.inspectedItem
        host: editor
        onChanged: editor.trackLeader()
    }
    Connections {
        target: sheet
        function onContentYChanged() {
            editor.trackLeader();
        }
    }
    readonly property bool leaderShown: inspector.shown && !!inspectedItem && !pointerLift
    Shape {
        visible: editor.leaderShown
        z: 115
        anchors.fill: parent
        ShapePath {
            strokeColor: Commons.Color.accent
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            fillColor: "transparent"
            startX: editor.leaderStart.x
            startY: editor.leaderStart.y
            PathLine {
                x: pulledChip.x + pulledChip.width / 2
                y: pulledChip.y
            }
        }
    }
    Rectangle {
        visible: editor.leaderShown
        z: 116
        x: editor.leaderStart.x - width / 2
        y: editor.leaderStart.y - height / 2
        width: Style.space(6)
        height: width
        radius: width / 2
        color: Commons.Color.accent
    }
    Tile {
        id: pulledChip
        visible: editor.leaderShown
        record: editor.inspected || ({})
        mode: editor.inspected ? editor.inspected.mode : "managed"
        pulled: true
        z: 125
        x: Math.max(inspector.x + Style.space(24), Math.min(inspector.x + inspector.width - width - Style.space(24), editor.leaderStart.x - width / 2))
        y: inspector.y - Style.space(30)
        rotation: -1.5
        Behavior on x {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }
    Inspector {
        id: inspector
        shown: editor.inspecting
    }

    // One layer: a plate tilted back about its middle line, holding the
    // layer's name, the five zones as tiles (the tray: one dashed slab) and a
    // spare column that keeps Center on the axis. The plate's box keeps the
    // room its tilted picture takes, so the layers stack without overlap.
    component Plate: Item {
        id: plate
        required property int index
        required property string modelData
        readonly property string mode: modelData
        readonly property bool tray: mode === "tray"
        readonly property var slot: editor.stack.layers[index] || ({
                top: 0,
                middle: 0,
                height: 0
            })
        property alias focusItem: plateFocus
        x: editor.plateX
        y: slot.top
        width: editor.plateWidth
        height: slot.height
        Behavior on y {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        Component.onCompleted: plates.register(this)
        Component.onDestruction: plates.unregister(this)

        Item {
            id: face
            width: plate.width
            height: editor.plateHeights[plate.index] || 0
            y: plate.slot.middle - plate.slot.top - height / 2
            transform: Rotation {
                axis {
                    x: 1
                    y: 0
                    z: 0
                }
                origin.x: editor.axis - plate.x
                origin.y: face.height / 2
                distanceToPlane: editor.planeDistance
                angle: editor.tilt
            }
            Behavior on height {
                enabled: editor.bar.animationsEnabled
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            // The layer's name, what it is, and how many it holds.
            Column {
                x: editor.platePad + editor.columns.xs[0] + Style.space(2)
                y: Style.space(6)
                width: editor.columns.widths[0] - Style.space(6)
                spacing: Style.space(4)
                Text {
                    width: parent.width
                    text: editor.shelfInfo[plate.mode].title
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: editor.shelfInfo[plate.mode].caption
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.55)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: {
                        var n = 0;
                        editor.columnsFor(plate.mode).forEach(function (c) {
                            n += editor.members(c, plate.mode, "").length;
                        });
                        return n ? n + (n === 1 ? " widget" : " widgets") : "Empty";
                    }
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.4)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
            Repeater {
                model: plate.tray ? [] : editor.sections
                Cell {
                    required property string modelData
                    section: modelData
                    mode: plate.mode
                    x: editor.column(modelData).x
                    width: editor.column(modelData).width
                    height: face.height
                }
            }
            Cell {
                visible: plate.tray
                section: "tray"
                mode: "tray"
                flows: true
                x: editor.column("tray").x
                width: editor.column("tray").width
                height: face.height
            }
        }

        Item {
            id: plateFocus
            readonly property bool ownsFocusRing: true
            anchors.fill: parent
            activeFocusOnTab: true
            Accessible.role: Accessible.Table
            Accessible.name: editor.shelfInfo[plate.mode].title
            Accessible.description: editor.cursorRecord ? editor.preferences.title(editor.cursorRecord) : "Empty"
            Keys.onPressed: function (event) {
                editor.keyPressed(event);
            }
            onActiveFocusChanged: editor.plateFocusChanged(plate.mode, activeFocus)
        }

        // Every pointer gesture over the layer lands here, above the chips, so
        // a drag survives them being rebuilt as the preview moves. Points map
        // through the tilt to the chips. The press keeps it across the other
        // layers. A click pulls the chip forward (PREFS-101).
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: editor.pointerLift ? Qt.ClosedHandCursor : editor.hoverKey ? Qt.OpenHandCursor : Qt.ArrowCursor
            onPositionChanged: function (mouse) {
                var point = mapToItem(editor, mouse.x, mouse.y);
                if (!editor.pointerLift) {
                    var tile = editor.tileAt(point);
                    editor.hoverKey = tile ? tile.record.instanceKey : "";
                    editor.hoverOn(pressed ? null : tile);
                }
                if (pressed && editor.pressed && !editor.pointerLift && Math.abs(point.x - editor.pressPoint.x) + Math.abs(point.y - editor.pressPoint.y) > Style.space(6)) {
                    editor.lift(editor.pressed.record, editor.pressed.cell);
                    editor.pointerLift = true;
                }
                editor.pointerMoved(point);
            }
            onExited: {
                if (!editor.pointerLift)
                    editor.hoverKey = "";
                editor.hoverOn(null);
            }
            onPressed: function (mouse) {
                editor.hoverOn(null);
                if (editor.lifted)
                    editor.cancel();
                var point = mapToItem(editor, mouse.x, mouse.y);
                editor.pressPoint = point;
                var tile = editor.tileAt(point);
                var cell = editor.cellAt(point);
                if (tile) {
                    var at = {
                        section: tile.section,
                        mode: tile.mode,
                        pos: tile.pos
                    };
                    editor.place(at);
                    editor.pressed = {
                        record: tile.record,
                        cell: at
                    };
                } else {
                    editor.pressed = null;
                    if (cell)
                        editor.place({
                            section: cell.section,
                            mode: cell.mode,
                            pos: editor.gapAt(cell, point)
                        });
                }
                editor.focusShelf(editor.cursorCell.mode, Qt.MouseFocusReason);
            }
            onReleased: {
                var clicked = !!editor.pressed && !editor.pointerLift;
                editor.pressed = null;
                if (editor.pointerLift)
                    editor.drop();
                else if (clicked)
                    editor.inspect(false);
                editor.followCursor();
            }
            onCanceled: {
                editor.pressed = null;
                if (editor.pointerLift)
                    editor.cancel();
            }
        }
    }

    // One zone on one layer: a tile with the zone's name and its chips, one
    // under another in bar order; the tray's slab, dashed, flows its icons.
    component Cell: Item {
        id: cell
        property string section: ""
        property string mode: ""
        property bool flows: false
        readonly property bool trayCell: mode === "tray"
        readonly property var tiles: chipTiles
        readonly property var list: editor.cellList(section, mode)
        readonly property bool targeted: !!editor.lifted && !!editor.liftTarget && editor.liftTarget.section === section && editor.liftTarget.mode === mode
        readonly property bool cursorHere: !editor.lifted && editor.cursorCell.section === section && editor.cursorCell.mode === mode
        readonly property bool active: editor.activeCell.section === section
        readonly property bool shaft: editor.previewCamera && section === "center"
        readonly property real pad: editor.tilePad
        readonly property real radius: Math.min(Style.space(10), Style.cornerRadius)
        Component.onCompleted: cellRepeater.register(this)
        Component.onDestruction: cellRepeater.unregister(this)
        onListChanged: Qt.callLater(editor.refreshInspected)

        // The slab's thickness, below it.
        Rectangle {
            visible: !cell.trayCell
            y: Style.space(6)
            width: parent.width
            height: parent.height
            radius: cell.radius
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        BorderSurface {
            id: well
            anchors.fill: parent
            radius: cell.radius
            color: cell.trayCell ? "transparent" : Qt.tint(Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, cell.mode === "shown" ? 0.09 : 0.065)), cell.shaft ? Qt.rgba(0, 0, 0, 0.35) : "transparent")
            // An empty tile waiting for a drop is outlined the way a landing place is.
            borderSpec: cell.trayCell ? Border.none() : cell.targeted && cell.list.length === 1 ? Border.flat(Commons.Color.accent, 1) : Border.flat(Qt.alpha(Commons.Color.popups.text, 0.12), 1)
        }
        // The tray's dashed edge.
        Shape {
            visible: cell.trayCell
            anchors.fill: parent
            ShapePath {
                strokeColor: Qt.alpha(Commons.Color.popups.text, cell.targeted ? 0.6 : 0.3)
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
            visible: !cell.trayCell
            x: cell.pad + Style.space(2)
            y: cell.pad
            width: cell.width - x - cell.pad
            text: editor.zoneNames[cell.section] || ""
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, cell.active ? 0.9 : 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: cell.active && editor.activeCell.mode === cell.mode ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        Text {
            x: cell.pad + Style.space(2)
            y: cell.pad + (cell.trayCell ? Style.space(5) : editor.nameRow)
            visible: cell.list.length === 0
            text: cell.trayCell ? "Nothing in the tray. Apps put their icons here while they run; drag one onto a layer above to place it like a widget." : "Empty"
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.3)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        BorderSurface {
            anchors.fill: parent
            anchors.margins: Style.space(3)
            visible: cell.list.length === 0 && cell.cursorHere && editor.gridFocused
            color: "transparent"
            radius: Math.max(0, cell.radius - Style.space(3))
            borderSpec: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
        }
        Flow {
            id: chipFlow
            x: cell.pad
            y: cell.pad + (cell.trayCell ? 0 : editor.nameRow)
            width: cell.flows ? Math.max(1, cell.width - cell.pad * 2) : editor.chipWidth
            spacing: cell.flows ? editor.columnGap : editor.chipGap
            Repeater {
                id: chipTiles
                model: tileList.model
            }
        }

        RetainedList {
            id: tileList
            recordProperty: "retainedRecord"
            records: cell.list.map(function (value, index) {
                return {
                    key: value.placeholder ? "insertion-gap" : value.record.instanceKey || cell.section + ":" + cell.mode + ":" + index,
                    entry: value.record,
                    placeholder: value.placeholder,
                    index: index
                };
            })
            factory: Component {
                Tile {
                    required property var retainedRecord
                    record: retainedRecord.entry
                    placeholder: retainedRecord.placeholder
                    section: cell.section
                    mode: cell.mode
                    pos: retainedRecord.index
                }
            }
        }
    }

    // A widget's icon in a chip's square: the middle of its ink, or a wide
    // face's first glyph, so nothing sticks out of the square.
    component InkIcon: Item {
        id: inkIcon
        property var record: ({})
        property real box: Style.space(20)
        readonly property bool hasImage: picture.hasImage
        readonly property var face: record && record.instanceKey ? editor.barFace(record) : null
        width: box
        height: box
        // Widget images in the bar's text colour that barely show on the
        // Preferences background get a backing (editor.inkBacked).
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Style.space(2)
            visible: editor.inkBacked && picture.hasImage
            radius: Style.space(3)
            color: Commons.Color.popups.text
        }
        // A wide face shows its first glyph only: about the bar icon's own width.
        readonly property bool wide: {
            var f = face;
            return hasImage && !!f && f.kind === "image" && f.w > 0 && f.inkLength / f.w * picture.width > box;
        }
        Item {
            width: inkIcon.wide ? Math.round(inkIcon.box * 0.62) : parent.width
            height: parent.height
            clip: true
            WidgetIcon {
                id: picture
                preferences: editor.preferences
                record: inkIcon.record
                size: inkIcon.box
                maxAspect: 8
                anchors.verticalCenter: parent.verticalCenter
                x: {
                    var f = inkIcon.face;
                    if (!hasImage || !f || f.kind !== "image" || !(f.w > 0))
                        return Math.round((inkIcon.box - width) / 2);
                    // Ink wider than the box starts at its leading icon, not mid-word.
                    var scale = width / f.w;
                    if (inkIcon.wide)
                        return Math.round(-f.inkStart * scale);
                    return Math.round(inkIcon.box / 2 - (f.inkStart + f.inkLength / 2) * scale);
                }
            }
        }
    }

    // A chip: the widget's icon, its name (elided) and a group's count, one
    // width everywhere. A landing place or the inspected chip's own place is
    // an outline; the dragged copy and the pulled-out chip sit flat in front.
    component Tile: Item {
        id: tile
        property var record: ({})
        property bool placeholder: false
        property bool ghost: false
        property bool pulled: false
        property string section: ""
        property string mode: ""
        property int pos: 0
        readonly property bool inLayer: !ghost && !pulled
        readonly property bool pulledOut: inLayer && !placeholder && editor.leaderShown && !editor.lifted && record.instanceKey === editor.inspectedKey
        readonly property bool outline: placeholder || pulledOut
        readonly property bool isCursor: inLayer && !editor.lifted && editor.cursorKey !== "" && record.instanceKey === editor.cursorKey
        readonly property bool hovered: inLayer && !editor.lifted && editor.hoverKey === record.instanceKey
        readonly property var group: record.groupId ? editor.bar.groups.find(function (g) {
            return g.id === record.groupId;
        }) || null : null
        readonly property int memberCount: group ? group.items.length : 0
        // Press feedback: the chip dips while the pointer holds it, before a drag.
        readonly property bool pressedDown: inLayer && !placeholder && !!editor.pressed && !editor.pointerLift && editor.pressed.record.instanceKey === record.instanceKey
        scale: pressedDown ? 0.97 : 1
        Behavior on scale {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
        width: editor.chipWidth
        height: editor.chipHeight

        // The pulled-out chip's shadow.
        Rectangle {
            visible: tile.pulled
            anchors.fill: parent
            anchors.topMargin: Style.space(6)
            anchors.bottomMargin: -Style.space(6)
            radius: surface.radius
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        BorderSurface {
            id: surface
            anchors.fill: parent
            radius: Math.max(0, Math.min(Style.space(5), Style.cornerRadius - Style.space(3)))
            color: tile.outline ? "transparent" : tile.ghost || tile.pulled ? Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, 0.15)) : tile.isCursor && editor.gridFocused ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent) : tile.isCursor ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent) : tile.hovered ? Qt.alpha(Commons.Color.popups.text, 0.14) : Qt.alpha(Commons.Color.popups.text, 0.06)
            borderSpec: tile.outline || tile.ghost || tile.pulled ? Border.flat(Commons.Color.accent, Math.max(1, Math.round(Style.space(1.5)))) : tile.isCursor && editor.gridFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : tile.isCursor ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1) : Border.none()
            Behavior on color {
                enabled: editor.bar.animationsEnabled
                ColorAnimation {
                    duration: 90
                }
            }
        }
        Row {
            id: chip
            x: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)
            // A keyboard lift shows what it carries in its outline; a pointer lift
            // carries it under the pointer, the inspector pulls it out in front.
            // Hidden widgets read dimmer.
            opacity: tile.outline ? (tile.placeholder && !editor.pointerLift ? 0.5 : 0) : tile.mode === "hidden" && tile.inLayer ? 0.5 : 1
            InkIcon {
                id: rowIcon
                record: tile.record
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: nameLabel
                text: tile.record.instanceKey ? editor.preferences.title(tile.record) : ""
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: Math.max(Style.space(16), tile.width - Style.space(16) - rowIcon.width - chip.spacing - (tile.memberCount > 0 ? memberPill.width + chip.spacing : 0))
                anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                id: memberPill
                visible: tile.memberCount > 0
                width: memberLabel.implicitWidth + Style.space(10)
                height: Style.space(16)
                radius: height / 2
                color: Qt.alpha(Commons.Color.popups.text, 0.12)
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: memberLabel
                    anchors.centerIn: parent
                    text: tile.memberCount
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }
    }

    // The inspector: the selected widget at the front of the stack, bottom
    // right, with where it is (its layer and zone) and how it behaves. Enter
    // or a click brings it out; Esc pushes it back (PREFS-101).
    component Inspector: BorderSurface {
        id: panel
        property bool shown: false
        readonly property var record: editor.inspected
        readonly property bool isGroup: !!record && !!record.groupId
        readonly property var group: isGroup ? editor.bar.groups.find(function (g) {
            return g.id === record.groupId;
        }) || null : null
        // A tray icon, and whether it is still in Omarchy's tray.
        readonly property bool trayIcon: !!record && !!record.trayItem
        readonly property bool inTray: !!record && record.mode === "tray"
        function focusFirst() {
            layerPicker.forceActiveFocus(Qt.TabFocusReason);
        }
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.min(editor.width, Style.space(670))
        height: body.implicitHeight + Style.space(22) + Style.space(16)
        z: 120
        radius: Math.min(Style.space(10), Style.cornerRadius)
        color: Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.alpha(Commons.Color.popups.text, 0.065))
        borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.16), 1)
        visible: opacity > 0
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.97
        transformOrigin: Item.Bottom
        Behavior on opacity {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        // Esc pushes the chip back; an open dropdown takes it first.
        Keys.onPressed: function (event) {
            if (event.key !== Qt.Key_Escape)
                return;
            editor.pushBack();
            event.accepted = true;
        }
        MouseArea {
            anchors.fill: parent
        }
        // The shadow it casts on the layers.
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: Style.space(10)
            anchors.bottomMargin: -Style.space(10)
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            radius: panel.radius
            color: Qt.rgba(0, 0, 0, 0.3)
        }

        Text {
            visible: !panel.record
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(22)
            text: editor.cursorCell.mode === "tray" ? "Nothing in the tray. Apps put their icons here while they run." : "Nothing " + (editor.cursorCell.mode === "shown" ? "on the bar in " : editor.cursorCell.mode === "managed" ? "on demand in " : "hidden in ") + editor.zoneNames[editor.cursorCell.section] + " yet. Pick up a widget with Space, or drag one here."
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }

        RowLayout {
            id: body
            visible: !!panel.record
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Style.space(22)
            anchors.rightMargin: Style.space(22)
            anchors.topMargin: Style.space(22)
            spacing: Style.space(24)

            // The widget as the bar draws it, its name and id.
            ColumnLayout {
                Layout.preferredWidth: Style.space(148)
                Layout.maximumWidth: Style.space(148)
                Layout.alignment: Qt.AlignTop
                spacing: Style.space(3)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(110)
                    Layout.bottomMargin: Style.space(9)
                    radius: Math.min(Style.space(6), Style.cornerRadius)
                    color: Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.rgba(0, 0, 0, 0.2))
                    clip: true
                    WidgetIcon {
                        anchors.centerIn: parent
                        preferences: editor.preferences
                        record: panel.record || ({})
                        size: Math.round(editor.iconSize * 2.4)
                        maxAspect: 1.5
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: panel.record ? editor.preferences.title(panel.record) : ""
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: panel.isGroup ? (panel.group ? panel.group.items.length + (panel.group.items.length === 1 ? " widget" : " widgets") + " in this group" : "") : panel.trayIcon ? (panel.inTray ? "In Omarchy's tray" : "Moved out of Omarchy's tray") : panel.record ? panel.record.id : ""
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.55)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                }
            }

            // Its layer: the way to move it without dragging.
            LayerPicker {
                id: layerPicker
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                record: panel.record
                withTray: panel.trayIcon
            }

            // Its zone, shortcut, activity and group.
            ColumnLayout {
                Layout.preferredWidth: Style.space(240)
                Layout.maximumWidth: Style.space(240)
                Layout.alignment: Qt.AlignTop
                spacing: Style.space(8)
                PrefsZoneMap {
                    compact: true
                    stacked: true
                    Layout.leftMargin: 0
                    zones: editor.zoneChoices
                    cameraOver: editor.previewCamera ? "center" : ""
                    noteFor: function (zone) {
                        return editor.cameraNote(zone);
                    }
                    marker: Component {
                        WidgetIcon {
                            preferences: editor.preferences
                            record: panel.record || ({})
                            size: Math.round(editor.iconSize * 0.6)
                            maxAspect: 1.6
                        }
                    }
                    value: panel.record && !panel.inTray ? panel.record.section : ""
                    // Out of the tray, an icon waits on demand until placed otherwise.
                    onChosen: function (value) {
                        editor.setPlacement(panel.record, value, panel.inTray ? "managed" : panel.record.mode);
                    }
                }
                Hint {
                    visible: panel.inTray
                    text: "Placed on the bar, it leaves the tray and works as it does there: click, right-click menu, scroll"
                }
                // Opens its panel (a group: its drawer) from anywhere.
                ShortcutRow {
                    visible: !panel.inTray
                    Layout.fillWidth: true
                    padding: 0
                    store: editor.preferences.shortcuts
                    target: !panel.record ? "" : panel.isGroup ? "group:" + panel.record.groupId : "widget:" + panel.record.id
                    unavailable: !panel.record ? "" : panel.record.mode === "hidden" ? (panel.isGroup ? "Hidden groups can't open" : "Hidden widgets can't open") : panel.isGroup || editor.bar.findPanelWidget(panel.record.id) || store.ready && store.info(target).keys ? "" : "Nothing to open"
                }
                PrefsToggle {
                    id: activityToggle
                    readonly property bool clockDriven: !!panel.record && !!editor.bar.quietActivityId(panel.record.id)
                    visible: !panel.isGroup && !panel.inTray
                    compact: true
                    label: "Peeks on activity"
                    enabled: editor.bar.autoHide && editor.bar.autoHideActivity && !clockDriven
                    opacity: enabled ? 1 : 0.45
                    checked: !!panel.record && !clockDriven && editor.bar.activityPeeksFor(panel.record.instanceKey, panel.record.id)
                    onToggled: function (checked) {
                        editor.bar.setActivityPeek(panel.record.instanceKey, checked);
                    }
                }
                Hint {
                    visible: !panel.isGroup && !panel.inTray && (activityToggle.clockDriven || editor.bar.autoHide && !editor.bar.autoHideActivity)
                    dim: true
                    text: activityToggle.clockDriven ? "It changes on a clock, so it never brings the bar out" : !editor.bar.autoHide ? "Applies while the bar autohides" : "Turned off for every widget on the Bar page"
                }
                // A group's members, by their faces.
                Flow {
                    visible: panel.isGroup
                    Layout.fillWidth: true
                    spacing: Style.space(6)
                    Repeater {
                        model: panel.group ? panel.group.items : []
                        WidgetIcon {
                            required property string modelData
                            preferences: editor.preferences
                            record: editor.preferences.entries.find(function (e) {
                                return e.instanceKey === modelData;
                            }) || ({})
                            size: Math.round(editor.iconSize * 0.85)
                        }
                    }
                }
                Dropdown {
                    visible: !panel.isGroup && !panel.inTray
                    Layout.fillWidth: true
                    label: "Group"
                    showLabel: false
                    options: [
                        {
                            value: "",
                            label: "Not grouped"
                        }
                    ].concat(editor.bar.groups.map(function (g) {
                        return {
                            value: g.id,
                            label: g.label
                        };
                    }))
                    value: ""
                    onChanged: function (value) {
                        if (value && panel.record)
                            editor.bar.assignGroup(panel.record.instanceKey, value, "");
                    }
                }
                Button {
                    visible: panel.isGroup
                    text: "Edit group"
                    iconText: "󰏫"
                    focusable: true
                    bordered: true
                    foreground: Commons.Color.popups.text
                    onClicked: editor.preferences.openGroup(panel.record.groupId)
                }
            }
        }
    }

    // The layers as a list of sheets: the widget's own is filled. One Tab
    // stop; j and k move the widget down or up a layer at once.
    component LayerPicker: Item {
        id: picker
        property var record: null
        property bool withTray: false
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
        readonly property string value: record ? record.mode : ""
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
        function choose(mode) {
            if (record)
                editor.setPlacement(record, record.section, mode);
        }
        function step(dy) {
            var i = options.findIndex(function (o) {
                return o.value === picker.value;
            });
            var next = Math.max(0, Math.min(options.length - 1, i + dy));
            if (next !== i)
                choose(options[next].value);
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
            spacing: 0
            Text {
                text: "Layer"
                textFormat: Text.PlainText
                color: Qt.alpha(Commons.Color.popups.text, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                bottomPadding: Style.space(6)
            }
            Repeater {
                model: picker.options
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool chosen: modelData.value === picker.value
                    width: rows.width
                    height: Style.space(30)
                    radius: Math.min(Style.space(5), Style.cornerRadius)
                    color: chosen ? Qt.alpha(Commons.Color.accent, 0.28) : rowMouse.containsMouse ? Qt.alpha(Commons.Color.popups.text, 0.06) : "transparent"
                    Behavior on color {
                        enabled: editor.bar.animationsEnabled
                        ColorAnimation {
                            duration: 90
                        }
                    }
                    // The sheet, seen in the layers' perspective.
                    Rectangle {
                        x: Style.space(18)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(34)
                        height: Style.space(10)
                        radius: Style.space(2)
                        color: row.chosen ? Commons.Color.accent : "transparent"
                        border.width: 1
                        border.color: row.chosen ? Qt.alpha(Commons.Color.accent, 0.9) : Qt.alpha(Commons.Color.popups.text, 0.4)
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -0.84, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }
                    Text {
                        x: Style.space(56)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        textFormat: Text.PlainText
                        color: Qt.alpha(Commons.Color.popups.text, row.chosen ? 1 : 0.7)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.choose(row.modelData.value)
                    }
                }
            }
            Row {
                topPadding: Style.space(8)
                leftPadding: Style.space(10)
                spacing: Style.space(4)
                KeyCap {
                    text: "j"
                    anchors.verticalCenter: parent.verticalCenter
                }
                KeyCap {
                    text: "k"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: Style.space(4)
                    text: "move it down or up a layer"
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.5)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }
    }

    component Hint: Text {
        property bool dim: false
        Layout.fillWidth: true
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, dim ? 0.35 : 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
    }
}
