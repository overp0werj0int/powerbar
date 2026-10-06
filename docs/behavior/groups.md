# Groups

Groups are named, ordered collections of existing widget instances, shown on the bar as one icon (a glyph, your own image, or the Omarchy logo; icon, name or both). The icon opens a drawer (a strip of the members as they draw themselves) or, when members are shown by name, a vertical menu. Groups live in `bar.powerbarGroups`, refer to widgets by their `powerbarInstance` keys, and never change a widget's settings, visibility mode, zone, place or plugin enablement; membership only keeps the widget off the main bar. Drawer timing, the zone drawer and activity reveal: on-demand-drawers.md. Drag and drop: drag-edit.md. Keyboard: keyboard.md. The Groups page: preferences.md. CLI (`groups`, `newGroup`, `setGroup`, `removeGroup`): integration.md INTEG-132 to INTEG-135.

**Sources:** GroupsModel.js, GroupBadgeModel.js, GlyphModel.js, GroupFace.qml, ManagedModel.js (menu geometry), ManagedDrawer.qml, Bar.qml (grep: group), tests/groups.test.cjs, tests/group-badges.test.cjs, tests/glyph.test.cjs, tests/managed.test.cjs, CONTEXT.md.

## Lifecycle

- **GROUP-1** `GroupsModel.create(config, id, label)` adds `{id, label, icon: "󰉋", section: "right", before: "", items: []}`; the label is `"New group"` when empty and is stored as given. It returns false for an empty or existing id, and creates `config.bar` if missing. Every other key reads as its default (GROUP-54 to GROUP-68). Labels are trimmed and cut to 80 characters by `edit()` (a blank label is ignored) and by the CLI.
- **GROUP-2** `GroupsModel.remove(config, id)` deletes the group and its member list; it returns false for an unknown id. The widgets stay in the layout with their zone, visibility and settings, and reappear where they were.
- **GROUP-3** A saved member whose widget is no longer in the layout (uninstalled) is left out of the group without any user action, and the cleaned list is written back once (integration.md INTEG-40). The group itself stays.
- **GROUP-4** While no layout entry has a `powerbarInstance` yet (config still loading), every saved member is kept and nothing counts as dangling.
- **GROUP-5** A group with no members still shows its icon; hovering or clicking it opens nothing, and a drawer whose last member leaves closes. Code: `ManagedDrawer.openZone`, `onSlotsChanged`.
- **GROUP-11** Deleting a group deletes no widget (see GROUP-2).

## Membership

- **GROUP-6** `GroupsModel.assign(config, key, id, before)` puts the widget with `powerbarInstance` `key` into group `id`, before member `before`, or at the end when `before` is empty or not a member (the index is taken after the widget left its old place, so reordering inside a group works). It returns false for an unknown group id, a key not in the layout, a `group:` pseudo-key, or `before === key`.
- **GROUP-7** A grouped widget keeps its layout entry (zone, place, saved visibility, settings) and stays loaded, but is not drawn on the main bar and takes no bar space: the group icon stands in. Members appear only in the group's drawer, never in a zone drawer.
- **GROUP-8** A widget is in at most one group: assigning it to another group removes it from the first (members of the first keep their order). In the saved data, a key listed in two groups belongs to the earlier group.
- **GROUP-9** `assign(config, key, "", ...)` (empty group id) removes the widget from every group; it returns true whenever the key exists in the layout, grouped or not.
- **GROUP-10** Members are drawn in the order of `items`; activity, visibility and size never reorder them.
- **GROUP-53** An Always hidden member has no slot, so it is in no drawer and not on the bar (on-demand-drawers.md DEMAND-3).
- **GROUP-93** Grouping or ungrouping writes only `bar.powerbarGroups`; the layout entry is not touched.
- **GROUP-94** A member's service enablement is unaffected by grouping or ungrouping (it stays loaded either way).
- **GROUP-95** An ungrouped widget returns to the place its layout entry gives it; the group's space on the bar is the icon alone.

## Face, icon and tooltip

- **GROUP-12** `face` is `"glyph"` (icon only, the default), `"text"` (name only) or `"both"` (icon, two spaces, name). On a vertical bar every group draws its icon only; its name shows in the tooltip.
- **GROUP-13** `edit(config, id, {icon})` with a new glyph replaces the icon whole: it sets `iconFont` only when the patch says `"omarchy"` and clears `iconImage`. Returns false for an unknown group id. `iconTint` is kept (it has no effect without an image).
- **GROUP-14** `iconFont` is saved only as `"omarchy"` (the Omarchy logo, U+E900); otherwise `groupIconFont()` takes the font from the stock icon list for that glyph, or "" (the bar's font). A group saved before fonts were kept resolves the same way.
- **GROUP-15** `iconImage` is a path (images chosen in the picker are copied to `~/.local/share/powerbar/icons/`). It replaces the glyph. It is drawn in the bar's text colour unless `iconTint` is `"own"`.
- **GROUP-16** `faceRuns(group, face)` gives the pieces to draw: `glyph` is the icon (text in its font, or the image); `text` is the name in the bar's font; `both` is icon, a one-space gap, name. An empty `face` argument uses the group's own face.
- **GROUP-17** `needsRuns(group, face)` is true for `both`, and for any face except `text` when the group has an image; those faces are drawn by GroupFace.qml. A plain glyph or name is one text button.
- **GROUP-18** `tooltip` is unset, true or false. The tooltip is the group's name (no shortcut). Unset: shown only when the face is `glyph`; true: always; false: never; on a vertical bar with a non-glyph face it is always shown.

## Badge

- **GROUP-19** `badge` (default true) shows a count on the group icon's top-right corner while the total is above 0 and the icon is on the bar; the badge uses the urgent colour when any counted member is urgent, else the accent colour.
- **GROUP-20** `badgeMode` `"sum"` (default) adds the members' counts; `"members"` counts how many members have a count above 0.
- **GROUP-21** Per member, `GroupBadgeModel.sample()` takes the first numeric property above 0 of `unseenCount`, `downCount`, `updateCount`, `badgeCount`, `notificationCount`, `unreadCount`, `alertCount`, `pendingCount`, `count` on the widget root (floored, capped at 9999), or the entry's `powerbarBadgeProperty` alone; `"none"` or no match gives 0.
- **GROUP-22** Urgent: the entry's `powerbarUrgentProperty` must be `true`; otherwise the first boolean among `hasUnseenPerson`, `urgent`, `isUrgent`, `critical`, `hasAlert`, `severe` decides; if none of those exist, a count that came from `downCount` or `alertCount` is urgent. Property names must be plain identifiers.
- **GROUP-23** `aggregate(samples, mode)` adds counts (`sum`) or counts members with a count (`members`), and ORs urgency; members with count 0 are ignored.
- **GROUP-24** The badge is the aggregate of the group's drawable members on that monitor's bar.
- **GROUP-25** Badges are read from live properties; there is no polling and no second widget instance.

## Zone and place

- **GROUP-26** `section` is `left`, `center` or `right` (default `right`); changing it through `edit()` clears `before`.
- **GROUP-27** `before` is the `powerbarInstance` of the widget the icon sits before; empty (or a key no longer in the zone) means the zone's end. When that widget leaves the zone, the icon stays in place by re-anchoring on the widget that followed it.
- **GROUP-28** `nextAnchor(config, section, key)` is the key of the widget after `key` in the zone, or "".
- **GROUP-29** `reanchor(config, section, key, next)` moves every icon of that zone anchored on `key` to `next`; false when none, or when `key` is still right before `next`.
- **GROUP-30** `moveHeader(config, id, section, beforeKey, relativeGroupId, after, visibility)` places the icon: next to another group's icon (before it, or after it when `after`), else before `beforeKey` in `section`, else at the zone's end. It sets the icon's visibility (`shown` or `managed` only). It returns false for an unknown group, a missing target group or `beforeKey`, itself as target, or another visibility value.
- **GROUP-31** Moving the icon changes no member's saved position.
- **GROUP-42** The bar draws each group whose visibility is not `hidden` in its zone before its anchor widget (at the zone's end if there is none); the layout itself is unchanged. Code: `GroupsModel.render()`.
- **GROUP-49** `visibility` is `shown` (default; the icon is always on the bar), `managed` (On demand: the icon is hidden at rest, reachable from the zone's drawer or dots like any On demand widget) or `hidden` (no icon on the bar at all; its members stay off the main bar).
- **GROUP-50** For a `managed` group, activity in any member reveals its icon in the zone for the reveal duration (on-demand-drawers.md DEMAND-12).
- **GROUP-51** On an autohidden bar that activity also slides the bar (or the zone's island) out and highlights the icon as if hovered (DEMAND-14), then both slide back.
- **GROUP-52** With `powerbarAutoHideActivity` false the autohidden bar does not slide out for member activity; a `managed` group's icon is still revealed on a visible bar.
- **GROUP-96** Rows and width of a menu: each row is one highlight-cell thick (32 px on a 38 px bar), rows sit one inset apart (3 px) with one inset of padding on every side. A row's name starts after the icon cell when the row shows an icon (`memberDisplay: "both"` and the member draws a glyph), otherwise at the icon edge, so all names share one left edge; a value the widget draws as text (battery %) is right-aligned one air from the row's end. The width fits the widest row plus two insets, at least four cells (128 px on a 38 px bar) and at most 320 px; longer names are cut with an ellipsis. Code: `ManagedModel.menuWidth()`, `menuLabelStart()`.
- **GROUP-97** A menu row takes the pointer whole: a click anywhere on it presses the member, a right click presses it as a right click, the wheel is passed to the widget, and a drag anywhere on the row drags the member.
- **GROUP-98** Menu placement: under a horizontal bar the first row starts where the icon's cell starts (shifted back by one inset); near the screen's far edge the menu flips so its last row ends one inset past where the cell ends. Beside a vertical bar the first row's centre is level with the icon's centre, and near the bottom the last row's. Never closer than one bar gap to a screen edge. Code: `ManagedModel.placeMenu()`.

## Drawer and menu

- **GROUP-32** Pointing at a group icon opens its drawer or menu at once (a hover drawer: no keyboard focus, same grace timers as a zone drawer). One drawer is open at a time.
- **GROUP-33** `memberDisplay`: `native` (default) shows each member as it draws itself in a strip; `name` shows a menu of names only; `both` a menu of icon and name (and value).
- **GROUP-34** `native` groups open a strip along the bar (vertical beside a side bar). `name` and `both` groups always open a vertical menu, with the island border, opacity, blur and shadow, Omarchy's menu font and text colour, and the island radius. The `orientation` setting (`auto`, `horizontal`, `vertical`) is saved but changes nothing today.
- **GROUP-35** Members appear in `items` order; each is the live widget, so its own clicks, wheel and panels work.
- **GROUP-36** A left click on the icon opens the drawer pinned (keyboard mode: it takes focus and has no close timer); a second click, Escape or a click outside closes it. A hover drawer closes by the grace timers. A right click on the icon opens Preferences on the Groups page with that group selected.
- **GROUP-37** After the pointer leaves a hover drawer's icon without entering the drawer it closes after `powerbarManagedEntryGraceSeconds` (default 1 s); after entering and leaving the drawer, after `powerbarManagedExitGraceSeconds` (1 s). Both range 1 to 15. Re-entry cancels.
- **GROUP-38** When a member's panel opens from the drawer, the drawer fades aside; when the panel closes, a hover-opened drawer closes 150 ms later and a pinned one comes back (on-demand-drawers.md DEMAND-51 to DEMAND-53).
- **GROUP-39** Opening a group's drawer with no member (IPC, click) opens nothing; opening it for the keyboard (click, `group`, `toggleGroup`, the keyboard mode) selects no member until the first navigation key.
- **GROUP-40** Opening a group's drawer closes a zone drawer, and the reverse.
- **GROUP-41** A group's drawer lists only members that have a slot on the same bar window, in `items` order.
- **GROUP-43** The icon is a button: left press toggles the pinned drawer, right press opens Preferences. Dropping or dragging: drag-edit.md.
- **GROUP-44** Starting a pointer drag on the group's own icon closes its drawer (drag-edit.md DRAG-5, DRAG-50).

## Shortcuts

- **GROUP-45** A group can have a shortcut (`powerbarShortcuts["group:<id>"]`, default none). It is a bind in the marked Powerbar block of `~/.config/hypr/bindings.lua` that runs `omarchy-shell powerbar toggleGroup <id>`. Recording, rendering and conflicts: keyboard.md KEYS-53 to KEYS-60; CLI: integration.md INTEG-125.
- **GROUP-46** `omarchy-shell powerbar group <id>` opens that group's drawer for the keyboard on the focused monitor's bar; unknown id or monitor: nothing happens.
- **GROUP-47** `omarchy-shell powerbar toggleGroup <id>` closes the drawer when that group's is open, else does what `group <id>` does.

## Keyboard

- **GROUP-48** In the bar's keyboard mode the into-screen key on a group icon opens its drawer with keyboard focus, no member selected; the same key (or Escape) leaves it. Keys, preview on key release, search and the name card: keyboard.md KEYS-10, KEYS-20, KEYS-25 to KEYS-31.
- **GROUP-74** to **GROUP-77** moved to keyboard.md (retired).

## Saved fields (`bar.powerbarGroups`)

Each entry is read through `GroupsModel.groups()`, so a missing or invalid value reads as its default.

- **GROUP-54** `id` (string, required): unique; later duplicates, entries that are not objects and entries without a string id are dropped.
- **GROUP-55** `label`: name (default "Group" when empty).
- **GROUP-56** `icon`: glyph (default "󰉋").
- **GROUP-57** `iconFont`: `"omarchy"` or absent.
- **GROUP-58** `iconImage`: image path or absent.
- **GROUP-59** `iconTint`: `"own"` or absent (text colour).
- **GROUP-60** `section`: `left`, `center`, `right` (default `right`).
- **GROUP-61** `before`: anchor key (default "").
- **GROUP-62** `visibility`: `shown` (default), `managed`, `hidden`.
- **GROUP-63** `face`: `glyph` (default), `text`, `both`.
- **GROUP-64** `tooltip`: boolean or absent.
- **GROUP-65** `badge`: boolean (default true; only an explicit false turns it off).
- **GROUP-66** `badgeMode`: `sum` (default) or `members`.
- **GROUP-67** `orientation`: `auto` (default), `horizontal`, `vertical`; no effect (GROUP-34).
- **GROUP-68** `items`: ordered `powerbarInstance` keys; non-strings, empty strings, `group:` keys, duplicates, keys already in an earlier group and keys no longer in the layout are dropped (GROUP-3, GROUP-8).
- **GROUP-85** Unknown values of `visibility`, `face`, `section`, `badgeMode`, `orientation` and `memberDisplay` read as their defaults (GROUP-54 to GROUP-68), and the CLI refuses them (integration.md INTEG-134).
- **GROUP-69** `memberDisplay`: `native` (default), `name`, `both`.

## Glyph detection (for the icon picker's "On your bar" source)

- **GROUP-70** `GlyphModel.glyphFrom(text)` is the first private-use (Nerd Font) character of a button's text, else the text itself when it is 1 to 3 non-space characters that include a letter ("EN"), else "". Numbers, long text and values are not glyphs.
- **GROUP-71** `GlyphModel.pick(buttons)` takes the first visible button with a glyph, else the first hidden one; `parts` is the number of visible buttons with text (more than one is a compound such as workspaces). No glyph gives null.
- **GROUP-72** The glyph store (`~/.cache/powerbar/glyphs.json`) keeps the last glyph seen per instance, so a hidden widget keeps its picture: `merge()` returns the same store when glyph, font, size and parts are unchanged; `forget()` drops a widget that stops drawing a glyph.
- **GROUP-73** `prune()` keeps only instances still in the layout.

## Retired IDs

GROUP-78 to GROUP-83 (dragging) moved to drag-edit.md (DRAG-14, DRAG-15, DRAG-24, DRAG-27, DRAG-48, DRAG-53). GROUP-84 merged into GROUP-3; GROUP-86 and GROUP-87 into GROUP-85 and GROUP-54 to GROUP-68; GROUP-88 and GROUP-89 into GROUP-46 and GROUP-47; GROUP-90 to GROUP-92 into integration.md (INTEG-52, INTEG-54, INTEG-56); the old GROUP-96 into GROUP-50. GROUP-74 to GROUP-77 moved to keyboard.md (KEYS-10, KEYS-25 to KEYS-31, KEYS-49). The numbers GROUP-96 to GROUP-98 are new (menu geometry, moved from on-demand-drawers.md).

## Doc drift

- None found: README.md "Groups", docs/design/groups.md and CONTEXT.md "Group" agree with the code (README's `groupsPreferences` opens the Groups page, Bar.qml:595).

## Open questions

- Dead setting: `orientation` is stored, shown by the CLI and settable, but `ManagedModel.drawerVertical()` ignores it (tests/managed.test.cjs "groups with member names ..." asserts that). Either wire it or remove it.
- Dead field in the old draft: `memberDisplayLayout` does not exist in code; removed.
- Possible bug: `GroupsModel.edit()` replaces the icon but keeps `iconTint: "own"`, so a later picked image starts as "own" (GroupsModel.js:117-124, `iconTint` untouched when `icon` is set).
