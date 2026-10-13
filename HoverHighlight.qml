import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Commons as Commons

// Hover and selection for bar and drawer items, drawn like the tiles in
// Preferences → Layout: a soft rounded fill behind the item. Visual only;
// hover and clicks stay with the enclosing widget.
//
// The owner places the mark (x, y, width, height); the fill (`body`) is
// drawn there, except while it slides in from the mark that went out just
// before (appearance.md LOOK-139, HighlightGlide.qml): it starts where that
// one was drawn and glides to its own place, so a hover or the keyboard
// cursor moves along a zone instead of fading out here and in there.
Item {
  id: mark
  property bool hovered: false
  property bool selected: false
  property bool motionEnabled: true
  property color hoverColor: "transparent"
  property color selectedColor: "transparent"
  property real rounding: 6
  // The keyboard cursor: the same mark with an accent ring as its border, one
  // device pixel wide (keyboard.md KEYS-69). The caller also lights the mark
  // (`hovered`) for the cursor.
  property bool outlined: false
  property color outlineColor: Commons.Color.accent
  property real outlineWidth: 1 / Math.max(1, Screen.devicePixelRatio)
  // Where two lit highlights overlap (Equal gaps), the older one fades so the
  // eye goes to what just happened; the newer one draws on top. The keyboard
  // cursor never fades for that.
  property bool older: false
  property real litAt: 0
  // The sliding: marks sharing a glide and a key (one zone of one bar, or
  // one drawer's rows) hand the fill from one to the next.
  property QtObject glide: null
  property string glideKey: ""
  readonly property bool shown: hovered || selected
  readonly property alias body: fill
  // The cursor arriving or leaving changes `outlined` and `hovered` together,
  // in either order, so both are settled once per event-loop turn: a change
  // that moved the ring is a cursor move and shows at once, without the fade.
  property bool lit: false
  property bool ringed: false
  property bool cursorMove: false
  // Taken over by the next mark, which slides on from where this one was:
  // out at once, no fade.
  property bool handedOff: false
  property bool sliding: false
  onShownChanged: Qt.callLater(mark.settle)
  onOutlinedChanged: Qt.callLater(mark.settle)
  Component.onCompleted: settle()
  function settle() {
    var lighting = shown && !lit
    cursorMove = outlined !== ringed
    ringed = outlined
    if (lighting) {
      handedOff = false
      var from = glideLive() && motionEnabled ? glide.takeOver(mark) : null
      if (from) slideFrom(from)
    }
    if (!shown && lit && glideLive()) glide.release(mark)
    lit = shown
  }
  // A settle queued with Qt.callLater can run while the glide is being torn
  // down, when Qt 6.12 has already dropped its functions.
  function glideLive() { return !!glide && typeof glide.release === "function" }
  function handOff() { slide.stop(); handedOff = true }
  // From a rect in scene coordinates to the mark's own place.
  function slideFrom(r) {
    var p = mark.mapFromItem(null, r.x, r.y)
    var dx = p.x, dy = p.y, dw = r.width - width, dh = r.height - height
    var far = Math.hypot(dx + dw / 2, dy + dh / 2)
    if (far < 0.5) return
    slide.stop()
    offX = dx; offY = dy; offW = dw; offH = dh
    // Quick for a neighbour, a little longer across the zone, never slow:
    // a pointer sweeping the bar retargets it from wherever it is drawn.
    slide.duration = Math.round(Math.max(100, Math.min(170, 90 + far * 0.15)))
    sliding = true
    slide.start()
  }
  property real offX: 0
  property real offY: 0
  property real offW: 0
  property real offH: 0
  ParallelAnimation {
    id: slide
    property int duration: 120
    NumberAnimation { target: mark; property: "offX"; to: 0; duration: slide.duration; easing.type: Easing.OutCubic }
    NumberAnimation { target: mark; property: "offY"; to: 0; duration: slide.duration; easing.type: Easing.OutCubic }
    NumberAnimation { target: mark; property: "offW"; to: 0; duration: slide.duration; easing.type: Easing.OutCubic }
    NumberAnimation { target: mark; property: "offH"; to: 0; duration: slide.duration; easing.type: Easing.OutCubic }
    onStopped: { mark.sliding = false; mark.offX = 0; mark.offY = 0; mark.offW = 0; mark.offH = 0 }
  }

  // The fade runs on `shade`, so a hand-off cuts a fade-out already running.
  property real shade: lit ? (older && !ringed ? 0.45 : 1) : 0
  Behavior on shade { enabled: mark.motionEnabled && !mark.cursorMove && !mark.sliding; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
  opacity: handedOff ? 0 : shade
  z: lit && (!older || ringed) ? 1 : 0
  visible: opacity > 0
  Accessible.ignored: true

  Rectangle {
    id: fill
    x: mark.offX
    y: mark.offY
    width: Math.max(0, mark.width + mark.offW)
    height: Math.max(0, mark.height + mark.offH)
    radius: Math.max(0, Math.min(mark.rounding, Math.min(width, height) / 2))
    color: mark.selected ? mark.selectedColor : mark.hoverColor
    // A border is drawn inside the shape: it has width only while it shows, so
    // the fill has no gap around it otherwise.
    border.width: mark.ringed ? mark.outlineWidth : 0
    border.color: mark.outlineColor
    Behavior on color { enabled: mark.motionEnabled && !mark.cursorMove && !mark.sliding; ColorAnimation { duration: 90 } }
  }
}
