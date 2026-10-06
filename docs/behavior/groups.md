# Groups

Groups are named, ordered collections of existing widget instances on the bar. Each group has its own icon (a glyph, user image, or Omarchy logo), display mode (icon only, name only, or both), zone, visibility mode, and drawer showing its members with their widget's own presentation. Groups are stored in `bar.powerbarGroups`, reference widget instances by their stable `powerbarInstance` keys, and do not change widget settings, visibility modes, service enablement, or layout positions; membership overrides main-bar visibility only.

**Sources:** GroupsModel.js, GroupBadgeModel.js, GlyphModel.js, GroupFace.qml, Bar.qml (grep group, powerbarGroup), ManagedDrawer.qml, tests/groups.test.cjs, tests/group-badges.test.cjs, tests/glyph.test.cjs, README.md (Groups section), docs/groups.md, CONTEXT.md.

## Group lifecycle

- **GROUP-1** Given a valid group ID (a non-empty string), a group label, when creating a group with `GroupsModel.create(config, id, label)`, then the group is added to `bar.powerbarGroups` with default icon (󰉋, the "Group" glyph), section "right", visibility "shown", face "glyph", empty items list, and `badge: true`, `badgeMode: "sum"`, `orientation: "auto"`, `memberDisplay: "native"`. Label is trimmed and capped at 80 characters. Returns true; false if the ID is empty, already exists, or the config has no bar.

- **GROUP-2** Given a valid group ID, when deleting a group with `GroupsModel.remove(config, id)`, then the group is removed from `bar.powerbarGroups` and its members lose their group membership (stored separately in group.items). Returns true; false if the group does not exist.

- **GROUP-3** When a widget is uninstalled since being grouped, `GroupsModel.groups()` drops the dangling member from the group's items list automatically, without removing the group. `GroupsModel.danglingMembers()` counts uninstalled members; the bar writes the cleaned list once when loading config.

- **GROUP-4** When there is no layout (a config still loading), `GroupsModel.groups()` keeps all members even if their keys are not yet in the layout. `danglingMembers()` returns 0.

- **GROUP-5** A group with no members remains in the list and renders as an icon on the bar. Rendering the group draws only the icon, never the empty drawer.

## Group membership

- **GROUP-6** Given a widget instance key (a powerbarInstance not starting with "group:"), when assigning it to a group with `GroupsModel.assign(config, key, id, before)`, then the widget is added to the group's items list at the position of the `before` key, or at the end if `before` is not in items or empty. It is removed from all other groups first. Returns true; false if the group ID is invalid, the key does not exist in layout, the key is a group pseudo-key, or `before === key`.

- **GROUP-7** When a member is assigned to a group, the widget stays in its layout entry, retains its saved visibility mode ("shown" or "managed"), settings, and service enablement. Widget visibility is overridden only by group membership; the widget is not drawn on the main bar while in a group (its location on the bar is replaced by the group icon).

- **GROUP-8** Transferring a member to a different group uses the same `assign()` call. The member is removed from the old group and added to the new one, preserving order relative to the `before` key.

- **GROUP-9** When assigning a member to an empty string or passing no group ID (null destination), `GroupsModel.assign(config, key, "", void)` or `assign(config, key, id, before)` where `id` is falsy removes it from all groups. Returns true if it was grouped, false otherwise.

- **GROUP-10** A widget instance can belong to only one group at a time. Assigning it to a new group removes it from its old group.

- **GROUP-11** When a group is deleted, its members are not deleted from the layout and do not lose their settings or service enablement.

## Group icons and display

- **GROUP-12** A group's `face` property is "glyph" (icon only), "text" (name only), or "both" (icon and name). Defaults to "glyph". The bar draws face types that need runs (images or "both" with a non-bar-font icon) using GroupFace.qml; plain text buttons draw a single string.

- **GROUP-13** A group's `icon` property is a Unicode glyph (e.g., "󰉋"). When a new icon is chosen (via `GroupsModel.edit(config, id, { icon: glyph })`), any prior custom image or font is cleared; the glyph keeps the font it was chosen in via `iconFont`. Returns true if the edit succeeds; false if the group ID is invalid.

- **GROUP-14** A group's `iconFont` is preserved when set and defaults to the font of the icon in the stock list (empty for most, "omarchy" for the logo U+E900). An icon saved before fonts were tracked falls back to the stock list's font. `GroupsModel.groupIconFont(group)` returns the effective font.

- **GROUP-15** A group can use a custom image (SVG or PNG) via `iconImage`, a file path in `~/.local/share/powerbar/icons/`. When set, it overrides the icon glyph. The image is drawn tinted in the bar's text colour unless `iconTint` is "own" (drawn in its own colours). Setting a new glyph icon clears `iconImage` and `iconTint`.

- **GROUP-16** `GroupsModel.faceRuns(group, face)` returns an array of runs: for "glyph", one run with the icon (a text glyph in its font, or an image); for "text", one run with the label in the bar's font; for "both", the icon run, a space gap run (accounting for glyph ink overhang), and the name run. An empty face mode falls back to the group's own face setting.

- **GROUP-17** `GroupsModel.needsRuns(group, face)` returns true if the face must be drawn as runs (because it has an image or is "both" with a non-bar icon font). The bar uses this to choose between a text button and GroupFace.qml.

- **GROUP-18** A group's `tooltip` property (boolean, defaults to undefined). When true, the group shows a tooltip with its name and shortcut. Omitted unless explicitly set.

## Group badges and notifications

- **GROUP-19** A group's `badge` property (boolean, defaults to true) controls whether a notification badge is shown. A badge counts or marks member activity using live properties on the widget root.

- **GROUP-20** A group's `badgeMode` is "sum" (add member counts) or "members" (count how many members have activity). Defaults to "sum".

- **GROUP-21** `GroupBadgeModel.sample(item, badgeOverride, urgentOverride)` reads one widget's badge and urgent state. It scans the widget's properties in order: `badgeOverride` (custom property name, or "none" to exclude), or the list `["unseenCount", "downCount", "updateCount", "badgeCount", "notificationCount", "unreadCount", "alertCount", "pendingCount", "count"]`. It returns the first numeric property > 0 (capped at 9999). Returns `{ count: 0, urgent: false }` if none found or `badgeOverride === "none"`.

- **GROUP-22** Urgent state is determined by `urgentOverride` (custom property name), or by scanning `["hasUnseenPerson", "urgent", "isUrgent", "critical", "hasAlert", "severe"]` for a boolean. If the count came from "downCount" or "alertCount", urgent defaults to true. Defaults to false.

- **GROUP-23** `GroupBadgeModel.aggregate(samples, mode)` combines member samples: in "sum" mode, adds counts and ORs urgency; in "members" mode, counts members with `count > 0` and ORs urgency. Ignores samples with count 0.

- **GROUP-24** When the bar's `groupBadge(id, window)` is called, it gathers `GroupBadgeModel.sample()` for each group member from `groupSlots()`, then aggregates them with the group's `badgeMode`. Returns `{ count, urgent }`.

- **GROUP-25** Badge properties are read reactively; no polling or extra widget instances. The bar watches widget properties and updates the badge when they change.

## Group zones and placement

- **GROUP-26** A group's `section` property is "left", "center", or "right". This determines which zone the group icon appears in on the bar. Defaults to "right".

- **GROUP-27** A group's `before` property is the `powerbarInstance` key of a widget the group is positioned before in its zone. Empty means the group appears at the end of its zone. When the widget is moved away, the group reanchors to the next widget (or the zone end if there is none).

- **GROUP-28** `GroupsModel.nextAnchor(config, section, key)` returns the `powerbarInstance` of the widget that follows the given key in the zone, or "" if it is last. Used before moving a widget to update the group's anchor.

- **GROUP-29** `GroupsModel.reanchor(config, section, key, next)` updates all groups anchored on `key` in the zone to anchor on `next` instead. Returns true if any groups were reanchored; false if none were or if the group is already at the same position. Call after moving the anchor widget to keep groups in place.

- **GROUP-30** `GroupsModel.moveHeader(config, id, section, beforeKey, relativeGroupId, after, visibility)` moves or reorders the group icon on the bar. If `relativeGroupId` is set, the group is placed relative to that group (before it if `after` is false, after it if true); otherwise it is placed at `beforeKey` in the zone. `visibility` must be "shown" or "managed". Returns true on success; false if the source or target group is invalid or parameters are malformed.

- **GROUP-31** The group icon's position on the bar does not change its members' saved positions in the layout; it is a runtime rendering that groups members for display and interaction.

## Group drawers

- **GROUP-32** Each group has its own drawer showing its members. The drawer is opened by hovering or clicking the group icon, or via the keyboard/IPC. Only one extended drawer (group or zone) is open at a time.

- **GROUP-33** The group drawer's member display mode is controlled by `memberDisplay`: "native" shows each member as the widget draws itself, "name" shows a list of member names only, "both" shows icon and name. Defaults to "native".

- **GROUP-34** Icon-only drawers (memberDisplay "native" with memberDisplayLayout "icon", or memberDisplay "name") follow the bar's orientation (horizontal or vertical). Named menus (memberDisplay "name" or "both") always use a vertical menu with Powerbar's border, opacity, blur, and shadow, Omarchy's menu font, and the main theme's corner radius.

- **GROUP-35** A group drawer's members are drawn in the order they were added to the group (stored in group.items), with no reordering by activity or visibility. Members are rendered using the drawer's display mode.

- **GROUP-36** When hovering the group icon on the bar, the group drawer opens temporarily (the "hover" open). When clicking the group icon, the drawer pins open (the "click" open). Clicking again, pressing Escape, or clicking outside the drawer closes it.

- **GROUP-37** A group drawer remains open while hovering its source icon. After leaving the icon, it stays open for up to 1 second (configurable via `powerbarManagedExitGraceSeconds`, range 1–15); re-entry cancels the countdown. A pinned drawer (opened with a click) does not auto-dismiss.

- **GROUP-38** When a member's panel (a popup or menu) opens from the drawer, the drawer steps aside (fades and loses click-through). The drawer steps back when the panel closes. If the drawer was opened with a click, it remains open after the panel closes; if opened with a hover, it closes after 3 seconds.

- **GROUP-39** `ManagedDrawer.openGroup(id, slot, keyboard)` opens the group drawer. If `keyboard` is true, the drawer is opened for keyboard navigation (no initial selection). The drawer is anchored to the group icon's location (`slot`).

- **GROUP-40** `ManagedDrawer.groupId` holds the ID of the open group, or "" if a zone drawer is open. `groupConfig` provides the group's settings (from `bar.groups`).

- **GROUP-41** `ManagedDrawer.slots` returns the drawable members when a group drawer is open: `bar.groupSlots(id, window).filter(...)` in the group's display order. These are live widget slots, not copies; dragging, clicking, and the widget's own state interact with the original.

## Group rendering and interaction

- **GROUP-42** `GroupsModel.render(layout, list)` is a helper that builds the rendered bar layout by inserting group icons into the layout at their saved positions (in the right zone, before the `before` widget). Each group icon is rendered as an entry with `id: "powerbar.group.<id>"`, `type: "group"`, `powerbarGroupId: id`, `powerbarInstance: "group:<id>"`, and `powerbarVisibility: group.visibility`. This is a runtime projection; the layout itself is not modified.

- **GROUP-43** The bar renders group icons as buttons that open the group drawer. Icon-only groups show just the icon; groups with face "both" show the icon and name using GroupFace.qml.

- **GROUP-44** When a group member draws a custom presentation (widget panel, context menu, popover), it uses the group drawer's display mode to show the member, not the main bar's view of the widget.

## Group shortcuts

- **GROUP-45** Each group can be assigned a shortcut key sequence (e.g., Super+A for Audio group). Shortcuts are stored in `powerbarShortcuts` and written to `~/.config/hypr/bindings.lua` in a marked block `-- >>> powerbar:` / `-- <<<`.

- **GROUP-46** `omarchy-shell powerbar group <id>` opens the group drawer on the focused monitor, pinning it if it was already open. On the bar, the group icon is highlighted.

- **GROUP-47** `omarchy-shell powerbar toggleGroup <id>` opens the group drawer if closed, or closes it if open. If a panel is open from a drawer member, the drawer stays open after the panel closes.

- **GROUP-48** The keyboard shortcut (default Super+B in Preferences → Keyboard) enters keyboard mode on the bar cursor. Pressing the into-screen key (↓ on top bar) when the cursor is on a group icon opens the group drawer with keyboard focus; no member is selected until navigation begins. The same keys again exit the drawer.

## Visibility and activity

- **GROUP-49** A group's `visibility` property is "shown" (always on the bar), "managed" (revealed on member activity), or "hidden" (not on the bar). Defaults to "shown".

- **GROUP-50** When a group member has activity (icon/value change, notification), and the group's visibility is "managed", the group icon is revealed on the bar for 2.5 seconds (the same duration as the autohide activity reveal). The activity also highlights the group icon as if hovered.

- **GROUP-51** When the bar's autohide is on and a group member has activity, the bar slides out (or its activity island if using islands style) and the group icon is revealed and highlighted, then both slide away after 2.5 seconds.

- **GROUP-52** If `powerbarAutoHideActivity` is false (Bar → Behavior → Show on widget activity off), managed group members do not trigger a reveal; the group stays hidden.

- **GROUP-53** Explicitly hidden group members stay hidden even when grouped; they are not drawn in the group drawer or on the main bar.

## Group configuration

Groups are stored in `bar.powerbarGroups` array (shell.json). Each entry is an object:

- **GROUP-54** `id` (string, required): unique group identifier.
- **GROUP-55** `label` (string, required): group name, trimmed, up to 80 characters.
- **GROUP-56** `icon` (string, required): Unicode glyph (e.g., "󰉋").
- **GROUP-57** `iconFont` (string, optional): "omarchy" or omitted. Preserves the icon's font.
- **GROUP-58** `iconImage` (string, optional): file path in ~/.local/share/powerbar/icons/. Overrides icon glyph. Omitted unless set.
- **GROUP-59** `iconTint` (string, optional): "own" to draw the image in its own colours, otherwise omitted (tinted in bar text colour).
- **GROUP-60** `section` (string): "left", "center", or "right". Defaults to "right".
- **GROUP-61** `before` (string): powerbarInstance key of the widget this group precedes, or "" for end-of-zone. Defaults to "".
- **GROUP-62** `visibility` (string): "shown", "managed", or "hidden". Defaults to "shown".
- **GROUP-63** `face` (string): "glyph", "text", or "both". Defaults to "glyph".
- **GROUP-64** `tooltip` (boolean, optional): show name and shortcut tooltip. Omitted unless set.
- **GROUP-65** `badge` (boolean): whether to show notification badge. Defaults to true.
- **GROUP-66** `badgeMode` (string): "sum" (add counts) or "members" (count members). Defaults to "sum".
- **GROUP-67** `orientation` (string): "auto", "horizontal", or "vertical". Defaults to "auto". Used for icon-only drawers.
- **GROUP-68** `items` (array of strings): ordered list of widget instance keys (powerbarInstance). Updated by drag and assignment operations.

## Glyph detection

GroupsModel and the icon picker use GlyphModel.js to extract meaningful icons from widget buttons:

- **GROUP-69** `GlyphModel.glyphFrom(text)` returns the first Nerd Font private-use character in the text, or a short text label (1–3 characters) with letters (e.g., "EN", "AI"), or "". Bare numbers and long text are not glyphs.

- **GROUP-70** `GlyphModel.pick(buttons)` selects the first visible button with a glyph, or the first hidden button if none is visible. Returns `{ glyph, font, size, parts }` where `parts` is the count of visible buttons with non-empty text (a compound like workspaces has multiple parts). Returns null if no button has a glyph.

- **GROUP-71** `GlyphModel.merge(store, key, entry)` updates a glyph store (JSON in `~/.cache/powerbar/glyphs.json`), adding or updating an entry. Returns the same store if nothing changed (same glyph, font, size, and parts count).

- **GROUP-72** `GlyphModel.forget(store, key)` removes a widget's stored glyph (when it stops drawing one).

- **GROUP-73** `GlyphModel.prune(store, keys)` keeps only glyphs for widget instances still in the layout, dropping the rest.

## Keyboard interaction

- **GROUP-74** When the keyboard cursor is on a group icon, pressing the into-screen key (↓ on top bar, → on right bar, etc.) opens the group drawer. The first member is not highlighted until the user navigates.

- **GROUP-75** In a group drawer opened from the keyboard, j / k (or Up / Down arrows) move between members. Space or Enter activates the member. The opposite key (↑ on top bar) returns to the cursor.

- **GROUP-76** The "/" key in keyboard mode starts a search. Search matches members by their name and the group's name. Tab and Shift+Tab move between matches. ↓ (on top bar) opens a found group's drawer directly from the search.

- **GROUP-77** `omarchy-shell powerbar keysStatus` returns JSON with keyboard mode state, including the cursor position and any open group drawer (groupId field).

## Drag and drop

- **GROUP-78** Dragging a widget onto a group icon adds it to the group (or reorders it if already a member), moving it to the end of the group's items list. The source slot stays visible; the icon glides to the group icon on release.

- **GROUP-79** Resting a drag on a group icon for 400 ms opens the group drawer (the "spring open"). The drawer closes when the pointer leaves the icon or the drag is released.

- **GROUP-80** Dropping a widget into an open group drawer adds or reorders it in the group's items list. The drop lands before the member or widget under the pointer, or at the end if over empty space.

- **GROUP-81** Dragging a group member out of a drawer and dropping it on the main bar or a zone's dots removes it from the group. Visibility and settings are not changed.

- **GROUP-82** Dragging a group member onto another group icon transfers it to the other group, removing it from the first.

- **GROUP-83** Dragging a group icon (the header) can reorder it relative to other groups or move it to a different zone. The group's section and before properties are updated. Members are not reordered.

## Configuration healing and cleanup

- **GROUP-84** When loading configuration, if a member's instance key is not in the layout (a widget was uninstalled), the member is automatically dropped from the group. `GroupsModel.danglingMembers()` counts these; the bar writes the cleaned list once to shell.json.

- **GROUP-85** Duplicate group IDs in the raw config are deduplicated: only the first is kept. Malformed entries (null, missing id, non-string id) are filtered out.

- **GROUP-86** Unknown or invalid values in group properties are sanitized: unknown visibility / face / orientation / memberDisplay values are replaced with defaults; invalid types are coerced or rejected.

- **GROUP-87** A group entry missing a required field (id, label, icon, section, items) gets a default; the group is still included in the list.

## IPC and state queries

- **GROUP-88** `omarchy-shell powerbar group <id>` (internal implementation `Bar.Keyboard.group(id)`) opens the group drawer on the focused monitor's bar. The group icon is highlighted and pinned open.

- **GROUP-89** `omarchy-shell powerbar toggleGroup <id>` (internal `Bar.Keyboard.toggleGroup(id)`) toggles the group drawer: if the group is open, closes it; otherwise opens it.

- **GROUP-90** `omarchy-shell powerbar groupsPreferences` (internal `Bar.Keyboard.groupsPreferences()`) opens Preferences on the focused monitor, with the Groups page (page 2) selected.

- **GROUP-91** `omarchy-shell powerbar drawerStatus` returns JSON with drawer state: if a group drawer is open, `{ opened: true, groupId: "id", ... }`; if a zone drawer, `{ opened: true, zone: "left|center|right", ... }`.

- **GROUP-92** `ManagedDrawer.drawerSource(drawer)` returns `"group:<id>"` if a group drawer is open, or `"managed:<zone>"` if a zone drawer.

## Widget state during grouping

- **GROUP-93** A grouped widget stays in its layout entry (the same zone, visibility, settings, instance key). The layout entry is not modified when the widget is grouped or ungrouped.

- **GROUP-94** A widget's service enablement (whether it loads and runs) is not affected by grouping. If the widget is disabled globally, it remains disabled even if grouped.

- **GROUP-95** A widget in a group is not drawn on the main bar; its space is not reserved. Only the group icon and its members' space (in the drawer) are drawn.

- **GROUP-96** When a widget in a managed group is revealed on activity, the group's visibility mode does not change; only the group icon is revealed for 2.5 seconds.

## Doc drift

- No contradictions found between README.md, docs/CONTEXT.md and code for groups.

## Open questions

- Icon picker's exact search algorithm and ranking are in IconSearch.js; refer to preferences.md (PREFS-46, PREFS-47) for search behavior.
- Bar.qml's drag and drop behavior with group members; dragging from a drawer is mentioned but exact positioning rules were not visible in the source read.
