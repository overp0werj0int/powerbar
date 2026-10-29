# Preferences design system

How Powerbar's Preferences window is drawn: type, text tiers, spacing, sizes,
corners, the parts every page is built from, how the cursor is marked, what
rises and what casts a shadow, the tilted plates and the camera over them,
motion, themes and contrast. Build a new page from this and it reads like the
others. The same rules suit another Omarchy plugin's settings window.

The type, tier, spacing and corner rules are the golden hierarchy the user
approved on 2026-10-30 (branch `golden-hierarchy`). The lab that argues for
them, with every page drawn today and golden side by side, is
[`docs/hierarchy-lab/hierarchy-lab.html`](../hierarchy-lab/hierarchy-lab.html);
captures of the pages before the change are in `docs/hierarchy-lab/captures/`.
Where today's code still has other numbers, this file gives the rule and the
code is being brought to it (the list is at the end). The behaviours are in
[`behavior/preferences.md`](../behavior/preferences.md); where the two
disagree on behaviour, `behavior/` wins. File and line references were read
on 2026-10-30 and will drift as the code changes.

## Contents

1. Principles
2. Tokens in QML
3. Type
4. Text tiers and colour
5. Spacing
6. Control sizes
7. Corners
8. Parts
9. Page structures
10. Focus and the cursor
11. Elevation and shadows
12. Pages in perspective
13. The camera over the plates
14. Motion
15. Light and dark themes
16. Accessibility
17. Build a new page
18. Review checklist
19. Sources

## 1. Principles

- The theme owns colour, font family, base size, spacing scale and corner
  rounding. Every number here goes through Omarchy's `Style` so it follows
  them.
- Things are as close as they are related. Each level of a page's structure
  takes the next gap on the ladder, and each level is at least 1.4 times the
  one inside it.
- Four text roles and three tiers. Size and weight tell role. Tier tells
  importance. Nothing else is needed.
- One control height. Rows, chips, faces, fields and buttons are all one
  label line plus padding.
- Corners come from the window rounding and step down as things nest. A
  square theme is square everywhere.
- Depth is drawn with flat bands, not blur. What rises casts a band as tall
  as its rise.
- The real bar is the preview. Pages do not draw a bar of their own.

## 2. Tokens in QML

Four files in the repo root carry the system. Use them; do not set sizes,
tiers, gaps or radii by hand.

| File | Kind | Members |
|---|---|---|
| `Ink.qml` | singleton | `page`, `section`, `label`, `caption` (px); `secondary` 0.786, `disabled` 0.382; `text` (the popups' text colour); `tint(tier)`; `line(size)`; `size(role)` |
| `Gap.qml` | singleton | `xxs` `xs` `s` `m` `l` `xl` `xxl` `xxxl`; `control` (25); `switchRow` (28) |
| `Round.qml` | singleton | `card`, `container`, `control`, `small` |
| `InkText.qml` | component | `GrayText` with `role: "page" \| "section" \| "label" \| "caption"`, `tier` (default 1, a caption's `Ink.secondary`), `disabled` |

```qml
// A row's label and its caption, a text pair.
ColumnLayout {
    spacing: Gap.xxs
    InkText { role: "label"; text: "Autohide" }
    InkText { role: "caption"; text: "The bar slides away; the screen edge brings it back." }
}
```

`InkText` sets the font family, the role's size and weight, the tier's
colour (`Ink.tint(tier)`, or `Ink.disabled` when `disabled`), plain text, and
a fixed line height of `Ink.line(size)`. Qt puts a fixed line's glyphs at its
top; `InkText` moves them down by half the extra room so the text sits in the
middle of its line as a browser sets it (`InkText.qml:21`). It is a
`GrayText`, so it keeps Powerbar's greyscale curve rendering.

Where `InkText` cannot be used (a kit control that draws its own text), take
the size from `Ink.label` or `Ink.caption` and the colour from
`Ink.tint(...)`.

## 3. Type

### Scale

A size is `base × φ^(n/3)`, rounded, with `base` the Omarchy body size (12 by
default, `Style.font.body`). Every third step is exactly φ (1.618) larger.
Omarchy's own caption, body and title tokens sit on this scale within a
pixel, so three of the four roles are Omarchy tokens.

| n | Exact at 12 | px | Role | Token |
|---|---|---|---|---|
| 3 | 19.4 | 19 | Page | `Ink.page` = `Style.fontPx(1.618)` |
| 2 | 16.6 | 17 | not used | |
| 1 | 14.1 | 14 | Section | `Ink.section` = `Style.font.title` |
| 0 | 12 | 12 | Label | `Ink.label` = `Style.font.body` |
| −1 | 10.2 | 10 | Caption | `Ink.caption` = `Style.font.caption` |
| −2 | 8.7 | 9 | not used | |

Omarchy's `bodySmall` (11) and `heading` (16) sit between steps. They are
not used on Preferences pages: 10, 11 and 12 are 9 to 10 % apart, below what
reads as a different size, so an 11 reads as a mistake next to a 12.

### Line height

Every text box is `round(size × φ)` tall (`Ink.line(size)`):

| Size | Line |
|---|---|
| 19 | 31 |
| 14 | 23 |
| 12 | 19 |
| 10 | 16 |

Wrapped captions get comfortable leading, and the control height falls out
of the label's line (section 6).

### Roles

| Role | Size | Weight | Tier | Used for |
|---|---|---|---|---|
| Page | 19 | Bold | Primary | The window's title ("Powerbar" in the header) |
| Section | 14 | DemiBold | Primary | Strip titles, layer and plate titles, the inspector's name |
| Label | 12 | Regular; Bold only for the current tab | Primary | Anything that names a control or a thing: tabs, rows, chips, widget and group names, field labels ("Screen edge", "Show", "Layer"), fader names, buttons, layer rows, Close |
| Caption | 10 | Regular; Bold for keycaps | Secondary | Anything that explains, counts or hints: captions, zone names, counts, badges, hints, footnotes, placeholders, the key legend's words, keycaps, empty notes |

The test: if it names something you can press or point at, it is a label.
If it explains, counts or hints, it is a caption. A field's label ("Show",
"Layer", "Zone") is a label, not a caption and not bold. A group's name is
the same size as its members' names.

The family is `Style.font.family` everywhere (menus may use
`Style.font.menuFamily`). No second face, no italics, no ALL CAPS.

## 4. Text tiers and colour

Text colour is the popups' text colour (`Commons.Color.popups.text`,
`Ink.text`) at one of three tiers, powers of 1/√φ:

| Tier | Alpha | Token | Use |
|---|---|---|---|
| Primary | 1 | `Ink.tint(1)` | Labels, titles, values the user set |
| Secondary | 1/√φ = 0.786 | `Ink.secondary` | Captions, hints, counts, the legend, inactive tabs, a fader's value next to its name |
| Disabled | 1/φ² = 0.382 | `Ink.disabled` | A control that does not apply now (PREFS-20) |

- Hover is the only state between tiers: an inactive tab or Close at
  secondary goes towards primary under the pointer.
- The accent (`Commons.Color.accent`) marks state, not rank: the current
  tab's underline and keycap, chosen pick rings, action rows, the leader,
  outlines of landing places, a draft value. Errors use `Commons.Color.urgent`.
- A dimmed control dims as a whole (its text, mark and fill) to the disabled
  tier, and stays in place.
- No other alphas for text. Today's pages use six (0.3 to 0.7); they all map
  to secondary.

Fills and borders come from Omarchy's state tokens: `Style.focusFillFor`,
`Style.selectedFillFor`, `Style.hoverFillFor`, `Border.controlSpec("focus", …)`,
`Border.flat(…)`. Surfaces are the popups' background tinted with the text
colour: a tile 6.5 % (the bar layer's 9 %), a pulled-out chip 15 %
(`ZoneTile.qml:118`, `LayoutEditor.qml:1617`). Hairline edges are the text
colour at 12 % (tiles, strips) or 16 % (inspector, tooltip).

## 5. Spacing

### The ladder

Gaps are Fibonacci numbers, each about φ times the one before, each through
`Style.space()` so it scales with the font and the theme's spacing scale.

| Step | px | Token | What it is for |
|---|---|---|---|
| xxs | 2 | `Gap.xxs` | A text pair: label and its caption, title and its caption, a field label and its control, a control and its hint, a name field and its caption |
| xs | 3 | `Gap.xs` | Siblings in one group: pick rows, chips, tabs, keys of a combo, rows in a zone, pool chips, zone squares, layer rows. A control's vertical padding |
| s | 5 | `Gap.s` | Inside a control: horizontal padding, keycap and its word, a fader's name and its rail, a zone's name and its rows. How far a row's highlight reaches past its text |
| m | 8 | `Gap.m` | Controls and fields in a strip or an inspector column. A tile's padding. A dot or icon and its label |
| l | 13 | `Gap.l` | A strip's padding. Title block, controls and faders as blocks. Zone and zone. Legend columns. The inspector's body blocks. The room on each side of a hairline |
| xl | 21 | `Gap.xl` | Strip and strip. Layer and layer, measured from the slab edge. The card's top and bottom padding. The inspector's padding and its column gap |
| xxl | 34 | `Gap.xxl` | Header and desk or plates. Page title and tabs. The Tuning tab and Close |
| xxxl | 55 | `Gap.xxxl` | The card's side inset. A plate's least height. The inspector's preview box height |

A hairline separates blocks, so it takes the block level: `l` on each side,
not the `m` between controls. Otherwise the line divides without grouping.

Never use negative margins to pull text together. A field is a column with
`xxs` spacing.

### Level by level

Desks (Look, Behavior, Tuning):

| Level | Between | Step |
|---|---|---|
| Text pair | label and caption; "Screen edge", its chips and its hint | xxs 2 |
| Group | rows of a pick list; chips; keys of a combo; tabs | xs 3 |
| Control | row padding; chip padding; shortcut row padding | xs × s (3 × 5) |
| Strip body | row, group, field, hairline | m 8 |
| Strip | padding; title block, body, faders | l 13 |
| Desk | strip and strip | xl 21 |
| Page | header and desk; page title and tabs | xxl 34 |
| Card | top padding; side inset | xl 21; xxxl 55 |

Layout's plates:

| Level | Between | Step |
|---|---|---|
| Text pair | layer title and caption | xxs 2 |
| Group | rows in a zone; rows on the Hidden slab | xs 3 |
| Control | a row's side padding; zone name and its rows | s 5 |
| Tile | tile padding; icon and name | m 8 |
| Plate | zone and zone; the plate's side padding | l 13 |
| Stack | layer and layer (slab edge to next plate) | xl 21 |
| Page | header and plates | xxl 34 |
| Card | top padding; side inset | xl 21; xxxl 55 |

Groups' plates and inspector:

| Level | Between | Step |
|---|---|---|
| Text pair | plate title and caption; "Show" and its chips; name field and its caption | xxs 2 |
| Group | rows in a zone; pool chips; inspector chips; zone squares; layer rows | xs 3 |
| Control | a row's side padding | s 5 |
| Indent | a face and its members | l 13 |
| Tile, field | tile padding; inspector fields | m 8 |
| Plate, card body | zone and zone; inspector columns, hairline, footer row | l 13 |
| Stack, card | plate and plate; inspector padding; its columns | xl 21 |
| Page | header and plates | xxl 34 |

The chains each page must keep (each step at least 1.4 times the last):
rows in a zone → tile padding → zone gap → layer gap → header gap
(3 → 8 → 13 → 21 → 34); text pair → group → strip body → strip padding →
strip gap (2 → 3 → 8 → 13 → 21); in the inspector, "Show" and its chips →
chip and chip → field and field → body blocks → columns (2 → 3 → 8 → 13 → 21).

### Alignment

A row's highlight reaches `s` past its text on each side, into the strip's or
tile's padding, so the row's label lines up with the title above it while the
highlight still has room. In a zone tile, the zone's name starts at the rows'
text edge.

## 6. Control sizes

| Thing | Size | Rule |
|---|---|---|
| Control (desk rows, widget rows, group faces, chips, fields, zone squares, layer rows, buttons, shortcut rows, the pool filter) | 25 tall | `Gap.control` = `Ink.line(Ink.label) + 2 × Gap.xs` |
| A row holding Omarchy's switch | 28 tall | `Gap.switchRow` = 22 + 2 × xs |
| Row with a caption | grows | label line + xxs + caption lines + 2 × xs |
| Chip | text + xs × s padding | label size, `xs` apart |
| Keycap | caption line + 2 × xxs tall, text + 2 × s wide, at least square | caption size, bold; height from `FontMetrics`, not the text |
| Badge, count pill | `Ink.line(Ink.caption)` (16) tall, s side padding | caption size, fully round |
| Row and face icon | 20 | `Style.space(20)` |
| Pick ring | 14, with a 6 dot | ring and dot share parity so the dot is on the ring's centre pixel |
| Fader | name line, xs, a 2 px track; knob 8 × 16 | name at label size, value at label size secondary |
| Footer line | `Ink.line(Ink.caption)` | |
| Inspector | at most 670 wide; columns 148 and 240 | `Style.space(…)` |
| Plate | at most 1380 wide, at least xxxl tall | centred on the screen's middle |
| Zone tile | at least 170 wide; a chip never under 80 | the longest widget name fits |
| Desk strip | at least 240 wide | the longest label fits |

## 7. Corners

Every radius comes from the theme's window rounding, `Style.cornerRadius`
(Hyprland's `decoration:rounding`), stepped down as things nest so a control
is never rounder than what holds it. None comes from the tilt.

| Token | Value | Used for |
|---|---|---|
| `Round.card` | corner | The Preferences card |
| `Round.container` | min(corner, 8) | Zone tiles, desk strips, inspector cards, the pool, a dropdown's list, tooltips |
| `Round.control` | min(corner, 5) | Rows, faces, chips, fields, layer rows, buttons, the preview box, a fader's or chip row's marked area |
| `Round.small` | min(corner, 3) | Keycaps, zone squares and the camera's square in a zone map |
| fully round | height / 2 | Dots, badges, count pills, switch knobs, the pick ring |

(The caps are `Style.space(8)`, `space(5)`, `space(3)`, so they scale with
the font.)

- On a square theme (Cumulus, corner 0) everything is square.
- A tile under the camera's cap keeps square top corners so the black meets
  it flush: `ZoneTile { topRadius: capped ? 0 : radius }`
  (`LayoutEditor.qml:1488`).
- A ring or outline drawn `d` outside a shape takes that shape's radius plus
  `d`, but only when the shape is rounded: `r > 0 ? r + d : 0`, so a square
  theme keeps square rings (the focus ring, `Preferences.qml` focusRing,
  takes the focused control's radius; a fader knob's ring the knob's). One
  drawn `d` inside takes the radius minus `d`, never below 0 (a tile's focus
  outline 3 in: `ZoneTile.qml:244`).
- A slab edge or shadow band under a shape is square at the top and takes
  the shape's radius at the bottom.

## 8. Parts

### The card

The window is a layer-shell overlay on the focused screen; the page is a
card one edge gap inside it, held off the bar's side by what a floating bar
would take (PREFS-102). The card is the popups' background, opaque, a 1 px
border in `Commons.Color.popups.border`, `Round.card`, no shadow
(`Preferences.qml:756`). Padding: `xl` top and bottom, `xxxl` each side.

### The header

One row: the page title (page role), `xxl`, the tabs (`xs` apart), a filler,
the Tuning tab when it is there, `xxl`, Close.

- A tab is its number as a keycap, `s`, its name at label size. Padding
  `s` × `m`. The current tab is primary and bold, its keycap in the accent;
  others are secondary, primary under the pointer (PREFS-6, PREFS-7).
- One accent underline, 2 px, fully round, under the current tab, gliding
  with the page slide (`Preferences.qml:945`).
- Close is the `esc` keycap, `s`, "Close" at label size, secondary, primary
  under the pointer (PREFS-2).

The pages start `xxl` under the header: that line is the plates' and desks'
top edge (PREFS-106, PREFS-124).

### The key legend

Bottom left of every page, beside the inspector (PREFS-103): one line per
key, a column of keycaps (`xs` apart within a combo) and a column of words at
caption size, secondary. Columns `l` apart, lines `s` apart. The keys'
column is as wide as the widest set any page shows (Shift with h j k l), so
the words start at one place on every page (`KeyLegend.qml:18`). The legend
changes with focus and always says what the focused control's keys do. A
page with a legend has no footer, unless a save failed (PREFS-5).

### The keycap

`KeyCap.qml`: caption size, bold, on the font's baseline; height from
`FontMetrics` plus 2 × `xxs` (a fallback glyph's taller line must not grow
it), width text plus 2 × `s`, at least square; fill the foreground at 7 %,
a 1 px border at 22 %, `Round.control`.

### Desk strip

`DeskStrip.qml`, a `ZoneTile` without a name: the tile colour, its 1 px
edge, `Round.container`, the 6 px slab edge (PREFS-125). Inside, `l`
padding, then three blocks `l` apart:

1. The title block: title (section), `xxs`, caption (caption, secondary,
   wraps).
2. The body: controls `m` apart; a group of pick rows is one control with
   its rows `xs` apart; a hairline has `l` on each side.
3. The footer block: an optional footnote (caption, secondary), then the
   faders `m` apart, each the strip's inner width.

Every strip on a desk is as tall as the tallest; the space goes between the
body and the footer block.

### Desk row

`DeskRow.qml` (PREFS-129): its label, an optional caption `xxs` under it,
and at the right Omarchy's `ToggleSwitch` (a switch row), or at the left a
pick ring `m` before the label (a choice row), or neither with the label in
the accent (an action row). Height `Gap.control`, or `Gap.switchRow` with a
switch; padding `xs` × `s`; the surface reaches `s` into the strip's padding
so the text stays in line with the title. `Round.control`. Hover: the hover
fill. Cursor: section 10.

### Choice chips

`DeskChoice.qml` (PREFS-128): one row of chips sharing the strip by their
labels, `xs` apart, padding `xs` × `s`, label size, `Round.control`. When
the labels would not fit whole at the label size (a large base size on a
narrow strip) the chips step down: the caption size with `s` at the sides,
then the caption size with `xs` at the sides; only past that do they elide
(`DeskChoice.labelFits`, `chipFont`, `chipPad`). A
labelled choice is a field: its label (label role), `xxs`, the chips, `xxs`,
its hint (caption, secondary).

### Fader

`Fader.qml` (PREFS-127): the name at the left (label, primary) and the value
at the right (label, secondary; accent and bold while a draft is pending),
on one line; `s` under it the rail with its 2 px track, ticks, default mark
and the 8 × 16 knob (`Round.small`). Faders are `m` apart.

### Shortcut row

`ShortcutRow.qml` (PREFS-76): a desk row with its keycaps at the right (a
combo's keys `xs` apart, the "+" between them at caption size, secondary).
Same height and padding as any row: `Gap.control`, not taller.

### Layer plate

`LayerPlate.qml` (PREFS-99): one layer, tilted (section 12), in seven
columns `l` apart across the plate's width less `l` padding each side: the
label column, the five zones in bar order, and a spare column that mirrors
the label's so Center stays on the screen's middle
(`PreferencesModel.layerColumns`, `PreferencesModel.js:186`). The label
column holds the title (section), `xxs`, its caption (caption, secondary);
the count ("14 widgets", "Empty") sits in the spare column on the caption's
line, caption size, secondary.

### Zone tile

`ZoneTile.qml` (PREFS-99, PREFS-106): the slab edge, the surface
(`Round.container`, a 12 % hairline), the zone's name at the top (caption,
secondary; primary for the cursor's zone, DemiBold on its own layer), `s`,
then a window of rows `xs` apart that scrolls when the layer gives the tile
less room than its rows need, with fades over the rows cut at its edges and
a thin thumb at its right edge. Padding `m`. The zone name starts at the
rows' text edge. An empty tile says "Empty" (caption, secondary).

A slab (the Hidden layer, solid; the tray, dashed) is one tile across the
five zones' columns, no zone names, its chips five to a row, `xs` apart, the
same spacing as rows in a zone (PREFS-107, PREFS-97).

### Widget row (chip)

A row in a zone (`LayoutEditor.qml` `Tile`): `Gap.control` tall, the tile's
chip width, `Round.control`; the icon (20), `m`, the name (label), and for a
group a count pill at the end. At rest the text colour at 6 %; hover 14 %;
cursor: section 10. Hidden widgets read at secondary.

### Inspector card

A card in front of the plates, bottom right, at most 670 wide, that edits
the thing under the cursor: Layout's (PREFS-101, PREFS-26) and Groups'
(PREFS-116). `Round.container`, the tile colour, a 16 % hairline, its shadow
(section 11). `xl` padding all round; columns `xl` apart; inside a column,
fields `m` apart; blocks (the columns, a hairline, the row under them) `l`
apart.

The first column is the thing itself: a preview box (`xxxl` tall,
`Round.container`, the background darkened 20 %), its name (section), `xxs`,
what it is (caption, secondary).

Its fields are built from `LayerPicker`, `PrefsZoneMap`, `PrefsToggle`,
`PrefsDropdown`, `ShortcutRow`, `PrefsChoice` and Omarchy's `Button`, and
follow the desk's rules, not the kit's own sizes:

| Part | Rule |
|---|---|
| Field label ("Show", "Layer", "Zone", "Shortcut") | label role, primary, regular; `xxs` to its control |
| Chips (`PrefsChoice`) | label size, `xs` apart, padding `xs` × `s`, `Round.control` |
| Toggle row (`PrefsToggle`) | our own row, not the kit's `Toggle`: `Gap.switchRow` tall, label at label size and regular, no surface at rest; hovered or focused, `Round.control` reaching `s` outside the text |
| Layer rows (`LayerPicker`) | `Gap.control` tall, `xs` apart, the parallelogram `m` before the label, `Round.small` |
| Zone squares (`PrefsZoneMap`) | `Gap.control` tall, `xs` apart, `Round.small`; its caption `xxs` under it |
| Buttons ("Change icon", Dissolve) | label size, padding `xs` × `s`, `Round.control` |
| Hint under a field | caption, secondary, `xxs` under it |
| Fields in a column | `m` apart |

### Tooltip

A name tip after 450 ms on a chip (PREFS-100): `Round.container`, the
background tinted 10 %, a 16 % hairline, padding `m` above and below and
`l` at the sides (a surface floating over the page, one step past its own
`m` gaps, so it does not read as a loose chip); the icon, `m`,
the name (label), `m`, the id (caption, secondary). It fades in 110 ms; the
next within 600 ms shows at once.

## 9. Page structures

There are three. Pick the one that fits what the page edits.

### Desk of strips (Look, Behavior, Tuning)

For settings: rows, choices and faders. `DeskPage.qml` (PREFS-124): one
plate, tilted like the layers, its top at the layers' top line, as wide as
the layers and centred on the same axis, without the label or count column.
The strips (`DeskStrip`, the page's children) share its width equally, `xl`
apart, and are all as tall as the tallest. A tall plate tilted back is seen
wider at its near edge, so the desk narrows until that edge stays on the
page (`DeskPage.qml:76`). The legend is at the bottom left.

The cursor walks the controls (PREFS-126, `DeskModel.js`): j/k down and up a
strip and on into the next, h/l a value or the next chip, and past a row's
end the same row of the next strip, Tab the next strip's first control. A
control on a desk declares `deskStops`, `deskHome`, `deskStop` and
`deskFocus(stop, reason)`, and `keyHints` for the legend.

### Plates of zone tiles (Layout, Groups)

For things placed on the bar. `LayoutEditor.qml`: a plate per layer, each
seven columns of `ZoneTile`s, stacked down the page with `xl` from one
plate's slab edge to the next plate. The stack has a fixed room, from the
header's band down to the legend's band; the plates share it by what they
ask for, never below a name and one row, and a fuller zone scrolls inside
its tile (PREFS-106, `PreferencesModel.shareLayers`). The Groups page is two
of these plates, the groups and the pool, the first served first (PREFS-109,
PREFS-115).

### Inspector card

For the detail of one thing. It stands in front of the plates at the bottom
right, opens on Enter or a click and closes on Esc (PREFS-101, PREFS-116).
On Layout the thing is pulled out of its plate: its place becomes an accent
outline, and a dashed accent leader runs from a dot there to a flat copy of
the chip, tilted 1.5°, 30 px above the card (PREFS-101). Tab walks the
card's controls and wraps inside it.

## 10. Focus and the cursor

- **The focus ring** (PREFS-108): one 1 px accent hairline `s` outside the
  focused control, following `Window.activeFocusItem` across the card,
  gliding in 120 ms. Its radius is the focused control's plus `s`, and
  square when the control is square (section 7).
  It is clipped to the scrolling area its control is in.
- **Controls that draw their own cursor** opt out with `ownsFocusRing: true`
  (a control) or `ownsFocusRings: true` (a whole page, as the desks do).
- **The desk cursor** (PREFS-129): the control's area takes the focus fill
  over the strip's own colour and the focus border (`Border.controlSpec("focus", …)`).
  A pick group is marked as one, the cursor's row the selected fill over it.
  A row of chips is marked as one, the cursor's chip with its own fill and
  ring. With Tuning's Mark the whole control off, only the switch, pick
  mark, chip or knob takes a ring `s` out (PREFS-132).
- **Plates**: the cursor's zone reads primary on every layer and bold on its
  own; the cursor's tile rises (section 11); the cursor's chip takes the
  focus fill and border while the plate has focus, the selected fill and a
  35 % hairline while it does not.
- **Hover** is a 14 % fill of the text colour on rows and chips; on text it
  is the step between tiers.
- **Landing places** are accent outlines (`DropOutline`, an empty tile
  waiting for a drop, a pulled-out chip's place).

## 11. Elevation and shadows

Preferences draw depth as flat bands under things, not blurred shadows. A
band is black, square at the top and rounded at the bottom like its shape,
half a pixel in from each side so nothing shows past the shape's ring, and
drawn antialiased (it is seen through the tilt). Nothing shimmers while it
moves.

| Level | What | Depth | Band | Code |
|---|---|---|---|---|
| 0 | The card | none | no shadow | `Preferences.qml:756` |
| 1 | A plate | flat on the page | none | `LayerPlate.qml` |
| 2 | A tile or strip at rest | 6 px slab | 45 % dark theme, 30 % light | `ZoneTile.qml:99` |
| 3 | The cursor's tile or strip | risen 10 | its slab edge reaches down to where it rested, one block, 16 px, no seam | `ZoneTile.qml:35`, PREFS-104, PREFS-125 |
| 3 | The cursor's chip | risen 8, grown to 103 % | a band 3 below its rise (11), 30 % dark, 20 % light; its tile's opaque colour under its fill | `LayoutEditor.qml:1581`, PREFS-104 |
| 3 | A Groups list chip / pool chip | risen 4 / 8 | the same band | `GroupsEditor.qml:2417` |
| 3 | A desk control (with Controls rise on) | risen 8, 103 % | the same band, on a plate of the strip's colour | `CursorLift.qml`, PREFS-132 |
| 4 | The chip pulled out to the inspector | flat copy, tilted 1.5° | a 6 px band | `LayoutEditor.qml:1249` |
| 5 | The inspector card | in front of everything on the page | a block 10 below it, inset 8 each side, 30 % | `LayoutEditor.qml:1758`, `GroupsEditor.qml:1505` |
| 6 | The name tip | above the inspector | none | `LayoutEditor.qml:1136` |

Rules:

- What rises casts a band as tall as its rise (plus the 3 px it keeps from
  its shadow), so height reads at once.
- A risen thing draws over its neighbours (`z`) and has an opaque colour
  under its fill, so what it rises over does not show through.
- Rises glide up and drop in the same frame the cursor leaves (`Rise.qml`),
  so a fast cursor leaves no trail.
- A slab (Hidden, tray), a chip that is lifted or pulled out, and a tile
  that flows do not rise.
- Desk controls do not rise by default: Tuning's Controls rise is off, so
  they keep their fill and ring (PREFS-132). Strips and tiles still rise.
- These depths are lengths in the picture, not gaps: they are not on the
  spacing ladder.
- The bar's own islands use `EffectSurface` (a `RectangularShadow` with
  blur, `EffectSurface.qml`), from the theme's shadow settings. That is the
  bar, not Preferences: do not use blurred shadows on a Preferences page.

## 12. Pages in perspective

The Layout and Groups plates and the desks are drawn as an exploded view of
the bar: each plate is tilted back about its top edge (PREFS-99). Behavior's
"Pages in perspective" (`powerbarPreferencesTilt`, default on, PREFS-70)
lays them flat; Omarchy's animations switch does not change the tilt.

| Number | Value | Code |
|---|---|---|
| Angle | 34° back, about the X axis | `LayoutEditor.qml:96` |
| Plane distance | `Style.space(1600)` (Qt's `Rotation.distanceToPlane`) | `LayoutEditor.qml:97` |
| Origin | the plate's top edge, at the camera's axis (the screen's middle, measured) | `LayerPlate.qml:36`, `LayoutEditor.qml:116` |

Every page takes these from the Layout editor (`layout.tilt`,
`layout.planeDistance`), so all pages tilt alike and a page switch changes
nothing of the camera.

A point `v` down the plane from its top edge is seen `v cos θ / (1 − v sin θ / d)`
below it; a line `u` from the axis is seen `u / (1 − v sin θ / d)` from it.
So the top edge keeps its width, lines converge on the screen's middle, and
the near edge is seen wider. `PreferencesModel.js` has the functions:

| Function | Gives | Line |
|---|---|---|
| `tiltedHeight(h, θ, d)` | how tall a plate `h` tall is seen: `h cos θ / (1 − sin θ · h / d)` | 205 |
| `tiltedPlaneHeight(seen, θ, d)` | the plate height for a seen height (the inverse) | 210 |
| `tiltedDepth(y, θ, d)` | the plane's own `v` for a seen `y`: `y d / (d cos θ + y sin θ)` | 269 |
| `tiltedSpread(u, y, θ, d)` | how far from the axis a line `u` out is seen at seen height `y`: `u (1 + sin θ · y / (d cos θ))` | 273 |
| `stackLayers(heights, θ, d, gap)` | each plate's box top and seen height, `gap` between pictures | 252 |
| `shareLayers(demands, floors, room, θ, d, gap, first)` | plate heights that fit `room`, shared out, floors kept | 222 |

At 34° and 1600:

| Plate height | Seen | Ratio | Near edge wider by |
|---|---|---|---|
| 55 | 46.5 | 0.85 | 2 % |
| 100 | 85.9 | 0.86 | 4 % |
| 200 | 178.3 | 0.89 | 8 % |
| 300 | 277.8 | 0.93 | 12 % |

How to use it:

- A plate's box is as tall as its seen picture, so plates stack without
  overlap. Lay out on the plane (the plate's own coordinates); stack by seen
  heights.
- Ask for plane heights, convert to seen to fit the room, convert back:
  `shareLayers` does both ways.
- A plate turns about its top edge, so when its height animates only its
  bottom moves (`LayerPlate.qml:32`).
- Anything drawn on a plate that must line up with something on another
  item (the camera's shade) works in `v`, from `tiltedDepth`.
- Hit-test through the tilt by mapping points, not by eye
  (`LayoutEditor.qml:860`).
- Every tilted rectangle is drawn antialiased, or its edges step. The
  desk's plate draws through one multisampled layer (`layer.samples: 4`) so
  the kit's switches and chips on it are smoothed after the turn; flat,
  there is no layer (`DeskPage.qml:135`). The layer keeps room above for a
  strip's rise.
- A desk narrows so its near edge stays on the page (`DeskPage.qml:76`).

## 13. The camera over the plates

On a screen with a camera at the top, the notch is drawn as a cap over the
pages (PREFS-24, `CameraShaft.qml`, `BeamShade.qml`, `shaders/beam.frag`):
solid black from just under the card's outline down to a torn paper edge a
little above the plates, a lighter fringe along the tear, and a soft shade
under it. It lies on the bar layer's own tilted plane, as wide as the
Center column, so its sides run on the lines that layer's Center tile edges
lie on.

- The eye: a 16 px ring round a 6 px dot, 14 px under the page's top,
  "camera" 6 px below it, both white at half strength (the cap is black on
  every theme).
- One shader draws the cap. Each item it crosses (Center tiles, the Hidden
  slab's Center part, strips under the column) draws the same shader over
  its own surface and under its rows, told its top and bottom as `v`
  (`vTop`, `vBottom`), so the tear and the shade cross a tile's edge without
  a step (`ZoneTile.qml:143`, `DeskStrip.qml:92`).
- With `shadeSpread` above 0, a second quad behind the plates and a clipped
  copy on each tile and strip carry the shade past the column's sides with a
  raised-cosine fall-off.
- The bar layer's Center tile has square top corners under the cap.
- While pages slide, Preferences draws one still camera behind both pages,
  and theirs hide (`Preferences.qml:1112`).
- Without a camera nothing of it draws, and Center sits in its own place.

The numbers live in `TuningModel.SECTIONS` (`TuningModel.js:13`), are read
through `Tuning.values.<key>` and are page px through `Style.space(1)`. The
defaults are the look that ships; the Tuning page moves them
(`powerbarTuning`, PREFS-132).

| Key | Meaning | Default | Range |
|---|---|---|---|
| `gapAbove` | the tear's line above the plates' top edge, px | 35 | 0–40 |
| `tearDepth` | how far the edge wanders either way, px | 8 | 2–40 |
| `grain` | bumps per px, thousandths | 31 | 5–80 |
| `octaves` | detail of the noise | 3 | 1–5 |
| `seed` | the edge's noise | 24 | 1–60 |
| `fringeWidth` | the fringe past its own torn line, px | 12 | 0–12 |
| `fringeStrength` | % | 13 | 0–100 |
| `fringeSeed` | the fringe's noise (not the edge's, so it is ragged) | 12 | 1–60 |
| `shadeBlur` | px either side of the shade's middle | 4 | 0–60 |
| `shadeDrop` | px from the edge to the shade's middle | 7 | 0–80 |
| `shadeStrength` | % at the edge | 16 | 0–100 |
| `shadeSpread` | px past each side of the column | 0 | 0–80 |

The fringe is rgb(0.54, 0.57, 0.71) on a dark theme and the popups'
background lightened 70 % towards white on a light one (`BeamShade.qml:156`).
A grain of noise hides banding; the column's sides keep a soft 1.5 px edge
against stepping on the tilt.

## 14. Motion

Motion follows Omarchy's one switch, as Omarchy's own widgets, panels and
`qs.Ui` kit do. `omarchy toggle animations` turns Hyprland's
`animations:enabled` off (for machines that render on the CPU); Omarchy's
`Style` reads it into `Style.reduceMotion` at start and on every reload
(`Style.qml:363`, `:477`). Then:

- **Every duration goes through `Style.duration(ms)`**, which returns 0 when
  motion is off (`Style.qml:365`). A `Behavior` or animation written this
  way needs no `enabled:` of its own: at 0 ms the value lands at once. That
  covers opacity and colour too; Omarchy keeps no short fades with motion
  off.
- **Anything that runs on its own** (a spinner, a scrolling label, a loop, a
  `FrameAnimation`, a `Timer` that steps motion) is gated with
  `running: … && !Style.reduceMotion`, as `Ui/Button.qml:197` and the media
  widget's scroll do.
- **A one-shot animation started from code** (the page slide's
  `slide.restart()`) checks `Style.reduceMotion` and sets the end value
  instead of starting.
- **The curve** for things appearing or moving in answer to the user is
  `Style.easeOut` ([0.23, 1, 0.32, 1], `Style.qml:371`); `Easing.OutCubic`
  is the kit's common short ease. Do not copy the curve's numbers; use the
  token.

A plugin's own animation switch, if it has one, is only a second "off":
Omarchy's switch off stops the plugin's motion whatever its own says.
Powerbar keeps its Animations row (`powerbarAnimations`, PREFS-70) for
people who want a still bar on an animated desktop; `bar.animationsEnabled`
is that option and `!Style.reduceMotion` (Bar.qml `systemMotion`,
INTEG-21), and while Omarchy's switch is off the row keeps showing its own
value with a caption saying why nothing moves. "Pages in perspective" is not
motion and stays.

| What | Duration | Curve | With motion off | Code |
|---|---|---|---|---|
| Page slide: the page out, the next in beside it, a card's width, plates moving in their own plane under a still camera | 240 ms | `Style.easeOut` | the new page at once | `Preferences.qml:163`, `:1077` |
| The tab underline | 240 ms | the same, on the same clock | at once | `Preferences.qml:966` |
| A rise (tile, chip, desk control) | 120 ms up | OutCubic | up and down at once | `Rise.qml` |
| A rise ending | 0 (the same frame) | | | `Rise.qml` |
| Focus ring glide | 120 ms | OutCubic | jumps; also off while pages slide | `Preferences.qml:899` |
| Plate height, plate y when a lift adds a row | 140 ms | OutCubic | at once | `LayerPlate.qml:47`, `LayoutEditor.qml:1302` |
| Card opening | 140 ms opacity | OutCubic | at once | `Preferences.qml:768` |
| Inspector in and out | 140 ms opacity, 160 ms scale from 97 % at its bottom edge | OutCubic | at once | `LayoutEditor.qml:1723`, PREFS-101 |
| Pulled chip following | 120 ms | OutCubic | at once | `LayoutEditor.qml:1257` |
| Tile scroll | 120 ms | OutCubic | at once | `ZoneTile.qml:259` |
| Name tip | 110 ms fade, after 450 ms rest | OutCubic | at once | `LayoutEditor.qml:1142` |

Rules:

- Cursor moves are instant; only what they cause (a rise, the ring) glides.
- Nothing in the cursor's state lingers: a chip's fill, growth and shadow go
  with it in one frame (PREFS-104).
- A switch during a slide carries on from where the strip is.
- One clock for things that move together: the slide and the underline share
  `turnDuration` and `turnCurve`.
- Stay under 300 ms. Ease-out for things entering, never ease-in.
- With motion off, things are where they end, at once, fades and colour
  changes included. The tilt stays.

## 15. Light and dark themes

Powerbar reads a theme as light when the popups' background has luminance
over 0.5 (`LayoutEditor.qml:109`, `AppearanceModel.luminance`) and passes
`lightTheme` down to tiles, strips, desk controls and the camera.

| Thing | Dark | Light |
|---|---|---|
| Slab edge | black 45 % | black 30 % |
| Chip and control band | black 30 % | black 20 % |
| Inspector shadow | black 30 % | black 20 % (the band rule) |
| Fringe | rgb(0.54, 0.57, 0.71) | background lightened 70 % to white |
| Cap, eye, "camera" | black, white 50 % | the same: a camera is black on every theme |

Everything else is theme colour at fixed alphas, so it follows any theme.
Do not hard-code a hex colour.

## 16. Accessibility

Contrast of the text colour at each alpha on Cumulus (text #eee2cc; the
card #1a3d57; a tile is the card tinted 6.5 % with the text colour, a bar
layer tile 9 %):

| Alpha | On the card | On a tile | On a bar layer tile | WCAG AA (4.5 : 1) |
|---|---|---|---|---|
| 1 (primary) | 8.9 : 1 | 7.5 : 1 | 7.1 : 1 | passes |
| 0.786 (secondary) | 6.1 : 1 | 5.4 : 1 | 5.1 : 1 | passes |
| 0.7 (today's legend, fader names) | 5.2 : 1 | 4.6 : 1 | 4.4 : 1 | fails on the bar layer |
| 0.55 (today's captions, inactive tabs) | 3.8 : 1 | 3.5 : 1 | 3.3 : 1 | fails |
| 0.45 | 3.1 : 1 | 2.8 : 1 | 2.7 : 1 | fails |
| 0.382 (disabled) | 2.6 : 1 | 2.4 : 1 | 2.4 : 1 | exempt: WCAG excludes inactive controls |
| 0.3 | 2.1 : 1 | 2.0 : 1 | 2.0 : 1 | fails |

- Every word a user reads to use a page is primary or secondary.
- Check a new theme the same way: the secondary tier must stay at 4.5 : 1 on
  the lightest surface text sits on (the bar layer's tiles).
- Every interactive item has `Accessible.role`, `Accessible.name` (and a
  description for a caption); decorative ones `Accessible.ignored: true`.
- Everything works from the keyboard; the legend always says how.
- Size never goes under the caption step (10 at the default base) and
  follows the user's base size.

## 17. Build a new page

1. Choose the structure: a desk of strips (settings), plates of zone tiles
   (placing things on the bar), and an inspector card for one thing's
   detail.
2. Start from the existing parts: `DeskPage` and `DeskStrip` with `DeskRow`,
   `DeskChoice`, `DeskPickGroup`, `Fader`, `ShortcutRow`; or `LayerPlate`,
   `ZoneTile` and the Layout editor's inspector.
3. Set every text with `InkText` and a role. Names are labels; explanations,
   counts and hints are captions.
4. Set every gap from `Gap`, by the level it sits at (section 5). Put a
   hairline at `l` from both neighbours.
5. Make every control `Gap.control` tall (`Gap.switchRow` with a switch),
   padded `xs` × `s`, its highlight reaching `s` past its text.
6. Set every radius from `Round`. A ring outside a shape adds its offset.
7. Take tilt and plane distance from the Layout editor; draw tilted shapes
   antialiased; stack by seen heights.
8. Let the cursor rise and cast its band through `ZoneTile`, `Rise` or
   `CursorLift`; give it `lightTheme`.
9. Give every control `keyHints` for the legend and, on a desk, the desk's
   stops; set `ownsFocusRing` if it draws its own cursor.
10. Run every duration through `Style.duration(ms)` and gate anything that
    runs on its own on `!Style.reduceMotion`; durations from section 14.
11. Check the page at base size 10 and 16, on a square and a rounded theme,
    on a light theme, under the camera with the tilt on and off, on a
    1280 × 800 screen. Do it in a box (`tools/box/`), never on the user's
    desktop.

## 18. Review checklist

| Check | Rule |
|---|---|
| A size other than 19, 14, 12 or 10 (at base 12) | Use a role; 11 and 16 are not used |
| A text alpha other than 1, 0.786 or 0.382 | Use a tier; hover is the only in-between |
| A name at caption size, or an explanation at label size | Names are labels, explanations captions |
| A field label in bold or dimmed | Label role, primary, regular |
| A raw `Style.space(n)` gap | A `Gap` step for its level |
| A gap the same as the one inside or outside it | Each level ≥ 1.4 × the one inside |
| A negative margin | A column with `xxs` |
| A hairline at the controls' gap | `l` on each side |
| A control not 25 tall (28 with a switch) | `Gap.control`, `Gap.switchRow` |
| A row's label not under the title's left edge | Highlight reaches `s` past the text |
| A radius from a fixed number or from the tilt | `Round.card`, `container`, `control`, `small` |
| A control rounder than its container | Step down the tokens |
| A blurred shadow on a page | A flat band as tall as the rise |
| A shadow or edge with one alpha for every theme | Dark and light values |
| A tilted edge without antialiasing | `antialiasing: true`, or the desk's multisampled layer |
| A raw `duration:` number, or motion gated only on a plugin's own switch | `Style.duration(ms)`, or the plugin's switch and `!Style.reduceMotion`; loops on both |
| A curve's numbers copied in | `Style.easeOut` |
| A ring rounded on a square theme | `r > 0 ? r + d : 0` |
| A rise that fades out | Drops in the same frame |
| Secondary text under 4.5 : 1 | Secondary is 0.786 |
| A control the legend does not explain | `keyHints` |

## 19. Sources

- The lab: [`docs/hierarchy-lab/hierarchy-lab.html`](../hierarchy-lab/hierarchy-lab.html)
  (today and golden drawn from the same tables; problems per page; level
  tables) and `docs/hierarchy-lab/captures/`.
- Tim Brown, [More meaningful typography](https://alistapart.com/article/more-meaningful-typography/)
  (A List Apart): modular scales from a ratio such as φ.
- [modularscale.com](https://www.modularscale.com/): φ and its roots as scale
  ratios.
- Chris Pearson, [Golden ratio typography calculator](https://grtcalculator.com/):
  line height as size × φ.
- W3C, [WCAG 2.2, contrast (minimum)](https://www.w3.org/TR/WCAG22/#contrast-minimum):
  4.5 : 1 for body-size text; inactive components are exempt.
- Nielsen Norman Group, [Proximity principle in visual design](https://www.nngroup.com/articles/gestalt-proximity/):
  related items closer than unrelated ones.
- Omarchy's `Style` (`/usr/share/omarchy/shell/Commons/Style.qml`): `fontPx`,
  `font.*`, `space`, `cornerRadius`, `duration`, the state fills.
