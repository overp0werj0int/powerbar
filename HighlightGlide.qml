import QtQuick

// One per bar window and one per drawer: the highlight that lights next
// slides over from the one that just went out, instead of the two fading
// (appearance.md LOOK-139). Only within one `glideKey` (a zone of the bar, or
// the drawer's rows); a move to another zone, or one while the old mark is
// still lit for its own reason (a hover beside the keyboard cursor), fades as
// before.
QtObject {
  id: glide
  // The mark that lit last, and where it was drawn when it went out.
  property var current: null
  property real leftAt: 0
  property var leftRect: null
  // A pointer crossing the gap between two cells lights the next one a
  // moment after the last went out: still one move.
  readonly property int graceMs: 160

  function rectOf(mark) {
    var p = mark.body.mapToItem(null, 0, 0)
    return { x: p.x, y: p.y, width: mark.body.width, height: mark.body.height }
  }
  // `mark` has just lit: where it slides from (scene coordinates), or null.
  // The mark it takes over from goes out at once.
  function takeOver(mark) {
    var prev = current
    current = mark
    if (!prev || prev === mark || prev.shown || prev.glideKey !== mark.glideKey) return null
    var from = prev.lit ? rectOf(prev) : Date.now() - leftAt <= graceMs ? leftRect : null
    if (from) prev.handOff()
    return from
  }
  // `mark` went out: remembered for the next one.
  function release(mark) {
    if (current !== mark) return
    leftAt = Date.now()
    leftRect = rectOf(mark)
  }
}
