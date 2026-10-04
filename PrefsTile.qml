import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One tile on a bento page: a titled group of related settings, drawn with the
// desktop's window corners. The header can carry the switch that turns the
// tile's subject on (Shadow) and a Reset action, shown only while one of the
// tile's settings differs from the theme. Reset asks twice, by click or with
// r, like Dissolve on Groups, because it changes several values at once.
BorderSurface {
  id: tile
  property string title: ""
  // Columns spanned on a 12- and a 6-column page; one column spans it all.
  property int span12: 12
  property int span6: 6
  property bool switchable: false
  property bool switchChecked: false
  // Reset is offered while this is true.
  property bool changed: false
  property bool resettable: false
  property bool animate: true
  // A short muted line at the header's end: what the tile holds or a notice.
  property string caption: ""
  // A destructive action in the header (Dissolve on Groups), asked twice like
  // Reset: by click, or with actionKey twice within 3 s.
  property string actionText: ""
  property string actionKey: ""
  property bool actionConfirming: false
  // A control at the header's end (a filter, a choice): parent it here.
  readonly property alias headerSlot: headerSlot
  default property alias content: body.data
  signal switched(bool checked)
  signal reset()
  signal action()

  property bool confirming: false
  readonly property bool canReset: resettable && changed
  // Footer keys added while focus is inside this tile.
  readonly property var tileHints: (canReset ? [{ keys: "r", label: confirming ? "Again to reset" : "Reset tile" }] : [])
    .concat(actionText && actionKey ? [{ keys: actionKey, label: actionConfirming ? "Again to " + actionText.toLowerCase() : actionText }] : [])
  readonly property real inset: Math.round(Style.spacing.rowPaddingX / 2)

  function askReset() {
    if (!canReset) return
    if (!confirming) { confirming = true; confirmTimer.restart(); return }
    confirming = false
    confirmTimer.stop()
    reset()
  }
  onCanResetChanged: if (!canReset) confirming = false

  implicitHeight: column.implicitHeight + inset * 2
  color: Qt.alpha(Color.popups.text, 0.035)
  borderSpec: Border.flat(Qt.alpha(Color.popups.text, 0.1), 1)
  radius: Style.cornerRadius
  Accessible.role: Accessible.Grouping
  Accessible.name: title

  Keys.onPressed: function(event) {
    if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return
    if (event.text.toLowerCase() === "r" && tile.canReset) { tile.askReset(); event.accepted = true }
    else if (tile.actionKey && event.text === tile.actionKey && tile.actionText) { tile.action(); event.accepted = true }
  }
  Timer { id: confirmTimer; interval: 3000; onTriggered: tile.confirming = false }

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: tile.inset
    spacing: Style.space(4)

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Style.spacing.rowPaddingX
      Layout.rightMargin: Style.spacing.rowPaddingX - (headSwitch.visible ? headSwitch.pad : 0)
      Layout.topMargin: Style.space(4)
      Layout.minimumHeight: Style.space(26)
      spacing: Style.space(8)
      // Omarchy's panel section header ("OUTPUT", "POWER PROFILE"), so tiles
      // read like the shell's own panels.
      PanelSectionHeader {
        text: tile.title.toUpperCase()
        foreground: Color.popups.text
        Layout.fillWidth: true
        elide: Text.ElideRight
        Accessible.name: tile.title
      }
      Text {
        visible: tile.caption !== ""
        text: tile.caption
        textFormat: Text.PlainText
        color: Qt.alpha(Color.popups.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        Layout.maximumWidth: Math.max(Style.space(120), tile.width * 0.6)
      }
      Item {
        id: headerSlot
        visible: children.length > 0
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        Layout.alignment: Qt.AlignVCenter
      }
      // Pointer only; keyboard users press r inside the tile.
      Button {
        visible: tile.canReset
        text: tile.confirming ? "Again to reset" : "Reset"
        tooltipText: tile.confirming ? "" : "Return this tile to the theme's values"
        bordered: true
        foreground: tile.confirming ? Color.urgent : Color.popups.text
        fontSize: Style.font.caption
        verticalPadding: Style.space(2)
        horizontalPadding: Style.space(8)
        onClicked: tile.askReset()
      }
      Button {
        visible: tile.actionText !== ""
        text: tile.actionConfirming ? "Again to " + tile.actionText.toLowerCase() : tile.actionText
        bordered: true
        foreground: tile.actionConfirming ? Color.urgent : Color.popups.text
        fontSize: Style.font.caption
        verticalPadding: Style.space(2)
        horizontalPadding: Style.space(8)
        onClicked: tile.action()
      }
      // The tile's own switch: one Tab stop, Space or Enter flips it.
      Item {
        id: headSwitch
        readonly property real pad: Style.space(3)
        visible: tile.switchable
        implicitWidth: switchTrack.implicitWidth + pad * 2
        implicitHeight: switchTrack.implicitHeight + pad * 2
        activeFocusOnTab: visible
        Accessible.role: Accessible.CheckBox
        Accessible.name: tile.title
        Accessible.checked: tile.switchChecked
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            tile.switched(!tile.switchChecked)
            event.accepted = true
          }
        }
        ToggleSwitch {
          id: switchTrack
          anchors.centerIn: parent
          checked: tile.switchChecked
          cursorRing: false
          foreground: Color.popups.text
          onToggled: { headSwitch.forceActiveFocus(Qt.MouseFocusReason); tile.switched(!tile.switchChecked) }
        }
      }
    }

    ColumnLayout {
      id: body
      Layout.fillWidth: true
      spacing: Style.space(2)
    }
  }
}
