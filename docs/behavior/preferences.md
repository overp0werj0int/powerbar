# Preferences behavior

Powerbar Preferences is a modal window providing access to every bar setting: widget layout (zone and visibility mode), group management (icon, name, members, badge), and bar appearance (style, position, size, shape, surface, shadow, behavior, keyboard). Preferences open centered on the focused monitor and remain above windows while open. Every control is reachable from the keyboard; changes persist immediately to `~/.config/omarchy/shell.json` and apply to the bar without restart. The window resizes and reflows its content responsively in 12, 6 or 1 columns.

Sources: PreferencesModel.js, BentoModel.js, ShelfModel.js, SliderModel.js, IconSearch.js, Preferences.qml, PrefsBento.qml, PrefsTile.qml, LayoutEditor.qml, GroupsPreferences.qml, IconPicker.qml, tests/preferences.test.cjs, tests/bento.test.cjs, tests/shelf.test.cjs, tests/slider.test.cjs, tests/icon-search.test.cjs, Bar.qml, README.md.

## Window and lifecycle

- **PREFS-1** Preferences open centered on the focused monitor when: clicked on the nine-dot button at the far right of a horizontal bar (or at the bottom of a vertical bar); sent `omarchy-shell powerbar preferences`; opened programmatically by another panel. While open, the bar's preferences button is disabled.

- **PREFS-2** Preferences close when: clicked the Esc key; clicked outside the window; sent `omarchy-shell powerbar closePreferences`; the user closes the window via window manager controls. The bar is refreshed and keyboard focus returns to its previous location.

- **PREFS-3** Preferences persist in memory a snapshot of the config when they open, allowing edits to proceed independently of concurrent bar reloads. If the config changes while Preferences are open, the next Preferences open starts with the new config.

- **PREFS-4** When opened, Preferences read widget glyphs (at ~/.cache/powerbar/glyphs.json) and widget images (at ~/.cache/powerbar/widgets/) once, then refresh the bar's widget registry once to detect new or updated plugins.

- **PREFS-5** A status message line at the bottom of Preferences displays "Could not save. Check that shell.json is writable." when a write to shell.json fails; otherwise the line is empty.

## Pages and tabs

- **PREFS-6** Preferences have three pages: Layout (page 1), Groups (page 2), Bar (page 3), labeled with icons and visible in a tab row at the top.

- **PREFS-7** The current page is switched by: clicking the page tab; pressing 1, 2 or 3; pressing Ctrl+1, Ctrl+2 or Ctrl+3; pressing Ctrl+Tab to cycle forward. The active tab is highlighted.

- **PREFS-8** When a page opens, focus is placed on its first control (the first focusable item in reading order). Esc closes Preferences from any page.

- **PREFS-9** When Preferences switch to the Bar > On demand page, the setting for inline expansion of managed widgets is displayed only when the bar's style supports it (all three styles do).

## Bento tile layout

- **PREFS-10** Every page is composed of tiles (rectangular content blocks) laid out in a bento grid that adapts to window width: 12 columns for width >= 1100px, 6 columns for width 820–1099px, 1 column for width < 820px.

- **PREFS-11** Each tile declares its span at 12 and 6 columns (span12 and span6). A tile's span12 and span6 are clamped to the grid's columns; an invalid span defaults to the full width.

- **PREFS-12** Tiles fill rows in reading order; a tile that does not fit the remaining space in a row starts the next row. Every tile in a row takes that row's tallest height, so all tiles in a row align their baseline.

- **PREFS-13** Rows are spaced vertically by 8 pixels (Hyprland's inner gap, `Style.space(8)`). The page's total height is the sum of row heights plus gaps; an empty page has zero height.

- **PREFS-14** When the window is resized, tiles are reflowed according to the new width (changing to 12, 6 or 1 columns). Tiles that span a wider width at 6 columns than at 12 columns maintain consistency (e.g., a tile declaring span12: 6, span6: 6 always spans 6).

- **PREFS-15** Tab navigation jumps between tiles: Tab moves to the first focusable control of the next visible tile forward, Shift+Tab to the previous tile. All controls within a tile are visited before Tab leaves it. An empty tile (no focusable controls) is skipped.

- **PREFS-16** When Tab or Shift+Tab is pressed by itself or with Shift (ambiguous shortcuts can be caught on some keyboards), the jump is triggered in both cases.

## Tile structure and reset

- **PREFS-17** Each tile has a header containing: a title (the tile's subject), an optional toggle switch (e.g., Shadow on/off), an optional action button (e.g., Dissolve), an optional caption (short muted text such as "Using theme's Powerbar look"), and an optional control slot (e.g., a filter or choice selector).

- **PREFS-18** When a tile's content differs from its default (resolved from the theme), a Reset button appears in the header. Pressing r while focus is inside the tile, or clicking Reset, enters confirmation mode; pressing r or Reset again (or clicking) within 3 seconds resets all settings in the tile to their defaults.

- **PREFS-19** A tile with an action (e.g., Dissolve on Groups) shows an action button in the header. Pressing the designated key (e.g., x) once enters confirmation mode; pressing it again within 3 seconds executes the action. The footer shows the key and its confirmation state.

- **PREFS-20** When a tile is not applicable (e.g., Show on activity for a widget that does not support activity reveals), the tile's controls are dimmed and a reason message appears below them, but the tile remains present and responsive (to avoid layout thrashing when focus moves).

## Layout page

- **PREFS-21** The Layout page shows the bar as it currently exists, with three shelves representing visibility modes: "On the bar" (Always shown / powerbarVisibility: shown), "On demand" (Managed / powerbarVisibility: managed), "Hidden" (Always hidden / powerbarVisibility: hidden).

- **PREFS-22** Each shelf is a row of up to three columns (Left, Center, Right zones), drawn at the bar's edge position and thickness, so they read as the bar does. Widgets in each shelf are drawn as they appear on the bar: icons at their bar size, rendered live (for grouped and drawer widgets) or from cached snapshots. Hidden widgets show their last known appearance; if no cached image exists, the widget's own glyph is drawn instead.

- **PREFS-23** When a vertical bar is edited in Preferences, it is still drawn horizontally at its horizontal thickness, showing widgets as they would appear on a horizontal bar; on a vertical bar, widgets display their horizontal representation saved by the bar.

- **PREFS-24** Each shelf's columns line up across shelves so that the Left zones stack, Center zones stack, and Right zones stack.

- **PREFS-25** With a center anchor (a widget pinned to the screen center), the Managed shelf's center column splits into two: "Left of [widget]" (center:start) and "Right of [widget]" (center:end), keeping widgets before the anchor on the left and after it on the right.

- **PREFS-26** A widget tile under the shelves displays settings for the selected widget: Zone (Left, Center, Right), Visibility (Always shown, On demand, Always hidden), Show on activity (checkbox), Keep at screen center (checkbox), and Group (choice dropdown). Only settings applicable to the widget are shown (others remain present, dimmed, with a reason).

- **PREFS-27** Moving a widget is done by: selecting it (clicking or using j/k to walk), lifting it with Space, moving the cursor with h/j/k/l across zones and shelves, and dropping with Space or Enter (unverified: stale drag rejection)

- **PREFS-28** When moving a widget from On demand to Always shown or vice versa (changing visibility), a drop on the target shelf changes its visibility. When moving a widget within its zone but changing shelves, only visibility is changed (the zone stays the same).

- **PREFS-29** Reordering a widget within its zone (same shelf, same zone) does not affect its visibility and retains all other settings (format, size, etc.).

- **PREFS-30** Hiding a widget removes it from the bar without deleting its settings. Showing it again (removing Always hidden) returns it to the visibility mode it had before being hidden (Always shown or On demand, remembered per widget).

- **PREFS-31** Pressing x while a widget is selected hides or (if already hidden) shows it again (toggles visibility between current and always-hidden, or returns from hidden to its remembered mode).

- **PREFS-32** Pressing g while a widget is selected opens the Groups page with focus on the Group control of the selected widget's settings tile.

- **PREFS-33** Pressing Enter while a widget is selected moves focus to its settings tile below the shelves so the user can adjust its zone, visibility, or group without dragging.

- **PREFS-34** All nine layout destinations (Left/Center/Right × Shown/Managed/Hidden) are valid drop targets; the widget retains its settings (format, instance key, plugin state) through every move.

## Groups page

- **PREFS-35** The Groups page displays a shelf of all groups (drawn as the bar draws them: icon, name if shown, badge if shown), a settings area for the selected group (icon, name, zone, visibility, badge), and a drawer representation showing the group's members and available non-member widgets.

- **PREFS-36** A group is represented by: a unique stable ID; an icon (a Nerd Font glyph, Omarchy logo, emoji, or custom SVG/PNG image); a display name; a zone (Left, Center, Right); a visibility mode (Always shown, On demand, Always hidden); a badge (text, count, dot, or hidden); an ordered list of member widget instances.

- **PREFS-37** Hovering the group shelf or clicking a group selects it. When selected, its settings and members display. Pressing h/l or arrow keys moves selection among groups; pressing Enter focuses on the icon control.

- **PREFS-38** Creating a new group: press n while focus is on the group shelf, or click the + button in the Groups shelf header. A new group with ID "g-[timestamp]-[random]" and label "New group" is created, selected, and its name field is focused for editing.

- **PREFS-39** Dissolving a group: press x once (or click Dissolve) to enter confirmation mode; press x again (or click Dissolve again) within 3 seconds to delete the group. Dissolving a group removes the group but keeps its member widgets on the bar at their original zones and visibility modes.

- **PREFS-40** Editing group properties: the settings tile shows Icon, Name, Zone, Visibility, and Badge, each editable and applying immediately. Changing the zone or visibility mode changes where the group's icon and member drawer appear without changing the members' own zones.

- **PREFS-41** A group's members are widgets added to it. The drawer shows members in the group's order (reorderable with Space+j/k and dropped with Space or Enter). Members are removed from the group with x (without deleting the widget itself).

- **PREFS-42** The Available widgets list shows non-member widgets (those not in any group). Pressing Enter or clicking on a widget in the list adds it to the selected group. The list can be filtered by typing; the filter is cleared when the page loses focus or Preferences close.

- **PREFS-43** Dragging is supported throughout Groups: members can be dragged to reorder within the drawer, widgets can be dragged from the Available list into the drawer to add them to the group, or dragged out of the drawer to remove them.

## Icon picker

- **PREFS-44** The icon picker is a popover that opens when clicking the icon control on the Groups settings tile. It searches and displays icons from up to five sources: On your bar (glyphs your widgets draw), Omarchy logos, Omarchy (Nerd Font glyphs used by Omarchy), Emoji, and Your own (custom SVG or PNG).

- **PREFS-45** When browsing (no active search), the picker displays section headers (one per non-empty source), with icons arranged in rows of N columns (columns determined by the picker's width and cell size). When searching, no headers are shown; all matching icons appear in one stream.

- **PREFS-46** Focus stays in the search field at all times. Typing searches by any term matching an icon's name or tags. Every query word must start a word of an icon's name or be found inside one (three letters or more, ranked lower); exact word matches rank higher than prefixes.

- **PREFS-47** Search results are sorted by: exact word match > prefix match > internal match (3+ chars), then by source order (On your bar > Omarchy logos > Omarchy > Emoji), then by icon list order. Shorter icon names rank higher than longer ones for ties. Icons with tags matching the query rank via their tags.

- **PREFS-48** Arrow keys (↑ ↓ ← →) move the cursor up, down, left, or right through the grid, skipping header rows. Vertical movement tries to keep the column; if the next row is shorter, it lands on the last icon of that row. Wrapping at edges is not supported; pressing down at the bottom stays at the same icon.

- **PREFS-49** Pressing Enter chooses the icon at the cursor and closes the picker. Tab switches to the next source (cycling All > On your bar > Omarchy > Emoji > Your own > All). Escape clears an active search (if any text is entered) or closes the picker if the search is empty.

- **PREFS-50** The icon picker accepts pasted glyphs and emoji: if the clipboard contains a single glyph or emoji sequence (including emoji with ZWJ joiners and skin tone modifiers), it is offered immediately as the chosen icon without searching. Plain text pastes are rejected.

- **PREFS-51** The "Your own" source allows uploading custom SVG or PNG images: dragging an image into the source or pasting an image (Ctrl+V) uploads it as the group's icon. The image path is stored in the group's config (shell.json) as `iconImage`. An error message appears if the upload fails (e.g., invalid format, write permission denied).

- **PREFS-52** Icon sources are indexed once per picker open, reading from: widget glyphs reported by the bar (bar.widgetGlyphs), Omarchy's logos (via OmarchyIcons.js), Nerd Font glyphs (via OmarchyIcons.js), and Omarchy's emoji list (from the JSON file at `$OMARCHY_PATH/shell/plugins/emojis/emojis.json` or `/usr/share/omarchy/shell/plugins/emojis/emojis.json` by default).

- **PREFS-53** The same glyph in the same font from two sources keeps the first and merges their tags/names: an Omarchy logo that a widget on the bar also draws is found by both "omarchy logo" and the widget's name.

- **PREFS-54** The picker displays about 2,170 icons in total: ~10 from your bar, ~200 Omarchy logos and Nerd Font named glyphs combined, ~1,950+ emoji. No limit is enforced; every icon for an empty query is displayed (sectioned into rows of N columns).

## Sliders, toggles, and choices

- **PREFS-55** Sliders are used for numeric adjustments (e.g., bar width, widget spacing). A slider displays the current value as a number, a track with a thumb, and optionally tick marks (shown only when the step count is <= 11).

- **PREFS-56** Clicking on the track moves the thumb to that position; dragging the thumb adjusts the value. The value snaps to the nearest step, rounded from the minimum: if min=0.5, max=3, step=0.5, entering 1.26 snaps to 1.5 and 1.24 snaps to 1.

- **PREFS-57** Keyboard adjustment: h/l or arrow keys increment/decrement by one step. Shift+h/l increment/decrement by 10 steps. Home goes to the minimum, End to the maximum, and Backspace resets to the default. Enter applies the value immediately; Esc undoes a change not yet applied.

- **PREFS-58** Slider edits settle before applying to the bar: a single edit (first keystroke or wheel notch after a 1.2-second pause) waits 450 ms before applying. A series of edits spaced less than 1.2 seconds apart extends the delay to 1.6 × the gap between edits (to at most 1000 ms), so tapping at a steady pace applies once after the last tap.

- **PREFS-59** Wheel (or touchpad) input accumulates fractions: every 120 angle-delta units = 1 notch. Fractions carry over between wheel events; the direction is preserved (negative deltas step down). Notches apply using the same settle delay as keyboard edits.

- **PREFS-60** Sliders show tick marks (notches) only when (max - min) / step + 1 <= 11 (11 ticks or fewer). Sliders with 12+ steps have no visible ticks.

- **PREFS-61** Toggles are boolean switches (on/off) shown as checkboxes or toggle buttons. Pressing Space or Enter flips the state; j/k walk the form, not the toggle. Changes apply immediately.

- **PREFS-62** Choices are dropdown selectors (e.g., Zone: Left/Center/Right, Visibility: Always shown/On demand/Always hidden, On demand display: In drawer/In bar, Bar style: Flat/Floating/Islands). Pressing Space or Enter opens a popup menu; arrow keys walk the options; Enter or Space chooses one.

- **PREFS-63** When a choice is open, Escape closes it without changing the selection; clicking elsewhere also closes it.

## Bar appearance and behavior

- **PREFS-64** The Bar page contains tiles for: Style and position, Size, Shape, Surface, Shadow, Behavior, On demand, and Keyboard. Each tile groups related settings.

- **PREFS-65** Style and position: a tile showing a small graphic of the screen with the bar positioned on one edge (top, right, bottom, left), allowing the user to click an edge to move the bar there, and a choice of bar style: Flat (edge-to-edge, square), Floating (held off edges, rounded, bordered), or Islands (zones wrapped individually). Every change applies to the bar immediately.

- **PREFS-66** Size: sliders for bar thickness (in pixels, typically 38) and widget spacing (gap between widgets, in pixels). Thinner bars shrink all dimensions proportionally.

- **PREFS-67** Shape: sliders for corner rounding and a toggle for borders. Changes apply live.

- **PREFS-68** Surface: sliders for opacity (0–100%), blur (in pixels), and toggles for how the text and icons blend with the background (theme colors are used). A Scope choice (Theme, Everywhere, or Just here) selects which theme(s) the settings apply to (see Appearance scopes, below).

- **PREFS-69** Shadow: toggles for drop shadow and a slider for shadow size (if enabled). A Scope choice applies to theme(s).

- **PREFS-70** Behavior: toggles for autohide (bar slides out past the edge), show bar on widget activity (when autohidden, activity reveals the bar briefly), and animations. A Scope choice applies to theme(s).

- **PREFS-71** On demand: a choice for how managed widgets are accessed: In drawer (the default, opens beside the zone) or In bar (widgets wait behind zone dots and expand inline if they fit, else open the drawer). On demand widgets auto-hide after 2.5 seconds of inactivity, matching the peek time of an autohidden bar.

- **PREFS-72** Keyboard: toggles and choices for keyboard behavior and shortcuts. Shortcuts are stored as they are recorded (Hyprland binds) each time Preferences open.

## Appearance scopes

- **PREFS-73** Many settings (Surface, Shadow, Behavior, toggles on tiles like Shadow) can be scoped to control which theme(s) they apply to. The scope is one of: Theme (this setting applies only to the current theme, and other themes use their own values or defaults), Everywhere (the setting is used by every theme that has no own setting for that key), or Just here (synonym for "Just this theme").

- **PREFS-74** A Scope choice appears below each tile's title as a row of three buttons. When Theme is selected, text under the button says "Using [theme]'s Powerbar look" or "Using [theme]'s look" (depending on whether a value is set locally). When Everywhere is selected, text says "Yours everywhere; [theme] has its own look" or "Yours, in every theme that has no own choice." When Just here is selected, text says "Yours, only while [theme] is on."

- **PREFS-75** Appearance scopes are controlled by shell.json keys: `powerbarAppearance.[theme].[tile]` (theme-scoped), `powerbarAppearanceEverywhere.[tile]` (everywhere-scoped). When a user chooses Everywhere, the setting is written to the Everywhere key and the theme-specific key (if it exists) is cleared.

## Keyboard shortcuts recording

- **PREFS-76** Keyboard shortcuts for widgets and groups are recorded when Preferences open. The Keyboard tile lists: toggle keyboard mode (default Super+B), open Preferences, and (if custom shortcuts exist) widget and group shortcuts.

- **PREFS-77** Each shortcut shows the widget or group name, the current binding (if any), and a button to record a new binding. Clicking the record button enters recording mode; the next key combination is captured and set as the new binding (replacing any existing one).

- **PREFS-78** Recording reads from Hyprland's active binds and writes to ~/.config/omarchy/hyprland.conf in a marked block (lines with `# o.bind` markers). The user's Hyprland config must source that file for the binds to take effect.

## Configuration persistence and healing

- **PREFS-79** All Preferences changes write to ~/.config/omarchy/shell.json via the bar's writeConfig function. Changes apply immediately to the bar without requiring a shell restart or config reload.

- **PREFS-80** When a write fails, the status line displays "Could not save. Check that shell.json is writable." Changes are not applied to the bar (they are held in the draft state for the user to retry).

- **PREFS-81** The config schema: the bar layout is stored in `shell.json` → `bar` → `layout` → (zones: left, center, right) → [entries]. Each entry is an object with: `id` (widget ID), `powerbarVisibility` (shown, managed, or hidden), `powerbarInstance` (unique key for duplicate widgets), and any widget-specific settings (e.g., `format` for clock).

- **PREFS-82** The bar style is stored in `shell.json` → `bar` → `powerbarStyle` (flat, floating, or islands); legacy `powerbarIslands: true` is read as islands and replaced on the next write.

- **PREFS-83** Each widget can declare a `powerbarBadgeProperty` and `powerbarUrgentProperty` to expose its badge/urgent state to the bar.

- **PREFS-84** When the bar first loads, it scans its plugin registry. If plugins have changed (new, removed, or updated), Powerbar asks the shell to rescan them once (via `omarchy-shell shell rescanPlugins`), at most once a minute.

## IPC functions for preferences

- **PREFS-85** `omarchy-shell powerbar preferences` opens Preferences on the focused monitor. If already open, it brings the window to focus.

- **PREFS-86** `omarchy-shell powerbar closePreferences` closes Preferences, if open. No effect if Preferences are not open.

- **PREFS-87** `omarchy-shell powerbar preferencesPage <n>` opens Preferences (if not open) and switches to page n (1 for Layout, 2 for Groups, 3 for Bar). Page numbers beyond the valid range are clamped to the last valid page.

- **PREFS-88** `omarchy-shell powerbar groupsPreferences` opens Preferences with the Groups page active (equivalent to `preferencesPage 2`).

## Multi-monitor behavior

- **PREFS-89** Each monitor can have one Preferences window open independently. Opening Preferences on a different monitor opens a new window on that monitor at the same position (center), without affecting any window open on other monitors.

- **PREFS-90** When the focused monitor changes (pointer or window focus move), Preferences remain on their current monitor. Sending `omarchy-shell powerbar preferences` targets the new focused monitor and opens or brings Preferences on that monitor to focus.

## Doc drift

- **DRIFT-1** README.md states "Show on activity, whether it is kept at the exact screen center" under Layout settings, but code in Preferences.qml shows these as separate controls (Show on activity checkbox, Keep at screen center checkbox) that apply independently to each widget.


## Open questions

- **QUESTION-1** The exact threshold for when an inline expansion falls back to the managed drawer is defined in the BarModel or ManagedModel (zone fit calculation), not PreferencesModel. The Preferences UI does not expose this control; it only offers the choice between "In drawer" and "In bar."

- **QUESTION-2** The exact list of widget-specific settings that persist through moves (e.g., `format` for clock) is not enumerated; the code states "retains its settings" but does not specify which properties are safe to retain and which are not.
