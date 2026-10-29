import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A row of chips on a desk strip (docs/behavior/preferences.md PREFS-128):
// the chips share the strip by their labels, the chosen one in the selected
// look, the cursor's chip with the focus fill and ring (the Layout chip's). Every chip is a stop of its
// own: the desk's h/l walk them and go on past the row's ends to the same
// row of the next strip, Space or Enter chooses, a click chooses.
Item {
  id: choice
  // [{ value, label }]
  property var options: []
  property string value: ""
  signal chosen(string value)

  readonly property int chosenIndex: options.findIndex(function (o) {
    return o.value === value;
  })
  // The chip the cursor is on, -1 while it is elsewhere.
  property int cursor: -1
  readonly property int deskStops: Math.max(1, options.length)
  readonly property int deskHome: Math.max(0, chosenIndex)
  readonly property int deskStop: Math.max(0, cursor)
  function deskFocus(stop, reason) {
    cursor = stop;
    forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
  }
  readonly property var keyHints: [
    {
      keys: "h l",
      label: "Chip to chip, then the next strip"
    },
    {
      keys: "space",
      label: "Choose it"
    }
  ]
  onActiveFocusChanged: if (!activeFocus)
    cursor = -1
  else if (cursor < 0)
    cursor = Math.max(0, chosenIndex)

  // With the cursor the row lifts as one, as a desk row does (PREFS-104,
  // PREFS-129), on a plate of the strip's colour.
  readonly property Item strip: {
    for (var p = parent; p; p = p.parent)
      if (p.isDeskStrip)
        return p;
    return null;
  }
  CursorLift {
    id: lift
    up: choice.activeFocus
    animate: choice.strip && choice.strip.desk ? choice.strip.desk.animate : true
    lightTheme: choice.strip ? choice.strip.lightTheme : false
    radius: Round.control
    plate: choice.strip ? choice.strip.surfaceColor : "transparent"
    padX: choice.padX
    padY: choice.padY
  }
  // As far as a row's surface reaches: into the strip's padding along, and
  // a row's padding above and below.
  readonly property real padX: Gap.s
  readonly property real padY: Gap.xs
  // Tuning's Mark the whole control (PREFS-132), on by default: the row of
  // chips' area takes the focus fill and ring as a switch row does, the
  // cursor's chip keeping its own; off, only the cursor's chip is marked.
  BorderSurface {
    visible: choice.activeFocus && Tuning.values.areaRing !== 0
    anchors.fill: parent
    anchors.leftMargin: -choice.padX
    anchors.rightMargin: -choice.padX
    anchors.topMargin: -choice.padY
    anchors.bottomMargin: -choice.padY
    radius: Round.control
    color: Qt.tint(choice.strip ? choice.strip.surfaceColor : "transparent", Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent))
    borderSpec: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent)
  }
  transform: Translate {
    y: -lift.raise
  }
  scale: lift.grown
  z: lift.raised ? 1 : 0
  Layout.fillWidth: true
  implicitWidth: chips.implicitWidth
  implicitHeight: chips.implicitHeight
  opacity: enabled ? 1 : Ink.disabled
  activeFocusOnTab: false
  Accessible.role: Accessible.RadioButton

  function choose(i) {
    if (i >= 0 && i < options.length)
      chosen(options[i].value);
  }
  Keys.onPressed: function (event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      return;
    if (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
      return;
    choose(cursor);
    event.accepted = true;
  }

  // The chips' labels measured at the label and caption sizes: while they
  // fit whole at the label size the chips take it; else (a large base size
  // on a narrow strip) the caption size, and then xs of side padding, so no
  // label is cut while one can be kept whole (PREFS-133).
  Row {
    id: labelProbe
    visible: false
    Repeater {
      model: choice.options
      InkText {
        required property var modelData
        text: modelData.label
      }
    }
  }
  Row {
    id: captionProbe
    visible: false
    Repeater {
      model: choice.options
      InkText {
        required property var modelData
        role: "caption"
        text: modelData.label
      }
    }
  }
  function need(textWidth, pad) {
    return textWidth + options.length * 2 * (pad + 1) + Math.max(0, options.length - 1) * Gap.xs;
  }
  readonly property bool labelFits: need(labelProbe.implicitWidth, Gap.s) <= width
  readonly property int chipFont: labelFits ? Ink.label : Ink.caption
  readonly property real chipPad: labelFits || need(captionProbe.implicitWidth, Gap.s) <= width ? Gap.s : Gap.xs
  RowLayout {
    id: chips
    anchors.fill: parent
    spacing: Gap.xs
    Repeater {
      model: choice.options
      Button {
        id: chip
        required property var modelData
        required property int index
        readonly property bool cursorHere: choice.activeFocus && index === choice.cursor
        Layout.fillWidth: true
        // The chips share the strip by their labels, so "Everywhere" fits.
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: Gap.control
        text: modelData.label
        selected: index === choice.chosenIndex
        bordered: true
        foreground: Commons.Color.popups.text
        background: "transparent"
        // Desk chips (PREFS-133): the label size, xs × s of padding, xs apart.
        fontSize: choice.chipFont
        verticalPadding: Gap.xs
        horizontalPadding: choice.chipPad
        onClicked: {
          choice.cursor = index;
          choice.forceActiveFocus(Qt.MouseFocusReason);
          choice.chosen(modelData.value);
        }
        // The cursor's focus fill and ring.
        Rectangle {
          anchors.fill: parent
          visible: chip.cursorHere
          color: Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent)
          radius: chip.radius
          border.width: 1
          border.color: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent).color
          antialiasing: true
        }
      }
    }
  }
}
