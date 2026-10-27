import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "CameraLookModel.js" as Model

// A temporary pane on the Look page (docs/behavior/preferences.md
// PREFS-132) for tuning the camera's torn cap live: a strip-look card at the
// page's bottom right with a fader for each of CameraLook's twelve numbers
// in two columns, and the file they are saved to. It goes once the look is
// set. Its faders apply as they move; it is not in the desk's walk and the
// legend leaves it out.
ZoneTile {
  id: pane
  required property Item desk
  readonly property real padding: Style.space(12)
  readonly property real columnWidth: Style.space(300)
  readonly property real columnGap: Style.space(24)
  // Its gaps, shrunk when the page is too short to keep it off the desk.
  readonly property real rowGap: place.compact ? Style.space(4) : Style.space(10)
  readonly property real sectionGap: place.compact ? Style.space(6) : Style.space(10)
  function heightWith(row, section) {
    return 2 * padding + head.implicitHeight + section + 6 * probe.implicitHeight + 5 * row + section + pathText.implicitHeight;
  }
  readonly property var place: Model.panePlace(desk.height, desk.seenBottom, heightWith(Style.space(10), Style.space(10)), heightWith(Style.space(4), Style.space(6)), Style.space(8), Style.space(12))
  // Under the plate's near right corner.
  x: desk.seenRight - width
  y: place.y
  width: 2 * columnWidth + columnGap + 2 * padding
  height: heightWith(rowGap, sectionGap)
  pad: padding
  nameShown: false
  animate: desk.animate
  lightTheme: desk.lightTheme
  Accessible.role: Accessible.Grouping
  Accessible.name: "Camera tear (temporary)"

  // A fader's height, for the pane's own.
  Fader {
    id: probe
    visible: false
    label: "x"
  }

  component TearFader: Fader {
    required property var modelData
    label: modelData.label
    unit: modelData.unit
    minimum: modelData.min
    maximum: modelData.max
    stepSize: 1
    defaultValue: modelData.value
    value: CameraLook[modelData.key]
    animate: pane.desk.animate
    formatter: function (v) {
      return modelData.key === "octaves" && v === 1 ? "1 octave" : "";
    }
    // Live: the cap follows the drag, and the file is written once it rests.
    onDrafted: function (v) {
      if (!isNaN(v))
        CameraLook.set(modelData.key, v);
    }
    onEdited: function (v) {
      CameraLook.set(modelData.key, v);
    }
  }

  Column {
    x: pane.padding
    y: pane.padding
    width: pane.width - 2 * pane.padding
    spacing: pane.sectionGap
    Column {
      id: head
      width: parent.width
      spacing: Style.space(4)
      Text {
        width: parent.width
        text: "Camera tear (temporary)"
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: "Tuning the torn edge. This pane goes once the look is set."
        textFormat: Text.PlainText
        color: Qt.alpha(Commons.Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
    Row {
      spacing: pane.columnGap
      ColumnLayout {
        width: pane.columnWidth
        spacing: pane.rowGap
        Repeater {
          model: CameraLook.params.slice(0, 6)
          TearFader {}
        }
      }
      ColumnLayout {
        width: pane.columnWidth
        spacing: pane.rowGap
        Repeater {
          model: CameraLook.params.slice(6)
          TearFader {}
        }
      }
    }
    Text {
      id: pathText
      width: parent.width
      text: CameraLook.path
      textFormat: Text.PlainText
      color: Qt.alpha(Commons.Color.popups.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideMiddle
    }
  }
}
