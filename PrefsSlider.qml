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

  property bool drafting: false
  property real draft: 0
  property bool dragging: false
  property real lastEdit: -Infinity
  property real wheelRest: 0
  property real grabOffset: 0

  readonly property real committed: SliderModel.snap(value, minimum, maximum, stepSize)
  readonly property real shown: drafting ? draft : committed
  readonly property bool hasDefault: isFinite(defaultValue) && defaultValue >= minimum && defaultValue <= maximum
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
  // Moves the draft and, unless the pointer still holds the knob, schedules
  // it to apply once the user goes quiet.
  function setDraft(v) {
    var next = SliderModel.snap(v, minimum, maximum, stepSize)
    var now = Date.now()
    var gap = now - lastEdit
    lastEdit = now
    if (!drafting && next === committed) return
    draft = next
    drafting = true
    drafted(next)
    settle.interval = SliderModel.settleDelay(gap)
    if (!dragging) settle.restart()
  }
  function step(count) { setDraft(shown + count * stepSize) }
  function flush() {
    settle.stop()
    if (!drafting) return
    var v = draft
    drafting = false
    if (v !== committed) edited(v)
    drafted(NaN)
  }
  function cancel() {
    settle.stop()
    dragging = false
    if (!drafting) return false
    drafting = false
    drafted(NaN)
    return true
  }
  function endDrag() {
    if (!dragging) return
    dragging = false
    if (!drafting) return
    settle.interval = SliderModel.RELEASE
    settle.restart()
  }

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

  Keys.onPressed: function(event) {
    var big = (event.modifiers & Qt.ShiftModifier) ? 5 : 1
    var t = event.text.toLowerCase()
    if (event.key === Qt.Key_Left || t === "h") row.step(-big)
    else if (event.key === Qt.Key_Right || t === "l") row.step(big)
    else if (event.key === Qt.Key_PageDown) row.step(-5)
    else if (event.key === Qt.Key_PageUp) row.step(5)
    else if (event.key === Qt.Key_Home) row.setDraft(row.minimum)
    else if (event.key === Qt.Key_End) row.setDraft(row.maximum)
    else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && row.hasDefault) row.setDraft(row.defaultValue)
    else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && row.drafting) row.flush()
    else if (event.key === Qt.Key_Escape && row.cancel()) {}
    else return
    event.accepted = true
  }
  // Leaving the slider, its page or the window applies what is pending.
  onActiveFocusChanged: if (!activeFocus && enabled) { endDrag(); flush() }
  onVisibleChanged: if (!visible) { endDrag(); flush() }
  onEnabledChanged: if (!enabled) cancel()
  Component.onDestruction: flush()
  Connections {
    target: row.Window.window
    ignoreUnknownSignals: true
    function onVisibleChanged() { if (row.Window.window && !row.Window.window.visible) { row.endDrag(); row.flush() } }
  }

  Timer { id: settle; onTriggered: row.flush() }
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
          return SliderModel.fromPosition(x - row.grabOffset - slider.knobSize / 2, slider.span,
            row.minimum, row.maximum, row.stepSize)
        }
        onPressed: function(mouse) {
          settle.stop()
          row.forceActiveFocus(Qt.MouseFocusReason)
          var centre = knob.x + knob.width / 2
          // On the knob, keep the grab point; on the track, jump there.
          row.grabOffset = Math.abs(mouse.x - centre) <= knob.width / 2 + Style.space(2) ? mouse.x - centre : 0
          row.dragging = true
          row.setDraft(valueAt(mouse.x))
        }
        onPositionChanged: function(mouse) { if (row.dragging) row.setDraft(valueAt(mouse.x)) }
        onReleased: row.endDrag()
        onCanceled: row.endDrag()
        onWheel: function(wheel) {
          if (!row.activeFocus || row.dragging) { wheel.accepted = false; return }
          var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x
          var notches = SliderModel.wheelSteps(row.wheelRest, delta)
          row.wheelRest = notches.rest
          if (notches.steps !== 0) row.step(notches.steps)
        }
      }
    }
  }
}
