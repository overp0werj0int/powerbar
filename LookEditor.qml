import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "AppearanceModel.js" as AppearanceModel

// The Look page (docs/behavior/preferences.md PREFS-130): the bar's style
// and place, size, shape, surface, shadow and, on a machine with a notched
// screen, the notch, as strips on a desk (DeskPage), every change showing on
// the bar above the page at once. While the Notch style draws, what cannot
// apply gives way (PREFS-96): Large bar and the Shape and Surface strips.
DeskPage {
  id: look
  pageLines: [
    {
      keys: "j k",
      label: "Down the strip, on to the next"
    },
    {
      keys: "h l",
      label: "Less, more on a fader; chip to chip, then the next strip"
    },
    {
      keys: "space",
      label: "Toggle, or choose"
    },
    {
      keys: "tab",
      label: "Next strip"
    },
    {
      keys: "backspace",
      label: "Back to the theme's value"
    },
    {
      keys: "4",
      label: "Behavior: how the bar comes, goes and answers keys"
    }
  ]

  // A strip's Scope choice (PREFS-73) and the line under it.
  component ScopeChoice: DeskChoice {
    property string tile: ""
    options: [
      {
        value: "theme",
        label: "Theme"
      },
      {
        value: "all",
        label: "Everywhere"
      },
      {
        value: "this",
        label: "Just here"
      }
    ]
    value: look.preferences.scopeOf(tile)
    Accessible.name: tile.charAt(0).toUpperCase() + tile.slice(1) + " values"
    onChosen: function (value) {
      look.preferences.setScope(tile, value);
    }
  }
  component Caption: GrayText {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    color: Qt.alpha(Commons.Color.popups.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
  component ScopeHint: Caption {
    property string tile: ""
    // Close under its chips.
    Layout.topMargin: -Style.space(5)
    text: look.preferences.scopeHint(tile)
    Accessible.name: text
  }
  readonly property string themeValue: "Back to the theme's value"
  // A pick-one row with no caption: one line, its ring filled when chosen.
  component PickRow: DeskRow {
    property string option: ""
    property string current: ""
    pick: true
    spaceHint: "Choose it"
    checked: option === current
  }

  // ------------------------------------------------------------ 1 Style
  DeskStrip {
    id: styleStrip
    readonly property string style: look.bar ? (look.bar.notchStyle ? "notch" : look.bar.barStyle) : "flat"
    title: "Style"
    caption: style === "islands" ? "A surface for each zone" : style === "floating" ? "One bar, off the edges" : style === "notch" ? "Notch applies on the top edge of the notched screen; elsewhere it draws as islands" : "Edge to edge, like Omarchy"
    footnote: "No scope: the bar sits in one place in every theme."
    DeskPickGroup {
      PickRow {
        label: "Flat"
        option: "flat"
        current: styleStrip.style
        onActivated: look.preferences.setBarStyle(option)
      }
      PickRow {
        label: "Floating"
        option: "floating"
        current: styleStrip.style
        onActivated: look.preferences.setBarStyle(option)
      }
      PickRow {
        label: "Islands"
        option: "islands"
        current: styleStrip.style
        onActivated: look.preferences.setBarStyle(option)
      }
      // Notch is offered where a screen has one, or while it is in use.
      PickRow {
        visible: !!look.bar && (look.bar.screenNotch || look.bar.notchStyle)
        label: "Notch"
        option: "notch"
        current: styleStrip.style
        onActivated: look.preferences.setBarStyle(option)
      }
    }
    Caption {
      text: "Screen edge"
      color: Qt.alpha(Commons.Color.popups.text, 0.7)
    }
    DeskChoice {
      Layout.topMargin: -Style.space(5)
      options: [
        {
          value: "top",
          label: "Top"
        },
        {
          value: "bottom",
          label: "Bottom"
        },
        {
          value: "left",
          label: "Left"
        },
        {
          value: "right",
          label: "Right"
        }
      ]
      value: look.bar ? look.bar.position : "top"
      Accessible.name: "Screen edge"
      onChosen: function (value) {
        look.preferences.setOption("position", value);
      }
    }
  }

  // ------------------------------------------------------------- 2 Size
  DeskStrip {
    title: "Size"
    // The notch's bar is always as tall as the camera.
    DeskRow {
      visible: !look.preferences.notchMode
      label: "Large bar"
      checked: look.bar ? look.bar.largeBar : false
      onActivated: look.preferences.setOption("powerbarLargeBar", !checked)
    }
    DeskPickGroup {
      PickRow {
        label: "Equal slots"
        option: "slots"
        current: look.bar ? look.bar.spacingMode : "slots"
        onActivated: look.preferences.setOption("powerbarSpacingMode", option)
      }
      PickRow {
        label: "Equal gaps"
        option: "gaps"
        current: look.bar ? look.bar.spacingMode : "slots"
        onActivated: look.preferences.setOption("powerbarSpacingMode", option)
      }
    }
    faders: [
      Fader {
        label: "Widget spacing"
        minimum: look.preferences.ranges.spacing.min
        maximum: look.preferences.ranges.spacing.max
        stepSize: look.preferences.ranges.spacing.step
        defaultValue: look.preferences.ranges.spacing.fallback
        value: AppearanceModel.clampTo(look.preferences.ranges.spacing, look.preferences.config.powerbarSpacing)
        formatter: function (v) {
          return v === 0 ? "None" : "";
        }
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setOption("powerbarSpacing", v);
        }
      }
    ]
  }

  // ------------------------------------------------------------ 3 Shape
  // The notch's zones take the camera's corners and have no border: nothing
  // here applies to them.
  DeskStrip {
    id: shapeStrip
    readonly property bool editable: look.preferences.scopeOf("shape") !== "theme"
    readonly property bool borders: look.preferences.lookValue("borders") !== false
    visible: !look.preferences.notchMode
    title: "Shape"
    ScopeChoice {
      tile: "shape"
    }
    ScopeHint {
      tile: "shape"
    }
    DeskRow {
      label: "Borders"
      enabled: shapeStrip.editable
      checked: shapeStrip.borders
      onActivated: look.preferences.setLook("shape", "borders", !checked)
    }
    faders: [
      Fader {
        readonly property real themeRounding: Style.cornerRadius / Style.spacing.scale
        enabled: shapeStrip.editable
        label: "Corner rounding"
        minimum: 0
        maximum: look.bar ? look.bar.roundingMax : 16
        stepSize: 1
        defaultValue: Math.min(maximum, Math.round(themeRounding))
        defaultLabel: look.themeValue
        value: typeof look.preferences.lookValue("rounding") === "number" ? look.preferences.lookValue("rounding") : themeRounding
        formatter: function (v) {
          return v === 0 ? "Square" : v >= maximum ? "Pill" : "";
        }
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setLook("shape", "rounding", v);
        }
      },
      Fader {
        readonly property real themeWidth: look.bar ? Border.top(look.bar.themeIslandBorder) / Style.space(1) : 1
        label: "Border thickness"
        minimum: look.preferences.ranges.borderWidth.min
        maximum: look.preferences.ranges.borderWidth.max
        stepSize: look.preferences.ranges.borderWidth.step
        defaultValue: themeWidth
        defaultLabel: look.themeValue
        enabled: shapeStrip.editable && shapeStrip.borders
        value: AppearanceModel.clampTo(look.preferences.ranges.borderWidth, look.preferences.lookValue("borderWidth"), themeWidth)
        formatter: function (v) {
          return v === look.preferences.ranges.borderWidth.min ? "Hairline" : "";
        }
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setLook("shape", "borderWidth", v);
        }
      }
    ]
  }

  // ---------------------------------------------------------- 4 Surface
  DeskStrip {
    id: surfaceStrip
    readonly property bool editable: look.preferences.scopeOf("surface") !== "theme"
    visible: !look.preferences.notchMode
    title: "Surface"
    ScopeChoice {
      tile: "surface"
    }
    ScopeHint {
      tile: "surface"
    }
    DeskRow {
      label: "Background blur"
      enabled: surfaceStrip.editable
      checked: look.bar ? look.bar.surfaceEffects.blur : false
      onActivated: look.preferences.setLook("surface", "blur", !checked)
    }
    // Kept per theme in every scope: a light or dark choice can't be shared
    // between light and dark themes.
    Caption {
      text: "Text and icons"
      color: Qt.alpha(Commons.Color.popups.text, 0.7)
    }
    DeskChoice {
      Layout.topMargin: -Style.space(5)
      options: [
        {
          value: "theme",
          label: "Theme"
        },
        {
          value: "light",
          label: "Light"
        },
        {
          value: "dark",
          label: "Dark"
        }
      ]
      value: look.bar ? look.bar.foregroundChoice : "theme"
      Accessible.name: "Text and icons"
      onChosen: function (value) {
        look.preferences.setText(value);
      }
    }
    faders: [
      Fader {
        enabled: surfaceStrip.editable
        label: "Background opacity"
        unit: "%"
        minimum: look.preferences.ranges.backgroundOpacity.min
        maximum: look.preferences.ranges.backgroundOpacity.max
        stepSize: look.preferences.ranges.backgroundOpacity.step
        defaultValue: look.preferences.ranges.backgroundOpacity.fallback
        // A transparent bar (Omarchy's Transparency) shows as Clear, a glassy
        // one as the opacity it draws.
        value: !look.bar ? 100 : Math.round(AppearanceModel.barOpacity(look.bar.surfaceEffects, false, look.bar.requestedTransparent, look.bar.glassy) * 100)
        formatter: function (v) {
          return v === 0 ? "Clear" : v === 100 ? "Opaque" : "";
        }
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setLook("surface", "opacity", v);
        }
      },
      // The floor of the surfaces Powerbar draws over windows: drawers,
      // menus, the key legend, tooltips (AppearanceModel.overlayOpacity).
      Fader {
        enabled: surfaceStrip.editable
        label: "Over windows"
        unit: "%"
        minimum: look.preferences.ranges.overWindows.min
        maximum: look.preferences.ranges.overWindows.max
        stepSize: look.preferences.ranges.overWindows.step
        defaultValue: look.preferences.ranges.overWindows.fallback
        value: look.bar ? Math.round(look.bar.surfaceEffects.overWindows * 100) : look.preferences.ranges.overWindows.fallback
        formatter: function (v) {
          return v === 0 ? "As the bar" : v === 100 ? "Opaque" : "";
        }
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setLook("surface", "overWindows", v);
        }
      }
    ]
  }

  // ----------------------------------------------------------- 5 Shadow
  DeskStrip {
    id: shadowStrip
    readonly property bool editable: look.preferences.scopeOf("shadow") !== "theme"
    readonly property bool shadowOn: !!look.bar && look.bar.surfaceEffects.shadow
    title: "Shadow"
    ScopeChoice {
      tile: "shadow"
    }
    ScopeHint {
      tile: "shadow"
    }
    DeskRow {
      label: "Shadow"
      enabled: shadowStrip.editable
      checked: shadowStrip.shadowOn
      onActivated: look.preferences.setLook("shadow", "enabled", !checked)
    }
    faders: [
      Fader {
        label: "Softness"
        minimum: look.preferences.ranges.shadowSize.min
        maximum: look.preferences.ranges.shadowSize.max
        stepSize: look.preferences.ranges.shadowSize.step
        defaultValue: look.preferences.ranges.shadowSize.fallback
        enabled: shadowStrip.editable && shadowStrip.shadowOn
        value: look.bar ? look.bar.surfaceEffects.shadowSize : look.preferences.ranges.shadowSize.fallback
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setLook("shadow", "softness", v);
        }
      },
      Fader {
        label: "Strength"
        unit: "%"
        minimum: look.preferences.ranges.shadowOpacity.min
        maximum: look.preferences.ranges.shadowOpacity.max
        stepSize: look.preferences.ranges.shadowOpacity.step
        defaultValue: look.preferences.ranges.shadowOpacity.fallback
        enabled: shadowStrip.editable && shadowStrip.shadowOn
        value: look.bar ? Math.round(look.bar.surfaceEffects.shadowOpacity * 100) : look.preferences.ranges.shadowOpacity.fallback
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setLook("shadow", "strength", v);
        }
      }
    ]
  }

  // ------------------------------------------------------------ 6 Notch
  // The Notch style's ears blend into the camera, which takes the place of
  // Surface (black, no blur there). In every style the camera's size places
  // the center and the large bar. Its default (Backspace) is the measured
  // or detected size, written as no setting at all; the action row puts
  // both faders back to it at once, and dims while they are there.
  DeskStrip {
    id: notchStrip
    readonly property var notch: look.bar ? look.bar.screenNotch : null
    readonly property bool sized: !!look.preferences.options.notchWidth || !!look.preferences.options.notchHeight
    visible: !!notch
    title: "Notch"
    caption: look.preferences.notchMode ? "Black, like the camera" : "The camera's size"
    DeskRow {
      action: true
      label: "Back to the camera's size"
      caption: notchStrip.notch ? "Measured " + notchStrip.notch.housing + " \u00d7 " + notchStrip.notch.detectedHeight + " px" : ""
      spaceHint: "Put both back"
      enabled: notchStrip.sized
      onActivated: look.preferences.clearOptions(["powerbarNotchWidth", "powerbarNotchHeight"])
    }
    faders: [
      Fader {
        label: "Width"
        unit: "px"
        minimum: 40
        maximum: 600
        stepSize: 1
        defaultValue: notchStrip.notch ? notchStrip.notch.housing : 191
        defaultLabel: "Back to the camera's size"
        value: notchStrip.notch ? notchStrip.notch.width : (look.preferences.options.notchWidth || 191)
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setOption("powerbarNotchWidth", v === defaultValue ? undefined : v);
        }
      },
      Fader {
        label: "Height"
        unit: "px"
        minimum: 16
        maximum: 96
        stepSize: 1
        defaultValue: notchStrip.notch ? notchStrip.notch.detectedHeight : 32
        defaultLabel: "Back to the camera's size"
        value: notchStrip.notch ? notchStrip.notch.height : 32
        animate: look.preferences.motion
        onEdited: function (v) {
          look.preferences.setOption("powerbarNotchHeight", v === defaultValue ? undefined : v);
        }
      }
    ]
  }
}
