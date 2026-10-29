import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A group of pick rows on a desk strip (docs/behavior/preferences.md
// PREFS-129): the rows one under the other, 10 px apart as the strip lays
// its controls, lifting together as one plate when the cursor is on any of
// them. With the cursor in it the group's area takes the focus fill and the
// ring as a switch row's does, the cursor's row the selected fill over it;
// with Tuning's Mark the whole control off, only the cursor's pick mark is
// ringed.
// The desk walks the rows as it walks any control (DeskStrip.controls looks
// inside).
Item {
  id: group
  readonly property bool deskGroup: true
  default property alias rows: column.data
  // The rows the desk can walk.
  readonly property var controls: column.children
  readonly property bool holdsCursor: {
    var kids = column.children
    for (var i = 0; i < kids.length; i++)
      if (kids[i].activeFocus)
        return true
    return false
  }
  readonly property Item strip: {
    for (var p = parent; p; p = p.parent)
      if (p.isDeskStrip)
        return p
    return null
  }
  Layout.fillWidth: true
  implicitWidth: column.implicitWidth
  implicitHeight: column.implicitHeight
  CursorLift {
    id: lift
    up: group.holdsCursor
    animate: group.strip && group.strip.desk ? group.strip.desk.animate : true
    lightTheme: group.strip ? group.strip.lightTheme : false
    radius: group.radius
    plate: group.strip ? group.strip.surfaceColor : "transparent"
    // As far as a row's surface reaches into the strip's padding.
    padX: Style.space(4)
  }
  readonly property real radius: Math.max(0, Math.min(Style.space(5), Style.cornerRadius - Style.space(3)))
  // Tuning's Mark the whole control (PREFS-132), on by default: the group's
  // area takes the focus fill and ring as a switch row does; off, only the
  // cursor's pick mark takes the ring (DeskRow).
  readonly property bool marked: holdsCursor && Tuning.values.areaRing !== 0
  // The fill, under the rows.
  Rectangle {
    visible: group.marked
    anchors.fill: parent
    anchors.leftMargin: -Style.space(4)
    anchors.rightMargin: -Style.space(4)
    radius: group.radius
    antialiasing: true
    color: Qt.tint(group.strip ? group.strip.surfaceColor : "transparent", Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent))
  }
  transform: Translate { y: -lift.raise }
  scale: lift.grown
  z: lift.raised ? 1 : 0
  ColumnLayout {
    id: column
    readonly property bool deskGroupBody: true
    anchors.fill: parent
    spacing: Style.space(3)
  }
  // The ring, over the rows' fills, as far out as the plate.
  BorderSurface {
    anchors.fill: parent
    anchors.leftMargin: -Style.space(4)
    anchors.rightMargin: -Style.space(4)
    radius: group.radius
    color: "transparent"
    borderSpec: group.marked ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
  }
}
