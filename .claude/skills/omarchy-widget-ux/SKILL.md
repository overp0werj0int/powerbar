---
name: omarchy-widget-ux
description: UI/UX, interaction and motion guidance for Omarchy Quickshell (QML) bar widgets, panels, drawers and preference screens such as Powerbar. Use when designing, building, reviewing or polishing any of their visuals, layout, keyboard navigation, drag and drop, previews, highlights, animations or microinteractions, and before writing QML that users will see or touch.
---

# Omarchy Widget UI/UX

A refinement of four sources, adapted to Quickshell/QML on Omarchy:
Anthropic's *frontend-design* (visual direction, copy, self-critique),
the Qt Company's *qt-qml* (QML correctness), Emil Kowalski's design
engineering and animation standards (motion and microinteractions), and
Omarchy's own UI kit and keyboard conventions. It also records what the
Powerbar Preferences redesign taught us.

The goal: interfaces that feel native to Omarchy, work fully from the
keyboard, show the real thing instead of a stand-in, and move only when motion
explains something.

## 1. Process

1. **Name the job.** Who uses this, how often, and what single task it must make
   easy. Frequency decides motion (section 6) and density.
2. **Look at the best comparable tools first.** For bar organisers: Ice and
   Bartender (a live bar you rearrange, rows for visible / hidden). For keyboard
   flow: Raycast, Linear. For accessible drag and drop: Atlassian (Space lift,
   arrows move, Space drop, Esc cancel). Borrow the model, not the look.
3. **Plan before code.** Write down: the one memorable element, the layout
   (a quick ASCII wireframe), the keyboard map, and which Omarchy kit components
   carry it. Check the plan against defaults you would produce for any similar
   screen; replace anything generic with a choice made for this brief.
4. **Build in small verified steps.** Syntax-check every QML file, reload, read
   the shell log, screenshot, look, fix. Never report visual work you have not
   seen (section 9).
5. **Critique like a user.** Before calling it done, walk the whole thing with
   only the keyboard, then only the pointer, then read every string aloud.
   Remove one decoration.

## 2. Visual direction

- **The theme owns colour and type.** Take every colour from `Color` and
  `Style` tokens (`Color.popups.text/background/border`, `Color.accent`,
  `Color.urgent`, `Style.hoverFillFor`, `Style.selectedFillFor`,
  `Style.focusFillFor`, `Style.controlFill`, `Border.controlSpec`). Inside the
  bar use the bar's own foreground (`barForeground`), in popups use
  `Color.popups.text`. Never hard-code hex colours; users switch themes daily.
- **One family, one scale.** Use `Style.font.family` (and `Style.font.menuFamily`
  for menus) with the `Style.font` scale: caption, bodySmall, body, title,
  heading. Hierarchy comes from size, weight and opacity (0.55–0.75 for
  secondary text), not from new faces.
- **Spend boldness in one place.** One memorable element per screen (in
  Powerbar Preferences: the user's real bar on their real wallpaper). Keep
  everything around it quiet.
- **Avoid template tells:** ALL-CAPS labels and eyebrows (one exception:
  section headers use Omarchy's own `PanelSectionHeader`, which is
  uppercase; see section 4), `A · B · C` meta strings, identical rounded cards with the same shadow everywhere, gradients
  as decoration, numbered markers on things that are not sequences.
- **Structure is information.** Borders, dividers and cards must encode
  grouping or state. Sections are a title plus an optional one-line
  description, not boxes around boxes.
- **Rounding nests.** An inner shape's radius is the outer radius minus the
  inset between them (highlight inside an island: `islandRounding - 3`).
- **Spacing from `Style.space()` and `Style.spacing.*`**, never raw pixels, so
  the theme's scale applies.
- **Centre forms, don't strand them.** Cap form width (about 760) and centre it;
  let wide editors (grids, lists) use the full width.
- **Settings pages are tiles laid out like tiled windows** (Powerbar's Bar page,
  October 2026): a 12/6/1-column grid by window width (≥1100 / ≥820), tiles
  twice Hyprland's `gaps_in` apart with the theme's `Style.cornerRadius`, fill
  `Qt.alpha(Color.popups.text, 0.035)` and a 0.1 border. Size encodes importance;
  a row's tiles share its tallest height; a dependent setting dims in place
  (0.45) inside its parent's tile. Each tile is titled with
  `PanelSectionHeader`. Aim for no scrolling at the largest card
  (1180 × 790); measure it, since one extra description line can tip it over.
- **Don't preview what the real thing already shows.** A drawn copy of the bar
  inside Preferences costs space and redraws while the live bar changes
  anyway; the user removed it on the first live look. Draw a picture only for
  what is not on screen (another edge, another style), and make one picture
  carry several settings rather than a thumbnail per option.
- **When an editor draws the bar's widgets, draw them exactly as the bar
  does** (Powerbar's Layout "On the bar" shelf, October 2026). Same slot
  model (`CellModel.place`, island end padding), same surface colour,
  rounding and border, same font, glyph size and text colour, images at 1:1.
  Never scale to fit: wrap a zone onto another island instead. The user
  rejected a shrunken copy ("keep scale, rounding and theme exactly as the
  real bar"). Elsewhere in an editor (lists of hidden or on-demand widgets)
  icon plus name is fine.
- **Never guess colours from the wallpaper.** Windows and busy wallpapers pass
  behind see-through surfaces; offer an explicit choice (Theme / Light / Dark)
  instead of a luminance or opacity heuristic. **Scope that choice to the
  theme it was made in** (`{ "<theme name>": "dark" }`): a Dark picked in a
  light theme is the background colour of a dark one and blanks the bar.
  Every other theme uses its own colours. Test colour settings by switching
  between a light and a dark theme.
- **Defer to Omarchy's own bar** for anything you have not deliberately
  replaced: bar thickness and gaps come from the theme, a widget's vertical
  layout is the widget's job. Explain where a difference comes from before
  proposing an override.
- **Small handles drawn over a wallpaper** (clickable edges, markers) get an
  outline in the surface's background colour so they read on light and dark
  wallpapers, and stay short enough to keep clear of neighbouring shapes.
- **Symmetry is a rule you state and build, not a look the mock happens to
  have** (Powerbar's Groups page, October 2026: "make sure the real layout is
  symmetrical and properly spaced, as the web version is a bit skewed").
  Tiles side by side are equal halves (6 + 6) that mirror each other: each
  puts its one control in the tile header (`PrefsTile.headerSlot`: a choice on
  one, a filter field on the other), then a well of the same height (the
  exact drawing sets it, the list beside it scrolls inside), then a one-line
  footer at the same height. A settings grid has equal columns computed from
  its container and fixed row heights (the bar's thickness when a bar
  drawing sits in a row), every control centred in its cell, filled column
  by column so a one-column window reads in the same order. Check right
  edges line up across rows, not just left edges.

## 3. Words

- Name things as users think of them: "On the bar", "In the drawer", "Hidden",
  not "shown / managed / hidden" or config keys.
- Sentence case everywhere. Active voice. A control says what happens:
  "Dissolve AI", "Restore default timing".
- One job per string. Descriptions are a single short line.
- Empty states invite the next action ("Press n to make your first group.").
- Errors say what failed and how to fix it, without apology
  ("Could not save. Check that shell.json is writable.").
- Destructive actions confirm by asking twice in place (press again within a
  few seconds), not with a modal.
- Status that is normally true stays quiet ("Changes apply as you make them").

## 4. Omarchy kit and keyboard model

Use `qs.Ui` components before building your own; they already carry theme
states and keyboard handling:

| Need | Component | Notes |
| --- | --- | --- |
| Button | `Button` | `focusable: true`, `bordered`, `foreground: Color.popups.text` in popups |
| On/off row | `Toggle` (row) / `ToggleSwitch` | Space/Enter/click emit `clicked()`; parent flips state |
| Pick one of N | `ButtonGroup` | One Tab stop; h/l or arrows walk chips; Space/Enter choose |
| Dropdown | `Dropdown`, `SearchableDropdown` | Enter/Space/Down open; j/k inside |
| Text | `TextField` | Kit focus styling; blocks navigation keys while editing |
| Slider | `PanelSlider` look | Powerbar's `PrefsSlider`: a focusable row, h/l (Shift ×5), Home/End, Backspace = default, Enter applies, Esc undoes; keeps a draft and writes the config once it settles (`SliderModel`: 450 ms quiet, 1 s max, 120 ms after release). Ranges stop where more stops looking different |
| Section label | `PanelSectionHeader` | Omarchy's panel headers ("OUTPUT", "KNOWN NETWORKS"): pass `text: title.toUpperCase()`, keep `Accessible.name` in sentence case |
| Compact rows in a tile | `PrefsToggle`/`PrefsSlider`/`PrefsChoice` `compact: true` | One line, no surface until hover or focus, radius = outer radius − inset |
| Keyboard panels | `PanelKeyCatcher`, `KeyboardPanel` | h/j/k/l, Enter, Space, x, Esc semantics |

**Keyboard rules (every screen, no exceptions):**

- Every action is reachable without a pointer. Tab/Shift+Tab move between
  controls or sections; j/k (and Up/Down) move within forms; h/l (and
  Left/Right) adjust or move sideways; Space/Enter activate; `x` removes
  (twice for destructive); Esc cancels the innermost thing first (a lift, an
  open dropdown, an edit), then closes.
- Pages switch with `1`–`N` and Ctrl+`1`–`N` (Ctrl works while typing),
  Ctrl+Tab cycles.
- A composite control (list, grid, chip group) is **one** Tab stop with its
  own cursor. It consumes j/k inside and hands them on at its edges, so j/k
  still walks the page.
- Let unhandled keys bubble: page-level handlers see only what the focused
  control did not accept. Text fields accept printable keys, so typing never
  navigates.
- **Focus is always visible.** Theme focus styling can be faint; draw one
  accent ring that follows `Window.activeFocusItem` across the card. Controls
  that draw their own cursor opt out with `readonly property bool
  ownsFocusRing: true`.
- **A footer shows the keys for whatever has focus**, as keycaps plus a verb,
  and changes as focus moves.
- Keep the focused control in view: scroll forms to reveal it.
- New item created from the keyboard? Put focus in its name field, text
  selected.

## 5. Direct manipulation, drag and drop

- **One state machine for keyboard and pointer:** cursor → lift → preview →
  drop or cancel. Space or a drag past a small threshold lifts; movement
  previews the landing place in the real layout (a placeholder in the gap);
  Space, Enter or release drops; Esc or release outside a target restores.
- **Preview, then commit.** Show the gap and the neighbours moving before
  writing config. If committing rebuilds the scene, glide the ghost into the
  predicted gap first and commit when it lands, so rebuild cost is invisible;
  finish with a short correction glide if the final slot differs.
- **Never lose a drop.** If a new press or a destroyed item interrupts the
  glide, commit the pending drop immediately.
- **Put the pointer handler above rebuilt tiles** (one overlay `MouseArea`
  with `preventStealing`), so a drag survives the model changing under it.
  Hit-test tiles by mapping points, not by per-tile handlers.
- **Gaps between wrapped tiles:** the landing index is the first real tile the
  pointer has not passed, reading rows top to bottom; ignore the placeholder
  when hit-testing, or the preview oscillates.
- **Containers open, they do not swallow.** Items like group icons make way
  like any other; resting a drag on one for about 400 ms springs its drawer
  open. Keep it open along the path to it and close after a short grace
  (about 450 ms) once the pointer truly leaves. When the source itself lives in
  a drawer that cannot stay open, fall back to drop-into.
- **Show the destination's form while hovering it:** a dragged widget over a
  named menu previews as that menu's row (name, or icon plus name).
- **Be forgiving at edges:** a target that is about to receive grows a small
  lip at its ends; a release that drifts slightly off the bar still lands.
- Keyboard moves cross zone boundaries at the ends of a row and change rows
  with j/k; pure movement logic belongs in a JS model with node tests.

**Drag invariants (learned shipping Powerbar's drag and drop):**

- **The preview is the contract.** Release commits the drop the preview
  shows; never hit-test again at release (the open gap has already shifted
  the layout under a still pointer).
- **Nothing moves after the drop.** The gap and the item that replaces it are
  the same size at the same spot: swap them in one frame (switch the size
  Behaviors off for that frame). Keep any size the transition needs (the
  dragged item's landing size) until the settle ends.
- **One drag behaviour on every surface.** Bar zones, drawers, icon groups
  and menus share the same resolver, preview model, outlined landing spot
  (one `DropOutline`), glide-then-commit and one-frame swap. A surface that
  does any of these its own way will drift.
- **A drop surface stays under the pointer.** Dropping into a drawer leaves
  it open (it closes on the exit grace once the pointer leaves), and a
  pointer drag ends the surface's keyboard mode, so the next click elsewhere
  focuses that window instead of being spent dismissing a grab.
- **The gesture's handler outlives the gesture.** If the dragged item lives
  in a list that can rebuild (a JS-array `Repeater`, a closing drawer), hold
  the source row for the drag, set the hold before anything can close it, and
  cancel the drag from the row's `onDestruction` so the bar can never freeze.
- **Whole rows take the pointer.** A row's drag and click go on an overlay
  above its content; a parent's `DragHandler` never sees a press a child
  `MouseArea` accepted.
- **Run boundaries are unambiguous.** Where two runs meet (shown | on demand),
  the gap belongs to one of them whichever neighbour is nearer; containers
  that cannot hold the dragged thing (a group in a group) show no gap at all.
- **A marker that stands for hidden widgets answers the pointer.** Resting on
  a yield marker ends the hover moment that hid its widgets (Powerbar, October
  2026: the user expected the centre's reveal to give way at once). Read the
  window's pointer for it; the widgets it stands for still take hover.
- **Things that open during a drag follow the drag** (Powerbar inline dots,
  October 2026). A zone expanded by resting on its dots holds only while the
  drag stays in that zone; reaching another zone collapses it at once, so it
  never leaves a neighbour's dots yielded or hidden. Read the drop again once
  an expansion settles under a still pointer. Out-of-view items (yielded, in a
  hidden zone) take no drops.
- **A target that a gap pushes keeps the drop where it took it.** A gap
  opening just before the dots moves them; dropping on them closes it again.
  Keep the drop on them while the pointer stays inside the rectangle they had
  when they took it, or a trembling hand flips between the two.
- **Offsets follow their axis.** A correction measured along the bar (ink
  centre) applies only to surfaces along the bar, not to a vertical menu
  under a horizontal one.

## 6. Motion and microinteractions

Decide in this order (Emil Kowalski's framework, in QML terms).

**1. Should it animate at all?**

| How often it is seen | Decision |
| --- | --- |
| Hundreds of times a day (keyboard shortcuts, palette toggles) | No animation |
| Tens of times a day (hover, list or focus movement) | Remove, or keep under about 120 ms |
| Occasionally (drawers, panels, drops, peeks) | Standard animation |
| Rarely (first run, confirmations) | Room for delight |

Keyboard-initiated high-frequency actions stay instant. Every animation must
answer "why": spatial continuity, state change, feedback, or preventing a
jarring jump. "It looks nice" is not enough for something seen often.

**2. Easing.** Entering or exiting: strong ease-out. Moving on screen: ease-in-out.
Colour and hover: plain ease. Never ease-in for UI; it delays the moment the
user watches. In QML prefer `Easing.OutCubic`/`OutQuint`, or a custom curve:

```qml
easing.type: Easing.BezierSpline
easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]      // strong ease-out
// on-screen movement: [0.77, 0, 0.175, 1, 1, 1]; drawers: [0.32, 0.72, 0, 1, 1, 1]
```

**3. Duration.**

| Element | Duration |
| --- | --- |
| Press feedback, hover fill | 90–160 ms |
| Tooltips, small popovers, focus ring glide | 110–200 ms |
| Dropdowns, chips, gaps opening | 150–250 ms |
| Drawers, panels, bar slide-in | 180–300 ms |

Stay under 300 ms for UI. Exit faster than enter.

**4. Physicality.**

- Never grow from `scale: 0`; enter from `scale: 0.95–0.98` with opacity 0.
- Anchored popovers scale from their trigger (`transformOrigin`); centred
  modals and the preferences card scale from the centre.
- Pressable things may dip to `scale: 0.97` while pressed (`Behavior on scale`,
  about 120 ms).
- After the first tooltip in a row, the next ones appear instantly.
- Use `Behavior`s for state-driven motion: they retarget mid-flight like CSS
  transitions. Use explicit `NumberAnimation`s for one-shot sequences, and
  springs (`SpringAnimation`, `SmoothedAnimation`) for things that follow the
  pointer or can be reversed mid-gesture. Keep bounce or overshoot subtle
  (0.1–0.3) and off in most UI.
- Stagger groups of entering items by 30–80 ms at most, and never block input
  while they play.
- When a crossfade shows two states at once, shorten it or blur briefly
  (`MultiEffect` blur, small radius) rather than lengthening it.

**5. Consistency and restraint in the bar.**

- One highlight language everywhere: a soft rounded fill behind the item in the
  bar's foreground (hover fill for hover or activity, selected fill for an open
  panel), nested inside island corners. No underlines in one place and fills
  in another.
- Activity that surfaces a hidden bar peeks briefly (about 2.5 s, extended by
  more activity), highlights the widget that changed, and ignores clock-driven
  widgets and the settling burst just after a rebuild. Measure real event
  rates before choosing thresholds.

**6. Reduced motion and performance.**

- Respect the user's animation switch (`animationsEnabled`): drop movement,
  keep short opacity and colour changes that aid comprehension.
- Prefer animating `x`, `y`, `scale`, `opacity` (Animator types where
  possible). Animate width or height only where layout must genuinely make
  room (gaps, islands) and keep those subtrees light.
- Per-frame following (`FrameAnimation`) only while visible.

## 7. Showing the real thing

- **Previews use the user's actual bar:** live widget images
  (`grabToImage`), their wallpaper as the backdrop, the real surface colour,
  rounding, border and shadow tokens. A preview that shows the truth is the
  best explanation of a setting.
- **Cache what you capture** (`~/.cache/<plugin>/…`) so things that are not
  loaded, such as hidden widgets, still show their last look; fall back to a
  glyph plus name only when nothing was ever seen.
- **Keep previews orientation-independent:** always draw them horizontally at
  the bar's size. Capture only from a horizontal bar and map side edges to top
  or bottom. Judge a saved image by recorded facts, not its shape: an icon on
  a large bar is 27 × 38, taller than wide, and a shape rule threw every one
  away.
- **Record what a capture is** beside it (Powerbar's `faces.json`): its size,
  where its ink starts and how long it is, whether it reads as a glyph, and
  the text colour it was drawn in. An image from another theme no longer
  matches the bar; redraw it in the current colour until it can be
  recaptured: fill its shape with exactly that colour (a colour fill masked
  by the image's alpha, Powerbar's `TintedImage`). **Not** MultiEffect
  brightness 1 then colorization: colorization keeps lightness, so the
  silhouette stays white and vanishes on a light bar. For the mask,
  `maskThresholdMin: 0.5` with `maskSpreadAtMin: 1` keeps soft edges; 0 and 1
  show the whole rectangle, the defaults cut jagged edges.
- **A side bar never captures, so keep an orientation-free fallback:** the
  glyph the widget draws itself. Nearly every widget draws the kit's
  `WidgetButton`/`BarIconButton`, whose `text` is its glyph (first private-use
  character, or a short label such as "EN"). Read it when the widget loads,
  keep it on disk for hidden widgets, drop it when the widget stops drawing
  one, and skip it for compounds (several visible buttons, like workspaces),
  which keep their image. Manifests carry no icon.
- **Scale is real pixels:** on HiDPI, `grabToImage` output is multiplied by the
  device pixel ratio; divide by `targetSize factor × Screen.devicePixelRatio`
  when reading saved images.

### Icon pickers (Powerbar's group icon, October 2026)

- **Offer what Omarchy itself uses, not the whole font.** The user rejected
  the full Nerd Font ("I don't want 12 thousands of symbols"). Omarchy has no
  written icon guideline; its practice is the guide: the glyphs its own shell,
  menus and configs use (284, 58% Material Design), its own font (logo and AI
  tools, U+E900–E90D), and its emoji list with keywords
  (`shell/plugins/emojis/emojis.json`). Add the glyphs the user's widgets draw
  first. About 2,170 in all; generate the list from Omarchy's sources and
  regenerate after updates.
- **Names come from the font itself:** a Nerd Font's `post` table names every
  glyph (`md-folder`, `fa-volume_up`); a standard-library reader takes 45 ms.
  A glyph whose name is a standard Mac name (`pi`) has none there.
- **Store the font with the glyph.** U+E900 is the Omarchy logo in Omarchy's
  font and `dev-cobol` in the Nerd Font; a face that draws icon and name as
  one string in one font shows the wrong glyph. Draw mixed faces as runs.
- **Gap from the ink, not the box.** Icon glyphs overhang their advance boxes
  by different amounts (the speaker 6.6 px past a 7.2 px box, the Omarchy
  logo not at all), so "icon + two spaces + name" in one string gives 8 px
  here and 14 px there. Draw icon-and-name faces as runs with the name one
  space after the icon's ink end.
- **One glyph, several sources: keep the first entry, merge the words.** The
  Omarchy logo drawn by a widget on the bar must still answer "omarchy logo".
- **Search like Omarchy's emoji picker:** focus stays in the field, typing
  searches, arrows walk the grid across section headers (by visual row,
  keeping the column), Enter chooses, Tab changes source, Esc clears then
  closes. Every query word must start a word of the name; hyphens,
  underscores and spaces are the same. A single pasted glyph or emoji is
  offered as itself. Only rows in view exist (a ListView of rows).
- **The user's own icon:** drop, Ctrl+V (`wl-paste --list-types`, as
  Omarchy's clipboard plugin does) or a typed path; copy it into the plugin's
  data folder; colour is an explicit choice. Tinting with MultiEffect fills
  the image's shape, so a multicolour icon becomes its silhouette; say so.

## 8. QML correctness (the rules that bite)

- Items inside `RowLayout`/`ColumnLayout`/`GridLayout` size with `Layout.*`
  only; never mix `anchors` and `Layout.*` on one item; `Row`/`Column`
  children cannot use `anchors.fill` or `centerIn`.
- Avoid binding loops. An `Image` with `PreserveAspectFit` changes its implicit
  size with its width; read `sourceSize` for the natural size. Some properties
  are read-only (`Image.implicitWidth`).
- `required property` in delegates; reach outer objects by `id`, not by
  implicit scope.
- Cache expensive expressions in `readonly property`; no heavy function calls
  in bindings that update per frame.
- `Loader { active: false }` for anything not shown; guard `Loader.item`.
- `clip` and subtree `opacity` cost offscreen passes; use them where needed,
  not by default.
- Every custom interactive item gets `Accessible.role`, `Accessible.name`,
  `activeFocusOnTab`; decorative items get `Accessible.ignored: true`.
- Put pure logic (movement, hit rules, config transforms) in `.js` models with
  node tests; keep QML declarative.
- **Qt 6 hovers disabled items** (for tooltips); a `MouseArea` keeps its own
  `enabled` when its parent is disabled. Make inert things deaf with
  `hoverEnabled: false` or the handler's `enabled`, and guard the handlers.
- **No hover while a button is held**; it resumes a frame after release.
- **Hover stops at the first item that takes it, and siblings below never see
  it.** A hover-enabled `MouseArea` takes hover; a `HoverHandler` placed
  inside an overlay `MouseArea` that sits above widgets made that overlay take
  it too, and every widget under it lost hover and its tooltip (Powerbar,
  October 2026). Put a region's hover on a common ancestor of what it covers,
  or test the window's own `HoverHandler.point` against the region's rect;
  never add a handler to an overlay just to learn the pointer is there.
- **A widget off the bar still takes the pointer.** A yielded, folded or
  waiting widget keeps its full box where the bar last put it, transparent and
  disabled, and Qt hovers it anyway: it steals hover (and opens its own
  tooltip) over whatever now sits there. Park it far off-screen once faded
  out; don't hide it, since some widgets size themselves from `visible`.
- **Never let hover change the layout under the pointer.** A hover on A that
  closes B's expansion slides A out from under the pointer and slides other
  widgets in. A hover may block a change from starting; it must not undo one
  in place.
- **Positioners skip zero-size items**, which keep a stale `x`; content
  larger than a collapsed slot still sits there at full size. Never hit-test
  across all targets; scope it to the item that was pressed.
- **A `Repeater` over QObjects is slow** (every property becomes a role,
  about 2 ms each): use identity tokens as the model and look objects up.
  A JS-array model rebuilds every delegate on any change.
- **`signal.connect(fn)` is not undone when the receiver dies**; disconnect in
  `Component.onDestruction`. A `var` binding returning the same object emits
  nothing.
- **A second `onXChanged:` for the same property fails the whole file**
  ("set multiple times"): merge handlers or use a `Connections` block.
- **Tab never reaches a parent's `Keys` handler**: a focused item with
  `activeFocusOnTab` steps the focus chain itself first. To make Tab jump
  between groups, use a `Shortcut { sequences: ["Tab"] }` whose `enabled` is
  "focus is inside this container".
- **A nested layout won't grow past its implicit width** unless one of its
  children has `Layout.fillWidth`; `Layout.fillWidth` on the layout alone
  does nothing.
- **Override a kit component's own bindings** (Toggle's 54 px minimum height,
  its colour) from a derived type with `Binding { target: root; property: …;
  when: … }`; the base's ids are out of scope.
- **`Window.window.visible` doesn't see a layer-shell window hidden for a
  remap**, but every item in it reads as invisible meanwhile. Code that
  measures items must pause on the owner's own remap flag, set before it
  hides.
- **`ClippingRectangle` renders nothing with `QT_QUICK_BACKEND=software`**:
  take offscreen screenshots of wallpaper previews with the `rhi` backend.
- **Qt's engine splits `Array.from(string)` by UTF-16 unit**, cutting
  Material glyphs (U+F0000 and up) in half while node tests pass. Walk
  surrogate pairs by hand and test string rules in `qmltestrunner` as well.
- **An id beats a property of the same name** in QML scope; name properties
  so they cannot collide with ids in the component.
- **Do not mutate a shared `TextMetrics`/`FontMetrics` inside a binding** to
  measure text: it loops. Make one `FontMetrics` per font once and call
  `tightBoundingRect(text)`.
- **A child's `Component.onDestruction` can run after its parent's
  properties are gone.** Records that point at an object (a slot) are removed
  in that object's own `onDestruction`, and cleanup code skips an owner whose
  properties read undefined; otherwise the throw stops the cleanup halfway
  and dead entries pile up.
- **Never bind an image's `source` (or its size) to `visible`.** `visible`
  is effective visibility: it turns false whenever an ancestor hides, such
  as a Preferences page in a StackLayout. `source: visible ? url : ""`
  unloaded every widget image on a page switch, and they came back blank
  (Layout's bar shelf after Layout → Bar → Layout). Bind to the data
  (`kind === "image"`). Likewise keep a `grabToImage` result alive as long as
  anything may load its `itemgrabber:` url.
- **A layout's size comes from its children's:** its maximum width is the sum
  of theirs. Cells whose width is computed from the grid's own `width` loop
  and settle wherever they started (776 px in a 1,124 px tile). Compute
  column widths from the container (`tile.width − insets`), then pin each
  cell's preferred, minimum and maximum width to it.
- **`Layout.*` only acts inside a layout.** Compact controls carry their
  own `Layout.leftMargin`; wrapped in a plain `Item` they lose it and their
  labels stop lining up with the tile title. Make wrappers layouts.
- **A slot for a control in another component's chrome:** expose an empty
  `Item` as a readonly alias (`headerSlot`) and reparent the control into it
  with `parent: tile.headerSlot`.
- **A glyph's square cell must still fit its ink.** "Glyph" is judged across
  the bar; a narrow stack long along a side bar needs a cell as long as its
  ink. Check geometry rules against every slot, edge, spacing mode and bar
  size, not the one widget that showed it.

## 9. Verify on the real desktop

- Syntax: `/usr/lib/qt6/bin/qmlformat --normalize File.qml >/dev/null`.
- Tests: `node tests/*.test.cjs` each; QML:
  `QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_QUICK_CONTROLS_STYLE=Basic QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests/qml -o -,txt`.
  Re-run once before blaming yourself for a timing test; flaky ones exist.
- Reload with `omarchy-restart-shell`; read warnings with
  `quickshell log -p /usr/share/omarchy/shell | grep <plugin>`. A load error
  makes the shell fall back to the stock bar: fix immediately.
- Open screens through IPC (for example
  `qs ipc -p /usr/share/omarchy/shell call powerbar preferencesPage 2`) and
  screenshot with `grim` (whole screen or `-g "x,y wxh"`), then look.
- Test other configurations (bar style, edge, autohide) by backing up
  `~/.config/omarchy/shell.json`, editing a copy, and restoring it byte for
  byte (`cmp`). Turn autohide off for captures or the bar will be hidden.
- Do not send synthetic keys or move the pointer while the user is active; if
  the config changes in ways your test could not cause, assume the user did
  it and leave it alone.
- Probe event-driven behaviour with a temporary `console.info` tag, measure
  over a real minute, then remove the probe.
- **Load offscreen before every live restart** (a broken file makes the shell
  fall back to the stock bar), then confirm the plugin's IPC target exists.
- **Prove the change is live by looking at it, not at a process.** Other
  Quickshell instances can run beside Omarchy's (another session's plugin
  preview shell); a pid taken from the first or newest `qs list` entry was
  the wrong process, so "the pid didn't change" and "it restarted" were both
  unreliable, and the user once saw an early draft ("the layout is
  completely botched") after a reported restart. Find the shell by its
  config path (`live.sh pid` does now), then open the page by IPC and
  screenshot the exact thing you changed before handing over.
- **Check the shape, not one pixel.** A centre sample proved a tint's colour
  while the image had become a solid square. Compare the whole crop with
  the expected silhouette.
- **Test it live yourself when the user allows it:** `wtype` drives
  Preferences (it takes exclusive keyboard focus); `wl-copy` feeds paste
  paths (`--type image/png`, `--type text/uri-list` for a copied file).
  Synthetic pointer drags aren't possible without ydotool/uinput, so a file
  manager drop stays for the user. Before each step check which group or
  item is selected (a restart resets the selection to the first one: test
  keys edited the user's AI group). Use throwaway items, back up
  `shell.json` and the clipboard (save every type, images included), and
  restore semantically: the user may install things meanwhile, so revert
  only the fields you changed, then compare.
- **Config that points at something gone is healed by the plugin, not the
  user.** The user asked for it ("let Powerbar take care of missing widgets
  itself"): drop dangling references whenever the config is read, write the
  cleaned config once, and never add UI for removing them. Guard the
  cleanup against a config still loading (no keys to check against), back
  up `shell.json` before the first live run and diff the result.
- **For anything that moves wrong for a moment** (wobble, slide, jump,
  flicker) or input that goes to the wrong place, use the
  `omarchy-widget-debug` skill: record frames offscreen, analyse them, and
  A/B against the last commit before claiming a fix.
- Expensive host reactions (Omarchy re-registers every bar widget on a
  config write, about 370 ms, twice) belong after the interaction: apply edits
  locally at once and write the config once things settle.

## 10. Review checklist

Report UI and motion findings as one table:

| Before | After | Why |
| --- | --- | --- |
| Hard-coded hex colour | `Color.*` / `Style.*` token | Themes change daily |
| ALL-CAPS section label | Sentence-case title | Template tell; harder to read |
| Control unreachable by keyboard | Focusable, in the key map, in the footer | Keyboard-first is non-negotiable |
| Faint theme focus only | Accent focus ring following focus | The user must always see where they are |
| Composite control with many Tab stops | One Tab stop with its own cursor | Tab walks sections, arrows walk items |
| Stand-in glyphs in a preview | Live or cached real rendering | Show the real thing |
| Commit on every drag move | Preview gap, commit on drop | Fast, cancellable, no rebuild stutter |
| Drop target swallows items | Container makes way, springs open on rest | Placement and membership both stay possible |
| `Easing.InQuad` on UI | Strong ease-out or custom Bézier | Ease-in feels sluggish |
| 400 ms UI transition | 150–250 ms, exit faster | Speed is perceived quality |
| Animation on a keyboard action | Instant | Seen hundreds of times a day |
| Entry from `scale: 0` | `scale: 0.96` + `opacity: 0` | Nothing appears from nothing |
| Two highlight styles | One rounded fill language | Consistency reads as quality |
| The bar redrawn smaller inside an editor | The bar's own slot model, surface and font at 1:1, wrapping | It must look like the bar |
| A Light/Dark choice shared by every theme | One choice per theme | A light theme's dark is a dark theme's background |
| Saved images judged by shape | Recorded size, ink and colour | Icons on a large bar are taller than wide |
| Image implicit size in a width binding | `sourceSize` | Avoids binding loops |
| Drop target recomputed at release | Commit the shown preview | The layout under the pointer has moved |
| Gap and new item animated separately | One-frame swap | Nothing moves after a drop |
| Drawer closes after a drop into it | Stays under the pointer | The user is still there |
| Drag handler on a row's label only | Overlay on the whole row | Child MouseAreas swallow presses |
| Hit test over every target on the bar | Scoped to the pressed item | Hidden content steals clicks |
| `Repeater` over QObjects | Identity-token model | Milliseconds per object per rebuild |
| Grid cells sized from the grid's own width | Widths from the container, pinned | A layout's size is its children's; it loops |
| Side-by-side tiles with different chrome | Mirrored halves: header control, well, footer | Symmetry must be built, the mock skews |
| Every glyph in the icon font | What Omarchy uses, plus your bar's, plus emoji | Thousands of symbols is noise |
| Glyph saved without its font | Glyph and font together | One code point, two fonts, two icons |
| "Missing" rows the user must remove | Dropped on read, cleaned in one write | Uninstalls are the plugin's job |
| `source: visible ? url : ""` | Source bound to the data | Hidden pages unload images that may not come back |
| "Restarted" without checking | New pid, start time after the edit, a screenshot | The user may see an old build |

## Sources

Adapted, not copied, from: Anthropic *frontend-design* (Apache 2.0), the Qt
Company *qt-qml* agent skill (BSD-3-Clause / Qt commercial), Emil Kowalski's
*emil-design-eng* and *review-animations* skills (MIT, © 2026 Emil
Kowalski), and Omarchy's `qs.Ui` component kit and panel conventions.
