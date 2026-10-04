import QtQuick
import QtQuick.Effects
import qs.Commons

// One widget drawn the way the bar draws it, from LayoutEditor.barFace: a
// saved or live image at 1:1 (redrawn in the bar's text colour when it was
// saved in another), a group's face (GroupFace), or a glyph or text in the
// bar's font. Place it at the slot's ink start (CellModel.place inkStart −
// face.inkStart); it is as tall as the bar.
Item {
  id: root
  property var face: null
  property real barThickness: Style.bar.sizeHorizontal
  property color ink: Color.popups.text
  property string fontFamily: Style.font.family
  readonly property string kind: face ? face.kind : ""
  width: kind === "image" ? face.w : kind === "group" ? groupFace.implicitWidth : kind === "text" ? text.implicitWidth : 0
  height: barThickness

  Image {
    visible: root.kind === "image"
    y: visible ? (root.barThickness - root.face.h) / 2 : 0
    width: visible ? root.face.w : 0
    height: visible ? root.face.h : 0
    source: visible ? root.face.url : ""
    smooth: true
    mipmap: true
    // An image in another theme's text colour, redrawn in the bar's own:
    // brightened to white, then coloured, keeping its shape.
    layer.enabled: visible && !!root.face.recolour
    layer.effect: MultiEffect {
      brightness: 1
      colorization: 1
      colorizationColor: root.ink
    }
  }
  GroupFace {
    id: groupFace
    visible: root.kind === "group"
    y: (root.barThickness - height) / 2
    group: visible ? root.face.group : null
    faceMode: visible ? root.face.mode : ""
    color: root.ink
    fontFamily: root.fontFamily
    fontSize: Style.font.body
  }
  Text {
    id: text
    visible: root.kind === "text"
    height: root.barThickness
    verticalAlignment: Text.AlignVCenter
    text: visible ? root.face.text : ""
    textFormat: Text.PlainText
    color: root.ink
    font.family: root.face && root.face.family || Style.font.family
    font.pixelSize: root.face && root.face.size || Style.font.body
    renderType: Text.NativeRendering
  }
}
