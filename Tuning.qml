pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "TuningModel.js" as Model

// The development numbers behind the look, in one place (docs/behavior/
// preferences.md PREFS-132; TuningModel.SECTIONS): whatever draws with one
// reads `Tuning.values.<key>`. The defaults are the look that ships. While
// the Tuning page is on (`on`, bound by Bar.qml from `powerbarTuning` in
// shell.json, INTEG-155) the page sets them and they are kept in the cache
// folder: read when the page comes on (a missing or bad file is the
// defaults) and written 500 ms after the last change. Off, the file is left
// alone and the defaults draw. No IPC.
Singleton {
    id: tuning
    property bool on: false
    property var values: Model.defaults()
    readonly property var sections: Model.SECTIONS
    readonly property string path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/powerbar/tuning.json"

    onOnChanged: values = on ? Model.parse(store.text()) : Model.defaults()
    // A change from the page: applied at once, written once it settles.
    function set(key, v) {
        var next = Model.clamp(key, v);
        if (next === undefined || values[key] === next)
            return;
        var copy = Object.assign({}, values);
        copy[key] = next;
        values = copy;
        if (on)
            save.restart();
    }

    FileView {
        id: store
        path: tuning.path
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: if (tuning.on) tuning.values = Model.parse(text())
    }
    Timer {
        id: save
        interval: 500
        onTriggered: store.setText(Model.serialize(tuning.values))
    }
}
