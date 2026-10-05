import QtQuick
import QtTest
import "../../"

// The Bar page's tiles: rows share one height, Tab jumps between tiles and
// wraps, a switched-off tile is still reachable through its header switch,
// and Reset asks twice before it changes anything.
// Needs Omarchy's kit: -import <dir> where <dir>/qs/{Commons,Ui} link to the
// shell's Commons and Ui folders.
Item {
  id: root
  width: 900; height: 700
  property int resets: 0
  property bool shadow: false

  PrefsBento {
    id: bento
    width: 880
    columns: 12
    gap: 8

    PrefsTile {
      id: first
      title: "Size"
      span12: 6
      PrefsToggle { id: large; compact: true; label: "Large bar" }
      PrefsToggle { compact: true; label: "Animations" }
    }
    PrefsTile {
      id: shadowTile
      title: "Shadow"
      span12: 6
      switchable: true
      switchChecked: root.shadow
      onSwitched: function(checked) { root.shadow = checked }
      resettable: true
      changed: true
      onReset: root.resets++
      PrefsSlider { id: softness; compact: true; label: "Softness"; enabled: root.shadow; animate: false }
    }
    PrefsTile {
      id: last
      title: "Behavior"
      span12: 12
      PrefsToggle { id: autohide; compact: true; label: "Autohide" }
    }
  }

  TestCase {
    name: "PrefsBento"
    when: windowShown

    function init() {
      root.resets = 0
      root.shadow = false
      shadowTile.confirming = false
      large.forceActiveFocus()
      wait(0)
    }

    function test_rowsShareHeightAndFillTheWidth() {
      tryCompare(bento, "implicitHeight", Math.max(first.implicitHeight, shadowTile.implicitHeight) + 8 + last.implicitHeight)
      compare(first.height, shadowTile.height)
      compare(first.width, (880 - 8) / 2)
      compare(shadowTile.x, first.width + 8)
      compare(last.width, 880)
    }

    function test_tabJumpsTilesAndWraps() {
      keyClick(Qt.Key_Tab)
      // Shadow is off, so its slider is skipped and Tab lands on the header switch.
      verify(bento.tileOf(bento.Window.activeFocusItem) === shadowTile)
      verify(!softness.activeFocus)
      keyClick(Qt.Key_Tab)
      verify(autohide.activeFocus)
      keyClick(Qt.Key_Tab)
      verify(large.activeFocus, "wraps to the first tile")
      keyClick(Qt.Key_Backtab)
      verify(autohide.activeFocus, "Shift+Tab wraps back")
    }

    function test_everyShiftTabFormGoesBack_data() {
      return [
        { tag: "Backtab", key: Qt.Key_Backtab, mods: Qt.NoModifier },
        { tag: "Shift+Backtab", key: Qt.Key_Backtab, mods: Qt.ShiftModifier },
        { tag: "Shift+Tab", key: Qt.Key_Tab, mods: Qt.ShiftModifier }
      ]
    }
    function test_everyShiftTabFormGoesBack(data) {
      keyClick(Qt.Key_Tab)
      keyClick(Qt.Key_Tab)
      verify(autohide.activeFocus)
      keyClick(data.key, data.mods)
      verify(bento.tileOf(bento.Window.activeFocusItem) === shadowTile)
    }

    function test_headerSwitchTurnsTheTileOn() {
      keyClick(Qt.Key_Tab)
      keyClick(Qt.Key_Space)
      verify(root.shadow)
      verify(softness.enabled)
    }

    function test_resetAsksTwice() {
      softness.enabled = true
      root.shadow = true
      softness.forceActiveFocus()
      keyClick(Qt.Key_R)
      compare(root.resets, 0)
      verify(shadowTile.confirming)
      keyClick(Qt.Key_R)
      compare(root.resets, 1)
      verify(!shadowTile.confirming)
    }

    function test_resetIsOnlyOfferedWhileChanged() {
      shadowTile.changed = false
      compare(shadowTile.tileHints.length, 0)
      shadowTile.askReset()
      shadowTile.askReset()
      compare(root.resets, 0)
      shadowTile.changed = true
    }
  }
}
