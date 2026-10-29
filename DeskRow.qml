import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A row on a desk strip (docs/behavior/preferences.md PREFS-129): its label
// with an optional one-line caption under it (without one the row is its
// label's line), and a switch at its right, or, for a pick-one row (`pick`),
// a 14 px ring before the label, filled in the accent when chosen, a 6 px dot
// in it (the same parity, so it sits on the ring's centre pixel); an action
// row (`action`) has neither, its label in the accent, like a link. Space,
// Enter or a click toggles the switch, chooses the row or does the action.
// With the cursor it looks and lifts as the Layout page's chip does
// (PREFS-104): the focus fill over the strip's own colour, the focus ring,
// risen 8 px with its shadow band; in a pick group the whole group lifts
// and draws the ring, and the row keeps its fill.
BorderSurface {
  id: row
  property string label: ""
  property string caption: ""
  property bool checked: false
  property bool pick: false
  property bool action: false
  // The legend's line for Space while the cursor is here, if the page's
  // does not say it (a Look pick row's "Choose it").
  property string spaceHint: ""
  signal activated()

  // On a desk (DeskPage): one stop that draws its own cursor.
  readonly property int deskStops: 1
  readonly property int deskHome: 0
  function deskFocus(stop, reason) { forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason) }
  readonly property bool ownsFocusRing: true
  readonly property var keyHints: [{ keys: "h l", label: "Same row, next strip" }]
    .concat(spaceHint ? [{ keys: "space", label: spaceHint }] : [])

  readonly property bool hot: mouse.containsMouse && enabled
  // The strip it is on, for its colour and theme.
  readonly property Item strip: {
    for (var p = parent; p; p = p.parent)
      if (p.isDeskStrip)
        return p
    return null
  }
  readonly property color base: strip ? strip.surfaceColor : "transparent"
  // In a pick group (DeskPickGroup) the group lifts, not the row.
  readonly property bool grouped: !!parent && parent.deskGroupBody === true
  // Tuning's Mark the whole control (PREFS-132), on by default: the row's
  // area takes the focus fill and ring; off, only its switch or pick mark
  // takes the ring (an action row, with no mark, keeps the row's).
  readonly property bool marksRow: Tuning.values.areaRing !== 0 || action
  readonly property color ringColor: Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent).color
  CursorLift {
    id: lift
    up: row.activeFocus && !row.grouped
    animate: row.strip && row.strip.desk ? row.strip.desk.animate : true
    lightTheme: row.strip ? row.strip.lightTheme : false
    radius: row.radius
    plate: row.base
  }
  transform: Translate { y: -lift.raise }
  scale: lift.grown
  z: lift.raised ? 1 : 0
  Layout.fillWidth: true
  // The surface reaches into the strip's padding; the text stays in line.
  Layout.leftMargin: -Gap.s
  Layout.rightMargin: -Gap.s
  // A control's height at least, xs above and below its text (PREFS-133).
  implicitHeight: Math.max(Gap.control, content.implicitHeight + 2 * Gap.xs)
  radius: Round.control
  activeFocusOnTab: false
  opacity: enabled ? 1 : Ink.disabled
  // Risen, the strip's own colour under the fill, so the row it rises over
  // does not show through.
  // In a group marked whole, the cursor's row is the selected fill over the
  // group's focus fill, so it still shows which row it is.
  color: activeFocus && marksRow ? Qt.tint(base, grouped ? Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent) : Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent))
    : hot ? Qt.alpha(Commons.Color.popups.text, 0.14) : "transparent"
  borderSpec: activeFocus && !grouped && marksRow ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
  Accessible.role: action ? Accessible.Button : pick ? Accessible.RadioButton : Accessible.CheckBox
  Accessible.name: label
  Accessible.description: caption
  Accessible.checked: checked

  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      row.activated()
      event.accepted = true
    }
  }

  RowLayout {
    id: content
    x: Gap.s
    y: (row.height - height) / 2
    width: row.width - 2 * Gap.s
    spacing: Gap.m
    // The pick mark.
    Rectangle {
      visible: row.pick
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: Math.max(0, (labelText.implicitHeight - height) / 2)
      implicitWidth: Style.space(14)
      implicitHeight: Style.space(14)
      radius: width / 2
      color: row.checked ? Commons.Color.accent : "transparent"
      border.width: row.checked ? 0 : 1
      border.color: Qt.alpha(Commons.Color.popups.text, 0.45)
      antialiasing: true
      // The cursor's ring round the mark alone, 4 px out as the fader's
      // knob has it, when the row's area is not marked.
      Rectangle {
        visible: row.activeFocus && !row.marksRow
        anchors.centerIn: parent
        width: parent.width + Style.space(8)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: row.ringColor
        antialiasing: true
      }
      Rectangle {
        visible: row.checked
        anchors.centerIn: parent
        width: Style.space(6)
        height: width
        radius: width / 2
        color: Commons.Color.popups.background
        antialiasing: true
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Gap.xxs
      InkText {
        id: labelText
        Layout.fillWidth: true
        text: row.label
        color: row.action ? Commons.Color.accent : Ink.tint(1)
        elide: Text.ElideRight
      }
      InkText {
        visible: row.caption !== ""
        Layout.fillWidth: true
        text: row.caption
        role: "caption"
        wrapMode: Text.WordWrap
      }
    }
    ToggleSwitch {
      id: toggle
      visible: !row.pick && !row.action
      Layout.alignment: Qt.AlignTop
      checked: row.checked
      interactive: false
      foreground: Commons.Color.popups.text
      // The cursor's ring round the switch alone, 4 px out as the fader's
      // knob has it, when the row's area is not marked.
      Rectangle {
        visible: row.activeFocus && !row.marksRow
        anchors.centerIn: parent
        width: parent.width + Style.space(8)
        height: parent.height + Style.space(8)
        radius: toggle.rounded ? height / 2 : Style.space(4)
        color: "transparent"
        border.width: 1
        border.color: row.ringColor
        antialiasing: true
      }
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: row.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      row.forceActiveFocus(Qt.MouseFocusReason)
      row.activated()
    }
  }
}
