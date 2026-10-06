# Keyboard: cursor navigation, fuzzy search, key strip, and shortcuts

The bar works from the keyboard with a cursor on stops (widgets, group icons, zone dots, the Preferences button). Nothing is bound to the keyboard mode by default: `omarchy-shell powerbar keys` toggles it, and Preferences → Bar → Keyboard offers SUPER + B for it (faded, tagged "Suggested") but binds nothing until the user accepts (KEYS-66). Keys are named by direction relative to the bar: along-the-bar keys move the cursor, the into-key (↓ on a top bar) goes into groups and drawers. Search (`/`) finds widgets by name. A name card names the cursor, a key strip lists the keys, `?` lists every shortcut. Esc steps back one level; Esc twice within 400 ms leaves from any depth.

**Sources:**
- BarKeysModel.js: keymap per edge, intents, step, zoneStep, fuzzy search, route, legend
- BarKeys.qml: mode state, stops, drawers, search, name card, hand-off, pointer takeover
- Bar.qml: IPC `keys`/`keysStatus`, key catcher, dismiss layer, key strip window (`keysStrip`), focus priming
- BarCli.qml: `keysOn`, `keysOff`
- ShortcutModel.js, ShortcutStore.qml, ShortcutRow.qml: shortcut parsing, recording, writing `bindings.lua`
- tests/bar-keys.test.cjs, tests/shortcuts.test.cjs

The CLI as a whole (`status`, `shortcuts`, `help`, error format) is integration.md's; only what it does to the keyboard mode is here.

## Keyboard mode: entry and exit

- **KEYS-1** `omarchy-shell powerbar keys` while the mode is off enters it on the focused monitor's bar (the first bar if none matches the focused monitor). Nothing happens while Preferences is open. On entry the cursor lands on, in order: the stop whose panel is open, the centre anchor (the clock), the middle stop of the list, or nowhere if there are no stops. The shortcut store is re-read and the name card shows at once. Stops are, in bar order: widgets and group icons that are on the bar and not in a drawer, folded or yielded, zone dots that are shown, and the Preferences button. Code: BarKeys.enter(), stops(), seen()

- **KEYS-2** The mode ends on: `keys` again; `keysOff`; Esc at bar level (Esc at an inner level steps back first, KEYS-38); two Esc within 400 ms; a click anywhere outside the bar and its open drawer while the bar holds the keys (a dismiss layer covers the rest of the screen and the click is not passed on); a window or a layer that is not Powerbar's or one of Omarchy's own bar surfaces opening (checked 150 ms after the event, and only if no registered panel is open); Enter on the Preferences button (the mode ends first, then Preferences opens). Leaving closes an open panel the cursor opened, closes any drawer, folds an inline expansion, hides the card and drops a pending search reveal.

- **KEYS-3** Enter or Space on a widget opens it like a click and the bar lets go of the keyboard for 400 ms (`handOff`). If the widget opened a registered panel (Omarchy's KeyboardPanel, PopupCard) the mode is suspended (KEYS-4); if a window or layer of its own opened, the mode ends (KEYS-2); if nothing opened (a toggle), the bar takes the keys back after the 400 ms and shows the card again. The card is hidden while the hand-off lasts.

- **KEYS-4** Suspended (a registered panel the cursor opened is open): keys go to the panel; a panel drawn as a popup of the bar that did not take the keys ignores every key but Esc, which closes it. When it closes the mode resumes: card shown, keys back on the cursor or the drawer it came from, and an Esc within 400 ms of the close counts as the second of a double Esc (KEYS-39).

- **KEYS-5** The bar reads keys only while `here`: active, not suspended, not in a hand-off. In every other state the mode is on but keys are not interpreted by it.

## Cursor movement

- **KEYS-6** Along keys move the cursor one stop; at either end it stays (no wrap). Horizontal bar: Left/h = previous, Right/l = next. Vertical bar: Up/k = previous, Down/j = next. Keys the bar does not use are swallowed (they do not reach the window). Code: BarKeysModel.keymap(), step()

- **KEYS-7** Tab goes to the first stop of the next zone that has stops; Shift+Tab (Backtab) to the last stop of the previous one; both wrap round left, centre, right. With stops in one zone only, they land on that zone's first or last stop.

- **KEYS-8** Home moves to the first stop, End to the last, whatever the zone.

- **KEYS-9** If the cursor's stop disappears (hidden, folded, yielded, its drawer or dots changed), the next movement starts from the first stop of the cursor's zone. The cursor is not moved by the disappearance itself.

## Into key: entering groups and drawers

- **KEYS-10** On a group icon, the into-key (top bar: Down or j; bottom: Up or k; right bar: Left or h; left bar: Right or l) opens the group's drawer entered at its first member. The bar's key catcher keeps the window focus; the drawer takes the keys.

- **KEYS-11** In drawer mode (`powerbarOnDemand` = `drawer`) the into-key on any widget of a zone that has on-demand widgets opens that zone's drawer entered at its first row; on the zone's dots it does the same. The bar cursor stays where it was.

- **KEYS-12** In inline mode (`inline`), landing the cursor on a zone's dots asks the zone to expand in place (the way hovering does). The widgets are checked every 25 ms, up to 20 times (500 ms); the cursor then lands on the first widget that appeared in the direction it was moving. If the zone cannot fit, its drawer opens entered instead. The into-key on dots in inline mode does nothing.

- **KEYS-13** In a drawer the out-key (top: Up/k; bottom: Down/j; right: Right/l; left: Left/h) or Esc closes it and returns to the bar with the cursor where it was (on the group icon or the widget or dots it came from); on a top or bottom bar the out-key first walks back up the rows and closes the drawer only from the first row. Code: BarKeysModel.drawerIntent()

## Drawer navigation

- **KEYS-14** In a drawer on a top or bottom bar the rows run away from the bar: the into-key moves to the next row, the out-key to the previous one (closing the drawer from row 0). On a side bar the rows run along the bar: the along keys (Up/k, Down/j) walk the rows, the out-key closes the drawer, and the into-key does nothing. Moving past the last or first row does nothing.

- **KEYS-15** In a drawer on a top or bottom bar, the along keys (Left/h, Right/l) close the drawer and move the bar cursor one stop in that direction. On a side bar they are not used in a drawer.

- **KEYS-16** Tab and Shift+Tab in a drawer close it and jump to the next or previous zone as in KEYS-7.

- **KEYS-17** Enter or Space in a drawer opens the current row's widget, with the same hand-off as KEYS-3.

- **KEYS-18** Esc in a drawer closes it (cursor back on the bar, KEYS-13); a second Esc within 400 ms ends the mode.

- **KEYS-19** When the opened member shows a registered panel the drawer steps aside and the mode is suspended; Esc in the panel closes it and the keys return to the drawer with the card on the current row.

- **KEYS-20** Preview: after a non-repeating key is released with the cursor on a group icon (or, in drawer mode, on zone dots) and no drawer open, a 100 ms timer opens the drawer unfolded beside the icon but not entered; any key pressed first cancels it, so a held key sweeping across stops never flashes drawers. In a preview the name card is hidden and the pointer may take over (KEYS-47).

## Search: fuzzy name matching and navigation

- **KEYS-21** `/` starts a search with an empty query (from a drawer it closes the drawer first). The key strip shows a "Find" box with a caret and, under an empty query, "Type part of a name"; the shortcut sheet closes. The strip shows for a search even when `powerbarKeyLegend` is false.

- **KEYS-22** Each typed character (h, j, k, l included) appends to the query, Space appends a space, Backspace removes one; each edit resets the match to the first and brings it into view. The strip reads "N of M", "1 match", or "No widget named that" (urgent colour) when nothing matches.

- **KEYS-23** Tab in search goes to the next match, Shift+Tab to the previous (wrapping), acting at once.

- **KEYS-24** Enter in search ends the search and opens the match: a member through its group's drawer, a widget behind dots or in a drawer once it has come into view, or the cursor's stop. Code: BarKeys.openMatch()

- **KEYS-25** Ranking (fzy): each space-separated word must match on its own letters, in order, with gaps allowed, using letters no earlier word used. The first word (when it has two or more letters) may match anywhere in the text; a single-letter first word, and every later word, must start at a word start or a capital. Consecutive letters score highest (1), then a word start (0.9 at the text start, 0.8 after a separator, 0.7 at a capital), gaps cost 0.01 inside and 0.005 outside. Best total score first; ties in bar order. An empty query matches nothing. Code: BarKeysModel.matches(), fuzzy()

- **KEYS-26** A match comes into view the way the pointer would bring it: on the bar → the cursor lands on it; in inline mode behind its zone's dots or folded → the dots open in place (another zone's expansion closes) and the cursor waits on the dots, then lands on the widget; in drawer mode in its zone's drawer → the drawer opens entered at it; a member lands in its group's drawer at its row; otherwise (yielded to another zone's expansion) that expansion closes first. Landing is checked every 25 ms up to 60 times (1.5 s); an expansion that cannot fit falls back to the zone's drawer. Code: BarKeysModel.route(), BarKeys.bringIn()

- **KEYS-27** Typing waits: a match already on the bar is taken at once, but a match that needs the bar to change (dots, drawer, closing another zone) is queued for 150 ms of no typing. Tab and Enter never wait.

- **KEYS-28** An arrow, Home or End in search ends it (query cleared) and does its usual job; on a top bar Down after a group match goes into that group.

- **KEYS-29** Esc in search ends it and clears the query; the cursor stays where the last match put it. A second Esc within 400 ms ends the mode.

- **KEYS-30** A member's search text is "<group name> <member name>"; "ai a" finds the AI group's members whose names start with a, and not the AI group itself (its text has no second a to use).

## Search catalogue

- **KEYS-31** The catalogue is every widget and group icon the bar holds a slot for (on the bar, behind dots, in a drawer, folded, yielded) plus the Preferences button ("Powerbar preferences"); members are found through their group name too. Hidden widgets have no slot and are not found. Zone dots are not searchable.

## Key strip and shortcut sheet

- **KEYS-32** While the mode is active and not suspended, a strip at the screen edge opposite the bar (24 px in) lists the keys for the current level, unless `powerbarKeyLegend` is false (default true; Preferences → Bar → Keyboard → Key legend). The strip is hidden while the bar is sliding. Bar level: Move (← → or ↑ ↓), Into (the into arrow) "Into a group", Tab "Next zone", Enter "Open", / "Find", ? "Shortcuts", Esc "Leave". Code: BarKeysModel.legend()

- **KEYS-33** Drawer level: Move, Enter "Open", Back (Esc; on a side bar the out arrow and Esc), Esc Esc "Leave". For a top or bottom bar, Move shows the into and out arrows (↓ ↑ on top).

- **KEYS-34** Search level: Tab "Next match", Enter "Open", Esc "Stop finding", Esc Esc "Leave".

- **KEYS-35** The arrows are named by the edge: top bar into = ↓, out = ↑; bottom into = ↑; right bar into = ←, out = →; left bar into = →. hjkl never appear on the strip.

- **KEYS-36** In drawer mode (`powerbarOnDemand` = `drawer`) the bar-level label is "Into a group or drawer"; in inline mode "Into a group".

- **KEYS-37** The double Esc is listed on the drawer and search strips only, as "Esc Esc" "Leave"; the bar-level strip lists a single Esc "Leave".

- **KEYS-70** `?` shows the shortcut sheet in the strip: "Shortcuts" and two columns, widget or group name and its shortcut, for every catalogue entry that has one; with none, "No widget on this bar has a shortcut yet. Set them in Preferences → Layout." It shows even when the key legend is off. `?` or Esc closes it; any other key closes it and then does its usual job.

## Double Escape (quick exit)

- **KEYS-38** Every Esc is timed: an Esc less than 400 ms after the previous Esc leaves the mode, whatever the depth (closing any open panel, drawer and search). A lone Esc closes the innermost level: search first, then the open sheet, then the drawer, then the mode.

- **KEYS-39** A registered panel's own Esc counts as the first: when it closes, an Esc within 400 ms leaves the mode too.

## Name card

- **KEYS-40** When the mode is `here` and the cursor is on a widget, the card beside it reads "<name>" or "<name>   <shortcut>" (three spaces; the shortcut as keycaps text such as "Super Ctrl A"). The Preferences button's card is "Powerbar preferences".

- **KEYS-41** In an entered drawer the card names the current row's widget (and its shortcut) instead of the cursor.

- **KEYS-42** The card refreshes when the cursor moves, when the drawer's row changes, when the drawer is no longer stepped aside, and when the shortcut store changes.

- **KEYS-43** The card is hidden on group icons and on zone dots in drawer mode (they open a drawer), on a drawer preview, while suspended or handing off, and when the mode ends.

- **KEYS-44** The card shows only for a target that belongs to the keyboard's window (`keysStatus.card.belongs`); on other monitors' bars it is hidden.

## Pointer takeover

- **KEYS-45** While the mode is `here`, moving the pointer onto a stop moves the cursor there. Only a real move counts: the pointer's position when the mode began, and a re-report of the same point, are ignored (under 1 px).

- **KEYS-46** A takeover closes any open drawer and moves the card to the new stop.

- **KEYS-47** In an entered drawer the pointer does not take over; in a drawer preview (not entered) it does.

## IPC and configuration

- **KEYS-48** `omarchy-shell powerbar keys` toggles the mode on the focused monitor's bar (nothing while Preferences is open). `keysOn` starts it and answers `ok`, or `error: not while Preferences are open`, or `error: no bar to put the cursor on`; `keysOff` ends it and answers `ok` whether or not it was on. `status` reports it as `runtime.keys`. Other CLI behavior: integration.md. Code: BarCli.keysOn(), keysOff()

- **KEYS-49** `omarchy-shell powerbar keysStatus` returns JSON: `active`, `suspended`, `screen` (monitor name), `cursor` (the name, or `dots:<token>`), `kind` (widget, group, dots, prefs), `zone`, `cursorState` (`managed`, `inlineShown`, `activity`, `hovered`, `token`; null on dots and prefs), `stops` (names in bar order, empty when inactive), `drawer` (null, or `group`, `zone`, `previewing`, `aside`, `cursor`, `member`), `searching`, `query`, `matches`, `sheet`, `handOff`, `foreign` (the last foreign window or layer event), `inline` (expanded zone), `barHidden`, `windowActive`, `drawerFocused`, `pointer` (`hovered`, `x`, `y`), `card` (`shown`, `text`, `mine`, `belongs`), `focused`.

- **KEYS-50** Opening a zone's drawer from the command line (`managed <zone>`) is integration.md's (INTEG-49).

- **KEYS-51** `powerbarKeyLegend` (default true) shows the key strip. When false the strip still appears for a search and for the shortcut sheet.

- **KEYS-52** `powerbarOnDemand` (`drawer` by default, or `inline`) decides what the dots and the into-key do (KEYS-11, KEYS-12).

- **KEYS-53** `powerbarShortcuts` in `bar` of shell.json maps a target (`widget:<plugin id>`, `group:<id>`, `bar:keys`) to a Hyprland key string such as `"SUPER + CTRL + A"`; `""` removes the shortcut (Omarchy's own too). Every change rewrites a marked block in `~/.config/hypr/bindings.lua` (from `-- >>> powerbar: widget, group and bar shortcuts (written by Powerbar Preferences)` to `-- <<< powerbar`; the rest of the file is untouched) and reloads Hyprland (`hyprctl reload config-only`). If Hyprland reports a new config error, the file is put back and Preferences' footer says "Hyprland refused the shortcut, so nothing changed: …". A group's shortcut goes when the group does.

- **KEYS-54** Recording (Preferences): Enter, Space or a click on a shortcut row (not while it is unavailable or Saving) puts Hyprland in the empty submap `powerbar-record` (15 s watchdog) and the tag reads "Press the keys"; the modifiers held show as keycaps. A plain Esc cancels. A combination needs Super, Ctrl or Alt unless it is an F key, else the tag says "Add Super, Ctrl or Alt"; an unmappable key says "Powerbar can't bind that key". If the keys are already bound to something else, the row names it and asks: Enter ("Take over") gives them to this target, Esc keeps them where they were; otherwise the shortcut is saved at once. Losing focus cancels. Code: ShortcutRow.qml, ShortcutModel.fromKeyEvent()

- **KEYS-66** No shortcut for the keyboard mode exists until the user sets one. The `bar:keys` row in Preferences → Bar → Keyboard ("Bar keyboard") shows SUPER + B faded, tagged "Suggested", with the hints Enter "Use Super B" and Space "Choose others". Enter takes it (clashes are checked as in KEYS-54); until then no `bar:keys` entry is in `powerbarShortcuts` and no bind is in `bindings.lua`. The bound command is `omarchy-shell powerbar keys` (a toggle).

- **KEYS-67** On a shortcut row, x or Delete removes a shortcut (a Powerbar-only one is dropped; one from Omarchy or the user's Hyprland files is written as removed, tag "None, <keys> removed"); Backspace restores Omarchy's own (visible while source is yours or removed).

- **KEYS-68** While the mode is on, the bar is held out as the pointer holds it: an autohidden bar stays shown, and a bar switched off with `omarchy toggle bar` is drawn until the mode ends.

- **KEYS-69** The stop under the cursor is drawn with the hover highlight and a 1.5 px accent ring (widgets, dots and the Preferences button alike).

## Shortcuts: parsing and rendering

- **KEYS-55** A shortcut is Hyprland's spelling: modifiers in the order SUPER, CTRL, ALT, SHIFT, MOD5, joined by " + ", then the key (a letter, F1..F12, a name such as SPACE or RETURN, `code:N`, XF86...). `normalize()` puts any spelling in that order; `same()` compares normalised.

- **KEYS-56** Labels split a shortcut into keycaps: ["Super", "Ctrl", "A"]; SPACE = "Space", RETURN = "Enter", ESCAPE = "Esc", `code:10` to `code:19` = "1".."0", the layout's punctuation, F keys as is, XF86 names without the prefix.

- **KEYS-57** A widget's shortcut shows its source: `omarchy` (Omarchy's bind is live; tag "Omarchy's"), `config` ("Your Hyprland's"), `yours` (set in Powerbar), `removed` (taken away, with the fallback shown), or `none`. A widget also answers to Omarchy's positional shortcut for its place among the right zone's panels (Super+Ctrl+1..9), shown as "By its place". `effective()` returns `{ keys, source, fallback }`.

- **KEYS-58** `conflicts()` lists what else answers these keys: Hyprland's live binds (outside submaps, and not Powerbar's own block) and other Powerbar shortcuts.

- **KEYS-59** `assign()` gives keys to a target and takes them from any other Powerbar shortcut that held them; `restore()` drops a target's entry.

- **KEYS-60** `render()` writes, per target in alphabetical order: `hl.unbind` of Omarchy's old keys if they changed, `hl.unbind` of the new keys, then `o.bind(keys, name, command)`. Commands: widget `omarchy-shell shell toggle <id>`; group `omarchy-shell powerbar toggleGroup <id>`; `bar:keys` `omarchy-shell powerbar keys`. The names are "Powerbar keyboard", "<group label> group", the widget's title (what Super+K lists). No binds renders no block.

- **KEYS-61** Omarchy's own widget shortcuts are read from `$OMARCHY_PATH/default/hypr/bindings/*.lua`, then the user's `~/.config/hypr/*.lua` (not `powerbar.lua`, Powerbar's block stripped), in load order; a later file's bind for the same widget id wins. `omarchy-shell shell toggle <id>` binds are by id; `togglePanelAt <section> N` ranges are by place.

- **KEYS-62** Before October 2026 shortcuts lived in `~/.config/hypr/powerbar.lua`, loaded from `hyprland.lua` by a `-- >>> powerbar >>>` block. Any write removes that loader (after a `hyprland.lua.bak.<date>-powerbar` backup) and the file, and writes the new block.

## Focus and refocus

- **KEYS-64** The bar window takes exclusive keyboard focus while the mode is `here`. If the window is still not active after 200 ms (a closing panel can hand focus elsewhere), the bar drops to on-demand focus for 50 ms and asks again, up to 6 times.

- **KEYS-65** Within the mode, if neither the bar's key catcher nor an entered drawer has focus, a 60 ms timer gives it back (the drawer if open and entered, else the bar).

## Doc drift

None found against README.md (its Keyboard mode section matches).

## Open questions

- A drag with the pointer (drag-edit.md) does not end the keyboard mode; pointer takeover moves the cursor but the mode stays on. Intended?
