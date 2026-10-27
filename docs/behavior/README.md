# Behavior of record

What Powerbar does, written so each behavior can become a behavioral test
without reading the code. The code is the source of truth: when a file here
and the code disagree, the file is wrong and gets fixed (or the code has a
bug, which gets a test and a fix).

## Areas

| File | IDs | Covers |
|---|---|---|
| [layout-zones.md](layout-zones.md) | `ZONE-n` | zones, placement and order, spacing, zone fit (no overlap), dots, position and vertical bars, bar size |
| [on-demand-drawers.md](on-demand-drawers.md) | `DEMAND-n` | on-demand widgets, activity reveal and peeks, drawers, inline expansion, drawer timing |
| [groups.md](groups.md) | `GROUP-n` | groups, their faces, badges and icons, group drawers and menus, group shortcuts |
| [keyboard.md](keyboard.md) | `KEYS-n` | the keyboard mode, cursor and stops, search, name card, key legend, focus, shortcuts |
| [drag-edit.md](drag-edit.md) | `DRAG-n` | drag and drop on the bar, into drawers and onto dots, drop preview, settle |
| [preferences.md](preferences.md) | `PREFS-n` | the Preferences window: Layout, Groups, Look and Behavior pages, desks, strips, faders, controls, icon picker, resets |
| [appearance.md](appearance.md) | `LOOK-n` | theme tokens, shape, surface, shadow, blur, islands, tooltips, appearance scopes, `powerbar.toml`, bar auto-hide |
| [integration.md](integration.md) | `INTEG-n` | startup, config healing, registry heal, Omarchy bar compatibility, the CLI and IPC, multi-monitor |

## Format

- One bullet per behavior: `- **AREA-n** <trigger> → <observable result>`,
  with the numbers (ms, px, counts) and the config keys or commands that
  drive it. A trailing `Code:` names where it lives.
- IDs are stable. A new behavior takes the next free number in its file; a
  removed behavior's ID is not reused. Tests name the ID they check.
- A behavior that is believed but not yet traced to code ends with
  `(unverified)`.
- Each file ends with **Doc drift** (places README.md or `docs/design/`
  disagree with the code) and **Open questions**.

## Keeping it true

A change to what the user sees or can do updates its entry here in the same
commit (see DEVELOPMENT.md, "The loop").
