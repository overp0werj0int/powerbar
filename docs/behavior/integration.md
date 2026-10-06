# Integration behaviors

Powerbar integrates with the Omarchy shell runtime, configuration system, and multi-monitor desktop. This area covers startup initialization, configuration healing and validation, widget registry healing, bar-off toggle, IPC endpoints, multi-monitor support, and compatibility with Omarchy bar commands and config keys.

**Sources:** Bar.qml (540–589, 2860–2869, 603–628, 745–769, 1975–1980), PluginApiSync.qml, GeometryObserver.qml, CaptureQueue.qml, OmarchyIcons.js, manifest.json, tests/startup-probe.cjs, README.md ("Module catalogue", "Custom user modules", "Bar properties available to widgets", "Known limitations"), stock bar `/usr/share/omarchy/shell/plugins/bar/Bar.qml`, `/usr/share/omarchy/bin/omarchy-bar`, `/usr/share/omarchy/bin/omarchy-toggle-bar`.

## Plugin manifest

- **INTEG-1** The plugin manifest declares `schemaVersion: 1`, `id: "p0werj0int.powerbar"`, `name: "Powerbar"`, `version: "1.0.0"`, author `"p0werj0int"`, license `"MIT"`, description `"Status bar with widgets"`, `kinds: ["bar"]`, and `entryPoints.bar: "Bar.qml"`.
- **INTEG-2** The manifest declares `omarchy.clonedFrom: "omarchy.bar"` to record that this bar is a clone of the built-in bar.

## Startup and initialization

- **INTEG-3** On plugin load, the bar reads its config from the `barConfig` property injected by the host shell (loaded from `~/.config/omarchy/shell.json` or `config/omarchy/shell.json` if the user has no file). Until injected, `barConfig` is an empty object `{}`.
- **INTEG-4** If `barConfig` is not a plain object or is falsy, the bar uses `fallbackBarConfig` (position: "top", transparent: false, centerAnchor: "omarchy.clock", layout: { left: [], center: [], right: [] }).
- **INTEG-5** After `Component.onCompleted`, the bar calls `applyBarConfig()` to apply the configuration and restarts the registry check timer (`registryCheck`).
- **INTEG-6** The bar injects a `bar` property (exposing theme colors, position, vertical, barSize, and methods like `run()`, `showTooltip()`, `requestPopout()`), along with `moduleName` and `settings`, into each instance of custom QML widgets and command widgets.
- **INTEG-7** When injected by the host, `pluginRegistry` (read-only registry view) is present for third-party full bars; the built-in bar declares it but does not otherwise use it.

## Config file and shell.json keys

- **INTEG-8** The bar config persists under the `bar:` subtree of `~/.config/omarchy/shell.json`. All `bar.*` config keys are read from `barConfig` (injected by the host on each reload). The bar never directly reads shell.json; the host owns file IO.
- **INTEG-9** `barConfig.position` specifies the bar position; valid values are `"top"`, `"bottom"`, `"left"`, `"right"`. Default is `"top"`.
- **INTEG-10** `barConfig.transparent` (boolean, default false) makes the bar background fully transparent (no theme background color).
- **INTEG-11** `barConfig.centerAnchor` (string, default "omarchy.clock") specifies which widget is anchored to the center if the bar is wider than needed.
- **INTEG-12** `barConfig.layout` (object with keys "left", "center", "right", each an array) specifies widget order in each zone. Invalid or missing zones are treated as empty arrays.
- **INTEG-13** `barConfig.powerbarAutoHide` (boolean, default false) enables auto-hiding of always-shown widgets when no activity is detected.
- **INTEG-14** `barConfig.powerbarAutoHideActivity` (boolean, default true) enables auto-hiding in response to activity events when auto-hide is on.
- **INTEG-15** `barConfig.powerbarOnDemand` (enum: "drawer" or "inline", default "drawer") controls whether on-demand (managed) widgets appear in a drawer or inline expansion.
- **INTEG-16** `barConfig.powerbarManagedRevealSeconds` (number, default 2.5, clamped to 1–60) controls the managed drawer reveal animation duration in seconds.
- **INTEG-17** `barConfig.powerbarManagedEntryGraceSeconds` (number, default 1, clamped to 1–15) controls the managed drawer entry hold time in seconds.
- **INTEG-18** `barConfig.powerbarManagedExitGraceSeconds` (number, default 1, clamped to 1–15) controls the managed drawer exit hold time in seconds.
- **INTEG-19** `barConfig.powerbarKeyLegend` (boolean, default true) shows the key legend in keyboard mode.
- **INTEG-20** `barConfig.powerbarDotsBadge` (boolean, default true) shows activity badges on zone dots.
- **INTEG-21** `barConfig.powerbarAnimations` (boolean, default true) enables animations when false.
- **INTEG-22** `barConfig.powerbarLargeBar` (boolean, default false) increases bar height by 12 pixels.
- **INTEG-23** `barConfig.powerbarSpacingMode` (enum: "gaps" or "slots", default "slots") controls whether widgets are separated by fixed gaps or elastic slots.
- **INTEG-24** `barConfig.powerbarSpacing` (number) controls the spacing scale passed to `Style.space()`.
- **INTEG-25** `barConfig.powerbarAppearance` (object) stores appearance overrides (shape/surface/shadow/blur/backdrop per theme). Default is absent; appearance falls back to theme tokens.
- **INTEG-26** `barConfig.powerbarGroups` (object) stores group definitions (names, membership, order). Default is absent; invalid group members are pruned.

## Widget registry healing

- **INTEG-27** When the bar switches to a different bar plugin (or on first install), the Omarchy shell's widget registry copy can point at components the shell has since rebuilt and destroyed, leaving every widget as a placeholder until healing.
- **INTEG-28** `registryStale()` returns true if any registered widget lacks a component (id has `component: undefined` or `component: null`).
- **INTEG-29** On initialization and whenever `barWidgetRegistry.revision` changes or the registry is injected, the bar starts a 2500 ms debounce timer (`registryCheck`).
- **INTEG-30** When the timer fires, `checkRegistry()` is called. If the registry is stale and less than 60000 ms (60s) has elapsed since the last rescan, no action is taken (guard prevents repeated rescans within 60s).
- **INTEG-31** If the registry is stale and the 60s guard has elapsed, the bar writes the current timestamp to a file at `$XDG_RUNTIME_DIR/powerbar-registry-rescan` (or `/tmp/powerbar-registry-rescan` if `XDG_RUNTIME_DIR` is unset), logs "powerbar: widget registry is stale after a bar switch; asking the shell to rescan plugins", and calls `omarchy-shell shell rescanPlugins` (a shell command that reloads all plugins, including Powerbar).
- **INTEG-32** The registry rescan guard file is a runtime file so the limit survives bar reloads but resets on shell restart.

## Config healing and cleanup

- **INTEG-33** When the theme name changes, the bar calls `healAppearance()` to clean up legacy appearance config.
- **INTEG-34** `healAppearance()` is a no-op if the bar cannot write config, the theme name is not set, or `AppearanceModel.legacyPresent(barConfig)` returns false.
- **INTEG-35** If appearance config healing is needed, the bar calls `writeConfig()` and logs "powerbar: healing appearance config" (once per theme transition), then schedules `pruneAppearanceThemes()`.
- **INTEG-36** `pruneAppearanceThemes()` removes unused theme entries from the appearance config. It is a no-op if no themes are installed, the bar cannot write config, or no stale themes are detected.
- **INTEG-37** When the bar config is applied at startup or when injected, if `AppearanceModel.legacyPresent(barConfig)` returns true, `healAppearance()` is scheduled via `Qt.callLater()`.
- **INTEG-38** When installed themes change, `pruneAppearanceThemes()` is scheduled via `Qt.callLater()` if theme entries are present.
- **INTEG-39** When `moduleSlots` changes, `prunePluginBarApis()` is scheduled via `Qt.callLater()` to remove API references for widgets no longer in the layout.
- **INTEG-40** When the bar config is applied at startup, if `GroupsModel.danglingMembers(barConfig)` returns true (group members reference widgets not in the layout), the bar schedules `pruneGroupMembers()` via `Qt.callLater()`.
- **INTEG-41** `pruneGroupMembers()` calls `writeConfig()` with a function that updates `config.bar.powerbarGroups` to remove dangling members.

## Bar-off toggle integration

- **INTEG-42** The bar reads the `bar-off` flag from the Omarchy runtime toggles directory (watched by `FileView`). When the flag is set, `barOffFlag` property becomes true.
- **INTEG-43** `barHidden` is computed as `barOffFlag && !barKeysItem.active`. When the bar is hidden by the flag but not by keyboard mode, all bar panels park off-screen without an exclusion zone.
- **INTEG-44** The stock bar shell command `omarchy toggle bar [toggle|on|off]` sets/unsets the flag. To handle flag changes that arrive in quick succession (which can strand the bar off-screen), Powerbar receives the `omarchy.bar syncHidden()` IPC call from the shell.
- **INTEG-45** When `omarchy.bar syncHidden()` is called, `barHiddenProbe.running` is set to true to re-read the flag even if the FileView watch has gone quiet.

## IPC endpoints (omarchy-shell powerbar <fn>)

The bar publishes these IPC endpoints for shell commands `omarchy-shell powerbar <fn>`:

### Control endpoints

- **INTEG-46** `preferences()` — Opens the Preferences window on the focused screen (or the first screen if no focused screen is found). Reads `root.focusedScreenName()` to find the screen.
- **INTEG-47** `closePreferences()` — Closes the Preferences window.
- **INTEG-48** `preferencesPage(page: int)` — Opens Preferences and switches to the specified page (1-indexed). If General (page 3) or Appearance (page 4) is requested, they open the combined Bar page (page index clamped to available pages). Uses `preferencesPane.pages.length` to find the max page.
- **INTEG-49** `managed(zone: string)` — Opens the managed drawer for the specified zone (e.g., "left", "center", "right") on the focused screen's bar.
- **INTEG-50** `closeManaged()` — Closes the open managed drawer.
- **INTEG-51** `keys()` — Toggles keyboard mode (same as Super+B by default).
- **INTEG-52** `group(id: string)` — Opens the drawer for the group with the specified id on the focused screen's bar. Searches `moduleSlots` for a group header entry matching the id and the focused screen name, then opens its drawer.
- **INTEG-53** `toggleGroup(id: string)` — Opens the group drawer if not open, or closes it if it is open and is showing the specified group. Returns the bar to the cursor if closing a panel.
- **INTEG-54** `groupsPreferences()` — Opens Preferences and sets the page to 2, which opens the Bar page (not Groups; should be page 1). Code: `preferencesPane.page = 2`.

### Status endpoints (return JSON strings)

- **INTEG-55** `keysStatus()` — Returns a JSON string of the result of `root.barKeys.status()`, containing keyboard mode state (current cursor, active stops, search results, name card visibility, etc.).
- **INTEG-56** `drawerStatus()` — Returns a JSON string describing the open managed drawer (or `{"opened": false}` if none). When open, includes: `opened`, `aside` (shifted aside), `opacity`, `zone`, `groupId`, `memberDisplay`, `stripVertical`, `surfaceRole`, `surfaceRadius`, `themeRadius`, `crossLength`, `desiredCross`, `reveal`, `width`, `height`, `entered`, `sourceHovered`, `hovered`, `keyboard`, `cursor`, `selectionVisible`, `focused`, `ids` (array of module names), `count`.
- **INTEG-57** `managedStatus()` — Returns a JSON array of on-demand widgets, each with: `id`, `key` (instance key), `zone`, `revealed` (activity visible), `mainVisible`, `inDrawer`, `panelOpen`, `observing` (activity target count).
- **INTEG-58** `popupStatus()` — Returns a JSON array of open widget panels, each with: `position` (bar position), `x`, `y`, `width`, `height`, `screenWidth`, `screenHeight`, `gap`, `barExtent`.

## Plugin API sync (PluginApiSync.qml)

- **INTEG-59** `PluginApiSync` distributes `layoutConfig` and click targets to each plugin's API instance on demand. It stores a map of plugin IDs to `clickTargets` arrays and updates each API's `clickTargets` property whenever targets change or are added.
- **INTEG-60** When a widget's `popout` property changes (which panel is open), `updatePopout(api)` is called for each plugin API. If Powerbar owns the popout, `api.activePopout` is set to the popout object; if a foreign popout is open, `api.foreignPopoutMarker` is set; otherwise it is null.
- **INTEG-61** When `layoutJSON` property changes, every plugin API's `layoutConfig` property is updated by parsing the new JSON.
- **INTEG-62** `addTarget(id, target)` appends a target (e.g. a click-accepting item) to the targets list for a plugin id if not already present, and updates the API immediately if it is registered.
- **INTEG-63** `removeTarget(id, target)` removes a target from the list for a plugin id and updates the API. If the list becomes empty, the entire entry is deleted.
- **INTEG-64** `forget(id)` deletes all targets for a plugin id (called when a plugin is unloaded).

## Multi-monitor support

- **INTEG-65** The bar creates one panel instance per screen in `Quickshell.screens` using `Variants { model: Quickshell.screens }`. Each screen gets its own bar and keyboard handler.
- **INTEG-66** `focusedScreenName()` returns the screen name of the Hyprland focused monitor, or an empty string if no monitor is focused.
- **INTEG-67** IPC calls to `preferences()`, `managed()`, `group()`, and `toggleGroup()` target the focused screen. If no focused screen is found, they fall back to the first screen.
- **INTEG-68** `captureWidgetImages(screen, done, keys, valid)` captures live widget images for the specified screen only. Jobs are keyed by screen name + instance key, and only widgets on that screen are included.
- **INTEG-69** When initializing or capturing images, if `Quickshell.screens.length > 0`, the bar uses the first screen for default operations.
- **INTEG-70** `sameWindow(left, right)` checks whether two items share the same screen (by comparing `screen.name` properties).

## Geometry observer (GeometryObserver.qml)

- **INTEG-71** `GeometryObserver` watches an item's geometry and that of all its ancestors (including transforms) for changes. It connects to 13 signals: `xChanged`, `yChanged`, `visibleChanged`, `widthChanged`, `heightChanged`, `scaleChanged`, `xScaleChanged`, `yScaleChanged`, `angleChanged`, `originChanged`, `rotationChanged`, `contentXChanged`, `contentYChanged`, and `parentChanged`.
- **INTEG-72** Geometry changes are collected into one deferred notification (via `Qt.callLater()`) per layout pass. When the `changed()` signal fires, both the target item and its ancestors' geometries are current.
- **INTEG-73** On destruction, all signal connections are disconnected and the chain is cleared.

## Capture queue (CaptureQueue.qml)

- **INTEG-74** `CaptureQueue` serializes GPU image readbacks with a bounded queue (`limit` property, default 2). It ensures at most 2 readbacks are in flight at once.
- **INTEG-75** `enqueue(jobs)` queues an array of capture jobs. Each job receives a unique `serial` number and is added to `pending`. The queue is pumped immediately.
- **INTEG-76** A job is `current` (active) if its serial matches the latest recorded serial for its key and its validity guard (if present) returns true.
- **INTEG-77** `start(job)` calls `job.prepare()` if defined; if it returns false, the job is abandoned. Otherwise, `job.item.grabToImage()` is called to capture the item. If grabbed, the result is passed to `job.accept()` only if the job is still current.
- **INTEG-78** When a readback completes (or fails), `finish(job, result)` is called. The in-flight count is decremented, and the queue is pumped via `Qt.callLater()`.
- **INTEG-79** Multiple `enqueue()` calls to the same job key replace the previous job without executing it (deduplication by key).

## Omarchy bar compatibility

- **INTEG-80** Powerbar honours the `omarchy.bar` stock bar's `syncHidden()` IPC endpoint to stay synchronized with the bar-off flag.
- **INTEG-81** Powerbar does NOT expose or respond to the stock bar's `move`, `put`, `set` IPC endpoints (for widget layout edits). Widget layout is managed entirely through Preferences and drag-and-drop, not through shell commands.
- **INTEG-82** The `omarchy bar` command (position, transparent, use, reset, defaults, put, move, set) is processed by the Omarchy shell and writes to `shell.json`. Powerbar reads these changes when the host re-injects `barConfig` after shell.json is reloaded.
- **INTEG-83** `omarchy bar position` updates the `bar.position` key in shell.json. Powerbar re-renders when barConfig is re-injected.
- **INTEG-84** `omarchy bar transparent` updates the `bar.transparent` key in shell.json.
- **INTEG-85** `omarchy bar use <id>` switches to a different bar plugin by updating shell.json. Powerbar is replaced by the other bar in this case (no cross-bar compatibility).
- **INTEG-86** `omarchy bar reset` restores the stock Omarchy bar.
- **INTEG-87** `omarchy bar defaults` restores the default layout and disables customizations.
- **INTEG-88** `omarchy bar put <id> [placement]` puts a widget on the bar. Powerbar reads the new layout from barConfig when injected; if it is invalid or refers to unregistered widgets, fallback zones are used.
- **INTEG-89** `omarchy bar move <id> [placement]` moves a widget. Powerbar does not directly process this command but reads the updated layout from barConfig.
- **INTEG-90** `omarchy bar set <id> <key> <value>` sets a per-widget option. Powerbar reads this via barConfig but does not offer a corresponding IPC endpoint; the user must use the Preferences UI or shell commands.

## Custom widget modules

- **INTEG-91** Custom widget modules are defined in shell.json under `bar.layout.<zone>` entries with arbitrary `id` values (not namespaced). Each entry must have a `type` field: `"command"` for shell-executed output or `"qml"` for a custom QML widget.
- **INTEG-92** Command modules have `type: "command"`, `exec: "/path/to/script"` (supports `~` for home), `interval: <seconds>` (refresh rate), `tooltip`, and `onClick` (shell command). They may output plain text or Waybar-style JSON (`{"text":"…","tooltip":"…","class":"…"}`).
- **INTEG-93** QML modules have `type: "qml"` and an optional `source` path (defaults to `~/.config/omarchy/bar/modules/<id>.qml`). They are loaded as `Item` components and receive `bar`, `moduleName`, and `settings` properties injected.
- **INTEG-94** Custom QML widgets must define `implicitWidth` and `implicitHeight`. The bar sets the height to `bar.barSize` (26 for horizontal, 38 with large bar) and lets width be determined by the widget.
- **INTEG-95** The `bar` property injected into custom widgets exposes: `foreground`, `background`, `urgent` (theme colors), `fontFamily`, `position`, `vertical`, `barSize`, `run(command)`, `shellQuote(value)`, `showTooltip(target, text)`, `hideTooltip(target)`, `requestPopout(owner)`, `releasePopout(owner)`.
- **INTEG-96** Custom widgets are loaded dynamically via the registry. If a widget is unregistered or its component is not available (after a bar switch), it shows as a placeholder until the registry is healed and the shell resumes.

## Icon generation and Omarchy integration

- **INTEG-97** `OmarchyIcons.js` is a generated file (by `tools/omarchy-icons.py`) containing two arrays: `logos` (Omarchy-specific icons from its font) and `glyphs` (Nerd Font icons used in Omarchy). Each glyph records its codepoint, Nerd Font name, and use count.
- **INTEG-98** The icon data is read-only and used by widgets to display themed icons. It is regenerated from the Omarchy installation and active fonts whenever the icon tool runs.

## PluginApiSync layout distribution

- **INTEG-99** When `layoutConfig` changes (via a config edit, bar reload, or layout reorder), `PluginApiSync` parses the JSON and distributes the new config to all registered plugin APIs via their `layoutConfig` property.
- **INTEG-100** Each plugin API receives a copy of the layout, allowing it to query and validate widget placement independently.

## Config write flow

- **INTEG-101** When the user edits config via Preferences or drags widgets, the bar collects edits into a queue (`queuedConfigEdits`). Edits are not immediately written; instead, a debounce timer waits for a quiet period.
- **INTEG-102** Once quiet, the bar calls `writeConfig(fn)`, which reads the current shell.json, applies the function `fn(config)` to edit the in-memory copy, and persists it. The host shell reloads the file and re-injects `barConfig`.
- **INTEG-103** Config edits show in the UI immediately (optimistically); they are reverted if the write fails.

## Startup sequence

- **INTEG-104** On plugin load: manifest is validated, Bar.qml is instantiated, properties are initialized to fallback values.
- **INTEG-105** The host shell injects `barConfig`, `barWidgetRegistry`, and `shell` properties.
- **INTEG-106** `Component.onCompleted` fires: `applyBarConfig()` is called (applies barConfig, checks for healing needs, schedules startup tasks), and the registry check timer is restarted.
- **INTEG-107** The bar creates one BarPanel per screen (via Variants + model: Quickshell.screens).
- **INTEG-108** Preferences and keyboard mode are initialized on demand.

---

## Doc drift

(No items found; README.md and observed behavior align on bar properties, limitations, and animation defaults.)

## Open questions

- INTEG-Q1: Does `barWidgetRegistry.revision` change whenever a plugin is dynamically reloaded, or only on shell startup? The code connects to `onRevisionChanged` but does not document when the shell increments it.
- INTEG-Q2: When `AppearanceModel.legacyPresent(barConfig)` or `GroupsModel.danglingMembers(barConfig)` return true, what exact edits are made by `healAppearance()` and `pruneGroupMembers()`? The code calls `writeConfig()` but the exact transformation is in AppearanceModel and GroupsModel (outside this area).
- INTEG-Q3: Does the bar survive a rapid bar-switch (switching plugins twice in succession)? The 60s guard prevents rescan storms, but concurrent registry changes are not fully characterized.
