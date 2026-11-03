import QtQuick

// A shortcut row (ShortcutRow) as a desk control (DeskStrip): one stop, its
// cursor in the desk's look. The Behavior page's Keyboard strip and the
// board inspectors use it.
ShortcutRow {
  readonly property int deskStops: 1
  readonly property int deskHome: 0
  function deskFocus(stop, reason) {
    forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
  }
  cursor: activeFocus
  activeFocusOnTab: false
}
