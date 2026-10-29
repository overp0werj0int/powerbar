import QtQuick
import QtQuick.Layouts
import qs.Commons

// A group of pick rows on a desk strip (docs/behavior/preferences.md
// PREFS-129): the rows one under the other, 10 px apart as the strip lays
// its controls, lifting together as one plate when the cursor is on any of
// them, the cursor's row keeping its fill and ring. The desk walks the rows
// as it walks any control (DeskStrip.controls looks inside).
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
    radius: Math.max(0, Math.min(Style.space(5), Style.cornerRadius - Style.space(3)))
    plate: group.strip ? group.strip.surfaceColor : "transparent"
    // As far as a row's surface reaches into the strip's padding.
    padX: Style.space(8)
  }
  transform: Translate { y: -lift.raise }
  scale: lift.grown
  z: lift.raised ? 1 : 0
  ColumnLayout {
    id: column
    readonly property bool deskGroupBody: true
    anchors.fill: parent
    spacing: Style.space(10)
  }
}
