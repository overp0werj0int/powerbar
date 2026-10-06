# On-demand drawers

Managed widgets hide at rest and reveal temporarily on activity or on-demand interaction. The drawer surface offers them from the pointer and keyboard, and inline expansion (on supported bar edges) shows managed widgets in-place when the pointer rests on zone dots.

**Sources:** ManagedModel.js, InlineQueue.js, ManagedDrawer.qml, ActivityObserver.qml, RetainedList.qml, RetainedStore.qml, TargetOwnerObserver.qml, Bar.qml (grep: managed, activity, reveal, inline, drawer), tests/managed.test.cjs, tests/inline-queue.test.cjs, tests/fixtures/ManagedWidget.qml, docs/managed-widgets.md, README.md section "Managed drawers and activity".

## Managed widget modes

Widgets in the main bar can be Always shown, Managed (hidden until revealed), or Always hidden. Managed widgets reserve no main-bar space until activity or interaction opens them.

- **DEMAND-1** Widgets with `powerbarVisibility` = `"shown"`, `"managed"`, or `"hidden"` use that explicit choice. Without it, undiscovered widgets remain `"pending"` until the registry provides metadata. First-party system widgets default to `"shown"`; third-party custom widgets default to `"managed"`.
- **DEMAND-2** Moving a widget between visibility modes does not reset its zone or other settings.
- **DEMAND-3** Managed widgets remain operational while hidden so Powerbar can observe their activity; hiding must not stop their services or reset state.
- **DEMAND-4** Widgets moving to Always shown end any active reveal timer and remain visible. Widgets moving to Always hidden cancel any active reveal immediately. Moving zones preserves an active reveal's remaining time.

## Activity reveal

When a managed widget emits activity, it appears in its zone on the main bar for a configured duration, then collapses without leaving a gap.

- **DEMAND-5** Activity is detected through widget property-change signals on `powerbarActivityRevision`, `powerbarIcon`, `powerbarValue`, `icon`, `iconText`, `text`, `displayValue`, or `value`, or through an explicit `powerbarActivity()` signal emission. Initial widget state establishes a baseline (does not count as activity).
- **DEMAND-6** Only public presentation values trigger activity: icon, icon text, text, numeric value, or display value changes. Visibility, geometry, opacity, and theme color changes do not count. An explicit `powerbarActivity()` signal qualifies even if the resulting icon/value matches the previous one.
- **DEMAND-7** Repeated identical values do not trigger activity. A changed icon or displayed value qualifies; a changing numeric reading qualifies.
- **DEMAND-8** Activity deadline is `now + managedRevealSeconds` (default 2.5 seconds from shell.json `powerbarManagedRevealSeconds`, 1–60 range). The deadline extends from the most recent activity event: another qualifying event restarts it. Repeated events never queue intervals; the deadline is always measured from the current time, not accumulated.
- **DEMAND-9** A widget's activity does not reorder its zone. It keeps its configured place among the zone's widgets.
- **DEMAND-10** The bar's layout changes (opening the drawer, moving a widget, changing theme/size), shell startup, and widget loading do not themselves count as activity.
- **DEMAND-11** At the reveal deadline, the widget collapses (hides) without leaving a gap. If the pointer is on the widget or its menu/panel is open, dismissal is deferred until the interaction ends.
- **DEMAND-12** For a managed group (all members are Managed), one member's activity reveals the group header in the zone. The group header's activity deadline extends from the most recent member activity.
- **DEMAND-13** Clock-driven widgets (e.g. `omarchy.clock`) never count as activity for an autohidden bar and never cause it to peek.

## Auto-hide bar activity peek

When a managed widget shows activity while the bar is hidden, the bar briefly slides out to show the widget's zone.

- **DEMAND-14** Activity peeks if the widget entry allows it (not opted out via `powerbarActivityPeek: false`) and the widget is not clock-driven. The bar slides out the widget's zone (islands mode) or the whole bar (continuous), highlighting the widget for the activity duration (default 2.5 seconds). A group member's activity highlights the group header in that zone.
- **DEMAND-15** Activity peeks are suppressed for 6 seconds after shell startup and after config change, so the bar does not slide out during initialization.
- **DEMAND-16** If the bar is already sliding out for another reason, activity peeks do not start another.

## Hover drawer

Hovering a zone containing managed widgets (or a zone with a handle when all are hidden) opens a floating drawer at the bar's edge.

- **DEMAND-17** Entering a zone containing managed widgets opens its drawer immediately and cancels any dismissal timer. The drawer contains all managed widgets in that zone, including those currently under an activity reveal.
- **DEMAND-18** Always hidden widgets do not appear in the drawer. A zone with only hidden managed widgets shows a small handle for hover discovery.
- **DEMAND-19** Leaving the zone starts an entry grace (default 1 second, `powerbarManagedEntryGraceSeconds`). Re-entering the zone or the drawer within that grace cancels dismissal.
- **DEMAND-20** Entering the drawer cancels pending dismissal and keeps it open.
- **DEMAND-21** Leaving the drawer starts a 1-second exit grace (default `powerbarManagedExitGraceSeconds`). Re-entering before expiry cancels dismissal. Grace expires with the pointer outside both surfaces and the drawer closes.
- **DEMAND-22** Drawer dismissal is suspended while the pointer is on the source zone, the drawer, or any interaction (drag, keyboard, widget panel) is held.
- **DEMAND-23** The entry grace default is 1 second (`powerbarManagedEntryGraceSeconds`, 1–15 range). The exit grace default is 1 second (`powerbarManagedExitGraceSeconds`, 1–15 range). These are shell.json keys; Preferences does not show them.
- **DEMAND-24** Hovering a different zone directly switches its drawer with no intermediate close; the previous zone's timers are cleared.
- **DEMAND-25** Escape, outside click, or host dismissal closes the drawer and releases any focus and temporary holds.
- **DEMAND-26** Only one drawer is open across the bar at a time.
- **DEMAND-27** Closing the bar, opening Preferences, or changing the bar edge closes the drawer.

## Drawer geometry and appearance

The managed drawer is an overlay; opening it does not move application windows or reserve workspace.

- **DEMAND-28** The drawer uses the bar's background, island border settings, corner rounding, and proportional widget scale; it works in continuous, transparent, or Islands mode.
- **DEMAND-29** The drawer opens toward the desktop: below on top edge, above on bottom, to the right on left, to the left on right. On vertical bars, it runs parallel to the bar.
- **DEMAND-30** A zone drawer's contents are aligned to that zone's island (or a placeholder for inline expansion). For a group drawer (a group menu), the drawer aligns to the group header's cell within the zone.
- **DEMAND-31** The drawer is positioned to fit on the monitor of its source zone. Contents fit to their measured size up to the available extent; overflow scrolls along the drawer orientation. Scrollbars appear as needed (horizontal for island strips, vertical for vertical strips or menus).
- **DEMAND-32** The drawer clips its extended region; the closed drawer area is transparent and click-through.

## Group drawers (menus)

A group with member names (`memberDisplay: "name"` or `"both"`) opens as a vertical menu. Otherwise it opens as a strip (island).

- **DEMAND-33** Menu rows show icons and names; rows without an icon start their name at the icon edge so all names share one left edge. Values (e.g. battery %) are right-aligned. Menu width fits its widest content plus 2 × inset, at least 128 px (4 cells), at most 320 px (longer names elide).
- **DEMAND-34** Menu rows are highlight cells thick (cell height varies with bar size; ~32 px on a 38 px bar) and spaced 1 inset apart (3 px on a 38 px bar).
- **DEMAND-35** Menu rows anchor their first row's start to the group icon's start and flip horizontally when near the screen edge. On vertical bars, the first row's centre is level with the group icon's centre; the last row flips toward the bottom edge if near it.

## Inline expansion (on-demand zones)

On supported bar edges (top and bottom), a zone can expand inline when the pointer rests on its dots. Inline expansion shows managed widgets in the zone's normal position, as if Always shown, while the zone is expanded. When it collapses, the widgets hide again.

- **DEMAND-36** Hovering a zone's dots initiates inline expansion: pointer intent (default 90 ms) must elapse before the zone opens. A swipe across dots opens nothing.
- **DEMAND-37** The zone expands if its hidden widgets fit beside every other moment running now. If they do not fit, the drawer opens instead.
- **DEMAND-38** Switching zones collapses the open zone at once and begins a settle timer (default 170 ms with animations, 0 ms without). The next zone opens only after the timer expires, so two zones never animate together.
- **DEMAND-39** Clicking the dots (no hover intent delay) opens the zone immediately if it fits, or skips to the drawer if it does not.
- **DEMAND-40** While a zone is expanded inline, hovering its dots does not open the drawer (the handle shows but is not hoverable). Clicking the dots closes the expansion (not the drawer).
- **DEMAND-41** The expansion releases center-section reveal holds (used for center activity peek) and waits for the zone's settle timer before proceeding.
- **DEMAND-42** Opening another zone releases the held reveal. Asking for the centre zone keeps its hold.
- **DEMAND-43** The zone stays open while the pointer is on its dots, on the expanded widgets, during a drag, or while keyboard interaction is held there. It collapses after the exit grace (default 1 second) once all interactions end.
- **DEMAND-44** Turning off inline mode (via `powerbarOnDemand` config) collapses the zone immediately.
- **DEMAND-45** Hiding the bar collapses the zone immediately.

## Keyboard drawer entry

Drawers can be opened from the keyboard without pointer hovering.

- **DEMAND-46** Calling `omarchy-shell powerbar managed left` (also `center`, `right`) opens that zone's drawer in keyboard mode. The drawer takes focus, and keyboard shortcuts do not pass through.
- **DEMAND-47** Tab/Shift+Tab or Left/Right/Up/Down arrows navigate widgets. The first navigation activates cursor selection; subsequent presses move the cursor. Entering a drawer without prior navigation readies the cursor but does not select (prevents opening a widget's panel on the first keystroke).
- **DEMAND-48** Enter/Space activates the cursor-selected widget. Escape dismisses the drawer and returns focus to the original context.
- **DEMAND-49** Hovering the drawer does not move the cursor, and reopening from the bar's keyboard cursor does not steal its focus (the cursor stays on the bar).
- **DEMAND-50** Pointer dismissal timers (entry and exit graces) are suspended during keyboard interaction; the drawer stays open until Escape is pressed or focus is lost.

## Widget panels from the drawer

A widget menu or popout opened from a drawer positions at the bar edge and the drawer steps aside.

- **DEMAND-51** A widget panel (group member menu, zone drawer, or third-party popout) opened from a drawer places at the bar's edge, as on the main bar. The drawer fades and takes no further input while the panel is open.
- **DEMAND-52** Once the panel closes, the drawer closes if it was opened by pointer (the panel was the last interaction stop); if opened by keyboard, the drawer returns with cursor selection on the same widget once no panel is open.
- **DEMAND-53** A handover grace (150 ms) allows one member's panel to close and another's to open without the drawer re-entering and leaving.

## Dragging to the managed drawer

Managed widgets can be moved via drag-and-drop into and out of the drawer.

- **DEMAND-54** Dragging a widget into an open managed drawer places it in that zone as Managed, preserving its order among the zone's widgets. Dropping a group icon into the drawer makes the entire group Managed.
- **DEMAND-55** Dragging a widget from the drawer back to the main bar makes it Always shown.
- **DEMAND-56** Dragging from one zone's managed drawer to another zone swaps zones for that widget (via the drawer or inline expansion).
- **DEMAND-57** A zone's dots are a drop target. An icon dragged from one zone's drawer can drop directly onto another zone's dots to move it there, even while the source drawer is open.
- **DEMAND-58** A drag that started on one of the drawer's rows is driven by a handler on that row. While the drag runs, the drawer keeps presenting and keeps its rows, whatever closes it or changes its members; destroying that row would leave the drag without its release.
- **DEMAND-59** During a drag into an open managed drawer, on-demand gaps show dots and the drawer extends its row spacing to show landing positions.

## Drawer dismissal and activity interaction

The drawer manages dismissal delays based on pointer proximity and user interaction.

- **DEMAND-60** Dismissal delay is computed from: if hovering the source zone, pointer (on drawer, or interacting), or holding an interaction, dismiss at once (delay 0). If entered the drawer before leaving it (not the entry grace), use exit grace. If entered the entry grace, use exit grace. Otherwise use entry grace.
- **DEMAND-61** Entry grace (default 1 second, `powerbarManagedEntryGraceSeconds`) starts when the pointer leaves the source zone. Exit grace (default 1 second, `powerbarManagedExitGraceSeconds`) starts when the pointer leaves the drawer. Re-entry resets the timer to the full duration.
- **DEMAND-62** The dismissal timer is a one-shot; reaching its deadline closes the drawer. A fresh hover or entry restarts it. The timer never stacks or queues intervals.

## Activity snapshot and change detection

Powerbar detects activity by comparing widget presentation snapshots.

- **DEMAND-63** A snapshot captures these public properties (if present): `powerbarActivityRevision`, `powerbarIcon`, `powerbarValue`, `icon`, `iconText`, `text`, `displayValue`, `value`. Only string, number, and boolean values are included.
- **DEMAND-64** A property is observed only if it exists on the target. Snapshots ignore undefined or missing properties.
- **DEMAND-65** Changes to visibility, geometry, opacity, or width do not affect the snapshot and do not trigger activity.

## Managed widget modes and visibility model

The mode function determines initial visibility based on whether the widget is discovered and first-party.

- **DEMAND-66** Explicitly configured `powerbarVisibility` values (`"shown"`, `"managed"`, `"hidden"`) always win. Undiscovered widgets (metadata missing) remain in `"pending"` mode until discovered.
- **DEMAND-67** For discovered widgets: first-party system widgets default to `"shown"`. Third-party or user-cloned widgets default to `"managed"`.

## Drawer position calculation

Managed drawer and menu positioning follows the bar's zone alignment and screen constraints.

- **DEMAND-68** Strip positioning (for islands): the strip centers on the source widget's cell, stays at least one bar gap from the screen edges, and snaps its end to the zone island within half a highlight (16 px). For managed drawers (no source widget), strips align to the zone island's outer end (left edge for left zone, right edge for right zone, centre for centre).
- **DEMAND-69** Menu positioning (for named groups): the first row starts where the source icon cell starts and flips horizontally when it would exceed the screen's opposite edge by more than the inset (3 px). On vertical bars, the first row's centre is level with the source's centre; the last row's centre is level with the source's centre when flipped toward the opposite edge.
- **DEMAND-70** Both strips and menus clamp their position to stay a bar gap from the screen edges (minimum spacing).

## Drag source from drawer

A drag initiated within the drawer identifies itself for drop handling.

- **DEMAND-71** A drag from within a managed drawer identifies its zone (`managed:<zone>` surface) or group (`group:<id>` surface).
- **DEMAND-72** During drag preview, the dragged row's handle (if any) is visible and usable.

## Slot retention during drag

The drawer retains widget presentations while a drag is in motion.

- **DEMAND-73** If a drag started on a drawer row, the drawer and its rows persist until the drag ends. Closing the drawer (by timeout or interaction) does not remove rows if `dragMount` is set.
- **DEMAND-74** Once the drag ends and `dragMount` is released, the drawer reconciles its row visibility based on the drawer's current state (open/closed).

## Instance identity and activity sharing

Widgets maintain stable identities so activity deadlines and state persist across configuration changes.

- **DEMAND-75** Each layout entry gets a stable `powerbarInstance` identity (format `pw-<timestamp>-<random>`) assigned once and persisted. Duplicate plugin instances on moves receive different identities.
- **DEMAND-76** Activity deadlines are keyed by `powerbarInstance`, so a widget's reveal state follows its identity across monitor changes and configuration updates. Deadlines are never persisted (session state only).

## Managed drawer opening modes

The drawer can open through hover, keyboard, or drawer-open fallback.

- **DEMAND-77** A zone drawer opens through hover (pointer on dots), keyboard entry (`omarchy-shell powerbar managed <zone>`), or inline fallback (attempting to expand inline when it doesn't fit). All three modes are distinct; clicking the dots (with no hover delay) is inline-fast, not hover entry.
- **DEMAND-78** Hover opening does not acquire keyboard focus. Keyboard opening (or reopening in keyboard mode after a panel) acquires focus.
- **DEMAND-79** When inline expansion determines the zone doesn't fit and opens the drawer instead, the drawer's source is the dot handle, not a widget cell.

## Drawer state and configuration

The drawer tracks internal state separately from user preferences.

- **DEMAND-80** The drawer's open/closed state, zone, group, cursor position, keyboard mode, and hover timers are session state only; they are not persisted to shell.json or powerbar.toml.
- **DEMAND-81** Explicit user choices (placement, visibility mode, zone for each widget) are persisted. Reveal timings and hover-delay configuration keys are set via shell.json `powerbar*Seconds` keys and survive restart but are not written by Preferences.

## Doc drift

| File | Line | Claim | Code says |
| --- | --- | --- | --- |
| README.md | 475–476 | "After leaving the source zone, you have 5 seconds to enter the drawer; after leaving the drawer, it closes after 3 seconds." | `powerbarManagedEntryGraceSeconds` and `powerbarManagedExitGraceSeconds` default to 1 second each (range 1–15 in Bar.qml). Grace periods are computed by `dismissDelay()` in ManagedModel.js and depend on pointer position, not 5/3 seconds. |
| README.md | 481 | "Managed widgets sliders configure activity, entry, and exit durations (10/5/3 seconds)." | Code defaults are 2.5 seconds (activity reveal), 1 second (entry grace), 1 second (exit grace). No Preferences sliders found in Preferences.qml/PreferencesModel.js for these durations; DEMAND-23 confirms the keys are shell.json only, not shown in UI. |

## Open questions

(None: all answered from code.)
