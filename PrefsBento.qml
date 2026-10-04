import QtQuick
import qs.Commons
import "BentoModel.js" as BentoModel

// Tiles laid out like tiled windows: the desktop's inner gap between them, 12
// columns in a wide window, 6 in a medium one, 1 in a narrow one (BentoModel).
// Put it in a PrefsForm: j/k still walk every control in reading order, and
// Tab and Shift+Tab jump to the first control of the next or previous tile.
Item {
  id: bento
  property int columns: 12
  property real gap: Style.space(8)
  readonly property var tiles: {
    var list = []
    for (var i = 0; i < children.length; i++) if (children[i].span12 !== undefined) list.push(children[i])
    return list
  }
  readonly property var shownTiles: tiles.filter(function(t) { return t.visible })

  function relayout() {
    var shown = shownTiles
    var placed = BentoModel.place(shown.map(function(t) { return { span12: t.span12, span6: t.span6, height: t.implicitHeight } }),
      columns, width, gap)
    shown.forEach(function(t, i) {
      var r = placed.rects[i]
      t.x = r.x; t.y = r.y; t.width = r.width; t.height = r.height
    })
    implicitHeight = placed.height
  }
  function schedule() { Qt.callLater(relayout) }
  onWidthChanged: schedule()
  onColumnsChanged: schedule()
  onGapChanged: schedule()
  onTilesChanged: {
    tiles.forEach(function(t) {
      t.implicitHeightChanged.connect(bento.schedule)
      t.visibleChanged.connect(bento.schedule)
    })
    schedule()
  }

  function tileOf(item) {
    for (var p = item; p && p !== bento; p = p.parent) if (p.parent === bento) return p
    return null
  }
  function inside(item, tile) {
    for (var p = item; p; p = p.parent) if (p === tile) return true
    return false
  }
  function firstControl(tile) {
    var next = tile.nextItemInFocusChain(true)
    return next && inside(next, tile) ? next : null
  }
  function jump(forward) {
    var list = shownTiles
    var current = list.indexOf(tileOf(Window.activeFocusItem))
    if (current < 0) current = forward ? -1 : list.length
    var i = BentoModel.nextTile(list.length, current, forward, function(n) { return !!bento.firstControl(list[n]) })
    if (i < 0) return false
    firstControl(list[i]).forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
    return true
  }

  // A focused control steps the focus chain itself on Tab before any parent
  // sees the key, so the jump is a shortcut, live only while focus is in a tile.
  readonly property bool focusInside: shownTiles.length > 0 && tileOf(Window.activeFocusItem) !== null
  Shortcut { sequences: ["Tab"]; enabled: bento.focusInside; onActivated: bento.jump(true) }
  Shortcut { sequences: ["Shift+Tab", "Backtab"]; enabled: bento.focusInside; onActivated: bento.jump(false) }
}
