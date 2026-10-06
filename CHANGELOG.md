# Changelog

## 1.0.0 — unreleased

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
