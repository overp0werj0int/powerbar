# Research: sources that earned their place

Start from these, then search for the specific question. Re-check links when
you cite them; keep a source only if it changes a rule or a number.

## Spacing, grouping, highlights

- Apple, Get to know the new design system (WWDC25) — concentricity; nested
  shapes share a centre; grouped toolbar items share one surface.
  https://developer.apple.com/videos/play/wwdc2025/356/
- Nested border radius — inner radius = outer radius − gap.
  https://www.30secondsofcode.org/css/s/nested-border-radius/ ,
  https://uxplanet.org/corner-radius-of-nested-elements-in-ui-design-4c27bb24a854
- GNOME Shell panel buttons — `-natural-hpadding: 12px`, `-minimum-hpadding: 6px`.
  https://github.com/x7c1/sutto/pull/82
- macOS menu bar — `NSStatusItemSpacing` (gap) vs `NSStatusItemSelectionPadding`
  (highlight padding). https://errickson.net/blog/mac-menu-bar-spacing.html ,
  https://github.com/jordanbaird/Ice
- Material 3 toolbars and icon buttons — 48 dp targets around 24 dp icons.
  https://m3.material.io/components/toolbars/guidelines ,
  https://m3.material.io/components/icon-buttons/accessibility
- Optical effects in UI — equal math can look uneven; centre on visual mass.
  https://medium.com/design-bridges/optical-effects-9fca82b4cd9a
- Figma auto layout — fixed gap vs space-between vs evenly.
  https://help.figma.com/hc/en-us/articles/360040451373-Guide-to-auto-layout

## Targets and pointing

- NN/g, Fitts's law — https://www.nngroup.com/articles/fitts-law/
- Coding Horror, infinite width at screen edges —
  https://blog.codinghorror.com/fitts-law-and-infinite-width/

## Drag and drop

- react-beautiful-dnd — impact from the dragged item's centre of gravity,
  not the grab point. https://medium.com/@alexandereardon/rethinking-drag-and-drop-d9f5770b4e6b
- Mixed-size items are the hard case —
  https://github.com/atlassian/react-beautiful-dnd/issues/930
- Atlassian accessible drag and drop: Space lifts, arrows move, Space drops,
  Esc cancels.

## Motion

- Material, duration and easing — longer distances get longer durations.
  https://m3.material.io/styles/motion/easing-and-duration
- Emil Kowalski's animation guidance (via `omarchy-widget-ux`): frequency
  decides whether to animate; ease-out to enter, ease-in-out to move; under
  300 ms.

## Query ideas

- "<platform> menu bar / panel / taskbar item spacing padding"
- "optical spacing icons mixed width toolbar"
- "<design system> toolbar grouped items shared background"
- "drag and drop reorder variable size items placeholder"
- "motion duration distance travelled"
- "settings label naming <concept> user research" (for naming decisions)
