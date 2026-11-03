import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A tray icon's menu, drawn as Omarchy's tray draws it (plugins/bar/widgets/
// Tray.qml): a popup card of rows, submenus opened in place with a way back.
// Omarchy's shell runs without QApplication, so the platform menu an app
// would show (QsMenuEntry.display) never appears; each submenu level keeps its
// own QsMenuOpener instead, owned by its parent's model.
PopupCard {
  id: card
  // The icon's tray item, and the colour and font of the bar it sits on.
  property var item: null
  property color foreground: Commons.Color.popups.text
  property string fontFamily: Style.font.family

  property var submenuStack: []
  readonly property int depth: submenuStack.length
  readonly property string currentTitle: depth > 0 ? submenuStack[depth - 1].title : ""
  readonly property var currentChildren: depth > 0 ? submenuStack[depth - 1].opener.children : rootOpener.children
  // A level change rebuilds the rows under a still pointer; a second click
  // meant for the old row would fire the new one.
  property bool settling: false

  function settle() { settling = true; settleTimer.restart() }
  function reset() {
    settling = false
    settleTimer.stop()
    flick.contentY = 0
    // Deepest first: an inner opener's entry belongs to its parent's model.
    var openers = submenuStack
    submenuStack = []
    for (var i = openers.length - 1; i >= 0; i--) openers[i].opener.destroy()
  }
  function enter(entry, title) {
    var opener = openerComponent.createObject(card, { menu: entry })
    if (!opener) return
    submenuStack = submenuStack.concat([{ opener: opener, title: title }])
    settle()
  }
  function leave() {
    if (!depth) return
    var stack = submenuStack.slice()
    var top = stack.pop()
    submenuStack = stack
    top.opener.destroy()
    settle()
  }

  // On properties: the card's own children must be items.
  readonly property Component openerComponent: Component { QsMenuOpener {} }
  readonly property Timer settleTimer: Timer { interval: 250; onTriggered: card.settling = false }
  readonly property QsMenuOpener rootOpener: QsMenuOpener { menu: card.item ? card.item.menu : null }

  // Reset once the fade has finished, so a submenu does not flash back to the
  // root menu on its way out.
  onVisibleChanged: if (!visible) reset()
  padding: Style.space(8)
  borderColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.45)
  contentWidth: fittedContentWidth(Style.space(232))
  contentHeight: fittedContentHeight(headerHeight + rows.implicitHeight, Style.space(420))
  readonly property int headerHeight: header.visible ? header.implicitHeight : 0

  Column {
    id: layout
    anchors.fill: parent

    // A submenu's title, which walks back out; it stays above the rows.
    Column {
      id: header
      visible: card.depth > 0
      width: layout.width
      Item {
        width: header.width
        implicitHeight: Style.space(30)
        Rectangle {
          anchors.fill: parent
          radius: Math.max(2, Style.cornerRadius)
          color: backMouse.containsMouse ? Style.hoverFillFor(card.foreground, card.foreground) : "transparent"
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(22)
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: Commons.I18n.rightToLeft ? "›" : "‹"
          color: card.foreground
          font.family: card.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(28)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          textFormat: Text.PlainText
          text: card.currentTitle
          color: card.foreground
          font.family: card.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
        MouseArea {
          id: backMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (card.settling) return
            flick.contentY = 0
            card.leave()
          }
        }
      }
      Separator { width: header.width }
    }

    Flickable {
      id: flick
      width: layout.width
      height: layout.height - card.headerHeight
      contentWidth: width
      contentHeight: rows.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: rows
        width: flick.width
        Repeater {
          model: card.currentChildren
          delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property string label: String(modelData.text || "")
            readonly property string appTitle: card.item ? String(card.item.title || card.item.id || "") : ""
            // At the root, a first row repeating the app's name and a
            // leading separator say nothing; Omarchy's tray drops them too.
            readonly property bool skipped: card.depth === 0 && ((index === 0 && modelData.hasChildren
              && label.toLowerCase() === appTitle.toLowerCase()) || (modelData.isSeparator && index <= 1))
            visible: !skipped
            width: rows.width
            implicitHeight: skipped ? 0 : modelData.isSeparator ? Style.space(11) : Style.space(30)
            opacity: modelData.enabled ? 1 : 0.45

            Separator { visible: row.modelData.isSeparator; width: row.width; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
              visible: !row.modelData.isSeparator
              anchors.fill: parent
              radius: Math.max(2, Style.cornerRadius)
              color: rowMouse.containsMouse && row.modelData.enabled ? Style.hoverFillFor(card.foreground, card.foreground) : "transparent"
            }
            Text {
              visible: !row.modelData.isSeparator && row.modelData.buttonType !== QsMenuButtonType.None
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(22)
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: row.modelData.checkState === Qt.Checked ? "" : ""
              color: card.foreground
              font.family: card.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Image {
              id: rowIcon
              visible: !row.modelData.isSeparator && String(row.modelData.icon || "") !== ""
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(24)
              width: Style.space(16)
              height: Style.space(16)
              fillMode: Image.PreserveAspectFit
              sourceSize.width: width * Screen.devicePixelRatio
              sourceSize.height: height * Screen.devicePixelRatio
              source: row.modelData.icon
            }
            Text {
              visible: !row.modelData.isSeparator
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: rowIcon.visible ? Style.space(46) : Style.space(28)
              anchors.right: chevron.left
              anchors.rightMargin: Style.space(8)
              textFormat: Text.PlainText
              text: row.label
              color: card.foreground
              font.family: card.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
            Text {
              id: chevron
              visible: !row.modelData.isSeparator && row.modelData.hasChildren
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              textFormat: Text.PlainText
              text: Commons.I18n.rightToLeft ? "‹" : "›"
              color: card.foreground
              font.family: card.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: !row.modelData.isSeparator && row.modelData.enabled
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                if (card.settling) return
                if (row.modelData.hasChildren) {
                  // Before the model swap destroys this row.
                  flick.contentY = 0
                  card.enter(row.modelData, row.label)
                } else {
                  row.modelData.triggered()
                  card.close()
                }
              }
            }
          }
        }
      }
    }
  }

  component Separator: Item {
    implicitHeight: Style.space(11)
    Rectangle {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: 1
      color: Commons.Color.popups.border
      opacity: 0.45
    }
  }
}
