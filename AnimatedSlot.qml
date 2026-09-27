import QtQuick

// Layout and chrome consume the same animated extent, so neighbouring icons
// cannot jump ahead of their island's expansion.
Item {
  id: slot
  property real targetWidth: 0
  property real targetHeight: 0
  property real targetInsetX: 0
  property real targetInsetY: 0
  property bool motionEnabled: true
  property int motionDuration: 100
  property int motionEasing: Easing.OutBack
  property real motionOvershoot: 0.3
  property bool ready: false
  property real animatedWidth: targetWidth
  property real animatedHeight: targetHeight
  property real animatedInsetX: targetInsetX
  property real animatedInsetY: targetInsetY
  implicitWidth: Math.max(0, animatedWidth)
  implicitHeight: Math.max(0, animatedHeight)
  width: implicitWidth
  height: implicitHeight
  clip: true
  Component.onCompleted: Qt.callLater(function() { slot.ready = true })
  Behavior on animatedWidth {
    enabled: slot.motionEnabled && slot.ready
    NumberAnimation { duration: slot.motionDuration; easing.type: slot.motionEasing; easing.overshoot: slot.motionOvershoot }
  }
  Behavior on animatedHeight {
    enabled: slot.motionEnabled && slot.ready
    NumberAnimation { duration: slot.motionDuration; easing.type: slot.motionEasing; easing.overshoot: slot.motionOvershoot }
  }
  Behavior on animatedInsetX {
    enabled: slot.motionEnabled && slot.ready
    NumberAnimation { duration: slot.motionDuration; easing.type: slot.motionEasing; easing.overshoot: slot.motionOvershoot }
  }
  Behavior on animatedInsetY {
    enabled: slot.motionEnabled && slot.ready
    NumberAnimation { duration: slot.motionDuration; easing.type: slot.motionEasing; easing.overshoot: slot.motionOvershoot }
  }
}
