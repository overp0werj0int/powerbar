---
name: omarchy-widget-lab
description: Research, measure and present a design proposal for an Omarchy widget or Powerbar feature as an interactive "lab" page, built from the user's real bar (cached widget captures, their wallpaper and theme), with today's behaviour as the baseline, options side by side, measured metrics, edge cases, highlight states, motion specs, an implementation plan and cited research; then iterate on it as the user tests hypotheses and locks decisions. Use this whenever the user wants to explore, compare, propose, validate or visualise a change to how an Omarchy bar widget, Powerbar, a drawer, a group, a panel or a preferences screen looks, spaces, highlights, animates or behaves, or asks for "a visual proposal", "a lab", "show me options", "research the best way to…", or to validate a design hypothesis, even if they never say "lab".
---

# Omarchy widget lab

A lab is an evidence-based design proposal the user can operate. It answers
one design question for an Omarchy widget (spacing, highlights, drag, motion,
grouping, a new preference) by showing the user's **real bar** rendered under
each option, measuring what the eye would judge, and explaining the rule
behind the recommendation. The Powerbar spacing lab
(`assets/reference-lab.html`) is the finished example of the format; match its
structure, tone and visual language. `assets/reference-final.html` is the
same lab after the user locked the design: the final specification kept in
the repo's docs.

The lab is also a conversation: the user will react with hypotheses
("could equal gaps borrow the cell's highlight?") and decisions ("lock both
in"). Each turn validates with numbers first, then updates the same page at
the same URL.

Load the `omarchy-widget-ux` skill alongside this one: its rules (theme
tokens, one highlight language, keyboard model, motion budget, sentence case)
are what the proposal must honour, and the lab is where they are shown.

## The deliverable

- A published Artifact page (private link), built from `assets/lab-template.html`.
- Its source in the project repo: `docs/<topic>-lab/<topic>-lab.html` with `w/`
  (widget captures) and `widgets.js`. `wall.jpg` stays local unless its licence
  allows redistribution (Omarchy theme wallpapers are often third-party).
- A short terminal report: the recommendation with its key numbers, problems
  found in today's code, what was not verified live, the link, and sources.

## Workflow

Read `references/process.md` for the full procedure, checkpoints and
wording; this is the outline.

1. **Frame the question.** One sentence: what decision does this lab settle?
   Who sees the result, how often (that sets the motion budget)?
2. **Read today's implementation.** Find the exact current algorithm and its
   constants in code (for Powerbar: `Bar.qml`, the `*Model.js` files, Omarchy's
   `qs.Ui` components under `/usr/share/omarchy/shell/Ui`). Note uncommitted
   work in `git status`; the baseline models the working tree, and says so.
3. **Collect the real thing.** Run
   `python3 scripts/collect_assets.py --list`, then
   `python3 scripts/collect_assets.py --out <repo>/docs/<topic>-lab [--widgets …] [--face name="text"]`.
   It reads (never writes) the Powerbar capture cache, shell.json, the theme
   colours and the wallpaper, and measures every widget's ink. Look at the
   numbers: odd ones (off-centre ink, oversized slots, captures taken in
   another state) become edge cases.
4. **Research.** Search the web for how the best comparable systems solve
   this (macOS menu bar, GNOME Shell, Windows 11 taskbar, Apple HIG and WWDC
   design talks, Material 3, Atlassian and react-beautiful-dnd for drag,
   Fitts's law, Emil Kowalski for motion). Keep each source only if it
   contributes a specific rule or number; `references/research.md` lists
   proven sources and queries.
5. **Define the options.** Always include **Today**, modelled faithfully from
   the code, including its quirks. Add one to three options, each written as
   formulas derived from real tokens (bar thickness, theme radius, icon slot),
   never magic numbers. Pick a recommendation.
6. **Build the page.** Call the Artifact tool's `quickstart` (intent
   `other`) once, then copy `assets/lab-template.html` into the lab folder,
   fill the config block and sections (`references/page-anatomy.md`), add
   option layouts to `ALGOS` (`references/engine.md`). Custom surfaces
   (drawers, panels, Preferences) get their own renderer in the same visual
   language.
7. **Validate before claiming.** Every chip, table and sentence with a
   number comes from measurement or simulation (`references/validation.md`).
   Run `bash scripts/screenshot.sh <page> <tmpdir>` once, read the slices,
   check the numbers match what you predicted, fix in one pass. Interactive
   demos also get a few mid-interaction renders through a state hook (the
   fifth argument is a URL fragment); a resting screenshot hides most drag
   and motion bugs.
8. **Publish.** Publish the repo file with `root` set to the lab folder and a
   `files` map of every `w/*.png`, `widgets.js` and `wall.jpg`; pass
   an `icon` on first publish. Republish the same path later to keep the URL.
9. **Report.** Recommendation table, problems found in today's code, what was
   not checked on the live desktop, next step, sources as links.

## Iterating with the user

- **A hypothesis** ("we can allow overflow…", "what if…"): restate it as a
  testable claim, derive the closed-form bound, measure it over *all* cached
  captures, simulate interactions if it involves motion or dragging. Answer
  with the verdict and its catches first, then update the page: a validation
  section (formulas, measured table, demos), the option everywhere it
  appears (hero, comparison, edge-case toggle, states, motion table,
  implementation steps), then republish.
- **A correction** ("overlap is fine, fade the older one"): change the rule,
  not just the demo; update the copy that explained the old rule; check the
  new rule numerically (for example, fade strength against the strongest
  state it can overlap).
- **A decision** ("lock both in", "name it"): add or update the dated
  Decisions section: what ships, the user-facing names with a naming table
  (rejected pairs and why, including vocabulary collisions such as
  Hyprland's "tiling"), a Preferences mock drawn to the real component (for
  Powerbar, `PrefsChoice`: label, one-line description that follows the
  choice, chips), the config key and default. Save a project memory with the
  numbers to implement.
- **Locked for good** ("we're locked in, keep the final design in the
  docs"): turn the lab into the final specification. Remove the Today
  baseline everywhere (option switch, comparison row, edge-case rows, timing
  toggles, "today" wording, the baseline layout code), show the locked
  options side by side instead, rewrite the copy to state the design rather
  than argue against the old one, mark Decisions as "Final" with the date,
  keep validation sections as the derivations behind the rules, and turn
  implementation steps into target-state instructions. Search the page for
  "today", "proposal" and "proposed" afterwards; none should remain.
- **Amendments after a live check** ("drop the preview", "merge these"):
  update the Decisions table with the date and reason and the memory; the
  user's live verdict outranks the lab's metrics (references/process.md,
  "After the lock").
- **New scope after the spec is final** ("more cases we forgot"): run the
  whole process again for the new part (read code, collect assets, research,
  rules, edge cases, validation), but add it to the same page as a new
  section marked "Draft for review" that states the design without a Today
  baseline; put what changes from the current code in your report instead.
  When the user approves it, drop the draft pill and fold it into Decisions.
- **"Add it to the repo"**: commit only the lab folder on a new branch
  (never sweep up the user's uncommitted work), return them to their branch,
  and give them the merge command. Switching branches removes the committed
  files from the working tree; read them back with `git show` if you still
  need them, and keep publishing from a path that exists.

When the user reports that something looks wrong, read their newest
screenshot (`ls -t ~/Pictures/screenshot-*.png | head -1`) before changing
anything, check the running shell is the build you think it is (its pid and
start time against your last edit), reproduce that state in a render, and
verify the fix in the same state.

When the user locks an option on a condition ("make sure the real layout is
symmetrical"), write the condition into Decisions as rules the build can be
audited against, since a browser mock only approximates the QML layout.

## Principles

- **Show the real thing.** The user's widgets, theme and wallpaper, never
  stand-in glyphs. Label anything synthetic (a mock value, a drawn face).
- **Today is the baseline.** Every option is measured against it with the
  same chips, so the page argues with numbers, not adjectives.
- **Rules, not pixels.** Present each option as a few formulas with live
  values; the renderer implements exactly those formulas.
- **Good and bad chips are measured.** A ✓ or ✗ comes from a threshold you
  can state (for example, glyph-gap spread ≤ 6 px, clearance ≥ 2 px).
- **Honest about limits.** Browser mockups are not the live shell. Never
  change the user's shell.json or send input to their desktop to take a
  capture; say what still needs checking on the running bar.
- **Plain, specific copy.** Sentence case, active voice, one idea per
  sentence, no ALL CAPS labels or "A · B · C" strings; names that describe
  what the user sees.
- **Motion is optional.** Omarchy has to run well on modest hardware. Every
  lab gives each animated change an "Animations off" equivalent that keeps
  its function and its meaning (a fill, an outline, a position), keeps logic
  independent of motion, and plans no per-frame work when off. The page has
  an Animations switch that turns all its demos to motion off, and the
  audit of today's code lists every animation or per-frame loop that ignores
  the central flag (for Powerbar, `powerbarAnimations` read as
  `animationsEnabled`).
- **One page, one URL.** Keep iterating on the same file; the page is the
  record of the design discussion.
