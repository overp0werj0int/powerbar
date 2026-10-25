# Preferences behavior

Powerbar Preferences is one overlay window on the focused monitor with three pages, Layout, Groups and Bar, each a bento grid of tiles. Every control is reachable from the keyboard, the footer lists the keys that apply to whatever has focus, and every change shows on the bar as it is made. Everything in Preferences can also be done from the command line (integration.md, CLI section).

Sources: Preferences.qml, PreferencesModel.js, BentoModel.js, ShelfModel.js, SliderModel.js, IconSearch.js, PrefsBento.qml, PrefsForm.qml, PrefsTile.qml, PrefsSlider.qml, PrefsChoice.qml, PrefsToggle.qml, LayoutEditor.qml, GroupsPreferences.qml, IconPicker.qml, ShortcutRow.qml, tests/preferences.test.cjs, tests/bento.test.cjs, tests/shelf.test.cjs, tests/slider.test.cjs, tests/icon-search.test.cjs.

## Window and lifecycle

- **PREFS-1** Preferences open on the focused monitor when the nine-dot Preferences button at the end of the bar is clicked or chosen from the keyboard mode (it opens on that bar's screen, and ends the keyboard mode first), or by `omarchy-shell powerbar preferences`, `preferencesPage <n>` or `groupsPreferences`. While open, the button shows its selected highlight. Opening closes any open drawer and the tooltip, and the keyboard mode cannot be started (`keysOn` answers `error: not while Preferences are open`). There is one window; opening it on another monitor moves it there. Code: Preferences.show(), open()

- **PREFS-2** Preferences close on Esc (from any control that does not use Esc itself: an open dropdown, a lifted widget, the icon picker and a slider with an unapplied value take it first), the Close button (esc) at the top right, or `omarchy-shell powerbar closePreferences` (no effect when closed). The card is min(screen width - 48, 1180) wide and min(screen height - 64, 790) tall, in scaled px, and fades in over 140 ms (scale 0.98 to 1 over 180 ms; no motion with animations off).
- **PREFS-92** `,` closes Preferences too (when the focused control does not take it; no Ctrl, Alt or Super), and returns to the keyboard mode when Preferences were opened from it (keyboard.md KEYS-81). Code: Preferences.qml closeToKeys()

- **PREFS-3** Preferences read the live config: a change from the CLI, another Preferences control or a file edit shows in the controls as it arrives.

- **PREFS-102** Preferences fill the screen but the bar's edge: the window keeps a margin on the bar's side as deep as the bar's extent (or the notch's height plus the edge gap on a notched screen), so the bar stays in view and changes show on it. There is no card and no dimmed area: the page is the popups background, with the header (title, page tabs, Close) at the top and, on the Groups and Bar pages, the key footer at the bottom, both inset by the page's margin (66 px, less on a narrow screen: a 23rd of the width). The Layout page draws its keys as a legend (PREFS-103) and has no footer unless a save failed. The Groups and Bar pages keep their content at most 1180 px wide, centred. Code: Preferences.qml window.barInset, card.inset.
- **PREFS-103** The Layout page's keys are a legend at the page's bottom left, beside the inspector: one row per key, a column of keycaps and what they do, 10 px apart, in the small body size at 70 % (one step under the body size, beside keycaps in the caption size). It shows the keys for whatever has focus (the layers, a lifted chip, the inspector's focused control, or "tab The layers" when nothing has focus) and leaves out the pages' digits and esc Close, which the header shows. It sits 8 px above the page's bottom, at most 640 px wide and never under the inspector, in front of the layers; the layers only scroll under it when the inspector is out and the sheet has made room for it. Code: LayoutEditor legend, hints.
- **PREFS-104** The cursor's chip rises 8 px off its tile and grows to 103 %, in its tile's own opaque colour under its fill so nothing shows through it, drawn over its neighbours with a soft shadow 3 px further below it than it has risen (six faint rings, each a pixel wider and three taller, 8 % each on a dark theme and 4.5 % on a light one), and the tile it is on rises 5 px off its layer, its dark edge staying put so the slab reads thicker; both in 120 ms, at once with animations off. The chip pulled out to the inspector casts the same shadow at 9 % a ring. Every tilted rectangle (slabs, edges, chips, the beam) is drawn antialiased, and slab edges are 30 % on a light theme instead of 45 %. A chip pulled out to the inspector (its outline stays), a lifted chip and the tray's slab do not rise. The leader follows the rise. Code: LayoutEditor Tile.raise, Cell.raise.
- **PREFS-105** On a preview with a camera, a dashed leader runs from the top middle of the bar layer's Center tile to a dot beside the camera, white at 55% over the cap (an accent is lost on black on a light theme) and accent beyond its seen edge (PreferencesModel.leaderExit), 16 px out from the cap on the side Center sits on (ZONE-96), with "Center" written outside it. The dot is a Tab stop and a pointer target (28 px): h/l (Left/Right) put Center left or right of the camera, Space or Enter and a click swap sides, and a drag of more than 6 px carries the dot and lands on the side of the screen's middle it is released on. The change is saved at once (`powerbarCenterSide`, cleared for the default right) and the real bar moves its Center widgets to that side; the dot glides there in 160 ms. The legend shows "h l Center left or right of the camera", "space Swap sides", "tab The layers". Code: LayoutEditor centerSide, setCenterSide, sideDot.

- **PREFS-106** The layer stack has a fixed height: the page below the header's band (36 px) down to the legend's band, which is as tall as the legend's longest list (eight rows) plus 24 px above and 8 px below it, whatever the legend shows, so the legend and the inspector never move and the layers never resize as focus moves. Each layer asks for the height its fullest zone needs (its name, its rows of chips, a lifted chip's place included); while the sum and the gaps fit, every layer gets it. When they do not, each layer starts at its floor (its name and one row; the tray one row) and the rest is shared out: every layer takes what it asks for up to an equal share of what is left, so modest layers leave the rest to the others and layers that all want more get the same (three layers over the room get a third each). When not even the floors fit, the floors win and the legend gives way. A zone with more rows than its layer gives it scrolls inside its tile: the chips show in a window from under the zone's name to 2 px above the tile's bottom, cut at its edges, with the tile's colour fading over the cut chips at an edge there is more beyond (20 px at the top, 14 px at the bottom), and a hairline thumb (1.5 px, rounded) of the text colour (30 %, 50 % on the cursor's tile) in the tile's right pad, as long as the window's share of the rows, only while the zone overflows; no track, no arrows. All of it sits on the tile, so it tilts with the layer and rises with the tile. The wheel over the tile scrolls it a row a notch (or by the touchpad's pixels); the cursor's chip, and a lifted chip's landing place, scroll into view with 10 px to spare above for the raise; a pointer drag held within 24 px of the window's top or bottom edge scrolls it at about 190 px/s while there is more that way, the landing place following; a chip scrolled out of the window is not under the pointer. The inspector, when out, overlaps the lower layers as before (PREFS-101). Code: PreferencesModel.shareLayers(), tiltedPlaneHeight(); LayoutEditor plateDemands, plateFloors, legendBand, stackRoom, Cell.scroll, reveal, scrollBy, revealCursor, autoScroll.

- **PREFS-4** On opening, Preferences list the saved widget images in `$XDG_CACHE_HOME/powerbar/widgets` (default `~/.cache/powerbar/widgets`), read the widget glyphs the bar recorded (`glyphs.json` next to it), take fresh images of the widgets on the target screen and read Hyprland's `general:gaps_in` (tile gap, PREFS-13). Hidden or unseen widgets are drawn from the saved image, else their own glyph, else Powerbar's stock glyph for that widget.

- **PREFS-5** A write that cannot be queued or that the host refuses shows "Could not save. Check that shell.json is writable." in the footer (red, right side); the bar returns to the saved config. A layout move names the widget and the neighbour it goes before by instance key (`PreferencesModel.anchorKey`), so it still lands beside that neighbour after another change to the layout; one whose widget or neighbour is gone shows "The layout changed elsewhere. Try again." and one that cannot be queued "Could not save the layout. Check that shell.json is writable.". Shortcut failures: KEYS-53.

## Pages and tabs

- **PREFS-6** Three pages, in a tab row at the top with their number as a keycap: Layout (1), Groups (2), Bar (3).

- **PREFS-7** A page is chosen by clicking its tab, pressing 1, 2 or 3 (when no control uses the key), Ctrl+1, Ctrl+2, Ctrl+3 (also while typing in a field), Ctrl+Tab (next, wrapping) or Ctrl+Shift+Tab (previous). The active tab is bold with an accent underline.

- **PREFS-8** A page opening takes focus to its first control: Layout the layer the cursor is on, Groups the group shelf, Bar its first control.

## Bento tile layout

- **PREFS-10** Pages are tiles in a grid of 12 columns when the page is at least 1100 px wide (unscaled), 6 columns from 820 to 1099, 1 column below. Code: BentoModel.columnsFor()

- **PREFS-11** Each tile declares a span for 12 and for 6 columns (`span12`, `span6`); a span is rounded, at least 1 and at most the column count, and a missing one is the full width. At one column every tile is full width.

- **PREFS-12** Tiles fill rows in reading order; a tile that does not fit the rest of a row starts the next row; every tile in a row takes the row's tallest height.

- **PREFS-13** Tiles are one tile gap apart in both directions: twice Hyprland's `general:gaps_in`, read once per opening (`Style.space(8)` until it is known or when it cannot be read). An empty page has zero height.

- **PREFS-14** Resizing the page reflows the tiles to the columns of the new width.

- **PREFS-15** On the Layout, Groups and Bar pages Tab and Shift+Tab jump to the first control of the next or previous tile (wrapping, skipping tiles with nothing to focus); j/k (or Down/Up) walk every control in reading order. Code: BentoModel.nextTile()

- **PREFS-16** Tab, Shift+Tab, Backtab and Shift+Backtab all jump (Qt reports Shift+Tab as ambiguous on some layouts; the direction comes from the key itself).

## Tile structure

- **PREFS-17** A tile has a header with its title, an optional caption (a short muted line), an optional switch, an optional action button and an optional control slot (the Scope choice, the Groups filter), then its controls.

- **PREFS-18** Tiles have no Reset action: pressing `r` in a tile does nothing and no Reset button is shown. A Shape, Surface or Shadow tile goes back to the theme's values by choosing Theme in its header (your values are kept for later); a single slider goes back to its default with Backspace. Code: PrefsTile.qml

- **PREFS-19** The Groups settings tile has the action Dissolve (key x, or the button) asked twice: the first press changes it to "Again to dissolve" and the footer to "Again to dissolve", a second press within 3 s runs it, otherwise it lapses.

- **PREFS-20** A control that does not apply is dimmed to 45 % but stays where it is, (Border thickness while Borders is off, Softness and Strength while Shadow is off), with a one-line reason where there is one (PREFS-26), so the layout does not move as focus does.

## Layout page

- **PREFS-21** The Layout page draws the bar as layers, top to bottom: "On the bar" (caption "Always visible", or the zone-fit notes when a zone gave way), "On demand" (caption: "Behind the zone's dots; shown on activity, or when you hover the dots" in inline mode, "In a menu from the zone's dots; shown briefly on activity" in menu mode, "In the zone's drawer when you hover it, or briefly on activity" in drawer mode), "Hidden" ("Kept off the bar"), then the tray's (PREFS-97). Each layer is a plate (PREFS-99) whose first column names it: the title and, 8 px below in the body-small size, the caption; its last column, on the right, says how many it holds ("7 widgets", "1 widget" or "Empty") on the caption's line, in its size, at 40 %. They correspond to `powerbarVisibility` `shown`, `managed`, `hidden`; a widget with no saved value is On the bar. Groups appear on the layer their visibility names. Code: LayoutEditor shelfInfo, Plate.

- **PREFS-22** A plate spans the page (at most 1380 px), centred on the screen's middle, and has seven columns 8 px apart: the layer's name, the five zones in bar order (Left, Left of center, Center, Right of center, Right; on a side bar Top, Above center, Center, Below center, Bottom), and a spare column that mirrors the name's, so Center sits on the screen's middle. The columns share the width equally, except that on a preview of a screen with a camera Center is as wide as the camera (at most one and a half shares) so it sits under it. The zones are tiles: the zone's name, then the widgets as chips one under another in bar order, each one tile wide; an empty tile says "Empty". A tile is 33 px plus 27 per row (chips 24 px tall, 3 apart, 8 px padding, a 20 px name row), and every tile on a layer is as tall as the layer's tallest. A chip shows the widget's icon in a 20 px square (the middle of its ink, or a wide face's first glyph), its name elided to fit, and a group's member count in a pill; chips on the Hidden layer are drawn at half strength. The icon comes from, in order, the widget's live image, a saved image in the current text colour, a group's face, the glyph the widget draws itself, a saved image recoloured, Powerbar's stock glyph. Code: PreferencesModel.layerColumns(); LayoutEditor columns, Cell, Tile, InkIcon.

- **PREFS-23** A side bar is drawn the same way, its zones under their side names, and widgets are drawn horizontally. On a narrow page the columns narrow with it; a chip is never under 80 px.

- **PREFS-24** Center always sits under the screen's middle. On a preview of a screen with a camera at the top, the camera's beam runs from the real notch down through every layer, behind them: black fading out towards the bottom of the last layer, with the camera's eye (a ring round a dot, 16 px) 14 px under the page's top and "camera" 6 px below it, both white at half strength since the beam is black on every theme. It is drawn on the bar layer's own tilted plane, as wide as Center, so its edges run on the lines that layer's Center tile edges lie on and spread with them as they come near (a little narrower than the notch at the top, wider than Center at the last layer). It is darkest down its middle and thins to nothing at the cone's edges (a gradient, not a blur: a blur steps on a light theme), so it reads as light rather than a band; the fade down the page is a mask over it. At the top a crisp, fully black cap of the same width runs from the page's edge to the first layer's Center tile (2 px behind its top edge), so the camera itself looks like the notch does; the beam starts behind that tile. That tile's top corners are square (the others keep the theme's rounding), so the cap ends flush with it instead of showing black through the corners' rounding. With animations off both are straight bands. Center's tile is darker on every layer, the beam seen through it. Without a camera there is no beam and Center sits in its own place. A caption under the On the bar layer is not drawn any more; the inspector's Zone says "left of the camera" or "right of the camera" (PREFS-26). Code: PreferencesModel.tiltedDepth(), tiltedSpread(); LayoutEditor shaft, Cell.shaft.

- **PREFS-25** One layout serves every screen. When the screens differ (one has a camera, another not), a Preview dropdown at the page's top right (over the bar layer's spare column) chooses the screen, labelled with the screen's name and "(camera)" on a notched one; it changes the picture (the camera's shaft and Center's width, the Zone notes), never the layout. It starts on the screen Preferences opened on. Code: LayoutEditor previewName, previewScreen, screensDiffer.

- **PREFS-26** The inspector (PREFS-101) shows the selected widget as the bar draws it, its name and its plugin id (a group: "N widgets in this group"; a tray icon: "In Omarchy's tray" or "Moved out of Omarchy's tray"), then: Layer, a list of sheets (On the bar, On demand, Hidden, and In the tray for a tray icon) with the widget's own filled, one Tab stop where j/k (and the arrows) or a click move the widget at once, with the hint "j k move it down or up a layer"; Zone, a small map of the bar (PrefsZoneMap): five equal cells with the camera over Center when the preview has one, the chosen cell filled and marked with the widget's icon; h/l or the arrows walk it, Space or Enter chooses, a click chooses at once, and its caption names the zone under the cursor, with "left of the camera" or "right of the camera" for the center's zones on a notched preview ("on <screen>" when the screens differ); the widget's shortcut row; "Peeks on activity", enabled only with Autohide and its activity option on and a widget that is not clock-driven, with a hint only when the reason is not the toggle itself ("It changes on a clock, so it never brings the bar out", "Turned off for every widget on the Bar page"); and Group (a dropdown, "Not grouped" plus every group; choosing a group puts the widget in its drawer; a group shows its members' faces and an "Edit group" button instead). Code: PrefsZoneMap.qml; LayoutEditor Inspector, LayerPicker, zoneChoices, cameraNote.

- **PREFS-27** Keyboard: h/l (Left/Right) move the cursor to the next zone on the same layer, j/k (Down/Up) walk the zone's chips and empty tiles (valid resting places) and continue into the same zone on the next or previous layer; the tray's one slab meets the last zone. Space lifts the chip under the cursor; j/k then move it along the zone and across layers, h/l to another zone; its place shows its name, faded, in an accent outline. Space or Enter drops it, Esc (or losing focus) puts it back. Shift with h/l (typed as capitals) or with Left/Right moves the chip under the cursor to the next zone at once, as a lift, that step and a drop would; Shift with j/k or with Down/Up moves it to the same zone on the next layer down or up at once (On the bar, On demand, Hidden; a tray icon on to In the tray and back), keeping its place in the zone as the inspector's Layer does; at the first or last layer nothing happens. The cursor goes with the chip; on an empty tile Shift only moves the cursor. Enter pulls the chip forward to the inspector, and again pushes it back (PREFS-101); x sends it to the Hidden layer and back. Pointer: press a chip and move more than 6 px to lift it; a flat copy follows the pointer and the landing place opens as an outline before the first chip whose middle the pointer has not passed (in the tray's row: reading left to right, row by row); release drops it; a press elsewhere puts it back. A click (press and release without moving) pulls the chip forward. The legend (PREFS-103) names the keys: "Along the layer, across the camera" ("Along the layer" without one), "Down the zone, on to the next layer", "Pick up, then drop", "shift h l Move it to the next zone", "shift j k Move it to the next layer", "enter Pull it forward to inspect" ("enter esc Push it back" while a chip is out), "Send it to the hidden layer", "Next layer"; during a lift: "Along the zone, on to the next layer", "Zone", "Drop", "Put it back". Code: PreferencesModel.stepLayer(), stepLayerLift(), nextLayer(), layerPos(); LayoutEditor moveCursor, step, carryLayer, gapAt, keyPressed.

- **PREFS-28** A drop on another layer writes the destination layer's `powerbarVisibility` on that entry and puts it at the drop position in the destination zone. Code: PreferencesModel.move()

- **PREFS-29** A drop in the same layer and zone reorders the entry and keeps every other setting (format, size, instance key). The Zone and Visibility choices of the tile change one thing at a time: a visibility change keeps the zone and place; a zone change appends to the zone's end.

- **PREFS-30** Hiding keeps the widget's settings. Showing it again returns it to the layer it was hidden from, remembered for the session; with none remembered, On the bar.

- **PREFS-31** x or Delete on the cursor's item hides it, or, if hidden, shows it again (PREFS-30).

- **PREFS-32** g on a group icon opens the Groups page with that group selected; on a widget it does nothing.

- **PREFS-33** Enter on a chip pulls it forward and moves focus to the inspector's Layer list (PREFS-101); a click pulls it forward and leaves focus on the layers. Esc in the inspector pushes it back and returns to the layers.

- **PREFS-34** All fifteen destinations (zone x layer) are valid, and the entry keeps its settings and instance key through any number of moves. A stale move (the layout changed under it) or an unknown zone changes nothing (PREFS-5).

- **PREFS-93** There is no zone mode to choose: the zones are always five, wherever the bar sits (layout-zones.md ZONE-91). A notched screen's look is the Notch style (PREFS-65). Code: LayoutEditor columnsFor; PreferencesModel.sections.

- **PREFS-94** The Groups page's Zone is the same map as a widget's (PREFS-26). Code: GroupsPreferences Zone.

- **PREFS-97** Under the Hidden layer a fourth layer, "In the tray" (caption "Omarchy's tray icons"), one dashed slab across the five zones' columns, lists the icons Omarchy's tray draws now: every running app's icon except passive ones, those Omarchy's own widgets draw (LocalSend; Dropbox and Superwhisper while their widget is on the bar) and those already moved out (INTEG-153). Each shows the app's live tray icon and its tray name, as chips flowing five to a row. The slab joins the layers' lift and drag: an icon picked up there can land in any zone of the three layers above, and a tray icon on a layer above can be dropped back into it; the cursor, j/k and the arrows reach it like any layer. Empty: "Nothing in the tray. Apps put their icons here while they run; drag one onto a layer above to place it like a widget." Code: TrayItemsModel.trayRows; LayoutEditor Cell (the tray slab), trayEntries, drop(); PreferencesModel rows.

- **PREFS-98** The tile of a tray icon still in the tray (caption "In Omarchy's tray") offers Layer and Zone, with a fourth sheet, "In the tray", filled. Choosing a zone or another layer moves the icon out (On demand when only a zone was chosen); the hint says it then works as it does in the tray. A moved icon's tile (caption "Moved out of Omarchy's tray") has the usual controls, plus the "In the tray" sheet to put it back. Shortcut and group controls appear only once the icon is out. An app that quit between showing and choosing: "That app has left the tray." Code: Preferences.qml takeFromTray, returnToTray; LayoutEditor setPlacement and its settings tile.

- **PREFS-99** The layers are drawn as an exploded view of the bar: each plate is tilted back 34° about its top edge, seen from 1600 px (Qt's Rotation with `distanceToPlane`), so its top edge keeps its width, Center's axis stays put and lines converge towards the screen's middle. The plates stack down the page 30 px apart, starting 36 px below the header, each in a box as tall as its tilted picture; a layer's top edge, and everything seen near it, stays put while its height animates, so it only ever grows or shrinks downward; a tile has a 6 px dark edge below it, and the bar layer's tiles are a shade lighter. When a lift adds a row the layers below move down (140 ms). With animations off the layers lie flat. The zone being worked on (the cursor's, or where a lift would land) reads brighter on every layer, bold on its own. The sheet never scrolls: the layers share its room (PREFS-106). Code: PreferencesModel.tiltedHeight(), stackLayers(); LayoutEditor tilt, planeDistance, stack, Plate.

- **PREFS-100** Resting the pointer on a chip for 450 ms shows its full title, with its plugin id (or "Group"), in a small flat tip by the pointer; the next chip within 600 ms shows its tip at once. A lift or a press hides it. Code: LayoutEditor nameTip, tipDelay, tipCool.

- **PREFS-101** Enter, or a click on a chip, pulls it forward to the inspector: a panel 670 px wide at the page's bottom right, in front of the layers (its contents: PREFS-26). The chip's place in its layer becomes an empty accent outline, and a dashed accent leader runs from a dot at that place to a flat copy of the chip, tilted 1.5°, outlined in accent with a shadow, 30 px above the inspector (kept over the inspector's width). The inspector follows the cursor while it is out, so j/k browse widgets; on an empty tile it says what the tile is for ("Nothing on the bar in Left yet. Pick up a widget with Space, or drag one here."). A lift keeps it out and the leader follows the lifted chip's place; a pointer drag hides the leader and the copy until the drop. From the keyboard, focus goes to Layer and Tab walks the inspector's controls (the legend shows "tab shift+tab Next, previous control", the focused control's keys and "esc Back to the layers"); from a click, focus stays on the layers. Esc (from the layers or from any control of the inspector that does not take it first) or Enter pushes the chip back and returns focus to the layers. It opens and closes in 140 ms, from 97 % at its bottom edge. Code: LayoutEditor inspect(), pushBack(), inspecting, Inspector, leaderStart, pulledChip.

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

- **PREFS-62** A choice is a row of chips (one focus stop): h/l or Left/Right walk them, Space or Enter chooses. The Group dropdown on the Layout page (Omarchy's Dropdown) opens a list to choose from.

- **PREFS-63** Esc closes an open dropdown without changing the value; clicking elsewhere closes it too; scrolling the page closes it.

## Bar page

- **PREFS-64** The Bar page has eight tiles, in order: Style and position (8 of 12 columns), Size, Shape, Surface, Shadow, Behavior, On demand (4 each) and Keyboard (4; 6 of 6 at medium width). With a notched screen a Notch tile follows Shape (4; 3 of 6); while the Notch style draws it takes the place of Shape and Surface (PREFS-96). Every change shows on the bar at once.

- **PREFS-65** Style and position: a picture of the screen where clicking an edge moves the bar there; Style (Flat "Edge to edge, like Omarchy", Floating "One bar, off the edges", Islands "A surface for each zone", and, with a notched screen or while it is in use, Notch "Notch applies on the top edge of the notched screen; elsewhere it draws as islands"); Screen edge (Top, Bottom, Left, Right). Writes `bar.powerbarStyle` and `bar.position`. The default style is Flat, the default edge top. Code: Preferences.qml Style choice; layout-zones.md ZONE-41, ZONE-82.

- **PREFS-66** Size: Large bar (`powerbarLargeBar`, default off), Spacing (Equal slots, the default, or Equal gaps; `powerbarSpacingMode`) and "Space between widgets" (`powerbarSpacing`, 0 to 16 in steps of 1, default 4, "None" at 0). Layout meaning: layout-zones.md.

- **PREFS-67** Shape (under a Scope choice): "Corner rounding" (0 "Square" up to the largest the bar's thickness can show, "Pill"), Borders (toggle) and "Border thickness" (0.5 to 3, step 0.5; "Hairline" at the bottom; enabled with Borders). The default rounding is the theme's.

- **PREFS-68** Surface (under a Scope choice): "Background opacity" 0 to 100 % in steps of 5 (default 100; the label reads "Clear" at 0 and "Opaque" at 100), "Background blur" and "Text and icons" (Theme, Light, Dark; kept per theme in every scope). While Omarchy's transparent bar is on (`bar.transparent`, `omarchy bar transparent`) the slider shows 0, "Clear". Choosing any opacity here removes `bar.transparent` (the bar leaves transparency) and writes the opacity in the tile's scope. Code: Preferences.setLook()

- **PREFS-69** Shadow (under a Scope choice): Shadow (toggle), Softness (2 to 24, step 1, default 16) and Strength (5 to 60 %, step 5, default 30), both enabled only while Shadow is on.

- **PREFS-70** Behavior: Autohide (`powerbarAutoHide`, default off), Show on widget activity (`powerbarAutoHideActivity`, default on; peeks on an autohidden bar and on one switched off with Omarchy's bar toggle, so it is never dimmed), Readable over windows (`powerbarReadableOverlay`, default on; hidden while the Notch style draws, PREFS-96) and Animations (`powerbarAnimations`, default on). These are not scoped.

- **PREFS-71** On demand: "Show them" In a drawer (the default, hovering a zone opens its drawer), In the bar (behind dots, expanding in the bar) or In a menu (behind dots, which open a menu of them with groups as submenus; `powerbarOnDemand`), and "Count on the dots" (`powerbarDotsBadge`, default on). Timing: on-demand-drawers.md.

- **PREFS-72** Keyboard: the "Bar keyboard" (`bar:keys`) and "Bar search" (`bar:search`) shortcut rows (SUPER + B and SUPER + CTRL + SLASH are suggested until the user takes or changes them, KEYS-66; the first start's notification opens Preferences here, KEYS-84) and "Key legend" (`powerbarKeyLegend`, default on).

- **PREFS-95** Notch (on a machine with a notched screen): caption "Black, like the camera" while the Notch style draws there, "The camera's size" otherwise. Its "Notch width" slider runs from 40 to 600 px in steps of 1 (layout-zones.md ZONE-80, ZONE-89). The default is the camera housing, and choosing it removes `powerbarNotchWidth`. A "Notch height" slider follows, 16 to 96 px in steps of 1; its default is the detected height (Omarchy's calibration, else the described rows), and choosing it removes `powerbarNotchHeight`. While either is set, a Reset button in the tile's header (a Tab stop, Enter or Space presses it) removes both in one write and puts focus on the width slider. Code: Preferences.qml notchTile, clearOptions.

- **PREFS-96** While the Notch style draws (the bar at the top, a screen with a notch), controls that cannot apply give way (appearance.md LOOK-143); they return when the bar moves to another edge:
  - **Size:** "Large bar" is hidden: the notch's bar is always as tall as the camera.
  - **Shape:** the tile is hidden: the ears take the camera's corners and have no border.
  - **Surface:** the tile gives way to the Notch tile. Shadow stays.
  - **Behavior:** "Readable over windows" is hidden: the notch is always opaque, so there is no minimum to raise.
  - **On demand:** "Show them" offers only In the bar and In a menu (the notch has no drawers; a saved "drawer" shows as In the bar). "Count on the dots" stays.

  The values these controls hold are kept for the other styles and edges. Code: Preferences.qml notchMode.

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

