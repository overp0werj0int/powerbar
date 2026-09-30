# The bar renderer (lab-template.html)

All geometry is in bar pixels; multiply by `Z` only when writing styles.

## Data

`widgets.js` (from `collect_assets.py`) sets `window.LAB`:

```js
LAB.widgets[name] = { w, h, ink: [left, width, top, height], parts: [[x, w], …], id, instance, zone, visibility }
LAB.zones = { left: [names], center: [names], right: [names] }
LAB.theme = { colors: { foreground, background, accent, color1, … }, font }
LAB.bar = { large, style, position, rounding, spacing }
```

Item specs passed to layouts are names, or objects:
`{ id: "group-ai", badge: 3 }`, `{ text: "88%" }` (drawn label),
`{ id: "prefs" }` (Powerbar's preferences glyph), `{ id: "ghost" }` (a drop
placeholder). `makeItem` turns them into items with `kind` (`glyph`, `text`,
`compound`), `w`, `h`, `inkX`, `inkW`, `parts`. Mark compounds in
`COMPOUNDS`; kinds otherwise come from ink width (≤ 16 px and one part is a
glyph).

## Params

`params({ size, rounding, spacing })` returns the tokens every layout uses:
`B` (bar thickness), `i` (inset), `T` (highlight thickness), `R` (island
radius), `r` (nested highlight radius), `cell` (icon cell), `air` (text side
air), `gap` (equal-gap spacing), `todayPad`, `todayR`. Add fields here when an
option needs a new token, and show it in RULE_ROWS.

## Layouts

A layout is `function (items, P) -> { len, cells }`. Each cell:

```js
{ it,                       // the item
  box: { x, L },            // layout box (x-ray dashed outline)
  ink: { x, w },            // painted extent after placement
  contentX,                 // where the capture image's left edge goes
  hl: { x, L, r },          // highlight rectangle and radius
  thumbs: [{ x, side, r }], // compounds: one per sub-target (addThumbs)
  splitAtInk: true }        // optional: hit areas split at glyph gaps, not highlight gaps
```

Return `fixedHits: true` to keep hit areas equal to boxes (today's
behaviour); otherwise `layout()` gives every cell a hit area that covers the
gutters and reaches the island ends. Register options in `ALGOS` with a
`label` and optional `summary` (used by the comparison rows). Keep `today`
first.

## renderZone(parent, specs, algo, P, opt)

Draws one island and returns `{ lay, wrap, island, refs, paint }`.

| opt | Effect |
| --- | --- |
| `Z` | zoom factor |
| `bg` | draw the island surface |
| `interactive` | hit buttons: hover, press, click to hold open, Tab focus, h/l in compounds |
| `all` | every highlight at 10% (consistency view) |
| `xray` | dashed boxes, ink bands, gap labels under the island |
| `states` | `{ index: "hover" \| "pressed" \| "open" \| "focus" \| "activity" \| "urgent" }` |
| `part` | `{ index: thumbIndex }` for compounds |
| `recent` | index of the most recently lit item when several states are set |

Overlap rule: where two lit highlights overlap, the more recent draws on top
(`.newest`) and the older fades (`.older`, 45%). Recency comes from
`lightClock` for interaction and from `opt.recent` for static demos.

## Vertical bars

`renderZone(..., { vertical: true })` draws the same layout along y: every
style goes through one `at(along, across, lenAlong, lenAcross)` helper, so
highlights, thumbs, hit areas, badges, x-ray and the overlap fade need no
second code path. Feed it items from `makeItemV`: captures report ink top
and height along the bar (`INKY`) and ink left and width across it, and text
uses a vertical form (`{ vtext: ["12", "—", "56"] }`, or `pitch` for
compounds such as workspaces) measured with canvas `actualBoundingBox*`.
Across a vertical bar, centre glyphs by ink, never by the horizontal slot.
`params({ vertical: true })` uses the theme's vertical size (28, +12 large),
not the horizontal one. Clamp badges 1 px inside the island on both axes.

## Auditing a surface

For any surface with many configurations (drawers, menus, vertical bars),
write `measureExt`-style code that measures the *drawn DOM* (element rects
divided by `Z`, plus `data-cx`/`data-il` on images for ink offsets), run it
over every combination off screen, and show the worst case per rule in a
"Checked in every combination" table. Print failing configurations under a
`#audit` hash while iterating. The audit found three bugs in one pass that
screenshots had hidden (strip clamp versus snap order, a menu taller than its
test screen, a value measured from its capture box instead of its ink).
Pair it with a hash hook that renders one configuration alone
(`#ext-ai-both-left-large-cells`, adding `solo-ext` to hide the rest) so
each can be screenshotted without clicking.

## metrics(lays)

Returns ranges (`[min, max]`) for `glyph` (air between glyphs), `ends` (air
at island ends), `hl` (gap between highlights), `clear` (highlight end to the
next glyph), and `centred` (end highlights centred on their glyph). Chips use
these with stated thresholds.

## Adding a surface

For drawers, panels or Preferences rows, write a renderer that reuses the
tokens (`params`), `el`, `px`, `fmt`, `chip`, the `.stage`, `.island.bg`,
`.hl.*` and `.prefs-card` styles. Keep geometry in a pure function and the
DOM in a draw function, as `layout` and `renderZone` do, so validation code
can call the geometry directly.

## Motion demos

Build the DOM once, then move elements by changing `left`/`width` with
`transition-duration` set per move; rebuilding the DOM kills transitions.
Put the decision logic (for example, the landing index) in a pure function of
the ghost position on the resting layout, never of positions that move in
response to it, or the preview oscillates. See `renderDragLab` in
`reference-lab.html`.

What made the drag demo read correctly (learned from user feedback):

- **The ghost is a lifted cell, not a bare capture.** Give it the dragged
  widget's own cell shape on an opaque bar surface with a shadow and the
  hover fill, lifted about 2 px and scaled 1.04, with the capture centred on
  its ink. A bare capture raised a few pixels just looks misaligned.
- **Start near the landing spot** (a few px off it, so the placeholder
  outline peeks out), and keep the ghost within about 12 px of the first and
  last landing spots so it never floats off the island.
- **Show what the rule measures.** If boundaries are drawn, also draw the
  point they are compared with (a dot under the ghost's centre), and explain
  the frame they live in.
- **Finish the gesture.** A drag demo must drop: on release the ghost
  settles in one 180 ms strong ease-out (glides its glyph centre onto the
  cell centre, loses the lift, scale, surface and shadow) while the
  placeholder fades, leaving an ordinary widget in the island. Pressing it
  (or Space) picks it up again in 120 ms; arrows move, Esc settles it back
  where it was lifted. Toggle `held` / `settled` classes and put the timing
  on `.settling` / `.lifting` so pointer following stays untransitioned.
  A played demo ends with a drop, not mid-air.
- **Expose a state hook** (`window.__dragLab = { move, spots, index }`, and
  `#ghost-N` and `#ghost-N-settled` in the URL) so you can render the demo at several positions
  with `screenshot.sh … dark ghost-N` and look at each before publishing.

## Traps found in review

- **The published page squeezes images.** The Artifact host wraps the page
  in a skeleton with `img { max-width: 100% }`, which shrinks any capture
  wider than its container (a 38 px update slot on a 28 px vertical bar, the
  tray's 54 px slot) and pushes it off-centre. Keep
  `.page img { max-width: none }`. `scripts/screenshot.sh` renders through
  the same wrapper, so the bug shows locally before publishing.
- **Self-drawn counts can't be cropped.** A widget that paints a count over
  its glyph hides part of the glyph under it. Render the widget's icon source
  clean (`collect_assets.py --glyph name=icon.svg`) and show the count with
  the shared badge.
- **Measure every shape the copy promises.** The spacing lab's text
  promised icon "circles" while its standard-bar formula gave 24 × 20 cells.
  An "icon highlights square" rule in the audit catches that class of
  mismatch between words and geometry.
