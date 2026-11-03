pragma Singleton
import QtQuick
import Quickshell
import qs.Commons

// The corners of every Preferences page (docs/design/preferences-design-system.md,
// PREFS-134): all from the theme's window rounding (Hyprland's
// decoration:rounding), stepped down the Fibonacci ladder so a control is
// never rounder than what holds it. Square on a square theme. Dots, badges
// and switch knobs stay round.
Singleton {
  readonly property int card: Style.cornerRadius
  // Tiles, strips, inspector cards, the pool, the preview box.
  readonly property int container: Math.min(Style.cornerRadius, Style.space(8))
  // Rows, faces, chips, fields, keycaps, zone squares, layer rows, buttons.
  readonly property int control: Math.min(Style.cornerRadius, Style.space(5))
  // The layer parallelogram, a fader's knob.
  readonly property int small: Math.min(Style.cornerRadius, Style.space(3))
}
