# Managed widgets

> Design notes. The behavior of record is
> [on-demand-drawers.md](../behavior/on-demand-drawers.md).

Status: implemented. Items marked **Proposed** below were adopted as implementation defaults. The implementation notes at the end describe concrete compatibility boundaries.

## Placement and visibility

Placement and visibility remain independent. Every widget has one zone (Left, Center, Right) and one visibility mode (Always shown, Managed, Always hidden).

| Mode | Main bar | Managed drawer |
| --- | --- | --- |
| Always shown | Remains present under the existing Always shown rules | Excluded |
| Managed | Hidden at rest; temporarily revealed by activity | Included |
| Always hidden | Never automatically revealed | Excluded |

Managed widgets remain operational while hidden so Powerbar can observe their activity. Hiding must not stop their services or reset state.

New custom widgets default to Managed. **Proposed:** system widgets default to Always shown. Explicit user choices always win, including a system widget moved to Managed or a custom widget moved to Always shown. Changing zones alone does not reset visibility.

For existing entries, preserve an explicit `powerbarVisibility`. Apply the system/custom default only when that field is absent. This changes today's missing-value behavior, which treats every widget as Managed. Preserve order, zone, and all widget settings during migration. Establish defaults only after registry discovery is complete; a temporarily missing widget must not be misclassified. Use host-provided first-party metadata, not an `omarchy.*` name test. A user-owned clone counts as custom.

## Activity reveal

A qualifying event reveals its managed widget in its assigned main-bar zone for **2.5 seconds**.

- Keep its configured order among the zone's widgets; activity does not reorder items.
- **Proposed:** another qualifying event restarts the deadline at the latest event plus the configured duration. Repeated events do not enqueue appearances.
- An unchanged active state does not repeatedly restart the timer.
- At expiry, collapse the main-bar slot without leaving a gap.
- **Proposed:** do not remove a widget beneath the pointer or while its menu/popout is in use. If its deadline has elapsed, collapse it once the interaction ends.
- Starting the shell, loading a widget, changing theme/size, opening the drawer, or moving a widget does not itself count as activity. First observations establish a baseline rather than producing startup flashes.
- Moving to Always hidden cancels the reveal immediately. Moving to Always shown ends the timer and makes the widget persistent. Moving zones preserves an active reveal's remaining time.

### What counts as activity

Confirmed trigger policy: **widget events, icon changes, and displayed-value changes**.

- An explicit activity event qualifies even if its resulting icon/value matches the previous one.
- A changed icon or displayed value qualifies, including a changing numeric reading, label, count, or status. Compare the displayed value, not an underlying number whose rounding leaves the display unchanged.
- Repeated identical values do not qualify. Establish the initial icon/value as a baseline without producing a startup reveal.
- Theme color, geometry, font size, hover appearance, and decorative animation frames do not qualify. A semantic icon change does.
- Each qualifying change restarts the reveal deadline. Consequently a widget changing more often than the configured duration can remain continuously visible; this follows the chosen policy.

**Detection must be event-driven where possible.** Subscribe to widget events and QML property-change signals for the icon and displayed value. Do not add a periodic Powerbar scan, screenshot comparison, or timer that polls widget properties. Reveal/dismissal timers are one-shot interaction timers, not polling.

The installed widget base API has no universal activity signal or standard root-level icon/value properties. Implementation therefore needs:

1. An explicit activity signal or revision, plus observable icon/value properties, as the preferred widget contract.
2. Adapters for existing widgets that connect their actual events and presentation-property notifications to that contract.
3. For widgets lacking usable signals or exposed presentation properties, continued access through the managed drawer. Do not claim automatic reveal support or silently add a polling fallback; add a signal-based adapter where feasible.
4. Isolation from Powerbar's own visibility/layout changes so hiding, revealing, or reparenting a widget never generates another activity event.

This policy adds no Powerbar polling. It does not replace polling already owned by an existing widget or its external data service. Reuse their notifications instead of starting duplicate data fetches.

## Hover drawer

Hovering a zone opens a small floating island containing **that zone's managed widgets**, including those currently under an activity reveal. Always hidden widgets are excluded.

**Proposed timer interpretation:** the drawer stays open while the pointer is on either the source zone or the drawer. The five-second entry grace begins when the pointer leaves the source zone, allowing it to cross the gap. It does not close underneath a pointer still hovering the source zone.

| Event | Result |
| --- | --- |
| Enter a zone containing managed widgets | Open its drawer immediately; cancel any dismissal timer |
| Leave the source zone before entering the drawer | Start a **5-second entry grace** |
| Enter the drawer | Cancel pending dismissal; keep it open |
| Leave the drawer | Start a **5-second exit grace** |
| Re-enter the drawer or source zone before expiry | Cancel pending dismissal |
| Grace expires with pointer outside both surfaces | Close the drawer |
| Enter another zone containing managed widgets | **Proposed:** switch directly to that zone's drawer; no stacked drawers |
| Escape, outside click, or host dismissal | Close and release focus and temporary holds |

Activity and drawer timers are independent. Drawer visibility does not extend activity deadlines. A widget can finish its main-bar reveal while remaining available in the open drawer.

**Proposed:** an active widget menu/popout holds its source drawer open until that interaction ends, then normal exit grace applies. Clicking a managed widget must perform the same action as clicking it in the main bar.

**Proposed empty-zone affordance:** a zone containing only hidden managed widgets retains a small, themed drawer handle so it is discoverable and hoverable. The handle is bar chrome, not a revealed managed widget. Zones with no managed widgets do not open an empty drawer.

## Geometry and appearance

The managed drawer is an overlay: opening it does not reserve desktop space or move application windows. It uses the normal bar background, island border settings, corner rounding, and proportional widget scale. It works whether the main bar is continuous, transparent, or in Islands mode.

| Main bar edge | Drawer position | Drawer orientation |
| --- | --- | --- |
| Top | Below its source zone | Horizontal |
| Bottom | **Proposed:** above its source zone, toward the desktop | Horizontal |
| Left | To the right of its source zone | Vertical, parallel to the bar |
| Right | To the left of its source zone | Vertical, parallel to the bar |

Align to the hovered zone and keep the entire drawer on that monitor. Fit to its contents up to the monitor's available extent; overflow scrolls along the drawer's orientation. Empty areas do not create full-screen pointer interception. The entry grace makes a transparent gap safe to cross.

**Proposed:** show one managed drawer at a time across monitors. Activity state is shared for the same configured widget, while hover ownership and positioning belong to the source monitor. Unplugging that monitor closes its drawer and clears pending timers.

## Timing

Drawer timing is fixed rather than offered in Preferences, where three
separate delays proved hard to reason about:

| Timing | Value | Advanced `shell.json` key (range) |
| --- | --- | --- |
| Activity reveal on the bar, and an autohidden bar's activity peek | 2.5 s | `powerbarManagedRevealSeconds` (1–60) |
| Time to reach the drawer after leaving the zone | 1 s | `powerbarManagedEntryGraceSeconds` (1–15) |
| Drawer stays open after the pointer leaves it | 1 s | `powerbarManagedExitGraceSeconds` (1–15) |

The keys still override the defaults when set by hand; Preferences neither
shows nor writes them.

## Keyboard and interaction

- Provide a focusable drawer handle and a keyboard invocation for each zone; hover cannot be the only way to reach managed widgets.
- Hover opening does not steal keyboard focus from the current application.
- Keyboard opening focuses the drawer. Tab/Shift+Tab traverse widgets; arrows follow drawer orientation; Enter/Space activate; Escape closes and returns focus where appropriate.
- Pointer dismissal timers are suspended during keyboard interaction in the drawer.
- Opening preferences dismisses the drawer. Hiding the bar dismisses it and prevents invisible hover targets.
- Layout moves, plugin removal, monitor changes, and bar rotation reconcile the drawer without leaving stale anchors, invisible keyboard grabs, or orphaned timers.

## Implementation constraints

- Do not unload a managed widget merely because its main-bar slot is hidden.
- Do not instantiate an additional polling/service/IPC-owning widget merely to display it in the drawer. Main-bar and drawer representations must share the same logical state and actions. Investigate safe presentation reuse/proxies with the existing host before implementation.
- Distinguish widget-native availability from Powerbar's visibility policy.
- Timers and explicit mode choices belong to individual layout entries, including duplicate plugin instances. Do not key all state solely by plugin ID.
- Temporary visibility and hover state are session state; they must not generate `shell.json` writes. Save only user preferences and explicit placement/mode choices.
- No changes to packaged Omarchy files are required or permitted.

## Acceptance scenarios

1. With no activity, a managed widget occupies no main-bar space but can be reached through its zone's drawer.
2. An event, icon change, or displayed-value change at t=0 reveals it; without interaction or further changes it disappears at t=10. A qualifying change at t=7 moves expiry to t=17. Identical values do not extend it; continuously changing displayed values can keep it revealed.
3. Shell startup establishes activity baselines without briefly revealing every managed widget.
4. Leaving the zone then entering its drawer 4 seconds later keeps it open. Never entering closes it after the 5-second grace.
5. Leaving the drawer starts a fresh 5-second grace; re-entry cancels it. Hovering continuously never times out.
6. Hovering Center while Left's drawer is open switches to Center without leaving Left's drawer or timers behind.
7. An open widget menu remains usable beyond both deadlines; dismissal restores the correct hidden/revealed state.
8. A third-party widget defaults to Managed, a system widget follows its default, and explicit user choices survive restart and discovery changes.
9. Always hidden widgets never flash or appear in the drawer. Always shown widgets never acquire an activity expiry.
10. All four bar edges place drawers toward the desktop; vertical drawers remain parallel. Long drawers scroll without crossing monitor bounds.
11. Keyboard users can open, navigate, activate, and close each drawer without pointer hovering.
12. Disabling/removing a plugin, removing a monitor, or hiding the bar leaves no drawer, dangling interaction hold, or duplicate service/IPC registration.
13. Theme changes and proportional resizing preserve alignment and do not generate activity reveals.
14. Activity-duration and hover-delay sliders persist, and defaults/reset produce 10/5/3 seconds.

15. Signal-driven icon/value updates reveal managed widgets without any periodic Powerbar observation timer; widgets lacking usable signals remain reachable in the drawer.

## Implementation notes

- Hover activation follows visible widget bounds, not empty bar space. Managed-only zones display a small handle whose own bounds are hoverable.
- The existing bar window keeps a stable surface sized for the bar and drawer, with a fixed workspace reservation. The closed drawer region is transparent and excluded from the input mask. Opening changes visibility and input coverage without resizing the whole bar. Hosted widget popup anchors stay in the same window, with no duplicate widget instantiation.
- Main-bar activation captures the clicked target, closes the drawer, then dispatches activation on the next event-loop turn so widget restoration precedes popup creation.
- The drawer owns a managed widget's actual presentation and activation indicator while open. Its main-bar slot stays hidden, including during activity or panel activation. Timed dismissal never suppresses subsequent hover entry.
- The one-time `powerbarInstance` identity migration preserves existing placement/settings and distinguishes duplicate entries. Activity deadlines are shared per identity across monitors and are never persisted.
- Activity adapters observe the standard public presentation properties on widget roots and registered bar buttons. Arbitrary private text trees are not scanned. Unsupported plugins stay reachable in the drawer and can opt in using the documented activity contract.
