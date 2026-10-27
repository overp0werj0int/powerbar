pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "CameraLookModel.js" as Model

// The camera's torn cap, its numbers in one place (docs/behavior/
// preferences.md PREFS-24, PREFS-132). The numbers are being tuned: every
// BeamShade (the camera's own on every page, the tiles' and strips') reads
// them here, the Look page's temporary pane sets them, and they are kept in
// the cache folder, read at start (a missing or bad file is the defaults)
// and written 500 ms after the last change. No config key, no IPC.
Singleton {
    id: look
    // Page px, thousandths per px, octaves, seeds and percent
    // (CameraLookModel.PARAMS).
    property int gapAbove: 8
    property int tearDepth: 14
    property int grain: 25
    property int octaves: 3
    property int seed: 7
    property int fringeSeed: 19
    property int fringeWidth: 2
    property int fringeStrength: 80
    property int shadeBlur: 18
    property int shadeDrop: 10
    property int shadeStrength: 45
    property int shadeSpread: 0

    readonly property var params: Model.PARAMS
    readonly property string path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/powerbar/camera-tear.json"

    function value(key) {
        return look[key];
    }
    // A change from the pane: applied at once, written once it settles.
    function set(key, v) {
        var next = Model.clamp(key, v);
        if (next === undefined || look[key] === next)
            return;
        look[key] = next;
        save.restart();
    }
    function apply(values) {
        Model.PARAMS.forEach(function (p) {
            look[p.key] = values[p.key];
        });
    }

    FileView {
        id: store
        path: look.path
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: look.apply(Model.parse(text()))
    }
    Timer {
        id: save
        interval: 500
        onTriggered: {
            var values = {};
            Model.PARAMS.forEach(function (p) {
                values[p.key] = look[p.key];
            });
            store.setText(Model.serialize(values));
        }
    }
}
