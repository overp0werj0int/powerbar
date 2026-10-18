# Developing Powerbar

For everyone working on Powerbar's code, people and coding agents alike: how
it is built, tested and checked before a commit.

Powerbar is an Omarchy shell plugin (Quickshell/QML) that replaces Omarchy's
bar. README.md is for users; CONTEXT.md is the glossary (zone, on-demand,
drawer, island…), use its words in code, commits and UI text.
`docs/behavior/` is the behavior of record: one file per area, every behavior
a stable ID (`ZONE-12`) a behavioral test can name. `docs/README.md` maps the
rest of `docs/`.

## Prerequisites

An Omarchy install (`/usr/share/omarchy`, `omarchy`, `omarchy-shell`), Qt 6
tools (`qmltestrunner`, `qmlformat` in `/usr/lib/qt6/bin`), node, python3.
omabox for desktop tests in a private Hyprland session
(`omabox help`); `wtype` only for the guarded live tests below.

## The loop

1. **Pure logic lives in `*Model.js`** with node tests in `tests/*.test.cjs`
   (decisions, layouts, ranking, placement). QML carries them out. New rules
   get a model function and a test first.
   A change in what the user sees or can do updates its `docs/behavior/`
   entry in the same commit (new behaviors get the next free ID; never reuse
   one).
2. **Validate before every commit:** `tools/validate.sh` (node tests, QML
   tests, the startup probe, `omarchy plugin validate`, qmlformat). Offscreen;
   it never touches the running shell.
3. **See it in a box, not on the user's desktop.** omabox runs a full Omarchy
   session invisibly. `omabox up --plugin` waits for Omarchy's own bar layer and
   times out, so: `omabox up`, then copy the plugin in and restart its shell:

   ```bash
   omabox up
   rsync -a --delete --exclude .git --exclude docs --exclude tests ./ \
     "$(omabox path)/home/.config/omarchy/plugins/p0werj0int.powerbar/"
   omabox restart-shell          # "the shell crashed while starting" is harmless here
   ```

   Edit `$(omabox path)/home/.config/omarchy/shell.json` (bar position,
   `powerbarAutoHide`, `powerbarOnDemand`…); the box applies it live. Drive it
   with `omabox pointer`, `omabox click`, `omabox keys`, look with `omabox shot
   -g …`, read state with `omabox run -- omarchy-shell powerbar <status>`.
   `omabox down` when done.
   `tools/box/` has the helpers for this (box with the user's layout, sync,
   live config changes, key and pointer driving, frame bursts with a card
   count, montages, edge cards, bench diffs); read its README before writing
   new ones.
   `tools/smoke.sh [name]` does all of this in a throwaway box and asserts
   the IPC basics (status, settings, keys, bar position) and that the box runs
   this checkout (`tools/build-check.sh -b BOX`); `SMOKE_SHOT=file.png`
   keeps a screenshot. `tests/run` is the portable subset (node tests and
   `bash -n`) that CI runs.
   **After an Omarchy update**, start with `node tools/omarchy-contract.cjs`
   (validate.sh runs it too): each `contract drift:` line names the Omarchy
   file, the exact text Powerbar relied on that is gone, and what that breaks.
   Read what replaced it in that file, adapt Powerbar, then update the entry
   in the script. Then `tools/smoke.sh` for Quickshell and Hyprland behaviour,
   which the contract does not cover.
4. **The live desktop only when the user asks.** Restart the user's shell with
   `.claude/skills/omarchy-widget-debug/scripts/live.sh restart powerbar`
   (it refuses while the session is locked; never restart a locked session).
   Then `tools/build-check.sh` (through `omabox host --` under the guard)
   says whether the shell now runs this checkout: `current`, or `stale` when
   the restart did not happen or kept older code. Trust it over a process id:
   `qs list` can name another Quickshell app.
   Drive the keyboard mode with `tools/live-keys.sh`, which checks before every
   key that the bar holds the keyboard. Never send keys or clicks to the real
   desktop otherwise.
5. **Something jerky, slow or out of order:** turn on the frame log first
   (`"powerbarFrameLog": true` on the bar in shell.json, applied live; not in
   Preferences; INTEG-146). The shell log then carries a timeline of what the
   bar did (`PB-EV t=<ms> <kind> <detail>`: keys, cursor, cards, hover, dots,
   inline asks and opens, drawers with their close reason, strip slides,
   drags, folds, config deliveries) and one `PB-FT anim=… frames= wall= p95=
   max= long=` line per motion, with `longframe dt=` on the timeline where a
   frame stalled. In a box: `omabox log -b NAME shell --grep PB-`. On the
   desktop the user sets the key, then
   `~/.claude/skills/omarchy-widget-debug/scripts/live.sh follow PB- 300`
   while they reproduce. Turn it off afterwards.
   For per-frame values of one motion, `tools/frame-probe.md`; for offscreen
   whole-bar timings, the bench (kept outside the plugin, see
   `docs/performance/implementation.md`). Measure before and after;
   claim only measured gains.

## State over IPC

`omarchy-shell powerbar <fn>` (same inside a box with `omabox run --`):

| Function | Tells |
|---|---|
| `status` | every setting, widget, group, shortcut, and runtime state (`help` lists all functions; README "Command line") |
| `keysStatus` | keyboard mode: cursor, stops, search, drawer, focus, name card |
| `drawerStatus` | the open drawer or group menu |
| `managedStatus` | on-demand widgets: zone, revealed, on the bar |
| `popupStatus` | the open widget panel |
| `keys` | toggles the keyboard mode (Super+B by default) |

## README images

`screenshots/` holds the README gallery, real captures only. `preview.jpg`
(the README hero and the plugin's preview) is `tools/showcase/card.html`
rendered by `tools/showcase/render.sh` (headless Chromium, 1200x675 at 2x:
16:9, the marketplace card's shape). The page is a gradient of the nord
theme's own colours with one capture laid in as a screen,
`screenshots/hero-nord.jpg`: a 1920x1080 box at scale 2.5 on nord, a layout
of stock Omarchy widgets, keyboard mode inside the System group (keysOn,
Left, Down, Down). The box's background is the same gradient under the
screen, from `render.sh --wall OUT.png` and `omarchy-theme-bg-set`. Keep
what matters inside the screen: catalogue cards crop the picture to between
about 1.5:1 and 2.4:1, which takes only gradient. Re-run render.sh after
replacing the capture.

The gallery shots are wide, readable captures from one omabox box
(`omabox up gal --theme NAME --env POWERBAR_DISPLAY_CUTOUTS=/home/sbx/cutouts.json`),
with the plugin copied into the box HOME, `omarchy bar use p0werj0int.powerbar`
and `tools/showcase/seed.py` writing a bar of stock widgets. Set the screen
per shot with `omabox -b gal hyprctl eval 'hl.monitor({ output = "HEADLESS-2",
mode = "2400x275@60", position = "0x0", scale = 2.5 })'`; do that again after a
`omarchy-theme-set`, which resets it. Keep shots wide (the key strip needs
about 240 logical px of height) and only Preferences tall:

| Shot | Theme, mode | State |
| --- | --- | --- |
| `drawer-latte.jpg` | catppuccin-latte, 2400x275 at 2.5 | floating; `powerbar managed right` |
| `search-tokyo-night.jpg` | tokyo-night, 2400x600 at 2.5 | flat; `keysSearch`, type `tail` |
| `notch-kanagawa.jpg` | kanagawa, 3024x1964 at 2, `shot -g 290,0,932,200` | `set zones notch`; `group g-show-system`. `cutouts.json`: `{"panels":[{"connector":"HEADLESS","width":3024,"height":1964,"top":64}]}` |
| `preferences.jpg` | osaka-jade, 2560x1600 at 2 | islands; `preferencesPage 1` |

Park the pointer where it hovers nothing. JPEG at quality 88.

## Skills

Development skills are not part of the plugin: `omarchy plugin add` clones
this tree as it is, and Omarchy's plugin review rejects agent instructions in
it, so `AGENTS.md`, `CLAUDE.md` and `.claude/` are git-ignored. Keep them
locally (a `CLAUDE.md` of `@DEVELOPMENT.md` is enough). The maintainer's
`.claude/skills/` holds:

- **omarchy-widget-ux**: theme tokens, keyboard model, motion budget, words.
  Read it before UI work.
- **omarchy-widget-debug**: frame-by-frame debugging (offscreen harness,
  `timeline.py`), the live loop (`live.sh`), focus and click pitfalls.
- **omarchy-widget-lab**: evidence-based design labs built from the user's
  real bar (`docs/<topic>-lab` while the design is open). Once it ships, its
  decisions go into `docs/behavior/` and the lab is deleted.

Without them, the loop above still holds: `tools/validate.sh`, `tests/run`,
`tools/smoke.sh`. (`.claude/skills/omarchy-widget-debug/scripts/live.sh`
restarts the live shell; without it use `omarchy restart shell`, never while
the session is locked.)

The skill a user's agent loads to *operate* Powerbar (CLI, settings, recipes)
is kept outside the plugin, in its own repository: Omarchy's plugin review
does not accept agent instructions in a plugin. Update it with any change to
`omarchy-shell powerbar` functions or settings.

## Git

- `develop` is the working branch: one branch per item off `develop`, merged
  back with `--no-ff`, then pushed. User-facing changes go under
  `## Unreleased` in CHANGELOG.md.
- `master` holds releases only. It stays the GitHub default branch, because
  `omarchy-plugin-update` installs and updates from the remote's HEAD, so
  every commit there reaches users. A release: on `release-X` off `develop`,
  bump `manifest.json` and INTEG-1 and turn Unreleased into `## X — date`;
  merge it into `develop`, then `develop` into `master` (`--no-ff`, "Release
  X"), tag `vX` on master, push `master`, `develop` and the tag, and run the
  release preflight.
- Commit as the repo's GitHub noreply address; never edit the user's git
  config.
- Commit messages: what changed and why, measured numbers where there are any.
