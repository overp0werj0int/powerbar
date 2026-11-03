import QtQuick
import "DeskModel.js" as DeskModel

// The cursor's walk over a desk's strips (DeskModel.js; PREFS-126), shared
// by the Look and Behavior pages (DeskPage) and the board inspectors
// (InspectorDesk): which control holds the cursor, where it is, and the
// keys. j/k go down and up a strip and on, h/l to the next or previous chip
// and past a row's ends to the same row of the next strip, Tab and
// Shift+Tab to the next or previous strip's first control. Its host passes
// its key presses to key().
QtObject {
  id: walk
  // The strips, left to right (DeskStrip).
  property var strips: []
  // The window's focused item.
  property Item focusedItem: null

  function within(item, ancestor) {
    for (var p = item; p; p = p.parent)
      if (p === ancestor)
        return true;
    return false;
  }
  // The control the cursor is in.
  readonly property Item focusedControl: {
    var f = focusedItem;
    if (!f)
      return null;
    for (var s = 0; s < strips.length; s++) {
      var list = strips[s].controls;
      for (var c = 0; c < list.length; c++)
        if (within(f, list[c]))
          return list[c];
    }
    return null;
  }
  function model() {
    return strips.map(function (s) {
      return s.controls.map(function (c) {
        return {
          stops: c.deskStops,
          home: c.deskHome
        };
      });
    });
  }
  function locate() {
    var f = focusedItem;
    for (var s = 0; s < strips.length; s++) {
      var list = strips[s].controls;
      for (var c = 0; c < list.length; c++)
        if (within(f, list[c]))
          return {
            strip: s,
            control: c,
            stop: list[c].deskStop !== undefined ? list[c].deskStop : 0
          };
    }
    return null;
  }
  property var remembered: null
  // The control the cursor was last on, to see it give way.
  property Item lastControl: null
  onFocusedControlChanged: {
    if (focusedControl) {
      remembered = locate();
      lastControl = focusedControl;
      return;
    }
    // The control under the cursor gave way (the Notch strip's action row
    // dims once used): the cursor stays in the strip, on the nearest
    // control left, instead of leaving the desk with nothing focused.
    var gone = lastControl;
    lastControl = null;
    if (gone && !gone.enabled)
      Qt.callLater(focusRemembered);
  }
  function go(place, reason) {
    if (!place || !strips[place.strip])
      return;
    var control = strips[place.strip].controls[place.control];
    if (control)
      control.deskFocus(place.stop, reason === undefined ? Qt.OtherFocusReason : reason);
  }
  // Back where the cursor was, else the desk's first control.
  function focusRemembered() {
    var m = model();
    go(remembered ? DeskModel.valid(m, remembered) : DeskModel.first(m), Qt.TabFocusReason);
  }
  function key(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      return;
    var m = model(), at = locate();
    var t = event.text.toLowerCase();
    var back = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier);
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
      go(at ? DeskModel.tab(m, at, back ? -1 : 1) : DeskModel.first(m), Qt.TabFocusReason);
    else if (t === "h" || t === "l" || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      var dir = t === "h" || event.key === Qt.Key_Left ? -1 : 1;
      go(at ? DeskModel.sideways(m, at, dir) : DeskModel.first(m));
    } else if (t === "j" || t === "k" || event.key === Qt.Key_Down || event.key === Qt.Key_Up)
      go(at ? DeskModel.vertical(m, at, t === "k" || event.key === Qt.Key_Up ? -1 : 1) : DeskModel.first(m));
    else
      return;
    event.accepted = true;
  }
}
