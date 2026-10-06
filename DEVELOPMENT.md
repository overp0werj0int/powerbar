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
   `tools/smoke.sh [name]` does all of this in a throwaway box and asserts
   the IPC basics (status, settings, keys, bar position); `SMOKE_SHOT=file.png`
   keeps a screenshot. `tests/run` is the portable subset (node tests and
   `bash -n`) that CI runs.
4. **The live desktop only when the user asks.** Restart the user's shell with
   `.claude/skills/omarchy-widget-debug/scripts/live.sh restart powerbar`
   (it refuses while the session is locked; never restart a locked session).
   Drive the keyboard mode with `tools/live-keys.sh`, which checks before every
   key that the bar holds the keyboard. Never send keys or clicks to the real
   desktop otherwise.
5. **Something jerky or slow:** `tools/frame-probe.md` (frame gaps on the live
   bar) and `docs/performance/bench` (offscreen whole-bar benchmark, profiler).
   Measure before and after; claim only measured gains.

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

## Skills

`.claude/skills/` holds the project's agent skills; Claude Code loads them
here automatically:

- **omarchy-widget-ux**: theme tokens, keyboard model, motion budget, words.
  Read it before UI work.
- **omarchy-widget-debug**: frame-by-frame debugging (offscreen harness,
  `timeline.py`), the live loop (`live.sh`), focus and click pitfalls.
- **omarchy-widget-lab**: evidence-based design labs built from the user's
  real bar (`docs/<topic>-lab` while the design is open). Once it ships, its
  decisions go into `docs/behavior/` and the lab is deleted.

`agents/skills/powerbar/` is the other kind: the skill a user's agent loads to
*operate* Powerbar (CLI, settings, recipes). Keep development guidance out of
it, and update it in the same commit as any change to `omarchy-shell powerbar`
functions or settings.

## Git

- One branch per item; merge to master with `--no-ff`, then push.
- Commit as the repo's GitHub noreply address; never edit the user's git
  config.
- Commit messages: what changed and why, measured numbers where there are any.
