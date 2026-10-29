import QtQuick
import qs.Commons

// Text on a Preferences page (Ink, PREFS-133): its role gives the size and
// weight, its tier the colour (a caption is secondary), and every line is
// Ink.line(size) tall. Qt sets a fixed line's glyphs at its top; they are
// moved down by half the extra room, as a browser centres them, so a label
// sits in the middle of its line (the line's box does not move).
GrayText {
  id: ink
  property string role: "label"
  property real tier: role === "caption" ? Ink.secondary : 1
  property bool disabled: false
  textFormat: Text.PlainText
  color: Ink.tint(disabled ? Ink.disabled : tier)
  font.family: Style.font.family
  font.pixelSize: Ink.size(role)
  font.weight: role === "page" ? Font.Bold : role === "section" ? Font.DemiBold : Font.Normal
  lineHeightMode: Text.FixedHeight
  lineHeight: Ink.line(font.pixelSize)
  transform: Translate {
    y: Math.max(0, Math.round((ink.lineHeight - ink.font.pixelSize * 1.32) / 2))
  }
}
