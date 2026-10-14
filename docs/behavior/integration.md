# Integration behaviors

How Powerbar meets the Omarchy shell: manifest, startup, `shell.json` keys,
config healing, the registry heal, compatibility with Omarchy's own bar
commands, the whole `omarchy-shell powerbar` command line (IPC), and several
monitors. Observable through the screen, `~/.config/omarchy/shell.json`, and
command output. Removed IDs (internal plumbing with nothing to observe) are
not reused.

**Sources:** Bar.qml (IpcHandler `powerbar` at 561, `omarchy.bar` at 2906;
`ensureInstanceIds`, `checkRegistry`, `healAppearance`, `pruneGroupMembers`),
BarCli.qml, CliModel.js, BarModel.js `options()`, ManagedModel.js
`healVisibility()`, AppearanceModel.js, GroupsModel.js, manifest.json,
tests/cli.test.cjs; stock `/usr/share/omarchy/bin/omarchy-bar`,
`omarchy-toggle-bar`, `omarchy-shell-config`.

## Plugin manifest

- **INTEG-1** `manifest.json` declares `schemaVersion: 1`, `id: "p0werj0int.powerbar"`, `name: "Powerbar"`, `version: "0.9.0"`, author `p0werj0int`, license `MIT`, description `Status bar with widgets`, `kinds: ["bar"]`, `entryPoints.bar: "Bar.qml"`.
- **INTEG-2** The manifest declares `omarchy.clonedFrom: "omarchy.bar"`.

## Startup

- **INTEG-3** The bar draws from the `bar:` subtree of `~/.config/omarchy/shell.json`, which the host injects as `barConfig` on every reload; Powerbar changes the file only through the host's `mutateShellConfig` (INTEG-101..103). Until injected, `barConfig` is `{}`.
- **INTEG-4** If `barConfig` is not a plain object the bar uses `{position: "top", transparent: false, centerAnchor: "omarchy.clock", layout: {left: [], center: [], right: []}}`. Code: `fallbackBarConfig`.
- **INTEG-5** On load `applyBarConfig()` runs and the registry check timer starts (INTEG-29). Code: `Component.onCompleted`.
- **INTEG-6** Command and QML widgets are given `bar`, `moduleName` and `settings` (INTEG-95).
- **INTEG-65** One bar window per screen in `Quickshell.screens`; each has its own keyboard handler and drawer. Code: `Variants { model: Quickshell.screens }`.

## shell.json keys

Defaults are what a config that never set the key gets (`BarModel.options()`,
`AppearanceModel.ranges`, `ManagedModel.seconds()` calls). Nothing here is
written back by merely starting Powerbar. Each key also has a CLI setting
name (INTEG-121).

- **INTEG-9** `bar.position` is `top`, `bottom`, `left` or `right`; anything else is read as `top`. Default `top`. Code: `normalizePosition`.
- **INTEG-10** `bar.background: "none"` (Omarchy's own key; `bar.transparent: true` on an Omarchy from before glassy) clears the bar's surface in every style and Theme text takes the wallpaper-derived colour Omarchy computes; drawers keep their surface; an auto-hiding bar keeps its readable minimum (see appearance.md). `glassy` draws a see-through, blurred surface (appearance.md LOOK-141). Default `opaque`.
- **INTEG-11** `bar.centerAnchor` is the plugin id kept at the centre of the centre zone. Default none (`""`; `omarchy.clock` only in the INTEG-4 fallback).
- **INTEG-12** `bar.layout` has `left`, `center`, `right` arrays; a missing or non-array zone is treated as empty.
- **INTEG-13** `bar.powerbarAutoHide` (bool, default `false`) auto-hides the bar.
- **INTEG-14** `bar.powerbarAutoHideActivity` (bool, default `true`; only `false` turns it off) lets activity reveal an auto-hidden bar.
- **INTEG-15** `bar.powerbarOnDemand` is `drawer` or `inline` (only the exact string `inline` selects inline; default `drawer`).
- **INTEG-16** `bar.powerbarManagedRevealSeconds`: how long an activity reveal lasts, default 2.5 s, clamped 1 to 60 (non-numbers give the default). Behavior in on-demand-drawers.md.
- **INTEG-17** `bar.powerbarManagedEntryGraceSeconds`: default 1 s, clamped 1 to 15.
- **INTEG-18** `bar.powerbarManagedExitGraceSeconds`: default 1 s, clamped 1 to 15 (also the inline collapse delay).
- **INTEG-19** `bar.powerbarKeyLegend` (bool, default `true`; only `false` hides it) shows the key legend in the keyboard mode.
- **INTEG-20** `bar.powerbarDotsBadge` (bool, default `true`; only `false` hides) shows badges on the zone dots.
- **INTEG-21** `bar.powerbarAnimations` (bool, default `true`; only `false` turns animations off).
- **INTEG-22** `bar.powerbarLargeBar` (bool, default `false`) makes the bar thicker by `2 x Style.space(6)` over the theme's size. Code: `barSizeFor`.
- **INTEG-23** `bar.powerbarSpacingMode` is `slots` or `gaps` (only the exact string `gaps` selects gaps; default `slots`).
- **INTEG-24** `bar.powerbarSpacing`: number 0 to 16 in steps of 1, default 4, clamped. Code: `AppearanceModel.ranges.spacing`.
- **INTEG-25** `bar.powerbarAppearance` holds shape/surface/shadow values per scope and theme (appearance.md); absent means the theme's own.
- **INTEG-26** `bar.powerbarGroups` holds the groups (groups.md); members no longer in the layout are dropped (INTEG-40).
- **INTEG-109** `bar.powerbarStyle` is `flat`, `floating` or `islands`; absent: `islands` if the older `powerbarIslands` is `true`, else `flat`. Choosing a style removes `powerbarIslands`.
- **INTEG-110** `bar.powerbarReadableOverlay` (bool, default `true`; only `false` turns it off).
- **INTEG-111** `bar.powerbarVisibilityDefault: "shown"` is the marker for a config on the current visibility rule (INTEG-112). A widget entry's `powerbarVisibility` is `shown`, `managed` or `hidden`.
- **INTEG-146** `bar.powerbarFrameLog` (bool, default `false`; only `true` turns it on; not in Preferences) writes the bar's event timeline and the frame timing of its motions to the shell log, applied live, for debugging with an agent. `PB-EV t=<ms> <kind> <detail>` lines name what happened: `key`, `keys` (on/off), `cursor`, `card` (show/move/hide with the target and its first line), `hover`, `center-hover`, `dots`, `ask` (the inline request), `inline` (open/close, `giveway`), `drawer` (open/close with the reason, aside/back), `strip` (out/away), `peek`, `drag`, `settle`, `barmove`, `popout`, `folded` (the zone-fit report), `position`, `hidden`, `config` (a config delivered), `framelog`, and `longframe dt=<ms> in=<run>` for any frame interval over 25 ms while a motion runs. A motion (strip, inline, drawer, card show, drag, settle, bar move) arms a frame run for its nominal time plus 100 ms; motions starting meanwhile join it, and when it ends one `PB-FT anim=<labels> frames=N nominal=MS wall=MS mean=MS p95=MS max=MS long=N` line sums it up (labels joined with `+`). Nothing is measured or logged while off. Code: FrameLog.qml, Bar.qml `ev()`.

## Config healing

- **INTEG-112** A widget with no saved `powerbarVisibility` is On the bar, third-party widgets included (as on Omarchy's bar); a widget whose registry entry is not loaded yet is "pending" and the Powerbar CLI reports it as `shown`. Code: `ManagedModel.mode`; `BarCli.liveMode`.
- **INTEG-113** One-time heal (`healVisibility`), written in the same config write that first assigns `powerbarInstance` ids: on a config Powerbar already ran on (any `powerbar*` bar key, or any entry with `powerbarInstance`) that has no `powerbarVisibilityDefault: "shown"`, each entry that is not from Omarchy (command or QML module, or a plugin whose registry metadata is not first-party, or by id not starting `omarchy.` while the registry has not loaded it) and has no saved `powerbarVisibility` gets `"managed"`, so it stays On demand as before; then the marker `powerbarVisibilityDefault: "shown"` is written. A fresh config (no `powerbar*` key, no instance id) gets only the marker; a marked config is left alone. Code: `Bar.ensureInstanceIds`, `ManagedModel.healVisibility`.
- **INTEG-114** Every layout entry gets a unique `powerbarInstance` key (`pw-<time>-<random>`); entries with a missing or duplicated key are re-keyed in one write. Code: `ensureInstanceIds`.
- **INTEG-115** A widget with nothing to show (no updates, Bluetooth off, empty tray) hides, as on Omarchy's bar, unless it was put On the bar by choice (explicit `powerbarVisibility: "shown"`) or is On demand, where it keeps a fallback icon. Code: `ManagedModel.placeholder`.
- **INTEG-33** When the theme name changes (`~/.local/state/omarchy/current/theme.name`), `healAppearance()` runs.
- **INTEG-34** `healAppearance()` does nothing unless the bar can write config, the theme name is known, and `AppearanceModel.legacyPresent(barConfig)` is true (any of `powerbarForeground`, `powerbar[Main]IslandRounding/IslandBorders/IslandBorderWidth/Blur/BackgroundOpacity/Shadow/ShadowSize/ShadowOpacity`, `powerbarMainReadableOverlay`, `powerbarExtendedReadableOverlay`).
- **INTEG-35** When it runs, those flat keys are removed and their values move into `powerbarAppearance` as the current theme's own values; other themes start on Theme. Code: `AppearanceModel.migrate`.
- **INTEG-36** `pruneAppearanceThemes()` removes `powerbarAppearance.themes.<name>` entries for themes not installed (not in `$OMARCHY_PATH/themes` or `~/.config/omarchy/themes`, and not the current theme); empty containers go too. It does nothing until both folders were listed, so a partial list never prunes, and it prunes only from a fresh listing: when a config change makes the last list look stale, both folders are listed again first, so a theme installed since startup keeps its values.
- **INTEG-37** `healAppearance` is also scheduled whenever a `barConfig` arrives with legacy keys; **INTEG-38** `pruneAppearanceThemes` whenever a `barConfig` arrives once the theme list is known, and when the list is read.
- **INTEG-40** When a `barConfig` arrives and a group lists a member (instance key) not in the layout (widget uninstalled), `pruneGroupMembers()` writes `powerbarGroups` back without those members. Skipped while the bar cannot write or edits are queued. `group:`-prefixed members are not dangling. Nothing asks the user. Code: `GroupsModel.danglingMembers`.

## Widget repair

- **INTEG-27** Omarchy hands a full bar a copy of its widget registry. A copy taken while the shell reloads its widgets (a bar switch, a first install) can list widgets whose component is already destroyed. Whether it does depends on when the JavaScript garbage collector runs: in a box with a real user's plugins, 3 switches came through whole, and with a collection forced every 2 s each of six switches lost 35 of 39. Nothing refreshes the copy until the shell registers another widget; until then those widgets are placeholders.
- **INTEG-28** A widget is stale when the registry lists it without a component. Code: `BarModel.staleWidgetIds`.
- **INTEG-29** Each time the bar is handed a registry and each time its `widgets` change, `WidgetRepair.sync()` runs at once: no timer, no shell rescan, no limit.
- **INTEG-30** A stale widget is loaded from its own plugin: the `barWidget` entry point of the `manifest.json` in its `sourceDir`, read as the shell reads it (a relative path without `..`, in a manifest with the widget's id). The component belongs to the bar and draws on the same frame. It logs `powerbar: the shell's widget registry lost the component of <ids>; loaded them from their plugins`. Code: `BarModel.widgetEntryPath`, `WidgetRepair.qml`.
- **INTEG-31** A widget that cannot be loaded (no folder, no readable manifest, no entry point, a QML error) stays a placeholder and is warned about with the reason: `powerbar: <id> has no component and could not be loaded (<reason>)`.
- **INTEG-32** A loaded widget keeps its component while the registry lists it from the same folder, even once the shell registers a fresh one: switching a working widget's component rebuilds it, briefly running two that each register their IPC handler. It is dropped when the widget is unregistered or moves folder. Code: `BarModel.keepRepaired`.
- **INTEG-143** `status` reports the repair as `runtime.registry`: `{widgets: <count>, stale: [ids], repaired: [ids], failed: {id: reason}}`.

## Omarchy bar compatibility

Omarchy's commands edit `shell.json` (or ask the host shell) and Powerbar
follows the re-injected `barConfig`; none reaches Powerbar's IPC.

- **INTEG-42** The flag file `~/.local/state/omarchy/toggles/bar-off` means the bar is off; a watch on the `toggles` directory re-reads it.
- **INTEG-43** With the flag set, the bar parks just past its screen edge with no reserved space; while the keyboard mode is active the bar shows anyway and the flag is untouched. Code: `barHidden`.
- **INTEG-44** `omarchy toggle bar [toggle|on|off]` flips the flag, then calls `omarchy-shell -q omarchy.bar syncHidden`.
- **INTEG-45** `omarchy.bar syncHidden` (IPC target `omarchy.bar`, no output) re-reads the flag at once, even if the directory watch went quiet, so a quick on/off pair cannot strand the bar off screen.
- **INTEG-116** While `bar.powerbarAutoHide` is on, `omarchy toggle bar` does not hide the bar: the flag reads as off again and the bar slides out as at its edge, held while the toggle's key (or any modifier if the bind is not found) is down, up to 60 s, and slides away the usual delay after release (a tap: at once). Code: `revealFromToggle`.
- **INTEG-80** `omarchy bar position <top|bottom|left|right>` writes `bar.position`; the bar moves.
- **INTEG-84** `omarchy bar background <opaque|glassy|none|cycle>` writes `bar.background` and drops `bar.transparent`; `omarchy bar transparent <true|false|toggle>` writes `none` or `opaque` there, and `bar.transparent` on an Omarchy from before glassy (toggle: `!= true`); the bar clears, turns glassy or fills (INTEG-10). Omarchy's menu Transparency calls the bar's `cycleBackground()` (`toggleTransparency()` on older shells), which Powerbar answers (appearance.md LOOK-133). Choosing an opacity in Preferences ends the transparency and the slider shows Clear while it is on.
- **INTEG-85** `omarchy bar use <id>` sets `bar.id`; `use omarchy.bar`, `use default`, `use built-in` and `omarchy bar reset` remove `bar.id` (Powerbar is replaced by that bar). An unknown id: `omarchy bar: <id> is not a known bar option; run 'omarchy plugin list'` (Omarchy's text).
- **INTEG-87** `omarchy bar defaults` replaces the whole `bar` object with Omarchy's default (position, transparent, layout, centerAnchor; no `bar.id`), so Powerbar's `powerbar*` keys and groups go and the stock bar becomes active; installed dropbox and tailscale widgets are re-added after `omarchy.workspaces`/`omarchy.tray`.
- **INTEG-88** `omarchy bar put <id> [section] [--before|--after <id>]` has the shell place the widget (`putBarWidget`); a widget already on the bar stays. Powerbar shows it on the next injection with a `powerbarInstance` (INTEG-114) and no saved visibility, so On the bar (INTEG-112).
- **INTEG-89** `omarchy bar move <id> ...` has the shell move the widget (`moveBarWidget`); Powerbar follows the new layout.
- **INTEG-90** `omarchy bar set <id> <key> <value>` has the shell set the entry's option (`setBarWidget`); Powerbar's own `powerbar*` entry keys are untouched. Powerbar's equivalent is INTEG-131.
- **INTEG-81** Powerbar has no `put`, `move` or `set` function of its own; its own placement commands are `setWidget` (INTEG-131).

## Custom widget modules

- **INTEG-91** Entries in `bar.layout.<zone>` with a non-plugin `id` are custom modules; each needs `type`: `command` or `qml`.
- **INTEG-92** `command` modules take `exec` (`~` expands), `interval` seconds, `tooltip`, `onClick`; output is plain text or Waybar-style JSON `{"text","tooltip","class"}`.
- **INTEG-93** `qml` modules take optional `source` (default `~/.config/omarchy/bar/modules/<id>.qml`), are loaded as an `Item`, and receive `bar`, `moduleName`, `settings`.
- **INTEG-94** A QML module defines `implicitWidth` and `implicitHeight`; the bar sets its height to the bar size.
- **INTEG-95** The injected `bar` exposes `foreground`, `background`, `urgent`, `fontFamily`, `position`, `vertical`, `barSize`, `run(cmd)` (runs `cmd` through `bash -lc`, detached), `showTooltip(target, text)`, `hideTooltip(target)`, `requestPopout(owner)`, `releasePopout(owner)`. It has no `shellQuote`: Omarchy's bar README lists `bar.shellQuote(value)`, but neither bar defines it; a widget quotes with `Util.shellQuote(value)` from `qs.Commons`, as Omarchy's own widgets do.
- **INTEG-96** A widget whose component is not available draws as a placeholder until the widget repair (INTEG-27..32) loads it.

## Command line: `omarchy-shell powerbar <function> [args]`

`omarchy shell powerbar ...` is the same. Omarchy offers no way for a plugin
to add an `omarchy` subcommand, so this is the surface. Function names are
case-sensitive. Arguments are plain strings; a JSON value is the one argument
after the setting or widget (quote it for the shell). `help` lists every
function; a test keeps `help` and the IpcHandler in step (the same 31 names).
Code: Bar.qml IpcHandler; BarCli.qml; CliModel.js.

### Answers

- **INTEG-117** Functions that write answer `ok`, or `error: <reason>` (a failure is text, not an exit code, since IPC returns the string). `get`, `status` and listings answer JSON on one line.
- **INTEG-118** A write is validated whole first and then queued exactly as Preferences queues it (300 ms debounce, INTEG-101), so what the CLI changes shows on the bar and in an open Preferences at once, and `ok` means queued, not yet on disk.
- **INTEG-119** If the shell gives Powerbar no way to save, every write answers `error: the shell gives Powerbar no way to save its settings` (checked after the setting name is found, before the value). If the write is refused when queued: `error: Could not save. Check that shell.json is writable.`

### Setting values

- **INTEG-120** A value is parsed as JSON when it parses (`true`, `12`, `"inline"`, `{...}`), else taken as text (`inline`, `SUPER + B`); an empty argument is the empty text. A switch also takes `on` or `off`.
- **INTEG-121** A setting is named by its CLI name or by its `shell.json` key (`autoHide` or `powerbarAutoHide`); `shortcut.<target>` names a shortcut. Unknown: `error: no setting <name>; omarchy-shell powerbar settings lists them`.

Settings (`settings` lists them as JSON `{name, type, key, values|min,max,step}`;
`key` is `bar.<key>`, or `bar.powerbarAppearance` for the appearance ones, or
`bar.powerbarShortcuts` for `shortcut.<target>`). `get` answers the value the
bar uses now, the stored value or its default:

| Name | Type, values | shell.json key | Default |
|---|---|---|---|
| `position` | choice top, bottom, left, right | `position` | top |
| `background` | choice opaque, glassy, none | `background` | opaque (from `transparent`) |
| `transparent` | bool, the older form of `background` | `transparent` (`background` on an Omarchy with glassy) | false |
| `centerAnchor` | text (plugin id, `""` for none) | `centerAnchor` | `""` |
| `style` | choice flat, floating, islands | `powerbarStyle` | flat |
| `largeBar` | bool | `powerbarLargeBar` | false |
| `spacingMode` | choice slots, gaps | `powerbarSpacingMode` | slots |
| `spacing` | number 0 to 16, step 1 | `powerbarSpacing` | 4 |
| `autoHide` | bool | `powerbarAutoHide` | false |
| `autoHideActivity` | bool | `powerbarAutoHideActivity` | true |
| `readableOverlay` | bool | `powerbarReadableOverlay` | true |
| `animations` | bool | `powerbarAnimations` | true |
| `onDemand` | choice drawer, inline | `powerbarOnDemand` | drawer |
| `dotsBadge` | bool | `powerbarDotsBadge` | true |
| `keyLegend` | bool | `powerbarKeyLegend` | true |
| `frameLog` | bool | `powerbarFrameLog` | false |
| `zones` | choice three, two, notch (layout-zones.md ZONE-72; a switch swaps layouts, `reset` returns to three) | `powerbarZones` | three |
| `notchWidth` | number 40 to 600, step 1 (logical px; the gap two-zone modes keep) | `powerbarNotchWidth` | the camera housing (185 at scale 2), 185 on a machine without a notch; `get` answers the width in use, `null` with no notch and none set |
| `revealSeconds` | number 1 to 60 | `powerbarManagedRevealSeconds` | 2.5 |
| `entryGraceSeconds` | number 1 to 15 | `powerbarManagedEntryGraceSeconds` | 1 |
| `exitGraceSeconds` | number 1 to 15 | `powerbarManagedExitGraceSeconds` | 1 |
| `shape.scope`, `surface.scope`, `shadow.scope` | choice theme, all, this | `powerbarAppearance` | `all` when shared values exist for the tile, else `theme` |
| `shape.rounding` | number 0 to the bar's pill limit (`ceil(barSize / 2 / spacing scale)`, so it depends on thickness), step 1 | `powerbarAppearance` | theme's corner radius |
| `shape.borders` | bool | `powerbarAppearance` | true |
| `shape.borderWidth` | number 0.5 to 3, step 0.5 | `powerbarAppearance` | theme's border width |
| `surface.opacity` | number 0 to 100, step 5 | `powerbarAppearance` | theme's bar background alpha (100 if none) |
| `surface.blur` | bool | `powerbarAppearance` | false |
| `surface.text` | choice theme, light, dark | `powerbarAppearance` | theme |
| `shadow.enabled` | bool | `powerbarAppearance` | false |
| `shadow.softness` | number 2 to 24, step 1 | `powerbarAppearance` | 16 |
| `shadow.strength` | number 5 to 60, step 5 | `powerbarAppearance` | 30 |
| `shortcut.bar:keys`, `shortcut.bar:search`, `shortcut.group:<id>`, `shortcut.widget:<plugin id>` | keys text | `powerbarShortcuts` | see INTEG-125 |

Setting names are those of Preferences. `set` of `style` also drops `powerbarIslands`. `get style` answers the style chosen, also in the notch mode, which draws islands whatever it is (appearance.md LOOK-143).

### Functions

- **INTEG-122** `status` answers JSON `{bar, version, theme, settings: {<name>: value}, widgets, groups, shortcuts, runtime}`; `runtime` is `{barOff, hidden, held, screens: [{screen, shown, peeking}], keys, drawer: {zone, group} | null, preferences: {open, page}, registry, build}` (`page` is `Layout`, `Groups` or `Bar` while open, else `""`; `registry`: INTEG-143; `build`: the digest of INTEG-147).
- **INTEG-123** `get <setting>` answers the value as JSON (`"top"`, `true`, `4`; a shortcut: INTEG-125).
- **INTEG-126** `set <setting> <value>` writes the setting: bar options through `bar.<key>`; `style` through the style writer; `zones` through the zone-mode switch (layout-zones.md ZONE-73); appearance tiles through Preferences' scope and look writers. Answers `ok` or one of these errors:
  - `error: <name> is true or false` (switch), `error: <name> is one of <a, b, c>` (choice), `error: <name> is a text value`, `error: <name> is a number`, `error: <name> is from <min> to <max>`, `error: <name> moves in steps of <step>` (a numeric string such as `"4"` quoted is not a number).
  - appearance look settings while the tile follows the theme: `error: <tile> follows the theme; set <tile>.scope to all or this first`.
  - `scope` and `surface.text` before the theme is known: `error: the current theme is not known yet`.
- **INTEG-127** `reset <setting>` returns it to its default: a bar option's key is deleted from `shell.json`; `style` deletes `powerbarStyle` and `powerbarIslands`; `zones` switches to three zones; a scope returns to its default scope; a look value is deleted from the scope the tile follows (when the tile follows the theme: `ok`, nothing changes); `surface.text` returns to `theme`; a shortcut returns to its default (INTEG-125). Same unknown-setting and cannot-save errors.
- **INTEG-128** `toggle <setting>` flips a bool setting (`true` becomes `false`, anything else becomes `true`); other types: `error: <name> is not a switch`.
- **INTEG-129** `settings` answers the table above as a JSON array plus the entry `{name: "shortcut.<target>", type: "shortcut", key: "bar.powerbarShortcuts", targets: ["bar:keys", "bar:search", "group:<id>", "widget:<plugin id>"]}`.
- **INTEG-130** `widgets` answers a JSON array, one per layout entry in layout order: `{id, instance, name, zone, index, visibility, group, centered, activityPeek, badgeProperty, urgentProperty, settings}`; `visibility` is `shown`, `managed` or `hidden` (as drawn now); `group` is the group id or `""`; `centered` is true for the centre widget named by `centerAnchor`; `settings` holds the entry's own options (everything except `id` and `powerbar*` keys).
- **INTEG-131** `setWidget <widget> <json>` takes a widget by instance key, or by plugin id when only one is on the bar, and a JSON object with any of `zone` (`left`|`center`|`right`), `visibility` (`shown`|`managed`|`hidden`), `before` (a widget selector, or `""` for the zone's end), `group` (a group id, or its name when no other group has it, or `""` for none), `activityPeek` (bool), `badgeProperty`, `urgentProperty` (property names, `""` for the default), `centered` (bool). The change lands whole or not at all. A widget that only changes visibility keeps its place; naming `before` or another `zone` moves it (a neighbour brings it to that zone; no neighbour: the zone's end). Errors:
  - `error: name a widget by its id or instance`, `error: no widget <sel> in the layout`, `error: <sel> is on the bar <n> times; name one instance: <key>, <key>`
  - `error: a widget change is a JSON object such as {"visibility":"managed"}`, `error: unknown field <f>; fields are zone, visibility, before, group, activityPeek, badgeProperty, urgentProperty, centered`
  - `error: zone is one of left, center, right`, `error: visibility is one of shown, managed, hidden`, `error: before names a widget, or "" for the zone's end`, `error: group is a group's id, or "" for none`, `error: activityPeek is true or false` (same for `centered`), `error: badgeProperty is a property name, or "" for the default` (same for `urgentProperty`), `error: <value> is not a property name`
  - `error: a widget can't go before itself`, `error: before names a widget in the <zone> zone, not <zone>`
  - `error: centered is for a widget on the bar in the center zone`; `centered: false` on the anchor clears `centerAnchor`.
- **INTEG-132** `groups` answers a JSON array: `{id, label, icon, iconFont, iconImage, iconTint, zone, before, visibility, face, tooltip (bool, or null if unset), badge, badgeMode, memberDisplay, members: [{instance, id}]}`.
- **INTEG-133** `newGroup <name>` makes a group named by the trimmed name (at most 80 characters; empty gives `New group`) and answers `{"id":"g-<time>-<random>"}`.
- **INTEG-134** `setGroup <group> <json>` takes a group by id, or by name when unique, and an object with any of `label`, `icon`, `iconFont`, `iconImage`, `iconTint`, `zone`, `before`, `visibility`, `face`, `tooltip`, `badge`, `badgeMode`, `memberDisplay`, `members` (widget selectors; leavers go first, the rest are appended in the order given). Choices: `visibility` shown|managed|hidden; `face` glyph|text|both; `badgeMode` sum|members; `memberDisplay` native|name|both; `iconTint` text|own; `iconFont` omarchy or `""`. Errors: Values it would not keep whole are refused: a label over 80 characters (`error: label is at most 80 characters`), an icon of more than one glyph or emoji (`error: icon is one glyph or emoji`), an `iconImage` that is not an absolute path (`error: iconImage is an absolute path to an SVG or PNG`).
  - `error: no group <sel>`, `error: <n> groups are called <sel>; name one by id: <id>, <id>`
  - `error: a group change is a JSON object such as {"label":"Media"}`, `error: unknown field <f>; fields are <list>`
  - `error: <field> is one of <choices>`, `error: tooltip is true or false` (same for `badge`), `error: label is a name`, `error: <icon|iconImage> is a glyph or an image path`, `error: zone is one of left, center, right`, `error: before names a widget, or "" for the zone's end`, `error: members is a list of widgets, by id or instance`, `error: iconFont goes with icon`
  - `error: before names a widget in the <zone> zone` (neighbour outside the group's zone); a member selector fails as in `setWidget`.
- **INTEG-135** `removeGroup <group>` dissolves the group (its widgets stay); selector errors as `setGroup`.
- **INTEG-125** `shortcuts` answers `{ready, shortcuts: [{target, name, keys, source, fallback, positional, ready, live}]}` (`live` only for a shortcut set in Powerbar: whether Hyprland has it bound, KEYS-72) for `bar:keys` and `bar:search` (always listed), every group, every widget id and any other target in `powerbarShortcuts`, keeping only those that hold keys, have a positional bind or have a source; it then re-reads Hyprland, so the next answer is current. `get shortcut.<target>` answers that one object. `set shortcut.<target> <keys>` takes keys like `SUPER + B`, `""` for none (Omarchy's own bind goes too), or `{"keys":"...","replace":true}` to take keys another bind holds; `reset shortcut.<target>` restores the default. Errors:
- **INTEG-140** `clearShortcuts` removes every shortcut Powerbar set and its block in `bindings.lua` (Omarchy's own binds come back); `ok`, or the errors of INTEG-125 while shortcuts are being written or read. The README's removal steps run it before `omarchy plugin remove`. Code: BarCli.qml clearShortcuts()
  - `error: a shortcut is keys such as "SUPER + B", "" for none, or {"keys": "…", "replace": true}`
  - `error: no group <id>`, `error: a shortcut target is bar:keys, bar:search, group:<id> or widget:<plugin id>`
  - `error: a shortcut change is still being applied; try again in a moment`, `error: reading Hyprland's shortcuts; try again in a moment` (first use; retry)
  - keys Hyprland cannot bind: the text from `ShortcutModel.bindable`.
  - taken: `error: <keys> is taken by <description>[, ...]; to take it anyway: omarchy-shell powerbar set shortcut.<target> '{"keys":"<keys>","replace":true}'`.
- **INTEG-136** `show`: if the bar is switched off (`bar-off`), runs `omarchy-toggle-bar off` (it comes back); if `autoHide` is on, holds the bar out until `hide` (as the pointer at its edge). `hide`: if `autoHide` is on, lets the bar slide away; otherwise, if the bar is not off, runs `omarchy-toggle-bar on`. Both answer `ok` at once. Turning `autoHide` off releases the hold.
- **INTEG-137** `keysOn` starts the keyboard mode on the focused monitor's bar (`ok` if already on); `error: not while Preferences are open` or `error: no bar to put the cursor on` when it cannot. `keysOff` ends it (`ok` always). `keys` toggles it (no answer). `keysSearch` starts it with the search open, or ends it while a search is open (keyboard.md KEYS-83). `keysStatus` answers its state as JSON (keyboard.md).
- **INTEG-147** `build` answers `{version, digest, commit, dirty, loadedAt, dir}`: the code this shell loaded. As the bar loads it runs `BuildStamp.sh` on its own folder (`dir`) once: `digest` is 12 hex digits of a SHA-256 over the names and contents of the top-level `*.qml`, `*.js`, `*.sh` and `manifest.json`, so a copy without `.git` (a box, `omarchy plugin add`) has its checkout's digest; `commit` is the short git commit when the folder is a git work tree, else `""`; `dirty` is whether any of those files differ from it. `digest` is `""` until the stamp has run (the first moments after load). `tools/build-check.sh [-b BOX]` runs the same stamp on the checkout and compares: `current: …` (exit 0), `stale: …` with both sides (exit 1: restart the shell), `no answer: …` (exit 2). `tools/smoke.sh` asserts the box is current. Code: BuildStamp.sh, Bar.qml `buildStamp`, BarCli.build()
- **INTEG-138** `help` answers a JSON array of `{call: "omarchy-shell powerbar <fn> <args>", does: "<text>"}`, one per function above.

### Panels and drawers

- **INTEG-46** `preferences` opens Preferences on the focused monitor, or on the first screen when none is focused. `closePreferences` closes it.
- **INTEG-48** `preferencesPage <n>` opens Preferences (if closed) at page `n`: 1 Layout, 2 Groups, 3 Bar; `n` above 3 opens Bar; 0 or negative changes nothing (the window still opens). Code: `setPage(min(n, pages) - 1)` ignores an index below 0.
- **INTEG-54** `groupsPreferences` opens Preferences at Groups (page 2).
- **INTEG-49** `managed <left|center|right>` opens that zone's On demand drawer for the keyboard on the focused monitor's bar (another monitor's only while no monitor is focused, as `keys` picks it); any other zone, or a focused monitor with no bar, does nothing and answers nothing. `closeManaged` closes the open drawer or group menu.
- **INTEG-52** `group <id>` opens that group's drawer on the focused monitor's bar for the keyboard (chosen as `managed` does); nothing happens if the id or monitor is unknown. `toggleGroup <id>` closes it when that group's drawer is open, else opens it.
- **INTEG-56** `drawerStatus` answers `{"opened": false}` with no drawer, else JSON with `opened`, `aside`, `opacity`, `zone`, `groupId`, `memberDisplay`, `stripVertical`, `surfaceRole`, `surfaceRadius`, `themeRadius`, `crossLength`, `desiredCross`, `reveal`, `width`, `height`, `entered`, `sourceHovered`, `hovered`, `keyboard`, `cursor`, `selectionVisible`, `focused`, `ids`, `count`.
- **INTEG-57** `managedStatus` answers an array of On demand widgets: `{id, key, zone, revealed, mainVisible, inDrawer, panelOpen, observing}`.
- **INTEG-58** `popupStatus` answers an array of open widget panels: `{position, x, y, width, height, screenWidth, screenHeight, gap, barExtent}`; `[]` when none.

## Multi-monitor

- **INTEG-66** The focused monitor is Hyprland's; with none, `focusedScreenName()` is `""`.
- **INTEG-67** `preferences` (and so `preferencesPage`, `groupsPreferences`) fall back to the first screen when no monitor matches; `managed`, `group` and `toggleGroup` do not (INTEG-49, 52).
- **INTEG-68** A widget's image for the drawer and name card is captured on its own screen's bar only.

## Config write flow

- **INTEG-101** Edits from Preferences, drags and the CLI are queued; 300 ms after the last (waiting for in-flight settles) they are applied in one `shell.mutateShellConfig`, and the host reloads the file and injects `barConfig` again.
- **INTEG-149** The write also waits while the user is at the bar: the pointer on any bar or in a drawer, the keyboard mode on, or a widget's panel open (Bar.qml barInUse). Omarchy's handling of a write re-registers every bar widget and stalls the shell for hundreds of milliseconds, so it lands where the stall goes unseen: 300 ms after the last of those ends. Still at the bar 20 s after the last edit, it is written anyway. Preferences is not the bar: its edits keep the 300 ms debounce (the keyboard mode ends when it opens, KEYS-81). Before, a drag's write landed 300 ms after the drop, under a pointer still on the bar, and keyboard drags held it only while Shift was down. Code: ConfigStore.qml idle, idleWait.
- **INTEG-102** Until then the bar shows the queued edits on top of the host's config; a `barConfig` arriving meanwhile does not undo them.
- **INTEG-103** If the write fails the bar shows the host's config again and Preferences' footer reads `Could not save. Check that shell.json is writable.`
- **INTEG-144** Powerbar writes shell.json only while the bar config the shell last delivered (under any queued edits) names Powerbar as the bar (`bar.id`). Omarchy saves its whole config with every bar write, and a shell.json it could not read (caught mid-write by another program) leaves it holding its defaults, which name no bar; a write then would save those defaults over the user's file. So with a config that does not name Powerbar: no edit is queued or written, the first-start ids are not written, and queued edits are dropped with `powerbar: the shell's config no longer names Powerbar as the bar; <n> change(s) not saved`. Code: `BarModel.ownsBarConfig`, ConfigStore.qml `canWrite()`, `flush()`.
- **INTEG-145** An edit that throws on the config (a malformed entry it did not expect) is dropped with `powerbar: a config change failed and was dropped: <error>`; the other queued edits are shown and written, and `writeConfig` answers false for it, so Preferences' footer reads `Could not save…`. Code: ConfigStore.qml `runEdits()`.
- **INTEG-148** A layout entry another writer saved without Powerbar's keys gets them back. Omarchy's `updateEntryInline` (a widget changing its own settings: the clock's format cycle, the tray pinning an icon) saves the entry as `{id}` plus the settings it was handed, which drops `powerbarInstance` (the clock, power, tailscale) and, from the tray, every `powerbar*` key; a new instance id would take the widget out of its group (its members are instance ids) and the next prune would remove it from `powerbarGroups` for good. So the bar keeps the layout it last showed, and a delivered config with an entry lacking `powerbarInstance` is not shown: each such entry takes the `powerbar*` keys it lacks (a key the writer set stays) from a previous entry of the same id whose instance is not in use, the same zone and position first, then the same zone, then any zone; the keys go back as a queued edit, so the bar shows the entry with them at once and shell.json has them after the next write. A widget removed and added back elsewhere in one write keeps its old instance the same way. No match (a new widget, the bar's first config): new ids as before. When the edit cannot be queued or its write fails, the config is shown as delivered and new ids follow. New ids and the group prune wait while keys are missing. Code: `BarModel.lostKeys`, `BarModel.applyLostKeys`, Bar.qml `restoreLostKeys()`.
- **INTEG-139** On shutdown queued edits are flushed.
- **INTEG-141** Failures that change what the user sees are logged to the shell log with a `powerbar:` prefix: a config write the shell refused (the bar shows the saved config again), a drop that failed (the widget stays where it was), an unreadable widget face cache, shortcuts not written (with the exit status), and the registry heal (INTEG-31). Code: ConfigStore.qml flush(), ShortcutStore.qml applyProc
- **INTEG-142** A widget hosted by Powerbar gets Omarchy's service-less entry facade, as under any third-party bar: `bar.shell.serviceFor(<its own id>)` returns null, so a `bar-widget` + `service` plugin's button and panel do nothing while its service runs. Omarchy's design since #9618, not Powerbar's; README Known limitations links the open issues (#11051, #11713, #11796, #12648, #13289, #14101) and PRs (#11970, #13194, #12260). Code: Omarchy shell.qml pluginShellForBarEntry; Powerbar does not override it.

---

## Doc drift

- README.md "Command line" (being rewritten): check that its function list equals `help` (31 functions, INTEG-138) and that groupsPreferences opens Groups, not Bar (Bar.qml:595 `setPage(1)`; the earlier draft of this file said Bar).
- Bar.qml:642 comment says "the 30 s guard"; the code guard is 60 000 ms (Bar.qml:653 `< 60000`).

## Open questions

- INTEG-Q1: when does the host bump `barWidgetRegistry.revision`? The shell, not Powerbar, decides; Powerbar only re-checks 2.5 s after any change.
- INTEG-Q2 (answered): the heals' edits are `AppearanceModel.migrate` (INTEG-35), `pruneThemes` (INTEG-36) and `GroupsModel.groups` (INTEG-40).
- INTEG-Q3: `preferencesPage 0` / negative opens the window but keeps the last page; probably should clamp to page 1 (bug candidate, Preferences.qml:102 `setPage` returns for index below 0).
