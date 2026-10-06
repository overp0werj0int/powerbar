# Keyboard: Super+B cursor navigation, fuzzy search, key legend, and shortcuts

The bar works from the keyboard with a cursor on stops (widgets, group icons, zone dots, the prefs button). The shortcut is bound via Preferences → Bar → Keyboard, default Super+B, which runs `omarchy-shell powerbar keys`. Keys adapt to the bar's edge: along-the-bar keys move the cursor, the into-key (↓ on top, ← on right) enters groups and drawers. Search (`/`) finds widgets by name (fzy ranking). A name card names the cursor. A key strip (`?`) shows all shortcuts. Esc steps back through drawer, search, mode. Esc twice (within 400 ms) leaves instantly from any depth.

**Sources:**
- BarKeysModel.js: keyboard intent rules, cursor movement, search ranking (fuzzy), key legend, route to widget (how search brings it into view)
- BarKeys.qml: mode state, stops list, drawer handling, search state, name card, panel handoff, keyboard focus, pointer takeover
- ShortcutModel.js: parsing, formatting, rendering shortcut binds, conflict detection
- Bar.qml: IPC functions, config keys, managed drawer opening
- tests/bar-keys.test.cjs: all movement, search, legend behaviors
- tests/shortcuts.test.cjs: shortcut format, conflicts, rendering, recording

## Keyboard mode: entry and exit

- **KEYS-1** Entering: `omarchy-shell powerbar keys` toggles the mode on the focused monitor. On entry, the cursor lands on the widget whose panel is open (if any), else the configured center anchor widget, else the middle stop (if any exist), else null. Stops list includes only widgets/groups on the bar, zone dots, and the prefs button, all visible and not folded or in another zone's drawer. On entry, bar refreshes its shortcut store and shows a name card beside the cursor. Exit restores no keyboard focus guarantee (it is on work, not the bar).

- **KEYS-2** Leaving: `omarchy-shell powerbar keys` again (toggle), or Esc twice within 400 ms, or Super+B (the bound shortcut), or a click outside the bar area, or a foreign window/layer opens (not a Powerbar or Omarchy bar/panel surface). Leaving closes any open drawer and turns off inline expansion (zone collapses). Hide card, drop any pending (queued) search action.

- **KEYS-3** Panel hands off keyboard: once Enter opens a widget, `handOff` flag rises for 400 ms. A registered panel (Omarchy's KeyboardPanel, PopupCard) takes the keys back when suspended; an unregistered window or layer leaves the mode. A toggle (no open) returns keyboard to bar once the 400 ms hand-off waits (or instantly if the panel closes faster). Name card and key strip hide during hand-off.

- **KEYS-4** Suspended: mode stays active but keys go to an open panel. Esc in the panel closes it and resumes bar keys (shows card, refocuses). Return from suspension shows card and refocuses.

- **KEYS-5** Mode active but not here: `active && suspended || !suspended && !handOff` but either one kills keyboard input. Input only accepted when `here: active && !suspended && !handOff` is true.

## Cursor movement

- **KEYS-6** Along-the-bar movement: keys Left/Right (or h/l on top/bottom bar) and Up/Down (or h/l on left/right bar) move the cursor by one stop. The cursor must move to a valid stop: unseen (hidden, folded, in drawer) stops are skipped. Cursor stops at bar ends (no wrap).

- **KEYS-7** Zone jumping: Tab moves to the next zone's first stop (forward); Shift+Tab or Backtab moves to the previous zone's last stop (backward); wraps around all zones. Returns -1 if no zone has stops; cursor is not moved.

- **KEYS-8** Home and End: Home moves cursor to the first stop; End to the last. Both ignore zone boundaries.

- **KEYS-9** Cursor position after bar changes: if the cursor's stop is deleted (widget hidden, on-demand folded, drawer closed), the cursor lands on the first stop of its zone. If the zone has no more stops, no move (cursor becomes unanchored). On a move, if the zone changed (inline expansion started/stopped, another zone expanded/collapsed), the current inlineZone for that stop updates.

## Into key: entering groups and drawers

- **KEYS-10** Group drawer entry: when the cursor is on a group icon, the into-key (Down on top, Up on bottom, Left on right, Right on left) opens the group's managed drawer. The cursor enters at member 0. Bar holds focus at a KeyCatcher element; drawer takes activeFocus.

- **KEYS-11** Zone drawer entry (drawer mode): when on-demand is "drawer" and the cursor is on a widget in a zone with managed members, the into-key opens the zone's managed drawer. The cursor enters at member 0, and bar holds focus on the zone's dots (if visible, else the zone's first stop).

- **KEYS-12** Zone dots inline expansion (inline mode): when on-demand is "inline" and the cursor lands on a zone's FoldHandle (dots), if the zone has managed members, calling openDots() with dir (1 or -1 for the arrow direction) requests the zone to expand. A pending state tracks the expansion; widgets are checked for visibility every 25 ms up to 20 frames (500 ms). Once shown, the cursor lands on the first widget that appeared in the dir direction. If the zone cannot fit in the bar (another zone must yield), it opens the zone's drawer instead.

- **KEYS-13** Out key: when in a drawer, the into-key (Left on vertical bars, Up/Down on horizontal) or Escape closes the drawer and refocuses the bar at the zone's dots (or first stop of that zone if dots not visible). From the first member of a drawer on a horizontal bar, the into-key goes back without moving.

## Drawer navigation

- **KEYS-14** Member walking: Up/Down (j/k on vertical bars, Left/Right on horizontal) move to adjacent members. Out of bounds is ignored (cursor does not leave the drawer's member range).

- **KEYS-15** Drawer column/row movement: on a horizontal bar's drawer (members are rows), Left/Right (h/l) run along the bar (call backMove: they close the drawer first, then move the bar cursor). On a vertical bar's drawer, Left/Right are no-op.

- **KEYS-16** Tab in drawer: Tab moves to the next zone's stop (closes drawer first, jumps cursor). Backtab goes to the previous zone.

- **KEYS-17** Enter in drawer: opens the drawer's current member and sets the handOff flag.

- **KEYS-18** Escape in drawer (on a row): Up from the first row goes back and closes the drawer. Any other Escape also closes.

- **KEYS-19** Drawer stays open if panel opens: After Enter on a member, if the panel is a registered panel (suspended), the drawer stays open and the bar holds keys. Esc in the panel closes it and returns focus to the drawer.

- **KEYS-20** Drawer preview on key release: once the key is released and no drawer is open yet, a 100 ms timer opens the group drawer in preview mode. During a held key sweeping past multiple stops, no drawer flashes.

## Search: fuzzy name matching and navigation

- **KEYS-21** Starting search: `/` (forward slash) starts search with an empty query. Focus stays with the bar; no drawer closes; key legend switches to search legend.

- **KEYS-22** Search character input: each character appends to the query; Space appends a word separator. Backspace removes the last character. After ~150 ms of pause in typing, the search brings a match into view.

- **KEYS-23** Tab in search: moves to the next match (matchIndex cycles modulo found.length). Does not end search. Acts immediately without revealPause delay.

- **KEYS-24** Enter in search: opens the current match. If it is a member in the drawer, activates it. If it is behind dots or in a drawer, brings it into view first, then opens it. If on bar, opens the widget.

- **KEYS-25** Search rank: each word (separated by spaces) must match separately, in any order, fuzzily (fzy algorithm: gaps cost more than consecutive matches, word starts and capitals bonus higher). A member matches its group name first ("ai local laya" matches "ai a"). A single letter or first word of a space-separated query must start a word; later words only need to appear in order. Exact match (entire query = widget name) ranks first. Bar order breaks ties. Empty query returns no matches.

- **KEYS-26** Search brings into view the way a pointer would: if the match is on the bar (visible, inline, not folded), lands on it (put). If it is behind dots in inline mode, dots open in place (zone expands, cursor waits on the dots). If it is folded or in a drawer, zone drawer opens and the match lands there. If another zone is expanded, that closes first (clear). Once the zone opens or drawer opens, the cursor lands on the match once it is visible (checked every 25 ms, up to 60 tries = 1.5 s).

- **KEYS-27** Typing pauses the reveal: typing does not open a zone immediately (it waits up to 150 ms for more typing). Tab and Enter act at once. A match already on bar (not behind dots) acts at once. Once revealed, the cursor moves to it and its zone (or drawer) stays open.

- **KEYS-28** Arrow in search ends search and moves: pressing Up/Down/Left/Right/Home/End ends the search (searching = false, query = "") and performs its normal cursor movement. On a top bar, ↓ in search enters the group found (its into key).

- **KEYS-29** Escape in search: ends search. If a panel was open when search started, Esc only closes search, not the panel.

- **KEYS-30** Search with members: search text is "<group name> <member name>" for members. /ai a finds all AI group members whose name starts with "a". /ai u finds the AI group but also members.

## Search catalogue

- **KEYS-31** Everything searchable is every visible widget and group, plus the prefs button. Hidden widgets have no slot so are not found. Members are found by group name too. Widgets in drawers, behind dots, or folded off are all found (search brings them into view). Bar order sets tie-breaking rank.

## Key legend: shortcut reference

- **KEYS-32** Legend toggle: `?` shows the key legend. Legend shows keys for bar mode (Move, Into, Next zone, Open, Find, Shortcuts, Leave), with a line per action. Pressing `?` again or Escape closes it. Legend adapts based on whether drawers mode is active.

- **KEYS-33** Legend in drawer: when in a drawer and `?` is pressed, legend shows drawer actions (Move, Open, Back/Leave, quick double Esc).

- **KEYS-34** Legend in search: search legend shows Tab (Next match), Enter (Open), Esc (Stop finding), Esc Esc (Leave).

- **KEYS-35** Legend arrows adapt to edge: on a top bar, the into-arrow is ↓ and out is ↑. On a right bar, into is ← and out is →. Legend names the arrows, not the key names (hjkl is not shown, arrows are).

- **KEYS-36** Legend with drawers mode: if on-demand is "drawer" and there are managed members in the cursor's zone, legend shows "Into a group or drawer" (parameter drawers=true).

- **KEYS-37** Legend always shows twice-Esc: both bar and drawer legends list "Esc Esc" as "Leave" (quick double press within 400 ms).

## Double Escape (quick exit)

- **KEYS-38** Double Escape rule: pressing Esc twice within 400 ms ends everything: closes any open panel, closes any drawer, ends search, and leaves the mode. Single Esc only closes the innermost: search first, then drawer, then mode.

- **KEYS-39** Panel Escape counts as first: once a panel closes, a following Esc within 400 ms is the second, so the next Esc starts the counter fresh.

## Name card

- **KEYS-40** Card shows cursor name and shortcut: when the keyboard mode is active and the cursor is not on an opens-drawer item (group, dots, prefs), a name card shows the cursor's widget name and any shortcut.

- **KEYS-41** Card in drawer: when in a drawer and not previewing, the card shows the drawer's current member. Bar uses the drawer's cellAt(cursor) as target; the card names the member and its shortcut.

- **KEYS-42** Card update triggers: card refreshes when the cursor changes, drawer cursor changes, drawer is no longer stepped-aside, or the shortcut store updates (shortcut label for this target changes).

- **KEYS-43** Card hides: when leaving mode, in a panel, or on a drawer-opening item (group, dots, prefs). Bar hides it with bar.hideCard().

- **KEYS-44** Card target belongs to window: the card shows only if its target item belongs to the keyboard's window (checked by bar.targetBelongsToWindow). If not, bar.hideCard().

## Pointer takeover

- **KEYS-45** Pointer over bar takes cursor: while keyboard mode is active (here = true), moving the pointer onto a visible stop moves the keyboard cursor to that stop. A pointer that moved (not just re-reported at the same spot) triggers takeover. The bar's lastPointer tracks the pointer position when mode started; a sub-1px move is ignored (jitter filter).

- **KEYS-46** Pointer takeover closes drawer and updates card: when takeover moves the cursor, the drawer closes (if open) and the card updates to show the new cursor.

- **KEYS-47** Pointer in drawer preview does not takeover: while previewing (drawer unfolded beside an icon but not entered), pointer on other stops does not move the keyboard cursor.

## IPC and configuration

- **KEYS-48** `omarchy-shell powerbar keys`: toggles the keyboard mode on the focused monitor's bar. If no bar on focused monitor, no-op.

- **KEYS-49** `omarchy-shell powerbar keysStatus`: returns JSON of the cursor's state: { active, suspended, screen (name), cursor (name or "dots:<token>"), kind ("widget", "group", "dots", "prefs"), zone, cursorState (managed, inlineShown, activity, hovered, token for the cursor's widget), stops (names of all stops), drawer (group id, zone, previewing, cursor index, member name), searching, query, matches (count), sheet, handOff, foreign (last layer/window that opened), inline (zone name), barHidden, windowActive, drawerFocused, pointer (hovered, x, y), card (shown, text, mine, belongs), focused }. 

- **KEYS-50** `omarchy-shell powerbar managed <zone>`: opens the managed drawer for a zone (left, center, right). Sets the cursor on the zone's dots (if visible), else the zone's first stop, and enters the drawer. Used by drawer mode (when on-demand is "drawer" and the bar keyboard cursor enters a zone with managed members).

- **KEYS-51** `powerbarKeyLegend` config: boolean (default true). When false, the key strip does not appear (legend toggle still works, just no strip). Checked by keys.bar.keyLegend; when false, KeyLegend and KeyCatcher are still present but hidden.

- **KEYS-52** `powerbarOnDemand` config: "inline" or "drawer" (default "drawer"). Governs how zone dots enter: "drawer" opens the zone's managed drawer; "inline" expands the zone in place behind its dots.

- **KEYS-53** `powerbarShortcuts` in shell.json: object mapping target ("widget:<id>" or "group:<id>" or "bar:keys") to a Hyprland key string ("SUPER + CTRL + A"). An empty string removes a shortcut (uses Omarchy's or none). Changes are rendered into ~/.config/hypr/bindings.lua in the marked Powerbar block. The block is rewritten on every change; keys it takes are unbound first, as are Omarchy shortcuts it moves or removes.

- **KEYS-54** Shortcut recording: in Preferences, Enter or clicking a shortcut field enters an empty submap (powerbar-record), stopping Hyprland's own shortcuts for 15 seconds. Every key press (no modifiers alone) is converted to a Hyprland key string via qt key code, modifiers, and scan code. A shortcut needs Super, Ctrl or Alt, unless it is an F-key (F1–F12 allowed without modifiers). Space records a key, Escape cancels.

## Shortcuts: parsing and rendering

- **KEYS-55** Shortcut string format: Hyprland's spelling: modifiers in order (SUPER, CTRL, ALT, SHIFT, MOD5) separated by " + ", then the key (letter A–Z, digit via code, F1–F12, named key like SPACE RETURN TAB, or XF86... function key). `normalize()` sorts modifiers to one canonical order. `same()` compares normalized strings.

- **KEYS-56** Shortcut labels: `label()` or `caps()` converts a shortcut string to a display list: ["Super", "Ctrl", "A"]. Keys display as "A" (letters), "Space" (SPACE), "Esc" (ESCAPE), "1" etc. (codes: code:10 becomes "1"), "F5" etc., or "XF86..." name. Scan codes are preferred over ASCII values (code:19 from Qt key 0x30 = "0").

- **KEYS-57** Widget shortcut sources: a widget shows Omarchy's shortcut (if live), one from the user's Hyprland config files, one set in Powerbar Preferences, or a positional shortcut (Super+Ctrl+1–9 by right-zone panel index), or "none". `effective()` returns { keys, source ("omarchy", "config", "yours", "removed", "none"), fallback (Omarchy's if the widget has one) }.

- **KEYS-58** Shortcut conflicts: `conflicts()` lists Hyprland's binds and Powerbar's other shortcuts that claim these keys. Does not count binds in other submaps (e.g., powerbar-record). Powerbar's block keys (parsed by blockKeys()) are excluded so they are not named as "already set".

- **KEYS-59** Shortcut assignment: `assign()` sets a shortcut, taking it from any other Powerbar shortcut that held it. `restore()` drops the entry, reverting to Omarchy's or none. A key string "" removes the shortcut.

- **KEYS-60** Shortcut rendering: `render()` writes the marked Lua block for ~/.config/hypr/bindings.lua. For each shortcut: unbind the previous Omarchy shortcut (if changed), unbind the new keys (in case another target held them), then o.bind() with the name and command. Widgets run `omarchy-shell shell toggle <id>`; groups run `omarchy-shell powerbar toggleGroup <id>`; "bar:keys" runs `omarchy-shell powerbar keys`.

- **KEYS-61** Omarchy's defaults and user config: `parseDefaults()` reads Omarchy's default binds from Lua and `hyprctl binds`, extracting widgets by id and by position (Super+Ctrl+1–9 ranges). `readDefaults([{text, origin}])` merges files in load order, later files overriding earlier for the same widget id. User config files (origin: "config") win over Omarchy's (origin: "omarchy").

- **KEYS-62** Backward compatibility: Before Oct 2026, shortcuts lived in ~/.config/hypr/powerbar.lua, loaded from hyprland.lua. The render block includes old markers (OLD_START, OLD_END); a new write removes both files and writes only the new block.

## Bar keyboard mode status

- **KEYS-63** Status structure: `keysStatus()` returns a JSON object with all state for tests and debugging. Keys are: active (boolean), suspended (boolean), screen (string, focused monitor name), cursor (widget name or "dots:<inlineToken>"), kind ("widget", "group", "dots", "prefs", empty), zone ("left", "center", "right", empty), cursorState (null if on dots/prefs, else { managed, inlineShown, activity, hovered, token }), stops (array of names), drawer (null or { group, zone, previewing, aside, cursor, member }), searching (boolean), query (string), matches (number), sheet (boolean), handOff (boolean), foreign (string, last layer/window that triggered foreign check), inline (zone name or empty), barHidden (boolean), windowActive (boolean), drawerFocused (boolean), pointer ({ hovered, x, y } or null), card ({ shown, text, mine, belongs }), focused (boolean, bar has focus).

## Focus and refocus

- **KEYS-64** Focus guarantee: the keyboard must always have a landing place. If neither the bar's KeyCatcher nor the drawer has activeFocus, a refocus timer (60 ms) tries again. Focus attempts: first the drawer (if open and not previewing), then the bar's KeyCatcher.

- **KEYS-65** Focus recovery: if neither has focus during mode, a 60 ms refocus timer tries again.

## Doc drift

None; README and code agree on keyboard behavior.

## Open questions

None; code is clear.
