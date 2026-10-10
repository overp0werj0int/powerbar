import QtQuick
import QtQuick.Window
import qs.Commons

// Hover and selection for bar and drawer items, drawn like the tiles in
// Preferences → Layout: a soft rounded fill behind the item. Visual only;
// hover and clicks stay with the enclosing widget.
Rectangle {
  id: mark
  property bool hovered: false
  property bool selected: false
  property bool motionEnabled: true
  property color hoverColor: "transparent"
  property color selectedColor: "transparent"
  property real rounding: 6
  // The keyboard cursor: the same mark with an accent ring as its border, one
  // device pixel wide (keyboard.md KEYS-69). The caller also lights the mark
  // (`hovered`) for the cursor.
  property bool outlined: false
  property color outlineColor: Color.accent
  property real outlineWidth: 1 / Math.max(1, Screen.devicePixelRatio)
  // Where two lit highlights overlap (Equal gaps), the older one fades so the
  // eye goes to what just happened; the newer one draws on top. The keyboard
  // cursor never fades for that.
  property bool older: false
  property real litAt: 0
  readonly property bool shown: hovered || selected
  // The cursor arriving or leaving changes `outlined` and `hovered` together,
  // in either order, so both are settled once per event-loop turn: a change
  // that moved the ring is a cursor move and shows at once, without the fade.
  property bool lit: false
  property bool ringed: false
  property bool cursorMove: false
  onShownChanged: Qt.callLater(mark.settle)
  onOutlinedChanged: Qt.callLater(mark.settle)
  Component.onCompleted: settle()
  function settle() {
    cursorMove = outlined !== ringed
    ringed = outlined
    lit = shown
  }
  radius: Math.max(0, Math.min(rounding, Math.min(width, height) / 2))
  color: selected ? selectedColor : hoverColor
  // A border is drawn inside the shape: it has width only while it shows, so
  // the fill has no gap around it otherwise.
  border.width: ringed ? outlineWidth : 0
  border.color: outlineColor
  opacity: lit ? (older && !ringed ? 0.45 : 1) : 0
  z: lit && (!older || ringed) ? 1 : 0
  visible: opacity > 0
  Accessible.ignored: true
  Behavior on opacity { enabled: mark.motionEnabled && !mark.cursorMove; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
  Behavior on color { enabled: mark.motionEnabled && !mark.cursorMove; ColorAnimation { duration: 90 } }
}
