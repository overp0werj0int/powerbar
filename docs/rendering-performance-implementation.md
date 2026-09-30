# Rendering performance implementation

30 September 2026. Implements the rendering audit against the existing working
changes; the spacing, highlight, drawer, and drag work present before this task
is preserved. No desktop configuration was edited and no plugin was deployed.

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
/usr/lib/qt6/bin/qmltestrunner -import tests/qml/imports -input tests/qml -o -,txt

# Emission also works where Node child-process spawning is restricted.
node docs/rendering-performance-probe.cjs --emit /tmp/powerbar-path-probe
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software \
/usr/lib/qt6/bin/qmltestrunner -input /tmp/powerbar-path-probe -o -,txt

python3 /home/p0werj0int/.agents/skills/omarchy-plugin-test/scripts/validate_plugin.py "$PWD"
omarchy plugin validate "$PWD"
```

The QML suite uses narrow test imports for Quickshell process/IPC and host
controls. Process stubs never execute commands. The BarIndicator fixture mirrors
the installed host's block/override/opacity contract; button/style stubs support
only these tests. This is portable regression evidence, not live host acceptance.

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
