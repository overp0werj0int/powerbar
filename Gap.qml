pragma Singleton
import QtQuick
import Quickshell
import qs.Commons

// The spacing of every Preferences page (docs/design/preferences-design-system.md,
// PREFS-133): Fibonacci numbers through Style.space, one per level of a
// page's structure, so things sit as close as they are related.
Singleton {
  // A text pair: label ↔ caption, title ↔ caption, field label ↔ control ↔ hint.
  readonly property int xxs: Style.space(2)
  // Siblings in one group (pick rows, chips, rows in a zone, keys of a combo);
  // a control's vertical padding.
  readonly property int xs: Style.space(3)
  // Inside a control: its side padding, keycap ↔ word, zone name ↔ its rows.
  readonly property int s: Style.space(5)
  // Controls and fields in a strip or an inspector column; tile padding;
  // dot or icon ↔ label.
  readonly property int m: Style.space(8)
  // A strip's padding and blocks; zone ↔ zone; a hairline's room each side.
  readonly property int l: Style.space(13)
  // Strip ↔ strip, layer ↔ layer, card and inspector padding.
  readonly property int xl: Style.space(21)
  // Header ↔ desk or plates; page title ↔ tabs.
  readonly property int xxl: Style.space(34)
  // The card's side inset.
  readonly property int xxxl: Style.space(55)
  // Every control is a label line and xs above and below (25); a row
  // holding Omarchy's 22 px switch is that and xs (28).
  readonly property int control: Ink.line(Ink.label) + 2 * xs
  readonly property int switchRow: Style.space(22) + 2 * xs
}
