# Rendering performance implementation

30 September 2026. Implements the rendering audit against the existing working
changes; the spacing, highlight, drawer, and drag work present before this task
is preserved. No desktop configuration was edited and no plugin was deployed.

> **1 October 2026:** the Indicators and Tray rows below described Powerbar's
> copies in `widgets/` and `indicators/`. Those copies were never loaded,
> because Omarchy reserves the `omarchy.*` widget ids for its built-ins, so
> they have been removed with their indicator services, test and test stubs.
> The other rows still apply.

## Changes

| Plan area | Implementation |
| --- | --- |
| API and targets | `PluginApiSync` publishes layout, targets and popout independently. Facades keep separate mutable layout copies and ownership checks. Registration resolves one owner, updates that slot, follows genuine reparenting, and cleans up destroyed controls. Placeholders retain global activation routing. |
| Idle chrome | `GeometryObserver` follows geometry, ancestor changes, scrolling and explicit transforms, coalescing notifications with `Qt.callLater`. Preferences no longer uses a stationary frame callback. Badge placement also follows sibling islands; compound target geometry is observed while hovered. |
| Indicators | One retained presentation per configured occurrence, transferred between active/inactive ObjectModels. Orientation updates the same grids. Dictation, Reminder and ScreenRecording share reference-counted producers per kind/settings contract across monitor copies. Refresh is coalesced. Equal active states do not republish order. |
| Widget lifetime | A per-monitor `RetainedStore` owns ModuleSlots independently of their placement. ObjectModels reconcile all six zone/anchor lists. Moves, settings updates and orientation changes preserve existing owners; actual removal/explicit hidden state destroys only removed owners. Registry Loader changes still replace the affected component. |
| Local state | Group and entry indexes replace repeated searches; per-monitor slot lists replace global scans on drag, managed lookup and overlap checks. Activity deadlines update only matching monitor copies. Disabled observers skip snapshots; badge sampling requires an enabled group badge. |
| Preview capture | `CaptureQueue` allows two concurrent readbacks. Requests validate the Preferences opening, screen, owner, record and source. A queued request measures its source again at start. Failed grabs release capacity. Newer requests supersede older results per screen/key. Preferences batches image publications and retains unaffected images. |
| Capture invalidation | Identical reloads request nothing. Entry/settings/order changes request changed keys. Main surface background opacity requires no widget capture. Unknown/global changes, registry reloads, font, size and colors refresh conservatively. Capture remains horizontal, at the existing 2× resolution, with PNG fallback persistence. |
| Tray and editors | Tray classification is one pass with a cached layout ownership check. Tray delegates are retained by QObject identity through pin/drawer transfers and rotation. Layout/Groups rows use retained lists and one stable insertion gap per list. Repeated pointer hits in the same cell do not republish the destination. Layout cell memberships and workspace indexes are computed once per membership change. |
| Images | Versioned wallpaper/thumbnail URLs use Qt's shared image cache. Non-shown layout rows no longer request their invisible wallpaper. |

The existing drag, settle, reveal, focus glide and width-hold durations/easing
are retained. Autohide's six-second edit quiet period is still armed for the
same structural edits, before synchronous retained updates. Presentation changes
caused synchronously by a structural edit establish the existing initialization
behavior; normal settings updates and later activity retain their policy.

## Verified work reductions

The isolated Qt probe uses Powerbar's **current** reconciliation, registration,
ownership and capture functions. Slot/window/source objects are fictional; it
does not instantiate native panels, commands or the live desktop.

| Workload | Result |
| --- | --- |
| 200 within-zone/cross-zone moves of 24 retained slots, with settings updates | 0 existing owners created or destroyed; internal state preserved |
| Add one owner | 1 created, 0 existing owners destroyed |
| Register one target among 24 slots and 12 APIs | 1 slot target evaluation; 0 API layout notifications |
| Target/popout-only updates | 0 layout publications; unrelated target lists unchanged |
| Destroy a control without unregistering | Slot/global target lists and lifetime watches cleaned up |
| Pending target parent becomes known; later transfer to another slot | Correct local membership after the coalesced resolution pass |
| Queued capture, close/obsolete owner, off-bar group, placeholder and vertical bar | Correct source/resolution and callback/save rejection |
| Indicator activity, orientation and two presentation copies | Same presentation objects and 3 shared producers; removal returns producer count to 0 |
| Reminder refresh burst and failed query | One refresh start; failed state cleared |
| Focus geometry at rest, scrolling, translation and reparenting | Zero notifications at rest; changed geometry observed and coalesced |
| Drag insertion gap moves through wrapped rows | Existing row objects/state retained; only gap removal destroys its owner |

These are lifecycle and notification counts, **not measured CPU, GPU or frame-time
speedups**. Qt 6.11.2, arm64, offscreen software rendering was used. The original
array-model probe recreated all 24 delegates on reversal, scanned 24 slots for
one target registration, and published 12 layouts for an unchanged full API
sync. The historical baseline is retained in the audit document.

## Reproduction

```sh
node --test tests/*.test.cjs
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software \
/usr/lib/qt6/bin/qmltestrunner -input tests/qml -o -,txt

# Emission also works where Node child-process spawning is restricted.
node docs/performance/probe.cjs --emit /tmp/powerbar-path-probe
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software \
/usr/lib/qt6/bin/qmltestrunner -input /tmp/powerbar-path-probe -o -,txt

python3 /home/p0werj0int/.agents/skills/omarchy-plugin-test/scripts/validate_plugin.py "$PWD"
omarchy plugin validate "$PWD"
```

The QML suite needs no host stubs now that the indicator test is gone (the
stubs it used were removed with it). This is portable regression evidence, not
live host acceptance.

Final validation: nine JavaScript test files pass, 53 QML checks pass, and the
extracted-path probe reports seven passed checks. Both plugin validators pass;
the portable validator retains its advisory about the existing custom command
shell path. `qmlformat` parses the root, widget, indicator and test QML files;
`git diff --check` passes. Parsing does not certify native host type resolution.

## Startup investigation

The subsequent report of a bar appearing and disappearing was traced to an
existing Omarchy `toggles/bar-off` flag. The shell logs recorded explicit IPC
exits for the observed restarts, no native crash was recorded, and the live
`shell debugBarGeometry` endpoint returned the instantiated Powerbar widgets.
The initial asynchronous flag probe sets `barHidden`, parking the surface past
its screen edge; autohide hover does not override that explicit hidden state.
On this installed Omarchy version, clearing it uses `omarchy toggle bar off`,
independently of the autohide setting. The wrapper passes its argument directly
to the generic flag command: `on` creates `bar-off`, while `off` removes it.
After user approval, the flag was cleared and the same shell process remained
running; no restart was needed. Compositor visual verification remains unrun.

The live startup logs also exposed three errors introduced during this refactor:
a removed badge label, an out-of-scope row reference in the Inspector wallpaper
binding, and a layout cell-cache consumer evaluating before the cache arrived.
The label and Inspector binding are restored, and the consumer tolerates the
initial unavailable cache while remaining reactive to its publication.

`tests/startup-probe.cjs` extracts the actual badge component and editor bindings
into an isolated Qt fixture. The missing label and Inspector reference failed
before correction; all five fixture checks now pass, including count overflow,
urgent styling and initialization/cache publication. The existing 53 QML checks
and both plugin validators also pass. This fixture does not instantiate a native
PanelWindow or certify the live visuals. No explicit shell restart was performed
for the code repair.

```sh
node tests/startup-probe.cjs /tmp/powerbar-startup-probe
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software \
/usr/lib/qt6/bin/qmltestrunner -input /tmp/powerbar-startup-probe -o -,txt
```

## Measured pass: 3 October 2026

The gates below asked for measurements before further changes. This pass
measured the whole bar instead of extracted functions. Every change keeps
behaviour identical. Final geometry, drawer mounts and saved layouts match
master exactly in all thirteen scenarios.

### Harness

`docs/performance/bench/` runs the real `Bar.qml`, `Preferences.qml` and
Omarchy's own `Commons` and `Ui` modules in an offscreen Quickshell.

- **Copy.** It builds a copy of the plugin in which layer-shell windows become
  plain windows. It loads the user's layout from `shell.json`, and stand-in
  widgets (glyphs, text, a clock, compound workspaces) play the plugins.
- **Isolation.** Nothing reaches the live shell: there is no Wayland or
  Hyprland connection, the image cache is private, and shell commands are
  stubbed.
- **Scenarios.** It scripts startup, idle, drop commits, a pointer drag sweep,
  a widget changing value and opacity, settings changes, drawer open and close,
  activity reveals, highlight flashes, and three pointer drag-and-drops (across
  zones, into a group drawer, out of it). Preferences runs as Layout-editor
  drops.
- **Output.** Each run logs timings, the process's CPU time per phase, and a
  geometry and layout dump.
- **Profiling.** `prof.sh` records a QML profiler trace of any scenario (`qs
  --debug`), and `analyze.py` ranks self time per binding and function.

```sh
docs/performance/bench/bench.py "$PWD" current 3          # medians of 3 runs
docs/performance/bench/prof.sh "$PWD" churn 1 /tmp/churn.qtd
docs/performance/bench/analyze.py /tmp/churn.qtd "$XDG_RUNTIME_DIR/powerbar-bench/prof-app.log" 30
```

### Findings and changes

| Finding (profiler evidence) | Change |
| --- | --- |
| Every slot's `cursorShape` scanned all click targets with `mapToItem`, and re-ran whenever any target's visibility or opacity changed. It accounted for 90% of QML time while one widget updated, and 141 ms of startup. | Hit-test only while the pointer is over the slot or it is pressed (a `HoverHandler` beside it). Elsewhere the shape is never shown, and a disabled area shows no cursor at all. |
| `GeometryObserver` and `TargetOwnerObserver` watched their ancestor chains through a Repeater of `Connections`. Any reparenting rebuilt every delegate: 290 ms of startup, and each highlight's observer was rebuilt on every hover. | Connect the chain's signals directly, connecting only the items that join it and disconnecting on destruction. Notifications are the same, and a destroyed item drops its own connections. |
| A Repeater over QObjects makes Qt expose every property of every object as a role. That cost 12.7 ms against 0.04 ms for strings in an isolated test, and dominated drawer opening and activity-observer creation. | The drawer's mounts, each slot's activity observers and the compound thumb's observers use one identity token per object (`String(object)`). Each delegate reads its object once from a plain table that never notifies, so delegates rebuild exactly when they did and keep their object for life. |
| `RenderModel.equal` serialised both sides even when they shared every member. | Same keys in the same order with identical values return early. Otherwise it serialises as before (key order still counts; covered in `tests/render.test.cjs`). |
| Preferences diffed and deep-copied the config on every change while closed. | Return early while closed: opening already takes its own baseline. |

Kept as they are:
- **Layout copies.** `PluginApiSync` gives each plugin facade its own copy of
  the layout (2–4 ms per drop), and that isolation is deliberate.
- **The drawer's input region.** About 6 ms of an offscreen open, but required.
- **Freezing Preferences' config while closed.** It saved 5 ms per settings
  change, but read stale config against live groups and made the first open
  slower.

### Results

Medians of three offscreen runs (Qt 6.11.2, software renderer, arm64) for the
user's layout: 35 entries, 79 click targets, two groups. CPU is the
Quickshell process's time during the scenario.

| Scenario | Before | After |
| --- | --- | --- |
| Startup, bar created | 643 ms | 142 ms |
| Startup CPU | 770 ms | 250 ms |
| Drop commit, synchronous | 33 ms | 10–20 ms |
| A widget changing value and opacity, 200 times | 2680 ms CPU | 490 ms CPU |
| Group drawer open | 105 ms | 7 ms |
| Drawer open and close, 40 times | 2330 ms CPU | 380 ms CPU |
| Highlight flashes, 120 times | 540 ms CPU | 120 ms CPU |
| Three pointer drag-and-drops, animated | 740 ms CPU | 400 ms CPU |
| Pointer move during a drag | 0.30 ms | 0.33 ms (unchanged) |

Run-to-run noise on a busy desktop is about ±30%, so the commit and
Preferences timings are ranges. The model tests (111), QML tests (50), startup
probe (5) and both plugin validators pass.

### Drops on the live shell: config writes queue until the bar settles

A live drop froze the bar for a visible moment. Timed in the running shell, and
profiled by relaunching it with `quickshell --debug` and `qmlprofiler`,
Powerbar's own work on a drop was 1–4 ms. Omarchy's `mutateShellConfig` was
not: it re-registers every bar widget, and each registration runs
`syncPluginApis`, which deep-copies the bar config for every plugin facade.
With about 40 plugins that came to 42 syncs and 1,513 copies, about 370 ms. It
happens twice per write, once for the write and again when Omarchy reloads the
file it wrote. The bar stayed on its old layout for about 400 ms, then hitched
again.

Powerbar now shows every config edit at once and writes it once the bar has
settled (`Bar.writeConfig`). Each edit is applied to the bar's own copy of its
config, the way Omarchy applies a bar's edit (to a copy of the bar subtree),
and queued. The queue is written as a single config change after 300 ms with
no drag, settle glide or bar move.
- **Plain values:** edits capture plain values when they are made. Slot state
  has moved on by the time they run again on the host's config.
- **Host updates:** a config arriving from the host while edits wait is shown
  with the queued edits on top.
- **Failure:** a failed write restores the host's config, and Preferences
  reports it.
- **Exception:** `ensureInstanceIds` still writes directly, because its edit
  invents identifiers.

Preferences also reads widget metadata from a cache refreshed once per
registry burst. It used to rebuild its pages for each of the 40 registrations.

The live shell, timing one drop and its restore:

| | Before | After |
| --- | --- | --- |
| New layout on screen | about 400 ms, frozen on the old layout | 8 ms |
| Shell blocked by the config sync | about 770 ms over two passes | one hitch of about 380 ms, 300 ms after the drop, on a bar already showing the result |

The remaining hitch is Omarchy's per-registration `syncPluginApis`. Batching
those registrations into one sync per config change, upstream, would remove most
of it.

### A drop no longer makes the island swell (3 October 2026, found live)

After a drop the bar wobbled: the island grew by a few pixels and shrank back.
The commit clears the drag source before the released icon has settled, and the
drop gap's width came from the source (`dragLandingExtent`), so it fell back to
the generic gap (the image plus a gutter, 41 px for a 25 px glyph). The settling
slot keeps the gap's width (`settleExtraWidth`), so it grew towards 41 px, then
eased back to 25 px once the settle ended. The settle now keeps the landing size
(`barDragSettleLanding`). Recorded per frame offscreen (an emulated Omarchy
write and reload included): within a zone, across zones and into the centre,
every island keeps its exact geometry from release to settle, and the old gap
and the new slot hand over on the same curve, so no icon moves.

### The dropped icon lands in its gap, in one frame (3 October 2026, found live)

After a drop the icon sometimes slid in from the right once more. Two causes:

- **The release recomputed the drop.** The preview shows the drop computed at
  the last pointer move, but `finishIconDrag` hit-tested again at release,
  against a layout the open gap had already shifted. The icon glided into the
  gap it saw, was committed beside it, and slid there (seen offscreen: the gap
  opened after the AI group, the commit put Workspaces after Scratchpeek, and
  the group was not re-anchored). The release now commits the shown drop
  (`barDragDrop`) and computes one only if none is shown.
- **A gap that trails an icon** (after a group icon, say) is the end of that
  icon's slot. Easing it out while the new slot eased in moved the new slot's
  left edge, so the icon slid while its slot grew. The gap and the slot are the
  same length at the same spot, so the commit now swaps them in one frame
  (`dragHandover` turns slot and end-gap motion off for that frame). A
  cancelled drag still eases its source back.

Recorded per frame offscreen for drops within a zone, across zones, after a
group icon and beside the centre anchor: every island and every visible icon
keeps its place from release to settle; the saved layouts of the drag
scenario are unchanged.

## Measured pass: 10 October 2026

A review found startup CPU about doubled since the 3 October pass, and idle CPU
too. Three changes, measured with the same bench (medians of 3, the user's
layout of 37 entries, CPU ms):

| Change | Why |
| --- | --- |
| Preferences builds its pages (Layout, Groups, Bar) the first time it opens, then keeps them (`Preferences.qml` `pagesLoaded`, page Loaders). A group asked for before its page exists is selected as it loads (`selectGroup`). | All three pages were built at startup for a window nobody had opened. |
| Widget faces captured in one run are published once, 100 ms after the last (`Bar.qml` `pendingFaces`, `facePublish`). | 5 s after start about 40 captures each reassigned `widgetFaces`, and the closed Layout editor redid its work each time. |
| A slot's ink measurements, cell placement and the island border return the same object when the values are the same (`measureKept`, `kept()`, `borderKept`); the hidden placeholder's tooltip is not computed. | A value change re-lays the label out in several steps; a step that measures what the last did no longer re-runs the cell, hold and zone fit. |

| Scenario | Before (3764842) | After |
| --- | --- | --- |
| Startup: create / CPU | 260 / 400 ms | 153 / 170 ms |
| Idle 10 s after startup | 160 ms | 120 ms |
| Drop commit, average | 28.1 ms | 17.2 ms |
| Settings change, average | 11.7 ms | 6.7 ms |
| Drawer open | 22.8 ms | 19.8 ms |
| Preferences, first open | 29 ms | 137 ms |

The first open of Preferences now pays for its pages (about 110 ms, once per
session) instead of every startup paying for them. Geometry and saved layouts
are identical to before in all fifteen scenarios. The per-frame recordings of
the animated scenarios have the same final values; a 0.7 to 2.7 px drift of
one icon after a drop varies from run to run on both versions alike.

Not done: the PNG writes of captured faces still run on the GUI thread, and
the zone fit still re-runs per measurement step (now with fewer steps).

## Profiling gates still outstanding

The running Omarchy shell was found with `qs list --all`. This sandbox denies
access to its Wayland socket. Offscreen native PanelWindow compilation has no
window backend, so full native bar construction, compositor profiling and live
visual acceptance remain unrun. The scoped Qt fixtures establish the portable
results above without changing the active shell.

The following plan choices require the live measurements specified in stage 0:

- Compare all four edges, styles, scales, group display modes, tray menus,
  focus/scrolling, all drag routes, activity suppression and monitor removal.
- Profile p50/p95/p99 opening, interaction, JS/layout, render/sync and compositor
  timing on 1 and 3 monitors; check memory/producer counts over 100 cycles.
- Tune capture concurrency using opening/completion latency and GPU readback
  cost. The current limit of two is a conservative bound, not a proven optimum.
- Evaluate outer tray layers, clipping, surface padding, shadow/effect caching,
  preview decode sizes, and PNG worker/persistence scheduling with pixel and
  input-region comparisons.
- Decide whether lazy page construction, list/menu virtualization, more ink
  caching, tooltip polling removal, popup discovery caching or asynchronous
  additions have a measured benefit. Visited page state and third-party dynamic
  popup discovery remain available under the current lifecycle contract.

The plan makes these changes conditional on equivalent visuals and a measured
benefit. They remain gated instead of claiming an unverified maximum speedup.

### A drag from a drawer can't get stuck (3 October 2026, found live)

The bar froze mid-drag: the dragged image stayed on screen and every drag
target stayed up. A drag that starts on a drawer row is driven by a handler on
that row, and the row was destroyed mid-drag, so the release never arrived.
Three things closed or rebuilt the drawer under the drag: a zone's inline
expansion opening (it closes the open drawer), a group edit (`editGroups`
closed the drawer first), and starting a drag while the previous drop was still
settling (that commits the previous drop, which can be a group edit). The
drawer's rows are a plain array model, so any member change rebuilds them all.

Now the drawer holds the row a drag started on (`ManagedDrawer.dragMount`): it
keeps presenting and keeps its rows until the drag ends, whatever closes it or
changes its members, and an inline expansion leaves it open. If that row is
destroyed anyway, the drag is cancelled rather than left running. A drop into
an open group drawer no longer closes it (`editGroups(..., keepDrawer)`), so
the group stays under the pointer.

The small Managed targets (round dots under each zone during a drag) are gone:
the zones' dots are the drop target for On demand.

### Dragging in and out of groups (3 October 2026, found live)

Checked with live logs of a real session (presses, drag starts, the drawer's
state and the input grab), then offscreen:

- **Drops into a menu landed a row late.** The landing point follows the dragged
  widget's ink centre, which is measured along the bar; in a menu below a
  horizontal bar it was added to the vertical position, about a row's worth.
  The ink now applies only to a surface along the bar.
- **A value widget couldn't be dragged out of a menu.** A menu row's drag and
  click lived on its name; the rest of the row is the widget itself (the
  battery's "100%"), whose own area took the press. The whole row now takes
  the drag and the click, above the widget.
- **The next click didn't focus anything.** A group opened by a click holds
  the keyboard and dismisses on an outside click, which that click spends.
  Kept open after a drop, it swallowed the click meant for another window. A
  pointer drag now ends the drawer's keyboard mode: it closes on hover like
  any other.
- **The dragged name showed twice.** From a menu the drag image was the whole
  row, name included, and the ghost adds the name. A row that shows the
  widget now gives just the widget, and it lands on the widget's spot.
- **A widget made On demand couldn't easily come back.** With a zone expanded,
  the gap where the shown widgets meet the expansion looked the same either
  way, but its result depended on the nearer neighbour: beside the expanded
  widget it landed On demand. Now that gap lands shown; a drop lands On demand
  only inside the expansion's run, or at the dots (`ZoneOrderModel.landsOnDemand`,
  hidden widgets skipped as neighbours). A gap right after a group icon of the
  same run takes the group's place, so the widget lands after the group as
  drawn, not before it.

### One drag behaviour on every surface (3 October 2026)

The bar, zone drawers (extended islands), icon-strip groups and menu groups
shared the drop resolution (`moduleDropAtScene`, `DragModel`, the dead zone)
but each drew and committed drops its own way. Audited side by side:

| | Bar | Drawers before | Now |
| --- | --- | --- | --- |
| Landing outline in the gap | yes, zone ends too | none | `DropOutline.qml` everywhere: a cell in strips, a row in menus, the drawer's end gap too |
| Release | glide into the gap, then commit | commit, then glide to the new row | glide, then commit (`ManagedDrawer.landingPoint`) |
| Gap to row handover | one frame | gap and row eased separately | one frame (`dragHandover`) |
| After the drop | — | zone drawers closed (structural edit); groups stayed | every drawer stays under the pointer (`keepDrawerThroughEdit`), leaving on the exit grace |
| Drag image | the widget | menus: name box with a 2 px accent border | name box bordered like the outline (1 px, 45 % of the text colour, highlight radius) |

Recorded per frame offscreen: drops into the Audio menu, the AI strip and a
zone drawer show the outline while dragging, glide, swap the gap for the new
row in one frame without moving any row, and leave the drawer open. The drag
scenario's saved layouts are unchanged.
- **A group icon has no place in a group drawer.** Groups don't nest, and the
  drop was already refused on release, but the drawer still opened a gap,
  outlined it and moved its rows. Now a dragged group icon finds no drop surface
  in any group drawer, and its own drawer closes when the drag starts (it hangs
  off the icon being moved).
