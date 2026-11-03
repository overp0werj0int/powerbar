import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A labelled pick-one row for the five zones, drawn as a small bar: one cell
// per zone in the proportions and order of the Layout page's columns, the
// camera over Center when the preview has one, the chosen zone filled. On a
// desk strip (DeskStrip) every cell is a stop, as a row of chips' are
// (DeskChoice): the desk's h/l walk them and go on past the ends, Space or
// Enter chooses; a click chooses at once. The caption names the zone under
// the cursor.
ColumnLayout {
  id: row
  // [{ value, label, share }] in bar order.
  property var zones: []
  property string value: ""
  // The camera over this zone, as the Layout page's layers draw it ("" for none).
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
  spacing: Gap.xxs

  function indexOf(zone) {
    for (var i = 0; i < zones.length; i++) if (zones[i].value === zone) return i
    return -1
  }
  // On a desk: a stop per zone, the chosen one home.
  readonly property int deskStops: Math.max(1, zones.length)
  readonly property int deskHome: Math.max(0, indexOf(value))
  readonly property int deskStop: Math.max(0, map.cursor)
  function deskFocus(stop, reason) {
    map.cursor = stop
    map.forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason)
  }
  readonly property var keyHints: [{ keys: "space", label: "Move it to that zone" }]
  readonly property int shown: map.activeFocus && map.cursor >= 0 ? map.cursor : indexOf(value)
  readonly property var shownZone: shown >= 0 ? zones[shown] : null

  InkText {
    text: "Zone"
    Layout.fillWidth: true
    elide: Text.ElideRight
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Gap.xxs
    Item {
      id: map
      property int cursor: -1
      readonly property real cellHeight: Gap.control
      readonly property real gap: Gap.xs
      readonly property real total: row.zones.reduce(function(sum, z) { return sum + z.share }, 0)
      Layout.fillWidth: true
      implicitHeight: cellHeight
      activeFocusOnTab: false
      Accessible.role: Accessible.RadioButton
      Accessible.name: "Zone: " + (row.shownZone ? row.shownZone.label : "")
      onActiveFocusChanged: if (!activeFocus) cursor = -1
        else if (cursor < 0) cursor = Math.max(0, row.indexOf(row.value))
      Keys.onPressed: function(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return
        if (cursor >= 0 && row.zones[cursor].value !== row.value) row.chosen(row.zones[cursor].value)
        event.accepted = true
      }
      // Cell n's left edge and width: shares of what the gaps leave.
      function widthOf(i) {
        return (width - gap * (row.zones.length - 1)) * row.zones[i].share / total
      }
      function span(n) {
        var x = 0
        for (var i = 0; i < n; i++) x += widthOf(i) + gap
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
          color: hot ? Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)
            : chosen ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent)
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
              row.deskFocus(zoneCell.index, Qt.MouseFocusReason)
              if (zoneCell.modelData.value !== row.value) row.chosen(zoneCell.modelData.value)
            }
          }
        }
      }
    }
    InkText {
      Layout.fillWidth: true
      text: row.shownZone ? row.shownZone.label + (row.noteFor(row.shownZone.value) ? ", " + row.noteFor(row.shownZone.value) : "") : ""
      role: "caption"
      elide: Text.ElideRight
    }
  }
}
