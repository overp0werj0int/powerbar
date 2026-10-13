# Changelog

## Unreleased

- **Zone modes: three zones, two, or Notch.** Preferences > Layout now has
  three modes, and each keeps its own arrangement (where each widget sits,
  in what order, and whether it's on the bar, on demand or hidden). Switching
  back finds a mode as you left it. Two zones drop the centre: everything sits
  left or right of a gap one notch wide (Bar > Notch > Notch width; 185 px by
  default). The first time you use a two-zone mode, the centre splits at the
  clock, and the clock and keyboard layout move beside the Preferences button.
  `omarchy-shell powerbar set zones three|two|notch`.
- **Notch**: on a MacBook screen Omarchy describes as notched
  (`display-cutouts.json`), two black zones grow out of the camera. They are
  flush with the top, rounded at their outer ends, and the large bar is
  exactly as tall as the notch.
  - With autohide, pointing at the camera makes each zone spring out of it
    sideways, and an activity peek brings out only the zone that changed.
  - On-demand widgets expand in the bar (the notch has no drawers). A zone
    that outgrows the screen wraps onto a second row at the edge, one black
    shape with the first.
  - On the Bar page, Style, Surface, Shadow and borders give way to the Notch
    tile.
  - Other screens show the same two black zones.
- **Glassy bar background**: Omarchy's bar now steps its background from
  clear to glassy to opaque (a double click on the bar, the menu's
  Transparency, `omarchy bar background`). Powerbar follows: glassy draws the
  bar see-through (35% at most) and blurred, a double click cycles the three,
  and the menu's Transparency works again (it answered "no bar"). Blur needs
  the layer rules in README, "Backdrop blur". On an Omarchy without glassy,
  Powerbar keeps toggling `transparent` as before.
- **Toasts keep their distance from the bar again**: Omarchy's notifications
  now ask the bar its size per screen, and Powerbar answered with a
  vertical bar's size.
- **Omarchy's panel shortcuts recognised again**: Omarchy now binds Super+Ctrl+A
  and the other panel keys in a new form, so Preferences showed Audio,
  Bluetooth and the rest without their shortcut. Both forms are read.

- **Moving a widget no longer rebuilds the bar** (Qt 6.12): every move,
  on the bar or in Preferences, emptied the bar for a moment and built every
  widget again, so the icons blinked out and the bar seemed to reload. Qt
  6.12 handed Powerbar's own edited config over in a form whose lists
  Omarchy's layout reader does not accept; the bar takes a plain copy now.
- **Battery percentage shown whole**: Omarchy's Power widget now draws its
  percentage as a label beside the battery icon, and Powerbar sized the
  widget to the icon alone, so "100%" was cut off. The label counts now.
- **Shortcuts bound on first start**: a new install binds Super+B to the
  keyboard mode and Super+Ctrl+/ to its search, each only where nothing else
  holds the keys, and a notification says what it bound and what holds any
  key it left alone. An existing setup is not touched; README has the two
  commands to bind them by hand.
- **Arrow keys in one keycap**: the key legend and the `?` sheet draw the
  arrows as one keycap (←→↓) and their vim letters as another (hjkl),
  as Atlas does, instead of a cap per key.
- **Widgets stay in their groups when Omarchy edits them**: cycling the
  clock's format, or pinning a tray icon, made Omarchy save the widget
  without Powerbar's keys; it got a new id, left its group and the group
  lost it for good (the tray also lost its On demand setting). The bar now
  puts those keys back from the layout it showed before.
- **Which code is running**: `omarchy-shell powerbar build` answers the
  version, a digest of the files the bar loaded, its git commit and when it
  loaded. `tools/build-check.sh` compares it with the checkout and says
  `current` or `stale`, so a restart that kept older code (or none at all)
  is caught after an update.
- **Omarchy contract check**: `tools/omarchy-contract.cjs` (also part of
  `tools/validate.sh`) checks the installed Omarchy still has every line,
  theme token and UI type Powerbar relies on, about 200 checks, and names
  the Omarchy file and the missing text when one drifts after an update.
- **Search shortcut**: `omarchy-shell powerbar keysSearch` starts the
  keyboard mode with its `/` search already open, for jumping straight to a
  widget by name. Bind it in Preferences → Bar → Keyboard ("Bar search",
  suggested Super+Ctrl+/) or with `set shortcut.bar:search`.
- **Ready for Qt 6.12**: the palette is read as `Commons.Color`, as Omarchy
  now does, since Qt 6.12's QtQuick brings its own `Color` type that would
  shadow it. `tools/validate.sh` fails on a bare `Color.` reference.

## 0.7.0 — 2026-10-11

A highlight that slides from widget to widget, a fuller keyboard mode with
vim and page keys and a two-column shortcut sheet, and a frame log for
debugging.

- **Sliding highlight**: the hover highlight and the keyboard
  cursor slide from widget to widget within a zone and along a drawer's
  rows, instead of fading out and in.
- **Keyboard mode**: `^` and `$` jump to the ends as Home and End do, Page
  Up and Page Down jump zone to zone, and Home, End, `^`, `$` work in drawers.
- **Shortcut sheet**: `?` lays out in two columns, every keyboard-mode key
  on the left (all arrows and their vim letters in one "Movement" row) and
  the widgets' and groups' own shortcuts on the right.
- **Key strip**: at bar level the arrows share one "Move" and Tab and
  Shift+Tab one "Zones".
- **Keyboard mode**: `,` opens Preferences, and `,` in Preferences closes
  them and brings the keyboard mode back with the cursor where it was. The
  key strip and the `?` sheet list it.
- **Frame log** for debugging: `"powerbarFrameLog": true` on the bar in
  shell.json (no Preferences switch) writes a timeline of what the bar does
  (`PB-EV` lines: keys, cards, hover, expansions, drawers, slides, drags,
  config) and the frame timing of each motion (`PB-FT` lines, long frames
  flagged) to the shell log. Off by default; nothing runs while off.

## 0.6.0 — 2026-10-10

Faster, steadier expansion and collapse, a keyboard mode that follows the
pointer, and tooltips that move instead of flickering.

- **Expansion and collapse**: from the keyboard, inline dots expand at once
  and the cursor lands on the zone's first widget as it opens (the first
  growth came about 290 ms after the key before); the give-way pause runs
  only when a widget actually has to yield. Zone drawers open after the
  pointer rests 90 ms, as group icons do, so a pointer crossing the bar no
  longer flashes them open.
- **Keyboard mode**: the cursor is the item's own highlight with a crisp
  one-device-pixel ring and moves without a fade; it follows the pointer
  onto the bar and into drawers, and the keys carry on from there. A click
  anywhere else ends the mode, on any monitor. In drawer mode a zone's strip
  previews as the cursor reaches the zone and is walked with the keys along
  the bar.
- **Tooltips and the name card** move to the next widget in place: no
  ghost fading out beside the new one, no card doubled, cut in half or
  flashing in another zone, and a card at either end of the screen stays
  on it.
- **Drag and drop**: a drop into a group drawer no longer runs a correction
  glide over a distance that was never real, and a widget removed mid-drag
  discards its drop.
- **Lighter startup and idle**: the drag label is built on first use,
  widget glyphs are read once per widget, and an autohide slide no longer
  re-places every highlight on each frame.
- A strip's end cells draw their highlight whole.

## 0.5.0 — 2026-10-10

The first release. Powerbar was cloned from Omarchy's built-in bar
(`omarchy.bar`, Omarchy 4 Quattro's shell) on 2026-09-21 and still starts
out looking and behaving exactly like it, answering to the same `omarchy bar`
commands. What it adds:

- **Where each widget lives**: On the bar, On demand or Hidden. On demand
  widgets show for a moment when they change, and otherwise wait in a drawer
  beside the bar or behind their zone's dots. A zone that runs out of room
  folds its widgets behind the same dots instead of overlapping the next.
- **Groups**: widgets gathered under one icon or name that opens them as a
  drawer or menu, with a badge adding up their members' counts.
- **Bar styles**: Flat, Floating or Islands; **autohide**, with activity
  peeks and Omarchy's bar toggle sliding the bar out while held.
- **Appearance scopes**: Shape, Surface and Shadow follow the theme, your
  values everywhere, or your values for one theme; a theme can ship
  `powerbar.toml`.
- **Keyboard mode** for the whole bar, its drawers and groups, with fuzzy
  search; a shortcut for any widget or group, written as a marked block in
  `~/.config/hypr/bindings.lua`.
- **Drag and drop** along the bar, between zones, into drawers and groups.
- **Preferences** (Layout, Groups, Bar), all usable from the keyboard, with an
  icon picker for groups.
- **`omarchy-shell powerbar`**: every setting, widget, group and shortcut from
  the command line, plus an agent skill (`agents/skills/powerbar/`).

Configs from pre-release builds carry over: the flat appearance keys move
into `powerbarAppearance` as the current theme's values, `powerbarIslands:
true` still reads as the Islands style, and the first shortcut write Hyprland accepts
replaces an old `~/.config/hypr/powerbar.lua` (and its loader in `hyprland.lua`)
with the block in `bindings.lua`.
