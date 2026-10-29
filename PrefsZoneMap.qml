import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A labelled pick-one row for the five zones, drawn as a small bar: one cell
// per zone in the proportions and order of the Layout page's columns, the
// camera between Left of center and Center when the preview has one, the
// chosen zone filled. One focus stop: h/l or Left/Right walk the cells, Space
// or Enter chooses; a click chooses at once. The caption names the zone under
// the cursor.
GridLayout {
  id: row
  property bool stacked: false
  property bool compact: false
  property string label: "Zone"
  // [{ value, label, share }] in bar order.
  property var zones: []
  property string value: ""
  // The camera sits after this zone ("" for none).
  property string cameraAfter: ""
  // Or over this zone, as the Layout page's layers draw it ("" for none).
  property string cameraOver: ""
  // A note for a zone after its name, such as where it sits by the camera.
  property var noteFor: function(zone) { return "" }
  // What fills the chosen cell (the widget's icon), or nothing.
  property Component marker: null
  signal chosen(string value)
  // A field (PREFS-133): its label, the cells xxs under it, a control tall
  // and xs apart, and xxs under them the caption; the column it stands in
  // spaces it from its neighbours.
  Layout.fillWidth: true
  columns: stacked ? 1 : 2
  columnSpacing: Gap.l
  rowSpacing: Gap.xxs

  function indexOf(zone) {
    for (var i = 0; i < zones.length; i++) if (zones[i].value === zone) return i
    return -1
  }
  readonly property int shown: map.activeFocus && map.cursor >= 0 ? map.cursor : indexOf(value)
  readonly property var shownZone: shown >= 0 ? zones[shown] : null

  InkText {
    text: row.label
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop
    elide: Text.ElideRight
  }
  ColumnLayout {
    spacing: Gap.xxs
    Item {
      id: map
      property int cursor: -1
      readonly property real cellHeight: Gap.control
      readonly property real gap: Gap.xs
      readonly property real cameraWidth: cellHeight
      readonly property bool camera: row.cameraAfter !== "" && row.indexOf(row.cameraAfter) >= 0
      readonly property real total: row.zones.reduce(function(sum, z) { return sum + z.share }, 0)
      implicitWidth: Style.space(232)
      implicitHeight: cellHeight
      activeFocusOnTab: true
      Accessible.role: Accessible.RadioButton
      Accessible.name: row.label + ": " + (row.shownZone ? row.shownZone.label : "")
      onActiveFocusChanged: cursor = activeFocus ? Math.max(0, row.indexOf(row.value)) : -1
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        var key = Util.readingKey(event, true)
        if (key === Qt.Key_Left) cursor = Math.max(0, cursor - 1)
        else if (key === Qt.Key_Right) cursor = Math.min(row.zones.length - 1, cursor + 1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          if (cursor >= 0 && row.zones[cursor].value !== row.value) row.chosen(row.zones[cursor].value)
        } else return
        event.accepted = true
      }
      // Cell n's left edge and width: shares of what the gaps and camera
      // leave. The cell mirroring the one before the camera grows by it, so
      // the map stays symmetric about its middle, as the Layout page's
      // shelves are.
      readonly property int cameraAt: camera ? row.indexOf(row.cameraAfter) : -1
      readonly property real slot: camera ? cameraWidth + gap : 0
      function widthOf(i) {
        var free = width - gap * (row.zones.length - 1) - 2 * slot
        return free * row.zones[i].share / total + (cameraAt >= 0 && i === row.zones.length - 1 - cameraAt ? slot : 0)
      }
      function span(n) {
        var x = 0
        for (var i = 0; i < n; i++) x += widthOf(i) + gap + (i === cameraAt ? slot : 0)
        return { x: x, width: widthOf(n) }
      }

      Repeater {
        model: row.zones
        BorderSurface {
          id: zoneCell
          required property var modelData
          required property int index
          readonly property bool chosen: modelData.value === row.value
          readonly property bool hot: map.activeFocus && map.cursor === index
          x: map.span(index).x
          width: map.span(index).width
          height: map.cellHeight
          radius: Round.small
          color: chosen ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent)
            : cellMouse.containsMouse ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent)
            : Qt.alpha(Commons.Color.popups.text, 0.07)
          borderSpec: hot ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
            : chosen ? Border.flat(Qt.alpha(Commons.Color.popups.text, 0.35), 1) : Border.none()
          // The camera over Center: a black tab from the cell's top edge,
          // under the cell's own border when it has one (chosen or focused),
          // so the border's line stays whole over it (PREFS-26).
          Rectangle {
            visible: row.cameraOver === zoneCell.modelData.value
            anchors.top: parent.top
            anchors.topMargin: zoneCell.borderTop
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(parent.width * 0.7)
            height: Style.space(5) - zoneCell.borderTop
            color: "black"
            bottomLeftRadius: Style.space(3)
            bottomRightRadius: Style.space(3)
          }
          Loader {
            anchors.centerIn: parent
            active: zoneCell.chosen && !!row.marker
            sourceComponent: row.marker
          }
          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              map.cursor = zoneCell.index
              if (zoneCell.modelData.value !== row.value) row.chosen(zoneCell.modelData.value)
            }
          }
        }
      }
      // The camera, as the Layout page draws it: a black square with a lens.
      Rectangle {
        visible: map.camera
        readonly property var before: map.camera ? map.span(row.indexOf(row.cameraAfter)) : ({ x: 0, width: 0 })
        x: before.x + before.width + map.gap
        width: map.cameraWidth
        height: map.cellHeight
        radius: Round.small
        color: "black"
        Rectangle {
          anchors.centerIn: parent
          width: Math.round(parent.width * 0.3)
          height: width
          radius: width / 2
          color: "#1d2433"
          border.width: 1
          border.color: "#2a3348"
        }
      }
    }
    InkText {
      Layout.preferredWidth: map.implicitWidth
      text: row.shownZone ? row.shownZone.label + (row.noteFor(row.shownZone.value) ? ", " + row.noteFor(row.shownZone.value) : "") : ""
      role: "caption"
      elide: Text.ElideRight
    }
  }
}
