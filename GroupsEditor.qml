import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PreferencesModel.js" as Model
import "GroupsModel.js" as Groups
import "GroupsEditorModel.js" as Editor

// The Groups page (docs/behavior/preferences.md PREFS-109 on), a stack of
// the Layout page's plates under the same camera (LayerPlate, ZoneTile,
// CameraShaft, CenterSideDot): "Groups", every group's face as a row in its
// zone's tile where the bar puts it, with the zone's "+" under them; "In the
// group", one drawer per zone showing its open group's widgets (the faces
// are its tabs, PREFS-120); the pool of widgets in no group as one dashed
// slab under both; and the chosen group's inspector at the bottom right with
// the keys beside it.
//
// Keyboard and pointer share one state machine (GroupsEditorModel.js): a
// cursor rests on a face, a zone's "+", a drawer's header or widget, or a
// widget in the pool; Space (or a drag) lifts a widget or a face, moving it
// previews where it lands (in a drawer, the pool, on a face, or a "+" for a
// new group; a face in a zone) and Space (or release) drops it. The plates
// are one Tab stop; the Center dot and the inspector are the others.
Item {
    id: editor
    required property var preferences
    // The Layout page's editor: its geometry, camera and how the bar draws things.
    required property var layout
    readonly property var bar: preferences.bar
    property string selectedId: ""
    // How far Preferences has slid the page off its place, as on the
    // Layout page.
    property real slide: 0
    // The keys are a legend on the page (PREFS-103), so the footer hides.
    readonly property var hints: []

    // ---------------------------------------------------------------- data
    readonly property var zones: Model.sections
    readonly property var groups: bar ? bar.groups : []
    function groupOf(id) {
        return groups.find(function (g) {
            return g.id === id;
        }) || null;
    }
    readonly property var selectedGroup: groupOf(selectedId)
    readonly property var entryIndex: {
        var out = ({});
        preferences.entries.forEach(function (e) {
            out[e.instanceKey] = e;
        });
        return out;
    }
    // Every group's face per zone in bar order, hidden ones where they would sit.
    readonly property var faces: Editor.railFaces(Groups.render(preferences.config && preferences.config.layout || ({}), Editor.railGroups(groups)), zones)
    readonly property var order: Editor.drawerOrder(faces, zones)
    readonly property var slots: Editor.drawerSlots(faces, zones)
    // Groups a drag opened by resting on their face (PREFS-120), per zone,
    // while it lasts.
    property var liftOpened: ({})
    // Each zone's open group, the one its drawer shows (PREFS-120).
    readonly property var openIds: {
        var out = ({});
        zones.forEach(function (zone) {
            out[zone] = Editor.openGroup(editor.faces, zone, editor.selectedId, editor.liftOpened);
        });
        return out;
    }
    // Each group's members (widgets still in the layout), in its order.
    readonly property var memberLists: {
        var out = ({});
        groups.forEach(function (g) {
            out[g.id] = g.items.map(function (key) {
                return editor.entryIndex[key];
            }).filter(function (r) {
                return !!r;
            });
        });
        return out;
    }
    readonly property int memberTotal: {
        var n = 0;
        for (var id in memberLists)
            n += memberLists[id].length;
        return n;
    }
    property string filterText: ""
    function poolOf(query) {
        return Editor.poolItems(preferences.entries, zones, function (key) {
            return !!editor.bar.groupFor(key);
        }, query, function (e) {
            return editor.preferences.title(e);
        });
    }
    readonly property var poolAll: poolOf("")
    readonly property var poolShown: poolOf(filterText)

    // --------------------------------------------------------- the cursor
    // The cursor's place (GroupsEditorModel), and what is there, so it
    // follows a face or a widget when the layout changes under it.
    property var at: ({
            area: "rail",
            zone: "left",
            slot: 0
        })
    property string cursorKey: ""
    property var lifted: null
    property var liftOrigin: null
    property var liftTarget: null
    property string liftHome: ""
    property bool pointerLift: false
    // Esc cancelled the pointer's lift while the button was still down: the
    // press is spent, so moving lifts nothing and the release does nothing
    // until the next press (PREFS-27).
    property bool pressSpent: false
    property var pressed: null
    property point pressPoint: Qt.point(0, 0)
    property point pointer: Qt.point(0, 0)
    property string hoverKey: ""
    property string pendingDissolve: ""
    readonly property string liftedKey: lifted && lifted.key ? lifted.key : ""
    readonly property bool liftingFace: !!lifted && !!lifted.face
    readonly property var counts: {
        var out = ({});
        for (var id in memberLists)
            out[id] = memberLists[id].filter(function (r) {
                return r.instanceKey !== editor.liftedKey;
            }).length;
        return out;
    }
    // A drawer as drawn: its members without a lifted widget, the lifted
    // one's landing place among them.
    function drawerList(id) {
        var list = (memberLists[id] || []).filter(function (r) {
            return r.instanceKey !== liftedKey;
        }).map(function (r) {
            return {
                record: r,
                placeholder: false
            };
        });
        if (lifted && !liftingFace && liftTarget && liftTarget.area === "drawer" && liftTarget.id === id)
            list.splice(Math.min(liftTarget.pos, list.length), 0, {
                record: lifted.record,
                placeholder: true
            });
        return list;
    }
    // The pool as drawn: a lifted widget landing in it shows where it goes,
    // in bar order.
    readonly property var poolList: {
        var list = poolShown.filter(function (r) {
            return r.instanceKey !== editor.liftedKey;
        }).map(function (r) {
            return {
                record: r,
                placeholder: false
            };
        });
        if (lifted && !liftingFace && liftTarget && liftTarget.area === "pool") {
            var r = lifted.record, i = list.findIndex(function (v) {
                return editor.zones.indexOf(v.record.section) > editor.zones.indexOf(r.section) || v.record.section === r.section && v.record.index > r.index;
            });
            list.splice(i < 0 ? list.length : i, 0, {
                record: r,
                placeholder: true
            });
        }
        return list;
    }
    readonly property int poolCount: poolShown.filter(function (r) {
        return r.instanceKey !== editor.liftedKey;
    }).length
    readonly property var stepState: ({
            zones: zones,
            faces: faces,
            members: counts,
            pool: poolCount,
            perRow: poolPerRow,
            chosen: selectedId,
            opened: liftOpened
        })
    function keyOf(p) {
        if (!p)
            return "";
        if (p.area === "rail") {
            var id = (faces[p.zone] || [])[p.slot];
            return id ? "face:" + id : "plus:" + p.zone;
        }
        if (p.area === "drawer") {
            var m = p.pos < 0 ? null : (memberLists[p.id] || []).filter(function (r) {
                return r.instanceKey !== editor.liftedKey;
            })[p.pos];
            return m ? "member:" + m.instanceKey : "header:" + p.id;
        }
        var v = poolShown.filter(function (r) {
            return r.instanceKey !== editor.liftedKey;
        })[p.pos];
        return v ? "pool:" + v.instanceKey : "pool:";
    }
    function place(p) {
        at = p;
        cursorKey = keyOf(p);
        var id = Editor.groupAt(stepState, p);
        if (id && id !== selectedId) {
            selectedId = id;
            pendingDissolve = "";
        }
        revealCursor();
    }
    // The place of what the cursor was on, after a change.
    function findKey(key) {
        var colon = key.indexOf(":"), kind = key.slice(0, colon), rest = key.slice(colon + 1);
        if (kind === "face")
            return Editor.facePlace(stepState, rest);
        if (kind === "plus")
            return zones.indexOf(rest) >= 0 ? {
                area: "rail",
                zone: rest,
                slot: (faces[rest] || []).length
            } : null;
        if (kind === "header")
            return Editor.facePlace(stepState, rest) ? {
                area: "drawer",
                id: rest,
                pos: -1
            } : null;
        if (kind === "member") {
            for (var id in memberLists) {
                var i = memberLists[id].findIndex(function (r) {
                    return r.instanceKey === rest;
                });
                if (i >= 0 && Editor.facePlace(stepState, id))
                    return {
                        area: "drawer",
                        id: id,
                        pos: i
                    };
            }
            var j = poolShown.findIndex(function (r) {
                return r.instanceKey === rest;
            });
            return j >= 0 ? {
                area: "pool",
                pos: j
            } : null;
        }
        if (kind === "pool" && rest) {
            var k = poolShown.findIndex(function (r) {
                return r.instanceKey === rest;
            });
            return k >= 0 ? {
                area: "pool",
                pos: k
            } : null;
        }
        return null;
    }
    function syncCursor() {
        if (lifted)
            return;
        var found = cursorKey ? findKey(cursorKey) : null;
        place(found || Editor.normalize(stepState, at));
    }
    onFacesChanged: syncLater.restart()
    onMemberListsChanged: syncLater.restart()
    onPoolShownChanged: syncLater.restart()
    Timer {
        id: syncLater
        interval: 0
        onTriggered: editor.syncCursor()
    }
    // A group is always chosen when there is one (PREFS-37): the first face.
    function chooseFirst() {
        if (!selectedGroup && order.length) {
            selectedId = order[0];
            place(Editor.firstPlace(stepState));
        }
    }
    onOrderChanged: Qt.callLater(chooseFirst)
    Component.onCompleted: Qt.callLater(chooseFirst)
    // Chosen from outside (g on a group icon, PREFS-32): the cursor goes to its face.
    onSelectedIdChanged: {
        pendingDissolve = "";
        if (selectedId && Editor.groupAt(stepState, at) !== selectedId) {
            var face = Editor.facePlace(stepState, selectedId);
            if (face)
                place(face);
        }
    }

    // -------------------------------------------------------------- edits
    function edit(id, patch) {
        if (id)
            bar.editGroups(function (config) {
                Groups.edit(config, id, patch);
            });
    }
    // A face to another zone, back at the place it had there this session
    // while its anchor is still there (Editor.zoneMove).
    property var zonePlaces: ({})
    function moveToZone(group, zone) {
        if (!group || group.section === zone)
            return;
        var moved = Editor.zoneMove(zonePlaces, group, zone, preferences.config && preferences.config.layout || ({}));
        zonePlaces = moved.memory;
        edit(group.id, moved.patch);
    }
    // A new group in a zone (PREFS-38), with a widget as its first member.
    function createIn(zone, key) {
        var id = "g-" + Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 7);
        bar.editGroups(function (config) {
            if (!Groups.create(config, id, "New group"))
                return;
            Groups.edit(config, id, {
                section: zone
            });
            if (key)
                Groups.assign(config, key, id, "");
        });
        selectedId = id;
        cursorKey = "face:" + id;
        syncLater.restart();
        Qt.callLater(function () {
            nameField.forceActiveFocus(Qt.OtherFocusReason);
            nameField.selectAll();
        });
    }
    // x twice within 3 s (PREFS-39): the members stay on the bar, in the pool.
    function dissolve(id) {
        if (!id)
            return;
        if (pendingDissolve !== id) {
            pendingDissolve = id;
            dissolveTimer.restart();
            return;
        }
        pendingDissolve = "";
        var i = order.indexOf(id), rest = order.filter(function (g) {
            return g !== id;
        });
        var next = rest.length ? rest[Math.max(0, Math.min(i, rest.length - 1))] : "";
        bar.editGroups(function (config) {
            Groups.remove(config, id);
        });
        selectedId = next;
        cursorKey = next ? "face:" + next : "";
        syncLater.restart();
    }
    Timer {
        id: dissolveTimer
        interval: 3000
        onTriggered: editor.pendingDissolve = ""
    }
    function takeOut(record) {
        if (!record)
            return;
        bar.assignGroup(record.instanceKey, "", "");
        cursorKey = "";
        syncLater.restart();
    }
    function addToChosen(record) {
        if (!record || !selectedGroup)
            return;
        bar.assignGroup(record.instanceKey, selectedId, "");
        cursorKey = "";
        syncLater.restart();
    }

    // -------------------------------------------------------------- lifts
    readonly property var cursorRecord: {
        if (at.area === "drawer" && at.pos >= 0)
            return (memberLists[at.id] || []).filter(function (r) {
                return r.instanceKey !== editor.liftedKey;
            })[at.pos] || null;
        if (at.area === "pool")
            return poolShown[at.pos] || null;
        return null;
    }
    function lift() {
        var record = cursorRecord;
        if (!record)
            return;
        liftOrigin = at;
        if (at.area === "drawer") {
            lifted = {
                key: record.instanceKey,
                group: at.id,
                pos: at.pos,
                record: record
            };
            liftTarget = {
                area: "drawer",
                id: at.id,
                pos: at.pos
            };
            liftHome = at.id;
        } else {
            lifted = {
                key: record.instanceKey,
                group: "",
                pos: -1,
                record: record
            };
            liftTarget = {
                area: "pool"
            };
            liftHome = selectedId;
        }
        hoverOn(null);
    }
    function liftFace(id) {
        var face = Editor.facePlace(stepState, id);
        if (!face)
            return;
        liftOrigin = face;
        lifted = {
            face: id,
            zone: face.zone
        };
        liftTarget = {
            area: "zone",
            zone: face.zone
        };
        hoverOn(null);
    }
    function cancel() {
        if (pointerLift) {
            pressed = null;
            pressSpent = true;
        }
        lifted = null;
        liftTarget = null;
        liftOpened = ({});
        faceRest.stop();
        pointerLift = false;
        if (liftOrigin)
            place(liftOrigin);
    }
    function drop() {
        if (!lifted)
            return;
        var carried = lifted, target = liftTarget;
        var into = target && target.area === "drawer" ? (memberLists[target.id] || []).filter(function (r) {
            return r.instanceKey !== carried.key;
        }).map(function (r) {
            return r.instanceKey;
        }) : [];
        var act = Editor.dropAction(carried, target, into, carried.group && target && target.id === carried.group ? carried.pos : -1);
        lifted = null;
        liftTarget = null;
        liftOpened = ({});
        faceRest.stop();
        pointerLift = false;
        if (act.op === "assign") {
            bar.assignGroup(act.key, act.id, act.before);
            cursorKey = (act.id ? "member:" : "pool:") + act.key;
        } else if (act.op === "create") {
            createIn(act.zone, act.key);
            return;
        } else if (act.op === "zone") {
            edit(act.id, {
                section: act.zone
            });
            cursorKey = "face:" + act.id;
        } else if (carried.face)
            cursorKey = "face:" + carried.face;
        else
            cursorKey = (carried.group ? "member:" : "pool:") + carried.key;
        syncLater.restart();
    }
    // A step of the cursor, or of a lifted widget's landing place; with
    // Shift a face changes zone (h l) or layer (j k), a widget moves at once.
    function step(dx, dy, carry) {
        if (lifted && !liftingFace) {
            liftTarget = Editor.stepLift(stepState, liftTarget, dx, dy, liftHome);
            if (liftTarget.area === "drawer")
                liftHome = liftTarget.id;
            revealCursor();
            return;
        }
        if (lifted) {
            if (dx)
                liftTarget = Editor.stepLift(stepState, liftTarget, dx, 0);
            return;
        }
        if (carry && (at.area === "rail" || at.area === "drawer" && at.pos < 0)) {
            var id = Editor.groupAt(stepState, at), group = groupOf(id);
            if (!group)
                return;
            if (dx) {
                var zone = Editor.nextZone(zones, group.section, dx);
                if (zone)
                    moveToZone(group, zone);
            } else {
                var v = Editor.nextVisibility(group.visibility, dy);
                if (v)
                    edit(id, {
                        visibility: v
                    });
            }
            cursorKey = (at.area === "drawer" ? "header:" : "face:") + id;
            syncLater.restart();
            return;
        }
        if (carry && cursorRecord) {
            lift();
            step(dx, dy, false);
            drop();
            return;
        }
        place(Editor.step(stepState, at, dx, dy));
    }
    function toRail() {
        place(Editor.firstPlace(stepState));
        stage.forceActiveFocus(Qt.OtherFocusReason);
    }
    function focusFirst() {
        stage.forceActiveFocus(Qt.TabFocusReason);
    }
    function keyPressed(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
            return;
        var key = event.key, t = event.text, c = t.toLowerCase();
        var carry = !!(event.modifiers & Qt.ShiftModifier);
        // While the pool's filter has text, letters type and the arrows walk.
        var typing = !lifted && at.area === "pool" && filterText !== "";
        var dx = key === Qt.Key_Left || !typing && c === "h" ? -1 : key === Qt.Key_Right || !typing && c === "l" ? 1 : 0;
        var dy = key === Qt.Key_Up || !typing && c === "k" ? -1 : key === Qt.Key_Down || !typing && c === "j" ? 1 : 0;
        if (dx || dy) {
            step(dx, dy, carry);
            event.accepted = true;
            return;
        }
        var enter = key === Qt.Key_Return || key === Qt.Key_Enter;
        if (lifted) {
            if (key === Qt.Key_Space || enter)
                drop();
            else if (key === Qt.Key_Escape)
                cancel();
            else
                return;
            event.accepted = true;
            return;
        }
        // A face, or a drawer's header: the group itself.
        var faceId = at.area === "rail" || at.area === "drawer" && at.pos < 0 ? Editor.groupAt(stepState, at) : "";
        var zone = at.area === "rail" ? at.zone : at.area === "drawer" ? Editor.zoneOfGroup(stepState, at.id) : "";
        if (at.area === "pool" && key === Qt.Key_Backspace && filterText)
            filterText = filterText.slice(0, -1);
        else if (at.area === "pool" && key === Qt.Key_Escape && filterText)
            filterText = "";
        else if (at.area === "pool" && key !== Qt.Key_Space && t.length === 1 && /\S/.test(t) && (typing || !/[0-9,]/.test(t))) {
            filterText += t;
            place({
                area: "pool",
                pos: 0
            });
        } else if (key === Qt.Key_Space && cursorRecord)
            lift();
        else if (key === Qt.Key_Space && faceId && at.area === "rail")
            liftFace(faceId);
        else if (enter && faceId) {
            nameField.forceActiveFocus(Qt.TabFocusReason);
            nameField.selectAll();
        } else if (enter && at.area === "rail" || c === "n" && zone)
            createIn(zone, "");
        else if (enter && at.area === "drawer" && cursorRecord)
            countField.forceActiveFocus(Qt.TabFocusReason);
        else if (enter && at.area === "pool")
            addToChosen(cursorRecord);
        else if ((c === "x" || key === Qt.Key_Delete) && faceId)
            dissolve(faceId);
        else if ((c === "x" || key === Qt.Key_Delete) && at.area === "drawer" && cursorRecord)
            takeOut(cursorRecord);
        else if (key === Qt.Key_Escape && at.area !== "rail")
            toRail();
        else
            return;
        event.accepted = true;
    }

    // ------------------------------------------------------------ geometry
    // The Layout page's: the same axis, columns, camera, tilt and tiles, so
    // switching pages moves nothing of the camera or the plates' frame.
    readonly property real axis: layout.axis
    readonly property real pageTop: layout.pageTop
    readonly property var columns: layout.columns
    readonly property real plateX: layout.plateX
    readonly property real plateWidth: layout.plateWidth
    readonly property real platePad: layout.platePad
    readonly property real tilt: layout.tilt
    readonly property real planeDistance: layout.planeDistance
    readonly property bool lightTheme: layout.lightTheme
    readonly property bool cameraShown: layout.previewCamera && !!layout.previewNotch
    readonly property real stackTop: layout.stackTop
    readonly property real tilePad: layout.tilePad
    readonly property real nameRow: layout.nameRow
    readonly property real chipHeight: layout.chipHeight
    readonly property real chipGap: layout.chipGap
    readonly property real chipWidth: layout.chipWidth
    readonly property real tileRaise: Style.space(5)
    // A zone's tile on a plate, in the plate: Center under the camera, as
    // on the Layout page.
    function column(zone) {
        return layout.column(zone);
    }
    // The pool's slab: across the five zones' columns, like the Hidden layer's.
    readonly property var slabBox: layout.column("hidden")
    readonly property real tileRadius: Math.min(Style.space(10), Style.cornerRadius)
    readonly property real chipRadius: Math.max(0, Math.min(Style.space(5), Style.cornerRadius - Style.space(3)))
    readonly property color pageColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    function tileColor(lead) {
        return Qt.tint(pageColor, Qt.alpha(Commons.Color.popups.text, lead ? 0.09 : 0.065));
    }
    function pillWidth(n) {
        return layout.textInk(String(n), Style.font.family, Style.font.caption).advance + Style.space(10);
    }
    // A drawer's header row and the hairline under it.
    readonly property real headerBlock: chipHeight + Style.space(5)
    function drawerNote(g) {
        return !g ? "" : g.visibility === "hidden" ? "Hidden: kept, never opens" : g.visibility === "managed" ? "On demand: behind its circle" : "";
    }
    readonly property real poolSpacing: layout.columnGap
    readonly property int poolPerRow: Editor.perRow(slabBox.width - 2 * tilePad, chipWidth, poolSpacing)
    readonly property int poolRows: Math.ceil(poolList.length / poolPerRow)
    // The bottom band: the legend's longest list (nine rows) with its
    // margins, or the inspector, whichever is taller (PREFS-115).
    KeyCap {
        id: capProbe
        visible: false
        text: "x"
    }
    readonly property real legendBand: Style.space(8) + Style.space(24) + 9 * capProbe.implicitHeight + 8 * Style.space(10)
    readonly property real bottomBand: Math.max(legendBand, selectedGroup ? inspector.height + Style.space(24) : 0)
    // The plates share the room as the Layout page's layers do (PREFS-106,
    // PREFS-115): the faces' plate fixed at four rows and the "+", the
    // drawers' as tall as the tallest drawer (four rows at most) and met
    // first, the pool its rows with what is left.
    readonly property var drawerSizes: drawerTiles.list.map(function (d) {
        return d.size;
    })
    readonly property var needs: Editor.plateNeeds({
        pad: tilePad,
        nameRow: nameRow,
        chip: chipHeight,
        gap: chipGap,
        header: headerBlock,
        drawers: drawerSizes,
        slack: Style.space(4),
        poolRows: poolRows,
        poolGap: poolSpacing,
        poolLabel: poolFace.labelBottom + Style.space(8) + filterBox.height + Style.space(8),
        // The pool's label column may hang into the bottom band over the
        // legend's spare room (on a tilted plate a length is seen shorter).
        labelRoom: bottomBand - legendBand
    })
    readonly property var plateHeights: Model.shareLayers(needs.demands, needs.floors, Math.max(0, height - stackTop - bottomBand), tilt, planeDistance, layout.layerGap, needs.first)
    readonly property var stack: Model.stackLayers(plateHeights, tilt, planeDistance, layout.layerGap)
    // Where a point on a plate (its own coordinates, before the tilt) is
    // seen in the page: plates turn about their top edge, seen about the axis.
    function seen(plate, px, py) {
        var h = Model.tiltedHeight(py, tilt, planeDistance);
        return Qt.point(axis + Model.tiltedSpread(plateX + px - axis, h, tilt, planeDistance), plate.y + h);
    }

    // ---------------------------------------------------------- the camera
    // The Layout page's camera with the Layout page's own arguments, so the
    // two pages draw the same shade everywhere and switching pages changes
    // nothing of it: its cap torn a little above the first plate, its shade
    // over the Center tiles under it (PREFS-24, PREFS-109).
    readonly property Item layoutCamera: layout.beamCamera
    CameraShaft {
        id: camera
        visible: editor.cameraShown
        opacity: editor.slide === 0 ? 1 : 0
        z: -1
        axis: editor.layoutCamera.axis
        half: editor.layoutCamera.half
        line: editor.layoutCamera.line
        pageTop: editor.layoutCamera.pageTop
        beamBottom: editor.layoutCamera.beamBottom
        tilt: editor.layoutCamera.tilt
        planeDistance: editor.layoutCamera.planeDistance
        lightTheme: editor.layoutCamera.lightTheme
    }
    readonly property Item beamCamera: camera

    // Which side of the camera Center sits on, as on the Layout page
    // (PREFS-105, PREFS-123): the same dot and leader, from this page's
    // Center tile.
    readonly property real centerTileRaise: {
        var t = faceTiles.list.find(function (c) {
            return c.zone === "center";
        });
        return t ? t.raise : 0;
    }
    CenterSideDot {
        id: centerDot
        z: 115
        x: -editor.slide
        opacity: 1 - Math.min(1, Math.abs(editor.slide) / Math.max(1, editor.width))
        width: editor.width
        height: editor.height
        camera: editor.beamCamera
        axis: editor.axis
        startY: editor.stackTop - editor.centerTileRaise
        pageTop: editor.pageTop
        side: editor.layout.centerSide
        label: editor.layout.zoneNames.center || "Center"
        animate: editor.bar.animationsEnabled
        onChosen: function (side) {
            editor.layout.setCenterSide(side);
        }
    }
    readonly property Item sideDot: centerDot.dot

    // Tiles by zone, for the pointer, the leaders and the windows.
    component TileList: QtObject {
        property var list: []
        function add(t) {
            list = list.concat([t]);
        }
        function drop(t) {
            list = list.filter(function (x) {
                return x !== t;
            });
        }
        function of(zone) {
            return list.find(function (t) {
                return t.zone === zone;
            }) || null;
        }
    }
    TileList {
        id: faceTiles
    }
    TileList {
        id: drawerTiles
    }

    // ------------------------------------------------------ the faces' plate
    // The Layout page's bar layer: each zone's tile holds its groups' faces
    // in bar order, a row each, four in view (PREFS-121), its "+" under them.
    Item {
        id: facesPlate
        x: editor.plateX
        y: editor.stackTop + (editor.stack.layers[0] ? editor.stack.layers[0].top : 0)
        width: editor.plateWidth
        height: editor.stack.layers[0] ? editor.stack.layers[0].height : 0
        z: 2
        LayerPlate {
            id: facesFace
            width: facesPlate.width
            height: editor.plateHeights[0] || 0
            columns: editor.columns
            pad: editor.platePad
            axisX: editor.axis - editor.slide - facesPlate.x
            tilt: editor.tilt
            planeDistance: editor.planeDistance
            animate: editor.bar.animationsEnabled
            title: "Groups"
            caption: "Each face where the bar puts it"
            count: editor.groups.length + (editor.groups.length === 1 ? " group" : " groups")
            Repeater {
                model: editor.zones
                FaceTile {
                    seenTop: facesPlate.y
                    height: facesFace.height
                }
            }
        }
    }
    // Each zone's open face (PREFS-120) has a dot at its bottom middle and a
    // dashed leader straight down to its drawer's header on the next plate:
    // full accent for the chosen group, 45 % for the others.
    Repeater {
        model: editor.zones
        Shape {
            id: faceLeader
            required property string modelData
            readonly property string groupId: editor.openIds[modelData] || ""
            readonly property Item tile: faceTiles.of(modelData)
            readonly property Item drawer: drawerTiles.of(modelData)
            readonly property int row: (editor.faces[modelData] || []).indexOf(groupId)
            readonly property var box: editor.column(modelData)
            // The face's bottom middle, or the window's edge it went past.
            readonly property real rowBottom: tile ? Math.max(tile.viewTop, Math.min(tile.viewTop + tile.viewHeight, tile.viewTop + row * tile.rowStep - tile.scroll + editor.chipHeight)) : 0
            readonly property point from: tile ? editor.seen(facesPlate, box.x + box.width / 2, rowBottom - tile.raise) : Qt.point(0, 0)
            readonly property point to: drawer ? editor.seen(drawersPlate, box.x + box.width / 2, drawer.pad + editor.nameRow - drawer.raise) : Qt.point(0, 0)
            visible: !!groupId && row >= 0 && !!tile && !!drawer
            z: 4
            anchors.fill: parent
            ShapePath {
                strokeColor: Qt.alpha(Commons.Color.accent, faceLeader.groupId === editor.selectedId ? 1 : 0.45)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                fillColor: "transparent"
                startX: faceLeader.from.x
                startY: faceLeader.from.y
                PathLine {
                    x: faceLeader.to.x
                    y: faceLeader.to.y
                }
            }
        }
    }

    // ---------------------------------------------------- the drawers' plate
    // The same plate again: each zone's tile is its one drawer, showing its
    // open group (PREFS-113, PREFS-120, PREFS-122).
    Item {
        id: drawersPlate
        x: editor.plateX
        y: editor.stackTop + (editor.stack.layers[1] ? editor.stack.layers[1].top : 0)
        width: editor.plateWidth
        height: editor.stack.layers[1] ? editor.stack.layers[1].height : 0
        z: 1
        Behavior on y {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        LayerPlate {
            id: drawersFace
            width: drawersPlate.width
            height: editor.plateHeights[1] || 0
            columns: editor.columns
            pad: editor.platePad
            axisX: editor.axis - editor.slide - drawersPlate.x
            tilt: editor.tilt
            planeDistance: editor.planeDistance
            animate: editor.bar.animationsEnabled
            title: "In the group"
            caption: "What the open group in each zone holds"
            count: {
                var n = 0;
                editor.zones.forEach(function (zone) {
                    n += (editor.memberLists[editor.openIds[zone]] || []).length;
                });
                return n + (n === 1 ? " widget" : " widgets");
            }
            Repeater {
                model: editor.zones
                DrawerTile {
                    seenTop: drawersPlate.y
                    height: drawersFace.height
                }
            }
        }
    }

    // ------------------------------------------------------------ the pool
    // One dashed slab across the zones' columns under both, tilted like a
    // layer, its name, count and the filter on its label column (PREFS-114).
    Item {
        id: poolPlate
        x: editor.plateX
        y: editor.stackTop + (editor.stack.layers[2] ? editor.stack.layers[2].top : 0)
        width: editor.plateWidth
        height: editor.stack.layers[2] ? editor.stack.layers[2].height : 0
        z: 1
        Behavior on y {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        LayerPlate {
            id: poolFace
            width: poolPlate.width
            height: editor.plateHeights[2] || 0
            columns: editor.columns
            pad: editor.platePad
            axisX: editor.axis - editor.slide - poolPlate.x
            tilt: editor.tilt
            planeDistance: editor.planeDistance
            animate: editor.bar.animationsEnabled
            title: "Not in a group"
            caption: "In bar order, zone by zone"
            count: editor.poolAll.length + (editor.poolAll.length === 1 ? " widget" : " widgets")
            // The filter (PREFS-42): typing while the pool has the cursor fills it.
            BorderSurface {
                id: filterBox
                readonly property bool live: editor.at.area === "pool" && stage.activeFocus
                x: poolFace.labelX
                y: poolFace.labelBottom + Style.space(8)
                width: poolFace.labelWidth
                height: Style.space(26)
                antialiasing: true
                radius: editor.chipRadius
                color: "transparent"
                borderSpec: Border.flat(live && editor.filterText ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.14), 1)
                GrayText {
                    x: Style.space(8)
                    width: parent.width - 2 * x
                    anchors.verticalCenter: parent.verticalCenter
                    text: editor.filterText || "Filter " + editor.poolAll.length + (editor.poolAll.length === 1 ? " widget" : " widgets")
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, editor.filterText ? 0.9 : 0.45)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideLeft
                }
            }
            ZoneTile {
                id: poolCell
                readonly property bool targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "pool"
                readonly property bool cursorHere: !editor.lifted && editor.at.area === "pool"
                x: editor.slabBox.x
                width: editor.slabBox.width
                height: poolFace.height
                animate: editor.bar.animationsEnabled
                lightTheme: editor.lightTheme
                dashed: true
                dashLit: targeted
                pad: editor.tilePad
                nameShown: false
                viewTop: pad
                chipHeight: editor.chipHeight
                spacing: editor.poolSpacing
                flowWidth: Math.max(1, width - 2 * pad)
                perRow: editor.poolPerRow
                current: cursorHere
                model: poolTiles.model
                GrayText {
                    x: poolCell.pad + Style.space(2)
                    y: poolCell.pad + Style.space(5)
                    width: parent.width - 2 * x
                    visible: editor.poolList.length === 0
                    text: editor.filterText ? "No widget matches “" + editor.filterText + "”. Esc clears the filter." : "Every widget is in a group. x on one in a drawer, or a drag here, takes it out."
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.3)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }
                RetainedList {
                    id: poolTiles
                    recordProperty: "retainedRecord"
                    records: editor.poolList.map(function (value, index) {
                        return {
                            key: value.placeholder ? "insertion-gap" : value.record.instanceKey,
                            entry: value.record,
                            placeholder: value.placeholder,
                            index: index
                        };
                    })
                    factory: Component {
                        Chip {
                            required property var retainedRecord
                            record: retainedRecord.entry
                            placeholder: retainedRecord.placeholder
                            area: "pool"
                            pos: retainedRecord.index
                            width: editor.chipWidth
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- the stage
    // The plates: one Tab stop with one cursor, and every pointer gesture
    // over them, mapped through the tilt.
    Item {
        id: stage
        readonly property bool ownsFocusRing: true
        anchors.fill: parent
        z: 50
        activeFocusOnTab: true
        Accessible.role: Accessible.List
        Accessible.name: "Groups"
        Accessible.description: editor.cursorRecord ? editor.preferences.title(editor.cursorRecord) : editor.selectedGroup ? editor.selectedGroup.label : "No groups yet"
        Keys.onPressed: function (event) {
            editor.keyPressed(event);
        }
        onActiveFocusChanged: if (!activeFocus)
            Qt.callLater(function () {
                if (!stage.activeFocus && editor.lifted && !editor.pointerLift)
                    editor.cancel();
            })
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: editor.pointerLift ? Qt.ClosedHandCursor : editor.hoverKey.indexOf("member:") === 0 || editor.hoverKey.indexOf("pool:") === 0 || editor.hoverKey.indexOf("face:") === 0 ? Qt.OpenHandCursor : editor.hoverKey.indexOf("plus:") === 0 || editor.hoverKey.indexOf("header:") === 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPositionChanged: function (mouse) {
                var point = Qt.point(mouse.x, mouse.y);
                if (!editor.pointerLift) {
                    var hit = editor.hitAt(point);
                    editor.hoverKey = hit ? hit.key : "";
                    editor.hoverOn(pressed ? null : hit);
                }
                if (pressed && editor.pressed && !editor.pointerLift && Math.abs(point.x - editor.pressPoint.x) + Math.abs(point.y - editor.pressPoint.y) > Style.space(6)) {
                    if (editor.pressed.kind === "face")
                        editor.liftFace(editor.pressed.id);
                    else
                        editor.lift();
                    editor.pointerLift = !!editor.lifted;
                }
                editor.pointerMoved(point);
            }
            onExited: {
                if (!editor.pointerLift)
                    editor.hoverKey = "";
                editor.hoverOn(null);
            }
            onWheel: function (wheel) {
                var point = Qt.point(wheel.x, wheel.y);
                var win = editor.windowAt(point);
                if (!win || !win.overflows) {
                    wheel.accepted = false;
                    return;
                }
                win.scrollBy(wheel.pixelDelta.y ? -wheel.pixelDelta.y : -wheel.angleDelta.y / 120 * win.rowStep);
                editor.pointerMoved(point);
            }
            onPressed: function (mouse) {
                editor.hoverOn(null);
                if (editor.lifted)
                    editor.cancel();
                editor.pressSpent = false;
                var point = Qt.point(mouse.x, mouse.y);
                editor.pressPoint = point;
                var hit = editor.hitAt(point);
                editor.pressed = hit && (hit.kind === "member" || hit.kind === "poolchip" || hit.kind === "face") ? hit : null;
                if (hit && hit.place)
                    editor.place(hit.place);
                stage.forceActiveFocus(Qt.MouseFocusReason);
            }
            onReleased: function (mouse) {
                var clicked = !editor.pointerLift && !editor.pressSpent;
                editor.pressed = null;
                editor.pressSpent = false;
                if (editor.pointerLift)
                    editor.drop();
                else if (clicked) {
                    var hit = editor.hitAt(Qt.point(mouse.x, mouse.y));
                    if (hit && hit.kind === "plus")
                        editor.createIn(hit.zone, "");
                }
            }
            onCanceled: {
                editor.pressed = null;
                if (editor.pointerLift)
                    editor.cancel();
            }
        }
    }
    // What is under the pointer, in the editor, through the plates' tilt: a
    // face, a "+", a zone's tile on the first plate; a drawer's header, a
    // member or the drawer; a pool chip or the pool.
    function inside(item, point) {
        if (!item || !item.visible)
            return false;
        var p = item.mapFromItem(editor, point.x, point.y);
        return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height;
    }
    function inView(win, point) {
        return win.viewContains(win.mapFromItem(editor, point.x, point.y));
    }
    function hitAt(point) {
        for (var z = 0; z < zones.length; z++) {
            var t = faceTiles.of(zones[z]);
            if (!inside(t, point))
                continue;
            if (inside(t.plus, point))
                return {
                    kind: "plus",
                    zone: t.zone,
                    key: "plus:" + t.zone,
                    place: {
                        area: "rail",
                        zone: t.zone,
                        slot: (faces[t.zone] || []).length
                    }
                };
            var row = inView(t, point) ? tileIn(t, point) : null;
            if (row)
                return {
                    kind: "face",
                    id: row.groupId,
                    key: "face:" + row.groupId,
                    place: {
                        area: "rail",
                        zone: t.zone,
                        slot: row.index
                    }
                };
            return {
                kind: "zone",
                zone: t.zone,
                key: ""
            };
        }
        for (var d = 0; d < zones.length; d++) {
            var drawer = drawerTiles.of(zones[d]);
            if (!inside(drawer, point))
                continue;
            if (!drawer.groupId)
                return null;
            if (inside(drawer.header, point))
                return {
                    kind: "header",
                    id: drawer.groupId,
                    key: "header:" + drawer.groupId,
                    drawer: drawer,
                    place: {
                        area: "drawer",
                        id: drawer.groupId,
                        pos: -1
                    }
                };
            var tile = inView(drawer, point) ? tileIn(drawer, point) : null;
            if (tile)
                return {
                    kind: "member",
                    id: drawer.groupId,
                    record: tile.record,
                    key: "member:" + tile.record.instanceKey,
                    place: {
                        area: "drawer",
                        id: drawer.groupId,
                        pos: tile.pos
                    }
                };
            return {
                kind: "drawer",
                id: drawer.groupId,
                key: "",
                drawer: drawer,
                place: Editor.facePlace(stepState, drawer.groupId) ? {
                    area: "drawer",
                    id: drawer.groupId,
                    pos: -1
                } : null
            };
        }
        if (inside(poolCell, point)) {
            var chip = inView(poolCell, point) ? tileIn(poolCell, point) : null;
            if (chip)
                return {
                    kind: "poolchip",
                    record: chip.record,
                    key: "pool:" + chip.record.instanceKey,
                    place: {
                        area: "pool",
                        pos: chip.pos
                    }
                };
            return {
                kind: "pool",
                key: "",
                place: {
                    area: "pool",
                    pos: editor.at.area === "pool" ? editor.at.pos : 0
                }
            };
        }
        return null;
    }
    function tileIn(win, point) {
        for (var i = 0; i < win.tiles.count; i++) {
            var tile = win.tiles.itemAt(i);
            if (!tile || tile.placeholder)
                continue;
            var p = tile.mapFromItem(editor, point.x, point.y);
            if (p.x >= 0 && p.y >= 0 && p.x < tile.width && p.y < tile.height)
                return tile;
        }
        return null;
    }
    // The gap in a drawer under the pointer: before the first real chip
    // whose middle the pointer has not passed.
    function gapIn(win, point) {
        var pos = 0;
        for (var i = 0; i < win.tiles.count; i++) {
            var tile = win.tiles.itemAt(i);
            if (!tile || tile.placeholder)
                continue;
            if (tile.mapFromItem(editor, point.x, point.y).y < tile.height / 2)
                return pos;
            pos++;
        }
        return pos;
    }
    // The scrolling window under the pointer: a zone's faces, a drawer or the pool.
    function windowAt(point) {
        for (var z = 0; z < zones.length; z++) {
            var t = faceTiles.of(zones[z]);
            if (inside(t, point))
                return t;
            var d = drawerTiles.of(zones[z]);
            if (inside(d, point))
                return d.groupId ? d : null;
        }
        return inside(poolCell, point) ? poolCell : null;
    }
    function pointerMoved(point) {
        pointer = point;
        if (!pointerLift)
            return;
        var hit = hitAt(point), next = null;
        if (liftingFace)
            next = hit && (hit.kind === "zone" || hit.kind === "face" || hit.kind === "plus") ? {
                area: "zone",
                zone: hit.kind === "face" ? slots[hit.id].zone : hit.zone
            } : null;
        else if (hit && (hit.kind === "member" || hit.kind === "drawer" || hit.kind === "header"))
            next = {
                area: "drawer",
                id: hit.id,
                pos: hit.kind === "header" ? 0 : gapIn(hit.drawer || drawerFor(hit.id), point)
            };
        else if (hit && (hit.kind === "pool" || hit.kind === "poolchip"))
            next = {
                area: "pool"
            };
        else if (hit && hit.kind === "plus")
            next = {
                area: "plus",
                zone: hit.zone
            };
        else if (hit && hit.kind === "face")
            next = {
                area: "face",
                id: hit.id
            };
        if (JSON.stringify(next) !== JSON.stringify(liftTarget)) {
            liftTarget = next;
            // Resting 400 ms on a face opens its group in the zone's drawer.
            if (next && next.area === "face")
                faceRest.restart();
            else
                faceRest.stop();
        }
        // Held near a scrolling window's top or bottom edge, the drag scrolls it.
        var win = windowAt(point), dir = 0;
        if (win && win.overflows) {
            var w = win.mapFromItem(editor, point.x, point.y), band = Style.space(24);
            if (w.y < win.viewTop + band && win.scroll > 0)
                dir = -1;
            else if (w.y > win.viewTop + win.viewHeight - band && win.scroll < win.maxScroll)
                dir = 1;
        }
        autoScroll.target = dir ? win : null;
        autoScroll.dir = dir;
    }
    Timer {
        id: faceRest
        interval: 400
        onTriggered: {
            var t = editor.liftTarget, slot = t && t.area === "face" ? editor.slots[t.id] : null;
            if (!editor.pointerLift || !slot || editor.openIds[slot.zone] === t.id)
                return;
            var o = Object.assign({}, editor.liftOpened);
            o[slot.zone] = t.id;
            editor.liftOpened = o;
        }
    }
    function drawerFor(id) {
        return drawerTiles.list.find(function (d) {
            return !!id && d.groupId === id;
        }) || null;
    }
    Timer {
        id: autoScroll
        property Item target: null
        property int dir: 0
        interval: 16
        repeat: true
        running: !!target && dir !== 0 && editor.pointerLift
        onTriggered: {
            target.scrollBy(dir * Style.space(3));
            editor.pointerMoved(editor.pointer);
        }
    }
    // The cursor's row, or a lifted one's landing place, scrolls into view.
    function revealCursor() {
        var p = lifted && liftTarget ? liftTarget : at;
        if (p.area === "rail" || p.area === "face" || p.area === "plus") {
            var face = p.area === "rail" ? p : p.area === "face" ? Editor.facePlace(stepState, p.id) : null;
            var t = face ? faceTiles.of(face.zone) : null;
            if (t && face.slot < (faces[face.zone] || []).length)
                t.reveal(face.slot);
        } else if (p.area === "drawer") {
            var d = drawerFor(p.id);
            if (d && p.pos >= 0)
                d.reveal(p.pos);
        } else if (p.area === "pool")
            poolCell.reveal(lifted ? Math.max(0, poolList.findIndex(function (v) {
                return v.placeholder;
            })) : p.pos);
    }

    // ------------------------------------------------------- the dragged copy
    // The lifted chip or face, flat over the plates: under the pointer while
    // it drags, over the landing place during a keyboard lift (PREFS-122).
    // A widget over a "+" rides a row higher, so the "+"'s highlight stays in
    // sight; a face sits on the row it lands on.
    property point keyLanding: Qt.point(0, 0)
    property bool keyLandingShown: false
    // The centre of the landing place in the editor: the placeholder in a
    // drawer or the pool, the face a widget goes into, the "+" (a new group),
    // or for a face its own row while over its own zone, else the "+" of the
    // zone it goes to (it lands at the end, where the "+" is).
    function landingItem() {
        var t = liftTarget;
        if (!lifted || !t)
            return null;
        var home = liftingFace && t.zone === lifted.zone;
        if (liftingFace && !home || t.area === "plus") {
            var tile = faceTiles.of(t.zone);
            return tile ? tile.plus : null;
        }
        var win = home ? faceTiles.of(t.zone) : t.area === "drawer" ? drawerFor(t.id) : t.area === "pool" ? poolCell : t.area === "face" ? faceTiles.of(slots[t.id] ? slots[t.id].zone : "") : null;
        if (!win || !win.tiles)
            return null;
        var id = home ? lifted.face : t.id;
        for (var i = 0; i < win.tiles.count; i++) {
            var item = win.tiles.itemAt(i);
            if (item && (home || t.area === "face" ? item.groupId === id : item.placeholder))
                return item;
        }
        return null;
    }
    function updateKeyLanding() {
        var item = !pointerLift ? landingItem() : null;
        if (!item) {
            keyLandingShown = false;
            return;
        }
        keyLanding = item.mapToItem(editor, item.width / 2, item.height / 2);
        keyLandingShown = true;
    }
    onLiftTargetChanged: { Qt.callLater(updateKeyLanding); keyLandingSettle.restart(); }
    onLiftedChanged: Qt.callLater(updateKeyLanding)
    onPointerLiftChanged: {
        if (!pointerLift)
            autoScroll.target = null;
        Qt.callLater(updateKeyLanding);
    }
    // Again once the rows have moved aside for the landing place.
    Timer {
        id: keyLandingSettle
        interval: 160
        onTriggered: editor.updateKeyLanding()
    }
    readonly property bool copyShown: !!lifted && (pointerLift || keyLandingShown)
    readonly property point copyAt: {
        var p = pointerLift ? pointer : keyLanding;
        var overPlus = !!liftTarget && liftTarget.area === "plus";
        return Qt.point(p.x, p.y - (overPlus ? chipHeight + chipGap : pointerLift ? 0 : Style.space(4)));
    }
    Chip {
        visible: editor.copyShown && !editor.liftingFace
        record: editor.lifted && editor.lifted.record || ({})
        ghost: true
        width: editor.chipWidth
        x: editor.copyAt.x - width / 2
        y: editor.copyAt.y - height / 2
        z: 100
    }
    FaceLook {
        visible: editor.copyShown && editor.liftingFace
        group: editor.liftingFace ? editor.groupOf(editor.lifted.face) : null
        ghost: true
        width: editor.chipWidth
        x: editor.copyAt.x - width / 2
        y: editor.copyAt.y - height / 2
        z: 100
    }

    // -------------------------------------------------------------- the tip
    // A face's or a widget's full name after a short rest on it, a "+"'s
    // "New group in Left" (PREFS-100).
    property var hoverHit: null
    property bool tipWarm: false
    function hoverOn(hit) {
        var key = hit ? hit.key : "";
        if (key === (hoverHit ? hoverHit.key : ""))
            return;
        hoverHit = key ? hit : null;
        if (!key || lifted) {
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
        var hit = hoverHit;
        if (!hit || lifted)
            return;
        var g = hit.kind === "face" ? groupOf(hit.id) : null;
        nameTip.record = hit.record || ({});
        nameTip.title = hit.kind === "plus" ? "New group in " + layout.zoneNames[hit.zone] : g ? g.label : hit.record ? preferences.title(hit.record) : "";
        var n = g ? (memberLists[g.id] || []).length : 0;
        nameTip.detail = hit.kind === "plus" ? "" : g ? "Group, " + n + (n === 1 ? " widget" : " widgets") : hit.record ? hit.record.id : "";
        nameTip.at = pointer;
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
    BorderSurface {
        id: nameTip
        property bool shown: false
        property var record: ({})
        property string title: ""
        property string detail: ""
        // Where the pointer rested; the tip is placed from its laid-out
        // size, kept inside the page, in front of everything (the inspector too).
        property point at: Qt.point(0, 0)
        readonly property real gap: Style.space(10)
        x: Math.max(0, Math.min(editor.width - width, at.x - width / 2))
        y: at.y + gap + Style.space(16) + height <= editor.height ? at.y + gap + Style.space(16) : at.y - gap - height
        z: 130
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
        color: Qt.tint(editor.pageColor, Qt.alpha(Commons.Color.popups.text, 0.1))
        borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.16), 1)
        Row {
            id: tipRow
            anchors.centerIn: parent
            spacing: Style.space(10)
            InkIcon {
                visible: !!nameTip.record.instanceKey
                layout: editor.layout
                record: nameTip.record
                anchors.verticalCenter: parent.verticalCenter
            }
            GrayText {
                anchors.verticalCenter: parent.verticalCenter
                text: nameTip.title
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }
            GrayText {
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: nameTip.detail
                textFormat: Text.PlainText
                color: Qt.alpha(Commons.Color.popups.text, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
    }

    // -------------------------------------------------------- the inspector
    // The member the cursor is on, for its badge sources.
    readonly property var member: !lifted && at.area === "drawer" && at.id === selectedId ? cursorRecord : null
    BorderSurface {
        id: inspector
        readonly property bool shown: !!editor.selectedGroup
        readonly property var group: editor.selectedGroup
        // Tab and Shift+Tab walk the inspector's controls and wrap round
        // inside it (PREFS-26): a stop before the first control and one
        // after the last send focus on round.
        property Item lastInside: null
        function lastControl() {
            var last = nameField;
            for (var item = nameField.nextItemInFocusChain(true); item && item !== endFence && item !== nameField && editor.within(item, inspector); item = item.nextItemInFocusChain(true))
                last = item;
            return last;
        }
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.min(editor.width, Style.space(670))
        height: inspectorBody.implicitHeight + Style.space(22) + Style.space(16)
        z: 120
        radius: editor.tileRadius
        color: editor.tileColor(false)
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
        // Esc returns to the rail; a control that takes it gets it first.
        Keys.onPressed: function (event) {
            if (event.key !== Qt.Key_Escape)
                return;
            editor.toRail();
            event.accepted = true;
        }
        Connections {
            target: editor
            function onFocusedChanged() {
                var f = editor.focused;
                if (f && f !== startFence && f !== endFence && editor.within(f, inspector))
                    inspector.lastInside = f;
            }
        }
        Item {
            id: startFence
            activeFocusOnTab: inspector.shown
            onActiveFocusChanged: if (activeFocus)
                (inspector.lastInside === nameField ? inspector.lastControl() : nameField).forceActiveFocus(Qt.TabFocusReason)
        }
        MouseArea {
            anchors.fill: parent
        }
        // The shadow it casts on the page.
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: Style.space(10)
            anchors.bottomMargin: -Style.space(10)
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            radius: inspector.radius
            color: Qt.rgba(0, 0, 0, 0.3)
        }
        ColumnLayout {
            id: inspectorBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Style.space(22)
            anchors.rightMargin: Style.space(22)
            anchors.topMargin: Style.space(22)
            spacing: Style.space(12)
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(24)
                // The face as the bar draws it, its name, where it is, Dissolve.
                ColumnLayout {
                    Layout.preferredWidth: Style.space(148)
                    Layout.maximumWidth: Style.space(148)
                    Layout.alignment: Qt.AlignTop
                    spacing: Style.space(6)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(54)
                        radius: Math.min(Style.space(6), Style.cornerRadius)
                        color: editor.layout.barSurface
                        clip: true
                        BarFace {
                            anchors.centerIn: parent
                            face: inspector.group ? editor.layout.groupFace(inspector.group, "") : null
                            barThickness: editor.layout.barThickness
                            ink: editor.layout.barInk
                            fontFamily: editor.layout.barFont
                        }
                    }
                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        Layout.topMargin: Style.space(4)
                        // Typing breaks a plain binding: this one comes back whenever the
                        // field is not being edited, so another group or widget shows its own.
                        Binding on text {
                            value: inspector.group ? inspector.group.label : ""
                            when: !nameField.activeFocus
                            restoreMode: Binding.RestoreNone
                        }
                        placeholderText: "Group name"
                        foreground: Commons.Color.popups.text
                        font.bold: true
                        Accessible.name: "Group name"
                        readonly property var keyHints: [
                            {
                                keys: "enter",
                                label: "Rename"
                            }
                        ]
                        onEditingFinished: if (inspector.group && text.trim() && text.trim() !== inspector.group.label)
                            editor.edit(inspector.group.id, {
                                label: text
                            })
                        Keys.onEscapePressed: function (event) {
                            text = inspector.group ? inspector.group.label : "";
                            editor.toRail();
                            event.accepted = true;
                        }
                    }
                    GrayText {
                        Layout.fillWidth: true
                        readonly property int n: inspector.group ? (editor.memberLists[inspector.group.id] || []).length : 0
                        text: !inspector.group ? "" : n + (n === 1 ? " widget, " : " widgets, ") + (inspector.group.visibility === "hidden" ? "hidden, zone " + editor.layout.zoneNames[inspector.group.section] : (inspector.group.visibility === "managed" ? "on demand at " : "on the bar at ") + String(editor.layout.zoneNames[inspector.group.section]).toLowerCase())
                        textFormat: Text.PlainText
                        color: Qt.alpha(Commons.Color.popups.text, 0.55)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    // Dissolve, asked twice (PREFS-39).
                    Item {
                        id: dissolveButton
                        readonly property bool confirming: !!inspector.group && editor.pendingDissolve === inspector.group.id
                        readonly property var keyHints: [
                            {
                                keys: "enter",
                                label: confirming ? "Again to dissolve" : "Dissolve, asked twice"
                            }
                        ]
                        Layout.fillWidth: true
                        Layout.topMargin: Style.space(4)
                        Layout.preferredHeight: Style.space(26)
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: dissolveLabel.text
                        Keys.onPressed: function (event) {
                            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space)
                                return;
                            editor.dissolve(inspector.group ? inspector.group.id : "");
                            event.accepted = true;
                        }
                        DashedFrame {
                            anchors.fill: parent
                            radius: editor.chipRadius
                            stroke: dissolveButton.confirming ? Commons.Color.error : Qt.alpha(Commons.Color.popups.text, dissolveMouse.containsMouse ? 0.45 : 0.25)
                        }
                        GrayText {
                            id: dissolveLabel
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(8)
                            anchors.rightMargin: Style.space(8)
                            verticalAlignment: Text.AlignVCenter
                            text: dissolveButton.confirming ? "Again to dissolve" : "Dissolve " + (inspector.group ? inspector.group.label : "")
                            textFormat: Text.PlainText
                            color: dissolveButton.confirming ? Commons.Color.error : Qt.alpha(Commons.Color.popups.text, 0.7)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: dissolveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editor.dissolve(inspector.group ? inspector.group.id : "")
                        }
                    }
                }
                // How it shows.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: Style.space(2)
                    PrefsChoice {
                        stacked: true
                        label: "Show"
                        options: [
                            {
                                value: "glyph",
                                label: "Icon"
                            },
                            {
                                value: "text",
                                label: "Name"
                            },
                            {
                                value: "both",
                                label: "Both"
                            }
                        ]
                        value: inspector.group ? inspector.group.face : ""
                        onChosen: function (value) {
                            editor.edit(editor.selectedId, {
                                face: value
                            });
                        }
                    }
                    PrefsChoice {
                        Layout.topMargin: Style.space(6)
                        stacked: true
                        label: "Widgets show"
                        options: [
                            {
                                value: "native",
                                label: "Icon"
                            },
                            {
                                value: "name",
                                label: "Name"
                            },
                            {
                                value: "both",
                                label: "Both"
                            }
                        ]
                        value: inspector.group ? inspector.group.memberDisplay : ""
                        onChosen: function (value) {
                            editor.edit(editor.selectedId, {
                                memberDisplay: value
                            });
                        }
                    }
                    PrefsToggle {
                        Layout.topMargin: Style.space(4)
                        compact: true
                        label: "Name on hover"
                        readonly property var keyHints: [
                            {
                                keys: "space",
                                label: "Toggle"
                            }
                        ]
                        checked: inspector.group ? (inspector.group.tooltip === undefined ? inspector.group.face === "glyph" : inspector.group.tooltip) : false
                        onToggled: function (checked) {
                            editor.edit(editor.selectedId, {
                                tooltip: checked
                            });
                        }
                    }
                    PrefsToggle {
                        compact: true
                        label: "Badge"
                        readonly property var keyHints: [
                            {
                                keys: "space",
                                label: "Toggle"
                            }
                        ]
                        checked: inspector.group ? inspector.group.badge : false
                        onToggled: function (checked) {
                            editor.edit(editor.selectedId, {
                                badge: checked
                            });
                        }
                    }
                    PrefsChoice {
                        stacked: true
                        enabled: !!inspector.group && inspector.group.badge
                        opacity: enabled ? 1 : 0.45
                        label: "Counts"
                        options: [
                            {
                                value: "sum",
                                label: "Add up"
                            },
                            {
                                value: "members",
                                label: "Busy widgets"
                            }
                        ]
                        value: inspector.group ? inspector.group.badgeMode : ""
                        onChosen: function (value) {
                            editor.edit(editor.selectedId, {
                                badgeMode: value
                            });
                        }
                    }
                }
                // Where it is: its layer and zone; its icon and shortcut.
                ColumnLayout {
                    Layout.preferredWidth: Style.space(240)
                    Layout.maximumWidth: Style.space(240)
                    Layout.alignment: Qt.AlignTop
                    spacing: Style.space(6)
                    LayerPicker {
                        Layout.fillWidth: true
                        value: inspector.group ? inspector.group.visibility : ""
                        animate: editor.bar.animationsEnabled
                        onChosen: function (value) {
                            editor.edit(editor.selectedId, {
                                visibility: value
                            });
                        }
                    }
                    PrefsZoneMap {
                        id: zoneMap
                        compact: true
                        stacked: true
                        Layout.leftMargin: 0
                        zones: editor.layout.zoneChoices
                        cameraOver: editor.layout.previewCamera ? "center" : ""
                        noteFor: function (zone) {
                            return editor.layout.cameraNote(zone);
                        }
                        marker: Component {
                            GroupFace {
                                group: inspector.group
                                faceMode: "glyph"
                                color: Commons.Color.popups.text
                                fontFamily: editor.layout.barFont
                                fontSize: Math.round(editor.layout.iconSize * 0.6)
                            }
                        }
                        value: inspector.group ? inspector.group.section : ""
                        onChosen: function (value) {
                            var group = editor.groupOf(editor.selectedId);
                            if (group)
                                editor.moveToZone(group, value);
                        }
                    }
                    GrayText {
                        Layout.fillWidth: true
                        text: "Shift h l on its face moves it too"
                        textFormat: Text.PlainText
                        color: Qt.alpha(Commons.Color.popups.text, 0.45)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    Button {
                        id: iconButton
                        readonly property var keyHints: [
                            {
                                keys: "enter",
                                label: "Choose an icon"
                            }
                        ]
                        text: "Change icon"
                        iconText: "󰏫"
                        focusable: true
                        bordered: true
                        foreground: Commons.Color.popups.text
                        Keys.onReturnPressed: picker.open(inspector.group, iconButton)
                        Keys.onEnterPressed: picker.open(inspector.group, iconButton)
                        onClicked: picker.open(inspector.group, iconButton)
                    }
                    ShortcutRow {
                        Layout.fillWidth: true
                        padding: 0
                        store: editor.preferences.shortcuts
                        target: inspector.group ? "group:" + inspector.group.id : ""
                        unavailable: inspector.group && inspector.group.visibility === "hidden" ? "Hidden groups can't open" : ""
                    }
                }
            }
            // The member under the cursor: where its badge count comes from.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Commons.Color.popups.text, 0.1)
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.spacing.controlHeight
                spacing: Style.space(10)
                GrayText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 3
                    text: editor.member ? editor.preferences.title(editor.member) + ", in this drawer" : "Put the cursor on a widget in the drawer to set where its badge count comes from"
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, editor.member ? 0.8 : 0.45)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }
                TextField {
                    id: countField
                    visible: !!editor.member
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    Binding on text {
                        value: editor.member ? editor.member.badgeProperty || "" : ""
                        when: !countField.activeFocus
                        restoreMode: Binding.RestoreNone
                    }
                    placeholderText: "Count from: detected"
                    foreground: Commons.Color.popups.text
                    font.pixelSize: Style.font.caption
                    verticalPadding: Style.space(3)
                    Accessible.name: "Badge count property"
                    onEditingFinished: if (editor.member)
                        editor.bar.editMemberBadge(editor.member.instanceKey, "badgeProperty", text.trim())
                }
                TextField {
                    id: urgentField
                    visible: !!editor.member
                    Layout.fillWidth: true
                    Layout.preferredWidth: 2
                    Binding on text {
                        value: editor.member ? editor.member.urgentProperty || "" : ""
                        when: !urgentField.activeFocus
                        restoreMode: Binding.RestoreNone
                    }
                    placeholderText: "Urgent from: detected"
                    foreground: Commons.Color.popups.text
                    font.pixelSize: Style.font.caption
                    verticalPadding: Style.space(3)
                    Accessible.name: "Urgent property"
                    onEditingFinished: if (editor.member)
                        editor.bar.editMemberBadge(editor.member.instanceKey, "urgentProperty", text.trim())
                }
                GrayText {
                    visible: !!editor.member
                    text: "x takes it out"
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.45)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }
        Item {
            id: endFence
            activeFocusOnTab: inspector.shown
            onActiveFocusChanged: if (activeFocus)
                (inspector.lastInside === inspector.lastControl() ? nameField : inspector.lastControl()).forceActiveFocus(Qt.TabFocusReason)
        }
    }
    readonly property Item focused: editor.Window.activeFocusItem
    function within(item, root) {
        for (var p = item; p; p = p.parent)
            if (p === root)
                return true;
        return false;
    }

    IconPicker {
        id: picker
        anchors.fill: parent
        z: 200
        preferences: editor.preferences
        onChosen: function (patch) {
            editor.edit(editor.selectedId, patch);
            picker.close();
        }
        onClosed: iconButton.forceActiveFocus(Qt.OtherFocusReason)
    }
    // The picker belongs to this page while Preferences shows it (PREFS-91).
    Connections {
        target: editor.preferences
        function onOpenedChanged() {
            if (!editor.preferences.opened)
                picker.close();
        }
        function onPageChanged() {
            if (editor.preferences.page !== 1) {
                picker.close();
                if (editor.lifted)
                    editor.cancel();
            }
        }
    }

    // ------------------------------------------------------------ the legend
    readonly property bool stageFocused: stage.activeFocus
    readonly property bool inspectorFocused: within(focused, inspector)
    // The row being worked on: where the lifted widget or face would land,
    // else the cursor's. Its zone's names read brighter on both plates, bold
    // on its own (PREFS-110).
    readonly property var activeAt: lifted && liftTarget ? liftTarget : at
    readonly property string activeZone: activeAt.area === "rail" || activeAt.area === "plus" || activeAt.area === "zone" ? activeAt.zone : activeAt.area === "drawer" || activeAt.area === "face" ? Editor.zoneOfGroup(stepState, activeAt.id) : ""
    readonly property int activePlate: activeAt.area === "drawer" ? 1 : activeAt.area === "pool" ? 2 : 0
    readonly property string cursorGroup: Editor.groupAt(stepState, at)
    readonly property string cursorZone: at.area === "rail" ? at.zone : at.area === "drawer" ? Editor.zoneOfGroup(stepState, at.id) : ""
    readonly property var legend: picker.opened ? picker.hints : focused === sideDot ? sideDot.keyHints.concat([
        {
            keys: "tab",
            label: "The groups"
        }
    ]) : lifted && liftingFace ? [
        {
            keys: "h l",
            label: "Move it to the next zone"
        },
        {
            keys: "space",
            label: liftTarget && liftTarget.zone && liftTarget.zone !== lifted.zone ? "Drop: in " + layout.zoneNames[liftTarget.zone] : "Drop"
        },
        {
            keys: "esc",
            label: "Put it back"
        }
    ] : lifted ? [
        {
            keys: "h l",
            label: layout.previewCamera ? "Along the layer, across the camera" : "Along the layer"
        },
        {
            keys: "j k",
            label: "Down the zone, on to the next layer"
        },
        {
            keys: "space",
            label: liftTarget && liftTarget.area === "plus" ? "Drop: a new group in " + layout.zoneNames[liftTarget.zone] : liftTarget && liftTarget.area === "face" && groupOf(liftTarget.id) ? "Drop: at the end of " + groupOf(liftTarget.id).label : "Drop"
        },
        {
            keys: "esc",
            label: "Put it back"
        }
    ] : stageFocused && (at.area === "rail" || at.area === "drawer" && at.pos < 0) ? [
        {
            keys: "h l",
            label: layout.previewCamera ? "Along the layer, across the camera" : "Along the layer"
        },
        {
            keys: "j k",
            label: "Down the zone, on to the next layer"
        }
    ].concat(cursorGroup && at.area === "rail" ? [
        {
            keys: "space",
            label: "Pick up, then drop"
        }
    ] : []).concat(cursorGroup ? [
        {
            keys: "shift h l",
            label: "Move the face to the next zone"
        },
        {
            keys: "shift j k",
            label: "On the bar, on demand, hidden"
        }
    ] : []).concat([
        {
            keys: "n",
            label: "New group in " + layout.zoneNames[cursorZone]
        }
    ]).concat(cursorGroup ? [
        {
            keys: "x",
            label: pendingDissolve && pendingDissolve === cursorGroup ? "Again to dissolve" : "Dissolve, asked twice"
        },
        {
            keys: "enter",
            label: "Inspect, at its name"
        }
    ] : [
        {
            keys: "enter",
            label: "New group here"
        }
    ]).concat([
        {
            keys: "tab",
            label: "The inspector"
        }
    ]) : stageFocused && at.area === "drawer" ? [
        {
            keys: "h l",
            label: layout.previewCamera ? "Along the layer, across the camera" : "Along the layer"
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
            keys: "shift h j k l",
            label: "Move it at once"
        },
        {
            keys: "x",
            label: "Take it out"
        },
        {
            keys: "enter",
            label: "Its Count from"
        },
        {
            keys: "esc",
            label: "Back to the faces"
        },
        {
            keys: "tab",
            label: "The inspector"
        }
    ] : stageFocused && at.area === "pool" ? [
        {
            keys: filterText ? "← →" : "h l",
            label: "Walk the widgets"
        },
        {
            keys: filterText ? "↑ ↓" : "j k",
            label: "By rows, up to the chosen drawer"
        },
        {
            keys: "space",
            label: "Pick up, then drop"
        },
        {
            keys: "enter",
            label: selectedGroup ? "Add to " + selectedGroup.label : "Add to the chosen group"
        },
        {
            keys: "type",
            label: "Filter"
        },
        {
            keys: "esc",
            label: filterText ? "Clear the filter" : "Back to the faces"
        },
        {
            keys: "tab",
            label: "The inspector"
        }
    ] : inspectorFocused ? [
        {
            keys: "tab shift+tab",
            label: "Next, previous control"
        }
    ].concat(focused && focused.keyHints ? focused.keyHints : within(focused, zoneMap) ? [
        {
            keys: "h l",
            label: "Walk the zones"
        },
        {
            keys: "space",
            label: "Move it to that zone"
        }
    ] : []).concat([
        {
            keys: "esc",
            label: "Back to the faces"
        }
    ]) : [
        {
            keys: "tab",
            label: "The groups"
        }
    ]
    GridLayout {
        id: legendGrid
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(8)
        width: Math.max(Style.space(200), Math.min(Style.space(640), (inspector.shown ? inspector.x : editor.width) - Style.space(32)))
        z: 118
        columns: 2
        columnSpacing: Style.space(14)
        rowSpacing: Style.space(10)
        Repeater {
            model: editor.legend
            Row {
                id: keysRow
                required property var modelData
                required property int index
                Layout.row: index
                Layout.column: 0
                spacing: Style.space(4)
                Repeater {
                    model: String(keysRow.modelData.keys).split(" ")
                    KeyCap {
                        required property string modelData
                        text: modelData
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    }
                }
            }
        }
        Repeater {
            model: editor.legend
            GrayText {
                required property var modelData
                required property int index
                Layout.row: index
                Layout.column: 1
                Layout.fillWidth: true
                text: modelData.label
                textFormat: Text.PlainText
                color: Qt.alpha(Commons.Color.popups.text, 0.7)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
            }
        }
    }
    // ---------------------------------------------------------- components
    // A zone's tile on the faces' plate: the Layout page's bar-layer tile
    // (ZoneTile), its groups' faces a row each in a window at most four rows
    // tall that scrolls (PREFS-106, PREFS-121), its "+" right under it.
    component FaceTile: ZoneTile {
        id: faceTile
        required property string modelData
        readonly property string zone: modelData
        readonly property var ids: editor.faces[modelData] || []
        readonly property bool cursorHere: !editor.lifted && editor.at.area === "rail" && editor.at.zone === modelData
        // A lifted face over another zone's tile.
        readonly property bool targeted: editor.liftingFace && !!editor.liftTarget && editor.liftTarget.zone === modelData && editor.liftTarget.zone !== editor.lifted.zone
        readonly property bool capped: editor.cameraShown && modelData === "center"
        readonly property alias plus: plusSlot
        x: editor.column(modelData).x
        width: editor.column(modelData).width
        animate: editor.bar.animationsEnabled
        lightTheme: editor.lightTheme
        lead: true
        borderSpec: targeted ? Border.flat(Commons.Color.accent, 1) : Border.flat(Qt.alpha(Commons.Color.popups.text, 0.12), 1)
        pad: editor.tilePad
        topRadius: capped ? 0 : radius
        raise: cursorHere ? editor.tileRaise : 0
        camera: editor.beamCamera
        shaded: capped
        spillShown: editor.cameraShown
        beamX: editor.column("center").x - x - editor.slide
        sliding: editor.slide !== 0
        beamWidth: editor.column("center").width
        line: editor.stackTop
        tilt: editor.tilt
        planeDistance: editor.planeDistance
        name: editor.layout.zoneNames[modelData] || ""
        nameActive: editor.activeZone === modelData
        nameBold: editor.activeZone === modelData && editor.activePlate === 0
        nameRow: editor.nameRow
        // The window holds the faces, four rows at most, and the "+" row
        // follows it (PREFS-112, PREFS-121); the rest of the tile stays empty.
        readonly property var view: Editor.faceView(ids.length, editor.chipHeight, editor.chipGap)
        viewTop: pad + editor.nameRow
        viewBottom: Math.max(0, height - viewTop - view.height)
        chipHeight: editor.chipHeight
        spacing: editor.chipGap
        flowWidth: editor.chipWidth
        current: cursorHere
        model: faceRows.model
        Component.onCompleted: faceTiles.add(this)
        Component.onDestruction: faceTiles.drop(this)
        RetainedList {
            id: faceRows
            recordProperty: "retainedRecord"
            records: faceTile.ids.map(function (id, index) {
                return {
                    key: id,
                    id: id,
                    index: index
                };
            })
            factory: Component {
                FaceChip {
                    required property var retainedRecord
                    groupId: retainedRecord.id
                    index: retainedRecord.index
                    zone: faceTile.zone
                }
            }
        }
        PlusSlot {
            id: plusSlot
            zone: faceTile.zone
            x: faceTile.pad
            y: faceTile.viewTop + faceTile.view.height + (faceTile.view.rows ? editor.chipGap : 0)
            width: editor.chipWidth
        }
    }
    // A face, drawn by its layer: on the bar accent-tinted, on demand plain
    // with the demand dots' ring, hidden dashed and faded; its icon, its
    // name (elided) and its count pill at the row's end.
    component FaceLook: Item {
        id: look
        property var group: null
        property bool ghost: false
        property bool isCursor: false
        property bool chosen: false
        property bool targeted: false
        property bool hovered: false
        readonly property string visibility: group ? group.visibility : "shown"
        readonly property int count: group ? (editor.memberLists[group.id] || []).length : 0
        height: editor.chipHeight
        BorderSurface {
            anchors.fill: parent
            antialiasing: true
            radius: editor.chipRadius
            color: look.targeted ? Qt.alpha(Commons.Color.accent, 0.4) : look.ghost ? Qt.tint(editor.pageColor, Qt.alpha(Commons.Color.popups.text, 0.15)) : look.visibility === "shown" ? Qt.alpha(Commons.Color.accent, look.hovered ? 0.3 : 0.22) : look.visibility === "managed" ? Qt.alpha(Commons.Color.popups.text, look.hovered ? 0.12 : 0.06) : look.hovered ? Qt.alpha(Commons.Color.popups.text, 0.06) : "transparent"
            borderSpec: look.ghost ? Border.flat(Commons.Color.accent, Math.max(1, Math.round(Style.space(1.5)))) : look.isCursor && editor.stageFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : look.chosen ? Border.flat(Commons.Color.accent, 1) : look.isCursor ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1) : Border.none()
        }
        DashedFrame {
            visible: look.visibility === "hidden" && !look.chosen && !look.isCursor && !look.ghost
            anchors.fill: parent
            radius: editor.chipRadius
            stroke: Qt.alpha(Commons.Color.popups.text, 0.35)
        }
        Row {
            id: faceRow
            x: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(5)
            opacity: look.visibility === "hidden" ? 0.55 : 1
            Rectangle {
                visible: look.visibility === "managed"
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(5)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(Commons.Color.popups.text, 0.7)
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(16)
                height: Style.space(16)
                GroupFace {
                    anchors.centerIn: parent
                    group: look.group
                    faceMode: "glyph"
                    color: Commons.Color.popups.text
                    fontFamily: editor.layout.barFont
                    fontSize: Style.font.body
                }
            }
            GrayText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, look.width - Style.space(12) - Style.space(16) - (look.visibility === "managed" ? Style.space(10) : 0) - 2 * faceRow.spacing - facePill.width)
                text: look.group ? look.group.label : ""
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
            }
            Rectangle {
                id: facePill
                anchors.verticalCenter: parent.verticalCenter
                width: editor.pillWidth(look.count)
                height: Style.space(16)
                radius: height / 2
                color: Qt.alpha(Commons.Color.popups.text, 0.12)
                GrayText {
                    anchors.centerIn: parent
                    text: look.count
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }
    }
    // A face in its zone's tile, a row as wide as the Layout page's chips;
    // the open one (PREFS-120) has the leader's dot at its bottom middle.
    component FaceChip: FaceLook {
        id: chip
        property string groupId: ""
        property int index: 0
        property string zone: ""
        readonly property bool placeholder: false
        readonly property bool open: editor.openIds[zone] === groupId
        group: editor.groupOf(groupId)
        isCursor: !editor.lifted && editor.cursorKey === "face:" + groupId
        chosen: editor.selectedId === groupId
        targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "face" && editor.liftTarget.id === groupId
        hovered: editor.hoverKey === "face:" + groupId
        opacity: editor.liftingFace && editor.lifted.face === groupId ? 0.35 : 1
        width: editor.chipWidth
        Rectangle {
            visible: chip.open
            x: (chip.width - width) / 2
            y: chip.height - height / 2
            z: 1
            width: Style.space(6)
            height: width
            radius: width / 2
            color: Qt.alpha(Commons.Color.accent, chip.chosen ? 1 : 0.45)
        }
    }
    // A zone's "+", the last row of its tile: a new group there (n or Enter
    // on it, a click, or a widget dropped on it).
    component PlusSlot: Item {
        id: plus
        property string zone: ""
        readonly property bool isCursor: !editor.lifted && editor.cursorKey === "plus:" + zone
        readonly property bool targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "plus" && editor.liftTarget.zone === zone
        readonly property bool hovered: editor.hoverKey === "plus:" + zone
        readonly property bool lit: isCursor || targeted || hovered
        height: editor.chipHeight
        BorderSurface {
            anchors.fill: parent
            antialiasing: true
            radius: editor.chipRadius
            color: plus.targeted ? Qt.alpha(Commons.Color.accent, 0.3) : plus.isCursor && editor.stageFocused ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
            borderSpec: plus.isCursor && editor.stageFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
        }
        DashedFrame {
            visible: !(plus.isCursor && editor.stageFocused)
            anchors.fill: parent
            radius: editor.chipRadius
            stroke: plus.lit ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.3)
        }
        GrayText {
            anchors.centerIn: parent
            text: "+"
            textFormat: Text.PlainText
            color: plus.lit ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }
    // A zone's tile on the drawers' plate: its one drawer, showing its open
    // group (PREFS-113, PREFS-122): a header row with the group's icon, name
    // and count over a hairline, a note for a hidden or on-demand group, then
    // its widgets as the Layout page's chips in a window that scrolls
    // (PREFS-106). Another face opened swaps it at once.
    component DrawerTile: ZoneTile {
        id: drawer
        required property string modelData
        readonly property string zone: modelData
        readonly property string groupId: editor.openIds[modelData] || ""
        readonly property var group: editor.groupOf(groupId)
        readonly property bool chosen: !!groupId && editor.selectedId === groupId
        readonly property var list: groupId ? editor.drawerList(groupId) : []
        readonly property string note: editor.drawerNote(group)
        readonly property bool targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "drawer" && editor.liftTarget.id === groupId
        readonly property bool cursorHere: !editor.lifted && editor.at.area === "drawer" && editor.at.id === groupId
        readonly property bool headerCursor: cursorHere && editor.at.pos < 0
        readonly property alias header: headerRow
        readonly property real headerTop: pad + editor.nameRow
        readonly property real noteHeight: note ? noteText.implicitHeight + Style.space(4) : 0
        // What it holds under its header, for the plate's height (PREFS-115).
        readonly property var size: ({
                note: noteHeight,
                rows: list.length,
                text: !groupId ? noGroup.implicitHeight : emptyText.implicitHeight
            })
        x: editor.column(modelData).x
        width: editor.column(modelData).width
        animate: editor.bar.animationsEnabled
        lightTheme: editor.lightTheme
        lead: chosen
        borderSpec: chosen || targeted && list.length === 1 ? Border.flat(Qt.alpha(Commons.Color.accent, 0.7), 1) : Border.flat(Qt.alpha(Commons.Color.popups.text, 0.12), 1)
        pad: editor.tilePad
        raise: cursorHere ? editor.tileRaise : 0
        camera: editor.beamCamera
        shaded: editor.cameraShown && modelData === "center"
        spillShown: editor.cameraShown
        beamX: editor.column("center").x - x - editor.slide
        sliding: editor.slide !== 0
        beamWidth: editor.column("center").width
        line: editor.stackTop
        tilt: editor.tilt
        planeDistance: editor.planeDistance
        name: editor.layout.zoneNames[modelData] || ""
        nameActive: editor.activeZone === modelData
        nameBold: editor.activeZone === modelData && editor.activePlate === 1
        nameRow: editor.nameRow
        viewTop: headerTop + editor.headerBlock + noteHeight
        chipHeight: editor.chipHeight
        spacing: editor.chipGap
        flowWidth: editor.chipWidth
        current: cursorHere
        model: memberTiles.model
        Component.onCompleted: drawerTiles.add(this)
        Component.onDestruction: drawerTiles.drop(this)
        // A swapped group starts at its top, the cursor's widget in view.
        onGroupIdChanged: {
            scroll = 0;
            Qt.callLater(editor.revealCursor);
        }
        GrayText {
            id: noGroup
            visible: !drawer.groupId
            x: drawer.pad + Style.space(2)
            y: drawer.headerTop
            width: drawer.width - 2 * x
            text: "No group in " + (editor.layout.zoneNames[drawer.zone] || "") + " yet. Press n on its + above."
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }
        Item {
            id: headerRow
            visible: !!drawer.groupId
            x: drawer.pad
            y: drawer.headerTop
            width: editor.chipWidth
            height: editor.chipHeight
            opacity: drawer.group && drawer.group.visibility === "hidden" ? 0.6 : 1
            BorderSurface {
                anchors.fill: parent
                antialiasing: true
                radius: editor.chipRadius
                color: drawer.headerCursor && editor.stageFocused ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent) : editor.hoverKey === "header:" + drawer.groupId ? Qt.alpha(Commons.Color.popups.text, 0.08) : "transparent"
                borderSpec: drawer.headerCursor && editor.stageFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : drawer.headerCursor ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1) : Border.none()
            }
            Row {
                x: Style.space(6)
                width: parent.width - 2 * x
                height: parent.height
                spacing: Style.space(6)
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(16)
                    height: Style.space(16)
                    GroupFace {
                        anchors.centerIn: parent
                        group: drawer.group
                        faceMode: "glyph"
                        color: Commons.Color.popups.text
                        fontFamily: editor.layout.barFont
                        fontSize: Style.font.body
                    }
                }
                GrayText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - Style.space(16) - 2 * parent.spacing - drawerPill.width)
                    text: drawer.group ? drawer.group.label : ""
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.weight: drawer.chosen ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                Rectangle {
                    id: drawerPill
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int n: (editor.memberLists[drawer.groupId] || []).length
                    width: editor.pillWidth(n)
                    height: Style.space(16)
                    radius: height / 2
                    color: Qt.alpha(Commons.Color.popups.text, 0.12)
                    GrayText {
                        anchors.centerIn: parent
                        text: drawerPill.n
                        textFormat: Text.PlainText
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
        Rectangle {
            visible: !!drawer.groupId
            x: drawer.pad
            y: drawer.headerTop + editor.chipHeight + Style.space(2)
            width: editor.chipWidth
            height: 1
            color: Qt.alpha(Commons.Color.popups.text, 0.1)
        }
        GrayText {
            id: noteText
            visible: drawer.note !== ""
            x: drawer.pad + Style.space(2)
            y: drawer.headerTop + editor.headerBlock
            width: drawer.width - 2 * x
            text: drawer.note
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }
        GrayText {
            id: emptyText
            visible: !!drawer.groupId && drawer.list.length === 0
            x: drawer.pad + Style.space(2)
            y: drawer.viewTop
            width: drawer.width - 2 * x
            text: "Empty. Drop widgets here, or press space on one in the pool."
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }
        RetainedList {
            id: memberTiles
            recordProperty: "retainedRecord"
            records: drawer.list.map(function (value, index) {
                return {
                    key: value.placeholder ? "insertion-gap" : value.record.instanceKey,
                    entry: value.record,
                    placeholder: value.placeholder,
                    index: index
                };
            })
            factory: Component {
                Chip {
                    required property var retainedRecord
                    record: retainedRecord.entry
                    placeholder: retainedRecord.placeholder
                    area: "drawer"
                    pos: retainedRecord.index
                    width: editor.chipWidth
                    opacity: drawer.group && drawer.group.visibility === "hidden" ? 0.6 : 1
                }
            }
        }
    }
    // A widget's chip, the Layout page's (PREFS-22, PREFS-104): its icon and
    // name; a landing place is an accent outline, the dragged copy flat in
    // front. Pool chips are at half strength.
    component Chip: Item {
        id: tile
        property var record: ({})
        property bool placeholder: false
        property bool ghost: false
        property string area: ""
        property int pos: 0
        readonly property bool inPage: !ghost
        readonly property bool isCursor: inPage && !placeholder && !editor.lifted && !!record.instanceKey && editor.cursorKey === (area === "pool" ? "pool:" : "member:") + record.instanceKey
        readonly property bool hovered: inPage && !editor.lifted && !!record.instanceKey && editor.hoverKey === (area === "pool" ? "pool:" : "member:") + record.instanceKey
        readonly property bool pressedDown: inPage && !placeholder && !!editor.pressed && !editor.pointerLift && !!editor.pressed.record && editor.pressed.record.instanceKey === record.instanceKey
        readonly property bool raised: isCursor
        scale: pressedDown ? 0.97 : raised ? 1.03 : 1
        Behavior on scale {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
        property real raise: raised ? Style.space(area === "pool" ? 8 : 4) : 0
        Behavior on raise {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
        transform: Translate {
            y: -tile.raise
        }
        z: raised ? 1 : 0
        height: editor.chipHeight
        Item {
            readonly property real drop: tile.ghost ? Style.space(6) : tile.raise + Style.space(3)
            readonly property real ring: tile.ghost ? 0.09 : editor.lightTheme ? 0.045 : 0.08
            visible: tile.ghost || tile.raise > 0
            anchors.fill: parent
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    x: -index
                    y: parent.drop - index
                    width: parent.width + 2 * index
                    height: parent.height + 3 * index
                    radius: editor.chipRadius + index
                    antialiasing: true
                    color: Qt.rgba(0, 0, 0, parent.ring)
                }
            }
        }
        readonly property color fill: tile.placeholder ? "transparent" : tile.ghost ? Qt.tint(editor.pageColor, Qt.alpha(Commons.Color.popups.text, 0.15)) : tile.isCursor && editor.stageFocused ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent) : tile.isCursor ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent) : tile.hovered ? Qt.alpha(Commons.Color.popups.text, 0.14) : Qt.alpha(Commons.Color.popups.text, 0.06)
        BorderSurface {
            anchors.fill: parent
            antialiasing: true
            radius: editor.chipRadius
            color: tile.raised ? Qt.tint(editor.tileColor(tile.area !== "pool"), tile.fill) : tile.fill
            borderSpec: tile.placeholder || tile.ghost ? Border.flat(Commons.Color.accent, Math.max(1, Math.round(Style.space(1.5)))) : tile.isCursor && editor.stageFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : tile.isCursor ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1) : Border.none()
            Behavior on color {
                enabled: editor.bar.animationsEnabled
                ColorAnimation {
                    duration: 90
                }
            }
        }
        Row {
            id: chipRow
            x: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)
            opacity: tile.placeholder ? (editor.pointerLift ? 0 : 0.5) : tile.area === "pool" ? 0.5 : 1
            InkIcon {
                id: chipIcon
                layout: editor.layout
                record: tile.record
                anchors.verticalCenter: parent.verticalCenter
            }
            GrayText {
                text: tile.record && tile.record.instanceKey ? editor.preferences.title(tile.record) : ""
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: Math.max(Style.space(16), tile.width - Style.space(16) - chipIcon.width - chipRow.spacing)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    // A dashed edge: the tray's (PREFS-97), a hidden face's or drawer's, a "+".
    component DashedFrame: Shape {
        id: frame
        property real radius: 0
        property real topRadius: radius
        property color stroke: Qt.alpha(Commons.Color.popups.text, 0.3)
        readonly property real r: Math.max(0, Math.min(radius, width / 2, height / 2))
        readonly property real tr: Math.max(0, Math.min(topRadius, width / 2, height / 2))
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: frame.stroke
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: "transparent"
            startX: frame.tr
            startY: 0.5
            PathLine {
                x: frame.width - frame.tr
                y: 0.5
            }
            PathArc {
                x: frame.width - 0.5
                y: frame.tr
                radiusX: frame.tr
                radiusY: frame.tr
            }
            PathLine {
                x: frame.width - 0.5
                y: frame.height - frame.r
            }
            PathArc {
                x: frame.width - frame.r
                y: frame.height - 0.5
                radiusX: frame.r
                radiusY: frame.r
            }
            PathLine {
                x: frame.r
                y: frame.height - 0.5
            }
            PathArc {
                x: 0.5
                y: frame.height - frame.r
                radiusX: frame.r
                radiusY: frame.r
            }
            PathLine {
                x: 0.5
                y: frame.tr
            }
            PathArc {
                x: frame.tr
                y: 0.5
                radiusX: frame.tr
                radiusY: frame.tr
            }
        }
    }
}
