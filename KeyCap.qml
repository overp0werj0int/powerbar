import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A key legend, as printed on a keycap.
BorderSurface {
  id: cap
  property string text: ""
  property color foreground: Commons.Color.popups.text
  implicitWidth: Math.max(implicitHeight, label.implicitWidth + Style.space(10))
  // From the font, not the text: arrows come from a fallback font with a
  // taller line, and caps of one row must share one height.
  implicitHeight: Math.ceil(metrics.height) + Style.space(4)
  radius: Math.min(Style.cornerRadius, Style.space(4))
  color: Qt.alpha(foreground, 0.07)
  borderSpec: Border.flat(Qt.alpha(foreground, 0.22), 1)
  Accessible.ignored: true
  FontMetrics { id: metrics; font: label.font }
  GrayText {
    id: label
    // On the font's baseline, centred as the font's line would be: a fallback
    // glyph's taller line would lift the text off its neighbours' baseline.
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round((cap.height - metrics.height) / 2 + metrics.ascent - baselineOffset)
    text: cap.text
    textFormat: Text.PlainText
    color: cap.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
