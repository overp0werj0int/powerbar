# Lab process in detail

How the Powerbar spacing lab was made, turned into a procedure. The skeleton
is fixed; the content changes with the question.

## Contents
1. Framing
2. Reading today's implementation
3. Collecting assets
4. Research
5. Options and the recommendation
6. Building the page
7. The one look and publishing
8. The first report
9. Iteration turns
10. Locking decisions, naming and the repo

## 1. Framing

Write the question as one decision: "How should Powerbar space icons, text
and compound widgets of different lengths, and how should their highlights
look?" List what the answer must cover (the user's words are the checklist:
"island ends, text like the clock, complex widgets, highlighting"). Note how
often users see the thing: hover and spacing are seen constantly, so motion
stays small.

Keep the user informed in short lines while you work ("Reading how Powerbar
packs widgets…", "Research done, building the page"): these sessions are long.

## 2. Reading today's implementation

Find the numbers the current design really uses, with file and line:

- Layout: widths (`implicitWidth`, fixed slots such as `Style.bar.iconSlot`),
  spacing properties, island padding, edge gaps.
- Highlights: geometry functions (`HighlightModel.pill`, `highlightGeometry`),
  inset, thickness, radius, fills (`Style.hoverFillFor`, `selectedFillFor`).
- Motion: durations and easing constants (`dragMotionDuration`, Behaviors),
  and which of them ignore the central flag: grep every `Behavior on`,
  `NumberAnimation`, `ColorAnimation`, `FrameAnimation` and animation timer,
  and list those without `enabled: animationsEnabled` (or equivalent) and any
  per-frame loop that runs while nothing moves. These go in the report and in
  an implementation step.
- Omarchy kit: `/usr/share/omarchy/shell/Ui/*.qml` (`WidgetButton`,
  `BarIconButton`) and `Commons/Style.qml` tokens (bar sizes, icon slot and
  canvas).
- Uncommitted work (`git diff`): model the working tree as "Today" and say so
  on the page if it differs from the last commit.

Write the baseline as a function in the page (`layoutToday`) that follows the
code exactly, quirks included. Problems you can prove from code (a highlight
wider than its pitch, a badge anchored above the bar, a highlight centred on
the slot rather than the ink) become findings and edge cases. Phrase them as
what the code does, and only claim what the code shows.

## 3. Collecting assets

```bash
python3 ~/.claude/skills/omarchy-widget-lab/scripts/collect_assets.py --list
python3 ~/.claude/skills/omarchy-widget-lab/scripts/collect_assets.py \
  --out <repo>/docs/<topic>-lab --face group-ai="AI" --face group-audio=" Audio"
```

- Captures come from `~/.cache/powerbar/widgets/<powerbarInstance>.png`,
  saved at 2 × device pixel ratio (the script detects the scale; pass
  `--scale` if detection fails). Widgets never shown have no capture.
- `--face` draws text faces with the user's monospace Nerd Font the way
  `WidgetButton` draws labels (12 px, 8.5 px margins): use it for group faces,
  mock values, or widgets without captures. Say on the page that these are drawn.
- Look at a composite before designing (paste captures side by side with PIL
  and read the image). Measured ink tells you most of the story: in the
  spacing lab, icon glyphs ranged 7–14.5 px inside fixed 27 px slots, the tray
  capture's chevron sat 14 px off-centre, and System update used a 38 px slot.
- If a capture looks like it was taken in an unusual state (a drawer open,
  a hover fill baked in), say so where you use it.

## 4. Research

Run 6–12 searches, in parallel where possible, across platform guidelines,
design-system docs and engineering write-ups; fetch a page only when the
search summary lacks the number you need. Useful angles are in
`research.md`. For each source keep one line: the rule or number it
contributes. Those lines become the page's "What the research says" list and
the Sources list in your reply (markdown links).

## 5. Options and the recommendation

- Today (baseline), then options. Two or three options is the sweet spot; an
  obviously weaker alternative is still worth showing when it teaches
  something (equal gaps taught why cells matter, and later won its place).
- Express each option as 4–7 formulas from tokens, with the live values beside
  them. Derive defaults so the familiar case is unchanged where possible (the
  standard bar kept its 27 px icon pitch with spacing 0).
- Pick a recommendation and name it as a concept ("One cell, one inset").
  User-facing names come later, when the user decides.

## 6. Building the page

1. Call the Artifact tool with `action: "quickstart"`, `intent: "other"`
   (required once per new artifact). The template already follows the page
   contract it returns: title as a name, both themes, tokens, 16 px gutters.
2. Copy `assets/lab-template.html` to `docs/<topic>-lab/<topic>-lab.html`.
3. Fill the config block (ZONES, ALGOS, RULE_ROWS, CASES, STATES), the
   header and every section (`page-anatomy.md`). Delete sections that do not
   apply rather than leaving placeholders.
4. New options: add a layout function (`engine.md`). New surfaces (a drawer
   grid, a panel, a Preferences row): write a renderer in the same visual
   language (wallpaper stage, bar world colours, chips, x-ray).
5. Interactive demos for anything that moves: persistent DOM with CSS
   transitions, not re-rendering (re-created elements cannot animate). The
   drag lab in `reference-lab.html` is the pattern.

## 7. The one look and publishing

```bash
bash ~/.claude/skills/omarchy-widget-lab/scripts/screenshot.sh docs/<topic>-lab/<topic>-lab.html "$CLAUDE_JOB_DIR/tmp/shots" 9000 dark
```

Read the slices. Check: the numbers in chips match your predictions, nothing
overlaps or clips unexpectedly, zones wrap sensibly, text is readable on the
wallpaper. Make one pass of fixes.

A resting screenshot says nothing about an interactive demo. For drag or
motion demos, render several states through the page's state hook (for
example ghost positions at the start, over a narrow neighbour, over a wide
one, and at the end, for the smallest and largest dragged widget), make a
contact sheet, and check each: the held item looks held, the placeholder is
visible, markers line up with the rule.

When the user says something "looks off", look at their latest screenshot
first: Omarchy saves them as `~/Pictures/screenshot-*.png` (`ls -t` for the
newest). Reproduce the state in a render, fix, verify the same state again. Then publish:

```python
# files map for the Artifact publish call
import json, os
d = "docs/<topic>-lab"
files = {f"w/{f}": f"w/{f}" for f in sorted(os.listdir(f"{d}/w"))}
files.update({"widgets.js": "widgets.js", "wall.jpg": "wall.jpg"})
print(json.dumps(files))
```

Publish with `file_path` = the page, `root` = the lab folder, `files` = that
map, `icon` (for example `ruler`), and a one-sentence `description`. The
source must be under the working directory (the job tmp dir is refused).

## 8. The first report

Keep it scannable:

- The link.
- The recommendation as a small table of formulas with values for each bar
  size, and the headline measurement (for example, glyph air 14–45.5 px today
  vs 23–26 px proposed).
- Problems found in today's code, each with the proof in one clause.
- What the page covers beyond that, in one or two lines.
- What was not verified on the live desktop.
- Where the source lives and the next step.
- Sources as markdown links.

## 9. Iteration turns

Each user turn usually brings one of: a hypothesis, a correction, a decision,
or new scope (a new edge case such as drag gaps for wide widgets). The order
of work is always: validate numerically, answer with the verdict in two or
three sentences, update the page everywhere the change touches, republish the
same path, report briefly.

Worked examples from the spacing lab:

- *Hypothesis:* equal-gap layout can use the cell's symmetric highlight,
  overflowing into gaps. Derivation: spill = (C − ink)/2, gap G = C/2 + 2, so
  clearance = 2 + ink/2 ≥ 2 px at any size. Measured over all 40 captures with
  anti-aliasing: worst 5.25 px. Catches found by the check: neighbours lit
  together overlap up to 7.5 px; island ends must be measured from the
  highlight. Page: new validation section with formulas, table and demos.
- *Correction:* overlap is fine; fade the older highlight. Checked the fade
  against the strongest state (open, 22%): 55% left it equal to a new hover,
  so 45% was used, and the reply said why.
- *New scope:* drag gaps for non-standard widths. Research (react-beautiful-dnd
  centre-of-gravity impact, Material duration by distance), then simulation:
  nearest-landing rule on the resting layout changed index exactly once per
  boundary per direction; √distance timing capped at 260 ms cut the clock's
  peak neighbour speed from 3.7× to 2.2× an icon's. Page: interactive drag lab.

## Adding scope to a final spec

When new cases arrive after the design is locked (the extended islands of
the spacing spec are the example in `reference-final.html` once updated),
repeat sections 1–7 for the new part, then:

- add one section with a "Draft for review" pill, its own formula panel,
  an interactive demo with its own controls, rendered edge-case cards and a
  short list of the remaining rules;
- reuse the page's tokens (`params`) so the new part inherits the locked
  rules instead of inventing numbers;
- collect any new captures with `--no-recolor` when their own colours are
  part of what the user sees, and copy only the new files into `w/`;
- report the differences from the current code in your reply (a table of
  today versus the draft), not on the page;
- check the console after adding code (`chromium --headless=new
  --enable-logging=stderr --v=0 --dump-dom file://…`); a missing helper
  silently stops everything after it.

## 10. Locking decisions, naming and the repo

When the user says the design is locked and wants the final design kept in
the docs, the lab becomes the specification (compare `reference-lab.html`
with `reference-final.html`):

- Remove the baseline: the Today option, its layout function and tokens,
  comparison rows, the "Today" row of each edge case, "fixed (today)" timing
  toggles, and every sentence that contrasts with the old behaviour.
- Show the locked options side by side wherever the baseline used to be
  (edge cases show both modes; the comparison becomes "the two modes side by
  side").
- Restate the lead and "why" paragraphs as the design's own reasons.
- Decisions become "Final, <date>"; validation sections stay, retitled as
  statements ("Why equal-gap highlights can overflow").
- Implementation steps describe the target state, naming files and keys.
- Guard saved preview state (localStorage) that may still say "today".
- `grep -i "today\|proposal\|proposed"` should find nothing.


- Decisions section at the top of the page, dated, listing what ships, the
  default, the config key.
- Naming: propose a user-facing pair (parallel, plain, says what changes),
  show rejected pairs with one-line reasons, check collisions with the words
  Omarchy users already use (tiling, workspaces, islands, drawers).
- Preferences mock drawn to the real component and section, with the one-line
  description that follows the selected chip, and a live preview of the
  user's bar in the chosen option.
- Project memory: one file with the decided numbers and names.
- Repo: `git switch -c docs/<topic>-lab`, add only the lab folder (and a
  `.gitignore` line for `wall.jpg` if its licence is unknown and the repo is
  public), commit with the attribution trailer, `git switch -` back, and tell
  the user `git merge docs/<topic>-lab`.

## After the lock: the live check amends the spec

A locked lab is still a proposal until the user has used it on their desktop.
The Preferences bento lab (October 2026) argued for a pinned bar preview with
a measured "preview in view at 18 of 18 stops"; on the first live look the
user removed it ("we can see our real bar changing anyway, and it takes
update cycles") and merged two tiles' pictures into one. Lessons:

- Before recommending a preview, ask whether the real thing is already on
  screen while the user works. A metric that a preview stays visible
  doesn't show the preview is needed.
- Prefer one picture that carries several settings over a thumbnail per option.
- Record live amendments in the Decisions table with the date and the
  reason ("Dropped after the live check"), and say plainly when the
  interactive mock still shows the first locked version. Update the project
  memory in the same turn.
- Implementation can move ahead of the page; don't rebuild the mock for every
  amendment unless the user asks for it.

The Layout lab (October 2026) added three more:

- **Fidelity outranks the "no preview" rule when the page is an editor of
  the bar.** The lab drew widgets on a plain shelf at a scaled size; after
  the live check the user asked to "keep scale, rounding and theme exactly
  as the real bar". Draw such rows with the bar's own geometry model and
  tokens at 1:1, and wrap instead of shrinking.
- **Live checks find adjacent bugs.** In the same pass the user hit a bar
  that went blank after a theme switch (a global Light/Dark choice) and a
  stacked widget overflowing its slot. Fix each on its own branch from
  master (a git worktree keeps the feature branch checked out for the live
  bar), fold the change into the feature branch only when the feature needs
  it, and say so in both commit messages.
- **A decision that is the user's goes to AskUserQuestion**, with the
  recommended option first and each option's consequence for their own setup
  ("your current Dark stays with the light theme"); then do exactly what the
  chosen option promised, including any one-off config migration, with a
  backup and a semantic diff.

The Groups lab (October 2026) added these:

- **Requirements arrive mid-lab; fold them in with numbers.** The user added
  an icon picker ("glyphs, icons available to Omarchy and emojis"), then
  search, then "paste your own icon with a drop area" while the page was
  being built. For each, find what exists on the machine first (fonts, icon
  themes, Omarchy's plugins and their data) and ask one scoping question
  with counts and consequences ("10,610 glyphs, or the 284 Omarchy uses").
  When the user asks for your recommendation, look for the platform's own
  practice before inventing a rule: Omarchy had no written icon guideline,
  but its sources showed exactly which icons it uses.
- **The mock is not the alignment spec.** CSS approximates QML; the user saw
  the web version as "a bit skewed" and locked the design on condition that
  the real layout be symmetrical and evenly spaced. Turn that into stated
  rules (equal halves, mirrored chrome, equal columns, fixed row heights) in
  the Decisions table, build them, and audit them offscreen (column widths,
  right edges, row heights, page height) before the live check.
- **A live complaint can be a stale build.** "Completely botched" was a shell
  started mid-edit running a first draft. Read the screenshot, then compare
  the running shell's pid and start time with your last edit before touching
  the code (see the UX skill, "Prove the restart happened").
- **A request to remove UI can be a request for automation.** The lab drew
  "Missing widget" rows with x to remove them; the user wanted Powerbar to
  clean up uninstalled widgets itself. Record such amendments in Decisions
  and mark the superseded edge case rather than deleting it.

- **The live check can be yours.** When the user handed over ("can you test
  it yourself in a real bar"), driving the real bar found three bugs every
  offscreen check had passed: a tint that drew white (then a square), gaps
  that depended on glyph overhang, and a search that lost a glyph's name.
  Run the user's own scenario list (paste, a copied file, an emoji, a logo
  beside a name, a light and a dark theme), screenshot the exact pixels,
  and fix on a branch before reporting.

The bar keys lab (October 2026, keyboard navigation) added these:

- **A behaviour lab has no picture to compare, so measure the interaction.**
  Write the rules once as a plain script (`nav.js`) that both the demo runs and
  a node script measures: a breadth-first search over each scheme's keys gave
  "keys to reach each of 36 widgets" (arrows median 9 / most 17, with Tab
  3 / 7, by name 3 / 5). The numbers can't drift from the demo.
- **Check the user's proposal against their own setup before building.** Their
  bar was on the right edge, so "Up/Down enter a group" collided with the keys
  that move along it, and their key repeat (`hyprctl getoption
  input:repeat_rate`, 40/s after 250 ms) ruled out any fixed dwell for
  "unfold on highlight". Present the result as a Keep / Change / Add table
  with one reason per row, not as a rival design.
- **Check every proposed shortcut against the live binds** (`hyprctl binds`,
  plain text, since its JSON drops `code:` keys) and Omarchy's defaults; say
  "free here and in stock Omarchy".
- **Interactive demos get a hash hook** (`#drawer`, `#search`, `#top`) so the
  one look can render several states; take each in its own screenshot run.

Tooling that bit:

- `collect_assets.py` and `screenshot.sh` need Pillow; when it isn't
  installed run them through `uv run --with pillow python …` (copy
  `screenshot.sh` and swap its `python3` for that) instead of installing
  system packages.
- **Private-use glyphs can vanish when a file is written.** Single BMP
  private-use characters (U+E000–U+F8FF, Font Awesome glyphs such as
  U+F028) came out as empty strings, while supplementary ones (Material,
  U+F0000+) survived. In generated pages and QML, write glyphs as escapes
  (`"\uf028"`, `"\u{f024b}"`) and grep the result for `""` where a glyph
  belongs.
- **Glyphs on any machine:** subset the fonts the page needs with
  `uv run --with fonttools --with brotli` (pyftsubset to woff2: the glyphs
  shown plus ASCII), publish them with the page, and keep them out of git
  (`.gitignore`) as with `wall.jpg`.
- **Render the real page too.** The rendering bench copies only top-level
  `.qml`/`.js` files into its work dir, so generated data the plugin imports
  belongs at the top level. A scratch copy of the bench with an extra
  scenario step (open the picker, type a query, shoot) shows states the
  stock scenarios don't reach; take each shot in its own step, since
  `grabToImage` is asynchronous and a close in the same step wins.
- The `#key=value` state hook works for local screenshots only; published
  artifacts receive just a bare `#anchor`.

## Building the Today baseline

- Model Today from the code with the user's real captures; the offscreen
  render of the real page is evidence, not the baseline. Plugins do not run
  offscreen, so the render shows stand-in buttons and plugin ids instead of
  names, and its widths are wrong (the bar row looked 26% scaled offscreen,
  60-72% with real captures).
- Read cell sizes from the bench (log the cells' x, width, fit) and the
  rest from the code, and quote both in the findings with file and line.
- Render the bench at the user's device pixel ratio when saved captures are
  involved (`"dpr": 1.6` in the bench's screens file).

## When the user says the current code is not good enough

Model new surfaces only from the locked rules on the page, not from the
running code's geometry. Take platform facts from the code (theme tokens
such as the vertical bar size, widget formats such as the clock's vertical
form) and nothing else. Then check every new surface against the same
principles as the main design: glyphs centred along and across, highlights
symmetric, one inset everywhere, columns aligned, badges inside, and both
spacing modes. Measure that across every combination (see "Auditing a
surface" in engine.md) before showing screenshots.
