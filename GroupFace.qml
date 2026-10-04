import QtQuick
import QtQuick.Window
import QtQuick.Effects
import qs.Commons
import "GroupsModel.js" as Groups

// A group's face drawn as runs (GroupsModel.faceRuns): its icon, a glyph in
// its own font or your own image, then for "both" the name in the bar's font.
// The bar's text button can only draw one string in one font, so the bar uses
// this for faces that need it (GroupsModel.needsRuns), and Preferences uses it
// for every group face it draws.
Row {
  id: root
  property var group: null
  // "glyph", "text" or "both"; empty draws the group's own setting.
  property string faceMode: ""
  property color color: Color.popups.text
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  // Your own image fits this square: the bar's glyph size (CellModel.GLYPH_INK).
  property real imageSize: 16
  readonly property var runs: Groups.faceRuns(group, faceMode)
  // Along the row: the span the runs draw (images whole, text by advance).
  readonly property real paintedWidth: implicitWidth
  spacing: 0

  Repeater {
    model: root.runs
    Item {
      id: run
      required property var modelData
      readonly property bool image: modelData.kind === "image"
      implicitWidth: image ? root.imageSize : runText.implicitWidth
      implicitHeight: image ? root.imageSize : runText.implicitHeight
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      Text {
        id: runText
        visible: !run.image
        text: run.image ? "" : run.modelData.text
        textFormat: Text.PlainText
        color: root.color
        font.family: run.modelData.font || root.fontFamily
        font.pixelSize: root.fontSize
        renderType: Text.NativeRendering
      }
      Image {
        visible: run.image
        anchors.fill: parent
        source: run.image ? (String(run.modelData.source).indexOf("/") === 0 ? "file://" : "") + run.modelData.source : ""
        sourceSize: Qt.size(root.imageSize * Screen.devicePixelRatio * 2, root.imageSize * Screen.devicePixelRatio * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
        // Text colour: the image's shape filled with the text colour, like
        // the bar's own icons. Its own colours: drawn as it is.
        layer.enabled: visible && run.modelData.tint === true
        layer.effect: MultiEffect {
          brightness: 1
          colorization: 1
          colorizationColor: root.color
        }
      }
    }
  }
}
