---
name: powerbar
description: >
  Operate the Powerbar Omarchy bar for the user: read and change its settings,
  move widgets between the bar, On demand and Hidden, make and edit groups,
  set shortcuts, switch styles, autohide, appearance (shape, surface, shadow,
  per theme), the keyboard mode, and Omarchy's own `omarchy bar` commands.
  Use whenever the user asks to change, explain or inspect their bar while
  Powerbar (p0werj0int.powerbar) is the active bar, or to switch to or away
  from it. Not for developing the plugin's code (that is AGENTS.md in the repo).
---

# Operating Powerbar

Powerbar replaces Omarchy's bar and keeps all of its commands. Everything you
can do in its Preferences window you can also do with
`omarchy-shell powerbar <function> [args…]`. Prefer that over editing
`~/.config/omarchy/shell.json`: it validates values, writes only what changed,
cleans up after itself, and the bar applies it at once.

## First: is Powerbar the bar?

```sh
jq -r '.bar.id // "omarchy.bar"' ~/.config/omarchy/shell.json   # p0werj0int.powerbar when active
omarchy-shell powerbar help >/dev/null && echo running          # answers only when loaded
```

- Not installed: `omarchy plugin add https://github.com/overp0werj0int/powerbar.git`.
- Installed but not active: `omarchy bar use p0werj0int.powerbar`.
- Back to Omarchy's bar: `omarchy bar reset` (Powerbar's settings stay in
  `shell.json` for later).

## Rules

- **Read before you write.** `omarchy-shell powerbar status` gives every
  setting, widget, group, shortcut and what the bar is doing right now. Use it
  to find ids and current values instead of guessing.
- **Check every part of the request.** After a multi-part request, read
  `status` (or `get`, `widgets`, `groups`) and confirm each part landed on the
  thing the user named, before saying it is done.
- **One change, then check.** Every write answers `ok` or `error: <reason>`.
  On `error`, read the reason; it says what is allowed. Don't retry the same
  call blindly, and don't fall back to editing `shell.json` to get around a
  refusal.
- **Back up before bulk edits** (more than a few changes, or anything to
  groups or the layout): `cp ~/.config/omarchy/shell.json ~/.config/omarchy/shell.json.bak.$(date +%Y%m%d%H%M%S)`.
- **Shortcuts touch Hyprland.** Setting one writes a marked block in
  `~/.config/hypr/bindings.lua` and reloads Hyprland. Confirm with the user
  before taking keys that something else holds (`replace`, below).
- **Never restart the shell while the session is locked**
  (`omarchy-hyprland-session-locked` exits 0 when locked). Powerbar applies
  changes live, so a restart is rarely needed; if it is, `omarchy restart shell`.
- **Don't drive the keyboard mode for the user** (sending keys to their
  desktop) unless they ask. Read its state with `keysStatus` instead.

## Reading state

| Call | Answers |
|---|---|
| `status` | `{version, theme, settings, widgets, groups, shortcuts, runtime}` |
| `settings` | every setting: `name`, `type`, `values` or `min`/`max`, `shell.json` key |
| `get <setting>` | one setting's current value (JSON) |
| `widgets` | each widget: `id`, `instance`, `name`, `zone`, `index`, `visibility`, `group`, `centered`, `activityPeek`, `badgeProperty`, `urgentProperty`, `settings` |
| `groups` | each group with all its fields and `members` (`instance`, `id`) |
| `shortcuts` | `{ready, shortcuts: [{target, name, keys, source, fallback, positional, ready, live}]}`; `source` says who binds it (omarchy, yours, powerbar…); for yours, `live` says Hyprland really has it bound |
| `managedStatus` / `drawerStatus` / `popupStatus` / `keysStatus` | On demand widgets, the open drawer, the open panel, the keyboard mode |
| `help` | every function, with what it does |

`runtime` holds `barOff`, `hidden`, `held`, per-screen `shown`/`peeking`,
`keys`, the open `drawer`, and `preferences: {open, page}`.

## Settings

`set <setting> <value>` takes JSON or plain text. `reset <setting>` returns it
to the default; `toggle <setting>` flips a true/false one.

| Setting | Values (default) | What it does |
|---|---|---|
| `position` | top, bottom, left, right (top) | the screen edge (same as `omarchy bar position`) |
| `transparent` | bool (false) | Omarchy's transparent bar: clear surface, text from the wallpaper (same as `omarchy bar transparent`) |
| `centerAnchor` | widget id or "" | widget kept at the exact screen centre |
| `style` | flat, floating, islands (flat) | flat = Omarchy's; floating = one surface off the edges; islands = each zone on its own |
| `largeBar` | bool (false) | 12 px thicker bar, widgets keep their size |
| `spacingMode` | slots, gaps (slots) | equal cells, or equal air between glyphs |
| `spacing` | 0–16 (4) | space between widgets |
| `autoHide` | bool (false) | bar parks past its edge; pointer at the edge brings it out |
| `autoHideActivity` | bool (true) | widget activity peeks an autohidden bar out |
| `readableOverlay` | bool (true) | keep surfaces over windows ≥ 88% opaque unless blur is on |
| `animations` | bool (true) | |
| `onDemand` | drawer, inline (drawer) | On demand widgets open in a drawer, or expand in the bar behind the zone's dots |
| `dotsBadge` | bool (true) | count on a zone's dots |
| `keyLegend` | bool (true) | key strip in the keyboard mode |
| `revealSeconds` | 1–60 (2.5) | how long activity shows an On demand widget |
| `entryGraceSeconds`, `exitGraceSeconds` | 1–15 (1) | how long a drawer waits for the pointer to arrive / come back |
| `shape.scope`, `surface.scope`, `shadow.scope` | theme, all, this (theme) | whose values the tile uses: the theme's, yours everywhere, yours in this theme only |
| `shape.rounding` 0–19, `shape.borders` bool, `shape.borderWidth` 0.5–3 | | |
| `surface.opacity` 0–100, `surface.blur` bool, `surface.text` theme/light/dark | | text is always per theme |
| `shadow.enabled` bool, `shadow.softness` 2–24, `shadow.strength` 5–60 | | |

Ranges come from `settings`; trust it over this table if they differ.

**Appearance follows the theme by default.** To change a shape, surface or
shadow value, first pick whose values to use, then set it:

```sh
omarchy-shell powerbar set shape.scope this      # just this theme (or "all": every theme)
omarchy-shell powerbar set shape.rounding 6
```

Setting a value while its scope is `theme` answers
`error: shape follows the theme; set shape.scope to all or this first`.

To undo: `reset shape.rounding` drops your value in the current scope (it
falls back to the shared value, then the theme's). To go back to the theme's
look entirely: `set shape.scope theme`; your stored values are kept for later.
(`reset shape.scope` picks Preferences' default instead: `all` when shared
values exist, else `theme`.)
A theme can also ship its own look in `powerbar.toml` (README, "For theme
authors").

## Widgets

A widget is named by its plugin id (`omarchy.bluetooth`), or by its
`instance` when it is on the bar more than once (the error lists them). Find
ids and display names with `widgets | jq -r '.[] | "\(.id)  \(.name)  \(.zone)  \(.visibility)"'`;
match the user's words to `name`, not a guessed id.

```sh
omarchy-shell powerbar setWidget omarchy.bluetooth '{"visibility":"managed"}'
omarchy-shell powerbar setWidget omarchy.weather '{"zone":"right","before":"omarchy.audio"}'
```

Fields: `zone` (left, center, right), `visibility` (shown = on the bar,
managed = On demand, hidden), `before` (a widget in the target zone, or "" for
the zone's end), `group` (a group id or name, "" to leave), `activityPeek`
(bool: show on activity), `badgeProperty` / `urgentProperty` (a property name
the group badge reads, "" for the default, "none" to exclude), `centered`
(bool, centre-zone widgets on the bar only).

Adding or removing widgets from the bar entirely is Omarchy's job:
`omarchy plugin enable|disable <id>` and `omarchy bar put <id> [--section …]`.

## Groups

```sh
id=$(omarchy-shell powerbar newGroup Sound | jq -r .id)
omarchy-shell powerbar setGroup "$id" '{"members":["omarchy.audio","omarchy.microphone"],"icon":"󰕾","face":"both"}'
omarchy-shell powerbar removeGroup Sound          # its widgets go back where they were
```

A group is named by id or label. Fields: `label`, `icon` (a glyph),
`iconImage` (path to an SVG/PNG), where `icon` is any glyph: a Nerd Font
icon, which matches the bar (copy one a widget already draws, or let the user
pick in Preferences → Groups), or an emoji, `iconTint` (text, own), `iconFont`
("", omarchy), `zone`, `before`, `visibility`, `face` (glyph, text, both: what
the bar shows), `memberDisplay` (native, name, both: how the drawer shows
members), `tooltip` (bool),
`badge` (bool), `badgeMode` (sum: add up counts; members: count busy widgets),
`members` (the full ordered list, by id or instance). Groups can't contain
groups.

## Shortcuts

```sh
omarchy-shell powerbar shortcuts                                  # what is bound, and by whom
omarchy-shell powerbar set shortcut.bar:keys "SUPER + B"           # the keyboard mode
omarchy-shell powerbar set shortcut.group:<group id> "SUPER + CTRL + ALT + J"
omarchy-shell powerbar set shortcut.widget:omarchy.audio '""'      # remove
omarchy-shell powerbar reset shortcut.widget:omarchy.audio         # back to Omarchy's own
```

A shortcut needs Super, Ctrl or Alt (or is an F-key). Keys another bind holds
are refused with its name: `error: … is taken by Audio; …`. Take them only if
the user agrees: `'{"keys":"SUPER + CTRL + A","replace":true}'`.

`set` answers `ok` once the change is queued; the write to `bindings.lua`
and Hyprland's reload follow. Check with `shortcuts` (`live: true`) before
telling the user it works. If Hyprland refused it or the file couldn't be
written, the setting is put back and `live` stays false.

## Actions

| Call | Does |
|---|---|
| `show` / `hide` | autohide on: hold the bar out until `hide`. Autohide off: switch the bar on/off (as `omarchy toggle bar`) |
| `keysOn` / `keysOff` / `keys` | start, end, toggle the keyboard mode on the focused monitor |
| `managed <left\|center\|right>` / `group <id>` / `toggleGroup <id>` / `closeManaged` | open or close a drawer |
| `preferences` / `preferencesPage <1-3>` / `groupsPreferences` / `closePreferences` | the Preferences window (1 Layout, 2 Groups, 3 Bar) |

## Omarchy's commands still work

`omarchy bar position|transparent|put|move|set|use|reset|defaults` and
`omarchy toggle bar` behave as on Omarchy's bar. Note: `omarchy bar defaults`
replaces the whole `bar` section with Omarchy's defaults, which drops every
Powerbar setting and switches back to Omarchy's bar. Back up first, and
prefer `reset <setting>` for single Powerbar settings.

## Recipes

- **"Make my bar like stock again but keep Powerbar"**: `reset` each setting
  you changed (`status | jq .settings` shows them), and `setWidget <id>
  '{"visibility":"shown"}'` for widgets you moved On demand or hid.
- **"Hide the bar until I need it"**: `set autoHide true`.
- **"Put these widgets in one icon"**: `newGroup`, then `setGroup` with
  `members`.
- **"Less clutter"**: move rarely-used widgets On demand
  (`setWidget <id> '{"visibility":"managed"}'`); they peek out on activity.
- **"Rounder / blurrier, just in this theme"**: `set shape.scope this`,
  `set shape.rounding …`; `set surface.scope this`, `set surface.blur true`
  (blur also needs the layer rules in README, "Backdrop blur").

## When something looks wrong

- `error: the shell gives Powerbar no way to save its settings`: the shell
  is not Omarchy's or is starting; wait and retry once.
- `error: not while Preferences are open`: `closePreferences` first.
- A widget shows a placeholder or nothing after switching bars: Powerbar
  reloads plugins once by itself within a few seconds; wait, then check
  `widgets`.
- The bar is gone: `omarchy-shell powerbar show` brings it back either way
  (switched off with Omarchy's toggle, or parked by autohide); `status | jq
  .runtime` says which (`barOff`, `hidden`). Careful: `omarchy toggle bar
  on|off` sets Omarchy's *bar-off* flag, so `on` hides the bar.
- Exact behavior of anything: the repo's `docs/behavior/` files, one per area.
