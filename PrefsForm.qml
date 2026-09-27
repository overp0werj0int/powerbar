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
  readonly property var hints: [
    { keys: "j k", label: "Move" }, { keys: "h l", label: "Adjust" },
    { keys: "space", label: "Toggle" }, { keys: "1-4", label: "Pages" }, { keys: "esc", label: "Close" }
  ]
  readonly property Item focusedItem: Window.activeFocusItem
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
    if (top < view.contentY) view.contentY = Math.max(0, top)
    else if (bottom > view.contentY + view.height) view.contentY = bottom - view.height
  }
  function step(forward) {
    var from = page.focusedItem && page.contains(page.focusedItem) ? page.focusedItem : null
    var next = from ? from.nextItemInFocusChain(forward) : column.nextItemInFocusChain(true)
    if (next && page.contains(next)) next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
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
