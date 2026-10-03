# Powerbar

Powerbar organizes desktop widgets by placement and visibility.

## Language

**Zone**:
A widget's placement along the bar: Left, Center, or Right. On a vertical bar these correspond to the top, middle, and bottom groups.

**Visibility mode**:
The rule governing a widget's presence: Always shown, Managed, or Always hidden. It is independent of its zone.
Preferences call Managed "On demand".
_Avoid_: Section when referring to a visibility rule.

**Main island**:
The themed surface containing a zone's visible widgets in the main bar.

**Managed drawer**:
A temporary island beside a zone that exposes that zone's managed widgets for interaction.
_Avoid_: Main island when referring to this temporary surface.

**On-demand display**:
How a zone's Managed widgets are reached: in the Managed drawer when the zone
is hovered ("drawer", the default), or by an inline expansion ("inline").

**On-demand run**:
Wherever a zone's Managed widgets appear on the bar (an inline expansion, an
activity reveal), they draw as one run at the zone's dots end, in their saved
order: the left zone's end, the right zone's start, and in the centre on their
side of the center anchor (left of it at the centre's start, right of it at its
end). Always shown widgets never move to make room for them. The saved layout
is not rewritten; Preferences splits the centre's On demand cell at the anchor.

**Inline expansion**:
In the inline display, a zone's Managed widgets wait behind its dots (shared
with widgets folded for lack of room) and expand in the main island, as the
zone's On-demand run, while the dots, then the zone, are hovered. Dots show
only while something waits behind them. The centre has dots on each side of its
anchor, and each side expands on its own. It is a zone-fit moment: neighbours yield.
A neighbour whose anchor would have to yield hides whole, then the zone past it
if needed; an expanding centre may slide back onto the bar. It falls back to
the Managed drawer only when the expanded zone can't fit the bar line.

**Activity reveal**:
A temporary appearance of a managed widget in the main bar after a qualifying activity event or state change.

**Group**:
A named, ordered collection of existing widget instances, represented by one bar icon.
Icon-only groups follow the bar orientation. Groups showing member names use a
vertical menu with Powerbar surface effects and the island radius; see
docs/spacing-lab/spacing-lab.html for drawer geometry.
Membership overrides main-bar visibility
without changing the member's saved zone, visibility mode, settings, or plugin enablement.
Explicitly hidden members remain hidden; groups cannot be nested.

**System widget**:
A widget supplied by the installed Omarchy distribution. User-installed widgets and user-owned clones are custom widgets.

## Current review follow-up

Pointer dragging now addresses layout entries by `powerbarInstance`, matching
Preferences and preserving the intended instance when a plugin appears twice.
An inactive Always shown placeholder opens Preferences on its monitor when its
widget exposes no supported activation method. The manifest names Powerbar's
maintainer and declares MIT; the original Omarchy notice is preserved in LICENSE.

Model tests, QML tests, QML formatting, and plugin validation passed for these
changes. The live Hyprland socket was unavailable during this check. Recheck
duplicate-instance pointer dragging, the placeholder click, outside-click
dismissal, horizontal group placement, and vertical layout in a running shell.

Drag destinations now include group icons and members, managed drawers, and
empty main-bar zones. Main-bar drops set Always shown; managed-drawer drops set
Managed; group drops change membership without rewriting widget settings.
Dropping outside these surfaces cancels. Native widget presentations and group
member labels each have a drawer drag handler. Live pointer acceptance for these
routes remains to be checked in a running shell.

## Drag interaction architecture

One bar-owned controller captures the visible icon once, tracks the pointer and
resolves the destination for main-bar, native-drawer and labelled-drawer drags.
The captured icon keeps the pointer's original grab point, and the source stays
visible until the captured image is ready. The source stays loaded throughout.
`DragModel.js` decides whether the source
holds its space, which slot opens a before/after gap, whether an empty surface
needs an end gap, and whether a group icon is a container target. The Row/Column
and drawer Grid animate widths or heights in place; no widget model is reordered
during the gesture. The moving icon and opening space provide the reorder cue.
Each icon's inset animates independently, so a before-to-after switch slides
the icon across its slot. Edge gaps sit outside Row/Column/Grid positioners;
their fixed spacing cannot introduce an instant step when a gap first appears.
All drag gap and inset transitions share a 150 ms sine ease, avoiding the large
first-frame move of the old 90 ms cubic ease.
On release the captured image stays up and settles for 180 ms. A drop into a
main-bar gap or onto a group icon glides there first, with the gap still open,
and commits only once the image has landed: the commit rebuilds every slot
synchronously, and committing at release froze the image at the pointer for as
long as that took. A short correction glide then covers any offset from the
committed slot. Other drops commit first, then the image glides from the
pointer to the moved icon's new slot, following it frame by frame. That slot
stays hidden until the glide ends and holds the drop gap's extent meanwhile, so
neighbours ease rather than step. An icon whose new home is not visible glides
into and fades over its group icon, or fades where it was released. A cancelled
drop glides back to the source as its space reopens.
The host config changes once on a valid drop. The center
anchor opens its gap in the neighboring list so the anchored icon stays centered.

| From | To | Result |
| --- | --- | --- |
| Main island | Main island or empty zone | Move the instance, set Always shown |
| Main island | Beside a group icon | Move the instance next to the group |
| Main island | Group drawer (opens after resting on its icon) | Add or reorder group membership |
| Main island | Open managed drawer | Move the instance, set Managed |
| Group drawer | Main island | Remove membership, set Always shown |
| Group drawer | Other group icon | Transfer membership |
| Group drawer | A zone's dots | Remove membership, set Managed |
| Managed drawer | Main island | Set Always shown |
| Managed drawer | Group icon | Add group membership |
| Group icon | Main island or another group icon | Move or reorder the group header |
| Group icon | Open managed drawer or a zone's dots | Set group visibility to Managed |
| Any icon | A zone's dots | Move the instance to the dots' end of its On-demand run (the centre: on that dots' side of the anchor), set Managed (On demand) |
| Any icon | Resting 400 ms on a zone's dots | Open the zone: inline expansion or its drawer, by the on-demand display |
| Any icon | Inside an inline expansion's run (between two widgets it shows, or between one and the dots) | Move the instance there, set Managed; where the shown widgets meet the expansion it lands Always shown |
| Any icon | Any gap on the bar | Lands at the gap as drawn: it joins the run of its visibility on the gap's side, so the saved order follows the drawn order |
| Any icon | Outside valid surfaces | Cancel without a config write |

Only one extended drawer can be open at a time. Group icons and the zones'
dots on the main bar allow direct transfers without opening two drawers. A
drawer a drag starts from keeps its rows until the drag ends, and a drop into
an open group drawer leaves it open. Group nesting remains excluded. Portable tests cover
preview decisions, model changes, a QtQuick layout transition, and capturing
the icon before hiding its source; the
live Hyprland socket was unavailable, so pointer feel and actual frame time
still require live acceptance.
