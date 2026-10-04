import QtQuick
import qs.Commons
import qs.Ui

// Your screen in miniature: the wallpaper, and the bar drawn in its style on
// its edge. Click another edge to move the bar there; the chips beside it are
// the keyboard path, so the picture takes no focus.
BarBackdrop {
  id: screen
  required property var bar
  property real aspect: 16 / 10
  signal edgeChosen(string edge)

  readonly property string edge: bar ? bar.position : "top"
  readonly property string style: bar ? bar.barStyle : "flat"
  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property real thick: Style.space(12)
  readonly property real gap: style === "flat" ? 0 : Style.space(3)
  readonly property real round: style === "flat" ? 0 : Math.min(thick / 2, (bar ? bar.islandRounding : 0) * 0.5)
  readonly property real along: vertical ? height : width
  // Surfaces and icon marks along the bar, as fractions of its length.
  readonly property var surfaces: style === "islands" ? [
    { a: gap, l: along * 0.3 }, { a: (along - along * 0.24) / 2, l: along * 0.24 }, { a: along - gap - along * 0.28, l: along * 0.28 }
  ] : [{ a: gap, l: along - gap * 2 }]
  readonly property real mark: Style.space(3)
  readonly property var marks: [
    { a: gap + Style.space(6), l: mark }, { a: gap + Style.space(12), l: mark }, { a: gap + Style.space(18), l: mark },
    { a: (along - along * 0.12) / 2, l: along * 0.12 },
    { a: along - gap - Style.space(21), l: mark }, { a: along - gap - Style.space(15), l: mark }, { a: along - gap - Style.space(9), l: mark }
  ]
  // Along/across the bar to item geometry for its edge.
  function px(a, c, t) { return !vertical ? a : edge === "right" ? width - c - t : c }
  function py(a, c, t) { return vertical ? a : edge === "bottom" ? height - c - t : c }
  function pw(l, t) { return vertical ? t : l }
  function ph(l, t) { return vertical ? l : t }

  implicitWidth: Style.space(300)
  implicitHeight: Math.round(implicitWidth / aspect)
  radius: Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2))
  source: ""
  position: "top"
  motionEnabled: !bar || bar.animationsEnabled

  Repeater {
    model: screen.surfaces
    BorderSurface {
      required property var modelData
      x: screen.px(modelData.a, screen.gap, screen.thick)
      y: screen.py(modelData.a, screen.gap, screen.thick)
      width: screen.pw(modelData.l, screen.thick)
      height: screen.ph(modelData.l, screen.thick)
      color: screen.bar ? screen.bar.mainSurfaceColor : "transparent"
      radius: screen.round
      borderSpec: screen.style === "flat" || !screen.bar ? Border.none() : screen.bar.islandBorder
    }
  }
  Repeater {
    model: screen.marks
    Rectangle {
      required property var modelData
      readonly property real cross: screen.gap + (screen.thick - screen.mark) / 2
      x: screen.px(modelData.a, cross, screen.mark)
      y: screen.py(modelData.a, cross, screen.mark)
      width: screen.pw(modelData.l, screen.mark)
      height: screen.ph(modelData.l, screen.mark)
      radius: Style.space(2)
      color: screen.bar ? Qt.alpha(screen.bar.barForeground, 0.85) : Color.popups.text
    }
  }
  // The other edges: a handle each, centred on the edge and half its length,
  // so it stays clear of the bar at the corners. An outline in the window's
  // background keeps it visible on light and dark wallpapers alike.
  Repeater {
    model: ["top", "right", "bottom", "left"]
    Rectangle {
      id: handle
      required property string modelData
      readonly property bool horizontal: modelData === "top" || modelData === "bottom"
      readonly property real inset: Style.space(4)
      readonly property real thickness: Math.max(5, Style.space(6))
      readonly property real length: (horizontal ? screen.width : screen.height) * 0.5
      visible: modelData !== screen.edge
      x: horizontal ? (screen.width - length) / 2 : modelData === "left" ? inset : screen.width - inset - width
      y: !horizontal ? (screen.height - length) / 2 : modelData === "top" ? inset : screen.height - inset - height
      width: horizontal ? length : thickness
      height: horizontal ? thickness : length
      radius: thickness / 2
      color: Qt.alpha(Color.popups.text, hit.containsMouse ? 0.95 : 0.55)
      border.width: Math.max(1, Style.space(1))
      border.color: Color.popups.background
      Behavior on color { enabled: screen.motionEnabled; ColorAnimation { duration: 100 } }
      MouseArea {
        id: hit
        // A grab area well beyond the thin handle.
        anchors.fill: parent
        anchors.margins: -Style.space(8)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: screen.edgeChosen(handle.modelData)
      }
    }
  }
}
