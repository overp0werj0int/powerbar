import QtQuick
import qs.Commons

// The cursor's lift for a row or chip on a surface (docs/behavior/
// preferences.md PREFS-104): put one in the item, bind the item's
// `transform` to a Translate of -raise, its `scale` to `grown` and its `z`
// to `raised`. It draws the flat shadow band the item casts as far below
// it as it has risen, under the item (z -1), and glides up and drops at once
// (Rise). Lighter on a light theme. A control with no surface of its own (a
// fader, a row of chips) gives it `plate`, the strip's colour, drawn under
// the control while it is up so what it rises over does not show through,
// and `padX`/`padY` to reach past the control's edges as a row's surface
// does.
Item {
  id: lift
  property bool up: false
  property bool animate: true
  property bool lightTheme: false
  property real reach: Style.space(8)
  property real radius: 0
  property color plate: "transparent"
  property real padX: 0
  property real padY: 0
  readonly property real raise: rise.value
  readonly property bool raised: raise > 0
  // 103 % at the top, with the rise.
  readonly property real grown: 1 + 0.03 * (reach > 0 ? raise / reach : 0)
  anchors.fill: parent
  anchors.leftMargin: -padX
  anchors.rightMargin: -padX
  anchors.topMargin: -padY
  anchors.bottomMargin: -padY
  z: -1
  Rise {
    id: rise
    up: lift.up
    height: lift.reach
    animate: lift.animate
  }
  Rectangle {
    visible: lift.raised
    y: lift.raise + Style.space(3)
    width: parent.width
    height: parent.height
    radius: lift.radius
    antialiasing: true
    color: Qt.rgba(0, 0, 0, lift.lightTheme ? 0.2 : 0.3)
  }
  Rectangle {
    visible: lift.raised && lift.plate.a > 0
    anchors.fill: parent
    radius: lift.radius
    antialiasing: true
    color: lift.plate
  }
}
