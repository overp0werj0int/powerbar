import QtQuick

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
  readonly property bool shown: hovered || selected
  radius: Math.max(0, Math.min(rounding, Math.min(width, height) / 2))
  color: selected ? selectedColor : hoverColor
  opacity: shown ? 1 : 0
  visible: opacity > 0
  Accessible.ignored: true
  Behavior on opacity { enabled: mark.motionEnabled; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
  Behavior on color { enabled: mark.motionEnabled; ColorAnimation { duration: 90 } }
}
