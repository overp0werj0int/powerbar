# Appearance

How Powerbar looks and when it shows: surface (opacity, blur, readable minimum), Omarchy's bar background (clear, glassy), island shape (rounding, borders), shadow, text and icon colour, appearance scopes (Theme / Everywhere / Just here), a theme's `powerbar.toml`, tooltips, animations, and bar auto-hide. Controls are in Preferences > Bar (tiles Shape, Surface, Shadow, Behavior); what the controls do on the page is in preferences.md ("Bar appearance and behavior", "Appearance scopes"), and the CLI names (`shape.rounding`, `surface.opacity`, `shadow.scope`, `background`, `transparent`, `autoHide`, `show`, `hide`) are in integration.md.

Storage: the look lives in `bar.powerbarAppearance` of shell.json: `all` (values shared by every theme) and `themes.<theme>` (values for one theme, plus that theme's `text`), each tile holding `use` (`this` or `all`; absent means the default scope) and its values: shape `{ rounding, borders, borderWidth }`, surface `{ opacity, blur }`, shadow `{ enabled, softness, strength }`. Behaviour switches stay flat in `bar`: `powerbarAutoHide`, `powerbarAutoHideActivity`, `powerbarReadableOverlay`, `powerbarAnimations`, `powerbarLargeBar` (layout-zones.md), and Omarchy's own `background` (or `transparent`). Keys from earlier versions are migrated (see Legacy migration).

**Sources:** AppearanceModel.js, RenderModel.js (captureDelta), TooltipModel.js, EffectSurface.qml, BarBackdrop.qml, BarFace.qml, TintedImage.qml, WidgetIcon.qml, Bar.qml (grep: autoHide, barOpacity, surfaceEffects, overlayStyled, tooltip, themeLook, barForeground, transparent, namespace), Preferences.qml (Shape, Surface, Shadow, Behavior tiles; scopeHint), tests/appearance.test.cjs, tests/render.test.cjs, tests/tooltip-model.test.cjs, tests/clean-defaults.test.cjs.

## Surface effects (opacity, blur, shadow)

- **LOOK-1** The bar's surface opacity is the value of Surface > "Background opacity" (stored `opacity`, 0 to 100): it is clamped to 0 to 100 and drawn as a fraction (0 gives 0, 50 gives 0.5, 100 or 140 gives 1, a negative gives 0; no step snapping on read; the slider moves in 5% steps and shows "Clear" at 0, "Opaque" at 100). The default, with nothing chosen and no theme value, is the theme's own bar background alpha (LOOK-9), else 100. Code: AppearanceModel.effects, ranges.backgroundOpacity.

- **LOOK-2** Surface > "Background blur" (stored `blur`, true only when exactly true; default off) puts the bar's layer on the Hyprland namespace `powerbar` (blurred by the user's layer rule, see LOOK-125); off, the namespace is `powerbar-clear`. Changing it hides the bar window for 60 ms with the layout frozen so the new namespace maps; widgets keep their sizes meanwhile. Code: AppearanceModel.effects; Bar.qml WlrLayershell.namespace, blurRemap.

- **LOOK-3** Shadow > "Shadow" (stored `enabled`, default off) paints a shadow behind the flat strip, the floating surface, each island, drawers, and the tooltip, name card and key legend when their look follows Powerbar's (LOOK-91). Code: EffectSurface.qml RectangularShadow; Bar.qml shadowEnabled, overlayShadow.

- **LOOK-4** Shadow > "Softness" (stored `softness`) is clamped to 2 to 24 px, 16 by default (0 gives 2, 30 gives 24). Code: AppearanceModel.ranges.shadowSize.

- **LOOK-5** Shadow > "Strength" (stored `strength`) is clamped to 5 to 60 percent, 30 by default (0 gives 0.05, 70 gives 0.6). Code: AppearanceModel.ranges.shadowOpacity.

- **LOOK-6** Readable minimum: with `powerbarReadableOverlay` unset or true (Behavior > "Readable over windows", default on) and blur off, surfaces that lie over windows are at least 88% opaque: drawers, the tooltip, name card and key legend when styled by Powerbar, and the bar itself while it autohides. An opacity of 50 is drawn as 0.88 there, 95 stays 0.95. The always-visible bar is not raised. In the Notch style on the notch every surface is opaque, so the setting has nothing to do and Preferences hides it (preferences.md PREFS-96). Code: AppearanceModel.overlayOpacity, barOpacity; Bar.qml overlaySurfaceColor.

- **LOOK-7** With `powerbarReadableOverlay: false` those surfaces use the chosen opacity as it is. The setting is not part of the appearance scopes: it is one flat key for every theme. Code: AppearanceModel.overlayOpacity (`readableOverlay !== false`).

- **LOOK-8** With blur on, the readable minimum does not apply: the chosen opacity is used, since the blur keeps text readable. Code: AppearanceModel.overlayOpacity.

- **LOOK-9** With no opacity chosen in any scope, the bar uses the alpha of the theme's own bar background (Omarchy's `[bar] background`), rounded to a whole percent: a theme with a see-through bar background draws see-through. Code: AppearanceModel.effects(config, Color.bar.background.a).

## Bar background (Omarchy's `bar.background`, `bar.transparent` before it)

- **LOOK-140** The bar's background is Omarchy's `bar.background`: `opaque`, `glassy` or `none`. A config without it (written by an Omarchy from before glassy) says `bar.transparent` instead: `true` is `none`, anything else `opaque`; `background` wins when both are present, and an unknown value falls back to `transparent`. `none` is the transparent bar below. Code: AppearanceModel.barBackground; Bar.qml applyBarConfig, backgroundLook.

- **LOOK-141** A glassy bar draws its own surface at no more than 35% opacity (the chosen opacity when that is lower), as Omarchy's glassy bar does, and its window takes the blurred namespace `powerbar` (README, "Backdrop blur"), so it also needs no readable minimum while autohiding. Clear wins over glassy; a glassy bar going clear stays glassy until the clear one has its text colour. Drawers, tooltips and the key legend keep their surface. With an Omarchy that has glassy, Powerbar runs `omarchy-bar sync-glass` whenever the look changes (once shell.json holds it), which turns Omarchy's Hyprland blur toggle on or off as Omarchy's bar does. Code: AppearanceModel.barOpacity; Bar.qml glassy, syncGlass, omarchyGlassy.

- **LOOK-142** Powerbar knows the installed Omarchy has glassy when it ships `default/hypr/toggles/bar-glassy.lua`. Writes then keep only `background` (Powerbar's `transparent` CLI setting writes `none` or `opaque`, as `omarchy bar transparent` does there); with an older Omarchy, writes keep only `transparent`, which is all its `omarchy bar` reads. Code: Bar.qml setBackground, omarchyGlassy; Preferences.qml setOption.

- **LOOK-129** A `none` background (`bar.transparent: true` before glassy; set by `omarchy bar background`, `omarchy bar transparent`, Omarchy's menu Transparency, the shell's toggle, or a double-click on empty bar space, LOOK-133) clears the bar's own surface to opacity 0 in every style (the flat strip, the floating surface, each island). Drawers, tooltips and the key legend keep their surface: the flag is the bar's. The surface clears once Omarchy's `omarchy-bar-text-color` has answered (a 120 ms debounce plus the command), not at the instant the flag is written. Code: AppearanceModel.barOpacity; Bar.qml setRequestedTransparency, transparentForegroundProc.

- **LOOK-130** While the bar's surface is fully clear and Surface > "Text and icons" is Theme, text and icons take the colour `omarchy-bar-text-color <position> <bar size> <theme text> <theme background>` reads from the wallpaper behind the bar, as on Omarchy's own bar; a Light or Dark choice wins, and so does a surface that is not fully clear. The command re-runs when the position, theme colours or `bar.transparent` change. Code: AppearanceModel.wallpaperText; Bar.qml barForeground, refreshTransparentForeground.

- **LOOK-131** An autohidden bar keeps its readable minimum even when transparent: base opacity 0 is raised to 0.88 (not with blur on, or Readable over windows off, where it stays 0). The wallpaper text colour then does not apply (the surface is not clear). Code: AppearanceModel.barOpacity.

- **LOOK-132** Preferences' Surface > "Background opacity" slider shows 0 ("Clear") while the bar is clear, and the opacity it draws while glassy. Moving it writes the opacity and deletes `bar.transparent` and `bar.background`, ending a clear or glassy bar. Code: Preferences.qml setLook; slider value.

- **LOOK-133** Double-clicking empty bar space (not on a widget) steps the background from clear to glassy to opaque and around, as on Omarchy's bar; with an Omarchy without glassy it toggles clear and opaque. The shell's `cycleBackground()` (Omarchy's menu) does the same, and its older `toggleTransparency()` toggles clear and opaque. A hold or drag on empty space moves the bar instead (layout-zones.md ZONE-38). Code: Bar.qml CenterGestureArea onDoubleClicked, cycleBackground, toggleTransparency; AppearanceModel.nextBackground.

- **LOOK-134** Turning transparency off returns the surface and text to the theme's at once: the text colour changes without its 420 ms crossfade while the switch settles. Code: Bar.qml setRequestedTransparency (foregroundAnimationEnabled).

## Island shape (rounding, borders)

- **LOOK-10** Shape > "Corner rounding" (stored `rounding`, in units scaled by the theme's spacing scale, minimum 0) has no stored maximum, but the drawn radius is capped at half the bar's thickness in px (a full pill): any larger value looks the same. With nothing chosen the theme's corner radius (`Style.cornerRadius`) is used. Code: Bar.qml roundingFor; AppearanceModel.ranges.rounding.

- **LOOK-11** On a 38 px (large) bar at spacing scale 1 the rounding slider tops out at 19, the full pill; at its top it reads "Pill", at 0 "Square". Code: AppearanceModel.roundingMax(38, 1) = 19.

- **LOOK-12** On the standard 26 px bar the slider tops out at 13; an odd thickness rounds up so a pill stays reachable (27 gives 14). Code: roundingMax(26, 1) = 13, roundingMax(27, 1) = 14.

- **LOOK-13** The top divides by the spacing scale: 42 px at scale 1.25 gives 17 (42 / 2 / 1.25 = 16.8, rounded up). Code: roundingMax(42, 1.25) = 17.

- **LOOK-14** Shape > "Borders" (stored `borders`) is on unless exactly false: islands, the floating surface, drawers and (when styled) tooltips draw the theme's popups border, or, when "Border thickness" is set, a border of that width. Code: Bar.qml borderFor.

- **LOOK-15** With `borders` false no border is drawn and "Border thickness" is disabled. Unset is not false: with nothing chosen the theme's own border shows. The flat strip never draws a border. Code: Bar.qml borderFor (`powerbarIslandBorders === false` gives Border.none).

- **LOOK-16** Shape > "Border thickness" (stored `borderWidth`) is clamped to 0.5 to 3 px in steps of 0.5; 0 gives 0.5 ("Hairline"), 4 gives 3, a non-number reads as 1. With none chosen the theme's border width is used. Code: AppearanceModel.ranges.borderWidth; Bar.qml borderFor.

- **LOOK-17** Rounding and border settings apply the same way on a side bar: vertical islands use the same radius (capped at half the 28 px bar width) and border. Code: Bar.qml roundingFor, borderFor.

## Text and icons colour

- **LOOK-18** With no choice, text and icons use the theme's colours (Omarchy's `[bar] text`). Surface > "Text and icons" offers Theme, Light and Dark. Code: AppearanceModel.foreground, Bar.qml textOn.

- **LOOK-19** A bare-string `powerbarForeground` from the earliest versions names no theme and applies nowhere; migration drops it. Code: AppearanceModel.foreground, fromLegacy.

- **LOOK-20** A "Dark" choice made in theme A is stored as `powerbarAppearance.themes.A.text: "dark"` and draws the darker of the theme's two colours (bar text and background) in A only. Other themes keep their own colours. Code: AppearanceModel.setText, resolve.

- **LOOK-21** "Light" likewise draws the lighter of the theme's two colours. Code: AppearanceModel.textPair.

- **LOOK-22** A stored `text` other than `light` or `dark` reads as Theme. Code: AppearanceModel.resolve.

- **LOOK-23** Light and dark are the theme's own pair (bar text and bar background) sorted by relative luminance (0.2126 R + 0.7152 G + 0.0722 B after sRGB linearisation): the brighter is Light, the darker Dark, whichever of the two is the text. Code: AppearanceModel.luminance, textPair.

- **LOOK-24** The choice belongs to the theme it was made in: switching themes shows that theme's own choice (default Theme), so a Light choice made for a dark theme never follows you into a light one. It is stored per theme in every scope. Code: AppearanceModel.resolve (`own.text`).

- **LOOK-26** Choosing Theme in "Text and icons" removes the stored `text` for the current theme; the theme's own `powerbar.toml` `[surface] text` (if any) then applies, else the theme's colours. Code: AppearanceModel.setText, resolve.

## Appearance scopes (Theme / Everywhere / Just here)

- **LOOK-27** Shape, Surface and Shadow each have a scope selector. With no user values stored, every tile reads "Theme": its controls are disabled and show the theme's values (from its `powerbar.toml`, else Omarchy's and Hyprland's), with the hint "Using <theme>'s look." (or "Using <theme>'s Powerbar look." when the theme file sets values for that tile). Code: AppearanceModel.scopeOf, resolve; Preferences.qml scopeHint.

- **LOOK-28** Once a tile holds shared ("Everywhere") values, every theme that has not chosen a scope for that tile follows Everywhere, and the hint reads "Yours, in every theme that has no own choice." (or "Yours everywhere; <theme> has its own look." when the theme file sets that tile). Code: AppearanceModel.defaultScope.

- **LOOK-29** The first pick of Everywhere for a tile shares what the tile shows at that moment: the shown values (including ones from the theme's file) are copied into the shared set, so nothing changes on screen. Code: AppearanceModel.setScope.

- **LOOK-30** With rounding 10 set under Everywhere, switching to a theme that has no own choice for Shape draws that theme's islands with rounding 10. Code: AppearanceModel.scopeOf.

- **LOOK-31** Just here keeps values for the current theme only: after picking Just here in theme A with its own rounding, theme B (no choice of its own) shows Theme if nothing is shared, or Everywhere if shared values exist; never A's values. The hint reads "Yours, only while <theme> is on." Code: AppearanceModel.resolve.

- **LOOK-32** The first pick of Everywhere seeds the shared set from what the tile shows: with Just here opacity at 70, picking Everywhere makes 70 the shared opacity. Code: AppearanceModel.setScope.

- **LOOK-33** Switching a tile's scope never erases stored values: Everywhere, Theme and back shows the earlier shared values again. Code: AppearanceModel.setScope, setValue.

- **LOOK-34** Lookup is key by key down the chain for the chosen scope: Just here, then Everywhere, then the theme's file. With Just here opacity 40 and Everywhere opacity 70, the theme in question shows 40, another theme on Everywhere shows 70, and returning shows 40. A key Just here lacks shows its Everywhere value. Code: AppearanceModel.resolve.

- **LOOK-35** Changing a control while a tile follows Everywhere writes the shared value; every theme not on Just here for that tile shows it. Code: AppearanceModel.setValue.

- **LOOK-36** While a tile follows Theme its controls are disabled; a write to it (for example from the CLI) changes nothing. Code: AppearanceModel.setValue (returns for scope "theme").

## A theme's powerbar.toml

- **LOOK-37** Powerbar reads one file, `~/.local/state/omarchy/current/theme/powerbar.toml`, reloads it when it changes or the theme changes, and applies its values to tiles on Theme (and as the last link of Everywhere and Just here, LOOK-34). No file means no theme values. Code: Bar.qml themeLookFile, themeLook.

- **LOOK-38** Omarchy builds that folder from the theme's shipped files, then copies the user's overlay (`~/.config/omarchy/themes/<name>/*`) over them, so an overlay `powerbar.toml` replaces the shipped one as a whole file; Powerbar sees only the result. Code: omarchy-theme-set (cp of the theme, then of the user overlay).

- **LOOK-39** Powerbar ships no template: `powerbar.toml` is whatever file lands in the current theme folder. Code: Bar.qml themeLookFile.

- **LOOK-40** `[shape]` takes `rounding`, `borders`, `border-width`: `rounding = 12`, `borders = true`, `border-width = 1.5` give rounding 12, borders true, border width 1.5. Key and section names are case-insensitive. Code: AppearanceModel.parseLook, lookKeys.

- **LOOK-41** `[surface]` takes `opacity`, `blur`, `text`: `opacity = 85`, `blur = true`, `text = "dark"` give 85, true, "dark" (percent, boolean, string). Code: parseLook.

- **LOOK-42** `[shadow]` takes `enabled`, `softness`, `strength`. Code: parseLook.

- **LOOK-43** `text` accepts exactly `"light"`, `"dark"` or `"theme"` (double or single quotes). Code: parseLook.

- **LOOK-44** A line with another `text` value, or a value that is not a number, `true`/`false` or a quoted string (such as `blur = maybe`), is skipped; other lines still apply. Only `text` is checked per key: a wrong-typed `rounding = "x"` is stored and then ignored by the bar. Code: parseLook.

- **LOOK-45** Full-line comments (`#`) and trailing comments (whitespace then `#` to the line end) are stripped before parsing. Code: parseLook.

- **LOOK-46** Unknown sections and unknown keys (including `borderWidth` camelCase) are ignored. Code: parseLook.

- **LOOK-47** An empty file, or one with only comments and whitespace, gives no values. Code: parseLook returns `{}`.

## Legacy migration

- **LOOK-48** When shell.json holds flat keys from earlier versions (`powerbarIslandRounding`, `powerbarIslandBorders`, `powerbarIslandBorderWidth`, `powerbarBlur`, `powerbarBackgroundOpacity`, `powerbarShadow`, `powerbarShadowSize`, `powerbarShadowOpacity`, their `powerbarMain*` forms, or a `powerbarForeground` map) and a theme name is known, one config write moves them into `powerbarAppearance`; it waits for the theme name, and runs once. Until it is written the bar draws the same from the old keys. Code: Bar.qml healAppearance; AppearanceModel.migrate.

- **LOOK-49** Old `powerbarMainBlur: true` with `powerbarMainBackgroundOpacity: 13` and no `powerbarBackgroundOpacity` draws opacity 0.13; `powerbarMainBlur: true` alone draws 0.80; `powerbarMainBlur: false` with an opacity of 13 draws 1 (the opacity was ignored without blur). Code: AppearanceModel.effects.

- **LOOK-50** For each setting the unified key wins, then its `powerbarMain` form; `powerbarExtended*` keys are never read: `powerbarMainShadow: true` draws a shadow, `powerbarExtendedShadow: true` alone does not. Code: AppearanceModel.effects value().

- **LOOK-51** Migration writes the old values as the current theme's own (`themes.<theme>.<tile>` with `use: "this"`) and deletes the flat keys and the `powerbarMainReadableOverlay` and `powerbarExtendedReadableOverlay` keys; `powerbarReadableOverlay` stays. A `powerbarForeground` map becomes `themes.<theme>.text` entries. Code: AppearanceModel.migrate, fromLegacy.

- **LOOK-52** Every other theme starts on Theme; nothing becomes shared on its own. Code: AppearanceModel.fromLegacy.

- **LOOK-53** See LOOK-50 for key precedence.

- **LOOK-54** A bare-string `powerbarForeground` is deleted by migration and stores nothing (LOOK-19). A `powerbarForeground` map keeps only its `light` and `dark` entries. Code: AppearanceModel.fromLegacy.

- **LOOK-55** At startup, once Powerbar has listed both theme folders (`/usr/share/omarchy/themes`, `~/.config/omarchy/themes`; if either listing fails nothing is pruned), values kept for themes no longer installed are deleted from `powerbarAppearance.themes`, always from a fresh listing (a theme installed while the shell runs keeps its values, INTEG-36); the current theme is always kept. Code: Bar.qml installedThemesProc, pruneAppearanceThemes; AppearanceModel.pruneThemes.

## Bar auto-hide

- **LOOK-56** `powerbarAutoHide: true` (Preferences > Behavior > Autohide; default off) makes the bar reserve no screen space and park past its edge, sliding out over windows; a 2 px strip at the edge stays to catch the pointer. Code: Bar.qml exclusiveZone, autoHideActive, autoHideEdge.

- **LOOK-57** Pointer on the 2 px edge strip, or on the bar, slides it out at once, over 180 ms (ease-out, instant with Animations off), and it stays while held (LOOK-59 to LOOK-62). Code: Bar.qml autoHideHeld, syncStrip.

- **LOOK-58** When nothing holds it any more, the bar waits 400 ms, then slides away over 130 ms. Pointer coming back within the 400 ms keeps it. Code: Bar.qml autoHideDelay (400 ms), syncStrip.

- **LOOK-59** The bar stays out while the pointer is on the bar window, the edge strip, or an open drawer. Code: Bar.qml autoHideHeld (windowHover, edgeHover, drawer.opened).

- **LOOK-60** It also stays out while a widget panel from this bar's window is open. Code: autoHideHeld (activePopout).

- **LOOK-61** It stays out while Preferences is open, the keyboard mode holds this bar, and while `omarchy-shell powerbar show` holds it (integration.md, CLI). Code: autoHideHeld (preferencesOpen, barKeys.heldBy, cliShown).

- **LOOK-62** It stays out during a widget drag, its settle, and a bar-move drag (layout-zones.md ZONE-38). Code: autoHideHeld (barDragSource, barDragSettling, barMoveActive).

- **LOOK-63** With `powerbarAutoHideActivity` (Preferences > Behavior > "Show on widget activity", default on), a change in a widget's `text`, `icon`, `iconText`, `value`, `displayValue`, `powerbarIcon`, `powerbarValue`, `powerbarActivityRevision` (or its `powerbarActivity()` signal) brings out a badge with that widget (or its group's icon) and highlights it, and the bar stays hidden. This holds on an autohidden bar and on one switched off with Omarchy's bar toggle (on-demand-drawers.md DEMAND-14). The badge is the widget alone on a surface in the bar's shape: the bar's rounding, surface, border and shadow, one cell's padding at each end. It slides in from the screen edge at the widget's own place along the bar, as the bar slides (180 ms, ease-out); each widget that changes brings its own. It shows the widget live and takes no pointer: the edge strip still reveals an autohidden bar, and when the bar slides out it covers the badges. The badges stay `powerbarManagedRevealSeconds` (default 2.5 s, 1 to 60) and each further activity restarts that time. Peeks are ignored for 6 s after the bar (re)builds or the layout changes, so loading values do not flash it. Code: Bar.qml autoHidePeek, peek(), peekQuietUntil; ManagedModel.snapshot.

- **LOOK-64** When the peek time ends, the badges slide away together over 130 ms (ease-out). Code: Bar.qml peekEnd, peekClear, PeekBadge.

- **LOOK-65** With `powerbarAutoHideActivity: false` activity never peeks, on an autohidden or a switched-off bar; only the pointer, drawers and the other holds do. Code: Bar.qml autoHidePeek, ActivityObserver enabledForActivity.

- **LOOK-66** A layout entry with `powerbarActivityPeek: false` (Layout page "Show on activity" off) does not peek the bar; the clock (`omarchy.clock`) never does, whatever the entry says. Code: ManagedModel.peeksOnActivity, quietWidgets.

- **LOOK-67** Hovering the 2 px edge strip reveals the bar; leaving it (and the bar) hides it after LOOK-58's delay. Clicking is not needed. Code: Bar.qml autoHideStrip, edgeHover.

- **LOOK-68** On an autohidden bar, when Omarchy's `bar-off` flag (`~/.local/state/omarchy/toggles/bar-off`, set by `omarchy toggle bar`, Super+Shift+Space) appears, Powerbar clears the flag at once (`omarchy-toggle bar-off off`) and slides the bar out instead of hiding it. Without autohide the flag hides the bar (integration.md, "Bar-off toggle integration"). Code: Bar.qml barHiddenProbe, revealFromToggle.

- **LOOK-69** The bar then stays out while the toggle's key is held: Powerbar asks Hyprland every 50 ms whether the bind's key (the bind described "Toggle top bar", else any modifier key) is down, for at most a minute, through one `hyprctl repl` kept open for the hold (no process per poll). Code: Bar.qml toggleKeyWatch, toggleHeld.

- **LOOK-70** After the key is released, the bar slides away 400 ms later (LOOK-58) unless the pointer or another hold keeps it. Code: autoHideHeld (toggleHeld) then autoHideDelay.

- **LOOK-71** The toggle leaves nothing set: the `bar-off` flag is off again after it. Code: Bar.qml revealFromToggle.

## Widget previews in Preferences

- **LOOK-72** While a widget is loaded on a horizontal bar, Preferences shows a live image of it at the bar's own look; Preferences never captures a side bar. Code: Bar.qml captureWidgetImages; WidgetIcon.qml live.

- **LOOK-73** A widget not loaded shows the last image Powerbar saved: `~/.cache/powerbar/widgets/<key>.png` (`$XDG_CACHE_HOME` honoured). The folder is private (made 0700; INTEG-151). Code: Bar.qml widgetImageFile; WidgetIcon cachedUrl.

- **LOOK-74** With neither, the widget's own glyph is shown (in its own font); with no recorded glyph, a stock glyph for its widget id. Code: Preferences.qml icon(); PreferencesModel.icon.

- **LOOK-75** A group shows its own face (glyph in the accent colour, or its image), never a capture. Code: WidgetIcon groupFace.

- **LOOK-76** On a large bar images are grabbed at twice their size and the 6 px lip above and below is trimmed, so the widget shows alone at either bar size. Code: WidgetIcon savedScale, trimY.

- **LOOK-77** A saved image whose height is not that of a horizontal bar (26 px, or 38 px on the large bar, within 1 px) is ignored and the glyph shown. Code: WidgetIcon cacheUsable.

- **LOOK-78** Glyphs the bar draws are read when Preferences opens and cached in `~/.cache/powerbar/glyphs.json` per widget; see preferences.md PREFS-4. Code: Bar.qml glyphButtons, widgetGlyphFile.

- **LOOK-79** A hidden or unloaded widget shows its cached glyph. Code: Bar.qml faceOf.

## Tooltips

- **LOOK-80** On a top bar a tooltip sits below the hovered widget, centred on it, 6 px away. Code: TooltipModel.place (position "top").

- **LOOK-81** On a bottom bar it sits above, centred. Code: TooltipModel.away.

- **LOOK-82** On a left bar it sits to the right, level with the widget. Code: TooltipModel.away.

- **LOOK-83** On a right bar it sits to the left, level with the widget. Code: TooltipModel.away.

- **LOOK-84** On the bar beside an open drawer, a tooltip that would overlap the drawer is moved past the drawer (away from the bar). Code: TooltipModel.place (overlaps).

- **LOOK-85** For a row of a menu (a group showing names) under a top or bottom bar, the tooltip sits beside the menu, to its right, level with the row. Code: TooltipModel.place (drawer.vertical).

- **LOOK-86** If the menu's right side has no room in the window, the tooltip goes to its left. Code: TooltipModel.place (bounds).

- **LOOK-87** For an item in a strip (a horizontal drawer) beside a vertical bar, the tooltip sits out from the bar past the strip, level with the item: left of a strip on a right bar, right of one on a left bar. Code: TooltipModel.place (strip).

- **LOOK-88** For an item in a strip under a horizontal bar, the tooltip sits past the strip, away from the bar, centred on the item. Code: TooltipModel.place.

- **LOOK-89** The gap between a tooltip and what it sits beside is 6 px. Code: Bar.qml (tooltip placement, `6`).

- **LOOK-91** The tooltip, the keyboard name card and the key legend are one look: while a tile (Shape, Surface, Shadow) follows Theme and the theme's file sets nothing for it, that part is Omarchy's own for tooltips and popups (its tooltip colours, corner radius and border, no Powerbar shadow); once the tile is the user's (Everywhere, Just here) or the theme's file sets it, that part is the bar's: surface colour at the overlay opacity (LOOK-6), the bar's text colour, island rounding (a pill at most), island border, and the shadow if on. Shape, Surface and Shadow are decided independently. Code: Bar.qml overlayStyled, tooltipBubble.

- **LOOK-92** A tooltip is not shown while the bar is sliding out, for a widget that is hidden, folded or yielded (Qt still hovers it); it hides 80 ms after the pointer leaves its widget (LOOK-136), and the hover poll catches a missed leave within 100 ms. A hide the bar asks for (a press on the still-hovered widget, a drag starting, dots giving way to their zone) is at once. Code: Bar.qml tooltipWindow (visible: !sliding), showTooltip, hideTooltip, tooltipLinger, hover poll timer.

- **LOOK-93** A tooltip shows 400 ms after the pointer rests on a widget; when another tooltip was shown and cleared within the last 800 ms it shows after about 1 ms. The warm state is one global timer, not per widget. A tooltip is the widget's own text, as on Omarchy's bar: a widget that brings none shows none, and no tooltip carries a shortcut. Code: Bar.qml showTooltip, tooltipWarmUntil, tooltipTimer.

- **LOOK-135** A tooltip (and the keyboard name card) for a widget on the bar sits the tooltip gap past the bar's outer edge, the strip that holds the islands, never past the widget's own cell: an island and a large bar's lip reach beyond the cell, and a tooltip measured from the cell sat on the island's edge. Code: TooltipModel.place (bar), Bar.qml tooltip anchoring with mainStrip.

- **LOOK-136** A tooltip or name card already up moves to its next target in place, resized for the new text and placed as LOOK-80 to 89 place it; it is never closed and opened again, which would leave the compositor fading the old one out where it was, beside the new one. Every card of a bar is drawn in one popup surface that never moves or changes size while shown: it spans the bar window's whole length from the bar's own side, reaches out as far as the card needs (it only grows while shown), takes no input, and the card moves inside it. Moving or resizing the popup itself raced Qt: a popup that changes size is put back by Qt where it was first shown (Quickshell keeps its own placement apart), so a card resized for new text flashed for a frame at the first card's place, doubled, scaled or cut, before it was placed again. For the pointer, the tooltip waits 80 ms after the pointer leaves its widget, so a pointer crossing to a neighbour with a tooltip of its own moves it there; the new one takes its place as soon as it is due (no 400 ms wait, as LOOK-93's warm state). For the keyboard, the card moves with the cursor between widgets and drawer rows. A real hide (a widget without a tooltip, a group icon or dots under the cursor, the mode ending) hides the card at once; the empty surface stays 800 ms (LOOK-93's warm window), so a card coming up meanwhile, on any widget of that bar, reuses it instead of opening beside the old one fading out. A tooltip moving to another monitor's bar shows on that bar's own surface. Code: Bar.qml tooltipWindow (cardUp, tooltipHold, reach, at), moveTooltip, showCard, showTooltip, hideTooltip, tooltipLinger; each bar window re-anchors on tooltipTarget/tooltipText changes.

- **LOOK-137** A tooltip that would run past the end of the screen along the bar (the first or last widget, a strip's end member) slides back on, short of the edge by its shadow's room; it never slides out from the bar over its widget. Code: TooltipModel.place (within, inset), Bar.qml overlayShadowPad.

- **LOOK-138** A card's words and place change together: a card whose next target has no place yet (a widget still growing from no width as its zone opens, KEYS-12) keeps its old words where it stands until the target has one, never the new name beside the old widget. A target just grown is placed after its positioners lay it out, not where it sat before (its zone's start). Code: Bar.qml tooltipWindow text, onAnchoring (forceLayout).
- **LOOK-139** A highlight moving within one zone of a bar, or within one drawer, slides instead of fading: the mark that lights next starts where the last one was drawn, at its size, and glides to its own cell over 100 to 170 ms (90 ms + 0.15 ms per px travelled, OutCubic), while the last one goes out at once. It slides when the last mark went out under 160 ms before (a pointer crossing the gap between two cells) or is going out in the same turn (the keyboard cursor). A pointer sweeping across many cells retargets the slide from wherever the fill is drawn, so it trails the pointer smoothly instead of jumping cell to cell; it never sweeps across a zone gap: a move to another zone, the first light after a pause, or a light while the last mark stays lit for its own reason (a hover beside the keyboard cursor, an open panel) fades in place as before (90 ms). Animations off: no slide. Code: HoverHighlight.qml (`slideFrom`, `handOff`), HighlightGlide.qml (one per bar window, keyed by zone; one per drawer)

- **LOOK-145** Highlights on the bar itself (hover, keyboard cursor, open panel, compound track and thumb) deepen as the bar's surface clears, so they stay visible over the wallpaper: hover and selected go from Omarchy's fill alphas on an opaque bar (and the notch) to 35% on a clear one, the compound track to 12%, in proportion to how clear the surface is; never lighter than Omarchy's. Drawers and Preferences keep Omarchy's fills. Code: AppearanceModel.highlightAlpha; Bar.qml deepened, onBarHoverColor.
- **LOOK-146** A widget is a compound (a track over the whole cell, a thumb over one part) only while two or more of its targets are drawn in its slot: shown, not faded to nothing and not cut off by a clipping parent. The indicators keep their folded icons in a zero-width, transparent area, so folded they are one cell with no thumb, and revealed each icon is a part. Parts are in bar order. The thumb follows the pointer, or the keyboard cursor's part (keyboard.md KEYS-88); a cursor resting on a compound without the pointer never shows a thumb at a stale pointer position. Code: Bar.qml targetPainted, compoundTargets, compoundThumb parts.

## Large bar

- **LOOK-94** `powerbarLargeBar: true` makes the bar 12 px thicker, a 6 px lip above and below each widget (26 to 38 px, 28 to 40 px vertical). Details in layout-zones.md ZONE-23. Code: Bar.qml largeBarLip, barSizeFor.

- **LOOK-95** With the large bar on, Preferences' bar shelves draw at the large thickness. Code: LayoutEditor.qml barThickness (barSizeFor).

- **LOOK-96** Strip drawers have the same thickness as the bar, lip included. A group's menu is the large bar's size on either bar (groups.md GROUP-96). Code: ManagedDrawer.qml thickness (bar.barSize), tokens (bar.menuTokens).

- **LOOK-97** Widget icons keep their own size on a large bar; the extra room is space around them. Code: Bar.qml largeBar comment, cellTokens.

- **LOOK-98** Previews of widgets grabbed on a large bar are trimmed of the lip (LOOK-76). Code: WidgetIcon.

## Notch look

- **LOOK-143** In the Notch style on a top bar with a notched screen (layout-zones.md ZONE-82) the zones are black with the theme's light text on every screen, because a widget takes one colour across the bar. On another edge the style draws as Islands with the bar's own look.
  - The look forces fully opaque surfaces with no blur or border; the Surface choices are kept for the other styles and edges.
  - The shadow is the user's (LOOK-3 to LOOK-5). The camera's body, each zone, a wrapped zone's two rows and the activity badges cast it.
  - Each zone's outer end has the camera's own corners (layout-zones.md ZONE-80), whatever the rounding setting: a shoulder at the top, where the screen's top edge curves down into the zone as it does into the camera, and the camera's bottom radius below. Its inner end is square and runs on under the camera. On a screen without a notch the zones are islands with the camera's bottom radius at every corner (the default housing's, 8 px, with no notched screen).
  - Highlights and cards nest in that radius, as in an island's rounding (LOOK-10). The rounding setting applies to the other styles and edges only.
  - On the notched screen the camera's own black is also drawn behind the zones, so they meet the camera however wide it really is. It has the housing's shape (layout-zones.md ZONE-80), round bottom corners, and shoulders where the screen's top edge curves into it. It shows whole when the zones are in, and below them under a bar shorter than the camera.

  Code: Bar.qml notchMode (surfaceEffects, mainSurfaceColor, barForeground, barStyle), islandRounding, notchCorners, cameraShape, NotchEnd; NotchShape.qml; NotchHanger.qml; IslandSurface; NotchModel.zoneCorners.

- **LOOK-144** Autohide on the notch:
  - **The camera is the edge strip:** only the camera reveals the bar (not a strip along the screen edge, as in LOOK-56 and LOOK-67), in the housing's shape: the screen beside its round bottom corners does not.
  - **Each zone slides on its own:** it slides sideways out of the camera and back into it, clipped at the camera's edge, instead of the strip leaving the screen.
  - **Out:** 220 ms with a spring (OutBack) whose overshoot is held to 4 px, however long the zone. The zone runs on under the camera by 6 px, or by the shoulder and bottom radius plus 1 px when that is more (13 px at scale 2 on a Pro), so the overshoot never parts it from the camera and a zone as tall as the camera covers its round corner once out.
  - **In:** 140 ms (ease-out).
  - **Peeks:** an activity peek (LOOK-63) brings the widget out of the camera on its zone's side, alone on a black badge a single widget long, with the zones' timing and spring above. The badge is square where it meets the camera and has the camera's corners at its outer end, as a zone does. One badge per side: a newer change on that side takes its place.
  - **Lengths:** a hidden zone that changes length follows at once.
  - **Off:** without autohide the zones stay out, blended into the camera.

  Code: Bar.qml slideNotch, notchTuck, notchOvershoot, zoneOut, autoHideStrip, the window mask, PeekBadge (peekLeft, peekRight); NotchModel.backOvershoot.

## Animations

- **LOOK-99** With `powerbarAnimations` unset or true (Behavior > Animations, default on), changes animate: islands and cells resize, drawers grow and shrink, the center slides (layout-zones.md ZONE-70), the bar slides in auto-hide, colours cross-fade. Code: Bar.qml animationsEnabled.

- **LOOK-100** With `powerbarAnimations: false` every change lands in one frame and nothing animates, except the text and icon colour crossfade (LOOK-106). Code: Bar.qml `enabled: root.animationsEnabled` on Behaviors.

- **LOOK-101** A drawer opens over 160 ms and grows from scale 0.96 to 1 (strong ease-out, cubic-bezier 0.23, 1, 0.32, 1). Code: ManagedDrawer.qml reveal, xScale.

- **LOOK-102** A drawer closes over 110 ms with the same ease-out. Code: ManagedDrawer.qml reveal.

- **LOOK-103** A widget's cell resizes over 120 ms (slot motion) when its width changes and no drag is running. Code: Bar.qml slot motionDuration.

- **LOOK-104** An autohidden bar slides out over 180 ms (ease-out). Code: Bar.qml syncStrip.

- **LOOK-105** An autohidden bar slides away over 130 ms. Code: Bar.qml syncStrip.

- **LOOK-106** When the text colour changes (theme switch, Light or Dark choice) it crossfades over 420 ms, InOutCubic, with Animations on; with Animations off it changes at once, on the bar and in widgets that follow the bar's `foregroundAnimationEnabled` (Omarchy's WidgetButton). Code: Bar.qml foregroundFades.

- **LOOK-107** The bar's background and urgent colours crossfade over 420 ms, InOutCubic, with Animations on. Code: Bar.qml Behavior on background / urgent.

- **LOOK-108** In Preferences' bar placement graphic the wallpaper fades in over 160 ms when it loads, with Animations on; off, it appears at once. Code: BarBackdrop.qml.

## Capture invalidation

- **LOOK-109** Changing only the bar's background opacity does not re-render widget previews. Code: RenderModel.captureDelta (returns `[]`).

- **LOOK-110** Any other change in the bar chrome (theme, style, size, spacing, text colour) re-renders every preview. Code: RenderModel.captureDelta (returns `null`).

- **LOOK-111** A changed layout re-renders only the widgets whose entry or index changed. Code: RenderModel.captureDelta.

## Faces drawn in Preferences (BarFace, TintedImage)

- **LOOK-112** A widget image saved in another text colour is redrawn in the bar's current text colour: its shape filled with that colour. Code: LayoutEditor.qml (recolour: f.ink !== barInkHex); BarFace TintedImage tint.

- **LOOK-113** Tinting uses the image's alpha as a mask, so soft edges stay soft (threshold 0.5, spread 1). Code: TintedImage.qml.

- **LOOK-114** A text face is drawn in the bar's font and current text colour. Code: BarFace.qml.

## Bar backdrop (placement graphic)

- **LOOK-119** The placement graphic in Preferences' Bar tile shows the current wallpaper at the monitor's aspect ratio with the bar drawn on the chosen edge in the chosen style (flat: one strip, no gap or rounding; floating: one surface off the edges; islands: three surfaces), using the bar's real surface colour, opacity and island border, so they show as they will look; clicking an edge moves the bar there. Code: BarPlacement.qml, BarBackdrop.qml.

- **LOOK-120** The wallpaper is cropped to fill the graphic, top-aligned and horizontally centred (the placement graphic always passes position "top"). Code: BarBackdrop.qml, BarPlacement.qml.

- **LOOK-121** BarBackdrop aligns the image to the bottom when its `position` is bottom or right, and to the top otherwise; the placement graphic does not use this. Code: BarBackdrop.qml.

- **LOOK-122** The wallpaper fades in over 160 ms when ready (LOOK-108). Code: BarBackdrop.qml.

## Icon colour in Preferences (WidgetIcon)

- **LOOK-123** A group's image icon drawn in Preferences is tinted to the text colour only when it was added as "Text colour"; otherwise it is drawn in its own colours (groups.md). Code: GroupFace.qml tint.

- **LOOK-124** A group whose icon is a glyph shows it in the accent colour in Preferences' widget lists. Code: WidgetIcon groupFace.

## Hyprland layer rules

- **LOOK-125** The bar's layer has namespace `powerbar` while blur is on (Surface > Background blur), `powerbar-clear` otherwise; the keyboard key legend uses `powerbar` when styled and blurred, `powerbar-keys` otherwise. The user's layer rules (README, "Backdrop blur": `^powerbar$` with `blur = true`, `blur_popups = true`, `ignore_alpha = 0.01`) are what actually blur, so blur needs them. Code: Bar.qml WlrLayershell.namespace.

- **LOOK-126** `^powerbar-clear$` is for surfaces that must not blur (rule `blur = false`). Code: Bar.qml.

- **LOOK-127** A blur change remaps the bar window (LOOK-2). Code: Bar.qml blurRemap.

---

## Doc drift

- None found against the current README.md, CONTEXT.md and docs/design/*. The earlier draft listed three items (animation durations absent from AppearanceModel; "doubles the islands' end padding"; per-animation tuning). The first and third are not claims anyone makes in the current README; the second is no longer in README.md.

## Open questions

- Answered from code: the 420 ms text-colour crossfade is one animation on `barForeground`, shared by every text and icon on the bar, so no element lags another. A tooltip has no fade: Animations does not change tooltip timing (400 ms delay, 800 ms warm window). Saved previews are divided by `2 * devicePixelRatio` to get their display size; live previews use their own size.
- Answered: a `bar.transparent` write clears the surface only once `omarchy-bar-text-color` answers with a colour (Bar.qml transparentForegroundProc). Omarchy's bar does exactly the same, and the script falls back to printing the theme's text colour, so it only fails when the script is missing; kept as on Omarchy's bar.
