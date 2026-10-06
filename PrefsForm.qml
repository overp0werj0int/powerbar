import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons

// A scrolling settings page. Up/Down and j/k walk the controls whenever the
// focused control does not use them itself, and the focused control is kept
// in view, so every setting is reachable without a pointer.
Controls.ScrollView {
  id: page
  default property alias content: column.data
  property real maxContentWidth: Style.space(760)
  readonly property Item focusedItem: Window.activeFocusItem
  // The footer's keys follow focus: a control with its own keys (a slider)
  // lists them between moving and switching pages.
  readonly property var focusedHints: focusedItem && focusedItem.keyHints && contains(focusedItem) ? focusedItem.keyHints : null
  // A bento tile adds its own keys (Dissolve), and Tab jumps between tiles.
  readonly property Item focusedTile: {
    for (var p = focusedItem; p && p !== column; p = p.parent) if (p.tileHints !== undefined) return p
    return null
  }
  readonly property var tileHints: focusedTile && contains(focusedTile) ? focusedTile.tileHints : []
  readonly property var hints: [{ keys: "j k", label: "Move" }]
    .concat(focusedTile && !focusedHints ? [{ keys: "tab shift+tab", label: "Next, previous tile" }] : [])
    .concat(focusedHints || [{ keys: "h l", label: "Adjust" }, { keys: "space", label: "Toggle" }])
    .concat(tileHints, [{ keys: "1-3", label: "Pages" }],
      focusedHints && focusedHints.some(function(h) { return h.keys === "esc" }) ? [] : [{ keys: "esc", label: "Close" }])
  contentWidth: availableWidth
  clip: true
  onFocusedItemChanged: if (contains(focusedItem)) reveal(focusedItem)

  function contains(item) {
    for (var p = item; p; p = p.parent) if (p === column) return true
    return false
  }
  function reveal(item) {
    var view = page.contentItem
    if (!view || !item) return
    var top = item.mapToItem(column, 0, 0).y - Style.space(24)
    var bottom = top + item.height + Style.space(48)
    var end = Math.max(0, view.contentHeight - view.height)
    if (top < view.contentY) view.contentY = Math.max(0, top)
    else if (bottom > view.contentY + view.height) view.contentY = Math.min(end, bottom - view.height)
  }
  function step(forward) {
    var from = page.focusedItem && page.contains(page.focusedItem) ? page.focusedItem : null
    var next = from ? from.nextItemInFocusChain(forward) : column.nextItemInFocusChain(true)
    if (next && page.contains(next)) next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
  }
  // An open dropdown list floats above the page; scrolling closes it, as
  // native menus do, instead of carrying it over the rest of the window.
  function closePopups(item) {
    for (var i = 0; i < item.children.length; i++) {
      var child = item.children[i]
      if (child.popupOpen === true && typeof child.close === "function") child.close()
      else closePopups(child)
    }
  }
  Connections {
    target: page.contentItem
    function onContentYChanged() { page.closePopups(column) }
  }
  function focusFirst() {
    var next = column.nextItemInFocusChain(true)
    if (next && contains(next)) next.forceActiveFocus(Qt.TabFocusReason)
  }

  ColumnLayout {
    id: column
    x: Math.max(0, (page.availableWidth - width) / 2)
    width: Math.min(page.availableWidth, page.maxContentWidth)
    spacing: Style.space(30)
    Keys.onPressed: function(event) {
      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
      if (event.key === Qt.Key_Down || event.text === "j") { page.step(true); event.accepted = true }
      else if (event.key === Qt.Key_Up || event.text === "k") { page.step(false); event.accepted = true }
    }
  }
}
