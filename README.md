# Powerbar

A customizable Omarchy bar, cloned from `omarchy.bar`. Its plugin ID is
`p0werj0int.powerbar` and its bar entry point is `Bar.qml`.

Powerbar is based on the [Omarchy bar](https://github.com/omacom/omarchy/tree/quattro/shell/plugins/bar),
whose original copyright and MIT license notice are preserved in [LICENSE](LICENSE).
The `author` field names the maintainer of this modified plugin; Omarchy remains
credited as the source of the cloned bar.

## Preferences

Click the nine-dot button at the far right of a horizontal bar (at the bottom
of a vertical bar). Preferences open in the center of that monitor, and every
part of them works from the keyboard.

- **Layout** shows your bar as tiles, one shelf per visibility, each with your
  three zones side by side (Top, Center and Bottom on a side bar). Widgets on
  the bar show as icons, as the bar draws them; the other shelves add names.
  The shelves are:
  - **On the bar** keeps a widget slot visible. If the widget has no visible
    content, Powerbar displays a fallback icon. Clicking it does what clicking
    the widget would: it presses the widget's own button even while the widget
    hides itself (the Omarchy update widget runs `omarchy-update`), or calls its
    `toggle()` or `open()`; only a widget with no action opens preferences.
  - **On demand** (Managed) is hidden at rest. Events and icon/value changes
    reveal the widget for 2.5 seconds, the same time an autohidden bar peeks
    out for activity, so the widget and its island leave together. Bar > On
    demand picks how you reach the rest:
    - **In a drawer** (the default): hover the zone to open a drawer of these
      widgets beside the bar.
    - **In the bar**: they wait behind the zone's dots (⋯ with a count, shared
      with widgets folded for lack of room). Hover the dots and the zone
      expands in place while the neighbouring zone makes room, as for an
      activity reveal. The zone collapses after the exit grace once the pointer
      leaves it. If the expansion can't fit, the zone's drawer opens instead.
      The keyboard (`powerbar managed <zone>` over IPC, or Enter on the dots) always uses
      the drawer.
  - **Hidden** removes the widget from the bar without deleting its settings or
    disabling its plugin elsewhere in the shell.

  Widgets appear as they draw themselves, including third-party widgets:
  drawer and group members are rendered live because they stay loaded, and a
  hidden widget shows the last look Powerbar saw, kept in
  `~/.cache/powerbar/widgets/`. Every preview draws a horizontal bar at your
  bar's size, whatever edge the bar is on; with a side bar, widgets show their
  saved horizontal look, since only a horizontal bar is ever captured. A
  widget Powerbar has no image of shows its own glyph instead, read from the
  button it draws on the bar at either orientation and kept in
  `~/.cache/powerbar/glyphs.json`, so a widget added to a side bar still
  shows its icon. Only a widget that draws no font glyph (a picture, or a
  value such as the clock) falls back to a stock one.

  A tile under the shelves holds the selected widget's settings: its zone and
  visibility (the way to move it without dragging), Show on activity, whether
  it is kept at the exact screen center, and its group. A setting that does
  not apply stays in place, dimmed, with the reason under it.
- **Groups** is tiles too: a shelf of your groups drawn as the bar draws them,
  the selected group's settings (icon and name, what the bar shows, zone,
  visibility, badge) in columns whose rows line up, then its drawer drawn as it
  opens beside the widgets not in a group. The icon opens a picker that
  searches the glyphs your widgets draw, Omarchy's own icons and its emoji, or
  takes your own SVG or PNG.
- **Bar** is everything about how the bar looks and behaves, in tiles; changes
  show on the bar itself. The tiles are Style and position (a picture of your
  screen with the bar in its style on its edge, the style and edge choices, and
  the widget pinned to the screen center), Size (large bar and widget spacing), Shape (rounding and borders), Surface
  (opacity, blur, readable over windows), Shadow, Behavior (autohide and
  animations) and On demand. They are laid out like your tiled windows: twice
  Hyprland's inner gap apart, with its corner rounding, in 12, 6 or 1 columns
  as the window narrows. Fonts and colors follow Omarchy.

### Keys

The footer always lists the keys for whatever has focus, and an accent ring
follows keyboard focus.

| Where | Keys |
| --- | --- |
| Anywhere | `1`–`3` or Ctrl+`1`–`3` switch pages, Ctrl+Tab cycles them, Tab / Shift+Tab move between controls, Esc closes |
| Forms | `j` / `k` or Up / Down move between controls, `h` / `l` or Left / Right adjust (Shift for larger steps), Space / Enter toggle or choose |
| Bar page | Tab / Shift+Tab jump to the next or previous tile; `r` twice resets the focused tile to the theme |
| Sliders | Home / End for the ends, Backspace for the default, Enter applies now, Esc undoes a value not yet applied |
| Layout shelves | `h` `j` `k` `l` move; Space picks up the widget, then `h` / `l` move it along and across zones and `j` / `k` or Tab change its shelf; Space or Enter drops it, Esc puts it back; `x` hides or restores; Enter goes to its settings (Esc comes back); Tab jumps to the next tile; `g` edits a group |
| Groups shelf | `h` / `l` choose, `n` makes a group, `x` twice dissolves it, Enter goes to its icon |
| Drawer and list | `j` / `k` choose; in the drawer Space picks up to reorder and `x` removes; in the list Enter adds and typing filters |
| Icon picker | Type to search, arrows move, Enter chooses, Tab changes the source, Ctrl+V pastes an image or a glyph, Esc clears then closes |

With the pointer, drag any widget in Layout or between the drawer and the list;
the landing place is previewed before you let go.

Changes apply immediately and persist through the host in `~/.config/omarchy/shell.json`.
**Bar style** (Bar → Style and position) is one of three, shown on a small
picture of your screen; click another edge of the picture to move the bar there:

- **Flat** runs edge to edge and meets the screen edges, square, like Omarchy's
  own bar.
- **Floating** is one continuous surface held off the screen edges, with the
  theme's border and corner rounding.
- **Islands** wrap each visible zone in the theme's border and corner rounding
  over a transparent backdrop.

Floating bars and islands keep the same distance from the edges, and all three
use the shared surface appearance. The preferences button stays in the right
zone (bottom zone on vertical bars).

**Autohide** (Bar → Behavior) stops the bar from reserving screen space and
parks it past its edge. Moving the pointer to that edge slides it back over the
windows, and it stays out while hovered, while a drawer, widget panel, drag or
Preferences is open, then slides away 400 ms after the pointer leaves. A 2 px
strip along the edge remains clickable for the bar while it is hidden. It works
with every bar style and on every edge.

Omarchy's bar toggle (Super+Shift+Space, `omarchy toggle bar`) brings an
autohidden bar out the same way instead of switching it off: it stays out while
the toggle's key is held and slides away 400 ms after the key is let go. The
`bar-off` flag goes back off, so turning autohide off later never finds the bar
hidden. Powerbar binds nothing for this; it asks Hyprland whether the key of
the bind described "Toggle top bar" (or any modifier) is still down.

While the bar is hidden, widget activity still shows (turn this off with
**Show on widget activity** under Bar → Behavior, or for single widgets
with **Show on activity** in the Layout page's settings tile; the keys are
`powerbarAutoHideActivity` and a widget's `powerbarActivityPeek: false`): when a widget's icon or
value changes, its island slides out (the whole bar for flat and floating
styles), the widget is highlighted as if hovered, and after 2.5 seconds it slides
back. More activity keeps it out. Activity in a group member highlights the
group's icon. The clock is ignored, since it changes every minute, and so is
anything in the first few seconds after the bar starts or its layout changes,
while widgets load their first values.

The added bar keys are `powerbarStyle` (`flat`, `floating` or `islands`),
`powerbarAutoHide` and `powerbarSpacing`. Configs from before bar styles keep
working: `powerbarIslands: true` reads as islands and anything else as flat,
and choosing a style replaces the old key; each layout entry
may have `powerbarVisibility` (`shown`, `managed`, or `hidden`). Without an explicit choice, Omarchy system
widgets default to Always shown and custom widgets to Managed. Stable
`powerbarInstance` keys are assigned once to distinguish duplicate instances.
Existing inline settings and duplicate widget instances are preserved.
The system tray retains Omarchy's placement at the inner edge of its section.

Widget files hot-reload; changes to the mounted bar engine require
`omarchy restart shell`. Verify the live instance with `hyprctl instances`
first if the terminal's `HYPRLAND_INSTANCE_SIGNATURE` might be stale.

**Switching bars.** Omarchy gives each replacement bar its own copy of the
widget registry. After switching to the stock bar and back (which is also what
a first install does), that copy can point at widget components the shell has
already rebuilt, so widgets would show only placeholders until the shell
restarts. Powerbar notices this a couple of seconds after it loads and asks the
shell to rescan its plugins once (`omarchy-shell shell rescanPlugins`, at most
once a minute), after which every widget loads normally. The bar disappears
for a few seconds while that happens.

For keyboard launchers, `omarchy-shell powerbar preferences` opens preferences
on the focused monitor; `omarchy-shell powerbar closePreferences` closes them.

## Groups

Open **Preferences → Groups** to create named drawers. Choose a group to rename
it, pick its icon, set its zone, and edit its members. The icon picker searches
the glyphs your widgets draw, Omarchy's own font, the glyphs Omarchy itself uses
and Omarchy's emoji; drop, paste or type the path of an SVG or PNG to use your
own, drawn in the bar's text colour or in its own colours. Widgets you uninstall
leave their groups by themselves. Right-click a group icon on the bar to open that group in
preferences. Groups also appear with their names and icons in Layout.

Each group independently chooses what the bar shows (**icon**, **name**, or **both**),
name tooltip, notification badge, badge mode, and drawer member display
(**native icon**, **name**, or **both**). Icon-only drawers follow the bar's
orientation. The same Powerbar border, shadow, blur, opacity, and animation
settings apply to every group drawer. Named menus use the main theme's corner
radius; icon-only drawers use Powerbar's island rounding.

Badges read live count properties from the existing hosted widgets, without
polling or extra widget instances. Powerbar recognizes `unseenCount`, `downCount`,
`updateCount`, `badgeCount`, `notificationCount`, `unreadCount`, `alertCount`,
`pendingCount`, and `count`. **Add up counts** adds the values; **Count busy widgets** shows how many
members have a positive value. The badge becomes urgent when a member exposes
an urgent boolean or a positive `downCount` / `alertCount`. Select a member in
Groups to enter a custom badge or urgent property name. `none` explicitly
excludes a member from badge aggregation.

Drag widgets between the drawer and the list beside it, or reorder them within
the drawer. On the bar, group icons make way for a dragged icon like any other,
so dropping beside a group places the icon next to it. Rest the drag on a group
icon for a moment and its drawer opens: drop among the members to add the icon,
which takes the group's member style (its own look, its name, or both) as soon
as it is over the drawer. Moving away closes the drawer again. A member dragged
out of a group drawer can instead be dropped straight onto another group icon to
transfer it. Drag a member onto the main bar to
remove it from its group and show it in that zone. Dragging outside the bar and
drawers cancels the move. Hover opens a group drawer temporarily; click pins
it. Click again, press Escape, or click outside to close it. Native widget clicks,
context menus, scrolling, and popups continue to work in the native and combined
display modes; a name-only label forwards left and right clicks and scrolling
to its widget and remains draggable.
Groups showing names (NAME or BOTH) open as a vertical menu using Powerbar's
surface appearance, Omarchy's menu font, and the main theme's corner radius.
The first member is highlighted only
after keyboard navigation begins; reopening a group starts without a selection.

Membership is stored in `bar.powerbarGroups` using existing widget instance keys.
Grouped widgets stay alive while collapsed. Deleting a group restores members to
their previous placement and visibility without deleting settings or disabling
plugins. Explicitly hidden widgets remain hidden. Groups cannot contain other
groups. Third-party widgets that require a service from Omarchy's trusted bar
facade can still lose that service under a replacement bar; grouping does not
change this host restriction.

`omarchy-shell powerbar groupsPreferences` opens this page;
`omarchy-shell powerbar group <id>` opens and pins a group on the focused monitor.

Mini Bar's [reference design](https://github.com/JMThomas00/omarchy-mini-bar)
informed these controls; Powerbar implements them in its own group model and
existing drawer without adding a second widget host or helper daemon.

## Shadows and backdrop blur

Bar → Behavior offers **Animations** (enabled by default). Main
and extended islands ease to their new size as widgets change; drawers grow out
of their edge over 160 ms and close over 110 ms, both on a strong ease-out
without overshoot. Widget spacing and island size share a 120 ms ease-out
resize, keeping icons inside the island while neighbours move into or out of the
row. An autohiding bar slides out over 180 ms and away over 130 ms. Once one
bar tooltip has shown, its neighbours show without the usual delay.
Widgets leave the main bar before opening begins and return after closing finishes.
Moving between zones replays the opening animation at the new zone.
Widgets control their own icon and status animations.
Main-bar actions finish drawer dismissal immediately before opening a popup.
Turn Animations off to make these changes immediate.

Hovering a widget, activity in it and an open panel share one highlight: as
thick as the bar less a small inset, as long as what the widget visibly paints
plus equal padding, and never shorter than it is thick. Every icon therefore
gets the same circle or rounded square and text gets a pill; one corner radius,
nested inside the island's, and the highlight never leaves its island.

**Large bar** (`powerbarLargeBar`) makes the bar 12 px thicker (Omarchy's size
plus a 6 px lip above and below each widget) and doubles the islands' end padding.
Text and icons keep their size; widgets gain room around them and their
highlights grow with the bar. Drawers and the Layout
page's On the bar shelf follow the same thickness.

The **Shape**, **Surface** and **Shadow** tiles apply one set of controls to the
full bar, main islands, and extended islands, including group drawers: borders
on/off and their thickness (0.5–3 px), rounding (square up to a full pill at the
bar's thickness), blur on/off, background opacity (0–100% in 5% steps), shadow
on/off, softness (2–24 px) and strength (5–60%). **Text and icons** (`powerbarForeground`) is
the theme's colours by default, or one fixed **Light** or **Dark** colour (the
theme's own bar text and background, whichever is lighter or darker) for every
Powerbar surface: the bar, drawers and menu-style groups. Powerbar never picks
it from the wallpaper, even with Omarchy's transparent bar on: it draws a
surface behind every widget and cannot know what shows through it. Opacity works independently of blur. Blur strength
follows the desktop's Hyprland settings. **Readable over windows** (on by
default, `powerbarReadableOverlay`) keeps surfaces that lie over windows, which
means every drawer and the bar itself while it autohides, at least 88% opaque
unless blur is on, so page text never shows through widgets.

Shared effect keys use `powerbarBlur`, `powerbarBackgroundOpacity`, `powerbarShadow`,
`powerbarShadowSize`, and `powerbarShadowOpacity`. Existing main-bar settings supply
the initial appearance; old extended-island overrides are ignored. Legacy opacity
that was inactive with blur off does not suddenly make the bar translucent.
Reset appearance clears both the shared settings and old per-surface fallbacks.

Backdrop blur needs these Powerbar-only rules in your Hyprland Lua configuration
(already installed on this development machine in `~/.config/hypr/looknfeel.lua`):

```lua
hl.layer_rule({
  match = { namespace = "^powerbar$" },
  no_anim = true,
  animation = "none",
  blur = true,
  ignore_alpha = 0.01,
})
hl.layer_rule({
  match = { namespace = "^powerbar-clear$" },
  no_anim = true,
  animation = "none",
  blur = false,
})
```

Powerbar briefly remaps its surface when switching the blur preference so the
compositor applies the new namespace immediately. The alpha threshold leaves
fully transparent space clear. Shadows are drawn locally around each surface,
with stable off-screen padding so opening drawers does not resize the bar window.

## Managed drawers and activity

Hover a visible widget in the Left, Center, or Right zone to open that zone's managed
drawer. A small handle remains when a zone has no visible widgets. Drawers open
toward the desktop; on vertical bars they run vertically beside the main bar.
Drag an icon into an open managed drawer to place it in that zone as Managed;
drag it back to the main bar to make it Always shown. Group members can use
these same destinations, which removes them from the group.
During a drag, the icon itself follows the pointer. The source space stays put
until the icon leaves it; then nearby icons make room with a short animation,
and the receiving island grows with the gap, plus a small lip at both ends so the space past its last icon is an obvious place to drop. A release that drifts a little off the bar's inner edge still lands on the bar. Dropping a group icon beside another group reorders the groups; dropping
it into a managed drawer makes the whole group Managed. Groups cannot be nested.
A zone's dots are a drop target too, so an icon from one extended island can
move directly into another zone's On demand widgets even while its source
drawer is open.
They reserve no additional workspace space. Their transparent area is click-through
when closed, and the bar surface keeps a stable size to avoid resize flicker.
Clicking a main-bar widget closes the drawer before activating the widget.
The original widget presentation is
moved into the drawer, keeping its controls, state, and services alive. While there,
its activation indicator stays in the drawer and its main-bar slot is hidden.

The drawer stays open while hovering its source zone or its contents. After
leaving the source zone, you have 5 seconds to enter the drawer; after leaving
the drawer, it closes after 3 seconds. Re-entry cancels dismissal, and entering after a timeout opens it immediately. Opening a
widget's panel holds the drawer until that interaction ends. General's **Managed
widgets** sliders configure activity, entry, and exit durations (10/5/3 seconds).

Keyboard entry: `omarchy-shell powerbar managed left` (also `center` and `right`).
Use Tab/Shift+Tab or arrows to choose a widget, Enter/Space to activate, and
Escape to dismiss. Hover opening does not acquire keyboard focus. Only one
drawer is open at a time. Preferences, hiding the bar, and changing its edge
close it.

Powerbar observes QML property-change signals on the widget root and its
registered bar buttons: `text`, `icon`, `iconText`, `value`, `displayValue`,
`powerbarIcon`, `powerbarValue`, and `powerbarActivityRevision`. Widgets can also
emit `signal powerbarActivity()` for repeated events with unchanged presentation.
Initial values establish a baseline. Equal values, geometry, opacity, and theme
colors are not activity. Each event restarts the reveal interval; frequently
changing values can keep a widget visible continuously. Powerbar adds no polling.
Widgets without exposed presentation signals still work in the drawer.

Custom border thickness and corner rounding have sliders, and the Shape,
Surface and Shadow tiles each have a Reset to the theme, shown only while one of
their settings is set. Sliders keep a draft while you work them and apply it to the bar
once it settles (on release, or after a short pause for keys and the wheel),
and their ranges stop where more stops looking different: rounding tops out at
a full pill for the bar's thickness. Bar size uniformly scales icons, text, and controls, including third-party
widgets; drawer contents use the same scale. All numeric preferences use sliders.

## Validation

```sh
node --test tests/*.test.cjs
# QML tests run against Omarchy's real Commons and Ui, linked from outside the
# plugin (plugins may not contain symlinks), with Quickshell stubbed.
KIT=$(mktemp -d); mkdir -p "$KIT/qs"; ln -s /usr/share/omarchy/shell/Commons /usr/share/omarchy/shell/Ui "$KIT/qs/"
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -import tests/qml/imports -import "$KIT" -input tests/qml -o -,txt

# Exercise the actual badge and editor startup bindings with fictional data.
node tests/startup-probe.cjs /tmp/powerbar-startup-probe
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input /tmp/powerbar-startup-probe -o -,txt
omarchy plugin validate "$PWD"
/usr/lib/qt6/bin/qmlformat --normalize Preferences.qml >/dev/null
```

The model tests cover movement among all nine cells, preserving settings and
unrelated config, duplicate instances, reordering, stale drags, and visibility
transitions that retain or remove the affected live owners. The QML suite covers
retention, scoped API updates, idle geometry, shared indicators and capture
lifecycle using controlled fixtures. See [rendering implementation evidence](docs/rendering-performance-implementation.md).
Live checks additionally cover loading,
opening from the nine-dot button, keyboard movement, drag-and-drop, persistence,
and Escape dismissal. Multi-monitor behavior still needs a multi-monitor session.

## Bar architecture

- Omarchy's built-in bar widgets (`omarchy.*`, such as Workspaces, Tray and Indicators) come from Omarchy's own bar plugin; the `omarchy.*` id namespace is reserved for them, so this plugin carries no copies.
- Feature plugins such as `../panels/audio/`, `../panels/network/`, `../panels/power/`, and `../agents/` provide richer popup bar plugins.
- The bar receives its config from the host shell as a `barConfig` property; the host loads it from `~/.config/omarchy/shell.json` (or `config/omarchy/shell.json` when the user has no file).
- `omarchy bar position` updates only the user shell.json file.

## Customizing

The bar config lives under the `bar:` key of [`~/.config/omarchy/shell.json`](../../README.md#shelljson-shape). Out of the box the shell uses [`config/omarchy/shell.json`](../../../config/omarchy/shell.json). Once you customize anything via the bar gestures, `omarchy bar ...`, or by editing shell.json directly, your file is canonical — there is no deep-merge.

The bar is configured directly on the bar itself: drag empty bar space (or click-and-hold) to move the bar to another screen edge, double-left-click empty center-bar space to toggle transparency, and drag widgets to reorder them. The `omarchy bar position`, `omarchy bar transparent`, `omarchy bar move`, and `omarchy bar set` commands do the same from scripts. Enable or disable widgets with `omarchy plugin enable` and `omarchy plugin disable` (widget ids come from `omarchy plugin list`).

Example `shell.json` (bar subtree only shown):

```json
{
  "version": 1,
  "bar": {
    "position": "top",
    "transparent": false,
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left": [
        { "id": "omarchy.menu" },
        { "id": "omarchy.spacer", "size": 12 },
        { "id": "omarchy.workspaces" }
      ],
      "center": [
        { "id": "omarchy.media" },
        { "id": "omarchy.clock", "format": "HH:mm" }
      ],
      "right": [
        { "id": "omarchy.audio" },
        { "id": "omarchy.power" }
      ]
    }
  }
}
```

`centerAnchor` pins one center module to the exact horizontal/vertical center and flanks others around it. Set to an empty string to disable anchoring (the center list is centered as a group).

## Module catalogue

### First-party interactive widgets

| Name | What it does | Interactions |
|---|---|---|
| `omarchy.menu` | Omarchy menu launcher | left = menu · right = terminal |
| `omarchy.workspaces` | Hyprland workspace switcher | left = focus workspace |
| `omarchy.clock` | Date/time label + popup with a month grid, ISO week numbers, and month stepping | left = popup · right = cycle label format · middle = timezone selector |
| `omarchy.media` | MPRIS now-playing — scrolling track + artist, cover-art popup | left = play/pause · middle = next · scroll = prev/next · right = popup |
| `omarchy.indicators` | Manual state indicators | left = indicator action |
| `omarchy.system-update` | Available update indicator | left = update |
| `omarchy.tray` | System tray | hover = reveal drawer · right on chevron = manage |
| `omarchy.weather` | Weather icon + popup with forecast | left = popup · right = full notification |
| `omarchy.microphone` | Mic icon + scroll volume | left = mute toggle · middle = audio panel · scroll = source volume |

| `omarchy.audio` | Volume icon + popup with master slider, output-device picker, per-app mixer | left = popup · right = mute · middle = popup · scroll = volume |
| `omarchy.network` | Wi-Fi/Ethernet icon + popup with Wi-Fi scan, signal, connect, DNS provider selection | left = popup |
| `omarchy.tailscale` | Tailscale status, connection switcher, machine browser, and copy actions | left = popup · right = toggle · middle = refresh |
| `omarchy.agents` | AI coding agent limits with pace, today, last week, and all-time model breakdown | left = panel · right = launch agent · middle = next subscription |
| `omarchy.power` | Battery/AC icon + popup with battery stats, power profiles, and system info | left = popup · right = toggle percentage |
| `omarchy.bluetooth` | Bluetooth icon + popup with device list, connect/disconnect, battery | left = popup · right = toggle radio |
| `omarchy.monitor` | Brightness and laptop display controls | left = popup |

The `omarchy.indicators` widget (Omarchy's built-in) loads its individual bar indicators from Omarchy's own bar plugin. Omit `items` (or set it to an empty array) to show all indicators in the default order, or set `items` to a subset such as `["Dnd", "Reminder", "NightLight"]`. Set `alwaysShow` to `true` to keep inactive indicators visible instead of revealing them only on hover. Multiple `omarchy.indicators` instances are allowed, so different sections can show different subsets.

## Orientation

All widgets work in `top`, `bottom`, `left`, and `right` positions. Popups anchor on the side opposite the bar edge, sliding into the workspace. Vertical bars use 28px width; widgets that show text fall back to compact icon-only forms (e.g. `media` hides its scrolling label).

## Custom user modules

The schema accepts arbitrary module ids that you provide. Set `type` to `command` for shell-driven output or `qml` for a custom QML widget. Both still go under `bar.layout.<section>` in `shell.json`.

Command module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "omarchy.tray" },
        { "id": "vpn", "type": "command", "exec": "~/.config/omarchy/bar/scripts/vpn-status", "interval": 5, "tooltip": "VPN", "onClick": "nm-connection-editor" },
        { "id": "omarchy.audio" }
      ]
    }
  }
}
```

The command may print plain text or Waybar-style JSON, for example:

```json
{"text":"󰌆","tooltip":"Work VPN","class":"active"}
```

QML module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "gpu", "type": "qml" },
        { "id": "omarchy.audio" }
      ]
    }
  }
}
```

Then create `~/.config/omarchy/bar/modules/gpu.qml`. If you want to store it elsewhere, add a `source` path.

Custom QML modules should be an `Item` with `implicitWidth` and `implicitHeight`. They may optionally define these properties, which the bar fills after loading:

```qml
import QtQuick

Item {
  property var bar
  property string moduleName
  property var settings

  implicitWidth: 28
  implicitHeight: bar ? bar.barSize : 26

  Text {
    anchors.centerIn: parent
    text: "GPU"
    color: bar ? bar.foreground : "white"
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 12
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (bar) bar.run("omarchy-launch-or-focus-tui btop")
  }
}
```

## Bar properties available to widgets

Widgets receive `bar` (the shell root), `moduleName` (string), and `settings` (object) injected at load time. The bar exposes:

- `bar.foreground`, `bar.background`, `bar.urgent` — theme colors (live-updated)
- `bar.fontFamily` — current monospace family
- `bar.position` — `"top" | "bottom" | "left" | "right"`
- `bar.vertical` — boolean shortcut
- `bar.barSize` — 26 horizontal / 28 vertical, 12 more with Large bar; size a
  widget's slot to it and keep its content at the theme's size
- `bar.run(command)` — fire-and-forget bash exec
- `bar.shellQuote(value)` — safe shell-quote a string
- `bar.showTooltip(target, text)` / `bar.hideTooltip(target)` — shared tooltip popup
- `bar.requestPopout(owner)` / `bar.releasePopout(owner)` — one-popup-at-a-time coordinator

First-party bar widgets are manifest-backed just like third-party widgets.
Omarchy's simple widgets carry sibling manifests such as `widgets/Workspaces.manifest.json` in its own bar plugin;
richer popup plugins live in feature directories such as `../panels/audio/`,
`../panels/network/`, and `../agents/`; and feature plugins such as
`omarchy.menu` and `omarchy.media` declare their bar-widget entry points in their own
`manifest.json`. Bar layout ids are namespaced, e.g. `omarchy.audio`,
`omarchy.network`, and `omarchy.clock`. Older UpperCamelCase ids such as
`AudioPanel` and `Clock` are migrated forward; new configs should use the
namespaced ids.

Third-party widgets ship as separate plugins under
`~/.config/omarchy/plugins/<plugin-id>/` with their own `manifest.json`
declaring `kinds: ["bar-widget"]` and a `barWidget` entry point. See
[../../README.md](../../README.md) for the manifest schema. Rescan, enable,
and place third-party plugins with `omarchy-shell shell rescanPlugins`,
`omarchy plugin enable`, and `omarchy bar move`.
