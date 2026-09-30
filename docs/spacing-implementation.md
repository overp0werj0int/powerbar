# Spacing implementation plan

The design is final. The spec of record is
[spacing-lab/spacing-lab.html](spacing-lab/spacing-lab.html) (open it in a
browser; it renders your cached widget captures). This plan turns the spec
into work in the order it can land without breaking drag and drop or the
drawers. Each step lists files, tests and how to accept it.

Wherever the plan and the spec disagree, the spec wins. Where the code
disagrees with the spec, change the code. The current highlight and alignment
geometry is not a reference.

## Status, 1 October 2026

Implemented and committed, together with the rendering performance work
(docs/rendering-performance-implementation.md).

**Implemented and live-checked:**
- **Cells:** `CellModel.js`, with node tests, and `HighlightModel.inkRect`.
- **Bar layout:** cell-sized slots, per-end island pads, and the preferences
  button as the last cell.
- **Highlights:** highlight = cell, and the badge on the cell's corner.
- **Spacing:** both spacing modes and the Preferences row.
- **Vertical bars:** glyphs centred across the bar by their ink, and group
  faces falling back to their glyph.
- **Drawers:** strips and menus with the new placement, and the group icon's
  open fill.
- **Motion:** every animation follows the Animations switch.
- **Highlight layers:** they now register when their window appears.
  Previously they never registered, so bar highlights drew inside each
  widget's own box.

**Placement fixes after live testing:**
- **Ink:** `inkRect` counts only what is visible. A child that clips has its
  ink cut to its box (the tray's closed drawer, hidden indicators), and a
  plain fill covering the widget is background (Scratchpeek's own pill).
  The kit's icon button counts as an icon only up to 16 px of ink, because
  the battery's is a whole string.
- **Width hold:** a cell losing at least one icon cell shrinks at once.
  `powerbarWidthHold: false` opts a widget out (the tray and Indicators
  animate their own width), and orientation, bar size or spacing changes
  reset the hold.
- **Across the bar:** slots are at least the bar's thickness, with the
  widget's box centred (the Agent Orchestrator is 27 px tall on a 38 px bar).
- **Orientation:** retained slots and lists are positioned by `x`/`y`, never
  by anchors switched by orientation, which removed their size bindings when
  the bar moved edge.
- **Drag lip:** removed; the outlined placeholder shows where a widget lands.

**Checked only in code and tests:**
- **Needs a pointer or keyboard:** compound thumbs, the Equal gaps overlap
  fade, drag landing and the placeholder outline, and the keyboard cursor
  ring. Checking these would have meant moving the pointer or sending keys.
- **Animations off:** that the shell stays idle, with a highlight showing
  and Animations off.

**Differences from the spec:**
- **Landing rule:** landing uses the ghost's ink centre with a 3 px dead
  zone, compared with the rendered cell centre (past any open gap), rather
  than with a separately computed resting layout.
- **Free text:** capped at 160 px of ink by the slot's clip, without the fade.
- **Pointer bridge:** the drawer's pointer area does not yet span the 4 px
  gap; the dismissal delay covers the crossing.
- **Menu counts:** members show no counts in menus; Powerbar has no
  per-member count yet.
- **Preferences focus ring:** follows geometry changes through
  `GeometryObserver` (rendering performance work), no longer per frame.

## The numbers

B is the bar's thickness: `Style.bar.sizeHorizontal` (26) or
`Style.bar.sizeVertical` (28), plus `largeBarLip × 2` (12) on the large bar.

| Token | Formula | Std 26 | Large 38 | Vert 28 | Vert large 40 |
| --- | --- | --- | --- | --- | --- |
| inset i | `min(3, (B − 16) / 2)` | 3 | 3 | 3 | 3 |
| thickness T | `B − 2i` | 20 | 32 | 22 | 34 |
| icon cell C | `T` (square) | 20 | 32 | 22 | 34 |
| text air a | `(C − 12) / 2` | 4 | 10 | 5 | 11 |
| text cell | `max(C, min(ink, 160) + 2a)` | | | | |
| gutter | `i + spacing` | 3 | 3 | 3 | 3 |
| island end | `i` (slots), `i + spill` (gaps) | | | | |
| gap G (Equal gaps) | `C / 2 + 2 + spacing` | 12 | 18 | 13 | 19 |
| highlight radius r | `clamp(R − i, 0, T / 2)` | | | | |

Other rules:

- **Spacing modes.** `powerbarSpacingMode`: `"slots"` (default) or `"gaps"`.
- **Preferences.** Style section, a `PrefsChoice` row "Spacing" with the chips
  Equal slots and Equal gaps, above "Space between widgets".
- **Highlight.** The highlight is the layout box, centred on the ink. In Equal
  gaps, overlapping highlights stay symmetric; the newer one draws on top and
  the older one fades to 45%.
- **Badge.** The badge rides the highlight's corner at 45° and is clamped 1 px
  inside the island on both axes.
- **Drag gap.**
  - Slots: the cell plus the gutter. Gaps: the glyph plus G.
  - Landing spot: nearest the ghost's centre on the resting layout, with a
    3 px dead zone.
  - Duration: `clamp(150 × √(gap ÷ icon gap), 150, 260)` ms on an ease-in-out
    sine.
  - Settle: 180 ms strong ease-out. Pick-up: 120 ms.
- **Drawers.**
  - Placement: gap to the bar = `edgeGap` (4). Strips are islands along the
    bar's axis: centre on the source cell, clamp one `edgeGap` from the screen
    edges, then snap an end within T / 2 of the island's end.
  - Menus: T-tall rows at pitch T + i, with padding i and the island radius R.
    Names start at C after an icon and at a in rows without one. Non-glyph
    members show their native look right-aligned at a from the row's end;
    counts use the shared badge there. Width = `clamp(content, 4C, 320)`.
  - Alignment: below a horizontal bar the first row starts at the source
    highlight's start, flipping near the screen edge. Beside a vertical bar the
    first row's centre is level with the source's centre, flipping near the
    bottom.
  - Motion: 160 ms in and 110 ms out, from scale 0.94 around the source's centre.
- **Motion.** One switch, `powerbarAnimations`, read as `animationsEnabled`.
  With it off, every change lands at once and nothing runs per frame.

## Before starting: reconcile the uncommitted highlight work

The working tree has uncommitted edits to `Bar.qml`, `HighlightModel.js` and
`tests/highlight.test.cjs`:

- `highlightGeometry()` is factored out of the widget highlight.
- The preferences button gets the shared highlight.
- `HighlightModel.pill` gets a `snap` that stretches end highlights to meet the
  island's end.

The factoring and the shared preferences-button highlight fit the spec. The
end stretch doesn't: under the spec the island ends one inset after the last
cell, so end highlights are concentric by construction and never stretch. A
stretched end cell would also be wider than its neighbours, which breaks the
square icon cells. The new `FrameAnimation` on the preferences button runs
every frame while it's highlighted, which breaks "off means idle".

Commit the factoring on its own, drop `snap` and its test, and gate or remove
the new `FrameAnimation` (see step 9).

## Steps

1. **Add `CellModel.js` with node tests.** `cellLength({ kind, ink, thickness,
   maxInk })` returns the box length: T for glyphs, `max(T, min(ink, maxInk) +
   2a)` otherwise. `layoutZone(items, { inset, spacing, mode })` returns each
   item's box, ink offset and highlight, and the island length, for `"slots"`
   and `"gaps"`. Kinds: glyph (a glyph with painted width at most 16 px),
   text, compound (two or more registered click targets).
   *Tests:* both bar sizes; glyph, short text (EN), long text (clamped at 160),
   compound; ends at i in slots and at i + spill in gaps; spacing widens
   gutters only; icon boxes are square.

2. **Measure an ink rectangle.** Extend `HighlightModel.inkWidth` to `inkRect`,
   returning left, width, top and height, so off-centre content (the tray's
   chevron sits 14 px right of centre; Workspaces has a 1.5 px trailing gap)
   centres on what is painted. Vertical bars need top and height.
   *Tests:* off-centre children, trailing gaps, painted hints.

3. **Size slots from the cell.** In `Bar.qml` the slot's `naturalWidth` (or
   `naturalHeight` on a vertical bar) becomes the cell length, and the
   presentation shifts by `(L − ink) / 2 − inkLeft`. `Row`/`Column` spacing
   becomes the gutter (`inset + widgetSpacing`), and `islandPadding` becomes
   the inset (plus the drag lip). The drag gap is the dragged cell plus the
   gutter.
   *Accept:* the chips on the spec's hero match a screenshot of the live bar
   (air between glyphs, air at the ends, end highlights centred).

4. **Make the highlight the slot box.** `highlightGeometry` reduces to the
   slot's rectangle at thickness T with radius `clamp(islandRounding − inset,
   0, T / 2)`, with no end adjustment. Hit areas cover the cell plus half of
   each gutter and the full thickness; the first and last reach the island's
   ends (the screen edge on a flat bar). Clip each slot to its hit area.

5. **Give compounds thumbs and hold widths.** Compounds show a faint track and
   a thumb over the hovered target: side `min(T, pitch − 1)`, radius
   `r − (T − side) / 2`. A cell grows at once and shrinks only after 8 s at the
   smaller size. Free text is capped at 160 px of ink, with a fade.

6. **Both modes and the preference.** Read `powerbarSpacingMode`; add the
   `PrefsChoice` row "Spacing" (Equal slots, Equal gaps) above "Space between
   widgets", with each option's one-line description. In gaps mode each
   `HoverHighlight` records when it lit; where two overlap, the newer gets the
   higher z and the older drops to 45% opacity.
   *Tests:* `PreferencesModel` round-trips the key; a QML test for the overlap
   fade.

7. **Drag with landing-size gaps.** The placeholder is the dragged widget's
   highlight, outlined. The landing spot is a pure function of the ghost's
   centre on the resting layout, in `DragModel.js`. Timing is as in the numbers
   above; the settle happens before the layout commits.
   *Tests:* `drag-preview.test.cjs`, with sweeps for an icon and the clock that
   change the landing spot exactly once per boundary; `tst_DragSettle.qml`
   with animations on and off.

8. **Vertical bars and drawers.**
   - **Vertical bars:** `layoutZone` with along-axis ink, B from
     `sizeVertical`. Glyphs centre across the bar by ink. Content across the
     bar must fit T: widgets supply a vertical form, such as the clock's
     `HH / — / mm`, and group faces fall back to their glyph. Badges are
     clamped inside the island.
   - **`ManagedDrawer.qml` strips:** `layoutZone` along the bar's axis, placed
     with the centre-clamp-snap rule.
   - **`ManagedDrawer.qml` menus:** the row rules from the numbers above. The
     pointer area spans the 4 px gap.
   - **Keyboard:** the cursor uses the bar's focus ring and never animates.
   - **Counts:** a widget's count shows with the shared badge, never painted
     over its glyph (the Agent Orchestrator does this today; its maintainer
     would need to expose the count instead).
   - **`ManagedModel.menuLabelStart`:** becomes `C` for icon rows and `a` for
     rows without an icon.
   - *Tests:* `managed.test.cjs` for placement (flip, clamp, snap, vertical
     level), label starts, trailing values and the menu width clamp.

9. **Put every animation behind the one switch.** These still ignore
   `animationsEnabled`:
   - `Bar.qml`: the `background` and `urgent` colour crossfades (next to
     `barForeground`), and the move-candidate edge's `Behavior on opacity`.
   - `BarBackdrop.qml`: `Behavior on opacity`.
   - `widgets/ActiveWindow.qml`: `Behavior on implicitWidth`.
   - `widgets/Tray.qml`: `Behavior on revealProgress`.
   - `LayoutEditor.qml`: the tile's `Behavior on color`.
   - The `FrameAnimation`s that re-place highlights (the widget highlight and
     the preferences button) must run only while their slot is moving and
     animations are on. Otherwise re-place on geometry changes.
   *Tests:* a QML test that turns the flag off and checks each change reaches
   its end state in the same frame.

10. **Verify on the desktop.** Run `node tests/*.test.cjs` and the QML tests.
    Then, with autohide off, screenshot all three bar styles, both sizes, both
    spacing modes and a vertical bar, once with animations on and once off.
    Open a group drawer in each display mode on a top bar and a left bar.
    Compare each with the matching state on the spec page: its hash hooks
    (`#ext-ai-both-left-large-cells`, `#ghost-3-settled`) render one state at
    a time. Check that the shell stays idle with a highlight showing and
    animations off.

## Tooling

The `omarchy-widget-lab` skill that produced the spec is in
`.claude/skills/omarchy-widget-lab/`. Use it for any follow-up design question
(it iterates on the same page) and to recapture assets
(`scripts/collect_assets.py`) after visual changes.
