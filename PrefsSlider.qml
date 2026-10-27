import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SliderModel.js" as SliderModel

// A labelled slider row, drawn like Omarchy's own panel sliders (the audio
// panel's track, fill and ringed knob) in the popup palette.
//
// The slider keeps a draft while it is worked and applies it to the bar only
// once it settles (SliderModel): on pointer release, or after a short quiet
// spell for keys and the wheel. `drafted` reports the draft as it moves (NaN
// once it is applied or dropped), so a preview in the window can follow it at
// no cost to the bar.
//
// Pointer: press the knob to drag it from where it was grabbed, or press the
// track to jump there and keep dragging. Keys: h/l or Left/Right step, Shift
// for five steps, Home/End for the ends, Backspace for the default, Enter
// applies now, Esc drops an unapplied draft. The wheel adjusts a focused
// slider and otherwise scrolls the page, so scrolling past never edits.
BorderSurface {
  id: row
  property string label: ""
  property string description: ""
  property string unit: "px"
  property real minimum: 0
  property real maximum: 100
  property real stepSize: 1
  property real value: 0
  // NaN when the setting has no default worth returning to.
  property real defaultValue: NaN
  // Optional words for special values, such as the ends of the range.
  property var formatter: null
  property bool animate: true
  // In a tile: label and value on one line, no description, and no surface
  // until the pointer or focus is on it.
  property bool compact: false
  signal edited(real value)
  signal drafted(real value)

  // The draft, its settling and the keys (SliderDraft, shared with Fader).
  SliderDraft {
    id: core
    host: row
    minimum: row.minimum
    maximum: row.maximum
    stepSize: row.stepSize
    value: row.value
    defaultValue: row.defaultValue
    onEdited: function(v) { row.edited(v) }
    onDrafted: function(v) { row.drafted(v) }
  }
  property alias drafting: core.drafting
  property alias dragging: core.dragging
  property alias lastEdit: core.lastEdit
  property alias wheelRest: core.wheelRest
  readonly property alias committed: core.committed
  readonly property alias shown: core.shown
  readonly property alias hasDefault: core.hasDefault
  readonly property bool hot: hover.hovered
  // Footer keys while this slider has focus.
  readonly property var keyHints: [{ keys: "h l", label: "Adjust" }, { keys: "shift", label: "Faster" }]
    .concat(hasDefault ? [{ keys: "⌫", label: "Default" }] : [])
    .concat(drafting ? [{ keys: "enter", label: "Apply" }, { keys: "esc", label: "Undo" }] : [])

  function format(v) {
    var custom = typeof formatter === "function" ? formatter(v) : ""
    if (custom) return custom
    return (stepSize < 1 ? v.toFixed(1) : Math.round(v)) + (unit === "%" ? "%" : unit ? " " + unit : "")
  }
  function setDraft(v) { core.setDraft(v) }
  function step(count) { core.step(count) }
  function flush() { core.flush() }
  function cancel() { return core.cancel() }
  function endDrag() { core.endDrag() }

  Layout.fillWidth: true
  implicitHeight: content.implicitHeight + (compact ? Style.space(8) : Style.space(20))
  radius: compact ? Math.max(0, Style.cornerRadius - Math.round(Style.spacing.rowPaddingX / 2)) : Style.cornerRadius
  activeFocusOnTab: enabled
  opacity: enabled ? 1 : 0.45
  readonly property bool resting: compact && !activeFocus && !hot
  color: resting ? "transparent" : Style.controlFill(activeFocus, hot, Commons.Color.popups.text, Commons.Color.accent)
  borderSpec: resting ? Border.none() : Border.controlSpec(activeFocus ? "focus" : hot ? "hover-cursor" : "normal", Commons.Color.popups.text, Commons.Color.accent)
  Accessible.role: Accessible.Slider
  Accessible.name: label
  Accessible.description: format(shown)

  Keys.onPressed: function(event) { if (core.keyPressed(event, false)) event.accepted = true }
  HoverHandler { id: hover }

  ColumnLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.spacing.rowPaddingX
    anchors.rightMargin: Style.spacing.rowPaddingX
    spacing: row.compact ? 0 : Style.space(4)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(12)
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(2)
        Text {
          text: row.label
          textFormat: Text.PlainText
          color: Commons.Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          Layout.fillWidth: true
          elide: Text.ElideRight
        }
        Text {
          visible: row.description !== "" && !row.compact
          text: row.description
          textFormat: Text.PlainText
          color: Qt.alpha(Commons.Color.popups.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
      // An unapplied draft shows in the accent and turns back once the bar has it.
      Text {
        Layout.alignment: row.compact ? Qt.AlignVCenter : Qt.AlignTop
        text: row.format(row.shown)
        textFormat: Text.PlainText
        color: row.drafting ? Commons.Color.accent : Qt.alpha(Commons.Color.popups.text, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    // The track, as Ui/PanelSlider draws it; the knob travels inside the
    // track's ends so the extremes are as easy to grab as the middle.
    Item {
      id: slider
      objectName: "sliderTrack"
      Layout.fillWidth: true
      readonly property real trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
      readonly property real knobSize: Math.max(14, Math.round(Style.spacing.controlHeight * 0.38))
      readonly property real progress: SliderModel.progress(row.shown, row.minimum, row.maximum)
      readonly property real span: Math.max(1, width - knobSize)
      readonly property int ticks: SliderModel.tickCount(row.minimum, row.maximum, row.stepSize)
      readonly property bool hot: pointer.containsMouse || row.dragging
      implicitHeight: Math.max(Style.space(22), knobSize + Style.spacing.md)
      function xFor(v) { return knobSize / 2 + span * SliderModel.progress(v, row.minimum, row.maximum) }

      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        x: slider.knobSize / 2 - height / 2
        width: slider.span + height
        height: slider.trackHeight
        radius: height / 2
        color: Style.selectedFillFor(Commons.Color.popups.text, Commons.Color.accent)
      }
      // The default, as a faint mark across the track.
      Rectangle {
        visible: row.hasDefault
        width: Math.max(1, Style.space(2))
        height: slider.trackHeight + Style.space(8)
        radius: width / 2
        anchors.verticalCenter: track.verticalCenter
        x: slider.xFor(row.defaultValue) - width / 2
        color: Qt.alpha(Commons.Color.popups.text, 0.35)
        Accessible.ignored: true
      }
      Rectangle {
        anchors.verticalCenter: track.verticalCenter
        x: track.x
        height: track.height
        radius: track.radius
        width: slider.span * slider.progress + track.height
        color: Commons.Color.popups.text
        Behavior on width {
          enabled: !row.dragging && row.animate
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
      }
      Repeater {
        model: slider.ticks
        Rectangle {
          required property int index
          width: Math.max(1, Style.space(2))
          height: slider.trackHeight + Style.space(4)
          radius: 1
          anchors.verticalCenter: track.verticalCenter
          x: slider.knobSize / 2 + slider.span * index / (slider.ticks - 1) - width / 2
          color: Commons.Color.popups.background
          Accessible.ignored: true
        }
      }
      BorderSurface {
        id: knob
        width: slider.knobSize
        height: slider.knobSize
        radius: width / 2
        anchors.verticalCenter: track.verticalCenter
        x: slider.span * slider.progress
        color: Commons.Color.popups.text
        borderSpec: Border.flat(Commons.Color.popups.background, Math.max(1, Style.space(2)))
        scale: row.dragging ? 1.2 : slider.hot ? 1.15 : 1
        Behavior on x {
          enabled: !row.dragging && row.animate
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
          enabled: row.animate
          NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
        }
      }

      MouseArea {
        id: pointer
        // A grab area taller than the track, across the whole row.
        anchors.fill: parent
        anchors.topMargin: -Style.space(6)
        anchors.bottomMargin: -Style.space(6)
        hoverEnabled: row.enabled
        enabled: row.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function valueAt(x) {
          return SliderModel.fromPosition(x - core.grabOffset - slider.knobSize / 2, slider.span,
            row.minimum, row.maximum, row.stepSize)
        }
        onPressed: function(mouse) {
          row.forceActiveFocus(Qt.MouseFocusReason)
          var centre = knob.x + knob.width / 2
          // On the knob, keep the grab point; on the track, jump there.
          core.grabOffset = Math.abs(mouse.x - centre) <= knob.width / 2 + Style.space(2) ? mouse.x - centre : 0
          core.startDrag(valueAt(mouse.x))
        }
        onPositionChanged: function(mouse) { if (row.dragging) row.setDraft(valueAt(mouse.x)) }
        onReleased: row.endDrag()
        onCanceled: row.endDrag()
        onWheel: function(wheel) {
          wheel.accepted = core.wheel(wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x)
        }
      }
    }
  }
}
