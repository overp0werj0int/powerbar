import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Three small screens, one per bar style, drawn with the current wallpaper,
// bar colors, rounding and edge. One focus stop: h/l or Left/Right walk the
// styles, Space or Enter picks one.
RowLayout {
  id: picker
  required property var bar
  property string wallpaper: ""
  readonly property string value: bar ? bar.barStyle : "flat"
  readonly property var styles: [
    { value: "flat", label: "Flat", hint: "Edge to edge, like Omarchy" },
    { value: "floating", label: "Floating", hint: "One bar, off the edges" },
    { value: "islands", label: "Islands", hint: "A surface for each zone" }
  ]
  property int cursor: 0
  signal chosen(string value)
  readonly property string miniEdge: bar && (bar.position === "bottom" || bar.position === "right") ? "bottom" : "top"
  function indexOfValue() { return Math.max(0, styles.findIndex(function(s) { return s.value === picker.value })) }

  spacing: Style.space(12)
  activeFocusOnTab: true
  Accessible.role: Accessible.List
  Accessible.name: "Bar style"
  Accessible.description: styles[cursor].label
  onActiveFocusChanged: if (activeFocus) cursor = indexOfValue()
  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
    if (event.key === Qt.Key_Left || event.text === "h") cursor = Math.max(0, cursor - 1)
    else if (event.key === Qt.Key_Right || event.text === "l") cursor = Math.min(styles.length - 1, cursor + 1)
    else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) picker.chosen(styles[cursor].value)
    else return
    event.accepted = true
  }

  Repeater {
    model: picker.styles
    ColumnLayout {
      id: option
      required property var modelData
      required property int index
      readonly property bool selected: modelData.value === picker.value
      readonly property bool isCursor: picker.activeFocus && picker.cursor === index
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      spacing: Style.space(8)

      BorderSurface {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(92)
        radius: Math.max(Style.cornerRadius, Style.space(6)) + Style.space(3)
        color: option.isCursor ? Style.focusFillFor(Color.popups.text, Color.accent)
          : hover.hovered ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
        borderSpec: option.selected ? Border.flat(Color.accent, Math.max(1, Style.space(2)))
          : Border.flat(Qt.alpha(Color.popups.text, 0.12), 1)
        HoverHandler { id: hover }

        BarBackdrop {

          motionEnabled: !picker.bar || picker.bar.animationsEnabled
          id: screen
          anchors.fill: parent
          anchors.margins: Style.space(4)
          source: picker.wallpaper
          position: picker.miniEdge
          MiniBar { anchors.fill: parent; style: option.modelData.value }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { picker.cursor = option.index; picker.forceActiveFocus(Qt.MouseFocusReason); picker.chosen(option.modelData.value) }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          text: option.modelData.label
          textFormat: Text.PlainText
          color: option.selected ? Color.popups.text : Qt.alpha(Color.popups.text, 0.8)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: option.selected
        }
        Text {
          text: option.modelData.hint
          textFormat: Text.PlainText
          color: Qt.alpha(Color.popups.text, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }
  }

  // A bar schematic in one style. Shapes are laid out along the bar and across
  // it from the screen edge, then turned to whichever edge the bar uses.
  component MiniBar: Item {
    id: mini
    property string style: "flat"
    // Always a horizontal bar, like every Preferences preview; a side bar is
    // shown along the top or bottom.
    readonly property bool vertical: false
    readonly property string edge: picker.bar && (picker.bar.position === "bottom" || picker.bar.position === "right") ? "bottom" : "top"
    readonly property real along: vertical ? height : width
    readonly property real thick: Style.space(12)
    readonly property real gap: style === "flat" ? 0 : Style.space(3)
    readonly property real round: style === "flat" ? 0 : Math.min(thick / 2, (picker.bar ? picker.bar.islandRounding : 0) * 0.5)
    readonly property var surfaces: style === "islands" ? [
      { a: gap, l: along * 0.3 }, { a: (along - along * 0.24) / 2, l: along * 0.24 }, { a: along - gap - along * 0.28, l: along * 0.28 }
    ] : [{ a: gap, l: along - gap * 2 }]
    readonly property var marks: [
      { a: gap + Style.space(6), l: Style.space(3) }, { a: gap + Style.space(12), l: Style.space(3) }, { a: gap + Style.space(18), l: Style.space(3) },
      { a: (along - along * 0.12) / 2, l: along * 0.12 },
      { a: along - gap - Style.space(21), l: Style.space(3) }, { a: along - gap - Style.space(15), l: Style.space(3) }, { a: along - gap - Style.space(9), l: Style.space(3) }
    ]
    // Along/across coordinates to item geometry for the bar's edge.
    function px(a, c, t) { return !vertical ? a : edge === "right" ? width - c - t : c }
    function py(a, c, t) { return vertical ? a : edge === "bottom" ? height - c - t : c }
    function pw(l, t) { return vertical ? t : l }
    function ph(l, t) { return vertical ? l : t }
    readonly property real markThick: Style.space(3)
    readonly property real markCross: gap + (thick - markThick) / 2

    Repeater {
      model: mini.surfaces
      BorderSurface {
        required property var modelData
        x: mini.px(modelData.a, mini.gap, mini.thick)
        y: mini.py(modelData.a, mini.gap, mini.thick)
        width: mini.pw(modelData.l, mini.thick)
        height: mini.ph(modelData.l, mini.thick)
        color: picker.bar ? picker.bar.mainSurfaceColor : "transparent"
        radius: mini.round
        borderSpec: mini.style === "flat" || !picker.bar ? Border.none() : picker.bar.islandBorder
      }
    }
    Repeater {
      model: mini.marks
      Rectangle {
        required property var modelData
        x: mini.px(modelData.a, mini.markCross, mini.markThick)
        y: mini.py(modelData.a, mini.markCross, mini.markThick)
        width: mini.pw(modelData.l, mini.markThick)
        height: mini.ph(modelData.l, mini.markThick)
        radius: Style.space(2)
        color: picker.bar ? Qt.alpha(picker.bar.barForeground, 0.85) : Color.popups.text
      }
    }
  }
}
