import QtQuick
import QtQuick.Effects

// An image, or with `tint` its shape filled with exactly `color`: a fill
// masked by the image's alpha. Brightening to white and colorizing does not
// do this: colorization keeps lightness, so a white silhouette stays white
// and vanishes on a light bar.
Item {
  id: root
  property alias source: image.source
  property alias sourceSize: image.sourceSize
  property alias fillMode: image.fillMode
  property alias asynchronous: image.asynchronous
  property alias status: image.status
  property bool tint: false
  property color color: "white"

  Image {
    id: image
    anchors.fill: parent
    visible: !root.tint
    smooth: true
    mipmap: true
    // The mask's texture while tinted.
    layer.enabled: root.tint
  }
  Rectangle {
    id: fill
    anchors.fill: parent
    visible: false
    color: root.color
    layer.enabled: root.tint
  }
  MultiEffect {
    anchors.fill: parent
    visible: root.tint
    source: fill
    maskEnabled: true
    maskSource: image
    // A ramp centred on half alpha: the shape with soft edges. (0 and 1
    // shows the whole rectangle; the defaults cut jagged edges.)
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }
}
