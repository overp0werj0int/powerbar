import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Commons as Commons
import "TrayItemsModel.js" as TrayItemsModel

// One of Omarchy's tray icons, moved out of the tray onto the bar
// (TrayItemsModel.js). It behaves as the tray's own icon does: left click
// activates the app (or opens its menu when the app only has a menu), middle
// click is its secondary action, right click opens its menu, and the wheel
// scrolls it. While the app is not running it takes no room.
Item {
  id: widget
  // Powerbar's bar, which coordinates popups and tooltips.
  required property var host
  required property var entry
  readonly property var traySettings: entry && typeof entry === "object" ? entry : ({})
  readonly property var item: TrayItemsModel.find(SystemTray.items.values, traySettings)
  readonly property bool present: !!item && item.status !== Status.Passive
  readonly property bool vertical: !!host && host.vertical
  readonly property real iconSlot: Style.bar.iconSlot
  readonly property real iconSize: Style.bar.iconSize
  readonly property string tooltip: TrayItemsModel.titleOf(item)
  // What the bar measures as this widget's ink (HighlightModel): an icon.
  readonly property real paintedWidth: present ? iconSize : 0
  readonly property bool tooltipHovered: present && mouse.containsMouse
  property bool menuOpen: false
  // The menu is made on the first right click, then kept: its card fades out
  // after closing.
  property bool menuMade: false

  visible: present
  implicitWidth: !present ? 0 : vertical ? (host ? host.barSize : iconSlot) : iconSlot
  implicitHeight: !present ? 0 : vertical ? iconSlot : (host ? host.barSize : iconSlot)

  function close() { menuOpen = false }
  function closeForPopoutSwitch() { close() }
  function showMenu() {
    if (!item) return
    if (!item.menu) {
      // The app draws its own menu, under the icon's centre.
      var point = widget.QsWindow.contentItem.mapFromItem(widget, width / 2, height / 2)
      item.display(widget.QsWindow.window, point.x, point.y)
      return
    }
    if (menuLoader.item) menuLoader.item.reset()
    menuMade = true
    menuOpen = true
  }
  // The bar's pointer layer takes every press on a slot and hands its click
  // here (Bar.qml pressModuleClickTarget), as it does for WidgetButton.
  function triggerPress(button) {
    if (!item) return
    if (host) host.hideTooltip(widget, true)
    if (button === Qt.RightButton) {
      if (menuOpen) close()
      else showMenu()
    } else if (button === Qt.MiddleButton) item.secondaryActivate()
    else if (item.onlyMenu) showMenu()
    else item.activate()
  }
  // The keyboard mode's Enter and a widget shortcut: the menu, or for an app
  // without one, its main action.
  function toggle() {
    if (!item) return
    if (menuOpen) close()
    else if (item.menu) showMenu()
    else item.activate()
  }
  // The app went away with its menu open.
  onPresentChanged: if (!present) close()

  TintedImage {
    anchors.centerIn: parent
    width: widget.iconSize
    height: widget.iconSize
    fillMode: Image.PreserveAspectFit
    // Decoded at device pixels, as Omarchy's tray does, so icons stay sharp.
    sourceSize.width: Math.round(widget.iconSize * Screen.devicePixelRatio)
    sourceSize.height: Math.round(widget.iconSize * Screen.devicePixelRatio)
    source: widget.item ? String(widget.item.icon || "") : ""
    // Symbolic icons are drawn in the bar's text colour.
    tint: String(widget.item && widget.item.icon || "").split("?")[0].slice(-9) === "-symbolic"
    color: widget.host ? widget.host.barForeground : "white"
  }

  // Hover and the wheel only: presses reach triggerPress.
  MouseArea {
    id: mouse
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (widget.host) widget.host.showTooltip(widget, widget.tooltip)
    onExited: if (widget.host) widget.host.hideTooltip(widget)
    onWheel: function(event) { if (widget.item) widget.item.scroll(event.angleDelta.y, false) }
  }

  Loader {
    id: menuLoader
    active: widget.menuMade
    sourceComponent: TrayMenu {
      anchorItem: widget
      bar: widget.host
      owner: widget
      item: widget.item
      open: widget.menuOpen
      fontFamily: widget.host ? widget.host.fontFamily : Style.font.family
    }
  }
}
