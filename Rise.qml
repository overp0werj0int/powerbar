import QtQuick

// A lift off a surface (docs/behavior/preferences.md PREFS-104): `value`
// glides up to `height` in 120 ms when `up` turns on, and drops to 0 in the
// same frame when it turns off, so a cursor moving fast leaves no trail of
// chips or tiles still settling with their shadows. At once both ways with
// animations off.
QtObject {
  id: rise
  property bool up: false
  property real height: 0
  property bool animate: true
  property real value: 0
  readonly property Animation glide: NumberAnimation {
    target: rise
    property: "value"
    duration: 120
    easing.type: Easing.OutCubic
  }
  onUpChanged: {
    glide.stop();
    if (up && animate) {
      glide.from = value;
      glide.to = height;
      glide.start();
    } else {
      value = up ? height : 0;
    }
  }
  Component.onCompleted: value = up ? height : 0
}
