import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// The key legend at a page's bottom left (docs/behavior/preferences.md
// PREFS-103): a column of keycaps and what each does for whatever has
// focus, one line each. The keys' column is as wide on every page (the
// widest set any page shows, Shift with h j k l), so the words start in the
// same place whichever page is up.
GridLayout {
  id: legend
  // [{ keys: "h l", label }]: keys split on spaces into caps.
  property var lines: []
  columns: 2
  columnSpacing: Gap.l
  rowSpacing: Gap.s
  // The widest keys a page shows, measured, not laid out.
  Row {
    id: widest
    visible: false
    spacing: Gap.xs
    Repeater {
      model: ["shift", "h", "j", "k", "l"]
      KeyCap {
        required property string modelData
        text: modelData
      }
    }
  }
  Repeater {
    model: legend.lines
    Row {
      id: keysRow
      required property var modelData
      required property int index
      Layout.row: index
      Layout.column: 0
      Layout.minimumWidth: widest.implicitWidth
      spacing: Gap.xs
      Repeater {
        model: String(keysRow.modelData.keys).split(" ")
        KeyCap {
          required property string modelData
          text: modelData
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        }
      }
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
