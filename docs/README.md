# Powerbar docs

For people working on Powerbar. Users start at the top-level README.md.

| Folder | What it holds |
|---|---|
| [behavior/](behavior/README.md) | The behavior of record: what Powerbar does, one file per area, every behavior a stable ID. Code is the truth; these files say what the code does in words a behavioral test can check. |
| [design/](design/) | Why things are the way they are: design notes and the implementation plans for groups, on-demand widgets, spacing and zone fit. History, not spec: where they disagree with `behavior/`, `behavior/` wins. |
| [design/preferences-design-system.md](design/preferences-design-system.md) | The Preferences design system: type roles and tiers, the spacing ladder, control sizes, corners, the parts and page structures, focus marking, elevation, the tilted plates and the camera, motion, themes and contrast; with a build and a review checklist. Its reasoning is the lab in `hierarchy-lab/`. |
| [performance/](performance/) | The rendering audit (`plan.md`), what was measured and changed (`implementation.md`), the path probe (`probe.cjs`); the offscreen whole-bar benchmark and profiler live outside the plugin (`implementation.md`, Harness). |

The glossary is `CONTEXT.md` at the top level; the development loop is
`DEVELOPMENT.md`.
