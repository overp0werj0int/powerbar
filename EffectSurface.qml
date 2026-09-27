import QtQuick
import QtQuick.Effects
import qs.Ui

// Shadows are painted locally, so each zone can have its own shape. Backdrop
// blur is supplied by Hyprland only under the translucent surface fill.
BorderSurface {
  id: surface
  property bool shadowEnabled: false
  property real shadowSize: 16
  property real shadowOpacity: 0.3
  property real surfaceScale: 1

  RectangularShadow {
    anchors.fill: parent
    z: -1
    visible: surface.shadowEnabled
    radius: surface.radius
    blur: surface.shadowSize / surface.surfaceScale
    color: Qt.rgba(0, 0, 0, surface.shadowOpacity)
  }
}
