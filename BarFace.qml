import QtQuick
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

  // An image saved in another theme's text colour is redrawn in the bar's
  // own: its shape filled with the text colour.
  TintedImage {
    visible: root.kind === "image"
    // Bound to the face, never to `visible`: that turns false whenever the
    // page is hidden, and an image unloaded then may not load again.
    y: root.kind === "image" ? (root.barThickness - root.face.h) / 2 : 0
    width: root.kind === "image" ? root.face.w : 0
    height: root.kind === "image" ? root.face.h : 0
    source: root.kind === "image" ? root.face.url : ""
    tint: root.kind === "image" && !!root.face.recolour
    color: root.ink
  }
  GroupFace {
    id: groupFace
    visible: root.kind === "group"
    y: (root.barThickness - height) / 2
    group: root.kind === "group" ? root.face.group : null
    faceMode: root.kind === "group" ? root.face.mode : ""
    color: root.ink
    fontFamily: root.fontFamily
    fontSize: Style.font.body
  }
  Text {
    id: text
    visible: root.kind === "text"
    height: root.barThickness
    verticalAlignment: Text.AlignVCenter
    text: root.kind === "text" ? root.face.text : ""
    textFormat: Text.PlainText
    color: root.ink
    font.family: root.face && root.face.family || Style.font.family
    font.pixelSize: root.face && root.face.size || Style.font.body
    renderType: Text.NativeRendering
  }
}
