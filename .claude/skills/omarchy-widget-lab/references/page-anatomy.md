# Page anatomy

Section by section, what each part of a lab page is for and what makes it
good. `assets/reference-lab.html` shows every section finished while options are
still being compared; `assets/reference-final.html` shows the same page
once the design is locked (no baseline, both modes side by side).

## Contents
- Visual language
- Header and hero
- Decisions
- The rule
- Comparison
- Validation sections
- Drag or motion labs
- Edge cases
- Highlight states
- Motion table
- Implementation mapping
- Research
- Copy rules

## Visual language

- **Two worlds.** The page chrome follows the viewer's light or dark theme
  (tokens on `:root`, dark under the media query and `[data-theme="dark"]`).
  The bar world (islands, highlights, Preferences mock) always uses the
  user's Omarchy theme from `widgets.js` (`applyTheme()`), on their
  wallpaper band (`.stage`). The bar should look like their desktop in both
  page themes.
- **Type.** Instrument Sans for the page, JetBrains Mono for numbers, formulas,
  chips and anything bar-side (it matches Omarchy's default monospace).
  One scale: 46 / 24 / 16 / 15 / 13.5 / 12.
- **Accent.** One muted accent (lavender family) for controls and formulas;
  green and orange only in measured good and bad chips.
- **Structure encodes something.** Cards only for edge cases and the
  formulas panel; numbered lists only for real sequences (implementation
  steps, drag rules in order of application).
- **Zoom.** Bars render at 2× (1.6× on phones) so highlights are legible;
  captures are 4×, so they stay sharp. A zoom control offers 1× (true size).

## Header and hero

- `<title>`: a two to four word name ("Powerbar Spacing Lab").
- `h1`: the thesis as a name ("One cell, one inset").
- Lead: one paragraph with the core idea in bold, and a sentence saying the
  preview is the user's own bar on their wallpaper.
- Controls: option switch (Today first), bar size, spacing, rounding, zoom,
  "Every highlight at once" (the consistency test: all fills drawn together),
  "Boxes and gaps" (x-ray: dashed layout boxes, ink bands, measured gaps
  under the island).
- Hero: the whole bar, three zones, interactive (hover, click holds open,
  Tab focus ring, h/l inside compounds).
- Chips under it: the three or four measurements that decide the question,
  each with ✓/✗ from a stated threshold.
- A note on how to interact and where the pixels came from.

## Decisions

Added when the user locks something. A dated status pill, a title, a list of
what ships (bold name, one-line consequence), and optionally a Preferences
mock (`.prefs-card`) drawn to the real component with a live preview. Below
it, a naming table: chosen pair first, then rejected pairs with reasons.

## The rule

Left: the formulas panel, one row per formula: monospace formula, live
value, one-sentence meaning. Right: an x-ray demo of three items and two or
three "why" paragraphs, each opening with a bold claim ("Why the box and the
highlight must be the same thing."). Say what today does wrong in numbers.

## Comparison

One row per option, the same widgets (usually the right island), every
highlight on, x-ray gap labels, and the same chips per row so the numbers
line up vertically. Label rows with option names; one-line summaries.

## Validation sections

One per hypothesis the user raised, titled as the question ("Can equal gaps
borrow the cell's highlight?"). Left: the derivation as formula rows ending
in the bound. Right: a measured table across bar sizes and spacings, a note
on how it was measured (how many captures, alpha threshold), and small
demos that show the worst case and the catches.

## Drag or motion labs

When the question involves motion, build a live demo with persistent
elements and CSS transitions: controls for what moves and which timing, a
draggable ghost with keyboard arrows and a "Play a sweep" button, optional
boundary ticks, chips for gap, duration, peak speed (and its ratio to an
icon), and a table across the widget kinds. Rules listed in the order they
apply, each with its reason.

## Edge cases

A two-column grid of cards. Each card: title (the situation), two sentences
(what today does, what the proposal does, with numbers), and two mini bars,
"Today" above "Proposed", with the relevant item hovered or all highlights on.
When there are several proposals, add a switch above the grid choosing which
fills the "Proposed" row. Typical cases for bar widgets: icon, text and
compound at island ends; short text (EN) as an icon; narrow vs wide glyphs;
off-centre ink; oversized slots; badges; long text; values that change width;
a lone widget; vertical bars; drag gaps.

## Highlight states

A four-column grid of the same three widgets with the middle one in each
state: rest, hover, pressed, open, keyboard focus, activity, urgent, drop
target. Caption: the token or fill percentage and the timing.

## Motion table

Above it, the motion contract as a short numbered list: one switch (name the
config key and the Preferences row), motion never carries information alone,
logic does not depend on motion, sequences short-circuit (commit in the same
event when off), off means idle (no per-frame work).

Then the table: Change / Animations on (monospace: duration, easing) /
Animations off / Why it still reads (the static cue that carries the
meaning). Include what never animates (keyboard focus). Every interactive
demo must work with the page's Animations switch off, and its chips should
say so ("at once (Animations off)").

## Implementation mapping

An ordered list: bold imperative step naming the file or function, then one
or two sentences with real identifiers (`HighlightModel.inkRect`,
`slot.naturalWidth`, `PrefsChoice`). Include tests to add and how to verify
on the desktop.

## Research

Two columns of sources: linked title, then one muted line saying what it
contributed. Only sources that changed a rule or a number.

## Copy rules

- Sentence case everywhere; no ALL CAPS eyebrows; no "A · B · C" meta lines.
- Active voice; short sentences; numbers with units ("23–26 px", "150 ms").
- Name things the way users see them (islands, drawers, groups, the clock),
  and the design concept once, in the thesis.
- Findings as facts from code or measurement; limits stated plainly
  ("These are browser mockups; the live bar has not been checked").
