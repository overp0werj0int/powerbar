# Groups

> Design notes. The behavior of record is [groups.md](../behavior/groups.md).

Named groups are Powerbar configuration, not additional plugins. Persist them
in `bar.powerbarGroups` with stable IDs, labels, icons, zones, optional placement
anchors, and ordered lists of existing `powerbarInstance` keys. Widgets stay in
their existing layout entries, retaining settings and service enablement.
No new processes, packages, credentials, or network calls are required.

Group members stay off the main bar and out of the zone's managed drawer. The
group icon opens the existing ManagedDrawer with that group's ordered members.
Hover opens temporarily; click pins/unpins. Only one drawer is active per bar;
switching groups closes any child panel. Existing animation, dismissal, and
keyboard interaction apply. Nested groups are excluded.
Icon-only drawers follow the bar orientation and use the Powerbar island appearance.
NAME and BOTH member displays always use a vertical menu with Powerbar's border,
opacity, blur, and shadow, Omarchy's menu font, and the island radius (rows sit one
inset in, so their corners are concentric with the menu's). Geometry, placement and
motion for strips and menus follow the spacing design ([spacing.md](spacing.md), "Extended islands").
Keyboard opening leaves rows unselected until
the user navigates; reopening never carries a cursor highlight forward.

Groups preferences (`GroupsPreferences.qml`)
are a bento page: a shelf of the groups drawn as the bar draws them, the selected
group's settings in a three-column grid whose rows line up, then its drawer drawn
exactly as it opens beside the widgets not in a group. They provide creation,
deletion, labels, icons, positions, widget assignment, transfer, and ordering.
The icon picker (`IconPicker.qml`, `IconSearch.js`) searches the glyphs your
widgets draw, Omarchy's own font, the Nerd Font glyphs Omarchy uses
(`OmarchyIcons.js`, written by `tools/omarchy-icons.py`; run it again after an
Omarchy update) and Omarchy's emoji, or takes your own SVG or PNG by drop, paste
or path. A chosen glyph keeps its font (`iconFont`); your own image is copied to
`~/.local/share/powerbar/icons/` (`iconImage`) and drawn in the text colour unless
`iconTint` is `"own"`. Faces that mix fonts or show an image draw as runs
(`GroupFace.qml`). Deleting a group restores its widgets' prior
visibility and placement. Explicitly hidden widgets remain hidden.

Layout (`LayoutEditor.qml`) and Groups (`GroupsPreferences.qml`) share one
interaction model: a keyboard cursor, Space to pick an item up, movement to
preview where it lands, Space or release to drop, Esc to put it back. Layout uses
zones and visibility rows; Groups uses ordered member and available lists. Group
headers appear in Layout with their saved face. Their visibility is independent of their members;
member activity reveals a managed group header.

The unified Appearance page applies the same border, rounding, shadow, blur, and
opacity to every bar surface. Legacy main-bar effects are the fallback; extended
overrides no longer split the appearance. Blur toggles remap the bar surface once
to apply the compositor namespace; drawer transitions do not remap it.

Verification: pure model tests pass for identity, duplicates, preservation,
transfer, ordering and deletion. QML syntax checks and the existing activity and
animated-slot suites pass. Live checks covered creation, renaming, preference
drag assignment/transfer/reordering, ordered drawers, hover and pin opening, and
dragging a drawer member onto another group's bar icon. Temporary groups were
removed afterward. Outside-click dismissal and horizontal group placement still
need manual acceptance checks.

Preferences refactor validation: all four model test files and seven QML test
checks pass. Live horizontal checks covered group creation, assignment by drag,
renaming, stock menu icon selection, keyboard zone movement in Layout, opacity
slider persistence, and compositor namespace changes when toggling blur. Test
groups and appearance overrides were removed. Vertical layout was not visually
rechecked in this refactor.

Mini Bar parity: per-group glyph/text/both face, tooltip, badge on/off, SUM/COUNT
aggregation, optional member property overrides, and native/name/both drawer
member display. Grouped native widgets
remain loaded while closed. Drawer members can be dragged out to return them to
the bar. Groups, General and Appearance share the `Prefs*` form components.

Badge values are read reactively from widget root properties through
`GroupBadgeModel.js`; no process, poller, or duplicate service is introduced.
The custom property names are constrained to plain QML property identifiers.
The host's service-facade limitation for third-party widgets remains.
