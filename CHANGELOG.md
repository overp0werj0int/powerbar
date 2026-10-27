# Changelog

## Unreleased

- On the Layout page, the cursor on a hidden widget (or a tray icon) no longer lights its zone's column on the layers above, inspected or not; k out of the slab still lands in the widget's zone (PREFS-99).
- The key legend at the bottom left of the Layout, Groups, Look and Behavior pages is written in the same size as the captions under the strip titles (PREFS-103).
- **The Bar page becomes two desks, Look and Behavior.** Preferences now have four pages (1 Layout, 2 Groups, 3 Look, 4 Behavior; `preferencesPage 3` and `4`, above 4 Behavior). Each is one of the Layout page's tilted plates under the same camera, its strips side by side, the camera's shade falling on those under it, and no bar preview: the real bar shows every change. Look holds Style (the styles as pick rows and the Screen edge as a row of chips), Size, Shape, Surface, Shadow and, on a notched screen, Notch; its numbers are faders lying flat at the strips' bottoms, name at the left and value at the right (h/l, Shift for five, Home/End, Backspace back to the theme's value, Enter, Esc, a drag or the wheel when focused). Behavior holds Comes and goes, On demand and Keyboard as rows with a caption each. On both pages j/k move the cursor and h/l move a value: j/k down a strip and on, h/l a fader's value, chip to chip on a row of chips, else the same row of the next strip; Tab to the next strip; the keys are a legend at the bottom left. The first start's notification and `preferencesKeyboard` open Behavior at the Bar keyboard row; Hyprland's gaps are no longer read and the placement graphic and the Notch Reset button are gone (PREFS-124 to PREFS-131).
- **The Groups page is a stack of the Layout page's plates.** The same camera, from the same place and with the same arguments, over three tilted plates drawn by the same parts as the Layout page: "Groups", the bar layer's plate with each zone's tile holding its groups' faces as rows where the bar puts them (on the bar tinted, on demand with a ring, hidden dashed; always named), room for four with more scrolling inside the tile, and a "+" row under them; "In the group", each zone's tile its one drawer showing the open group (the faces are its tabs), a dashed leader down to it from the open face's dot; and "Not in a group", the widgets in no group as one slab in bar order, with its filter. The Center dot beside the camera works as on the Layout page. h/l go to the same row in the next zone, j/k down a zone and on to the next plate; a widget is picked up with Space or a drag and dropped in a drawer, on a face (a drag resting on a face opens its drawer), on the slab or on a "+" (a new group there, with it as the first member); a face moves zone with Space then h/l, Shift+h/l or a drag, and layer with Shift+j/k. The chosen group's inspector sits at the bottom right with its name, how it shows, its layer, zone, icon and shortcut, and the badge sources of the widget under the cursor; the keys are a legend beside it (PREFS-109 to PREFS-123).
- The camera on the Layout, Groups, Look and Behavior pages no longer pours a beam through the plates: its black cap ends in a torn paper edge a little above them, with the paper's lighter core showing along the tear and a soft shade falling a short way under it, over the gaps and the Center tiles alike (one fragment shader, the cap's sides where they were; PREFS-24). With `"powerbarTuning": true` on the bar in shell.json (no Preferences switch, like the frame log) Preferences gain a fifth page, Tuning, its tab at the header's right: the numbers behind the look as faders under the camera (the cap's tear, fringe and shade), moved live and kept in `~/.cache/powerbar/tuning.json` while the page is there, plus the frame log switch; off, the shipped defaults draw (PREFS-132, INTEG-155). The Center leader is one accent dash all along (PREFS-105), and the inspector's leader points at the window's edge when its chip is scrolled out of view (PREFS-101), and an empty zone tile under the cursor no longer draws an outline: its name reads bold; the slabs keep theirs (PREFS-27).
- A raised zone tile takes its edge with it, so every tile's edge reads the same (PREFS-104); the Preferences focus ring is a hairline with 5 px of room, in the theme's shape (PREFS-108); the inspector's zone map is square on a square theme (PREFS-26).
- In the Layout page's inspector, Tab and Shift+Tab walk its controls (Layer, Zone, Shortcut, Peeks on activity, Group) and wrap round inside it instead of leaving it, and the legend names each control's own keys; the Group dropdown opens above itself, in view, instead of below the window's edge; the Layer list's own j/k line is gone, the legend shows it (PREFS-26, PREFS-101).
- The Layout page's Hidden layer is one slab in bar order instead of five near-empty zones: a hidden widget keeps its zone, which the inspector shows and Shift with h or l changes; h and l walk along the slab (and the tray's), j and k go by rows, x on a hidden widget brings it back (PREFS-107).
- **The Layout page is an exploded view of the bar.** Preferences now fill
  the screen under the bar. On the bar, On demand, Hidden and the tray are
  plates tilted back in perspective, each with its name, its five zones (Hidden
  and the tray as one slab each) as
  tiles of one width mirrored about the screen's middle (Center under the
  camera on a notched screen, its black cap torn a little above the
  layers on Center's own lines), and the widgets as small chips.
  Enter or a click pulls a chip forward on a dashed leader to an inspector
  at the front, where its layer (j/k), zone, shortcut, activity peek and
  group are set; Esc pushes it back. The keys are a legend at the bottom
  left, beside the inspector, in small text. Resting the pointer on a chip shows its full
  name and id. h and l change zone; j and k walk a zone and carry on into
  the next layer, with or without a chip picked up; Shift with h or l
  moves the chip to the next zone at once, Shift with j or k to the same
  zone on the next layer at once. The cursor's chip and its tile rise a little off
  the layer. A layer that gains or loses a chip only grows or shrinks
  downward: its top edge and what sits near it stay put. The layers share
  the page between the header and the legend, so the legend and the
  inspector never move: a layer gets the height it needs while the layers
  fit, else each starts at its name and one row and the rest is shared out
  fairly; a zone with more rows than its layer has then scrolls inside its
  tile, with a hairline thumb and faded edges, by wheel, keys or a drag held at
  its edge. With animations off the layers lie flat.
- **Center can sit left of the camera.** On a notched screen the Center
  zone's widgets sit beside the camera, on the right until now. A dot beside
  the camera on the Layout page (or `powerbar set centerSide left`) moves
  them to the left; they come next to the camera on either side.
- **A zone's dots are a small circle.** With five zones a bar could carry
  five sets of three dots; each zone now marks its waiting widgets with
  one small, quiet empty circle, on horizontal and vertical bars alike,
  and the drawer mode's zone button shows it too.
  It takes the same space and opens the same menu or drawer.
- **The Left of center menu opens on hover.** Resting on its circle no
  longer reveals the indicators, which slid the circle away and the clock
  under the pointer, so the menu closed at once and a click opened the
  clock instead.
- **Menus show Crash Desk's and Omapop's icons.** A widget whose text is an
  icon and a count (Crash Desk) shows the icon in the menu's icon cell and
  the count at the row's end; Omapop's drawn mark counts as an icon.
- **On demand in a menu.** Preferences > Bar > On demand > Show them has a
  third choice, In a menu: each zone's dots open a menu of its On demand
  widgets with their icons and names, walked with the pointer or the keys.
  An On demand group is a row that opens its widgets in a submenu. On the
  notch the menu slides out under the ear's dots (`powerbarOnDemand: "menu"`).
  A widget whose icon is a picture (Reprieve's mark) shows it in the icon
  cell, as group menus now do too.
- **A floating bar wraps the notch.** On a MacBook's notched screen the
  floating bar dips round the camera, the same gap off it as off the
  screen's edges, with its border and shadow following the cutout. Its top
  corners follow the screen's rounded corners, as the outer islands' do in
  the Islands style. A small bar grows there to keep a band under the
  camera. A bar on the left or right edge rounds its top corner on the
  screen's edge the same way.
- **Five zones.** The bar's zones are Omarchy's sections: Left, Left of
  center, Center, Right of center and Right. Center sits over the middle of
  the bar, or first right of the camera on a notched screen. Preferences >
  Layout shows the five as columns sized like the bar, with the camera
  between Left of center and Center; it turns for a side bar, and picks the
  screen to picture when one has a camera and another not. A widget's Zone
  is a small map of the bar.
- **Notch is a style.** Preferences > Bar > Style offers Notch on a MacBook:
  black ears on the notched screen's top edge, islands elsewhere. The bar
  can now move to another edge in it.
- **Zone modes are gone.** Three zones, Two zones, "Pinned to screen center"
  and "Keep at screen center" make way for the five zones. Your layout is
  read into them once: the pinned widget becomes Center, what was before it
  Left of center, what was after it Right of center; a notch layout's zones
  become Left and Right of center. The arrangements each mode kept are
  copied to `~/.cache/powerbar/zone-layouts-<date>.json` before they leave
  `shell.json`. `set zones` and `set centerAnchor` say what replaced them;
  `setWidget` takes `centerBegin` and `centerEnd` zones and drops `centered`.
- **Older Omarchy.** Where Omarchy's bar has only left, center and right,
  Powerbar writes those three, Center holding one widget (the one Omarchy's
  bar centres), and keeps the split beside them.
- **Omarchy's new bar sections.** Widgets Omarchy places in `centerBegin`,
  `centerEnd` or its tray drawer show on Powerbar again. Omarchy puts every
  newly installed widget in `centerEnd`, so these used to vanish. Powerbar
  saves the layout in Omarchy's shape, so the stock bar reads it the same way.
- **Notch height.** Preferences > Bar > Notch has a height slider next to
  the width (`omarchy-shell powerbar set notchHeight N`), defaulting to the
  detected height. The tile now shows on any machine with a notched screen.
- **Indicators under the keyboard.** The cursor on the indicators reveals
  them, and the keys along the bar walk their icons (and Workspaces') one
  by one before moving on; Enter presses the one under the cursor. Their
  highlight no longer lands on a folded icon beside the widget.
- **A flat bar fits the notch.** On a notched screen a flat top bar, large
  or small, is exactly as tall as the camera, so it ends level with it. Both
  draw the same there: the large bar's spacing, with highlights sized to the
  strip. Other screens keep the bar's own size.
- **Expansions stop at the notch.** An inline
  expansion that would run over the camera opens its drawer instead, as a
  second island under the bar, the way it does when the bar is full.
- **Activity peeks while the bar is off.** With the bar switched off
  (Super+Shift+Space), a widget that changes still comes out alone on its
  badge, as on an autohidden bar. Show on widget activity now applies with
  or without Autohide.
- **Tray icons on the bar.** Preferences > Layout has an In the tray shelf
  with the icons in Omarchy's tray. Drag one onto the bar, On demand, Hidden
  or into a group and it leaves the tray and works as a widget, with the
  tray's click, right-click menu and scroll. Drag it back and the tray shows
  it again. On Omarchy's own bar such an icon stays hidden in the tray, where
  its Manage list can bring it back. While its app is not running, drawers
  and menus leave it out, as the tray does.
- **Esc in the keyboard mode works beside Plume.** A widget's window-wide
  shortcut (Plume 1.0 binds Esc for its settings inside its bar widget) took
  Esc before the mode saw it; the mode now keeps its keys while it has them.
- **A group's icon closes its member's panel.** With a member's panel open
  from a group menu, clicking the group's icon closes the panel and brings
  the menu back, instead of the panel sliding to the screen's left edge. A
  drawer that closes any other way closes its member's panel with it. A
  click on a group icon whose menu the pointer had opened now keeps the menu
  open, as it does from rest.
- **A member's panel takes the mouse again.** A panel opened from a group
  menu or a drawer the click had opened (Audio's, say) worked only from the
  keys: the bar kept the keyboard for the drawer underneath, and Hyprland
  sent the pointer there too.
- **A click on a window closes a clicked menu.** A group's menu or a zone's
  On demand menu opened by a click held the keyboard so tightly that a click
  on another window went nowhere and the menu stayed. It now holds the keys
  as the keyboard mode does: the click closes the menu and reaches the
  window. A click right as the pointer reached the dots no longer opens the
  menu for hovering only.
- **The notch measured on Apple's artwork.** Every notched MacBook panel's
  camera and screen corners in `notch-panels.json` now come from Apple's
  product bezel images, which draw the screen pixel for pixel. The camera is
  a little wider at the top edge than macOS reports (191 instead of 185 at
  scale 2 on a 14" Pro: its shoulders flare out 3 px a side), with rounder
  bottom corners, and the 15" Air's is 6 px narrower than the guess it had.
  Each panel also lists the radius of the screen's top corners.
- **Reset the notch's size.** Preferences > Bar > Notch has a Reset button
  while the width or height is set by hand; it goes back to the measured
  size. Before, only Backspace on a slider could.

## 0.9.6 — 2026-10-17

Private folders for existing installs, from the marketplace review.

- **Folders an earlier version made are closed too.** On every start
  Powerbar makes its cache and icon folders 0700 and the files in them 0600,
  so an install from before 0.9.5 needs no `chmod` by hand.

## 0.9.5 — 2026-10-17

Private widget images, from the marketplace review.

- **Powerbar's folders are private.** The widget images Preferences keeps
  (they can show a window title or other private text), `faces.json` and
  `glyphs.json` are written in folders Powerbar now makes 0700, so no other
  user can open them; the icons you add to groups are 0600 in 0700 folders.
  Folders an earlier version made keep their mode; this closes them:
  `chmod -R go= ~/.cache/powerbar ~/.local/share/powerbar`.

## 0.9.4 — 2026-10-15

A new description.

- **One line says what Powerbar is:** "A replacement bar for Omarchy with
  drawers, in-bar expansion, notch support, configurable visibility, a
  sophisticated keyboard mode, autohide and a polished Preferences window."
  It is the plugin's description and the tagline in `preview.jpg`.
- **README:** the intro says the two shortcuts are offered in a notification
  on the first start, no longer bound.

## 0.9.3 — 2026-10-15

The marketplace preview, redrawn.

- **A 16:9 preview on the theme's own colours.** `preview.jpg` is now the
  marketplace card's shape and uses no wallpaper: Powerbar on nord, laid in
  as a screen on a gradient of nord's colours. The catalogue's card crops
  take only gradient.
- **README:** the install section says the shortcuts are offered, not bound,
  and the gallery credits Omarchy for its themes and wallpapers.

## 0.9.2 — 2026-10-15

Ready for the Omarchy plugin marketplace: Powerbar asks before it binds a
key, and a security pass.

- **Shortcuts are offered, not bound.** On its first start Powerbar no
  longer writes Super+B and Super+Ctrl+/ into `bindings.lua` by itself. A
  notification offers them (or names what already holds them) and stays
  until you dismiss it; click it and Preferences opens at Bar → Keyboard on
  the keyboard mode's shortcut, where Enter takes it. New command:
  `omarchy-shell powerbar preferencesKeyboard`.
- **Names are shown as written.** A group or widget name that holds markup
  is shown as plain text everywhere, never read as rich text (which could
  load an image from the network).
- **Group images are local files.** A group's own icon is an absolute path to
  an `.svg` or `.png`; a URL is refused by `setGroup` and dropped from the
  config. Imported and pasted icons are read once, capped at 512 KB, with a
  timeout.
- **Safer shortcut writes.** The block in `bindings.lua` is written through a
  fresh temporary file, so a link planted beside it can't redirect the write;
  an old `powerbar.lua` is removed only when Powerbar wrote it; names with
  control characters can't break the block.
- **Nothing writes while the bar goes away.** Switching to another bar (or
  the shell reloading) no longer logs "canWriteConfig is not a function", and
  no late change can reach `shell.json` or `bindings.lua` after Powerbar is
  replaced.
- **README and screenshots** checked against this version, with four new
  wide captures on stock themes. The Omarchy version badge is gone; Powerbar
  was tested on Omarchy 4.0.4 and the next version's development build.
- **For developers:** the agent skill and the offscreen bench now live
  outside the plugin; `SECURITY.md` says how to report a vulnerability.

## 0.9.1 — 2026-10-14

Saving waits until you leave the bar, and the key legend lines up again.

- **Saving waits until you leave the bar.** Omarchy freezes the shell for a
  moment whenever the config is written, so a change made at the bar (a
  drag, a keyboard drag, a menu action) is now saved once the pointer and
  the keyboard mode have left the bar and its drawers, instead of 300 ms
  after each drop. The bar shows the change at once as before; staying on
  the bar, it is saved after 20 s.
- **Key legend lines up again.** The arrow keycaps in the keyboard mode's
  strip were taller than the others and pushed the row out of line; every
  cap now has one height and its text sits on the same baseline as the rest.

## 0.9.0 — 2026-10-14

Drag widgets from the keyboard: Shift with the arrows.

- **Drag from the keyboard.** In the keyboard mode, Shift with the arrows
  (or Shift+h j k l) moves the widget or group icon under the cursor one
  place along the bar, and the cursor goes with it. Past a zone's end it
  moves into the next zone; onto the dots it goes On demand and the zone
  opens with it; inside an expanded zone it moves along the run, and out of
  the run it's shown again. In a drawer or a group's menu it reorders the
  members. Shift with the into and out keys moves a widget into an open
  zone drawer and back onto the bar. Every move glides, the drawer stays
  open, and the config is saved once you let go of Shift, so a widget
  swept along the bar never stalls. The key strip and the `?` sheet list
  it.
- **A widget passes its own group.** Shift+Left on a widget right after
  a group icon now moves it past the group. Before, nothing happened,
  though Shift+Right past a group worked.

## 0.8.2 — 2026-10-14

The drop outline glides from gap to gap while you drag.

- **The drop outline slides.** Dragging a widget along a zone or a drawer, the
  outline of where it will land now glides from one gap to the next, as the
  hover highlight does, instead of shrinking away in one gap and growing in
  the next. Where it first shows it fades in at its full size.

## 0.8.1 — 2026-10-14

A ready-made layout for two zones and the Notch on a fresh install, and
highlights that hold up on a see-through bar.

- **Highlights hold up on a see-through bar.** Hovering or walking the bar
  over a clear or glassy background now draws a deeper highlight (35% on a clear
  bar), where it used to all but vanish over the wallpaper.

- **A ready-made two-zone and Notch layout for a fresh install.** On Omarchy's
  stock bar, the first switch to two zones or Notch now lays the widgets out
  as a finished arrangement: menu, workspaces, indicators, updates, weather
  and agents on the left; Bluetooth, network, audio, power, monitor,
  keyboard layout, clock and tray on the right. A three-zone layout you've
  changed is still split at the clock as before.

## 0.8.0 — 2026-10-14

Zone modes, with a Notch mode that grows the bar out of a MacBook's camera;
activity peeks that bring out just the widget that changed; drawers one size
on every bar; and Powerbar kept working with Omarchy's glassy background and
Qt 6.12.

- **Zone modes: three zones, two, or Notch.** Preferences > Layout now has
  three modes, and each keeps its own arrangement (where each widget sits,
  in what order, and whether it's on the bar, on demand or hidden). Switching
  back finds a mode as you left it. Two zones drop the centre: everything sits
  left or right of a gap one notch wide (Bar > Notch > Notch width; 185 px by
  default). The first time you use a two-zone mode, the centre splits at the
  clock, and the clock and keyboard layout move beside the Preferences button.
  `omarchy-shell powerbar set zones three|two|notch`.
- **Notch**: on a MacBook screen Omarchy describes as notched
  (`display-cutouts.json`), two black zones grow out of the camera. They are
  shaped at their outer ends like the camera itself (its shoulders at the
  top, its corner radius below, whatever the rounding setting), and the bar
  is always
  exactly as tall as the notch. Their dots sit at the far ends, by the screen
  edges, windows stop under the camera even while the bar autohides, the bar
  can't be dragged off the top, and a zone's second row is walked from the
  keyboard as a grid. Each MacBook panel's notch width comes from
  macOS readings, kept in `notch-panels.json`, with the housing's corner
  radii: the camera keeps its real shape with the zones in, whatever the
  bar's rounding, and only that shape reveals the bar.
  - With autohide, pointing at the camera makes each zone spring out of it
    sideways, and an activity peek springs only the widget that changed out
    of the camera, on its own black badge beside it.
  - A group's drawer slides down out of the bar like a zone out of the
    camera: black, attached, its top corners curving into the bar and its
    bottom corners the camera's.
  - On-demand widgets expand in the bar (the notch has no drawers). A zone
    that outgrows the screen wraps onto a second row at the edge, one black
    shape with the first.
  - On the Bar page, Style, Shape and Surface give way to the Notch tile,
    and Readable over windows is hidden (the notch is always opaque).
  - Other screens show the same two black zones.
- **Activity peeks show just the widget**: with autohide, a widget that
  changes no longer brings out its whole zone or the whole bar. It comes out
  alone, on a badge in the bar's shape (its rounding, surface, border and
  shadow), at its own place along the bar, with the bar's timing; the bar
  stays hidden.
- **Preferences stays in its corner on the notch**: when a zone wraps onto a
  second row, the Preferences button keeps its place at the screen edge and
  only the widgets before it wrap.
- **Notch offered wherever the bar sits**: Preferences > Layout offered the
  Notch mode only while the bar was at the top; it now does from any edge,
  since the mode moves the bar there.
- **Shadow on the notch**: the Shadow tile stays on the Bar page in the
  Notch mode; the camera, the zones and their second rows cast it.
- **Drawers are one size on every bar**: a group's strip or menu is always
  the large bar's size, with the bar's spacing, whether the bar is small,
  large or as tall as the notch (on the notch it was the camera's height).
- **Glassy bar background**: Omarchy's bar now steps its background from
  clear to glassy to opaque (a double click on the bar, the menu's
  Transparency, `omarchy bar background`). Powerbar follows: glassy draws the
  bar see-through (35% at most) and blurred, a double click cycles the three,
  and the menu's Transparency works again (it answered "no bar"). Blur needs
  the layer rules in README, "Backdrop blur". On an Omarchy without glassy,
  Powerbar keeps toggling `transparent` as before.
- **Toasts keep their distance from the bar again**: Omarchy's notifications
  now ask the bar its size per screen, and Powerbar answered with a
  vertical bar's size.
- **Omarchy's panel shortcuts recognised again**: Omarchy now binds Super+Ctrl+A
  and the other panel keys in a new form, so Preferences showed Audio,
  Bluetooth and the rest without their shortcut. Both forms are read.
- **Moving a widget no longer rebuilds the bar** (Qt 6.12): every move,
  on the bar or in Preferences, emptied the bar for a moment and built every
  widget again, so the icons blinked out and the bar seemed to reload. Qt
  6.12 handed Powerbar's own edited config over in a form whose lists
  Omarchy's layout reader does not accept; the bar takes a plain copy now.
- **Battery percentage shown whole**: Omarchy's Power widget now draws its
  percentage as a label beside the battery icon, and Powerbar sized the
  widget to the icon alone, so "100%" was cut off. The label counts now.
- **Shortcuts bound on first start**: a new install binds Super+B to the
  keyboard mode and Super+Ctrl+/ to its search, each only where nothing else
  holds the keys, and a notification says what it bound and what holds any
  key it left alone. An existing setup is not touched; README has the two
  commands to bind them by hand.
- **Arrow keys in one keycap**: the key legend and the `?` sheet draw the
  arrows as one keycap (←→↓) and their vim letters as another (hjkl),
  as Atlas does, instead of a cap per key.
- **Widgets stay in their groups when Omarchy edits them**: cycling the
  clock's format, or pinning a tray icon, made Omarchy save the widget
  without Powerbar's keys; it got a new id, left its group and the group
  lost it for good (the tray also lost its On demand setting). The bar now
  puts those keys back from the layout it showed before.
- **Which code is running**: `omarchy-shell powerbar build` answers the
  version, a digest of the files the bar loaded, its git commit and when it
  loaded. `tools/build-check.sh` compares it with the checkout and says
  `current` or `stale`, so a restart that kept older code (or none at all)
  is caught after an update.
- **Omarchy contract check**: `tools/omarchy-contract.cjs` (also part of
  `tools/validate.sh`) checks the installed Omarchy still has every line,
  theme token and UI type Powerbar relies on, about 200 checks, and names
  the Omarchy file and the missing text when one drifts after an update.
- **Search shortcut**: `omarchy-shell powerbar keysSearch` starts the
  keyboard mode with its `/` search already open, for jumping straight to a
  widget by name. Bind it in Preferences → Bar → Keyboard ("Bar search",
  suggested Super+Ctrl+/) or with `set shortcut.bar:search`.
- **Ready for Qt 6.12**: the palette is read as `Commons.Color`, as Omarchy
  now does, since Qt 6.12's QtQuick brings its own `Color` type that would
  shadow it. `tools/validate.sh` fails on a bare `Color.` reference.

## 0.7.0 — 2026-10-11

A highlight that slides from widget to widget, a fuller keyboard mode with
vim and page keys and a two-column shortcut sheet, and a frame log for
debugging.

- **Sliding highlight**: the hover highlight and the keyboard
  cursor slide from widget to widget within a zone and along a drawer's
  rows, instead of fading out and in.
- **Keyboard mode**: `^` and `$` jump to the ends as Home and End do, Page
  Up and Page Down jump zone to zone, and Home, End, `^`, `$` work in drawers.
- **Shortcut sheet**: `?` lays out in two columns, every keyboard-mode key
  on the left (all arrows and their vim letters in one "Movement" row) and
  the widgets' and groups' own shortcuts on the right.
- **Key strip**: at bar level the arrows share one "Move" and Tab and
  Shift+Tab one "Zones".
- **Keyboard mode**: `,` opens Preferences, and `,` in Preferences closes
  them and brings the keyboard mode back with the cursor where it was. The
  key strip and the `?` sheet list it.
- **Frame log** for debugging: `"powerbarFrameLog": true` on the bar in
  shell.json (no Preferences switch) writes a timeline of what the bar does
  (`PB-EV` lines: keys, cards, hover, expansions, drawers, slides, drags,
  config) and the frame timing of each motion (`PB-FT` lines, long frames
  flagged) to the shell log. Off by default; nothing runs while off.

## 0.6.0 — 2026-10-10

Faster, steadier expansion and collapse, a keyboard mode that follows the
pointer, and tooltips that move instead of flickering.

- **Expansion and collapse**: from the keyboard, inline dots expand at once
  and the cursor lands on the zone's first widget as it opens (the first
  growth came about 290 ms after the key before); the give-way pause runs
  only when a widget actually has to yield. Zone drawers open after the
  pointer rests 90 ms, as group icons do, so a pointer crossing the bar no
  longer flashes them open.
- **Keyboard mode**: the cursor is the item's own highlight with a crisp
  one-device-pixel ring and moves without a fade; it follows the pointer
  onto the bar and into drawers, and the keys carry on from there. A click
  anywhere else ends the mode, on any monitor. In drawer mode a zone's strip
  previews as the cursor reaches the zone and is walked with the keys along
  the bar.
- **Tooltips and the name card** move to the next widget in place: no
  ghost fading out beside the new one, no card doubled, cut in half or
  flashing in another zone, and a card at either end of the screen stays
  on it.
- **Drag and drop**: a drop into a group drawer no longer runs a correction
  glide over a distance that was never real, and a widget removed mid-drag
  discards its drop.
- **Lighter startup and idle**: the drag label is built on first use,
  widget glyphs are read once per widget, and an autohide slide no longer
  re-places every highlight on each frame.
- A strip's end cells draw their highlight whole.

## 0.5.0 — 2026-10-10

The first release. Powerbar was cloned from Omarchy's built-in bar
(`omarchy.bar`, Omarchy 4 Quattro's shell) on 2026-09-21 and still starts
out looking and behaving exactly like it, answering to the same `omarchy bar`
commands. What it adds:

- **Where each widget lives**: On the bar, On demand or Hidden. On demand
  widgets show for a moment when they change, and otherwise wait in a drawer
  beside the bar or behind their zone's dots. A zone that runs out of room
  folds its widgets behind the same dots instead of overlapping the next.
- **Groups**: widgets gathered under one icon or name that opens them as a
  drawer or menu, with a badge adding up their members' counts.
- **Bar styles**: Flat, Floating or Islands; **autohide**, with activity
  peeks and Omarchy's bar toggle sliding the bar out while held.
- **Appearance scopes**: Shape, Surface and Shadow follow the theme, your
  values everywhere, or your values for one theme; a theme can ship
  `powerbar.toml`.
- **Keyboard mode** for the whole bar, its drawers and groups, with fuzzy
  search; a shortcut for any widget or group, written as a marked block in
  `~/.config/hypr/bindings.lua`.
- **Drag and drop** along the bar, between zones, into drawers and groups.
- **Preferences** (Layout, Groups, Bar), all usable from the keyboard, with an
  icon picker for groups.
- **`omarchy-shell powerbar`**: every setting, widget, group and shortcut from
  the command line, plus an agent skill (`agents/skills/powerbar/`).

Configs from pre-release builds carry over: the flat appearance keys move
into `powerbarAppearance` as the current theme's values, `powerbarIslands:
true` still reads as the Islands style, and the first shortcut write Hyprland accepts
replaces an old `~/.config/hypr/powerbar.lua` (and its loader in `hyprland.lua`)
with the block in `bindings.lua`.
