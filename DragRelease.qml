import QtQuick

// A drag's release, held for one turn of the event loop (DRAG-77). Hyprland
// releases a held button whenever it hands the pointer to another surface,
// right before the leave: with nothing keyboard-focused (an empty workspace)
// it does so as soon as the pointer leaves the bar's input region. That
// release carries the last point on the bar, where the user did not let go.
// The leave arrives in the same turn, so a release followed by the window
// losing the pointer is one outside the bar (DRAG-32); any other lands where
// it was made. `after` runs once either way, after the outcome.
QtObject {
  id: gate
  property var pending: null
  signal landed(var point, var slot)
  signal left(var point, var slot)

  function release(point, slot, after) {
    if (pending) settle(pending, false)
    var made = { point: point, slot: slot, after: after || null }
    pending = made
    Qt.callLater(function() { gate.settle(made, false) })
  }
  function pointerLeft() { if (pending) settle(pending, true) }
  function settle(made, outside) {
    if (pending !== made) return
    pending = null
    if (outside) left(made.point, made.slot)
    else landed(made.point, made.slot)
    if (made.after) made.after()
  }
}
