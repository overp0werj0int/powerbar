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
node docs/rendering-performance-probe.cjs --emit /tmp/powerbar-path-probe
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

`docs/rendering-bench/` runs the real `Bar.qml`, `Preferences.qml` and
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
docs/rendering-bench/bench.py "$PWD" current 3          # medians of 3 runs
docs/rendering-bench/prof.sh "$PWD" churn 1 /tmp/churn.qtd
docs/rendering-bench/analyze.py /tmp/churn.qtd "$XDG_RUNTIME_DIR/powerbar-bench/prof-app.log" 30
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
