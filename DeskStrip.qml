import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "PreferencesModel.js" as Model

// One strip on a desk (DeskPage; docs/behavior/preferences.md PREFS-125): a
// Layout page tile (ZoneTile: its colour, 1 px edge, radius and 6 px slab
// edge) with 8 px of padding as a Layout tile has, its title, a caption,
// then its controls 4 px apart, a footnote and its faders at the bottom, one under the other. The
// camera's torn cap and its shade fall over its surface where the camera's
// column crosses it, continuing what the gaps show. The desk places it and gives every
// strip the tallest one's height. Its lift says the cursor is in it, as a
// tile's does on the Layout page; no outline.
ZoneTile {
  id: strip
  readonly property bool isDeskStrip: true
  property string title: ""
  property string caption: ""
  property string footnote: ""
  // The controls, top to bottom; the faders go at the bottom.
  default property alias content: body.data
  property alias faders: faderColumn.data
  // Set by the desk.
  property Item desk: null
  readonly property real padding: Style.space(8)
  readonly property bool holdsCursor: {
    for (var p = strip.Window.activeFocusItem; p; p = p.parent)
      if (p === strip)
        return true;
    return false;
  }
  // The controls the cursor can rest on, in reading order.
  readonly property var controls: {
    var list = [];
    var kids = body.children;
    for (var i = 0; i < kids.length; i++) {
      if (kids[i].deskGroup === true && kids[i].visible) {
        var rows = kids[i].controls;
        for (var r = 0; r < rows.length; r++)
          if (rows[r].deskStops !== undefined && rows[r].visible && rows[r].enabled)
            list.push(rows[r]);
      } else if (kids[i].deskStops !== undefined && kids[i].visible && kids[i].enabled)
        list.push(kids[i]);
    }
    kids = faderColumn.children;
    for (var j = 0; j < kids.length; j++)
      if (kids[j].deskStops !== undefined && kids[j].visible && kids[j].enabled)
        list.push(kids[j]);
    return list;
  }
  readonly property real naturalHeight: column.implicitHeight + 2 * padding
  readonly property var box: desk ? desk.boxOf(strip) : null
  x: box ? box.x : 0
  width: box ? box.width : 0
  height: desk ? desk.stripHeight : naturalHeight

  pad: padding
  nameShown: false
  animate: !!desk && desk.animate
  lightTheme: !!desk && desk.lightTheme
  current: holdsCursor
  borderSpec: Border.flat(Qt.alpha(Commons.Color.popups.text, 0.12), 1)
  Accessible.role: Accessible.Grouping
  Accessible.name: title

  // The camera's cap and shade over the part of the strip under the
  // camera's column: the column's whole width, cut to the strip.
  // The shade past the column's sides (Tuning's shadeSpread), on every
  // strip it reaches, cut to the strip.
  Item {
    id: spillClip
    readonly property real reach: Tuning.values.shadeSpread * Style.space(1)
    visible: !!strip.desk && strip.desk.cameraShown && reach > 0 && beamClip.beamEnd + reach > 0 && beamClip.beamStart - reach < strip.width
    anchors.fill: parent
    clip: true
    BeamShade {
      readonly property Item camera: strip.desk ? strip.desk.camera : null
      spill: 1
      outer: spillClip.reach
      colWidth: strip.desk ? strip.desk.beamWidth : 0
      tilt: strip.desk ? strip.desk.tilt : 34
      planeDistance: strip.desk ? strip.desk.planeDistance : 1600
      lightTheme: camera ? camera.lightTheme : false
      x: beamClip.beamStart - spillClip.reach
      width: colWidth + 2 * spillClip.reach
      height: parent.height
      vTop: strip.desk ? Model.tiltedDepth(strip.desk.seenTop - strip.desk.line, strip.desk.tilt, strip.desk.planeDistance) : 0
      vBottom: strip.desk ? Model.tiltedDepth(strip.desk.seenTop + Model.tiltedHeight(strip.height, strip.desk.tilt, strip.desk.planeDistance) - strip.desk.line, strip.desk.tilt, strip.desk.planeDistance) : 0
    }
  }
  Item {
    id: beamClip
    readonly property real beamStart: strip.desk ? strip.desk.beamLeft - strip.x : 0
    readonly property real beamEnd: strip.desk ? beamStart + strip.desk.beamWidth : 0
    visible: !!strip.desk && strip.desk.cameraShown && beamEnd > 0 && beamStart < strip.width
    anchors.fill: parent
    clip: true
    BeamShade {
      readonly property Item camera: strip.desk ? strip.desk.camera : null
      tilt: strip.desk ? strip.desk.tilt : 34
      planeDistance: strip.desk ? strip.desk.planeDistance : 1600
      lightTheme: camera ? camera.lightTheme : false
      x: beamClip.beamStart
      width: strip.desk ? strip.desk.beamWidth : 0
      height: parent.height
      vTop: strip.desk ? Model.tiltedDepth(strip.desk.seenTop - strip.desk.line, strip.desk.tilt, strip.desk.planeDistance) : 0
      vBottom: strip.desk ? Model.tiltedDepth(strip.desk.seenTop + Model.tiltedHeight(strip.height, strip.desk.tilt, strip.desk.planeDistance) - strip.desk.line, strip.desk.tilt, strip.desk.planeDistance) : 0
    }
  }

  ColumnLayout {
    id: column
    x: strip.padding
    y: strip.padding
    width: strip.width - 2 * strip.padding
    height: Math.max(implicitHeight, strip.height - 2 * strip.padding)
    spacing: Style.space(8)
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(2)
      GrayText {
        Layout.fillWidth: true
        text: strip.title
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
      GrayText {
        visible: strip.caption !== ""
        Layout.fillWidth: true
        text: strip.caption
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
    }
    ColumnLayout {
      id: body
      Layout.fillWidth: true
      spacing: Style.space(4)
    }
    Item {
      Layout.fillHeight: true
    }
    GrayText {
      visible: strip.footnote !== ""
      Layout.fillWidth: true
      text: strip.footnote
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
    // Flat, each the strip's inner width, one under the other.
    ColumnLayout {
      id: faderColumn
      Layout.fillWidth: true
      visible: children.length > 0
      spacing: Style.space(8)
    }
  }
}
