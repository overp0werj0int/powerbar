import QtQuick

// The camera's beam as one shade (shaders/beam.frag, docs/behavior/
// preferences.md PREFS-24): black, solid across the cap, a raised cosine
// across the beam, fading down the page with no slope at either end,
// dithered. vTop and vBottom say where the item lies down the camera's plane
// (PreferencesModel.tiltedDepth from the line it turns about), so every item
// drawing it continues the same function. CameraShaft draws the beam itself
// and hands its numbers to the tiles and slabs that draw it over their own
// surface.
ShaderEffect {
    property real vTop: 0
    property real vBottom: 0
    // How dark the beam is where it leaves the cap.
    property real peak: 0.65
    // Where the cap's solid black starts giving way to the beam, and where
    // it has fully become the beam.
    property real capEnd: 0
    property real capFade: 0
    // Where the beam has faded out.
    property real span: 1
    property real edge: 1.5 / Math.max(1, width / 2)
    property real taper: 0.3
    fragmentShader: Qt.resolvedUrl("shaders/beam.frag.qsb")
}
