import QtQuick
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
  // The keyboard cursor: the same mark with an accent ring as its border, so
  // ring and fill share one shape and one fade (keyboard.md KEYS-69). The
  // caller also lights the mark (`hovered`) for the cursor.
  property bool outlined: false
  property color outlineColor: Color.accent
  property real outlineWidth: 1.5
  // Where two lit highlights overlap (Equal gaps), the older one fades so the
  // eye goes to what just happened; the newer one draws on top. The keyboard
  // cursor never fades for that.
  property bool older: false
  property real litAt: 0
  readonly property bool shown: hovered || selected
  // A border is drawn inside the shape, so a transparent one would leave a
  // gap around the fill: the ring has width only while it shows. It stays on
  // while the mark fades out after the cursor left, and comes off at once
  // when the mark stays lit for something else (the pointer on it).
  property bool ringFading: false
  onOutlinedChanged: {
    if (outlined) ringFading = true
    else Qt.callLater(mark.settleRing)
  }
  function settleRing() { if (!outlined && (shown || opacity === 0)) ringFading = false }
  onOpacityChanged: if (opacity === 0 && !outlined) ringFading = false
  radius: Math.max(0, Math.min(rounding, Math.min(width, height) / 2))
  color: selected ? selectedColor : hoverColor
  border.width: outlined || ringFading ? outlineWidth : 0
  border.color: outlineColor
  opacity: shown ? (older && !outlined ? 0.45 : 1) : 0
  z: shown && (!older || outlined) ? 1 : 0
  visible: opacity > 0
  Accessible.ignored: true
  Behavior on opacity { enabled: mark.motionEnabled; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
  Behavior on color { enabled: mark.motionEnabled; ColorAnimation { duration: 90 } }
}
