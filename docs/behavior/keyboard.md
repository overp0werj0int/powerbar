# Keyboard: cursor navigation, fuzzy search, key strip, and shortcuts

The bar works from the keyboard with a cursor on stops (widgets, group icons, zone dots, the Preferences button). `omarchy-shell powerbar keys` toggles it. On Powerbar's first start SUPER + B is bound to it when nothing else holds those keys (KEYS-84); otherwise Preferences → Bar → Keyboard offers SUPER + B (faded, tagged "Suggested") and binds nothing until the user accepts (KEYS-66). Keys are named by direction relative to the bar: along-the-bar keys move the cursor, the into-key (↓ on a top bar) goes into groups and drawers. Search (`/`) finds widgets by name. A name card names the cursor, a key strip lists the keys, `?` lists every shortcut. Esc steps back one level; Esc twice within 400 ms leaves from any depth.

**Sources:**
- BarKeysModel.js: keymap per edge, intents, step, zoneStep, fuzzy search, route, legend
- BarKeys.qml: mode state, stops, drawers, search, name card, hand-off, the cursor following the pointer
- Bar.qml: IPC `keys`/`keysStatus`, key catcher, focus grab (`keysGrab`), key strip window (`keysStrip`), focus priming
- BarCli.qml: `keysOn`, `keysOff`, `keysSearch`
- ShortcutModel.js, ShortcutStore.qml, ShortcutRow.qml: shortcut parsing, recording, writing `bindings.lua`
- tests/bar-keys.test.cjs, tests/shortcuts.test.cjs

The CLI as a whole (`status`, `shortcuts`, `help`, error format) is integration.md's; only what it does to the keyboard mode is here.

## Keyboard mode: entry and exit

- **KEYS-1** `omarchy-shell powerbar keys` while the mode is off enters it on the focused monitor's bar (another monitor's bar only while no monitor is focused; a focused monitor without a bar gets none, and `keysOn` then answers `error: no bar to put the cursor on`). Nothing happens while Preferences is open. On entry the cursor lands on, in order: the stop whose panel is open, the centre anchor (the clock), the middle stop of the list, or nowhere if there are no stops. The shortcut store is re-read and the name card shows at once. Stops are, in bar order: widgets and group icons that are on the bar and not in a drawer, folded or yielded, zone dots that are shown, and the Preferences button. Code: BarKeys.enter(), stops(), seen()

- **KEYS-2** The mode ends on: `keys` again; `keysOff`; Esc at bar level (Esc at an inner level steps back first, KEYS-38); two Esc within 400 ms; a click anywhere outside the bar and its open drawer while the bar holds the keys, on any monitor, as a click outside dismisses Omarchy's keyboard panels (a Hyprland focus grab on the bar window: the compositor drops it on a click elsewhere, and the click is not passed on; the drawer is part of the bar window, so the whole drawer takes the pointer whatever its size; the grab starts once the bar has the keyboard, since one started before is dropped at once); a window or a layer that is not Powerbar's or one of Omarchy's own bar surfaces opening (checked 150 ms after the event, and only if no registered panel is open); Enter on the Preferences button (the mode ends first, then Preferences opens). Leaving closes an open panel the cursor opened, closes any drawer, folds an inline expansion, hides the card and drops a pending search reveal.

- **KEYS-3** Enter or Space on a widget opens it like a click and the bar lets go of the keyboard for 400 ms (`handOff`). If the widget opened a registered panel (Omarchy's KeyboardPanel, PopupCard) the mode is suspended (KEYS-4); if a window or layer of its own opened, the mode ends (KEYS-2); if nothing opened (a toggle), the bar takes the keys back after the 400 ms and shows the card again. The card is hidden while the hand-off lasts, and the bar gives up keyboard focus and its focus grab, so the keys reach what the press opened.

- **KEYS-4** Suspended (a registered panel the cursor opened is open): keys go to the panel; a panel drawn as a popup of the bar that did not take the keys ignores every key but Esc, which closes it. When it closes the mode resumes: card shown, keys back on the cursor or the drawer it came from, and an Esc within 400 ms of the close counts as the second of a double Esc (KEYS-39).

- **KEYS-5** The bar reads keys only while `here`: active, not suspended, not in a hand-off. In every other state the mode is on but keys are not interpreted by it.

## Cursor movement

- **KEYS-6** Along keys move the cursor one stop; at either end it stays (no wrap). Horizontal bar: Left/h = previous, Right/l = next. Vertical bar: Up/k = previous, Down/j = next. Keys the bar does not use are swallowed (they do not reach the window). Code: BarKeysModel.keymap(), step()

- **KEYS-7** Tab goes to the first stop of the next zone that has stops; Shift+Tab (Backtab) to the last stop of the previous one; both wrap round left, centre, right. With stops in one zone only, they land on that zone's first or last stop.

- **KEYS-8** Home moves to the first stop, End to the last, whatever the zone.
- **KEYS-82** As in vim, `^` does what Home does and `$` what End does; Page Down does what Tab does and Page Up what Shift+Tab does (KEYS-7), on the bar and in a drawer. In a drawer Home and `^` move to its first member, End and `$` to its last (the strip scrolls them into view). In a search they are typed, as other characters are. Code: BarKeysModel.barIntent, drawerIntent; BarKeys keyName (PageUp, PageDown), drawerKey (first, last)

- **KEYS-9** If the cursor's stop disappears (hidden, folded, yielded, its drawer or dots changed), the next movement starts from the first stop of the cursor's zone. The cursor is not moved by the disappearance itself.

## Into key: entering groups and drawers

- **KEYS-10** On a group icon, the into-key (top bar: Down or j; bottom: Up or k; right bar: Left or h; left bar: Right or l) opens the group's drawer entered at its first member. The bar's key catcher keeps the window focus; the drawer takes the keys.

- **KEYS-11** In drawer mode (`powerbarOnDemand` = `drawer`) the into-key on any widget of a zone that has on-demand widgets opens that zone's drawer entered at its first row; on the zone's dots it does the same. The bar cursor stays where it was.

- **KEYS-12** In inline mode (`inline`), landing the cursor on a zone's dots expands the zone in place at once: no hover intent and, unlike the pointer, no settle wait after another zone collapses (DEMAND-38), so the zone left folds while this one grows. The cursor lands as the zone opens, before its widgets have grown, on the first widget in the direction it was moving (in the zone's drawn order); its ring shows at the widget's full cell from the first frame and rides with it as it grows. A widget whose cell still has no width (its zone's positioner places it only once it grows) is not lit until it has a place, never for a frame at the zone's start; its card waits likewise (appearance.md LOOK-138). If the zone cannot fit, its drawer opens entered instead. The into-key on dots in inline mode does nothing. Code: BarKeys openDots, checkPending, landable; Bar.qml inlineEnter (keyboard), inlineSlots; ModuleSlot barHighlight (width > 0).

- **KEYS-13** In a drawer the out-key (top: Up/k; bottom: Down/j; right: Right/l; left: Left/h) or Esc leaves it and returns to the bar with the cursor where it was (on the group icon or the widget or dots it came from); in a menu on a top or bottom bar the out-key first walks back up the rows and leaves only from the first row. When the cursor there previews that same drawer (KEYS-20: its group's icon, a widget or the dots of its zone), the drawer folds back to that preview where it is, without closing and opening again, and the card moves from the row to the cursor as the same popup (LOOK-136); otherwise it closes. Code: BarKeysModel.drawerIntent(); BarKeys backToBar()

## Drawer navigation

- **KEYS-14** A strip (a zone's drawer, or a group showing icons only) runs along the bar on every edge: the along keys (Left/h, Right/l on a top or bottom bar; Up/k, Down/j on a side bar) walk its members, the out-key leaves it from any member, and the into-key does nothing. A menu (a group showing names) runs down the screen: on a top or bottom bar its rows run away from the bar, so the into-key moves to the next row and the out-key to the previous one (leaving from row 0); on a side bar the along keys walk the rows, the out-key leaves and the into-key does nothing. Moving past the last or first member does nothing. Before, a strip under a top or bottom bar was walked with the into and out keys, as a menu. Code: BarKeysModel.drawerIntent (strip)

- **KEYS-15** In a menu on a top or bottom bar, the along keys (Left/h, Right/l) close the drawer and move the bar cursor one stop in that direction. In a strip they walk it (KEYS-14); on a side bar they are not used in a menu.

- **KEYS-16** Tab and Shift+Tab in a drawer close it and jump to the next or previous zone as in KEYS-7.

- **KEYS-17** Enter or Space in a drawer opens the current row's widget, with the same hand-off as KEYS-3.

- **KEYS-18** Esc in a drawer closes it (cursor back on the bar, KEYS-13); a second Esc within 400 ms ends the mode.

- **KEYS-19** When the opened member shows a registered panel the drawer steps aside and the mode is suspended; Esc in the panel closes it and the keys return to the drawer with the card on the current row.

- **KEYS-20** Preview: after a non-repeating key is released with the cursor on a group icon, or in drawer mode on a widget or the dots of a zone with On demand widgets (as the pointer resting there opens that zone's drawer, on-demand-drawers.md DEMAND-17), and no drawer open, a 100 ms timer opens the drawer unfolded but not entered; any key pressed first cancels it, so a held key sweeping across stops never flashes drawers. A zone's preview stays open while the cursor moves among that zone's widgets and dots; moving to another zone, or to a group icon, closes it, and the next stop's preview follows the next key release. A release in a drawer the keys just left (an along key out of a menu, Tab) counts too. On a group icon or dots the name card is hidden during a preview; on a widget it stays, past the drawer (appearance.md LOOK-84). The pointer moves the cursor as anywhere (KEYS-45). Code: BarKeys previewZone(), previews(), released(), put(); ManagedDrawer Keys.onReleased

## Search: fuzzy name matching and navigation

- **KEYS-21** `/` starts a search with an empty query (from a drawer it closes the drawer first). The key strip shows a "Find" box with a caret and, under an empty query, "Type part of a name"; the shortcut sheet closes. The strip shows for a search even when `powerbarKeyLegend` is false.

- **KEYS-22** Each typed character (h, j, k, l included) appends to the query, Space appends a space, Backspace removes one; each edit resets the match to the first and brings it into view. The strip reads "N of M", "1 match", or "No widget named that" (urgent colour) when nothing matches.

- **KEYS-23** Tab in search goes to the next match, Shift+Tab to the previous (wrapping), acting at once.

- **KEYS-24** Enter in search ends the search and opens the match: a member through its group's drawer, a widget behind dots or in a drawer once it has come into view, or the cursor's stop. Code: BarKeys.openMatch()

- **KEYS-25** Ranking (fzy): each space-separated word must match on its own letters, in order, with gaps allowed, using letters no earlier word used. The first word (when it has two or more letters) may match anywhere in the text; a single-letter first word, and every later word, must start at a word start or a capital. Consecutive letters score highest (1), then a word start (0.9 at the text start, 0.8 after a separator, 0.7 at a capital), gaps cost 0.01 inside and 0.005 outside. Best total score first; ties in bar order. An empty query matches nothing. Code: BarKeysModel.matches(), fuzzy()

- **KEYS-26** A match comes into view the way the pointer would bring it: on the bar → the cursor lands on it; in inline mode behind its zone's dots or folded → the dots open in place (another zone's expansion closes, without the settle wait) and the cursor waits on the dots, then lands on the widget as soon as the zone has opened, grown or not; in drawer mode in its zone's drawer → the drawer opens entered at it; a member lands in its group's drawer at its row; otherwise (yielded to another zone's expansion) that expansion closes first. Landing is checked every 25 ms up to 60 times (1.5 s); an expansion that cannot fit falls back to the zone's drawer. Code: BarKeysModel.route(), BarKeys.bringIn()

- **KEYS-27** Typing waits: a match already on the bar is taken at once, but a match that needs the bar to change (dots, drawer, closing another zone) is queued for 150 ms of no typing. Tab and Enter never wait.

- **KEYS-28** An arrow, Home or End in search ends it (query cleared) and does its usual job; on a top bar Down after a group match goes into that group.

- **KEYS-29** Esc in search ends it and clears the query; the cursor stays where the last match put it. A second Esc within 400 ms ends the mode.

- **KEYS-30** A member's search text is "<group name> <member name>"; "ai a" finds the AI group's members whose names start with a, and not the AI group itself (its text has no second a to use).

## Search catalogue

- **KEYS-31** The catalogue is every widget and group icon the bar holds a slot for (on the bar, behind dots, in a drawer, folded, yielded) plus the Preferences button ("Powerbar preferences"); members are found through their group name too. Hidden widgets have no slot and are not found. Zone dots are not searchable.

## Key strip and shortcut sheet

- **KEYS-32** While the mode is active and not suspended, a strip at the screen edge opposite the bar (24 px in) lists the keys for the current level, unless `powerbarKeyLegend` is false (default true; Preferences → Bar → Keyboard → Key legend). The strip is hidden while the bar is sliding. Bar level: the along arrows and the into arrow together "Move", in one keycap (←→↓ on a top bar; arrows in a keycap always run ← ↑ → ↓), Tab Shift+Tab "Zones", Enter "Open", / "Find", ? "Shortcuts", , "Preferences", Esc "Leave". Code: BarKeysModel.legend()

- **KEYS-33** Drawer level: Move, Enter "Open", Back, , "Preferences", Esc Esc "Leave". Move shows the along arrows for a strip, and for a menu on a side bar; for a menu on a top or bottom bar, the into and out arrows (↑↓ on top), one keycap. Back shows the out arrow and Esc, except for a menu on a top or bottom bar (Esc alone).

- **KEYS-34** Search level: Tab "Next match", Enter "Open", Esc "Stop finding", Esc Esc "Leave".

- **KEYS-35** The arrows are named by the edge: top bar into = ↓, out = ↑; bottom into = ↑; right bar into = ←, out = →; left bar into = →. hjkl never appear on the strip.


- **KEYS-37** The double Esc is listed on the drawer and search strips only, as "Esc Esc" "Leave"; the bar-level strip lists a single Esc "Leave".

- **KEYS-70** `?` shows the shortcut sheet in the strip, in two columns side by side with a thin rule between, the strip as wide as they need. Left, "Keyboard mode": every key of the mode for this edge, keycaps then what they do: first one "Movement" row: every arrow (along, into, out) in one keycap, then their vim letters in another (←↑→↓ and hjkl, on every edge), then Home ^ "First stop", End $ "Last stop", Tab PgDn "Next zone", Shift+Tab PgUp "Previous zone", Enter Space "Open", / "Find", , "Preferences" (KEYS-81), ? "This sheet", Esc "Back, or leave", Esc Esc "Leave from anywhere". Right, "Widgets and groups": every catalogue entry that has a shortcut, its name and its keys drawn as keycaps joined by "+"; with none, it reads "No widget on this bar has a shortcut yet. Set them in Preferences → Layout." The key legend row is hidden while the sheet shows. It shows even when the key legend is off. `?` or Esc closes it; any other key closes it and then does its usual job. Code: BarKeysModel.sheetKeys(); Bar.qml keysStrip

## Double Escape (quick exit)

- **KEYS-38** Every Esc is timed: an Esc less than 400 ms after the previous Esc leaves the mode, whatever the depth (closing any open panel, drawer and search). A lone Esc closes the innermost level: search first, then the open sheet, then the drawer, then the mode.

- **KEYS-39** A registered panel's own Esc counts as the first: when it closes, an Esc within 400 ms leaves the mode too.

## Name card

- **KEYS-40** When the mode is `here` and the cursor is on a widget, the card beside it shows the widget's name, one line, no shortcut (shortcuts are on the `?` sheet, KEYS-70, and in Preferences). The Preferences button's card is "Powerbar preferences".

- **KEYS-41** In an entered drawer the card is about the current row instead of the cursor: in an icon strip it names the row's widget; in a named menu (where the row already shows the name) it shows what hovering the row shows, the widget's own tooltip such as "Microphone muted", falling back to the name when the widget has none. Code: BarKeysModel.js cardText().

- **KEYS-79** A card follows its widget while the widget moves (a zone growing or shrinking under the cursor), re-placed each frame of the motion. Code: Bar.qml tooltip GeometryObserver, reanchorTooltip.
- **KEYS-77** A card on a drawer's row sits beside that row once the drawer has finished opening, outside the drawer, also when a search (`/`) opened the drawer and put the cursor on a row in the same moment; it is placed again when the drawer's size or position changes. Before, a search into a left-zone group left the card at the first row's height, over the menu. Code: Bar.qml reanchorTooltip (drawer reveal end, geometry).

- **KEYS-42** The card refreshes when the cursor moves, when the drawer's row changes and when the drawer is no longer stepped aside.

- **KEYS-43** The card is hidden on group icons and on zone dots in drawer mode (they open a drawer), while suspended or handing off, and when the mode ends. A preview hides it only where the cursor is on one of those (KEYS-20).

- **KEYS-44** The card shows only for a target that belongs to the keyboard's window (`keysStatus.card.belongs`); on other monitors' bars it is hidden.

## The cursor follows the pointer

- **KEYS-45** While the mode is `here`, the cursor follows the pointer: moving it onto a stop on the bar puts the cursor there, and the keys carry on from that stop. Only a real move counts: the pointer's position when the mode began, a re-report of the same point when the bar changes under a resting pointer, and the first report after the pointer comes into the bar or a drawer before it has settled (the bar slid in less than 300 ms ago; a drawer still unfolding or opened less than 250 ms ago) are ignored (under 1 px). The pointer leaving the bar leaves the cursor where it was. Code: BarKeys pointerMoved.

- **KEYS-46** On the bar the pointer's own rules run as without the mode: a drawer the keys held is let go to them the moment the pointer moves on the bar (its icon under the pointer keeps it open; elsewhere it closes as when the pointer leaves it, with the 100 ms step-away wait of DEMAND-89 and the exit delay), group icons open their drawers after the hover intent, and dots open their zone after the settle wait. Dots that open under the cursor land it on the widget beside them (dots at the start of their run: its first; at its end: its last). Code: BarKeys letDrawerGo, onInlineZoneChanged.

- **KEYS-47** Moving the pointer onto a drawer's row puts the cursor into that drawer at that row, as the into-key and arrows would, whoever opened the drawer: the keys hold it from then on (it stays open when the pointer leaves it off the bar) and the card names the row (KEYS-41). Back on the bar the drawer is the pointer's again (KEYS-46). Code: BarKeys pointerOnRow; ManagedDrawer memberHover.

- **KEYS-80** While the mode holds a bar, the card names the cursor there and the pointer's own tooltips on that bar neither show nor take the card down; on other monitors' bars, and while the mode is suspended or handing off, tooltips are as usual. Before, hovering a widget without a tooltip of its own cleared the card as the cursor reached it. Code: Bar.qml keysCardHolds (showTooltip, hideTooltip).

## IPC and configuration

- **KEYS-48** `omarchy-shell powerbar keys` toggles the mode on the focused monitor's bar (nothing while Preferences is open). `keysOn` starts it and answers `ok`, or `error: not while Preferences are open`, or `error: no bar to put the cursor on`; `keysOff` ends it and answers `ok` whether or not it was on. `status` reports it as `runtime.keys`. Other CLI behavior: integration.md. Code: BarCli.keysOn(), keysOff()

- **KEYS-83** `omarchy-shell powerbar keysSearch` opens the mode's search (KEYS-21) on the focused monitor's bar in one step, for jumping to a widget by name from a shortcut. Off: the mode starts (KEYS-1) and the search opens. On, on that bar, at bar level or in a drawer: the drawer closes and the search opens. On another monitor's bar, or with a panel or hand-off holding the keys: the mode ends there (KEYS-48 leave) and starts again on the focused bar with the search open. While a search is open it ends the mode, so one shortcut opens and closes it. Answers `ok`, or `error: not while Preferences are open`, or `error: no bar to put the cursor on`. Code: BarKeys.search(), BarCli.keysSearch()

- **KEYS-49** `omarchy-shell powerbar keysStatus` returns JSON: `active`, `suspended`, `screen` (monitor name), `cursor` (the name, or `dots:<token>`), `kind` (widget, group, dots, prefs), `zone`, `cursorState` (`managed`, `inlineShown`, `activity`, `hovered`, `token`; null on dots and prefs), `stops` (names in bar order, empty when inactive), `drawer` (null, or `group`, `zone`, `previewing`, `aside`, `cursor`, `member`), `searching`, `query`, `matches`, `sheet`, `handOff`, `foreign` (the last foreign window or layer event), `inline` (expanded zone), `barHidden`, `windowActive`, `drawerFocused`, `pointer` (`hovered`, `x`, `y`), `card` (`shown`, `text`, `mine`, `belongs`), `focused`.

- **KEYS-50** Opening a zone's drawer from the command line (`managed <zone>`) is integration.md's (INTEG-49).

- **KEYS-51** `powerbarKeyLegend` (default true) shows the key strip. When false the strip still appears for a search and for the shortcut sheet.

- **KEYS-52** `powerbarOnDemand` (`drawer` by default, or `inline`) decides what the dots and the into-key do (KEYS-11, KEYS-12).

- **KEYS-53** `powerbarShortcuts` in `bar` of shell.json maps a target (`widget:<plugin id>`, `group:<id>`, `bar:keys`, `bar:search`) to a Hyprland key string such as `"SUPER + CTRL + A"`; `""` removes the shortcut (Omarchy's own too). Every change rewrites a marked block in `~/.config/hypr/bindings.lua` (from `-- >>> powerbar: widget, group and bar shortcuts (written by Powerbar Preferences)` to `-- <<< powerbar`; the rest of the file is untouched) and reloads Hyprland (`hyprctl reload config-only`). If Hyprland reports a new config error, the file is put back and Preferences' footer says "Hyprland refused the shortcut, so nothing changed: …". A group's shortcut goes when the group does.
- **KEYS-71** Writing `bindings.lua` never loses the user's lines: the file is replaced in one step (a sibling file moved over it), so a failure part way leaves it as it was; a linked `bindings.lua` stays a link and its target is written. Nothing is written, and Preferences' footer says "Could not update Hyprland's shortcuts, so nothing changed: …", when the file is not writable or its Powerbar block is damaged (a begin marker without its end, an end without a begin, two blocks, or the end before the begin). A damaged block is read as the user's own text, never as Powerbar's. Code: ShortcutApply.sh; ShortcutModel.js paired(); tests/shortcut-apply.test.cjs The loader of the old `powerbar.lua` in `hyprland.lua` (and that file) goes only after Hyprland took the new block, and only when the loader's markers are whole; a refused block leaves both as they were.
- **KEYS-72** When the write fails or Hyprland refuses the block, the saved `powerbarShortcuts` goes back to what it was, so the shortcuts Powerbar shows always match those bound. A shortcut set in Powerbar also reports `live`: whether Hyprland has those keys bound now. Code: ShortcutStore.qml write()/applyProc; ShortcutModel.js effective()
- **KEYS-73** A target whose id is not plain (anything but letters, digits, `.`, `-`, `_`) binds nothing: it never becomes part of a bind's command. The CLI refuses it with `error: a widget id is letters, digits, dots, dashes and underscores`. Code: ShortcutModel.js command(); CliModel.js shortcutTarget()
- **KEYS-74** A group dissolved while a shortcut change is being written loses its shortcut once that write is done. After a failed write, this cleanup waits for the next change instead of retrying. Code: ShortcutStore.qml pruneStaleGroups()
- **KEYS-75** With the same widget on the bar twice, moving between panels (a panel's own Tab) walks both copies, and Omarchy's place-based panel shortcut (`togglePanelAt`, Super+Ctrl+1–9) opens the copy at that place, not the first. Code: Bar.qml panelNavigationSlots(), panelWidgetIdAt(); BarModel.js pickPanelSlot()
- **KEYS-76** Opening Preferences (its button, `omarchy-shell powerbar preferences`, a bind) ends the keyboard mode first, so only one of them holds the keyboard. Code: Preferences.qml open()
- **KEYS-81** `,` toggles Preferences from the keyboard mode: at bar level or in a drawer (not in a search, where it is typed) it opens Preferences on that bar's monitor, as Enter on the Preferences button does, and the mode ends (KEYS-76). In Preferences `,` (when the focused control does not take it, as a text field does) closes Preferences; when they were opened from the mode (`,` or Enter on the button), the mode comes back on the same bar with the cursor on the stop it left from (a drawer it was in stays closed; the cursor is on the drawer's icon or zone stop). Opened any other way, `,` only closes them. Code: BarKeysModel.PREFS_KEY, barIntent, drawerIntent; BarKeys openPreferences, backFromPreferences, enter(onWindow, at); Preferences.qml closeToKeys

- **KEYS-54** Recording (Preferences): Enter, Space or a click on a shortcut row (not while it is unavailable or Saving) puts Hyprland in the empty submap `powerbar-record` (15 s watchdog) and the tag reads "Press the keys"; the modifiers held show as keycaps. A plain Esc cancels. A combination needs Super, Ctrl or Alt unless it is an F key, else the tag says "Add Super, Ctrl or Alt"; an unmappable key says "Powerbar can't bind that key". If the keys are already bound to something else, the row names it and asks: Enter ("Take over") gives them to this target, Esc keeps them where they were; otherwise the shortcut is saved at once. Losing focus cancels. Code: ShortcutRow.qml, ShortcutModel.fromKeyEvent()

- **KEYS-66** Outside the first start (KEYS-84), no shortcut for the keyboard mode exists until the user sets one. The `bar:keys` row in Preferences → Bar → Keyboard ("Bar keyboard") shows SUPER + B faded, tagged "Suggested", with the hints Enter "Use Super B" and Space "Choose others". Enter takes it (clashes are checked as in KEYS-54); until then no `bar:keys` entry is in `powerbarShortcuts` and no bind is in `bindings.lua`. The bound command is `omarchy-shell powerbar keys` (a toggle). The `bar:search` row under it ("Bar search") works the same way, suggesting SUPER + CTRL + SLASH (Super+/, Super+Shift+/ and Super+Alt+/ are Omarchy's); its command is `omarchy-shell powerbar keysSearch` (KEYS-83). The suggestions are `ShortcutModel.SUGGESTED`.
- **KEYS-84** First start: when Powerbar's first config write (the one that assigns instance ids) finds a config it never ran on (no `powerbar*` bar key, no entry with `powerbarInstance`; `ManagedModel.powerbarHasRun`), it also writes `bar.powerbarShortcutOffer: true`. The shortcut store then reads Hyprland's binds and the binding files again (not an earlier read) and, for `bar:keys` (SUPER + B) and `bar:search` (SUPER + CTRL + SLASH) in that order: a target `powerbarShortcuts` already has an entry for (`""` included) is left alone; one whose keys nothing answers (as KEYS-54 judges a clash: Hyprland's binds outside submaps and Powerbar's own block aside, and Powerbar's other shortcuts) is bound as if accepted in Preferences; one whose keys are held is not, and the holder keeps them. The flag is removed in the same write. One notification ("Powerbar shortcuts", `notify-send -a Powerbar`) says what happened once the block is written: `Super + B starts the keyboard mode, Super + Ctrl + / starts it with its search open. Change them in Preferences → Bar → Keyboard.`; for a held key `Super + B (the keyboard mode) is taken by <what holds it>. Choose keys in Preferences → Bar → Keyboard.`; when Hyprland refuses the block, its error and `Set the bar's shortcuts in Preferences → Bar → Keyboard.` A config Powerbar ran on (an upgrade) gets no flag and nothing is bound; `omarchy bar defaults` (INTEG-87) makes the config new again, so the next start offers again. Nothing happens while Powerbar cannot write the config (INTEG-144); the flag waits. Code: Bar.qml `ensureInstanceIds`, ShortcutStore.qml `offerSuggested()`, `ShortcutModel.offer`, `offerMessage`.

- **KEYS-67** On a shortcut row, x or Delete removes a shortcut (a Powerbar-only one is dropped; one from Omarchy or the user's Hyprland files is written as removed, tag "None, <keys> removed"); Backspace restores Omarchy's own (visible while source is yours or removed).

- **KEYS-68** While the mode is on, the bar is held out as the pointer holds it: an autohidden bar stays shown, and a bar switched off with `omarchy toggle bar` is drawn until the mode ends.

- **KEYS-69** The stop under the cursor is drawn with its own hover highlight, outlined: a one-device-pixel accent ring as the highlight's border (widgets, dots, the Preferences button and drawer rows alike), so ring and fill are one shape. A cursor move within a zone or a drawer slides the ring and fill from the stop it leaves to the stop it reaches (appearance.md LOOK-139); a move to another zone shows at once, without the hover fade: the stop it leaves goes dark and the stop it reaches lights in the same frame, as do the cursor appearing and keyboard mode ending. When the pointer keeps the stop lit after the cursor leaves it, the ring comes off and the fill stays. Pointer hover keeps its 90 ms fade. Where highlights overlap (DRAG-21) the outlined one never dims. Code: HoverHighlight `outlined`, `settle()`.

## Shortcuts: parsing and rendering

- **KEYS-55** A shortcut is Hyprland's spelling: modifiers in the order SUPER, CTRL, ALT, SHIFT, MOD5, joined by " + ", then the key (a letter, F1..F12, a name such as SPACE or RETURN, `code:N`, XF86...). `normalize()` puts any spelling in that order; `same()` compares normalised.

- **KEYS-56** Labels split a shortcut into keycaps: ["Super", "Ctrl", "A"]; SPACE = "Space", RETURN = "Enter", ESCAPE = "Esc", `code:10` to `code:19` = "1".."0", the layout's punctuation, F keys as is, XF86 names without the prefix.

- **KEYS-57** A widget's shortcut shows its source: `omarchy` (Omarchy's bind is live; tag "Omarchy's"), `config` ("Your Hyprland's"), `yours` (set in Powerbar), `removed` (taken away, with the fallback shown), or `none`. A widget also answers to Omarchy's positional shortcut for its place among the right zone's panels (Super+Ctrl+1..9), shown as "By its place". `effective()` returns `{ keys, source, fallback }`.

- **KEYS-58** `conflicts()` lists what else answers these keys: Hyprland's live binds (outside submaps, and not Powerbar's own block) and other Powerbar shortcuts.

- **KEYS-59** `assign()` gives keys to a target and takes them from any other Powerbar shortcut that held them; `restore()` drops a target's entry.

- **KEYS-60** `render()` writes, per target in alphabetical order: `hl.unbind` of Omarchy's old keys if they changed, `hl.unbind` of the new keys, then `o.bind(keys, name, command)`. Commands: widget `omarchy-shell shell toggle <id>`; group `omarchy-shell powerbar toggleGroup <id>`; `bar:keys` `omarchy-shell powerbar keys`; `bar:search` `omarchy-shell powerbar keysSearch`. The names are "Powerbar keyboard", "Powerbar search", "<group label> group", the widget's title (what Super+K lists). No binds renders no block.

- **KEYS-61** Omarchy's own widget shortcuts are read from `$OMARCHY_PATH/default/hypr/bindings/*.lua`, then the user's `~/.config/hypr/*.lua` (not `powerbar.lua`, Powerbar's block stripped), in load order; a later file's bind for the same widget id wins. `omarchy-shell shell toggle <id>` binds and, from newer Omarchy, `{ panel = "<id>" }` binds are by id; `togglePanelAt <section> N` ranges are by place.

- **KEYS-62** Before October 2026 shortcuts lived in `~/.config/hypr/powerbar.lua`, loaded from `hyprland.lua` by a `-- >>> powerbar >>>` block. Any write removes that loader (after a `hyprland.lua.bak.<date>-powerbar` backup) and the file, and writes the new block.

## Focus and refocus

- **KEYS-64** The bar window takes exclusive keyboard focus while the mode is `here`. If the window is still not active after 200 ms (a closing panel can hand focus elsewhere), the bar drops to on-demand focus for 50 ms and asks again, up to 6 times.

- **KEYS-65** Within the mode, if neither the bar's key catcher nor an entered drawer has focus, a 60 ms timer gives it back (the drawer if open and entered, else the bar).
- **KEYS-78** When the monitor whose bar holds the mode goes away (unplugged, switched off), the mode ends with it, as `keysOff` would. Code: Bar.qml BarPanel `Component.onDestruction`.

## Retired IDs

KEYS-36 (the "Into a group or drawer" label) merged into KEYS-32 and KEYS-70: the into arrow is part of "Move" and "Movement".

## Doc drift

None found against README.md (its Keyboard mode section matches).

## Open questions

- A drag with the pointer (drag-edit.md) does not end the keyboard mode; pointer takeover moves the cursor but the mode stays on. Intended?
