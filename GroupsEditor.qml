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
import "BoardModel.js" as Board
import "SectionsModel.js" as SectionsModel
import "MotionModel.js" as MotionModel

// The Groups page (docs/behavior/preferences.md PREFS-109 on), two of the
// Layout page's plates under the same camera (LayerPlate, ZoneTile,
// CameraShaft, CenterSideDot): "Groups", each zone's tile a list of its
// groups in bar order, every group's widgets indented right under its face,
// then the zone's "+"; the pool of widgets in no group as one dashed slab
// under it; and the chosen group's inspector at the bottom right with the
// keys beside it.
//
// Keyboard and pointer share one state machine (GroupsEditorModel.js): a
// cursor rests on a face, a widget row, a zone's "+" or a widget in the
// pool; j/k walk one list per zone and on to the pool, h/l the same row in
// the next zone. Space (or a drag) lifts a widget or a face, moving it
// previews where it lands (at a gap of any group, the pool, or a "+" for a
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

    // ---------------------------------------------------------------- data
    readonly property var zones: SectionsModel.lists
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
    readonly property var order: Editor.faceOrder(faces, zones)
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
    // The filter takes the keys (PREFS-42): / opens it while walking the
    // groups and widgets (not from the inspector, which edits one group,
    // nor its icon picker), Esc clears it and goes back to where / was
    // pressed, Enter or Down goes to the matches keeping it.
    property bool filtering: false
    property var filterFrom: null
    function openFilter() {
        if (lifted || picker.opened || Board.within(focused, inspector))
            return;
        if (!filtering)
            filterFrom = {
                at: at,
                item: focused && focused !== stage ? focused : null
            };
        filtering = true;
        stage.forceActiveFocus(Qt.OtherFocusReason);
    }
    function cancelFilter() {
        var from = filterFrom;
        filtering = false;
        filterText = "";
        filterFrom = null;
        if (from && from.item && from.item.visible) {
            from.item.forceActiveFocus(Qt.OtherFocusReason);
            return;
        }
        place(Editor.normalize(stepState, from ? from.at : null));
        stage.forceActiveFocus(Qt.OtherFocusReason);
    }
    function filterKey(event) {
        var key = event.key, t = event.text;
        if (key === Qt.Key_Escape)
            cancelFilter();
        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Down) {
            if (poolShown.length) {
                filtering = false;
                filterFrom = null;
                place({
                    area: "pool",
                    pos: 0
                });
            }
        } else if (key === Qt.Key_Backspace)
            filterText = filterText.slice(0, -1);
        else if (t.length === 1 && (/\S/.test(t) || t === " " && filterText !== ""))
            filterText += t;
        else if (key !== Qt.Key_Up && key !== Qt.Key_Left && key !== Qt.Key_Right)
            return;
        // The first match under the cursor as the filter changes.
        if (filtering && poolShown.length && (key === Qt.Key_Backspace || t.length === 1))
            place({
                area: "pool",
                pos: 0
            });
        event.accepted = true;
    }
    // / from anywhere on the page that does not type it.
    Keys.onPressed: function (event) {
        if (event.text === "/" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            openFilter();
            event.accepted = true;
        }
    }
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
            area: "plus",
            zone: "left"
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
    // Each group's member keys without a lifted widget, and how many.
    readonly property var liveKeys: {
        var out = ({});
        for (var id in memberLists)
            out[id] = memberLists[id].filter(function (r) {
                return r.instanceKey !== editor.liftedKey;
            }).map(function (r) {
                return r.instanceKey;
            });
        return out;
    }
    readonly property var counts: {
        var out = ({});
        for (var id in liveKeys)
            out[id] = liveKeys[id].length;
        return out;
    }
    // Each zone's list as drawn (Editor.drawnRows): faces, widget rows, an
    // empty group's note, and a lifted widget's landing place among them.
    readonly property var lists: {
        var out = ({}), target = lifted && !liftingFace ? liftTarget : null;
        zones.forEach(function (zone) {
            out[zone] = Editor.drawnRows(editor.faces[zone], editor.liveKeys, target);
        });
        return out;
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
            chosen: selectedId
        })
    function keyOf(p) {
        if (!p)
            return "";
        if (p.area === "face")
            return "face:" + p.id;
        if (p.area === "plus")
            return "plus:" + p.zone;
        if (p.area === "member") {
            var m = (liveKeys[p.id] || [])[p.pos];
            return m ? "member:" + m : "face:" + p.id;
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
            return zones.indexOf(rest) >= 0 ? Editor.plusPlace(stepState, rest) : null;
        if (kind === "member") {
            for (var id in liveKeys) {
                var i = liveKeys[id].indexOf(rest);
                if (i >= 0 && Editor.facePlace(stepState, id))
                    return {
                        area: "member",
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
        onTriggered: {
            editor.syncCursor();
            Qt.callLater(editor.refreshChosenFace);
        }
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
        Qt.callLater(refreshChosenFace);
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
        renameOnShow = id;
        selectedId = id;
        inspecting = true;
        cursorKey = "face:" + id;
        syncLater.restart();
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
        pushBack();
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
        if (at.area === "member")
            return entryIndex[(liveKeys[at.id] || [])[at.pos]] || null;
        if (at.area === "pool")
            return poolShown[at.pos] || null;
        return null;
    }
    function lift() {
        var record = cursorRecord;
        if (!record)
            return;
        liftOrigin = at;
        if (at.area === "member") {
            lifted = {
                key: record.instanceKey,
                group: at.id,
                pos: at.pos,
                record: record
            };
            liftTarget = Editor.liftStart(at);
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
    }
    function cancel() {
        if (pointerLift) {
            pressed = null;
            pressSpent = true;
        }
        lifted = null;
        liftTarget = null;
        pointerLift = false;
        if (liftOrigin)
            place(liftOrigin);
    }
    function drop() {
        if (!lifted)
            return;
        var carried = lifted, target = liftTarget;
        var into = target && target.area === "gap" ? (liveKeys[target.id] || []) : [];
        var act = Editor.dropAction(carried, target, into, carried.group && target && target.id === carried.group ? carried.pos : -1);
        lifted = null;
        liftTarget = null;
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
    // A face past the next (dy > 0) or previous group in its zone, in bar
    // order (Shift+j/k, PREFS-117). GroupsModel.moveHeader takes a group on
    // the bar or on demand; a hidden one moves as if shown and is hidden
    // again in the same edit, so it takes the same place.
    function moveFace(group, dy) {
        var past = Editor.neighbourFace(stepState, group.id, dy);
        if (!past)
            return;
        var hidden = group.visibility === "hidden";
        bar.editGroups(function (config) {
            if (Groups.moveHeader(config, group.id, group.section, "", past, dy > 0, hidden ? "shown" : group.visibility) && hidden)
                Groups.edit(config, group.id, {
                    visibility: "hidden"
                });
        });
    }
    // A step of the cursor, or of a lifted widget's landing place; with
    // Shift a face changes zone (h l) or moves past a group (j k), a widget
    // moves at once.
    function step(dx, dy, carry) {
        if (lifted && !liftingFace) {
            liftTarget = Editor.stepLift(stepState, liftTarget, dx, dy, liftHome);
            if (liftTarget.area === "gap")
                liftHome = liftTarget.id;
            revealCursor();
            return;
        }
        if (lifted) {
            if (dx)
                liftTarget = Editor.stepLift(stepState, liftTarget, dx, 0);
            return;
        }
        if (carry && at.area === "face") {
            var group = groupOf(at.id);
            if (!group)
                return;
            if (dx) {
                var zone = Editor.nextZone(zones, group.section, dx);
                if (zone)
                    moveToZone(group, zone);
            } else
                moveFace(group, dy);
            cursorKey = "face:" + group.id;
            syncLater.restart();
            return;
        }
        if (carry && cursorRecord) {
            // A moved widget stays among its zone's groups: a step that
            // would land it on a "+" (a new group) or in the pool is not
            // a move, so it stays put.
            lift();
            step(dx, dy, false);
            if (liftTarget && (liftTarget.area === "plus" || liftTarget.area === "pool"))
                cancel();
            else
                drop();
            return;
        }
        place(Editor.step(stepState, at, dx, dy));
    }
    // The chosen group pulled forward to the inspector (PREFS-116), as the
    // Layout page pulls a chip: from the keyboard the inspector takes focus,
    // in its first strip; Esc, or Enter on the plates, pushes it back.
    property bool inspecting: false
    function inspect(byKey) {
        inspecting = true;
        if (byKey)
            inspector.focusFirst();
    }
    function pushBack() {
        inspecting = false;
        stage.forceActiveFocus(Qt.OtherFocusReason);
    }
    // Coming to the page: on the plates, nothing pulled forward.
    function focusFirst() {
        inspecting = false;
        stage.forceActiveFocus(Qt.TabFocusReason);
    }
    function keyPressed(event) {
        var k = Board.keyCommand(event.key, event.text, event.modifiers);
        if (!k)
            return;
        if (filtering) {
            filterKey(event);
            return;
        }
        if (k.dx || k.dy) {
            step(k.dx, k.dy, k.carry);
            event.accepted = true;
            return;
        }
        var enter = k.act === "enter";
        if (lifted) {
            if (k.act === "space" || enter)
                drop();
            else if (k.act === "escape")
                cancel();
            else
                return;
            event.accepted = true;
            return;
        }
        // A face: the group itself.
        var faceId = at.area === "face" ? Editor.groupAt(stepState, at) : "";
        var zone = Editor.zoneAt(stepState, at);
        if (k.act === "space" && cursorRecord)
            lift();
        else if (k.act === "space" && faceId)
            liftFace(faceId);
        else if (enter && inspecting && (faceId || at.area === "member") || k.act === "escape" && inspecting)
            pushBack();
        else if (enter && faceId)
            inspect(true);
        else if (enter && at.area === "plus" || k.c === "n" && zone)
            createIn(zone, "");
        else if (enter && at.area === "member" && cursorRecord)
            inspect(true);
        else if (enter && at.area === "pool")
            addToChosen(cursorRecord);
        else if ((k.c === "x" || k.act === "delete") && faceId)
            dissolve(faceId);
        else if ((k.c === "x" || k.act === "delete") && at.area === "member" && cursorRecord)
            takeOut(cursorRecord);
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
    // A zone's tile on a plate, in the plate: Center under the camera, as
    // on the Layout page.
    function column(zone) {
        return layout.column(zone);
    }
    // The pool's slab: across the five zones' columns, like the Hidden layer's.
    readonly property var slabBox: layout.column("hidden")
    readonly property real tileRadius: Round.container
    readonly property real chipRadius: Round.control
    readonly property color pageColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    function tileColor(lead) {
        return Qt.tint(pageColor, Qt.alpha(Commons.Color.popups.text, lead ? 0.09 : 0.065));
    }
    function pillWidth(n) {
        return layout.textInk(String(n), Style.font.family, Ink.caption).advance + 2 * Gap.s;
    }
    // A widget row's indent under its face, and the branch tying them.
    readonly property real indent: Gap.l
    // A face's icon box, as a widget row's icon.
    readonly property real faceIcon: Style.space(20)
    readonly property real poolSpacing: layout.chipGap
    readonly property int poolPerRow: Editor.perRow(slabBox.width - 2 * tilePad, chipWidth, poolSpacing)
    readonly property int poolRows: Math.ceil(poolList.length / poolPerRow)
    // The bottom band: the legend's longest list (seven rows, a face's or a
    // widget's with the inspector out) with its margins, or the inspector,
    // whichever is taller (PREFS-115).
    KeyCap {
        id: capProbe
        visible: false
        text: "x"
    }
    readonly property real legendBand: Gap.xl + 7 * capProbe.implicitHeight + 6 * Gap.s
    readonly property real bottomBand: Math.max(legendBand, selectedGroup ? inspector.height + Gap.xl : 0)
    // The plates share the room as the Layout page's layers do (PREFS-106,
    // PREFS-115): the list's plate as tall as its tallest zone (eight rows at
    // most) and the "+", met first, the pool its rows with what is left.
    readonly property var needs: Editor.plateNeeds({
        pad: tilePad,
        nameRow: nameRow,
        chip: chipHeight,
        gap: chipGap,
        zoneRows: zones.map(function (zone) {
            return (editor.lists[zone] || []).length;
        }),
        poolRows: poolRows,
        poolGap: poolSpacing,
        poolLabel: poolFace.labelBottom + Gap.m + filterBox.height + Gap.m,
        // The pool's label column may hang into the bottom band over the
        // legend's spare room (on a tilted plate a length is seen shorter).
        labelRoom: bottomBand - legendBand
    })
    readonly property var plateHeights: Model.shareLayers(needs.demands, needs.floors, Math.max(0, height - stackTop - bottomBand), tilt, planeDistance, layout.layerGap, needs.first)
    readonly property var stack: Model.stackLayers(plateHeights, tilt, planeDistance, layout.layerGap)

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
        var t = tileOf("center");
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

    // Tiles by zone, for the pointer and the windows.
    ItemRegistry {
        id: listTiles
    }
    function tileOf(zone) {
        return listTiles.find(function (t) {
            return t.zone === zone;
        });
    }

    // ------------------------------------------------------- the list's plate
    // The Layout page's bar layer: each zone's tile lists its groups in bar
    // order, every group's widgets under its face, eight rows in view
    // (PREFS-121), its "+" under them.
    Item {
        id: listPlate
        x: editor.plateX
        y: editor.stackTop + (editor.stack.layers[0] ? editor.stack.layers[0].top : 0)
        width: editor.plateWidth
        height: editor.stack.layers[0] ? editor.stack.layers[0].height : 0
        z: 2
        LayerPlate {
            id: listFace
            width: listPlate.width
            height: editor.plateHeights[0] || 0
            columns: editor.columns
            pad: editor.platePad
            axisX: editor.axis - editor.slide - listPlate.x
            tilt: editor.tilt
            planeDistance: editor.planeDistance
            animate: editor.bar.animationsEnabled
            title: "Groups"
            caption: "Each face where the bar puts it, its widgets under it"
            count: editor.groups.length + (editor.groups.length === 1 ? " group, " : " groups, ") + editor.memberTotal + (editor.memberTotal === 1 ? " widget" : " widgets")
            Repeater {
                model: editor.zones
                ListTile {
                    seenTop: listPlate.y
                    height: listFace.height
                }
            }
        }
    }

    // ------------------------------------------------------------ the pool
    // One dashed slab across the zones' columns under the list's plate,
    // tilted like a layer, its name, count and the filter on its label
    // column (PREFS-114).
    Item {
        id: poolPlate
        x: editor.plateX
        y: editor.stackTop + (editor.stack.layers[1] ? editor.stack.layers[1].top : 0)
        width: editor.plateWidth
        height: editor.stack.layers[1] ? editor.stack.layers[1].height : 0
        z: 1
        Behavior on y {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: MotionModel.PLATE_MS
                easing.type: Easing.OutCubic
            }
        }
        LayerPlate {
            id: poolFace
            width: poolPlate.width
            height: editor.plateHeights[1] || 0
            columns: editor.columns
            pad: editor.platePad
            axisX: editor.axis - editor.slide - poolPlate.x
            tilt: editor.tilt
            planeDistance: editor.planeDistance
            animate: editor.bar.animationsEnabled
            title: "Not in a group"
            caption: "In bar order, zone by zone"
            count: editor.poolAll.length + (editor.poolAll.length === 1 ? " widget" : " widgets")
            // The filter (PREFS-42): / opens it from anywhere on the page.
            // Open, it has the focus fill and ring and a caret after its
            // text; closed with text, an accent edge says it still applies.
            BorderSurface {
                id: filterBox
                readonly property bool live: editor.filtering && stage.activeFocus
                x: poolFace.labelX
                // A field m under the label's caption, a control tall
                // (PREFS-133).
                y: poolFace.labelBottom + Gap.m
                width: poolFace.labelWidth
                height: Gap.control
                antialiasing: true
                radius: editor.chipRadius
                color: live ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
                borderSpec: live ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.flat(editor.filterText ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.14), 1)
                InkText {
                    id: filterLabel
                    x: Gap.s
                    width: parent.width - 2 * x - (slashCap.visible ? slashCap.width + Gap.s : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: editor.filterText || "Filter " + editor.poolAll.length + (editor.poolAll.length === 1 ? " widget" : " widgets")
                    role: "caption"
                    tier: editor.filterText ? 1 : Ink.secondary
                    // Typed text keeps its end in view; the placeholder its start.
                    elide: editor.filterText ? Text.ElideLeft : Text.ElideRight
                }
                // The caret: after the text, or before the placeholder.
                Rectangle {
                    visible: filterBox.live
                    x: filterLabel.x + (editor.filterText ? Math.min(filterLabel.contentWidth, filterLabel.width) + 1 : -2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: Ink.caption + Style.space(2)
                    color: Commons.Color.popups.text
                }
                KeyCap {
                    id: slashCap
                    visible: !filterBox.live
                    anchors.right: parent.right
                    anchors.rightMargin: Gap.xs
                    anchors.verticalCenter: parent.verticalCenter
                    text: "/"
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
                InkText {
                    x: poolCell.pad + Gap.s
                    y: poolCell.pad + Gap.s
                    width: parent.width - 2 * x
                    visible: editor.poolList.length === 0
                    text: editor.filterText ? "No widget matches “" + editor.filterText + "”. " + (editor.filtering ? "Esc clears the filter." : "/ changes the filter.") : "Every widget is in a group. x on one under its group, or a drag here, takes it out."
                    role: "caption"
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
        // Leaving the plates ends the filter's hold on the keys, keeping
        // its text, and puts a keyboard lift back.
        onActiveFocusChanged: if (!activeFocus) {
            editor.filtering = false;
            editor.filterFrom = null;
            // The page may be gone by then.
            Qt.callLater(function () {
                if (stage && !stage.activeFocus && editor.lifted && !editor.pointerLift)
                    editor.cancel();
            });
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: editor.pointerLift ? Qt.ClosedHandCursor : editor.hoverKey === "filter:" ? Qt.IBeamCursor : editor.hoverKey.indexOf("member:") === 0 || editor.hoverKey.indexOf("pool:") === 0 || editor.hoverKey.indexOf("face:") === 0 ? Qt.OpenHandCursor : editor.hoverKey.indexOf("plus:") === 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPositionChanged: function (mouse) {
                var point = Qt.point(mouse.x, mouse.y);
                if (!editor.pointerLift) {
                    var hit = editor.overFilter(point) ? null : editor.hitAt(point);
                    editor.hoverKey = hit ? hit.key : editor.overFilter(point) ? "filter:" : "";
                    nameTip.hover(pressed || !hit ? "" : hit.key, hit);
                }
                if (pressed && editor.pressed && !editor.pointerLift && Board.pastThreshold(editor.pressPoint, point, Style.space(6))) {
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
                nameTip.hover(null);
            }
            onWheel: function (wheel) {
                var point = Qt.point(wheel.x, wheel.y);
                var win = editor.windowAt(point);
                if (!win || !win.scrollByWheel(wheel)) {
                    wheel.accepted = false;
                    return;
                }
                editor.pointerMoved(point);
            }
            onPressed: function (mouse) {
                nameTip.hover(null);
                if (editor.lifted)
                    editor.cancel();
                editor.pressSpent = false;
                var point = Qt.point(mouse.x, mouse.y);
                // A click on the filter opens it, as / does; anywhere else
                // ends its hold on the keys, keeping its text.
                if (editor.overFilter(point)) {
                    editor.pressed = null;
                    editor.pressSpent = true;
                    editor.openFilter();
                    return;
                }
                if (editor.filtering) {
                    editor.filtering = false;
                    editor.filterFrom = null;
                }
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
                    else if (hit && (hit.kind === "face" || hit.kind === "member"))
                        editor.inspect(false);
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
    // "+", a face, a widget row, an empty group's note or else a zone's tile
    // on the list's plate; a pool chip or the pool.
    function inside(item, point) {
        return !!item && item.visible && Board.covers(item, editor, point);
    }
    function inView(win, point) {
        return win.viewContains(win.mapFromItem(editor, point.x, point.y));
    }
    // Whether a point on the stage is on the pool's filter, through the tilt.
    function overFilter(point) {
        var q = filterBox.mapFromItem(stage, point.x, point.y);
        return filterBox.visible && q.x >= 0 && q.y >= 0 && q.x <= filterBox.width && q.y <= filterBox.height;
    }
    function hitAt(point) {
        for (var z = 0; z < zones.length; z++) {
            var t = tileOf(zones[z]);
            if (!inside(t, point))
                continue;
            if (inside(t.plus, point))
                return {
                    kind: "plus",
                    zone: t.zone,
                    tile: t,
                    key: "plus:" + t.zone,
                    place: Editor.plusPlace(stepState, t.zone)
                };
            var row = t.chipAt(editor, point);
            if (row && row.kind === "face")
                return {
                    kind: "face",
                    id: row.groupId,
                    zone: t.zone,
                    tile: t,
                    key: "face:" + row.groupId,
                    place: {
                        area: "face",
                        id: row.groupId
                    }
                };
            if (row && row.kind === "member")
                return {
                    kind: "member",
                    id: row.groupId,
                    zone: t.zone,
                    tile: t,
                    record: row.record,
                    key: "member:" + row.record.instanceKey,
                    place: {
                        area: "member",
                        id: row.groupId,
                        pos: row.pos
                    }
                };
            return {
                kind: "zone",
                zone: t.zone,
                tile: t,
                key: ""
            };
        }
        if (inside(poolCell, point)) {
            var chip = poolCell.chipAt(editor, point);
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
    // The scrolling window under the pointer: a zone's list or the pool.
    function windowAt(point) {
        for (var z = 0; z < zones.length; z++) {
            var t = tileOf(zones[z]);
            if (inside(t, point))
                return t;
        }
        return inside(poolCell, point) ? poolCell : null;
    }
    function pointerMoved(point) {
        pointer = point;
        if (!pointerLift)
            return;
        var hit = hitAt(point), next = null;
        if (liftingFace)
            next = hit && hit.tile ? {
                area: "zone",
                zone: hit.zone
            } : null;
        else if (hit && hit.kind === "plus")
            next = {
                area: "plus",
                zone: hit.zone
            };
        else if (hit && hit.tile) {
            var gap = inView(hit.tile, point) ? Editor.listGap(hit.tile.mapRows(editor, point)) : null;
            next = gap ? {
                area: "gap",
                id: gap.id,
                pos: gap.pos
            } : null;
        } else if (hit && (hit.kind === "pool" || hit.kind === "poolchip"))
            next = {
                area: "pool"
            };
        if (JSON.stringify(next) !== JSON.stringify(liftTarget))
            liftTarget = next;
        // Held near a scrolling window's top or bottom edge, the drag scrolls it.
        edgeScroll.aim(windowAt(point), editor, point);
    }
    EdgeScroll {
        id: edgeScroll
        active: editor.pointerLift
        onStepped: editor.pointerMoved(editor.pointer)
    }
    // A place's row in its zone's list as drawn, -1 for none.
    function rowOf(zone, p) {
        return (lists[zone] || []).findIndex(function (r) {
            return p.area === "face" ? r.kind === "face" && r.id === p.id : p.area === "member" ? r.kind === "member" && r.id === p.id && r.pos === p.pos : p.area === "gap" ? r.kind === "gap" : false;
        });
    }
    // The cursor's row, or a lifted one's landing place, scrolls into view
    // (a "+" is always in view).
    function revealCursor() {
        var p = lifted && liftTarget ? liftTarget : at;
        if (p.area === "face" || p.area === "member" || p.area === "gap") {
            var zone = Editor.zoneAt(stepState, p), t = tileOf(zone), i = rowOf(zone, p);
            if (t && i >= 0)
                t.reveal(i);
        } else if (p.area === "pool")
            poolCell.reveal(lifted ? Math.max(0, poolList.findIndex(function (v) {
                return v.placeholder;
            })) : p.pos);
    }

    // ------------------------------------------------------- the dragged copy
    // The lifted chip or face, flat over the plates: under the pointer while
    // it drags, over the landing place during a keyboard lift (PREFS-119).
    // A widget over a "+" rides a row higher, so the "+"'s highlight stays in
    // sight; a face sits on the row it lands on.
    property point keyLanding: Qt.point(0, 0)
    property bool keyLandingShown: false
    // The centre of the landing place in the editor: the placeholder in a
    // group's rows or the pool, the "+" (a new group), or for a face its own
    // row while over its own zone, else the "+" of the zone it goes to (it
    // lands at the end, where the "+" is).
    function landingItem() {
        var t = liftTarget;
        if (!lifted || !t)
            return null;
        var home = liftingFace && t.zone === lifted.zone;
        if (liftingFace && !home || t.area === "plus") {
            var tile = tileOf(t.zone);
            return tile ? tile.plus : null;
        }
        var win = home ? tileOf(t.zone) : t.area === "gap" ? tileOf(Editor.zoneAt(stepState, t)) : t.area === "pool" ? poolCell : null;
        if (!win || !win.tiles)
            return null;
        for (var i = 0; i < win.tiles.count; i++) {
            var item = win.tiles.itemAt(i);
            if (item && (home ? item.kind === "face" && item.groupId === lifted.face : item.placeholder))
                return item.landing || item;
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
    onLiftedChanged: {
        Qt.callLater(updateKeyLanding);
        Qt.callLater(refreshChosenFace);
    }
    onPointerLiftChanged: {
        if (!pointerLift)
            edgeScroll.aim(null);
        Qt.callLater(updateKeyLanding);
    }
    // Again once the rows have moved aside for the landing place.
    Timer {
        id: keyLandingSettle
        interval: MotionModel.LANDING_SETTLE_MS
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
    // "New group in Left" (PREFS-100): under the pointer, in front of
    // everything (the inspector too).
    BoardNameTip {
        id: nameTip
        layout: editor.layout
        z: 130
        suppressed: !!editor.lifted
        describe: function (hit) {
            var g = hit.kind === "face" ? editor.groupOf(hit.id) : null;
            var n = g ? (editor.memberLists[g.id] || []).length : 0;
            var gap = Style.space(10), p = editor.pointer;
            return {
                record: hit.record || ({}),
                title: hit.kind === "plus" ? "New group in " + editor.layout.zoneNames[hit.zone] : g ? g.label : hit.record ? editor.preferences.title(hit.record) : "",
                detail: hit.kind === "plus" ? "" : g ? "Group, " + n + (n === 1 ? " widget" : " widgets") : hit.record ? hit.record.id : "",
                below: Qt.point(p.x, p.y + gap + Style.space(16)),
                above: Qt.point(p.x, p.y - gap)
            };
        }
    }

    // -------------------------------------------------------- the inspector
    // The member the cursor is on, for its badge sources.
    readonly property var member: !lifted && at.area === "member" && at.id === selectedId ? cursorRecord : null
    // A new group's name is typed at once, as soon as its face is in.
    property string renameOnShow: ""
    component FieldLabel: InkText {
        Layout.fillWidth: true
        elide: Text.ElideRight
    }
    BoardInspector {
        id: inspector
        readonly property var group: editor.selectedGroup
        layout: editor.layout
        shown: editor.inspecting && !!editor.selectedGroup
        desk: inspectorDesk
        // xl all round (PREFS-133).
        bodyHeight: inspectorDesk.implicitHeight
        // Esc returns to the chosen face; a control that takes it gets it first.
        onEscaped: editor.pushBack()
        onGroupChanged: if (group && group.id === editor.renameOnShow) {
            editor.renameOnShow = "";
            Qt.callLater(faceEditor.edit);
        }
        // Three strips (PREFS-116): the face and how it shows, where it is,
        // its badge and keys, Dissolve last at the bottom right.
        InspectorDesk {
            id: inspectorDesk
            layout: editor.layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Gap.xl
            // A new group's name, else Show: what is set most.
            start: inspector.group && inspector.group.label === "New group" ? faceEditor : showChoice
            escLabel: "Back to the faces"
            DeskStrip {
                readonly property int n: inspector.group ? (editor.memberLists[inspector.group.id] || []).length : 0
                title: inspector.group ? inspector.group.label : ""
                caption: !inspector.group ? "" : n + (n === 1 ? " widget, " : " widgets, ") + (inspector.group.visibility === "hidden" ? "hidden, zone " + editor.layout.zoneNames[inspector.group.section] : (inspector.group.visibility === "managed" ? "on demand at " : "on the bar at ") + String(editor.layout.zoneNames[inspector.group.section]).toLowerCase())
                FaceEditor {
                    id: faceEditor
                    layout: editor.layout
                    group: inspector.group
                    onPickIcon: picker.open(inspector.group, faceEditor)
                    onRenamed: function (group, text) {
                        editor.edit(group.id, {
                            label: text
                        });
                    }
                }
                FieldLabel {
                    text: "Show"
                }
                DeskChoice {
                    id: showChoice
                    Layout.topMargin: Gap.xxs - Gap.m
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
                FieldLabel {
                    text: "Widgets show"
                }
                DeskChoice {
                    Layout.topMargin: Gap.xxs - Gap.m
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
                DeskRow {
                    label: "Name on hover"
                    checked: inspector.group ? (inspector.group.tooltip === undefined ? inspector.group.face === "glyph" : inspector.group.tooltip) : false
                    onActivated: editor.edit(editor.selectedId, {
                        tooltip: !checked
                    })
                }
            }
            DeskStrip {
                title: "Where"
                caption: "Its layer and zone"
                LayerPicker {
                    value: inspector.group ? inspector.group.visibility : ""
                    animate: editor.bar.animationsEnabled
                    onChosen: function (value) {
                        editor.edit(editor.selectedId, {
                            visibility: value
                        });
                    }
                }
                PrefsZoneMap {
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
            }
            DeskStrip {
                title: "Badge and keys"
                caption: "What it counts, what opens it"
                DeskRow {
                    label: "Badge"
                    checked: inspector.group ? inspector.group.badge : false
                    onActivated: editor.edit(editor.selectedId, {
                        badge: !checked
                    })
                }
                FieldLabel {
                    text: "Counts"
                    opacity: countsChoice.enabled ? 1 : Ink.disabled
                }
                DeskChoice {
                    id: countsChoice
                    Layout.topMargin: Gap.xxs - Gap.m
                    enabled: !!inspector.group && inspector.group.badge
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
                DeskTextRow {
                    enabled: !!editor.member
                    label: "Count from"
                    placeholder: "detected"
                    subject: editor.member
                    value: editor.member ? editor.member.badgeProperty || "" : ""
                    onCommitted: function (member, text) {
                        editor.bar.editMemberBadge(member.instanceKey, "badgeProperty", text);
                    }
                }
                DeskTextRow {
                    enabled: !!editor.member
                    label: "Urgent from"
                    placeholder: "detected"
                    subject: editor.member
                    value: editor.member ? editor.member.urgentProperty || "" : ""
                    onCommitted: function (member, text) {
                        editor.bar.editMemberBadge(member.instanceKey, "urgentProperty", text);
                    }
                }
                DeskShortcutRow {
                    stacked: true
                    store: editor.preferences.shortcuts
                    target: inspector.group ? "group:" + inspector.group.id : ""
                    unavailable: inspector.group && inspector.group.visibility === "hidden" ? "Hidden groups can't open" : ""
                }
            }
            // Dissolve, asked twice (PREFS-39): the card's last word, under
            // the strips.
            actions: DeskRow {
                readonly property bool confirming: !!inspector.group && editor.pendingDissolve === inspector.group.id
                action: true
                danger: confirming
                trailing: true
                label: confirming ? "Again to dissolve" : "Dissolve " + (inspector.group ? inspector.group.label : "")
                spaceHint: confirming ? "Again to dissolve" : "Dissolve, asked twice"
                onActivated: editor.dissolve(inspector.group ? inspector.group.id : "")
            }
        }
    }
    // ------------------------------------------------------ the pulled face
    // The chosen face pulled out of its zone's list to the front, as the
    // Layout page pulls a chip (PREFS-101, PREFS-116): its place in the list
    // an empty accent outline, a dashed accent leader from a dot there to a
    // flat copy tilted over the inspector.
    property Item chosenFaceItem: null
    function faceItemOf(id) {
        var tiles = listTiles.items;
        for (var t = 0; t < tiles.length; t++) {
            var win = tiles[t].tiles;
            if (!win)
                continue;
            for (var i = 0; i < win.count; i++) {
                var item = win.itemAt(i);
                if (item && item.kind === "face" && item.groupId === id)
                    return item;
            }
        }
        return null;
    }
    function refreshChosenFace() {
        var item = selectedId && !lifted ? faceItemOf(selectedId) : null;
        if (item !== chosenFaceItem)
            chosenFaceItem = item;
        trackLeader();
    }
    property point leaderStart: Qt.point(0, 0)
    // The leader starts at the face's middle; a face scrolled out of its
    // zone's window is pointed at from the window's edge it went past.
    function trackLeader() {
        var item = chosenFaceItem;
        if (!item)
            return;
        var tile = listTiles.find(function (t) {
            return Board.within(item, t);
        });
        if (!tile) {
            leaderStart = item.mapToItem(editor, item.width / 2, item.height / 2);
            return;
        }
        var p = item.mapToItem(tile, item.width / 2, item.height / 2);
        var y = Math.max(tile.viewTop, Math.min(tile.viewTop + tile.windowHeight, p.y));
        leaderStart = tile.mapToItem(editor, p.x, y);
    }
    onChosenFaceItemChanged: trackLeader()
    GeometryObserver {
        target: editor.chosenFaceItem
        host: editor
        onChanged: editor.trackLeader()
    }
    readonly property bool leaderShown: inspector.shown && !!chosenFaceItem && !lifted && !picker.opened
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
                x: pulledFace.x + pulledFace.width / 2
                y: pulledFace.y
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
    FaceLook {
        id: pulledFace
        visible: editor.leaderShown
        group: editor.selectedGroup
        pulled: true
        width: editor.chipWidth
        z: 125
        x: Math.max(inspector.x + Style.space(24), Math.min(inspector.x + inspector.width - width - Style.space(24), editor.leaderStart.x - width / 2))
        y: inspector.y - Style.space(30)
        rotation: -1.5
        Behavior on x {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: MotionModel.GLIDE_MS
                easing.type: Easing.OutCubic
            }
        }
    }

    readonly property Item focused: editor.Window.activeFocusItem

    IconPicker {
        id: picker
        anchors.fill: parent
        z: 200
        preferences: editor.preferences
        onChosen: function (patch) {
            editor.edit(editor.selectedId, patch);
            picker.close();
        }
        onClosed: faceEditor.deskFocus(0, Qt.OtherFocusReason)
    }
    // The picker belongs to this page while Preferences shows it (PREFS-91).
    Connections {
        target: editor.preferences
        function onOpenedChanged() {
            if (!editor.preferences.opened) {
                picker.close();
                editor.filtering = false;
                editor.filterText = "";
            }
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
    readonly property bool inspectorFocused: Board.within(focused, inspector)
    // The row being worked on: where the lifted widget or face would land,
    // else the cursor's. Its zone's name reads brighter, bold while it is on
    // the list's plate (PREFS-110).
    readonly property var activeAt: lifted && liftTarget ? liftTarget : at
    readonly property string activeZone: Editor.zoneAt(stepState, activeAt)
    readonly property int activePlate: activeAt.area === "pool" ? 1 : 0
    readonly property string cursorGroup: Editor.groupAt(stepState, at)
    readonly property string cursorZone: Editor.zoneAt(stepState, at)
    readonly property var filterLine: ({
            keys: "/",
            label: "Filter the widgets not in a group"
        })
    // Tab goes to the inspector only while it is out (a click pulled it).
    readonly property var inspectorTab: inspector.shown ? [
        {
            keys: "tab shift+tab",
            label: "The inspector"
        }
    ] : []
    // Enter to the inspector heads the legend where it applies.
    readonly property var inspectLines: at.area === "face" || at.area === "member" ? [
        {
            keys: inspecting ? "enter esc" : "enter",
            label: inspecting ? "Push it back" : "Inspect it"
        }
    ] : []
    readonly property var legend: picker.opened ? picker.hints : filtering && stageFocused ? [
        {
            keys: "type",
            label: "Filter by name"
        },
        {
            keys: "backspace",
            label: "Take a letter off"
        },
        {
            keys: "enter ↓",
            label: poolShown.length ? "To the matches" : "No match yet"
        },
        {
            keys: "esc",
            label: "Clear it and go back"
        }
    ] : focused === sideDot ? sideDot.keyHints.concat([
        {
            keys: "tab shift+tab",
            label: "The groups"
        }
    ]) : lifted && liftingFace ? [
        {
            keys: "←→",
            label: "Move it"
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
            keys: "←↑→↓",
            label: "Move it"
        },
        {
            keys: "space",
            label: liftTarget && liftTarget.area === "plus" ? "Drop: a new group in " + layout.zoneNames[liftTarget.zone] : "Drop"
        },
        {
            keys: "esc",
            label: "Put it back"
        }
    ] : stageFocused && at.area !== "pool" ? inspectLines.concat(at.area === "face" || at.area === "member" ? [
        {
            keys: "space",
            label: "Pick up, then drop"
        },
        {
            keys: "shift+←↑→↓",
            label: "Move it"
        }
    ] : []).concat([
        {
            keys: "n",
            label: "New group in " + layout.zoneNames[cursorZone]
        }
    ]).concat(at.area === "face" ? [
        {
            keys: "x",
            label: pendingDissolve && pendingDissolve === cursorGroup ? "Again to dissolve" : "Dissolve, asked twice"
        }
    ] : at.area === "member" ? [
        {
            keys: "x",
            label: "Take it out"
        }
    ] : [
        {
            keys: "enter",
            label: "New group here"
        }
    ]).concat([filterLine]).concat(inspectorTab) : stageFocused && at.area === "pool" ? [
        {
            keys: "space",
            label: "Pick up, then drop"
        },
        {
            keys: "enter",
            label: selectedGroup ? "Add to " + selectedGroup.label : "Add to the chosen group"
        },
        filterLine
    ].concat(inspectorTab) : inspectorFocused ? inspectorDesk.legend : [
        {
            keys: "tab shift+tab",
            label: "The groups"
        },
        filterLine
    ]
    KeyLegend {
        id: legendGrid
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: Math.max(Style.space(200), Math.min(Style.space(640), (inspector.shown ? inspector.x : editor.width) - Gap.xl))
        z: 118
        lines: editor.legend
    }
    // ---------------------------------------------------------- components
    // A zone's tile on the list's plate: the Layout page's bar-layer tile
    // (ZoneTile), its groups' faces in bar order with each group's widgets
    // under its face (PREFS-111), in a window at most eight rows tall that
    // scrolls (PREFS-106, PREFS-121), its "+" right under it.
    component ListTile: ZoneTile {
        id: listTile
        required property string modelData
        readonly property string zone: modelData
        readonly property var rows: editor.lists[modelData] || []
        readonly property bool cursorHere: !editor.lifted && editor.at.area !== "pool" && editor.cursorZone === modelData
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
        // The window holds the rows, eight at most, less when the plate has
        // less room under its "+" (PREFS-115), and the "+" row follows it
        // (PREFS-112, PREFS-121); the rest of the tile stays empty.
        readonly property var view: Editor.listView(rows.length, editor.chipHeight, editor.chipGap)
        readonly property real plusGap: view.rows ? editor.chipGap : 0
        readonly property real windowHeight: Math.max(0, Math.min(view.height, height - viewTop - plusGap - editor.chipHeight - pad))
        viewTop: pad + editor.nameRow
        viewBottom: Math.max(0, height - viewTop - windowHeight)
        chipHeight: editor.chipHeight
        spacing: editor.chipGap
        flowWidth: editor.chipWidth
        current: cursorHere
        model: listRows.model
        Component.onCompleted: listTiles.add(this)
        Component.onDestruction: listTiles.remove(this)
        RetainedList {
            id: listRows
            recordProperty: "retainedRecord"
            records: listTile.rows.map(function (r) {
                return {
                    key: r.kind === "face" ? "face:" + r.id : r.kind === "member" ? "member:" + r.key : r.kind === "gap" ? "insertion-gap" : "note:" + r.id,
                    row: r,
                    entry: r.kind === "member" ? editor.entryIndex[r.key] || null : r.kind === "gap" && editor.lifted ? editor.lifted.record : null
                };
            })
            factory: Component {
                ListRow {
                    required property var retainedRecord
                    row: retainedRecord.row
                    record: retainedRecord.entry
                }
            }
        }
        PlusSlot {
            id: plusSlot
            zone: listTile.zone
            x: listTile.pad
            y: listTile.viewTop + listTile.windowHeight + listTile.plusGap
            width: editor.chipWidth
        }
    }
    // A row of a zone's list (Editor.drawnRows): a face; a widget, the
    // Layout page's chip indented under its face, a branch hairline tying it
    // there; a lifted widget's landing place, drawn the same; or an empty
    // group's note. A hidden group's widgets are at 60 %, like its face.
    component ListRow: Item {
        id: listRow
        property var row: ({})
        property var record: null
        readonly property string kind: row.kind || ""
        readonly property string groupId: row.id || ""
        readonly property int pos: row.pos || 0
        readonly property bool placeholder: kind === "gap"
        readonly property bool widget: kind === "member" || kind === "gap"
        readonly property var group: editor.groupOf(groupId)
        readonly property real fade: group && group.visibility === "hidden" ? Ink.secondary : 1
        // Where a keyboard lift's copy sits over a landing place.
        readonly property var landing: widgetLoader.item
        width: editor.chipWidth
        height: editor.chipHeight
        z: widgetLoader.item && (widgetLoader.item.raised || widgetLoader.item.raise > 0) ? 1 : 0
        Loader {
            active: listRow.kind === "face"
            anchors.fill: parent
            sourceComponent: Component {
                FaceChip {
                    groupId: listRow.groupId
                }
            }
        }
        // The branch: from under the face's icon down to this row's middle,
        // and on past it to the next widget row, with a tick to the row.
        Rectangle {
            visible: listRow.widget
            x: Gap.s
            y: listRow.row.first ? -(editor.chipGap + (editor.chipHeight - editor.faceIcon) / 2) : -editor.chipGap
            width: 1
            height: (listRow.row.last ? Math.round(listRow.height / 2) : listRow.height) - y
            color: Qt.alpha(Commons.Color.popups.text, 0.25)
            opacity: listRow.fade
        }
        Rectangle {
            visible: listRow.widget
            x: Gap.s
            y: Math.round(listRow.height / 2)
            width: editor.indent - Gap.s - Gap.xxs
            height: 1
            color: Qt.alpha(Commons.Color.popups.text, 0.25)
            opacity: listRow.fade
        }
        Loader {
            id: widgetLoader
            active: listRow.widget
            x: editor.indent
            width: listRow.width - editor.indent
            height: listRow.height
            sourceComponent: Component {
                Chip {
                    record: listRow.record || ({})
                    placeholder: listRow.placeholder
                    area: "member"
                    pos: listRow.pos
                    opacity: listRow.fade
                }
            }
        }
        InkText {
            visible: listRow.kind === "note"
            x: editor.indent + Gap.s
            width: listRow.width - x
            anchors.verticalCenter: parent.verticalCenter
            text: "Empty: space on a pool widget adds here"
            role: "caption"
            elide: Text.ElideRight
            opacity: listRow.fade
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
        property bool hovered: false
        // The inspector's pulled-out copy, and the place it left (PREFS-116).
        property bool pulled: false
        property bool pulledOut: false
        readonly property string visibility: group ? group.visibility : "shown"
        readonly property int count: group ? (editor.memberLists[group.id] || []).length : 0
        height: editor.chipHeight
        // The pulled copy's shadow band, as a pulled chip's (BoardChip).
        Rectangle {
            visible: look.pulled
            x: 0.5
            y: parent.height
            width: parent.width - 1
            height: Style.space(6)
            radius: Round.control
            topLeftRadius: 0
            topRightRadius: 0
            antialiasing: true
            color: Ink.band(editor.layout.lightTheme)
        }
        BorderSurface {
            anchors.fill: parent
            antialiasing: true
            radius: editor.chipRadius
            color: look.pulledOut ? "transparent" : look.ghost || look.pulled ? Qt.tint(editor.pageColor, Qt.alpha(Commons.Color.popups.text, 0.15)) : look.visibility === "shown" ? Qt.alpha(Commons.Color.accent, look.hovered ? 0.3 : 0.22) : look.visibility === "managed" ? Qt.alpha(Commons.Color.popups.text, look.hovered ? 0.12 : 0.06) : look.hovered ? Qt.alpha(Commons.Color.popups.text, 0.06) : "transparent"
            borderSpec: look.ghost || look.pulled || look.pulledOut ? Border.flat(Commons.Color.accent, Math.max(1, Math.round(Style.space(1.5)))) : look.isCursor && editor.stageFocused ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : look.chosen ? Border.flat(Commons.Color.accent, 1) : look.isCursor ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1) : Border.none()
        }
        DashedFrame {
            visible: look.visibility === "hidden" && !look.chosen && !look.isCursor && !look.ghost && !look.pulled && !look.pulledOut
            anchors.fill: parent
            radius: editor.chipRadius
            stroke: Qt.alpha(Commons.Color.popups.text, 0.35)
        }
        // A row as the Layout page's (PREFS-133): s in, its icon m from its
        // name at the label size.
        Row {
            id: faceRow
            visible: !look.pulledOut
            x: Gap.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: Gap.m
            opacity: look.visibility === "hidden" ? Ink.secondary : 1
            Rectangle {
                id: demandDot
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
                width: editor.faceIcon
                height: editor.faceIcon
                GroupFace {
                    anchors.centerIn: parent
                    group: look.group
                    faceMode: "glyph"
                    color: Commons.Color.popups.text
                    fontFamily: editor.layout.barFont
                    fontSize: Style.font.body
                }
            }
            InkText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, look.width - 2 * Gap.s - editor.faceIcon - (demandDot.visible ? demandDot.width + faceRow.spacing : 0) - 2 * faceRow.spacing - facePill.width)
                text: look.group ? look.group.label : ""
                elide: Text.ElideRight
            }
            Rectangle {
                id: facePill
                anchors.verticalCenter: parent.verticalCenter
                width: editor.pillWidth(look.count)
                height: Ink.line(Ink.caption)
                radius: height / 2
                color: Qt.alpha(Commons.Color.popups.text, 0.12)
                InkText {
                    anchors.centerIn: parent
                    text: look.count
                    role: "caption"
                    tier: 1
                }
            }
        }
    }
    // A face in its zone's list, a row as wide as the Layout page's chips.
    component FaceChip: FaceLook {
        property string groupId: ""
        group: editor.groupOf(groupId)
        isCursor: !editor.lifted && editor.cursorKey === "face:" + groupId
        chosen: editor.selectedId === groupId
        pulledOut: editor.leaderShown && editor.selectedId === groupId
        hovered: editor.hoverKey === "face:" + groupId
        opacity: editor.liftingFace && editor.lifted.face === groupId ? 0.35 : 1
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
        InkText {
            anchors.centerIn: parent
            text: "+"
            color: plus.lit ? Commons.Color.accent : Ink.tint(Ink.secondary)
        }
    }
    // A widget's chip in a group's rows, the pool or the dragged copy
    // (BoardChip), with this page's kind-prefixed cursor keys. Pool chips are
    // at half strength.
    component Chip: BoardChip {
        property string area: ""
        property int pos: 0
        readonly property string boardKey: record && record.instanceKey ? (area === "pool" ? "pool:" : "member:") + record.instanceKey : ""
        layout: editor.layout
        height: editor.chipHeight
        isCursor: !ghost && !placeholder && !editor.lifted && boardKey !== "" && editor.cursorKey === boardKey
        hovered: !ghost && !editor.lifted && boardKey !== "" && editor.hoverKey === boardKey
        pressedDown: !ghost && !placeholder && !!editor.pressed && !editor.pointerLift && !!editor.pressed.record && editor.pressed.record.instanceKey === record.instanceKey
        boardFocused: editor.stageFocused
        pointerCarry: editor.pointerLift
        dimmed: area === "pool"
        leadTile: area !== "pool"
        riseHeight: Style.space(area === "pool" ? 8 : 4)
    }
}
