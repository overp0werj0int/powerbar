import QtQuick
import qs.Commons
import qs.Commons as Commons

// The camera's torn cap as one shade (shaders/beam.frag, docs/behavior/
// preferences.md PREFS-24): solid black down to a torn edge a little above
// the plates, a fringe along the tear and a soft shade under it, dithered.
// vTop and vBottom say where the item lies down the camera's plane
// (PreferencesModel.tiltedDepth from the line it turns about), so every item
// drawing it continues the same function; the tear's numbers are
// Tuning's (PREFS-132). CameraShaft draws the cap itself, and the tiles and strips
// draw it over their own surface. An item `outer` px wider than the column
// on each side with `spill` draws only the shade past the column's sides.
ShaderEffect {
    property real vTop: 0
    property real vBottom: 0
    // The camera's column, and how far past its sides this item reaches.
    property real colWidth: width - 2 * outer
    property real outer: 0
    property real spill: 0
    property real edge: 1.5 / Math.max(1, colWidth / 2)
    // The plane: its tilt (degrees) and how far it is seen from.
    property real tilt: 34
    property real planeDistance: 1600
    readonly property real tiltCos: Math.cos(tilt * Math.PI / 180)
    readonly property real tiltK: Math.sin(tilt * Math.PI / 180) / Math.max(1, planeDistance)
    // The paper's lighter core along the tear.
    property bool lightTheme: false
    property color fringeColor: lightTheme ? Qt.tint(Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1), Qt.rgba(1, 1, 1, 0.7)) : Qt.rgba(0.54, 0.57, 0.71, 1)
    // Tuning's numbers (TuningModel.SECTIONS), in page px.
    readonly property real unit: Style.space(1)
    readonly property real gapAbove: Tuning.values.gapAbove * unit
    readonly property real tearDepth: Tuning.values.tearDepth * unit
    readonly property real grain: Tuning.values.grain / 1000 / unit
    readonly property real octaves: Tuning.values.octaves
    readonly property real seed: Tuning.values.seed
    readonly property real fringeSeed: Tuning.values.fringeSeed
    readonly property real fringeWidth: Tuning.values.fringeWidth * unit
    readonly property real fringeStrength: Tuning.values.fringeStrength / 100
    readonly property real shadeBlur: Tuning.values.shadeBlur * unit
    readonly property real shadeDrop: Tuning.values.shadeDrop * unit
    readonly property real shadeStrength: Tuning.values.shadeStrength / 100
    readonly property real shadeSpread: Tuning.values.shadeSpread * unit
    fragmentShader: Qt.resolvedUrl("shaders/beam.frag.qsb")
}
