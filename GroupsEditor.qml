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

// The Groups page (docs/behavior/preferences.md PREFS-109 on), in the Layout
// page's language: the camera as the Layout page draws it, a rail of the
// bar's five zones holding every group's face where the bar puts it, one
// drawer under each zone showing its open group's widgets (the faces are its
// tabs, PREFS-120), the pool of widgets in no
// group as one tilted slab at the bottom, and the chosen group's inspector at
// the bottom right with the keys beside it.
//
// Keyboard and pointer share one state machine (GroupsEditorModel.js): a
// cursor rests on a face, a zone's "+", a widget in a drawer or in the pool;
// Space (or a drag) lifts a widget, moving it previews where it lands (in a
// drawer, the pool, or a "+" for a new group) and Space (or release) drops
// it. The rail, the drawers and the pool are one Tab stop; the inspector is
// the other.
Item {
    id: editor
    required property var preferences
    // The Layout page's editor: its geometry, camera and how the bar draws things.
    required property var layout
    readonly property var bar: preferences.bar
    property string selectedId: ""
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
            var m = (memberLists[p.id] || []).filter(function (r) {
                return r.instanceKey !== editor.liftedKey;
            })[p.pos];
            return m ? "member:" + m.instanceKey : "empty:" + p.id;
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
        if (kind === "empty")
            return Editor.facePlace(stepState, rest) ? {
                area: "drawer",
                id: rest,
                pos: 0
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
    // A group is always chosen when there is one (PREFS-37): the first on the rail.
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
        if (at.area === "drawer")
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
        if (lifted)
            return;
        if (carry && at.area === "rail") {
            var id = Editor.groupAt(stepState, at), group = groupOf(id);
            if (!group)
                return;
            if (dx) {
                var zone = Editor.nextZone(zones, group.section, dx);
                if (zone)
                    edit(id, {
                        section: zone
                    });
            } else {
                var v = Editor.nextVisibility(group.visibility, dy);
                if (v)
                    edit(id, {
                        visibility: v
                    });
            }
            cursorKey = "face:" + id;
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
        var faceId = at.area === "rail" ? Editor.groupAt(stepState, at) : "";
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
        else if (enter && faceId) {
            nameField.forceActiveFocus(Qt.TabFocusReason);
            nameField.selectAll();
        } else if ((enter || c === "n") && at.area === "rail")
            createIn(at.zone, "");
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
    onPointerLiftChanged: if (!pointerLift)
        autoScroll.target = null

    // ------------------------------------------------------------ geometry
    // The Layout page's: the same axis, columns, camera and tilt, so
    // switching pages moves nothing of the camera.
    readonly property real axis: layout.axis
    readonly property real pageTop: layout.pageTop
    readonly property var columns: layout.columns
    readonly property real colBase: layout.plateX + layout.platePad
    readonly property real tilt: layout.tilt
    readonly property real planeDistance: layout.planeDistance
    readonly property bool lightTheme: layout.lightTheme
    readonly property bool cameraShown: layout.previewCamera && !!layout.previewNotch
    readonly property string centerSide: bar ? bar.barOptions.centerSide : "right"
    readonly property var railCols: Editor.railColumns(cameraShown, centerSide)
    function columnBox(i) {
        return {
            x: colBase + columns.xs[i],
            width: columns.widths[i]
        };
    }
    function zoneBox(zone) {
        return columnBox(railCols[zone]);
    }
    readonly property var labelBox: columnBox(railCols.label)
    readonly property real stackTop: layout.stackTop
    readonly property real railHeight: Style.space(32)
    readonly property real railBottom: stackTop + railHeight
    readonly property real faceHeight: Style.space(22)
    readonly property real faceGap: Style.space(4)
    readonly property real segPad: Math.round((railHeight - faceHeight) / 2)
    readonly property real tileRadius: Math.min(Style.space(10), Style.cornerRadius)
    readonly property real chipRadius: Math.max(0, Math.min(Style.space(5), Style.cornerRadius - Style.space(3)))
    readonly property color pageColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    function tileColor(lead) {
        return Qt.tint(pageColor, Qt.alpha(Commons.Color.popups.text, lead ? 0.09 : 0.065));
    }
    function pillWidth(n) {
        return layout.textInk(String(n), Style.font.family, Style.font.caption).advance + Style.space(10);
    }
    function faceNatural(g) {
        if (!g)
            return Style.space(40);
        return faceCompact(g) + layout.textInk(g.label, Style.font.family, Style.font.caption).advance + Style.space(5);
    }
    // A face without its name: the icon and the count pill inside the chip.
    function faceCompact(g) {
        if (!g)
            return Style.space(30);
        return Math.max(Style.space(30), Style.space(6) + (g.visibility === "managed" ? Style.space(10) : 0) + Style.space(16) + Style.space(5) + pillWidth((memberLists[g.id] || []).length) + Style.space(6));
    }
    // Each zone's segment on the rail: its faces in bar order, then its "+"
    // at the end. Faces keep their names while all of the zone's fit, else
    // all drop them; past the room the segment clips them, the "+" stays
    // (GroupsEditorModel.faceWidths). `seen` is the part of a face not clipped.
    readonly property var railLayout: {
        var out = ({});
        zones.forEach(function (zone) {
            var box = editor.zoneBox(zone), ids = editor.faces[zone] || [];
            var list = ids.map(function (id) {
                return editor.groupOf(id);
            });
            var room = Math.max(0, box.width - 2 * editor.segPad - editor.faceHeight - editor.faceGap);
            var fit = Editor.faceWidths(list.map(editor.faceNatural), list.map(editor.faceCompact), room, editor.faceGap);
            var x = box.x + editor.segPad, end = x + room;
            out[zone] = {
                x: box.x,
                width: box.width,
                plusX: box.x + box.width - editor.segPad - editor.faceHeight,
                named: fit.named,
                chips: ids.map(function (id, i) {
                    var w = fit.widths[i];
                    var chip = {
                        id: id,
                        x: x,
                        width: w,
                        seen: Math.max(0, Math.min(w, end - x))
                    };
                    x += w + editor.faceGap;
                    return chip;
                })
            };
        });
        return out;
    }
    function faceChip(id) {
        var slot = slots[id];
        if (!slot)
            return null;
        return railLayout[slot.zone].chips[slot.index] || null;
    }
    // The drawers hang 20 px under the rail, one per zone at its column,
    // showing the zone's open group.
    readonly property real drawersTop: railBottom + Style.space(20)
    readonly property real headerHeight: Style.space(34)
    readonly property real noteHeight: Style.space(18)
    readonly property real emptyHeight: Style.space(46)
    readonly property real drawerPad: Style.space(6)
    readonly property real chipHeight: layout.chipHeight
    readonly property real chipGap: layout.chipGap
    function drawerNote(g) {
        return !g ? "" : g.visibility === "hidden" ? "Hidden: kept, never opens" : g.visibility === "managed" ? "On demand: behind its circle" : "";
    }
    function drawerDemand(id) {
        var n = drawerList(id).length, g = groupOf(id);
        return headerHeight + Style.space(4) + (drawerNote(g) ? noteHeight : 0) + (n ? n * chipHeight + (n - 1) * chipGap : emptyHeight) + Style.space(8);
    }
    readonly property real drawerFloor: headerHeight + Style.space(4) + noteHeight + chipHeight + Style.space(8)
    // The pool spans the zones' columns; its name sits in the rail's label column.
    readonly property var poolBox: {
        var cols = zones.map(function (z) {
            return editor.railCols[z];
        });
        var lo = Math.min.apply(null, cols), hi = Math.max.apply(null, cols);
        return {
            x: colBase + columns.xs[lo],
            width: columns.xs[hi] + columns.widths[hi] - columns.xs[lo]
        };
    }
    readonly property real poolPad: layout.tilePad
    readonly property real poolSpacing: layout.columnGap
    readonly property real poolChipWidth: layout.chipWidth
    readonly property int poolPerRow: Editor.perRow(poolBox.width - 2 * poolPad, poolChipWidth, poolSpacing)
    readonly property int poolRows: Math.max(1, Math.ceil(poolList.length / poolPerRow))
    readonly property real poolLabelHeight: poolLabel.implicitHeight + Style.space(12)
    readonly property real poolDemand: Math.max(poolLabelHeight, 2 * poolPad + poolRows * chipHeight + (poolRows - 1) * poolSpacing)
    readonly property real poolFloor: Math.max(poolLabelHeight, 2 * poolPad + chipHeight)
    // The bands (PREFS-113): the page under the header's band down to the
    // band the legend and the inspector take, the pool at its bottom.
    readonly property real bottomBand: Math.max(layout.legendBand, selectedGroup ? inspector.height + Style.space(24) : 0)
    readonly property var bands: Editor.shareBands(height - stackTop - bottomBand, drawersTop - stackTop + layout.layerGap, Model.tiltedHeight(poolDemand, tilt, planeDistance), Model.tiltedHeight(poolFloor, tilt, planeDistance), drawerFloor)
    readonly property real drawerBand: bands.drawers
    readonly property real poolSeen: bands.poolSeen
    readonly property real poolTop: Math.max(drawersTop + drawerBand + layout.layerGap, height - bottomBand - poolSeen)
    readonly property real poolPlane: Model.tiltedPlaneHeight(poolSeen, tilt, planeDistance)

    // ---------------------------------------------------------- the camera
    // The Layout page's camera at the same place; its cap stays solid down
    // to the rail's bottom, and the beam fades out under the pool.
    CameraShaft {
        id: camera
        visible: editor.cameraShown
        z: -1
        axis: editor.axis
        half: editor.columns.widths[3] / 2
        line: editor.stackTop
        pageTop: editor.pageTop
        beamBottom: editor.poolTop + editor.poolSeen + Style.space(8)
        capBottom: editor.railBottom
        capLength: Style.space(24)
        tilt: editor.tilt
        planeDistance: editor.planeDistance
        lightTheme: editor.lightTheme
    }

    // ------------------------------------------------------------ the rail
    // Its name, what it is and what it holds, in the label column.
    Column {
        x: editor.labelBox.x + Style.space(2)
        y: editor.stackTop + Style.space(6)
        width: editor.labelBox.width - Style.space(6)
        spacing: Style.space(6)
        Text {
            width: parent.width
            text: "Groups"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: "Each face where the bar puts it"
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            text: editor.groups.length + (editor.groups.length === 1 ? " group, " : " groups, ") + editor.memberTotal + (editor.memberTotal === 1 ? " widget" : " widgets")
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
        }
    }
    Repeater {
        model: editor.zones
        Segment {}
    }
    Repeater {
        model: editor.order
        FaceChip {}
    }
    Repeater {
        model: editor.zones
        PlusSlot {}
    }

    // --------------------------------------------------------- the drawers
    // One per zone, its open group's; the faces above are its tabs.
    Repeater {
        model: editor.zones
        Drawer {}
    }

    // ------------------------------------------------------------ the pool
    // One slab across the zones' columns, tilted back about its top edge
    // like a layer, its name and the filter in the label column.
    Item {
        id: poolPlate
        x: editor.layout.plateX
        y: editor.poolTop
        width: editor.layout.plateWidth
        height: editor.poolSeen
        z: 1
        Item {
            id: poolFace
            width: poolPlate.width
            height: editor.poolPlane
            transform: Rotation {
                axis {
                    x: 1
                    y: 0
                    z: 0
                }
                origin.x: editor.axis - poolPlate.x
                origin.y: 0
                distanceToPlane: editor.planeDistance
                angle: editor.tilt
            }
            Column {
                id: poolLabel
                x: editor.labelBox.x - poolPlate.x + Style.space(2)
                y: Style.space(6)
                width: editor.labelBox.width - Style.space(6)
                spacing: Style.space(6)
                Text {
                    width: parent.width
                    text: "Not in a group"
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: editor.poolAll.length + (editor.poolAll.length === 1 ? " widget" : " widgets") + " in bar order"
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.55)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                }
                // The filter (PREFS-42): typing while the pool has the cursor fills it.
                BorderSurface {
                    readonly property bool live: editor.at.area === "pool" && stage.activeFocus
                    width: parent.width
                    height: Style.space(26)
                    antialiasing: true
                    radius: editor.chipRadius
                    color: "transparent"
                    borderSpec: Border.flat(live && editor.filterText ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.14), 1)
                    Text {
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
            }
            Item {
                id: poolCell
                readonly property bool targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "pool"
                readonly property bool cursorHere: !editor.lifted && editor.at.area === "pool"
                readonly property alias window: poolWindow
                x: editor.poolBox.x - poolPlate.x
                width: editor.poolBox.width
                height: poolFace.height
                DashedFrame {
                    anchors.fill: parent
                    radius: editor.tileRadius
                    stroke: Qt.alpha(poolCell.targeted ? Commons.Color.accent : Commons.Color.popups.text, poolCell.targeted ? 0.9 : 0.3)
                }
                Text {
                    x: editor.poolPad + Style.space(2)
                    y: editor.poolPad + Style.space(5)
                    width: parent.width - 2 * x
                    visible: editor.poolList.length === 0
                    text: editor.filterText ? "No widget matches “" + editor.filterText + "”. Esc clears the filter." : "Every widget is in a group. x on one in a drawer, or a drag here, takes it out."
                    textFormat: Text.PlainText
                    color: Qt.alpha(Commons.Color.popups.text, 0.3)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                }
                ChipWindow {
                    id: poolWindow
                    anchors.fill: parent
                    pad: editor.poolPad
                    viewTop: editor.poolPad
                    flowWidth: Math.max(1, poolCell.width - 2 * editor.poolPad)
                    spacing: editor.poolSpacing
                    perRow: editor.poolPerRow
                    current: poolCell.cursorHere
                    fade: editor.pageColor
                    model: poolTiles.model
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
                            width: editor.poolChipWidth
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- the stage
    // The rail, the drawers and the pool: one Tab stop with one cursor, and
    // every pointer gesture over them.
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
            cursorShape: editor.pointerLift ? Qt.ClosedHandCursor : editor.hoverKey.indexOf("member:") === 0 || editor.hoverKey.indexOf("pool:") === 0 || editor.hoverKey.indexOf("face:") === 0 ? Qt.OpenHandCursor : editor.hoverKey.indexOf("plus:") === 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
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
                var win = editor.windowAt(Qt.point(wheel.x, wheel.y));
                if (!win || !win.overflows) {
                    wheel.accepted = false;
                    return;
                }
                win.scrollBy(wheel.pixelDelta.y ? -wheel.pixelDelta.y : -wheel.angleDelta.y / 120 * win.rowStep);
            }
            onPressed: function (mouse) {
                editor.hoverOn(null);
                if (editor.lifted)
                    editor.cancel();
                var point = Qt.point(mouse.x, mouse.y);
                editor.pressPoint = point;
                var hit = editor.hitAt(point);
                editor.pressed = hit && (hit.kind === "member" || hit.kind === "poolchip" || hit.kind === "face") ? hit : null;
                if (hit && hit.place)
                    editor.place(hit.place);
                else if (hit && hit.kind === "drawer")
                    editor.place(Editor.facePlace(editor.stepState, hit.id) || editor.at);
                stage.forceActiveFocus(Qt.MouseFocusReason);
            }
            onReleased: function (mouse) {
                var clicked = !editor.pointerLift;
                editor.pressed = null;
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
    // What is under the pointer, in the editor: a face, a "+", a zone's
    // segment, a drawer's member or the drawer, a pool chip or the pool.
    QtObject {
        id: registry
        property var drawers: []
        function add(d) {
            drawers = drawers.concat([d]);
        }
        function drop(d) {
            drawers = drawers.filter(function (x) {
                return x !== d;
            });
        }
    }
    function inBox(point, x, y, w, h) {
        return point.x >= x && point.y >= y && point.x < x + w && point.y < y + h;
    }
    function hitAt(point) {
        var chipY = stackTop + segPad;
        for (var z = 0; z < zones.length; z++) {
            var seg = railLayout[zones[z]];
            if (inBox(point, seg.plusX, chipY, faceHeight, faceHeight))
                return {
                    kind: "plus",
                    zone: zones[z],
                    key: "plus:" + zones[z],
                    place: {
                        area: "rail",
                        zone: zones[z],
                        slot: seg.chips.length
                    }
                };
            for (var i = 0; i < seg.chips.length; i++)
                if (inBox(point, seg.chips[i].x, chipY, seg.chips[i].seen, faceHeight))
                    return {
                        kind: "face",
                        id: seg.chips[i].id,
                        key: "face:" + seg.chips[i].id,
                        place: {
                            area: "rail",
                            zone: zones[z],
                            slot: i
                        }
                    };
            if (inBox(point, seg.x, stackTop, seg.width, railHeight))
                return {
                    kind: "zone",
                    zone: zones[z],
                    key: ""
                };
        }
        for (var d = 0; d < registry.drawers.length; d++) {
            var drawer = registry.drawers[d];
            if (!drawer.groupId)
                continue;
            var p = drawer.mapFromItem(editor, point.x, point.y);
            if (p.x < 0 || p.y < 0 || p.x >= drawer.width || p.y >= drawer.height)
                continue;
            var tile = drawer.window.viewContains(drawer.window.mapFromItem(editor, point.x, point.y)) ? tileIn(drawer.window, point) : null;
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
                drawer: drawer
            };
        }
        var q = poolCell.mapFromItem(editor, point.x, point.y);
        if (q.x >= 0 && q.y >= 0 && q.x < poolCell.width && q.y < poolCell.height) {
            var chip = poolWindow.viewContains(poolWindow.mapFromItem(editor, point.x, point.y)) ? tileIn(poolWindow, point) : null;
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
    function windowAt(point) {
        for (var d = 0; d < registry.drawers.length; d++) {
            if (!registry.drawers[d].groupId)
                continue;
            var p = registry.drawers[d].mapFromItem(editor, point.x, point.y);
            if (p.x >= 0 && p.y >= 0 && p.x < registry.drawers[d].width && p.y < registry.drawers[d].height)
                return registry.drawers[d].window;
        }
        var q = poolCell.mapFromItem(editor, point.x, point.y);
        return q.x >= 0 && q.y >= 0 && q.x < poolCell.width && q.y < poolCell.height ? poolWindow : null;
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
        else if (hit && (hit.kind === "member" || hit.kind === "drawer"))
            next = {
                area: "drawer",
                id: hit.id,
                pos: gapIn(hit.drawer ? hit.drawer.window : drawerFor(hit.id).window, point)
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
        return registry.drawers.find(function (d) {
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
    // The cursor's widget, or a lifted one's landing place, scrolls into view.
    function revealCursor() {
        var p = lifted && liftTarget ? liftTarget : at;
        if (p.area === "drawer") {
            var d = drawerFor(p.id);
            if (d)
                d.window.reveal(p.pos);
        } else if (p.area === "pool")
            poolWindow.reveal(lifted ? Math.max(0, poolList.findIndex(function (v) {
                return v.placeholder;
            })) : p.pos);
    }

    // ------------------------------------------------------- the dragged copy
    Chip {
        visible: editor.pointerLift && !!editor.lifted && !editor.liftingFace
        record: editor.lifted && editor.lifted.record || ({})
        ghost: true
        width: editor.poolChipWidth
        x: editor.pointer.x - width / 2
        y: editor.pointer.y - height / 2
        z: 100
    }
    FaceLook {
        visible: editor.pointerLift && editor.liftingFace
        group: editor.liftingFace ? editor.groupOf(editor.lifted.face) : null
        ghost: true
        width: group ? editor.faceNatural(group) : 0
        x: editor.pointer.x - width / 2
        y: editor.pointer.y - height / 2
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
        nameTip.detail = hit.kind === "plus" ? "" : g ? "Group" : hit.record ? hit.record.id : "";
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
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: nameTip.title
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }
            Text {
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
                    Text {
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
                        Text {
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
                            editor.edit(editor.selectedId, {
                                section: value
                            });
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Shift h l on the rail moves it too"
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
                Text {
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
                Text {
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
    readonly property var legend: picker.opened ? picker.hints : lifted ? [
        {
            keys: "h j k l",
            label: "Through the open drawers, the pool, the faces and the + slots"
        },
        {
            keys: "space",
            label: liftTarget && liftTarget.area === "plus" ? "Drop: a new group in " + layout.zoneNames[liftTarget.zone] : liftTarget && liftTarget.area === "face" && groupOf(liftTarget.id) ? "Drop: at the end of " + groupOf(liftTarget.id).label : "Drop"
        },
        {
            keys: "esc",
            label: "Put it back"
        }
    ] : stageFocused && at.area === "rail" ? [
        {
            keys: "h l",
            label: "Choose a face, zone by zone"
        },
        {
            keys: "shift h l",
            label: "Move the face to the next zone"
        },
        {
            keys: "shift j k",
            label: "On the bar, on demand, hidden"
        },
        {
            keys: "j",
            label: Editor.groupAt(stepState, at) ? "Into its drawer" : "Into the pool"
        },
        {
            keys: "n",
            label: "New group in " + layout.zoneNames[at.zone]
        },
        {
            keys: "x",
            label: pendingDissolve && pendingDissolve === Editor.groupAt(stepState, at) ? "Again to dissolve" : "Dissolve, asked twice"
        },
        {
            keys: "enter",
            label: Editor.groupAt(stepState, at) ? "Inspect, at its name" : "New group here"
        },
        {
            keys: "tab",
            label: "The inspector"
        }
    ] : stageFocused && at.area === "drawer" ? [
        {
            keys: "j k",
            label: "Walk the widgets, up to the face, down to the pool"
        },
        {
            keys: "h l",
            label: "The same row in the next drawer"
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
            label: "Inspect it"
        },
        {
            keys: "esc",
            label: "Back to the rail"
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
            label: filterText ? "Clear the filter" : "Back to the rail"
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
            label: "Back to the rail"
        }
    ]) : [
        {
            keys: "tab",
            label: "The rail"
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
            Text {
                required property var modelData
                required property int index
                Layout.row: index
                Layout.column: 1
                Layout.fillWidth: true
                text: modelData.label
                textFormat: Text.PlainText
                color: Qt.alpha(Commons.Color.popups.text, 0.7)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
            }
        }
    }
    // With no group yet, the page says how to start.
    Text {
        visible: editor.groups.length === 0
        x: editor.zoneBox("left").x
        y: editor.drawersTop
        width: editor.poolBox.width
        text: "No groups yet. A group gathers related widgets behind one face on the bar. Press n on a zone, click its +, or drop a widget from the pool on it."
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
    }

    // ---------------------------------------------------------- components
    // A zone on the rail: a flat tile, its name above it.
    component Segment: Item {
        id: segment
        required property string modelData
        readonly property var box: editor.railLayout[modelData]
        readonly property bool active: (editor.lifted && editor.liftTarget ? editor.liftTarget.zone === modelData || (editor.liftTarget.area === "drawer" || editor.liftTarget.area === "face") && editor.slots[editor.liftTarget.id] && editor.slots[editor.liftTarget.id].zone === modelData : editor.at.area === "rail" && editor.at.zone === modelData)
        readonly property bool targeted: editor.liftingFace && !!editor.liftTarget && editor.liftTarget.zone === modelData && editor.liftTarget.zone !== editor.lifted.zone
        x: box.x
        y: editor.stackTop
        width: box.width
        height: editor.railHeight
        Text {
            y: -height - Style.space(4)
            x: Style.space(2)
            width: parent.width
            text: editor.layout.zoneNames[segment.modelData] || ""
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, segment.active ? 0.9 : 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: segment.active ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        BorderSurface {
            anchors.fill: parent
            antialiasing: true
            radius: editor.tileRadius
            color: editor.tileColor(true)
            borderSpec: Border.flat(segment.targeted ? Commons.Color.accent : segment.active && editor.stageFocused ? Qt.alpha(Commons.Color.accent, 0.6) : Qt.alpha(Commons.Color.popups.text, 0.12), 1)
        }
    }
    // A face on the rail, drawn by its layer: on the bar accent-tinted, on
    // demand plain with the demand dots' ring, hidden dashed and faded.
    component FaceLook: Item {
        id: look
        property var group: null
        property bool ghost: false
        property bool isCursor: false
        property bool chosen: false
        property bool targeted: false
        property bool hovered: false
        // Without its name: the icon and the count pill (PREFS-111).
        property bool named: true
        // The part the segment does not clip.
        property real seen: width
        readonly property string visibility: group ? group.visibility : "shown"
        readonly property int count: group ? (editor.memberLists[group.id] || []).length : 0
        height: editor.faceHeight
        Item {
            width: Math.max(0, Math.min(look.width, look.seen))
            height: look.height
            visible: width > 0
            clip: width < look.width - 0.5
            Item {
                width: look.width
                height: look.height
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
                    Text {
                        id: faceName
                        visible: look.named
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
                        Text {
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
        }
    }
    component FaceChip: FaceLook {
        id: chip
        required property string modelData
        readonly property var box: editor.faceChip(modelData) || ({
                x: 0,
                width: 0,
                seen: 0
            })
        readonly property var slot: editor.slots[modelData] || null
        // The open face, the one its zone's drawer shows (PREFS-120).
        readonly property bool open: !!slot && editor.openIds[slot.zone] === modelData
        readonly property real mid: Math.min(chip.width, box.seen) / 2
        group: editor.groupOf(modelData)
        named: !!slot && editor.railLayout[slot.zone].named
        seen: box.seen
        isCursor: !editor.lifted && editor.cursorKey === "face:" + modelData
        chosen: editor.selectedId === modelData
        targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "face" && editor.liftTarget.id === modelData
        hovered: editor.hoverKey === "face:" + modelData
        opacity: editor.liftingFace && editor.lifted.face === modelData && editor.pointerLift ? 0.35 : 1
        x: box.x
        y: editor.stackTop + editor.segPad
        width: box.width
        z: 2
        // The open face's leader to its zone's drawer, the dot at the face.
        Shape {
            id: faceLeader
            readonly property var drawer: chip.slot ? editor.zoneBox(chip.slot.zone) : ({
                    x: 0,
                    width: 0
                })
            readonly property real endX: Math.max(drawer.x + Style.space(12), Math.min(drawer.x + drawer.width - Style.space(12), chip.x + chip.mid)) - chip.x
            visible: chip.open && chip.mid > 0 && drawer.width > 0
            x: 0
            y: 0
            width: Math.max(chip.width, endX + 1)
            height: editor.drawersTop - chip.y + 1
            ShapePath {
                strokeColor: Qt.alpha(Commons.Color.accent, chip.chosen ? 1 : 0.45)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                fillColor: "transparent"
                startX: chip.mid
                startY: editor.faceHeight + Style.space(3)
                PathLine {
                    x: chip.mid
                    y: editor.faceHeight + Style.space(9)
                }
                PathLine {
                    x: faceLeader.endX
                    y: editor.drawersTop - chip.y
                }
            }
        }
        Rectangle {
            visible: faceLeader.visible
            x: chip.mid - width / 2
            y: editor.faceHeight + Style.space(3) - height / 2
            width: Style.space(6)
            height: width
            radius: width / 2
            color: Qt.alpha(Commons.Color.accent, chip.chosen ? 1 : 0.45)
        }
    }
    // A zone's "+": a new group there (n or Enter on it, a click, or a widget
    // dropped on it).
    component PlusSlot: Item {
        id: plus
        required property string modelData
        readonly property bool isCursor: !editor.lifted && editor.cursorKey === "plus:" + modelData
        readonly property bool targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "plus" && editor.liftTarget.zone === modelData
        readonly property bool hovered: editor.hoverKey === "plus:" + modelData
        readonly property bool lit: isCursor || targeted || hovered
        x: editor.railLayout[modelData].plusX
        y: editor.stackTop + editor.segPad
        width: editor.faceHeight
        height: editor.faceHeight
        z: 2
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
        Text {
            anchors.centerIn: parent
            text: "+"
            textFormat: Text.PlainText
            color: plus.lit ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }
    // A zone's drawer, flat under its rail segment, showing its open group
    // (PREFS-120): a header with its face and count, then its widgets in a
    // window that scrolls (PREFS-106). Another face opened swaps it at once.
    component Drawer: Item {
        id: drawer
        required property string modelData
        readonly property string zone: modelData
        readonly property string groupId: editor.openIds[modelData] || ""
        readonly property var group: editor.groupOf(groupId)
        readonly property var box: editor.zoneBox(modelData)
        readonly property bool chosen: !!groupId && editor.selectedId === groupId
        readonly property bool hidden: !!group && group.visibility === "hidden"
        readonly property var list: groupId ? editor.drawerList(groupId) : []
        readonly property string note: editor.drawerNote(group)
        readonly property bool targeted: !!editor.lifted && !editor.liftingFace && !!editor.liftTarget && editor.liftTarget.area === "drawer" && editor.liftTarget.id === groupId
        readonly property bool cursorHere: !editor.lifted && editor.at.area === "drawer" && editor.at.id === groupId
        readonly property alias window: drawerWindow
        x: box.x
        y: editor.drawersTop
        width: box.width
        visible: groupId !== ""
        height: groupId ? Math.min(editor.drawerDemand(groupId), editor.drawerBand) : 0
        z: 3
        opacity: hidden ? 0.6 : 1
        // A swapped group starts at its top, the cursor's widget in view.
        onGroupIdChanged: {
            drawerWindow.scroll = 0;
            Qt.callLater(editor.revealCursor);
        }
        Component.onCompleted: registry.add(this)
        Component.onDestruction: registry.drop(this)
        Behavior on height {
            enabled: editor.bar.animationsEnabled
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
        // Its shadow on the page, soft: rings that widen as they fade.
        Repeater {
            model: 8
            Rectangle {
                required property int index
                z: -1
                x: -index
                y: Style.space(6) + index
                width: drawer.width + 2 * index
                height: drawer.height + index
                radius: editor.tileRadius + index
                antialiasing: true
                color: Qt.rgba(0, 0, 0, editor.lightTheme ? 0.025 : 0.05)
            }
        }
        BorderSurface {
            id: drawerSurface
            anchors.fill: parent
            antialiasing: true
            radius: editor.tileRadius
            topLeftRadius: 0
            topRightRadius: 0
            color: editor.tileColor(drawer.chosen)
            borderSpec: drawer.hidden && !drawer.chosen && !(drawer.targeted && drawer.list.length === 1) ? Border.none() : Border.flat(drawer.chosen || drawer.targeted && drawer.list.length === 1 ? Qt.alpha(Commons.Color.accent, 0.7) : Qt.alpha(Commons.Color.popups.text, 0.12), 1)
        }
        DashedFrame {
            visible: drawer.hidden && !drawer.chosen
            anchors.fill: parent
            radius: editor.tileRadius
            topRadius: 0
            stroke: Qt.alpha(Commons.Color.popups.text, 0.6)
        }
        Row {
            x: Style.space(10)
            width: parent.width - 2 * x
            height: editor.headerHeight
            spacing: Style.space(6)
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(18)
                height: Style.space(18)
                GroupFace {
                    anchors.centerIn: parent
                    group: drawer.group
                    faceMode: "glyph"
                    color: Commons.Color.popups.text
                    fontFamily: editor.layout.barFont
                    fontSize: Style.font.body
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - Style.space(18) - 2 * parent.spacing - drawerPill.width)
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
                Text {
                    anchors.centerIn: parent
                    text: drawerPill.n
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }
        Rectangle {
            y: editor.headerHeight
            width: parent.width
            height: 1
            color: Qt.alpha(Commons.Color.popups.text, 0.1)
        }
        Text {
            visible: drawer.note !== ""
            x: Style.space(10)
            y: editor.headerHeight + Style.space(4)
            width: parent.width - 2 * x
            height: editor.noteHeight
            verticalAlignment: Text.AlignVCenter
            text: drawer.note
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
        }
        Text {
            visible: drawer.list.length === 0
            x: Style.space(10)
            y: drawerWindow.viewTop
            width: parent.width - 2 * x
            text: "Empty. Drop widgets here, or press space on one in the pool."
            textFormat: Text.PlainText
            color: Qt.alpha(Commons.Color.popups.text, 0.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
        }
        BorderSurface {
            visible: drawer.list.length === 0 && drawer.cursorHere && editor.stageFocused
            x: Style.space(3)
            y: drawerWindow.viewTop - Style.space(3)
            width: parent.width - Style.space(6)
            height: Math.max(0, parent.height - y - Style.space(3))
            antialiasing: true
            color: "transparent"
            radius: editor.chipRadius
            borderSpec: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
        }
        ChipWindow {
            id: drawerWindow
            anchors.fill: parent
            pad: editor.drawerPad
            viewTop: editor.headerHeight + Style.space(4) + (drawer.note ? editor.noteHeight : 0)
            flowWidth: Math.max(1, drawer.width - 2 * editor.drawerPad)
            spacing: editor.chipGap
            perRow: 1
            current: drawer.cursorHere
            fade: drawerSurface.color
            model: memberTiles.model
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
                    width: Math.max(Style.space(40), drawer.width - 2 * editor.drawerPad)
                }
            }
        }
    }
    // A window of chips that scrolls when it has more rows than room
    // (PREFS-106): cut at its edges with the surface's colour fading over
    // the cut chips, a hairline thumb in the right pad.
    component ChipWindow: Item {
        id: win
        property real pad: 0
        property real viewTop: 0
        property real flowWidth: 0
        property real spacing: 0
        property int perRow: 1
        property bool current: false
        property color fade: "transparent"
        property alias model: chipRepeater.model
        readonly property alias tiles: chipRepeater
        readonly property real rowStep: editor.chipHeight + spacing
        readonly property real room: Style.space(10)
        readonly property real viewHeight: Math.max(0, height - viewTop - pad)
        readonly property real contentHeight: chipFlow.implicitHeight
        readonly property real maxScroll: Math.max(0, contentHeight - viewHeight)
        readonly property bool overflows: maxScroll > 0.5
        property real scroll: 0
        Behavior on scroll {
            enabled: editor.bar.animationsEnabled
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
        function reveal(pos) {
            if (!overflows)
                return;
            var top = Math.floor(pos / Math.max(1, perRow)) * rowStep, bottom = top + editor.chipHeight;
            if (top - room < scroll)
                scroll = Math.max(0, top - room);
            else if (bottom > scroll + viewHeight)
                scroll = Math.min(maxScroll, bottom - viewHeight);
        }
        function viewContains(p) {
            return p.y >= viewTop - room && p.y < viewTop + viewHeight;
        }
        Item {
            x: win.pad - Style.space(4)
            y: win.viewTop - win.room
            width: win.width - 2 * win.pad + 2 * Style.space(4)
            height: win.viewHeight + win.room
            clip: true
            Flow {
                id: chipFlow
                x: Style.space(4)
                y: win.room - win.scroll
                width: win.flowWidth
                spacing: win.spacing
                Repeater {
                    id: chipRepeater
                }
            }
            Rectangle {
                visible: win.scroll > 0.5
                z: 2
                width: parent.width
                height: win.room + Style.space(10)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: win.fade
                    }
                    GradientStop {
                        position: 0.5
                        color: win.fade
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(win.fade, 0)
                    }
                }
            }
            Rectangle {
                visible: win.scroll < win.maxScroll - 0.5
                z: 2
                y: parent.height - height
                width: parent.width
                height: Style.space(14)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(win.fade, 0)
                    }
                    GradientStop {
                        position: 1
                        color: win.fade
                    }
                }
            }
        }
        Rectangle {
            visible: win.overflows
            x: win.width - win.pad + Style.space(2)
            y: win.viewTop + (win.contentHeight > 0 ? win.scroll / win.contentHeight * win.viewHeight : 0)
            width: Style.spaceReal(1.5)
            height: Math.max(Style.space(16), win.viewHeight * win.viewHeight / Math.max(1, win.contentHeight))
            radius: width / 2
            antialiasing: true
            color: Qt.alpha(Commons.Color.popups.text, win.current ? 0.5 : 0.3)
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
            Text {
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
