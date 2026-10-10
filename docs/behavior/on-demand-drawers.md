# On-demand widgets and drawers

An On demand widget (saved as `powerbarVisibility: "managed"`, "Managed" in code and CONTEXT.md) is hidden at rest. It appears on the bar for a moment when it has activity, and is reached through its zone's drawer (the default) or an inline expansion of the zone (`powerbarOnDemand: "inline"`). Group drawers and menus: groups.md. Drag and drop into drawers and onto dots: drag-edit.md. Zone fit and the dots: layout-zones.md. Keyboard mode: keyboard.md. The shell.json keys and the CLI: integration.md.

**Sources:** ManagedModel.js, InlineQueue.js, ManagedDrawer.qml, ActivityObserver.qml, Bar.qml (grep: managed, activity, reveal, inline, drawer, peek, placeholder), BarModel.js (`options()`), tests/managed.test.cjs, tests/inline-queue.test.cjs, tests/clean-defaults.test.cjs, CONTEXT.md.

## Visibility modes and the default

Each layout entry has one visibility mode: `"shown"` (Always shown, "On the bar" in Preferences), `"managed"` (On demand) or `"hidden"` (Always hidden). The mode is independent of the zone.

- **DEMAND-1** An entry with `powerbarVisibility` of `"shown"`, `"managed"` or `"hidden"` uses it. Without one, the widget is shown (DEMAND-82). A widget the registry has not described yet is drawn nowhere ("pending") until it is; command and QML-module entries count as known at once. Code: `ManagedModel.mode()`.
- **DEMAND-2** Changing a widget's visibility (Preferences, drag, `setWidget`) rewrites only `powerbarVisibility` (plus zone and place when the change is a move); its settings and `powerbarInstance` are kept. Code: `PreferencesModel.move()`.
- **DEMAND-3** An On demand widget stays loaded while it is off the bar, so its activity can be observed (`managedStatus` shows `observing` > 0). An Always hidden widget is removed from the rendered layout: it has no slot, is never loaded, and is in no drawer. Code: `Bar.normalizeLayout()`.
- **DEMAND-4** Setting a widget to Always shown or Always hidden ends any activity reveal at once (shown: it is simply visible; hidden: it is gone). Moving an On demand widget to another zone keeps its remaining reveal time (the deadline belongs to its `powerbarInstance`, DEMAND-76).
- **DEMAND-82** Default: an entry with no saved `powerbarVisibility` is Always shown, whoever supplies the widget (Omarchy, a plugin, a command or QML module), as on Omarchy's bar. Nothing writes this default back into the layout. Code: `ManagedModel.mode()`; the CLI reports it (integration.md INTEG-112).
- **DEMAND-83** Legacy configs: a config Powerbar ran on before this default (it has any `powerbar*` key under `bar`, or an entry with `powerbarInstance`) and that lacks `bar.powerbarVisibilityDefault: "shown"` keeps the old rule until healed: an entry with no saved visibility and not from Omarchy is On demand, an Omarchy entry is Always shown. A fresh config (no `powerbar*` key, no instance id) never follows the old rule. Code: `ManagedModel.legacyDefaults()`.
- **DEMAND-84** Heal, as the user sees it: on the first run of the current version the config is rewritten once. On a legacy config every not-from-Omarchy entry with no saved visibility gets `powerbarVisibility: "managed"`, so what is on the bar and what is in the drawers does not change; entries with a saved visibility and Omarchy's own widgets are untouched. On a fresh config only the marker is written. Both end with `bar.powerbarVisibilityDefault: "shown"`; a marked config is never healed again, and a widget added later without a visibility is Always shown. Mechanics: integration.md INTEG-113. Code: `ManagedModel.healVisibility()`, `Bar.ensureInstanceIds()`.

## Empty widgets: the placeholder rule

- **DEMAND-85** A widget with nothing to show (no updates pending, Bluetooth off, an empty tray) hides itself, as on Omarchy's bar, unless the user placed it. It keeps a fallback icon in its place when its mode is On demand (the drawer needs something to show), or when its saved `powerbarVisibility` is explicitly `"shown"`. A widget with no saved visibility (the default, DEMAND-82) and an Always hidden one keep no fallback. Placing a widget through Preferences, drag or `setWidget` always saves a visibility, so it then keeps a fallback. Code: `ManagedModel.placeholder()`, Bar.qml slot `needsPlaceholder`.
- **DEMAND-86** The fallback is a bar-sized button with the widget's stock icon (`PreferencesModel.icon`) and the tooltip "<name> is inactive. Click to open it." (or "... Click to set it up." when nothing can be activated). A click does what a click on the widget would: presses its own button even while hidden (the Omarchy update widget runs `omarchy-update`), else calls its `toggle()` or `open()`, else opens Preferences. The widget counts as empty when it has no item, or its item is invisible, fully transparent or zero-sized.

## Activity reveal

When an On demand widget has activity it appears in its zone for `powerbarManagedRevealSeconds` (default 2.5, clamped 1 to 60), then collapses without leaving a gap.

- **DEMAND-5** Activity is a change of `powerbarActivityRevision`, `powerbarIcon`, `powerbarValue`, `icon`, `iconText`, `text`, `displayValue` or `value` (string, number or boolean) on the widget's root or one of its bar buttons, or an emitted `powerbarActivity()` signal. The first values after a widget loads set the baseline and are not activity. Code: `ManagedModel.snapshot()`, ActivityObserver.qml.
- **DEMAND-6** Visibility, geometry, opacity, width and theme colour changes are not activity. A `powerbarActivity()` signal counts even when the icon or value ends up the same.
- **DEMAND-7** A repeated identical value is not activity; a changed icon, text or number is.
- **DEMAND-8** Each qualifying event sets the deadline to now plus the reveal duration, so a later event extends it from that moment; events never queue. A widget that changes more often than the duration stays out.
- **DEMAND-9** A revealed widget keeps its configured place among the zone's widgets; activity never reorders the zone.
- **DEMAND-10** Moving a widget, changing the layout, theme or size, opening a drawer, shell start and widget load are not activity (events during a layout rebuild are dropped).
- **DEMAND-11** At the deadline the widget collapses, unless the pointer is on it or a panel of it is open; it then stays until that ends. Drawer visibility does not extend the deadline.
- **DEMAND-12** For a group whose own visibility is On demand, activity in any member reveals the group icon in its zone for the same duration (group deadline `group:<id>`); the member itself is never on the bar. Code: `Bar.reportActivity()`.
- **DEMAND-13** The clock (`omarchy.clock`) never makes an autohidden bar slide out (DEMAND-14); as an On demand widget it still reveals itself. Code: `ManagedModel.quietActivity()`.

## Autohide activity peek

- **DEMAND-14** On an autohidden bar (`powerbarAutoHide`), a widget's activity slides the bar out for the reveal duration and highlights the widget as if hovered: just that zone's island on Islands, the whole bar on Flat and Floating. A group member highlights its group icon, in the group's zone. It needs `powerbarAutoHideActivity` (default true; Bar > Behavior "Show on widget activity") and does not happen for a widget with `powerbarActivityPeek: false` or for the clock. With the bar switched off (`bar-off`) nothing slides out. Code: `Bar.autoHidePeek()`, `ManagedModel.peeksOnActivity()`.
- **DEMAND-15** No peek for 6 s after the shell starts and for 6 s after each bar config change, so widgets loading their first values do not slide the bar out.
- **DEMAND-16** Further activity while a peek runs restarts the peek timer; on Islands several zones can peek together, and all slide back when the timer ends.

## Zone drawer: opening and closing by pointer

In the default drawer mode a zone's On demand widgets (and widgets folded off the bar for lack of room, listed first) open in a drawer beside the bar.

- **DEMAND-17** Pointing at any visible widget of a zone, or at its dots or drawer button, opens that zone's drawer once the pointer has rested there 90 ms (moving to another of the zone's widgets restarts the wait), so sweeping along the bar opens nothing; the zone's own drawer, already open, is held at once. This applies when the zone has On demand or folded widgets; nothing opens for a zone without them. The drawer holds the zone's On demand widgets in order, including ones currently under an activity reveal. Hover does not take keyboard focus. Code: ManagedDrawer.qml sourceEnter, zoneIntent.
- **DEMAND-18** Always hidden widgets are not in the drawer (DEMAND-3). A zone with On demand widgets but no widget on the bar shows a bar-sized 󰇘 button (tooltip "Left drawer", "Center drawer" or "Right drawer") in the middle of the zone; hovering or pressing it opens the drawer. Pressing the dots of a zone with folded widgets opens it without keyboard focus.
- **DEMAND-19** While the pointer is on the source (a zone widget or the dots) or on the drawer, no close timer runs. Leaving the source before ever entering the drawer starts a close timer of `powerbarManagedEntryGraceSeconds` (default 1 s, clamped 1 to 15); coming back to the source or entering the drawer cancels it.
- **DEMAND-20** Entering the drawer cancels pending dismissal; the drawer is then "entered" until it closes.

- **DEMAND-89** A drawer opened by hovering (not pinned by a click or opened from the keyboard) closes as soon as the pointer has rested 100 ms on another stop along the bar instead of waiting out the grace: for a group's drawer, any stop but its icon; for a zone's drawer, a widget in another zone. So its icon's open highlight goes with it, and the next widget's highlight and tooltip never share the bar with the old drawer (the tooltip is placed with no drawer to avoid). A pointer only passing a neighbour on its way into a wide menu (under 100 ms) does not count, nor does anything while one of its widgets has a panel open or a drag runs. Code: ManagedModel.js closesForStop(), ManagedDrawer.qml pointerOnStop/stepAway.
- **DEMAND-21** Once the drawer has been entered, leaving both source and drawer starts `powerbarManagedExitGraceSeconds` (default 1 s, clamped 1 to 15). Re-entering cancels it and the next leave restarts it from the full time; the timer is one-shot and never stacks. Expiry closes the drawer. Code: `ManagedModel.dismissDelay()` (0 means no timer runs).
- **DEMAND-22** No close timer runs while the pointer is on the source or drawer, a keyboard drawer is held, a widget panel is open from it, or a drag is moving.
- **DEMAND-23** The three timings are shell.json keys only (`powerbarManagedRevealSeconds` 2.5, `powerbarManagedEntryGraceSeconds` 1, `powerbarManagedExitGraceSeconds` 1); Preferences neither shows nor writes them. A missing or non-number value gives the default.
- **DEMAND-24** Pointing at another zone with On demand widgets switches the drawer to that zone in place (a fresh open animation, no close in between); the previous zone's timers are dropped.
- **DEMAND-25** Escape closes a drawer. A click outside closes only a drawer opened for the keyboard or pinned by a click (hover drawers take no clicks and no focus grab). After a close that was not a timeout, the same zone does not reopen until the pointer has left it and come back.
- **DEMAND-26** One drawer is open across the bar at a time; opening one closes any other, on any monitor.
- **DEMAND-27** Hiding the bar, opening Preferences, changing the bar edge, switching the on-demand display and editing groups (unless a drop keeps it open) close the drawer at once. Pressing a bar widget closes the drawer first, then performs the press. A pointer drag ends keyboard use of the drawer.
- **DEMAND-87** Default on-demand display: `powerbarOnDemand` is `"drawer"`; only the exact value `"inline"` selects inline expansion. Code: `BarModel.options().onDemand`.
- **DEMAND-88** Drawers open with a 160 ms ease-out from 96 % scale and close in 110 ms; with animations off (`powerbarAnimations: false`) they appear and vanish at once.
- **DEMAND-91** The opening motion starts on the second frame after the open, once the drawer's rows are laid out and painted, so its first painted frame is the motion's start. Code: ManagedDrawer.qml revealStart.

## Drawer geometry and appearance

- **DEMAND-28** A drawer is always drawn as an island, whatever the bar style: island border and rounding (at most half the bar's thickness), the extended surface colour and effects, bar-scaled widgets, and it floats one bar gap from the bar (a Flat bar adds the gap itself). It is an overlay: windows do not move and no space is reserved. Code: ManagedDrawer.qml:91-92.
- **DEMAND-29** It opens toward the desktop: below a top bar, above a bottom bar, right of a left bar, left of a right bar. On a side bar it is vertical.
- **DEMAND-30** A zone drawer has no source icon, so it lines up with the island's outer end: the island's start for Left, its end for Right, centred for Center. Without islands the "island" is the screen width minus one bar gap each side.
- **DEMAND-31** Its length fits its contents but at most the screen axis minus two bar gaps; beyond that it scrolls along its axis, with a scroll bar only while it overflows. It stays on its source monitor.
- **DEMAND-32** A closed drawer takes no pointer input: only the open (and not stepped-aside) drawer rectangle is in the bar window's input region.
- **DEMAND-68** A strip drawer with a source icon (a group's, groups.md GROUP-34) is centred on the icon's cell, kept one bar gap from both screen edges, and an end within half a highlight (16 px on a 38 px bar) of the zone island's end snaps onto it. Code: `ManagedModel.placeStrip()`.
- **DEMAND-70** Strips and menus never come closer than one bar gap to a screen edge. Menu width, rows and placement: groups.md GROUP-96 to GROUP-98.

## Inline expansion

In inline mode a zone's On demand widgets wait behind its dots (shared with folded widgets; a count badge shows if `powerbarDotsBadge`, default true) and expand in place as a zone-fit moment: neighbours yield (layout-zones.md). Hovering a visible widget opens nothing. The keyboard (`managed <zone>`) and the fallback below always use the drawer.

- **DEMAND-36** The pointer must rest on the dots for 90 ms before a zone is asked for; leaving sooner (a swipe) asks for nothing.
- **DEMAND-37** The request is measured against every other moment running now. If the zone's hidden widgets fit, it expands; if not, nothing expands and the zone's drawer opens instead (as by hover, without keyboard focus; its source is the dots, not a widget).
- **DEMAND-38** When the request changes while a zone is expanded, the open zone collapses at once and the next opens only after a settle time of 170 ms (0 with animations off), so two zones never animate together. Opening a zone other than the centre first releases a held centre reveal and waits the same settle time. The keyboard skips the settle (KEYS-12): its moves are intent, so the zone it leaves collapses while the next expands.
- **DEMAND-39** Pressing the dots skips the 90 ms intent (the settle time still applies); a zone that cannot fit opens its drawer.
- **DEMAND-40** While a zone is expanded its dots are gone (they show only while something waits behind them), so nothing opens a drawer over it. Pointing at a widget of another zone collapses the expanded one at once.
- **DEMAND-90** When an expansion makes widgets yield that were not yielding already, its widgets grow after an 80 ms pause (the neighbours yield first), and the dots they replace keep their cell for the same 80 ms before shrinking (120 ms), so the island's end only moves outward. When nothing has to yield there is no pause: widgets grow and dots shrink together from the first frame. The fit that decides is measured before the zone is shown. With animations off both are instant. Code: Bar.qml inlinePlan, inlineGiveWay, FoldHandle giveWayMs; slot motionDelay.
- **DEMAND-43** An expansion stays while the pointer is on its dots or any widget of the zone, a drag is in the zone, the keyboard mode holds the zone, a group drawer is open, or a panel is open from the zone. When all of that ends it collapses after `powerbarManagedExitGraceSeconds` (default 1 s).
- **DEMAND-44** Switching the on-demand display collapses the expansion and closes any drawer at once. Hiding the bar collapses it at once. Opening a zone drawer (keyboard, IPC, fallback) collapses it.

## Keyboard drawer entry

- **DEMAND-46** `omarchy-shell powerbar managed <left|center|right>` opens that zone's drawer on the focused monitor, for the keyboard: the drawer takes focus and no member is selected yet. Nothing happens for a zone with no On demand widgets (integration.md INTEG-49).
- **DEMAND-47** Tab, Right and Down move to the next member; Shift+Tab, Left and Up to the previous. The first press shows the cursor (on the first member for next, the last for previous); later presses wrap around.
- **DEMAND-48** In a drawer opened for the keyboard (`managed <zone>`), the first Enter or Space only shows the cursor on the first member; with the cursor showing, Enter or Space presses the member under it. Escape closes the drawer. A drawer opened from the bar's keyboard cursor: keyboard.md KEYS-10, KEYS-20. Code: ManagedModel.js pressAction()
- **DEMAND-49** Hovering a member highlights it without moving the keyboard cursor.
- **DEMAND-50** A keyboard drawer has no close timer; it stays until Escape, an outside click, or a close from the bar.

## Member panels from a drawer

- **DEMAND-51** A widget panel opened from a drawer member (menu or popout) places at the bar's edge as on the bar; the drawer fades out (110 ms) and takes no input while it is open.
- **DEMAND-52** When the last member panel closes, a pointer-opened drawer closes; a keyboard drawer returns once no panel at all is open, with its cursor on the same member.
- **DEMAND-53** A 150 ms grace after a panel closes lets one member's panel hand over to another's without the drawer returning and leaving.

## Dragging

Drops into, out of and between drawers and onto dots: drag-edit.md (DRAG-16, DRAG-24, DRAG-25, DRAG-28, DRAG-29, DRAG-51).

- **DEMAND-58** A drag that starts on a drawer row is driven by that row. While it runs the drawer keeps presenting and keeps its rows, whatever closes it or changes its members; when it ends the drawer reconciles with its real state (open or closing). Code: ManagedDrawer.qml `dragMount`.

## Identity and session state

- **DEMAND-75** Each layout entry gets a stable `powerbarInstance` (`pw-<base-36 time>-<random>`) once; a duplicate gets a new one. It is saved and survives moves.
- **DEMAND-76** Activity deadlines are kept per `powerbarInstance` in memory only, so an entry's reveal follows it across monitors and layout changes and is lost on restart.
- **DEMAND-80** Whether a drawer is open, its zone, cursor, keyboard mode and every hover timer are session state: nothing is written to shell.json or powerbar.toml.
- **DEMAND-81** What is saved is the user's choices: zone, place and visibility per entry, and the optional timing keys above.

## Retired IDs

DEMAND-33, 34, 35, 69 moved to groups.md (GROUP-96 to GROUP-98). DEMAND-54, 55, 56, 57, 59, 71, 72 moved to drag-edit.md. DEMAND-41, 42, 45, 60, 61, 62, 63, 64, 65, 66, 67, 73, 74, 77, 78, 79 were merged into the entries above (DEMAND-5, 6, 19, 21, 37, 38, 44, 46, 58, 82) or removed because no code supports them.

## Doc drift

| File | Claim | Code |
| --- | --- | --- |
| README.md ("Managed drawers and activity") | After leaving the zone "you have 5 seconds to enter the drawer; after leaving the drawer, it closes after 3 seconds" | 1 s and 1 s (Bar.qml:382-383; `ManagedModel.dismissDelay()`) |
| README.md (same section) | "General's Managed widgets sliders configure activity, entry, and exit durations (10/5/3 seconds)" | No such sliders; defaults 2.5 / 1 / 1 s, shell.json keys only (Bar.qml:376-383, comment "Preferences no longer offers it") |
| docs/design/managed-widgets.md:20, 136 | New custom widgets default to Managed; system widgets "Proposed" shown | Every widget without a saved visibility is shown (ManagedModel.js:13-19) |
| docs/design/managed-widgets.md:61, 66, 68, 132-133 | 5-second entry and exit grace | 1 s each (Bar.qml:382-383) |
| docs/design/managed-widgets.md:142 | Sliders persist, defaults 10/5/3 | Not offered; 2.5 / 1 / 1 (Bar.qml:381-383) |
| docs/design/managed-widgets.md:72 | Escape, outside click or host dismissal closes the drawer | Outside click closes only keyboard or pinned drawers (Bar.qml:3536-3540) |
| docs/design/managed-widgets.md:82 | Drawer follows a continuous, transparent or Islands bar | Always island-styled (ManagedDrawer.qml:91-92) |

## Open questions

- None open.
