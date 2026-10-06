# Powerbar

A drop-in replacement for Omarchy's bar. It starts out looking and behaving
exactly like Omarchy's own bar, answers to the same `omarchy bar` commands,
and adds on-demand widgets, groups, bar styles, autohide, a keyboard mode and
a Preferences window, all of which you can also drive from the command line.

Powerbar is based on the [Omarchy bar](https://github.com/omacom/omarchy/tree/quattro/shell/plugins/bar),
whose original copyright and MIT license notice are preserved in
[LICENSE](LICENSE).

## Install

```sh
omarchy plugin add https://github.com/overp0werj0int/powerbar.git
omarchy bar use p0werj0int.powerbar
```

Until you change something, Powerbar draws Omarchy's bar plus one button:
flat, on the edge `bar.position` names, at your theme's size, every widget in
Omarchy's sections, order and spacing, nothing on demand, no shortcuts bound.
The nine-dot button at the far right (bottom of a side bar) opens
Preferences.

Back to Omarchy's bar at any time: `omarchy bar reset`. Your Powerbar
settings stay in `~/.config/omarchy/shell.json` for when you come back.

Needs Omarchy 4 (Quattro). Tested on Omarchy 4.0.4-1, Hyprland 0.56.2 and
Quickshell 0.3.1.

## Update

```sh
omarchy plugin update p0werj0int.powerbar
```

It shows what changed and asks before applying it (`--yes` skips the
question); the shell then reloads its plugins and the bar redraws once.

## Remove

```sh
omarchy-shell powerbar clearShortcuts
omarchy plugin remove p0werj0int.powerbar
```

The first line takes Powerbar's shortcuts out of Hyprland; it needs Powerbar
running, so do it before removing. Removing deletes the plugin's folder and,
if Powerbar was your bar, puts Omarchy's bar back.

What stays behind is harmless to Omarchy's bar and is picked up again if you
reinstall. To remove it too:

| What | Where | To clean |
| --- | --- | --- |
| Settings | `bar.powerbar*` keys, and `powerbar*` keys in each widget entry of `bar.layout`, in `~/.config/omarchy/shell.json` | The `jq` command below |
| Shortcuts | The block from `-- >>> powerbar: …` to `-- <<< powerbar` in `~/.config/hypr/bindings.lua` | `omarchy-shell powerbar clearShortcuts` before removing (or clear each one in Preferences); afterwards, delete the block, markers included, and `hyprctl reload` |
| Theme files you wrote | `powerbar.toml` in `~/.config/omarchy/themes/<name>/` (Powerbar only reads them) | Delete them |
| Icons you added to groups | `$XDG_DATA_HOME/powerbar/icons` (`~/.local/share/powerbar/icons`) | `rm -r ~/.local/share/powerbar` |
| Images of your widgets | `$XDG_CACHE_HOME/powerbar` (`~/.cache/powerbar`) | `rm -r ~/.cache/powerbar` |
| Plugin rescan stamp | `$XDG_RUNTIME_DIR/powerbar-registry-rescan` | Gone after a reboot |

```sh
f=~/.config/omarchy/shell.json; cp "$f" "$f.bak"
jq 'def clean: with_entries(select(.key | startswith("powerbar") | not));
  .bar |= (clean | if .layout then .layout |= map_values(if type == "array"
    then map(if type == "object" then clean else . end) else . end) else . end)' \
  "$f.bak" > "$f.new" && mv "$f.new" "$f"
```

## What it adds

**Where each widget lives.** Every widget is **On the bar**, **On demand** or
**Hidden**. On demand widgets stay out of the way and show up for a moment
when something changes in them (a new value, an icon change). The rest of the
time you reach them by hovering their zone, which opens a drawer beside the
bar, or, with *On demand: In the bar*, behind the zone's dots, which expand in
place. When a zone runs out of room, its widgets fold behind the same dots
instead of overlapping the next zone.

**Groups.** Gather widgets under one icon (or name) on the bar that opens
them as a drawer or menu. A group can show a badge that adds up its members'
counts (unread, updates, alerts) and turns urgent when a member does.

**Bar styles.** *Flat* (Omarchy's), *Floating* (one surface held off the
screen edges) or *Islands* (each zone on its own). **Autohide** parks the bar
past its edge: push the pointer there and it slides out, and widget activity
peeks it out for a moment. Omarchy's bar toggle (Super+Shift+Space) brings an
autohidden bar out while you hold it.

**Your look or the theme's.** Rounding, borders, opacity, blur, shadow and
text colour follow your theme until you change them, and then each of Shape,
Surface and Shadow can use your values *Everywhere* or *Just here* (this theme
only). Switching themes never asks you to redo anything.

**Keyboard.** The whole bar, its drawers and groups work from the keyboard,
with fuzzy search to find any widget wherever it is. Any widget or group can
have a shortcut.

**Drag and drop.** Drag widgets along the bar, between zones, into a drawer
(makes them On demand), onto a group, or out of one. The landing place opens
up before you let go.

## Preferences

Three pages, all usable from the keyboard (the footer lists the keys for
whatever has focus):

- **Layout**: your bar as shelves (On the bar, On demand, Hidden), each with
  your three zones. Drag or pick up widgets to move them; the tile below holds
  the selected widget's zone, visibility, *Show on activity*, centring, group
  and shortcut.
- **Groups**: make, name and arrange groups; pick an icon from your widgets'
  glyphs, Omarchy's icons and emoji, or drop in your own SVG or PNG.
- **Bar**: style and edge, size and spacing, Shape, Surface, Shadow,
  Behavior (autohide, readable over windows, animations), On demand and
  Keyboard. Changes show on the bar as you make them.

| Where | Keys |
| --- | --- |
| Anywhere | `1`–`3` switch pages, Ctrl+Tab cycles them, Tab / Shift+Tab move between controls, Esc closes |
| Forms | `j` / `k` move between controls, `h` / `l` adjust (Shift for larger steps), Space / Enter toggle or choose |
| Sliders | Home / End for the ends, Backspace for the default, Esc undoes a value not yet applied |
| Layout shelves | `h` `j` `k` `l` move; Space picks up a widget, then `h` / `l` move it and `j` / `k` change its shelf; Space drops it, Esc puts it back; `x` hides or restores; `g` edits its group |
| Groups shelf | `h` / `l` choose, `n` makes a group, `x` twice dissolves it, Enter goes to its icon |
| Icon picker | Type to search, arrows move, Enter chooses, Tab changes the source, Ctrl+V pastes an image or a glyph |

## Keyboard mode

Preferences → Bar → Keyboard offers Super+B for it (nothing is bound until
you accept). The cursor starts on the clock, or on the widget whose panel is
open. Keys are named by direction relative to the bar, so they mean the same
on every edge:

- The arrows (or h j k l) along the bar move the cursor; Home / End jump to
  the ends; Tab / Shift+Tab jump zone to zone.
- The key that points into the screen (↓ on a top bar) goes into a group or a
  zone's drawer; the opposite key comes back.
- Enter or Space opens the widget, a group or Preferences (the last stop).
- `/` finds a widget by name, fuzzily (`/pm` finds Plugin Manager), and opens
  the way to it, into a group, a drawer or behind dots.
- `?` lists every widget's and group's shortcut.
- Esc closes the innermost thing; Esc twice quickly ends everything and gives
  the keys back to your window. So does Super+B again.

## Shortcuts

A widget's or group's settings show the shortcut that opens it, whether it
comes from Omarchy, your Hyprland files or Powerbar. Press Enter on it to
record new keys; keys already in use are named and you choose whether to take
them. Powerbar writes its shortcuts the way Omarchy plugins do, as a marked
block in `~/.config/hypr/bindings.lua` (everything outside the markers is left
alone), so Super+K lists them.

## Command line

Omarchy's own commands work on Powerbar as on its bar: `omarchy bar position`,
`transparent`, `put`, `move`, `set`, `use`, `reset`, `defaults`, `omarchy
toggle bar`, and the panel shortcuts (`omarchy-shell shell toggle <id>`).
Everything Powerbar adds answers to `omarchy-shell powerbar <function>`;
`omarchy-shell powerbar help` lists them. Answers are JSON, `ok`, or
`error: …` with the reason, and changes go through the same checks as
Preferences.

| Command | Does |
| --- | --- |
| `status` | Every setting, widget, group and shortcut, and what the bar is doing |
| `settings` | Every setting: type, values, `shell.json` key |
| `get <setting>` / `set <setting> <value>` / `reset <setting>` / `toggle <setting>` | Read, change, restore the default, flip a switch |
| `widgets` / `setWidget <widget> <json>` | The layout; move or change one (`zone`, `visibility`, `before`, `group`, `activityPeek`, `badgeProperty`, `urgentProperty`, `centered`) |
| `groups` / `newGroup <name>` / `setGroup <group> <json>` / `removeGroup <group>` | Groups and their members |
| `shortcuts` | Powerbar's shortcuts and Omarchy's panel shortcuts |
| `show` / `hide` | Hold an autohidden bar out until `hide`; or switch the bar on and off |
| `keys` / `keysOn` / `keysOff` / `keysStatus` | The keyboard mode |
| `managed <zone>` / `group <id>` / `toggleGroup <id>` / `closeManaged` | Open or close a drawer |
| `drawerStatus` / `managedStatus` / `popupStatus` | The open drawer, On demand widgets, the open panel |
| `preferences` / `preferencesPage <1-3>` / `groupsPreferences` / `closePreferences` | Preferences |

Settings are named as in Preferences (`style`, `autoHide`, `onDemand`,
`spacing`, `shape.rounding`, `surface.opacity`, `shadow.scope`…), plus a few
with no control in Preferences: `revealSeconds` (how long activity shows a
widget, 2.5 s), `entryGraceSeconds` and `exitGraceSeconds` (how long a drawer
waits for the pointer, 1 s each). Shortcuts are `shortcut.bar:keys`,
`shortcut.group:<id>` and `shortcut.widget:<plugin id>`.

```sh
omarchy-shell powerbar set onDemand inline
omarchy-shell powerbar toggle autoHide
omarchy-shell powerbar setWidget omarchy.bluetooth '{"visibility":"managed"}'
omarchy-shell powerbar setGroup "$(omarchy-shell powerbar newGroup Sound | jq -r .id)" \
  '{"members":["omarchy.audio","omarchy.microphone"],"face":"both"}'
omarchy-shell powerbar set shortcut.bar:keys "SUPER + B"
```

An agent can do all of this for you: `agents/skills/powerbar/` is a skill
that teaches it how.

## For theme authors: `powerbar.toml`

A theme can ship `powerbar.toml`, and you can add or change one for any theme
in Omarchy's overlay folder (`~/.config/omarchy/themes/<name>/powerbar.toml`).
Every key is optional; what it leaves out comes from Omarchy and Hyprland. It
applies while a tile is set to *Theme*.

```toml
[shape]
rounding = 12        # stored units, as the slider
borders = true
border-width = 1

[surface]
opacity = 85         # percent
blur = true
text = "light"       # theme | light | dark

[shadow]
enabled = true
softness = 10
strength = 30
```

## Backdrop blur

Blur behind the bar needs these layer rules in your Hyprland Lua
configuration (for example `~/.config/hypr/looknfeel.lua`). `blur_popups`
blurs the bar's tooltips too.

```lua
hl.layer_rule({
  match = { namespace = "^powerbar$" },
  no_anim = true,
  animation = "none",
  blur = true,
  blur_popups = true,
  ignore_alpha = 0.01,
})
hl.layer_rule({
  match = { namespace = "^powerbar-clear$" },
  no_anim = true,
  animation = "none",
  blur = false,
})
```

## For widget authors

Widgets need nothing special to work in Powerbar. To show activity on demand,
Powerbar watches `text`, `icon`, `iconText`, `value`, `displayValue`,
`powerbarIcon`, `powerbarValue` and `powerbarActivityRevision` on your widget
and its bar buttons, or a `signal powerbarActivity()` for repeated events.
Group badges read `unseenCount`, `downCount`, `updateCount`, `badgeCount`,
`notificationCount`, `unreadCount`, `alertCount`, `pendingCount` or `count`.
Powerbar adds no polling.

## Known limitations

- **Scrolling layout: a click on the bar can scroll the view.** This is
  Hyprland's: its scrolling layout scrolls the focused window into view on
  every mouse button release over any part of it, even when the click landed
  on a bar drawn over it ([hyprwm/Hyprland#13558](https://github.com/hyprwm/Hyprland/discussions/13558)).
  Powerbar meets it wherever a window sits under the bar: with autohide on,
  and on a side bar. Until Hyprland fixes it, `scrolling:follow_focus = false`
  stops it, at the cost of clicks and hovers no longer bringing a partly
  hidden window into view.
- **Switching bars** back and forth makes Powerbar ask the shell to reload its
  plugins once (at most once a minute), so the bar disappears for a few
  seconds.
- Multi-monitor setups are less tested than single-monitor ones.

## What Powerbar touches

Powerbar runs inside the Omarchy shell, as you: no daemon or service of its
own, nothing that needs root, and no network connections. Beyond the
commands below, it follows Hyprland's focused monitor and asks it for
keyboard focus in the keyboard mode, through Quickshell's Hyprland module.

| File | Read | Written |
| --- | --- | --- |
| `~/.config/omarchy/shell.json` | Its settings and Omarchy's bar keys | Through the shell, only under `bar`: its `powerbar*` keys, and on first start a `powerbarInstance` id on each widget entry. Omarchy's bar commands write it as they always do |
| `~/.config/hypr/bindings.lua` | With your other `~/.config/hypr/*.lua` files, Omarchy's default bindings and `hyprctl binds`, to show every shortcut | Only its marked block, when you set a shortcut: replaced in one step, and put back if Hyprland then reports a new config error. The same step deletes `~/.config/hypr/powerbar.lua` and its marked loader in `hyprland.lua` (backed up first), left by early Powerbar builds |
| `~/.local/state/omarchy/` | `current/theme/powerbar.toml`, `current/theme.name`, `toggles/bar-off` | `toggles/bar-off` is cleared when Omarchy's bar toggle slides an autohidden bar out |
| `~/.config/omarchy/themes/`, `$OMARCHY_PATH` | Installed themes (to drop settings for themes you removed), Omarchy's emoji list | Nothing |
| `$XDG_DATA_HOME/powerbar/icons` | | Icons you add to groups (SVG or PNG, 512 KB at most); unused ones are deleted |
| `$XDG_CACHE_HOME/powerbar` | | Images of your widgets for Preferences, `faces.json`, `glyphs.json` |
| `$XDG_RUNTIME_DIR/powerbar-registry-rescan` | | When it last asked the shell to rescan plugins |

| Command | When |
| --- | --- |
| `omarchy-shell shell rescanPlugins` | A bar switch left widgets without their component; at most once a minute |
| `omarchy-toggle-bar`, `omarchy-toggle bar-off off` | `omarchy-shell powerbar show` / `hide`; Omarchy's bar toggle on an autohidden bar |
| `omarchy-bar-text-color` | A transparent bar picks its text colour over the wallpaper, as Omarchy's does |
| `hyprctl binds`, `cat` | Reading shortcuts (Preferences, the keyboard mode, `shortcuts`) |
| `hyprctl reload config-only`, `hyprctl configerrors` | After writing the shortcut block (`ShortcutApply.sh`, with `grep`, `awk`, `cp`, `mv`, `readlink`) |
| `hyprctl eval` | Recording a shortcut: a temporary submap so the keys reach Preferences, for 15 s at most |
| `hyprctl binds -j` with `jq`, `hyprctl repl` | Omarchy's bar toggle on an autohidden bar: finds the toggle's key and checks every 50 ms whether it is still held, for 60 s at most |
| `hyprctl -j getoption general:gaps_in` | Opening Preferences, to space its tiles like your windows |
| `wl-paste` (under `timeout 2s`) | Ctrl+V in the icon picker |
| `ls`, `mkdir`, `cp`, `stat`, `rm` | The icon and image folders above |
| Your custom modules' `exec`, `onClick`… | Command modules in your layout, through `bash -lc`, as on Omarchy's bar |

## Troubleshooting

**The bar is gone.** If it was switched off with Omarchy's bar toggle
(Super+Shift+Space, `omarchy toggle bar`), `omarchy-shell powerbar show`
brings it back, as does `omarchy toggle bar off` (the word names Omarchy's
`bar-off` flag, so `off` shows the bar). With autohide on, the toggle never
hides the bar: it slides out while you hold the keys. An autohidden bar comes
out when the pointer reaches its edge; `omarchy-shell powerbar show` holds it
out until `hide`, and `omarchy-shell powerbar set autoHide off` ends
autohide. If `omarchy-shell powerbar status` does not answer, run `omarchy
restart shell`. Still nothing: `omarchy bar reset` returns to Omarchy's bar
(it works without the shell, from a TTY too), keeping your Powerbar
settings; `omarchy bar use p0werj0int.powerbar` comes back.

**Widgets show placeholders after switching bars.** The shell can keep a stale
copy of its widget list after a switch. Powerbar notices within a few
seconds and asks the shell to rescan its plugins (the bar disappears for a
few seconds), at most once a minute. If placeholders remain after a minute,
`omarchy restart shell`.

**A shortcut does nothing.** `omarchy-shell powerbar shortcuts` lists each
one with its `source` (`yours` for one set in Powerbar, `omarchy` or `config`
for Omarchy's and your Hyprland files') and, for yours, `live`: whether
Hyprland has those keys bound right now. `live: false` means Hyprland did not
take the block: look in `~/.config/hypr/bindings.lua` for a damaged Powerbar
block (a marker without its pair; Preferences names it) and `hyprctl
configerrors`. A key another bind holds is only taken when you choose to.

## More

How every part behaves, precisely: [docs/behavior/](docs/behavior/README.md).
Working on Powerbar itself: [DEVELOPMENT.md](DEVELOPMENT.md).
