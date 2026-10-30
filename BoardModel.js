// What the Layout and Groups boards decide the same way (docs/behavior/
// preferences.md PREFS-27, PREFS-117): what a key asks for, when a press
// becomes a drag, which way a held carry scrolls a window, how far a wheel
// notch goes, which gap a pointer is at, and the plain hit and focus
// questions both pages ask. No Qt objects beyond what a caller hands in:
// `covers` and `within` read only `mapFromItem`, `width`, `height` and
// `parent`, so node tests pass plain objects.
//
// Two orders both pages keep, and a new board page must too. A press moves
// the cursor to what it landed on before it takes focus, so a field that
// finishes on the focus change saves for the right subject. A drop is decided
// while the chip is still lifted and written once it is put down.

// Qt's key and modifier codes (Qt::Key, Qt::KeyboardModifier). They are Qt's
// ABI; tests/qml/tst_BoardModel.qml compares each with Qt.Key_* and
// Qt.*Modifier, so a typo fails the build instead of a key going dead.
var KEY = {
  escape: 0x01000000, ret: 0x01000004, enter: 0x01000005, del: 0x01000007,
  left: 0x01000012, up: 0x01000013, right: 0x01000014, down: 0x01000015,
  space: 0x20,
  shift: 0x02000000, control: 0x04000000, alt: 0x08000000
}

// A key on a board, or null while Ctrl or Alt is held: the boards take no
// chords. Otherwise the step h j k l or an arrow asks for (dx and dy, each
// -1, 0 or 1), whether Shift carries, `act` one of "space", "enter" (Return
// or Enter), "escape", "delete" or "", and the typed text as is (`t`) and
// lower-cased (`c`) for each page's own letters.
function keyCommand(key, text, modifiers) {
  if (modifiers & (KEY.control | KEY.alt)) return null
  var c = text.toLowerCase()
  return {
    dx: key === KEY.left || c === "h" ? -1 : key === KEY.right || c === "l" ? 1 : 0,
    dy: key === KEY.up || c === "k" ? -1 : key === KEY.down || c === "j" ? 1 : 0,
    carry: !!(modifiers & KEY.shift),
    act: key === KEY.space ? "space" : key === KEY.ret || key === KEY.enter ? "enter"
      : key === KEY.escape ? "escape" : key === KEY.del ? "delete" : "",
    t: text,
    c: c
  }
}

// Whether the pointer has gone far enough from the press to lift: the
// Manhattan distance past `limit`.
function pastThreshold(from, to, limit) {
  return Math.abs(to.x - from.x) + Math.abs(to.y - from.y) > limit
}

// Which way a window scrolls while a carry is held at `y` (in the window's
// coordinates): -1 in the top band while it can go up, 1 in the bottom band
// while it can go down, else 0 (PREFS-106).
function edgeDirection(y, viewTop, viewHeight, scroll, maxScroll, band) {
  if (y < viewTop + band && scroll > 0) return -1
  if (y > viewTop + viewHeight - band && scroll < maxScroll) return 1
  return 0
}

// How far a wheel event scrolls: a touchpad's pixels, else a row a notch.
function wheelDelta(pixelY, angleY, rowStep) {
  return pixelY ? -pixelY : -angleY / 120 * rowStep
}

// The gap the pointer is at among a window's rows, as ZoneTile.mapRows gives
// them ({ x, y, width, height }: the pointer in each row's own coordinates,
// landing places left out). Before the first row the pointer has not passed.
// A column is passed below a row's middle; a flow (the hidden and tray slabs)
// below a row, or on it right of its middle.
function gapIndex(rows, flows) {
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    var passed = flows ? r.y >= r.height || (r.y >= 0 && r.x >= r.width / 2) : r.y >= r.height / 2
    if (!passed) return i
  }
  return rows.length
}

// Whether `item` is `root` or inside it.
function within(item, root) {
  for (var p = item; p; p = p.parent)
    if (p === root) return true
  return false
}

// Whether `point`, in `from`'s coordinates, falls in `item`'s box, mapped
// through whatever transforms lie between (the plates' tilt). Visibility is
// the caller's.
function covers(item, from, point) {
  var p = item.mapFromItem(from, point.x, point.y)
  return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height
}
