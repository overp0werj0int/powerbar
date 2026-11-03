import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// The key legend at a page's bottom left (docs/behavior/preferences.md
// PREFS-103): a column of keycaps and what each does for whatever has
// focus, one line each. Plain cursor movement is left out: the arrows (and
// their vim letters) only get a line where they do more: a lifted widget's
// move, Shift's move, a fader's value, the Center dot's side. Space parts alternatives ("enter esc"), "+" joins
// a combination ("shift+tab" as shift + tab); the arrows share one cap,
// ← ↑ → ↓ as the bar's keyboard mode draws them (BarKeysModel.arrowCap). The
// keys' column is as wide on every page (the widest set a page shows), so
// the words start in the same place whichever page is up.
GridLayout {
  id: legend
  // [{ keys: "tab shift+tab", label }].
  property var lines: []
  component Keys: Row {
    property string keys: ""
    spacing: Gap.xs
    Repeater {
      model: keys.split(" ")
      KeyCombo {
        required property string modelData
        // A thin space parts arrows in one cap: side by side the font
        // joins ← → into ↔.
        keys: modelData.split("+").map(function (k) {
          return /^[←↑→↓]+$/.test(k) ? k.split("").join("\u2009") : k;
        })
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      }
    }
  }
  columns: 2
  columnSpacing: Gap.l
  rowSpacing: Gap.s
  // The widest keys a page shows, measured, not laid out.
  Column {
    id: widest
    visible: false
    Repeater {
      model: ["tab shift+tab", "shift+←↑→↓", "enter esc"]
      Keys {
        required property string modelData
        keys: modelData
      }
    }
  }
  Repeater {
    model: legend.lines
    Keys {
      required property var modelData
      required property int index
      Layout.row: index
      Layout.column: 0
      Layout.minimumWidth: widest.implicitWidth
      keys: String(modelData.keys)
    }
  }
  Repeater {
    model: legend.lines
    InkText {
      required property var modelData
      required property int index
      Layout.row: index
      Layout.column: 1
      Layout.fillWidth: true
      text: modelData.label
      role: "caption"
      elide: Text.ElideRight
    }
  }
}
