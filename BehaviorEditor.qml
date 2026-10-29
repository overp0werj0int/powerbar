import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// The Behavior page (docs/behavior/preferences.md PREFS-131): how the bar
// comes and goes, where on-demand widgets show, and its keyboard, as three
// strips of rows on a desk (DeskPage). Every control is a row, so h/l go to
// the same row of the next strip. While the Notch style draws, Readable
// over windows and In a drawer give way (PREFS-96).
DeskPage {
  id: behavior
  // Where the first start's notification and the keyboard mode's opener put
  // the cursor (KEYS-66, KEYS-84).
  readonly property Item keyboardRow: barKeysRow
  pageLines: [
    {
      keys: "j k",
      label: "Down the strip, on to the next"
    },
    {
      keys: "h l",
      label: "Same row, next strip"
    },
    {
      keys: "space",
      label: "Turn it on, or choose it"
    },
    {
      keys: "enter",
      label: "Record the shortcut"
    },
    {
      keys: "tab",
      label: "Next strip"
    },
    {
      keys: "3",
      label: "Look: style, size, shape, surface, shadow, notch"
    }
  ]

  component Hairline: Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: Qt.alpha(Commons.Color.popups.text, 0.12)
  }
  // A shortcut row as a desk control: one stop, its cursor in the desk's look.
  component DeskShortcut: ShortcutRow {
    readonly property int deskStops: 1
    readonly property int deskHome: 0
    function deskFocus(stop, reason) {
      forceActiveFocus(reason === undefined ? Qt.OtherFocusReason : reason);
    }
    store: behavior.preferences.shortcuts
    suggested: behavior.preferences.shortcuts.suggested(target)
    cursor: activeFocus
    padding: Style.space(8)
    activeFocusOnTab: false
    Layout.leftMargin: -Style.space(8)
    Layout.rightMargin: -Style.space(8)
  }

  // ---------------------------------------------------- 1 Comes and goes
  DeskStrip {
    title: "Comes and goes"
    caption: "When the bar shows itself, and how it moves."
    DeskRow {
      label: "Autohide"
      caption: "The bar slides away; the pointer at the edge, or the keyboard, brings it back."
      checked: behavior.preferences.options.autoHide
      onActivated: behavior.preferences.setOption("powerbarAutoHide", !checked)
    }
    // Peeks on an autohidden bar and on one switched off (Super+Shift+Space),
    // so it holds whether Autohide is on.
    DeskRow {
      label: "Show on widget activity"
      caption: "A hidden bar peeks for a moment when a widget changes, with that widget lit."
      checked: behavior.preferences.options.autoHideActivity
      onActivated: behavior.preferences.setOption("powerbarAutoHideActivity", !checked)
    }
    // Powerbar's safety minimum for surfaces over windows, not a theme value,
    // so it stays outside the appearance scopes. The notch is always opaque,
    // so it has nothing to raise there.
    DeskRow {
      visible: !behavior.preferences.notchMode
      label: "Readable over windows"
      caption: "A darker surface whenever a window sits under the bar."
      checked: behavior.bar ? behavior.bar.surfaceEffects.readableOverlay : true
      onActivated: behavior.preferences.setOption("powerbarReadableOverlay", !checked)
    }
    DeskRow {
      label: "Animations"
      caption: "Drawers, drops and peeks move. Off, they snap, and nothing runs each frame."
      checked: behavior.bar ? behavior.bar.animationsEnabled : true
      onActivated: behavior.preferences.setOption("powerbarAnimations", !checked)
    }
    // Preferences' own look, apart from the bar's motion: the exploded
    // view's tilt (PREFS-99), flat for a plainer page.
    DeskRow {
      label: "Pages in perspective"
      caption: "Preferences draws its pages as plates tilted back. Off, they lie flat."
      checked: behavior.preferences.options.preferencesTilt
      onActivated: behavior.preferences.setOption("powerbarPreferencesTilt", !checked)
    }
  }

  // --------------------------------------------------------- 2 On demand
  // The notch has no drawers: there the choice is the bar or a menu, and a
  // saved drawer shows as the bar.
  DeskStrip {
    id: onDemand
    readonly property string shown: behavior.preferences.notchMode && behavior.preferences.options.onDemand === "drawer" ? "inline" : behavior.preferences.options.onDemand
    title: "On demand"
    caption: "Widgets behind a zone's dots. Where they show when asked."
    DeskRow {
      visible: !behavior.preferences.notchMode
      pick: true
      label: "In a drawer"
      caption: "Hovering a zone's dots opens a drawer under the bar."
      checked: onDemand.shown === "drawer"
      onActivated: behavior.preferences.setOption("powerbarOnDemand", "drawer")
    }
    DeskRow {
      pick: true
      label: "In the bar"
      caption: "The dots expand into the bar, in place."
      checked: onDemand.shown === "inline"
      onActivated: behavior.preferences.setOption("powerbarOnDemand", "inline")
    }
    DeskRow {
      pick: true
      label: "In a menu"
      caption: "The dots open a menu of them, groups as submenus."
      checked: onDemand.shown === "menu"
      onActivated: behavior.preferences.setOption("powerbarOnDemand", "menu")
    }
    Hairline {}
    DeskRow {
      label: "Count on the dots"
      caption: "Each dot shows how many widgets wait behind it."
      checked: behavior.preferences.options.dotsBadge
      onActivated: behavior.preferences.setOption("powerbarDotsBadge", !checked)
    }
  }

  // ---------------------------------------------------------- 3 Keyboard
  // The keyboard mode (docs/behavior/keyboard.md): its shortcuts (offered,
  // never bound until taken here; KEYS-84) and its strip of keys.
  DeskStrip {
    title: "Keyboard"
    caption: "Shortcuts bound in Hyprland. Enter on a row records a new one."
    DeskShortcut {
      id: barKeysRow
      label: "Bar keyboard"
      caption: "h l walk the bar, Enter opens, Shift drags"
      target: "bar:keys"
    }
    DeskShortcut {
      label: "Bar search"
      caption: "Type a widget's name to reach it"
      target: "bar:search"
    }
    Hairline {}
    DeskRow {
      label: "Key legend"
      caption: "The keys for the focused thing, shown along the bottom."
      checked: behavior.preferences.options.keyLegend
      onActivated: behavior.preferences.setOption("powerbarKeyLegend", !checked)
    }
  }
}
