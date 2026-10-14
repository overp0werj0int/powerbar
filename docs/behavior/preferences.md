# Preferences behavior

Powerbar Preferences is one overlay window on the focused monitor with three pages, Layout, Groups and Bar, each a bento grid of tiles. Every control is reachable from the keyboard, the footer lists the keys that apply to whatever has focus, and every change shows on the bar as it is made. Everything in Preferences can also be done from the command line (integration.md, CLI section).

Sources: Preferences.qml, PreferencesModel.js, BentoModel.js, ShelfModel.js, SliderModel.js, IconSearch.js, PrefsBento.qml, PrefsForm.qml, PrefsTile.qml, PrefsSlider.qml, PrefsChoice.qml, PrefsToggle.qml, LayoutEditor.qml, GroupsPreferences.qml, IconPicker.qml, ShortcutRow.qml, tests/preferences.test.cjs, tests/bento.test.cjs, tests/shelf.test.cjs, tests/slider.test.cjs, tests/icon-search.test.cjs.

## Window and lifecycle

- **PREFS-1** Preferences open on the focused monitor when the nine-dot Preferences button at the end of the bar is clicked or chosen from the keyboard mode (it opens on that bar's screen, and ends the keyboard mode first), or by `omarchy-shell powerbar preferences`, `preferencesPage <n>` or `groupsPreferences`. While open, the button shows its selected highlight. Opening closes any open drawer and the tooltip, and the keyboard mode cannot be started (`keysOn` answers `error: not while Preferences are open`). There is one window; opening it on another monitor moves it there. Code: Preferences.show(), open()

- **PREFS-2** Preferences close on Esc (from any control that does not use Esc itself: an open dropdown, a lifted widget, the icon picker and a slider with an unapplied value take it first), a click on the dimmed area outside the card, the Close button (esc) at the top right, or `omarchy-shell powerbar closePreferences` (no effect when closed). The card is min(screen width - 48, 1180) wide and min(screen height - 64, 790) tall, in scaled px, and fades in over 140 ms (scale 0.98 to 1 over 180 ms; no motion with animations off).
- **PREFS-92** `,` closes Preferences too (when the focused control does not take it; no Ctrl, Alt or Super), and returns to the keyboard mode when Preferences were opened from it (keyboard.md KEYS-81). Code: Preferences.qml closeToKeys()

- **PREFS-3** Preferences read the live config: a change from the CLI, another Preferences control or a file edit shows in the controls as it arrives.

- **PREFS-4** On opening, Preferences list the saved widget images in `$XDG_CACHE_HOME/powerbar/widgets` (default `~/.cache/powerbar/widgets`), read the widget glyphs the bar recorded (`glyphs.json` next to it), take fresh images of the widgets on the target screen and read Hyprland's `general:gaps_in` (tile gap, PREFS-13). Hidden or unseen widgets are drawn from the saved image, else their own glyph, else Powerbar's stock glyph for that widget.

- **PREFS-5** A write that cannot be queued or that the host refuses shows "Could not save. Check that shell.json is writable." in the footer (red, right side); the bar returns to the saved config. A layout move names the widget and the neighbour it goes before by instance key (`PreferencesModel.anchorKey`), so it still lands beside that neighbour after another change to the layout; one whose widget or neighbour is gone shows "The layout changed elsewhere. Try again." and one that cannot be queued "Could not save the layout. Check that shell.json is writable.". Shortcut failures: KEYS-53.

## Pages and tabs

- **PREFS-6** Three pages, in a tab row at the top with their number as a keycap: Layout (1), Groups (2), Bar (3).

- **PREFS-7** A page is chosen by clicking its tab, pressing 1, 2 or 3 (when no control uses the key), Ctrl+1, Ctrl+2, Ctrl+3 (also while typing in a field), Ctrl+Tab (next, wrapping) or Ctrl+Shift+Tab (previous). The active tab is bold with an accent underline.

- **PREFS-8** A page opening takes focus to its first control: Layout the shelf the cursor is on, Groups the group shelf, Bar its first control.

## Bento tile layout

- **PREFS-10** Pages are tiles in a grid of 12 columns when the card is at least 1100 px wide (unscaled), 6 columns from 820 to 1099, 1 column below. Code: BentoModel.columnsFor()

- **PREFS-11** Each tile declares a span for 12 and for 6 columns (`span12`, `span6`); a span is rounded, at least 1 and at most the column count, and a missing one is the full width. At one column every tile is full width.

- **PREFS-12** Tiles fill rows in reading order; a tile that does not fit the rest of a row starts the next row; every tile in a row takes the row's tallest height.

- **PREFS-13** Tiles are one tile gap apart in both directions: twice Hyprland's `general:gaps_in`, read once per opening (`Style.space(8)` until it is known or when it cannot be read). An empty page has zero height.

- **PREFS-14** Resizing the card reflows the tiles to the columns of the new width.

- **PREFS-15** On the Layout, Groups and Bar pages Tab and Shift+Tab jump to the first control of the next or previous tile (wrapping, skipping tiles with nothing to focus); j/k (or Down/Up) walk every control in reading order. Code: BentoModel.nextTile()

- **PREFS-16** Tab, Shift+Tab, Backtab and Shift+Backtab all jump (Qt reports Shift+Tab as ambiguous on some layouts; the direction comes from the key itself).

## Tile structure

- **PREFS-17** A tile has a header with its title, an optional caption (a short muted line), an optional switch, an optional action button and an optional control slot (the Scope choice, the Groups filter), then its controls.

- **PREFS-18** Tiles have no Reset action: pressing `r` in a tile does nothing and no Reset button is shown. A Shape, Surface or Shadow tile goes back to the theme's values by choosing Theme in its header (your values are kept for later); a single slider goes back to its default with Backspace. Code: PrefsTile.qml

- **PREFS-19** The Groups settings tile has the action Dissolve (key x, or the button) asked twice: the first press changes it to "Again to dissolve" and the footer to "Again to dissolve", a second press within 3 s runs it, otherwise it lapses.

- **PREFS-20** A control that does not apply is dimmed to 45 % but stays where it is, (Border thickness while Borders is off, Softness and Strength while Shadow is off, Show on widget activity while Autohide is off), with a one-line reason where there is one (PREFS-26), so the layout does not move as focus does.

## Layout page

- **PREFS-21** The Layout page draws the bar as three shelves, top to bottom: "On the bar" (caption "Always visible", or the zone-fit notes when a zone gave way), "On demand" (caption: "Behind the zone's dots; shown on activity, or when you hover the dots" in inline mode, "In the zone's drawer when you hover it, or briefly on activity" in drawer mode), "Hidden" ("Kept off the bar"). They correspond to `powerbarVisibility` `shown`, `managed`, `hidden`; a widget with no saved value is On the bar. Groups appear in the shelf their visibility names.

- **PREFS-22** Each shelf has the three zones as columns (Left, Center, Right; on a side bar Top, Center, Bottom), lined up from shelf to shelf. The On the bar shelf is drawn as the bar draws it: the bar's cell geometry at its top-edge thickness, text colour, font, surface, rounding and border; a zone too long for its column wraps onto another island line instead of shrinking. A widget is drawn from, in order, its live image, a saved image in the current text colour, a group's face, the glyph the widget draws itself, a saved image recoloured, Powerbar's stock glyph. Code: ShelfModel.zone()

- **PREFS-23** A side bar is edited drawn horizontally, at the thickness of a top bar.

- **PREFS-24** Columns line up across shelves; the On demand shelf's centre column splits in two when a widget is pinned to the screen centre (PREFS-25).

- **PREFS-25** With a centre anchor (Pinned to screen center, `bar.centerAnchor`), the On demand shelf's centre column splits into "Left of <widget>" (`center:start`; "Above <widget>" on a side bar) and "Right of <widget>" (`center:end`), the widgets that wait behind the dots before and after the anchor. Code: PreferencesModel.columns()

- **PREFS-26** Under the shelves a tile titled with the selected widget (caption: its plugin id, or "N widgets in this group") holds: Zone (Left/Center/Right), Visibility (On the bar/On demand/Hidden), the widget's shortcut row, Show on activity, Keep at screen center, and Group (a dropdown, "Not grouped" plus every group; choosing a group puts the widget in its drawer; a group's own tile shows Members and an "Edit group" button instead). Show on activity is enabled only with Autohide and its activity option on and a widget that is not clock-driven (hints: "Applies while the bar autohides", "Turned off for every widget on the Bar page", "It changes on a clock, so it never brings the bar out"); Keep at screen center only for a widget on the bar in the centre.

- **PREFS-27** Keyboard move: h/j/k/l or the arrows move the cursor across items, empty cells (valid resting places) and shelves; Space lifts the item under the cursor; h/l then reorder it and step across zones, j/k change shelf; Space or Enter drops it, Esc (or losing focus) cancels. Pointer: press an item and move more than 6 px to lift it, release to drop; a press elsewhere cancels a lift. The empty tile says "Nothing on the bar in <zone> yet. Pick up a widget with Space, or drag one here."

- **PREFS-28** A drop on another shelf writes the destination shelf's `powerbarVisibility` on that entry and puts it at the drop position in the destination zone. Code: PreferencesModel.move()

- **PREFS-29** A drop in the same shelf and zone reorders the entry and keeps every other setting (format, size, instance key). The Zone and Visibility choices of the tile change one thing at a time: a visibility change keeps the zone and place; a zone change appends to the zone's end.

- **PREFS-30** Hiding keeps the widget's settings. Showing it again returns it to the shelf it was hidden from, remembered for the session; with none remembered, On the bar.

- **PREFS-31** x or Delete on the cursor's item hides it, or, if hidden, shows it again (PREFS-30).

- **PREFS-32** g on a group icon opens the Groups page with that group selected; on a widget it does nothing.

- **PREFS-33** Enter on an item (or double-click) moves focus to the first control of its settings tile; Esc there returns to the shelf.

- **PREFS-34** All nine destinations (zone x shelf) are valid, and the entry keeps its settings and instance key through any number of moves. A stale move (the layout changed under it) or an unknown zone changes nothing (PREFS-5).

- **PREFS-93** The header of the On the bar shelf has a Zones choice: "Three zones", "Two zones" and, when a screen has a notch (or the notch mode is already in use), "Notch". It is offered wherever the bar sits: the Notch mode moves the bar to the top. Choosing a mode writes `bar.powerbarZones` and swaps in that mode's own arrangement (layout-zones.md ZONE-72 to ZONE-74); the shelves redraw from it. Code: LayoutEditor ButtonGroup; Preferences.setZoneMode; Bar.qml screenNotch.

- **PREFS-94** In two zones and on the notch, each shelf has two columns, Left and Right (Top and Bottom on a side bar). Several controls follow:
  - The selected widget's Zone choice and the Groups page's Zone choice offer only those two.
  - "Keep at screen center" is gone.
  - On the notch the On the bar shelf's zones hug the middle, as each grows out of the camera.

  Code: LayoutEditor twoZones, notchMode, zoneColumns, lineX; GroupsPreferences Zone options.

## Groups page

- **PREFS-35** The Groups page has four tiles: "Groups" (every group drawn as the bar draws it, with name and count), the selected group's settings (title: its name; caption: "N widgets, on the bar at left"), "In the drawer" (its members as the drawer draws them, with "Widgets show" Icon/Name/Both, and Count/Urgent source fields for the selected member) and "Not in a group" (a filter and the widgets that are in no group). Groups, their faces and drawers: groups.md.

- **PREFS-36** The settings tile edits the selected group: Icon (the icon well, PREFS-44), Name, Show (Icon, Name or Both), Name on hover, Zone, Visibility (On the bar, On demand, Hidden, with a one-line meaning), Badge, Counts (Add up or Busy widgets; enabled with Badge) and its shortcut (disabled for a hidden group: "Hidden groups can't open"). Each applies at once.

- **PREFS-37** Clicking a group or h/l (Left/Right) selects the previous or next group (no wrap); j/Down goes to the next control; Enter goes to the icon well. A first group is selected when there is one.

- **PREFS-38** n on the shelf, or the new-group button, makes a group with id `g-<time in base 36>-<5 random chars>` and the name "New group", selects it and focuses its name field with the text selected.

- **PREFS-39** Dissolving (PREFS-19) removes the group and keeps its members on the bar; the selection moves to the neighbouring group.

- **PREFS-40** Editing the name commits when the field loses focus or Enter is pressed, if non-empty and different; Esc restores the old name and returns to the shelf.

- **PREFS-41** In "In the drawer": j/k (or the arrows) choose a member, Space lifts it, j/k move it, Space or Enter drops it, Esc cancels; x or Delete takes the member out of the group (it stays on the bar). Pointer: press and move more than a few pixels to lift; drop in the drawer to place, or on the "Not in a group" list to remove.

- **PREFS-42** The "Not in a group" list shows the widgets in no group; Enter, Space or a click adds the chosen one to the selected group; typing (anywhere in the list) goes to the filter, "Filter N widgets"; Esc clears the filter, then returns to the list.

- **PREFS-43** Dragging from the list into the drawer adds a widget at the drop place; dragging a member onto the list removes it.

## Icon picker

- **PREFS-44** Clicking the group's icon well, or Enter or Space on it, opens the picker over the page. Its tabs are All, On your bar, Omarchy, Emoji, Your own. The search field always keeps focus and reads "Search N icons, or paste one" (N is the real count, about 2,170).

- **PREFS-45** With no search and the All tab, icons are listed under headers (On your bar, Omarchy logos, Omarchy, Emoji; empty ones left out) in rows as wide as the picker allows. With a search, or on another tab, there are no headers.

- **PREFS-46** A query is split into words; every word must start a word of an icon's name (names split on spaces, hyphens and underscores) or, at three letters or more, sit inside one. Each icon from your bar also answers to "bar", Omarchy logos to "omarchy" and "logo".

- **PREFS-47** Results sort by score: exact word 4, prefix 3, inside a word 1, plus 0.5 when it is the icon's first word, minus 0.05 per word of the name (up to 12); ties by source (your bar, Omarchy, emoji), then list order. A query matching nothing says "No icons match “…”. Try a simpler word, or paste a glyph or emoji."

- **PREFS-48** Arrows move the cursor through the icons, skipping headers; Up and Down keep the column or land on the last icon of a shorter row; PageUp and PageDown move a screenful; at the ends the cursor stays.

- **PREFS-49** Enter chooses the cursor's icon (writing `icon` and `iconFont` to the group) and closes the picker; Tab and Shift+Tab cycle the tabs (wrapping); Esc clears the search text first, then closes the picker.
- **PREFS-91** The icon picker closes when Preferences closes or leaves the Groups page, so it never comes back open with its keys in the footer. Code: GroupsPreferences.qml Connections on preferences

- **PREFS-50** A search that is a single pasted glyph or emoji (an emoji sequence with ZWJ joiners, a skin tone, a keycap or a flag counts as one) offers it first as "Pasted, drawn in the bar's font". Other text is searched normally.

- **PREFS-51** On "Your own": drop an SVG or PNG on the page, or Ctrl+V an image or a copied file (or type its absolute path and press Enter). Up to 512 KB; Powerbar copies it to `$XDG_DATA_HOME/powerbar/icons/<12 hex>.<svg|png>` (default `~/.local/share/powerbar/icons`). Left/Right choose "Text colour" or "Its own colours"; Enter writes `iconImage` and `iconTint` (`text` or `own`). Errors: "Only SVG or PNG files. <file> is neither.", "<file> is over 512 KB. Icons are drawn 16 px tall; a smaller file is plenty.", "Could not read <file>.", "Could not copy <file> to <dir>.", "The pasted image is over 512 KB.", "Could not read the pasted image."

- **PREFS-52** The index is built each time the picker opens from: the glyphs your widgets draw (private-use characters only), Omarchy's logos and the Nerd Font glyphs Omarchy uses, and Omarchy's emoji list (`$OMARCHY_PATH/shell/plugins/emojis/emojis.json`, else under `/usr/share/omarchy`). Code: IconSearch.index()

- **PREFS-53** The same glyph in the same font from two sources is listed once, under the first source, with the words of both: an Omarchy logo a widget on your bar draws is found by "omarchy logo" and by the widget's name.

- **PREFS-54** The picker holds about 2,170 icons; none is cut off, an empty query shows all of them.

## Sliders, toggles, and choices

- **PREFS-55** A slider shows its label, the value (with its unit, or a word at special values: "None", "Square", "Pill", "Hairline", "Clear", "Opaque"), a track with a knob, and tick marks only when there are 11 or fewer steps.

- **PREFS-56** Pressing the track jumps the knob there and keeps dragging; pressing the knob drags it. The value snaps to the nearest step counted from the minimum (min 0.5, step 0.5: 1.26 gives 1.5, 1.24 gives 1).

- **PREFS-57** Keys: h/l or Left/Right one step (Shift: five), PageUp/PageDown five, Home/End the ends, Backspace or Delete the default, Enter applies now, Esc drops a value not yet applied. The wheel changes a focused slider only (otherwise the page scrolls).

- **PREFS-58** An edit applies to the bar once it settles: after the pointer is released (120 ms), or for keys and wheel after 450 ms of quiet; steps less than 1.2 s apart stretch the wait to 1.6 x the gap, at most 1000 ms. Leaving the slider, its page or the window applies what is pending. Code: SliderModel.settleDelay()

- **PREFS-59** The wheel counts 120 angle-delta units per step, carries the remainder between events, and keeps its direction; its steps use the keyboard's settle delay.

- **PREFS-60** Ticks: a slider shows one per step when (max - min) / step + 1 is at most 11, otherwise none.

- **PREFS-61** A toggle flips on Space, Enter or a click and applies at once.

- **PREFS-62** A choice is a row of chips (one focus stop): h/l or Left/Right walk them, Space or Enter chooses. The two dropdowns (Pinned to screen center, and Group on the Layout page; Omarchy's Dropdown) open a list to choose from.

- **PREFS-63** Esc closes an open dropdown without changing the value; clicking elsewhere closes it too; scrolling the page closes it.

## Bar page

- **PREFS-64** The Bar page has eight tiles, in order: Style and position (8 of 12 columns), Size, Shape, Surface, Shadow, Behavior, On demand (4 each) and Keyboard (4; 6 of 6 at medium width). In two zones a Notch tile follows Shape (4; 3 of 6); on the notch it takes the place of Shape and Surface (PREFS-96). Every change shows on the bar at once.

- **PREFS-65** Style and position: a picture of the screen where clicking an edge moves the bar there; Style (Flat "Edge to edge, like Omarchy", Floating "One bar, off the edges", Islands "A surface for each zone"); Screen edge (Top, Bottom, Left, Right); Pinned to screen center (None or a centre widget that is On the bar). Writes `bar.powerbarStyle`, `bar.position`, `bar.centerAnchor`. The default style is Flat, the default edge top.

- **PREFS-66** Size: Large bar (`powerbarLargeBar`, default off), Spacing (Equal slots, the default, or Equal gaps; `powerbarSpacingMode`) and "Space between widgets" (`powerbarSpacing`, 0 to 16 in steps of 1, default 4, "None" at 0). Layout meaning: layout-zones.md.

- **PREFS-67** Shape (under a Scope choice): "Corner rounding" (0 "Square" up to the largest the bar's thickness can show, "Pill"), Borders (toggle) and "Border thickness" (0.5 to 3, step 0.5; "Hairline" at the bottom; enabled with Borders). The default rounding is the theme's.

- **PREFS-68** Surface (under a Scope choice): "Background opacity" 0 to 100 % in steps of 5 (default 100; the label reads "Clear" at 0 and "Opaque" at 100), "Background blur" and "Text and icons" (Theme, Light, Dark; kept per theme in every scope). While Omarchy's transparent bar is on (`bar.transparent`, `omarchy bar transparent`) the slider shows 0, "Clear". Choosing any opacity here removes `bar.transparent` (the bar leaves transparency) and writes the opacity in the tile's scope. Code: Preferences.setLook()

- **PREFS-69** Shadow (under a Scope choice): Shadow (toggle), Softness (2 to 24, step 1, default 16) and Strength (5 to 60 %, step 5, default 30), both enabled only while Shadow is on.

- **PREFS-70** Behavior: Autohide (`powerbarAutoHide`, default off), Show on widget activity (`powerbarAutoHideActivity`, default on; dimmed while Autohide is off), Readable over windows (`powerbarReadableOverlay`, default on; hidden on the notch, PREFS-96) and Animations (`powerbarAnimations`, default on). These are not scoped.

- **PREFS-71** On demand: "Show them" In a drawer (the default, hovering a zone opens its drawer) or In the bar (behind dots, expanding in the bar; `powerbarOnDemand`), and "Count on the dots" (`powerbarDotsBadge`, default on). Timing: on-demand-drawers.md.

- **PREFS-72** Keyboard: the "Bar keyboard" (`bar:keys`) and "Bar search" (`bar:search`) shortcut rows (bound on the first start where free, KEYS-84; otherwise SUPER + B and SUPER + CTRL + SLASH are only suggested, KEYS-66) and "Key legend" (`powerbarKeyLegend`, default on).

- **PREFS-95** Notch (two zones and the notch): caption "The gap in the middle" in two zones, "Black, like the camera" on the notch. Its "Notch width" slider runs from 40 to 600 px in steps of 1 (layout-zones.md ZONE-77, ZONE-80). The default is the camera housing, or 185 without a notch, and choosing it removes `powerbarNotchWidth`. In two zones, "Pinned to screen center" is gone from Style and position.

- **PREFS-96** On the notch, controls that cannot apply give way in place to what does (appearance.md LOOK-143):
  - **Style and position:** the screen picture is disabled. Style and Screen edge give way to "On the notch" and the line "Black zones grow out of the camera at the top of the screen. Choose Three or Two zones on the Layout page for the other styles."
  - **Size:** "Large bar" is hidden: the notch's bar is always as tall as the camera.
  - **Shape:** the tile is hidden: the zones take the camera's corners and have no border.
  - **Surface:** the tile gives way to the Notch tile. Shadow stays.
  - **Behavior:** "Readable over windows" is hidden: the notch is always opaque, so there is no minimum to raise.
  - **On demand:** "Show them" gives way to the line "Behind dots in their zone; they expand in the bar when you hover the dots. The notch has no drawers." "Count on the dots" stays.

  The values these controls hold are kept for the other modes.

## Appearance scopes

- **PREFS-73** Shape, Surface and Shadow each have a Scope choice, Theme, Everywhere or Just here, with a hint line under it: Theme "Using <theme>'s look." (with "Powerbar look" when the theme ships its own `powerbar.toml` values), Everywhere "Yours, in every theme that has no own choice." (or "Yours everywhere; <theme> has its own look."), Just here "Yours, only while <theme> is on." With Theme chosen the controls are read-only (dimmed) and show the theme's values. Rules and storage: appearance.md (LOOK-27 to LOOK-36).

## Keyboard shortcuts

- **PREFS-76** A shortcut row appears in the Layout tile (widget or group), the Groups settings tile (its group) and Bar → Keyboard (`bar:keys`, `bar:search`). Its behavior, recording and the file it writes: keyboard.md KEYS-53 to KEYS-62, KEYS-66, KEYS-67. A row is unavailable, with its reason as the tag, for a hidden widget or group ("Hidden widgets can't open", "Hidden groups can't open") and for a widget with nothing to open ("Nothing to open").

## Configuration persistence and healing

- **PREFS-79** Every Preferences change is applied at once to the bar's own copy of its config, and written to shell.json once drag, glide and slider settle have finished (Bar.writeConfig). A control writes the value it shows; only an undefined value deletes its key (`Preferences.setOption`).

- **PREFS-80** When the host refuses a write the bar returns to the saved config and the footer shows the message of PREFS-5.

- **PREFS-81** The layout is `bar.layout.<left|center|right>`: entries with `id`, `powerbarVisibility` (`shown`, `managed`, `hidden`; absent = shown), `powerbarInstance` (unique key) and the widget's own settings. Defaults for absent keys: BarModel.options() (autoHide false, autoHideActivity true, largeBar false, spacingMode slots, onDemand drawer, animations true, keyLegend true, dotsBadge true) and AppearanceModel.ranges. Configs Powerbar ran on before the "On the bar" default keep what they show: integration.md.

- **PREFS-82** The style is `bar.powerbarStyle` (`flat`, `floating`, `islands`); an old `powerbarIslands: true` reads as islands and is replaced on the next write.

- **PREFS-83** A group's member can name the widget property its badge counts and its urgent state (`powerbarBadgeProperty`, `powerbarUrgentProperty`); the "In the drawer" tile edits them for the selected member (placeholders "Count: detected" and "Urgent: detected").

- **PREFS-84** The widget registry rescan after a bar switch is integration.md's.

## IPC functions for preferences

- **PREFS-85** `omarchy-shell powerbar preferences` opens Preferences on the focused monitor (the first screen if none matches); if open, it reopens them there, on the current page.

- **PREFS-86** `closePreferences` closes them; nothing happens when they are closed.

- **PREFS-87** `preferencesPage <n>` opens Preferences if closed and shows page n (1 Layout, 2 Groups, 3 Bar); a number above 3 shows the Bar page (the old General and Appearance pages are the Bar page now) and below 1 leaves the page as it is.

- **PREFS-88** `groupsPreferences` opens Preferences (if closed) and shows the Groups page, also when already open.

## Multi-monitor behavior

- **PREFS-89** There is one Preferences window. `preferences` and the Preferences button of a bar open it on the monitor they belong to; opening it elsewhere moves it.

- **PREFS-90** Changing the focused monitor does not move an open window; the next `preferences` opens it on the newly focused monitor.

## Doc drift

None found against the rewritten README.md.

## Open questions

