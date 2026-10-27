import QtQuick

// Text for Preferences (and the key legend's caps): Qt Quick's default text,
// distance fields, antialiases with LCD subpixels on desktop GPUs whatever
// the window, so on Powerbar's translucent windows grey text took blue and
// orange fringes. Curve rendering antialiases in grey and stays sharp on the
// tilted plates (PREFS-102).
Text {
  renderType: Text.CurveRendering
}
