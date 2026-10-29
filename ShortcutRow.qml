import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ShortcutModel.js" as Shortcuts

// A widget's or a group's shortcut, as one compact row: its keys as keycaps
// and where they come from. Enter (or a click) records new keys: Hyprland
// steps aside (ShortcutStore.startRecording) so every key reaches the row.
// Keys another shortcut already has ask first; Enter takes them over. x takes
// the shortcut away, Backspace goes back to the one Omarchy or your Hyprland
// files give it.
BorderSurface {
  id: row
  required property var store
  property string target: ""
  // Why it can't have one (a hidden widget, no panel to open); "" when it can.
  property string unavailable: ""
  property string label: "Shortcut"
  // Keys offered while nothing is bound ("SUPER + B"): drawn faded with
  // "Suggested"; Enter takes them (checked for clashes), Space records others.
  property string suggested: ""
  readonly property bool suggesting: phase === "idle" && usable && !!suggested && !info.keys && !info.positional && info.source !== "removed"
  // Where the label starts: s in, the row's surface reaching s out past
  // its column so the label stays in line with the fields around it
  // (PREFS-133).
  property real padding: Gap.s
  // A line under the label (a desk's rows, PREFS-129), and the desk's cursor
  // look: the Layout chip's focus fill and ring, risen with its shadow band
  // (PREFS-104).
  property string caption: ""
  property bool cursor: false
  readonly property Item strip: {
    for (var p = parent; p; p = p.parent)
      if (p.isDeskStrip)
        return p
    return null
  }
  readonly property color base: strip ? strip.surfaceColor : "transparent"
  CursorLift {
    id: lift
    up: row.cursor
    animate: row.strip && row.strip.desk ? row.strip.desk.animate : true
    lightTheme: row.strip ? row.strip.lightTheme : false
    radius: row.radius
  }
  transform: Translate { y: -lift.raise }
  scale: lift.grown
  z: lift.raised ? 1 : 0

  // "idle", "recording" or "confirm" (the keys belong to something else).
  property string phase: "idle"
  property string captured: ""
  property var clashes: []
  property string notice: ""
  property int heldMods: 0
  readonly property var info: store.ready && target ? store.info(target) : { keys: "", source: "none", fallback: "", positional: "" }
  readonly property bool usable: unavailable === "" && !!target
  readonly property bool ownsFocusRing: phase !== "idle"
  readonly property string shownKeys: phase === "confirm" ? captured
    : phase === "recording" ? Shortcuts.format({ mask: heldMods, key: "" }).replace(/ \+ $/, "")
    : info.keys || info.positional || (suggesting ? suggested : "")
  readonly property var shownCaps: phase === "recording"
    ? Shortcuts.caps(Shortcuts.format({ mask: heldMods, key: "X" })).slice(0, -1) : Shortcuts.caps(shownKeys)

  // What the row says beside the keys, and the longer line a page may show
  // under or beside it (message).
  readonly property string tag: !usable ? unavailable
    : store.busy && phase === "idle" ? "Saving"
    : phase === "recording" ? (notice || "Press the keys")
    : phase === "confirm" ? (caption !== "" ? "" : clashes.map(function(c) { return c.description }).join(", "))
    : info.source === "omarchy" ? "Omarchy's"
    : info.source === "config" ? "Your Hyprland's"
    : info.source === "yours" ? ""
    : info.positional ? "By its place"
    : suggesting ? "Suggested"
    : info.source === "removed" ? "None, " + Shortcuts.label(info.fallback) + " removed"
    : "None"
  // While its keys clash, a row with a caption says so there instead: the
  // keys whole, the other binding's description cut to fit two lines.
  readonly property string clashText: phase === "confirm" ? Shortcuts.clashText(captured, clashes) : ""
  readonly property bool captionClash: phase === "confirm" && caption !== ""
  readonly property string message: store.error ? store.error
    : phase === "recording" ? "Hyprland's own shortcuts pause until you press one. Esc cancels."
    : phase === "confirm" ? clashText + ". Enter gives it to this one instead."
    : info.positional && !info.keys ? Shortcuts.label(info.positional) + " opens it as the bar's " + ordinal(info.positional) + " panel on the right; it follows its place."
    : ""
  function ordinal(keys) {
    var n = Number(Shortcuts.caps(keys).pop())
    return n === 1 ? "first" : n === 2 ? "second" : n === 3 ? "third" : n + "th"
  }

  readonly property var keyHints: phase === "recording" ? [{ keys: "esc", label: "Cancel" }]
    : phase === "confirm" ? [{ keys: "enter", label: "Take over" }, { keys: "esc", label: "Keep it there" }]
    : !usable ? []
    : suggesting ? [{ keys: "enter", label: "Use " + Shortcuts.label(suggested) }, { keys: "space", label: "Choose others" }]
    : [{ keys: "enter", label: info.keys ? "Change" : "Set" }]
      .concat(info.keys ? [{ keys: "x", label: "Remove" }] : [])
      .concat((info.source === "yours" || info.source === "removed") && info.fallback !== ""
        ? [{ keys: "backspace", label: "Restore " + Shortcuts.label(info.fallback) }] : [])

  function record() {
    if (!usable || store.busy) return
    notice = ""
    heldMods = 0
    phase = "recording"
    store.startRecording(target)
  }
  function cancel() {
    store.stopRecording()
    phase = "idle"
    captured = ""
    clashes = []
    notice = ""
  }
  function take(keys) {
    store.stopRecording()
    if (Shortcuts.same(keys, info.keys)) { phase = "idle"; return }
    var found = store.conflicts(keys, target)
    captured = keys
    clashes = found
    phase = found.length ? "confirm" : "idle"
    if (!found.length) store.save(target, keys)
  }
  // Yours with nothing behind it simply goes; one from Omarchy or your
  // Hyprland files is taken away (Backspace brings it back).
  function remove() {
    if (info.source === "yours" && !info.fallback) store.restore(target)
    else store.save(target, "")
  }
  function confirm() {
    store.save(target, captured)
    phase = "idle"
    clashes = []
  }
  onActiveFocusChanged: if (!activeFocus && phase !== "idle") cancel()
  Component.onDestruction: if (phase === "recording") store.stopRecording()

  Layout.fillWidth: true
  Layout.leftMargin: -padding
  Layout.rightMargin: -padding
  // A control's height at least, xs above and below its text.
  implicitHeight: Math.max(Gap.control, labelColumn.implicitHeight + 2 * Gap.xs)
  radius: Round.control
  color: phase !== "idle" ? Qt.tint(base, Qt.alpha(Commons.Color.accent, 0.1))
    : cursor ? Qt.tint(base, Style.focusFillFor(Commons.Color.popups.text, Commons.Color.accent))
    : rowMouse.containsMouse && usable ? Qt.alpha(Commons.Color.popups.text, 0.14) : "transparent"
  borderSpec: phase !== "idle" || cursor ? Border.controlSpec("focus", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
  opacity: usable ? 1 : Ink.disabled
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: label + ": " + (shownKeys ? Shortcuts.label(shownKeys) : "none") + (tag ? ", " + tag : "")

  // While recording, every key is the row's: no page shortcut (Ctrl+1, Tab)
  // may take one first.
  Keys.onShortcutOverride: function(event) { if (row.phase !== "idle") event.accepted = true }
  // The modifiers held so far show as keycaps while recording.
  Keys.onReleased: function(event) {
    if (row.phase !== "recording") return
    var released = event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R ? 64
      : event.key === Qt.Key_Control ? 4 : event.key === Qt.Key_Alt ? 8 : event.key === Qt.Key_Shift ? 1 : 0
    row.heldMods = row.maskOf(event.modifiers) & ~released
    event.accepted = true
  }
  function maskOf(mods) {
    return (mods & Qt.MetaModifier ? 64 : 0) | (mods & Qt.ControlModifier ? 4 : 0) | (mods & Qt.AltModifier ? 8 : 0) | (mods & Qt.ShiftModifier ? 1 : 0)
  }
  Keys.onPressed: function(event) {
    var key = event.key, plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.ShiftModifier))
    if (row.phase === "recording") {
      event.accepted = true
      if (key === Qt.Key_Escape && plain) { row.cancel(); return }
      var got = Shortcuts.fromKeyEvent(key, event.modifiers, event.nativeScanCode)
      row.heldMods = row.maskOf(event.modifiers)
      if (got.keys) row.take(got.keys)
      else if (got.error) row.notice = got.error
      return
    }
    if (row.phase === "confirm") {
      event.accepted = true
      if (key === Qt.Key_Return || key === Qt.Key_Enter) row.confirm()
      else if (key === Qt.Key_Escape) row.cancel()
      return
    }
    if (!row.usable) return
    if ((key === Qt.Key_Return || key === Qt.Key_Enter) && plain && row.suggesting) { row.take(row.suggested); event.accepted = true }
    else if ((key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space) && plain) { row.record(); event.accepted = true }
    else if ((key === Qt.Key_X || key === Qt.Key_Delete) && plain && row.info.keys) { row.remove(); event.accepted = true }
    else if (key === Qt.Key_Backspace && plain && (row.info.source === "yours" || row.info.source === "removed")) { row.store.restore(row.target); event.accepted = true }
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: row.padding
    anchors.rightMargin: row.padding
    spacing: Gap.m
    ColumnLayout {
      id: labelColumn
      Layout.fillWidth: row.caption !== ""
      spacing: Gap.xxs
      InkText {
        text: row.label
      }
      InkText {
        visible: row.caption !== ""
        Layout.fillWidth: true
        text: row.captionClash ? row.clashText : row.caption
        role: "caption"
        color: row.captionClash ? Commons.Color.urgent : Ink.tint(tier)
        wrapMode: Text.WordWrap
        maximumLineCount: row.captionClash ? 2 : 100
        elide: row.captionClash ? Text.ElideRight : Text.ElideNone
      }
    }
    InkText {
      Layout.fillWidth: row.caption === ""
      horizontalAlignment: Text.AlignRight
      text: row.tag
      role: "caption"
      elide: Text.ElideRight
      color: row.phase === "confirm" || (row.phase === "recording" && row.notice) ? Commons.Color.urgent
        : row.phase === "recording" ? Commons.Color.accent : Ink.tint(tier)
    }
    KeyCombo {
      keys: row.shownCaps
      foreground: row.phase === "confirm" ? Commons.Color.urgent : Commons.Color.popups.text
      opacity: row.info.keys || row.phase !== "idle" ? 1 : Ink.secondary
    }
    Button {
      visible: row.phase === "confirm"
      text: "Take over"
      focusable: false
      foreground: Commons.Color.popups.text
      onClicked: row.confirm()
    }
  }
  MouseArea {
    id: rowMouse
    anchors.fill: parent
    z: -1
    hoverEnabled: true
    cursorShape: row.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      row.forceActiveFocus(Qt.MouseFocusReason)
      if (row.phase === "idle") row.record()
    }
  }
}
