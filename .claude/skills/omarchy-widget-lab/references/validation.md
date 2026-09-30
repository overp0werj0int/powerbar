# Validating claims

A lab earns trust by never showing a number it did not measure. Three tools
cover almost everything.

## 1. Closed-form bounds

Write the claim as an inequality over the tokens, and solve it so it holds for
every widget, not just the ones on screen.

Example (equal gaps with overflowing highlights):
- spill of a glyph highlight = (C − ink) / 2, largest as ink → 0, so < C/2
- choose gap G = C/2 + 2
- clearance to the neighbour's glyph = G − spill = 2 + ink/2 ≥ 2 px, for any
  bar size and spacing; for text, G − a = 8 px
- overlap of two lit neighbours = spill₁ + spill₂ − G (positive for narrow
  pairs), which exposes the catch that needs a rule

Show the derivation as formula rows on the page, ending in the bound.

## 2. Measurement over all captures

Run the bound against every capture in `~/.cache/powerbar/widgets`, not only
those in the lab, with a strict alpha threshold (> 8) so anti-aliased fringes
count. Tabulate across bar sizes (26, 38) and spacings (0, 4, 8). Report the
worst real case by name ("the tray chevron, 6.5 px wide: 5.25 px clearance").

```python
from PIL import Image; import os
d = os.path.expanduser("~/.cache/powerbar/widgets"); S = 4
for f in os.listdir(d):
    a = Image.open(os.path.join(d, f)).convert("RGBA").split()[3]
    box = a.point(lambda v: 255 if v > 8 else 0).getbbox()
    ink = (box[2] - box[0]) / S if box else 0
    ...
```

## 3. Simulation

For anything interactive, simulate the rule in a script before building the
demo:

- **Stability:** sweep the pointer or ghost across the row and back in small
  steps, count state changes; the ideal is one per boundary per direction.
  Report "10 of 10".
- **Distances:** track the worst distance between what the user holds and
  where it will land.
- **Motion:** peak speed of an ease-in-out sine move is π·d / (2·T). Compare
  each case with the common one (an icon) and keep ratios near 2 or below;
  durations stay under 300 ms (Emil Kowalski, `omarchy-widget-ux`).

## Checking fills and fades

When a rule changes opacity or colour, compute the result against the
strongest state it can meet. A fade meant to make the newest highlight win
must leave the older fill visibly below a fresh hover (open 22% × 0.45 ≈ 10%
against hover 13%).

## Honesty

- Say what the measurement covers ("40 captures, alpha > 8") and what it
  cannot ("captures taken in another state", "the live bar was not checked").
- If a capture might be unrepresentative, say so where it is used.
- Only claim today's behaviour from code you read; phrase it as what the code
  does.
