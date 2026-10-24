import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import "NotchModel.js" as NotchModel

// A floating bar on the notched screen (appearance.md LOOK-147): the surface,
// its border and its shadow follow one outline, which dips round the camera
// (NotchModel.wrapCut) and takes the screen's corners at the top
// (NotchModel.outerCorners). An EffectSurface everywhere else.
Item {
  id: surface
  property color color: "transparent"
  property var borderSpec: Border.none()
  property bool shadowEnabled: false
  property real shadowSize: 16
  property real shadowOpacity: 0.3
  // Corner radii, and the cut (wrapCut) or null.
  property real topRadius: 0
  property real bottomRadius: 0
  property var cut: null

  readonly property real borderWidth: Border.isNone(borderSpec) ? 0 : Border.top(borderSpec)
  function outline(inset, offset) {
    return NotchModel.wrapOutline({ width: width, height: height, tl: topRadius, tr: topRadius, bl: bottomRadius, br: bottomRadius,
      cut: cut, inset: inset, x: offset, y: offset })
  }

  // The shadow: the outline in black, blurred, under the surface. Drawn with
  // room round it, since the blur spreads past the outline.
  Item {
    readonly property real pad: Math.ceil(surface.shadowSize) + 2
    visible: surface.shadowEnabled && surface.width > 0
    z: -1
    x: -pad; y: -pad
    width: surface.width + pad * 2
    height: surface.height + pad * 2
    opacity: surface.shadowOpacity
    layer.enabled: visible
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1
      blurMax: Math.max(1, Math.round(surface.shadowSize))
    }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: "black"
        strokeColor: "transparent"
        PathSvg { path: surface.outline(0, Math.ceil(surface.shadowSize) + 2) }
      }
    }
  }
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: surface.color
      strokeColor: "transparent"
      PathSvg { path: surface.outline(0, 0) }
    }
    // The border: the ring between the outline and the same outline its
    // width inside.
    ShapePath {
      fillColor: surface.borderWidth > 0 ? Border.color(surface.borderSpec) : "transparent"
      fillRule: ShapePath.OddEvenFill
      strokeColor: "transparent"
      PathSvg { path: surface.borderWidth > 0 ? surface.outline(0, 0) + " " + surface.outline(surface.borderWidth, 0) : "" }
    }
  }
}
