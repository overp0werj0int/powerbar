pragma Singleton
import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons

// The type of every Preferences page (docs/design/preferences-design-system.md,
// PREFS-133): four sizes on Omarchy's body size × φ^(n/3), three tiers of
// the text colour on powers of 1/√φ, and every line round(size × φ) tall.
// A label names a control or a thing; a caption explains, counts or hints.
Singleton {
  // n = 3, 1, 0, -1: 19, 14, 12, 10 at the default size.
  readonly property int page: Style.fontPx(1.618)
  readonly property int section: Style.font.title
  readonly property int label: Style.font.body
  readonly property int caption: Style.font.caption
  // Primary is 1; secondary 1/√φ (6.1 : 1 on Cumulus); disabled 1/φ².
  readonly property real secondary: 0.786
  readonly property real disabled: 0.382
  readonly property color text: Commons.Color.popups.text

  function tint(tier) {
    return Qt.alpha(text, tier);
  }
  function line(size) {
    return Math.round(size * 1.618);
  }
  function size(role) {
    return role === "page" ? page : role === "section" ? section : role === "caption" ? caption : label;
  }
}
