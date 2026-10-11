# Changelog

## Unreleased

- **Sliding highlight** (experimental): the hover highlight and the keyboard
  cursor slide from widget to widget within a zone and along a drawer's
  rows, instead of fading out and in.
- **Keyboard mode**: `^` and `$` jump to the ends as Home and End do, Page
  Up and Page Down jump zone to zone, and Home, End, `^`, `$` work in drawers.
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
